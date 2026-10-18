import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/calorie_parser.dart';
import '../domain/nutrition_label_image.dart';
import '../domain/parse_result.dart';
import 'calorie_json_parser.dart';

typedef GeminiCalorieParser = GoogleAiCalorieParser;

class GoogleAiCalorieParser implements CalorieParser {
  GoogleAiCalorieParser({
    required this.apiKey,
    this.model = 'gemini-3.5-flash-lite',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    this.client,
    this.thinkingConfig,
  });

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client? client;
  final Map<String, Object>? thinkingConfig;

  @override
  Future<ParseResult?> parse(String input) async {
    final String trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      return null;
    }

    return _generateContent(
      systemInstruction: CalorieParsePrompts.textSystemInstruction,
      parts: <Map<String, Object>>[
        <String, Object>{'text': trimmedInput},
      ],
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

    final String trimmedHint = hint?.trim() ?? '';
    final String prompt = trimmedHint.isEmpty
        ? CalorieParsePrompts.labelUserPrompt
        : '${CalorieParsePrompts.labelUserPrompt} Product hint: $trimmedHint';

    return _generateContent(
      systemInstruction: CalorieParsePrompts.labelSystemInstruction,
      parts: <Map<String, Object>>[
        <String, Object>{'text': prompt},
        <String, Object>{
          'inlineData': <String, Object>{
            'mimeType': image.normalizedMimeType,
            'data': base64Encode(image.bytes),
          },
        },
      ],
      timeout: const Duration(seconds: 30),
    );
  }

