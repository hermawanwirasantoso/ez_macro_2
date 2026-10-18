import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/calorie_parser.dart';
import '../domain/nutrition_label_image.dart';
import '../domain/parse_result.dart';
import 'calorie_json_parser.dart';

/// Parses meals and nutrition labels with the Claude Messages API.
///
/// Dart has no official Anthropic SDK, so this calls `POST /v1/messages`
/// directly. The API key is only ever sent in the `x-api-key` header, never in
/// the URL or logs.
class ClaudeCalorieParser implements CalorieParser {
  ClaudeCalorieParser({
    required this.apiKey,
    this.model = 'claude-haiku-5-5',
    this.baseUrl = 'https://api.anthropic.com',
    String? effort,
    this.client,
  }) : effort = effort ?? defaultEffortForModel(model);

  static const String apiVersion = '2023-06-01';
  static const String fallbackBeta = 'server-side-fallback-2026-07-01';

  /// Haiku runs at `medium`: at `low` it sometimes skipped thinking and
  /// mis-added multi-ingredient meals (e.g. oats + milk). Sonnet and Opus were
  /// already consistent at `low`, so they stay there.
  static String defaultEffortForModel(String model) =>
      model.contains('haiku') ? 'medium' : 'low';

  /// Models that accept `fallbacks: "default"`, which re-runs a request on a
  /// recommended model server-side if a safety classifier declines it.
  static const Set<String> _defaultFallbackModels = <String>{
    'claude-fable-5-1',
    'claude-opus-5-5',
    'claude-opus-5',
    'claude-sonnet-5-5',
  };

  /// Image types the Messages API accepts. Anything else (e.g. HEIC) is left
  /// to the next parser in the chain.
  static const Set<String> _supportedImageTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };

  static const Map<String, Object> _numberField = <String, Object>{
    'type': 'number',
  };
  static const Map<String, Object> _stringField = <String, Object>{
    'type': 'string',
  };

  /// JSON schema for structured outputs; matches the shape described in
  /// [CalorieParsePrompts].
  static const Map<String, Object> resultSchema = <String, Object>{
    'type': 'object',
    'properties': <String, Object>{
      'mealLabel': _stringField,
      'portionSize': _numberField,
      'portionUnit': _stringField,
      'calories': _numberField,
      'proteinG': _numberField,
      'carbsG': _numberField,
      'fatG': _numberField,
      'saturatedFatG': _numberField,
      'fiberG': _numberField,
      'addedSugarG': _numberField,
      'sodiumMg': _numberField,
      'confidence': _numberField,
    },
    'required': <String>[
      'mealLabel',
      'portionSize',
      'portionUnit',
      'calories',
      'proteinG',
      'carbsG',
      'fatG',
      'saturatedFatG',
      'fiberG',
      'addedSugarG',
      'sodiumMg',
      'confidence',
    ],
    'additionalProperties': false,
  };

  final String apiKey;
  final String model;
  final String baseUrl;

  /// `output_config.effort`; defaults per model via [defaultEffortForModel].
  final String effort;
  final http.Client? client;

  @override
  Future<ParseResult?> parse(String input) async {
    final String trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      return null;
    }

    return _createMessage(
      systemInstruction: CalorieParsePrompts.textSystemInstruction,
      content: trimmedInput,
    );
  }

  @override
  Future<ParseResult?> parseNutritionLabel(
    NutritionLabelImage image, {
    String? hint,
  }) async {
    if (image.isEmpty) {
      return null;
    }

    final String mediaType = image.normalizedMimeType;
    if (!_supportedImageTypes.contains(mediaType)) {
      _debugLog('Claude does not accept $mediaType images; skipping.');
      return null;
    }

    final String trimmedHint = hint?.trim() ?? '';
    final String prompt = trimmedHint.isEmpty
        ? CalorieParsePrompts.labelUserPrompt
        : '${CalorieParsePrompts.labelUserPrompt} Product hint: $trimmedHint';

    return _createMessage(
      systemInstruction: CalorieParsePrompts.labelSystemInstruction,
      content: <Map<String, Object>>[
        <String, Object>{
          'type': 'image',
          'source': <String, Object>{
            'type': 'base64',
            'media_type': mediaType,
            'data': base64Encode(image.bytes),
          },
        },
        <String, Object>{'type': 'text', 'text': prompt},
      ],
      timeout: const Duration(seconds: 45),
    );
  }

  Future<ParseResult?> _createMessage({
    required String systemInstruction,
    required Object content,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final bool useFallbacks = _defaultFallbackModels.contains(model);
      final Map<String, Object> payload = <String, Object>{
        'model': model,
        'max_tokens': 16000,
        'system': systemInstruction,
        'messages': <Map<String, Object>>[
          <String, Object>{'role': 'user', 'content': content},
        ],
        'output_config': <String, Object>{
          'effort': effort,
          'format': <String, Object>{
            'type': 'json_schema',
            'schema': resultSchema,
          },
        },
        if (useFallbacks) 'fallbacks': 'default',
      };

      final http.Response response = await httpClient
          .post(
            _buildMessagesUri(baseUrl),
            headers: <String, String>{
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': apiVersion,
              if (useFallbacks) 'anthropic-beta': fallbackBeta,
              // Browsers block direct calls without this opt-in. Safe here
              // because the key is the user's own, entered on their device.
              if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog(
          'Claude API failed with ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      return _parseResultFromResponse(response.body);
    } catch (e) {
      _debugLog('Claude parser exception: $e');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  ParseResult? _parseResultFromResponse(String responseBody) {
    dynamic payload;
    try {
      payload = jsonDecode(responseBody);
    } catch (e) {
      _debugLog('Failed to decode Claude response body as JSON: $e');
      return null;
    }

    if (payload is! Map) {
      _debugLog('Claude unexpected response payload: $payload');
      return null;
    }

    if (payload['stop_reason'] == 'refusal') {
      _debugLog('Claude declined the request: ${payload['stop_details']}');
      return null;
    }

    final dynamic content = payload['content'];
    if (content is! List) {
      _debugLog('Claude returned no content: $payload');
      return null;
    }

    // Only text blocks carry the answer; thinking and fallback blocks are
    // skipped.
    final StringBuffer buffer = StringBuffer();
    for (final dynamic block in content) {
      if (block is Map && block['type'] == 'text') {
        final dynamic text = block['text'];
        if (text is String) {
          buffer.write(text);
        }
      }
    }

    final ParseResult? result = CalorieJsonParser.fromModelText(
      buffer.toString(),
    );
    if (result == null) {
      _debugLog('Claude failed to parse content: $content');
    }
    return result;
  }

  Uri _buildMessagesUri(String rawBaseUrl) {
    final String normalized = rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/v1/messages')) {
      return Uri.parse(normalized);
    }
    if (normalized.endsWith('/v1')) {
      return Uri.parse('$normalized/messages');
    }
    return Uri.parse('$normalized/v1/messages');
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}
