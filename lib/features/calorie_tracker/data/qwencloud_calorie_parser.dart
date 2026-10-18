import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/calorie_parser.dart';
import '../domain/nutrition_label_image.dart';
import '../domain/parse_result.dart';
import 'calorie_json_parser.dart';

class QwenCloudCalorieParser implements CalorieParser {
  QwenCloudCalorieParser({
    required this.apiKey,
    this.model = 'deepseek-v4.1-flash',
    this.baseUrl = 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    this.client,
  });

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client? client;

  @override
  Future<ParseResult?> parse(String input) async {
    final String trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      return null;
    }

    return _chatCompletions(
      systemInstruction: CalorieParsePrompts.textSystemInstruction,
      userContent: trimmedInput,
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

    return _chatCompletions(
      systemInstruction: CalorieParsePrompts.labelSystemInstruction,
      userContent: <Map<String, Object>>[
        <String, Object>{'type': 'text', 'text': prompt},
        <String, Object>{
          'type': 'image_url',
          'image_url': <String, Object>{
            'url':
                'data:${image.normalizedMimeType};base64,${base64Encode(image.bytes)}',
          },
        },
      ],
      timeout: const Duration(seconds: 30),
    );
  }

  Future<ParseResult?> _chatCompletions({
    required String systemInstruction,
    required Object userContent,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final Uri uri = _buildChatCompletionsUri(baseUrl);
      final Map<String, Object> payload = <String, Object>{
        'model': model,
        'temperature': 0,
        'max_tokens': 2048,
        'enable_thinking': false,
        'response_format': <String, String>{'type': 'json_object'},
        'messages': <Map<String, Object>>[
          <String, Object>{
            'role': 'system',
            'content': systemInstruction,
          },
          <String, Object>{
            'role': 'user',
            'content': userContent,
          },
        ],
      };

      final http.Response response = await httpClient
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog(
          'QwenCloud API failed with ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      return _parseResultFromResponse(response.body);
    } catch (e) {
      _debugLog('QwenCloud parser exception: $e');
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
      _debugLog('Failed to decode QwenCloud response body as JSON: $e');
      return null;
    }

    if (payload is! Map) {
      _debugLog('QwenCloud unexpected response payload: $payload');
      return null;
    }

    final dynamic choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      _debugLog('QwenCloud returned no choices: $payload');
      return null;
    }

    for (final dynamic choice in choices) {
      if (choice is! Map) {
        continue;
      }

      final String? contentText = _extractMessageContent(choice['message']);
      if (contentText == null || contentText.trim().isEmpty) {
        continue;
      }

      final ParseResult? result = CalorieJsonParser.fromModelText(contentText);
      if (result != null) {
        return result;
      }
    }

    _debugLog('QwenCloud failed to parse choices: $choices');
    return null;
  }

  String? _extractMessageContent(dynamic message) {
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    if (message is! Map) {
      return null;
    }

    final String? fromContent = _extractContentValue(message['content']);
    if (fromContent != null && fromContent.trim().isNotEmpty) {
      return fromContent;
    }

    final String? fromReasoning =
        _extractContentValue(message['reasoning_content']);
    if (fromReasoning != null && fromReasoning.trim().isNotEmpty) {
      return fromReasoning;
    }

    return null;
  }

  String? _extractContentValue(dynamic content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      final StringBuffer buffer = StringBuffer();
      for (final dynamic part in content) {
        if (part is String && part.isNotEmpty) {
          buffer.write(part);
        } else if (part is Map) {
          final dynamic text = part['text'];
          if (text is String && text.isNotEmpty) {
            buffer.write(text);
          }
        }
      }
      final String value = buffer.toString().trim();
      return value.isEmpty ? null : value;
    }
    if (content is Map) {
      final dynamic text = content['text'];
      if (text is String) {
        return text;
      }
    }
    return null;
  }

  Uri _buildChatCompletionsUri(String rawBaseUrl) {
    final String normalized = rawBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/chat/completions')) {
      return Uri.parse(normalized);
    }
    return Uri.parse('$normalized/chat/completions');
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}