  Future<ParseResult?> _generateContent({
    required String systemInstruction,
    required List<Map<String, Object>> parts,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final Uri uri = _buildGenerateContentUri(
        rawBaseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
      );
      final http.Response response = await _postGenerateContent(
        httpClient: httpClient,
        uri: uri,
        systemInstruction: systemInstruction,
        parts: parts,
        timeout: timeout,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog(
          'Google AI Studio API failed with ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      return _parseResultFromResponse(response.body);
    } catch (e) {
      _debugLog('Google AI Studio parser exception: $e');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  Map<String, Object>? _resolveThinkingConfig() {
    if (thinkingConfig != null) {
      return thinkingConfig!.isEmpty ? null : thinkingConfig;
    }
    return defaultThinkingConfigForModel(model);
  }

  /// Returns the recommended default `thinkingConfig` payload for a given model.
  ///
  /// - Gemini 3.x+ models (e.g. `gemini-3.5-flash-lite`, `gemini-3-flash`):
  ///   Require `thinkingLevel` (`'low'`, `'medium'`, `'high'`, `'minimal'`).
  ///   Passing `thinkingBudget: 0` causes:
  ///   "Thinking budget does not map to any valid thinking level."
  ///   We use `'low'` to minimize latency and token consumption while parsing.
  /// - Gemini 2.x models (e.g. `gemini-2.5-flash`):
  ///   Support `thinkingBudget: 0` to disable reasoning tokens.
  /// - Older models (e.g. `gemini-1.5-flash`):
  ///   Do not support `thinkingConfig` (returns `null`).
  static Map<String, Object>? defaultThinkingConfigForModel(String model) {
    String lower = model.trim().toLowerCase();
    if (lower.startsWith('models/')) {
      lower = lower.substring('models/'.length);
    }

    if (!lower.startsWith('gemini') && !lower.contains('/gemini')) {
      return null;
    }

    // Models older than 2.0 (e.g. gemini-1.5-flash, gemini-1.0-pro, gemini-pro)
    // do not support thinkingConfig.
    if (lower.startsWith('gemini-1.') ||
        lower.startsWith('gemini-1-') ||
        lower.contains('/gemini-1.') ||
        lower == 'gemini-pro' ||
        lower.contains('gemini-pro-vision')) {
      return null;
    }

    // Gemini 2.0 / 2.5 models use numeric thinkingBudget (0 disables thinking).
    if (lower.startsWith('gemini-2.') ||
        lower.startsWith('gemini-2-') ||
        lower.contains('/gemini-2.') ||
        lower.contains('/gemini-2-')) {
      return <String, Object>{
        'thinkingBudget': 0,
      };
    }

    // Gemini 3 and newer (including default gemini-3.5-flash-lite) use thinkingLevel.
    // Supplying thinkingBudget (especially 0) causes:
    // "Thinking budget does not map to any valid thinking level."
    return <String, Object>{
      'thinkingLevel': 'low',
    };
  }

  Future<http.Response> _postGenerateContent({
    required http.Client httpClient,
    required Uri uri,
    required String systemInstruction,
    required List<Map<String, Object>> parts,
    required Duration timeout,
  }) {
    final Map<String, Object>? resolvedThinkingConfig = _resolveThinkingConfig();
    final Map<String, Object> generationConfig = <String, Object>{
      'temperature': 0,
      'responseMimeType': 'application/json',
      'thinkingConfig': ?resolvedThinkingConfig,
    };

    final Map<String, Object> payload = <String, Object>{
      'systemInstruction': <String, Object>{
        'parts': <Map<String, String>>[
          <String, String>{'text': systemInstruction},
        ],
      },
      'contents': <Map<String, Object>>[
        <String, Object>{
          'role': 'user',
          'parts': parts,
        },
      ],
      'generationConfig': generationConfig,
    };

    return httpClient
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);
  }

  ParseResult? _parseResultFromResponse(String responseBody) {
    dynamic payload;
    try {
      payload = jsonDecode(responseBody);
    } catch (e) {
      _debugLog('Failed to decode response body as JSON: $e');
      return null;
    }

    if (payload is! Map) {
      _debugLog('Google AI Studio unexpected response payload: $payload');
      return null;
    }

    final dynamic candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      _debugLog('Google AI Studio returned no candidates: $payload');
      return null;
    }

    for (final dynamic candidate in candidates) {
      if (candidate is! Map) {
        continue;
      }

      final dynamic content = candidate['content'];
      if (content is! Map) {
        continue;
      }

      final String? contentText = _extractContentText(content['parts']);
      if (contentText == null || contentText.trim().isEmpty) {
        continue;
      }

      final ParseResult? result = CalorieJsonParser.fromModelText(contentText);
      if (result != null) {
        return result;
      }
    }

    _debugLog('Google AI Studio failed to parse candidates: $candidates');
    return null;
  }

  Uri _buildGenerateContentUri({
    required String rawBaseUrl,
    required String model,
    required String apiKey,
  }) {
    final String normalized = rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.contains(':generateContent')) {
      final Uri parsedUri = Uri.parse(normalized);
      if (!parsedUri.queryParameters.containsKey('key') && apiKey.isNotEmpty) {
        return parsedUri.replace(
          queryParameters: <String, String>{
            ...parsedUri.queryParameters,
            'key': apiKey,
          },
        );
      }
      return parsedUri;
    }

    final String path = normalized.endsWith('/models/$model')
        ? '$normalized:generateContent'
        : normalized.endsWith('/models')
            ? '$normalized/$model:generateContent'
            : '$normalized/models/$model:generateContent';

    return Uri.parse('$path?key=$apiKey');
  }

  String? _extractContentText(dynamic parts) {
    if (parts is String) {
      return parts;
    }

    if (parts is List<dynamic>) {
      // 1. Try finding a non-thought part that contains valid calorie JSON directly.
      for (final dynamic part in parts) {
        if (part is Map) {
          final dynamic text = part['text'];
          final bool isThought =
              part['thought'] == true ||
              part['thought'] == 'true' ||
              part['role'] == 'thought';

          if (text is String && text.trim().isNotEmpty && !isThought) {
            if (CalorieJsonParser.fromModelText(text) != null) {
              return text;
            }
          }
        }
      }

      // 2. Concatenate non-thought parts (e.g. streaming or split text).
      final StringBuffer nonThoughtBuffer = StringBuffer();
      final StringBuffer allBuffer = StringBuffer();

      for (final dynamic part in parts) {
        if (part is Map) {
          final dynamic text = part['text'];
          final bool isThought =
              part['thought'] == true ||
              part['thought'] == 'true' ||
              part['role'] == 'thought';
          if (text is String && text.isNotEmpty) {
            allBuffer.write(text);
            if (!isThought) {
              nonThoughtBuffer.write(text);
            }
          }
        } else if (part is String && part.isNotEmpty) {
          allBuffer.write(part);
          nonThoughtBuffer.write(part);
        }
      }

      final String nonThoughtValue = nonThoughtBuffer.toString().trim();
      if (nonThoughtValue.isNotEmpty) {
        return nonThoughtValue;
      }

      // 3. Fallback: try finding any part that contains valid calorie JSON directly.
      for (final dynamic part in parts) {
        if (part is Map) {
          final dynamic text = part['text'];
          if (text is String && text.trim().isNotEmpty) {
            if (CalorieJsonParser.fromModelText(text) != null) {
              return text;
            }
          }
        }
      }

      final String allValue = allBuffer.toString().trim();
      return allValue.isEmpty ? null : allValue;
    }

    if (parts is Map) {
      final dynamic text = parts['text'];
      if (text is String) {
        return text;
      }
    }

    return null;
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}
