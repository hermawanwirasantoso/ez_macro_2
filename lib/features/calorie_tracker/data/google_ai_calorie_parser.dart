import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/calorie_parser.dart';
import '../domain/parse_result.dart';

typedef GeminiCalorieParser = GoogleAiCalorieParser;

class GoogleAiCalorieParser implements CalorieParser {
  GoogleAiCalorieParser({
    required this.apiKey,
    this.model = 'gemini-3.5-flash-lite',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
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
        input: trimmedInput,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog(
          'Google AI Studio API failed with ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? candidates =
          payload['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        _debugLog('Google AI Studio returned no candidates: $payload');
        return null;
      }

      final Map<String, dynamic>? candidate =
          candidates.first as Map<String, dynamic>?;
      final Map<String, dynamic>? content =
          candidate?['content'] as Map<String, dynamic>?;
      final String? contentText = _extractContentText(content?['parts']);
      if (contentText == null || contentText.trim().isEmpty) {
        _debugLog('Google AI Studio empty content text in candidate: $candidate');
        return null;
      }

      final String jsonContent = _extractJsonObject(contentText.trim());
      final Map<String, dynamic> extracted =
          jsonDecode(jsonContent) as Map<String, dynamic>;

      final String rawLabel = (extracted['mealLabel'] ?? '').toString().trim();
      final String mealLabel = rawLabel.isEmpty ? 'Meal' : rawLabel;
      final int? calories = _toInt(extracted['calories']);
      if (calories == null || calories <= 0) {
        _debugLog('Google AI Studio response missing calories field: $extracted');
        return null;
      }

      final ({int protein, int carbs, int fat}) estimated =
          _estimateMacrosForCalories(calories);
      final int proteinG =
          (_toIntByKeys(extracted, <String>['proteinG', 'protein', 'protein_g']) ??
                  estimated.protein)
              .clamp(0, 400)
              .toInt();
      final int carbsG =
          (_toIntByKeys(extracted, <String>['carbsG', 'carbs', 'carbohydrate_g']) ??
                  estimated.carbs)
              .clamp(0, 600)
              .toInt();
      final int fatG =
          (_toIntByKeys(extracted, <String>['fatG', 'fat', 'fat_g']) ?? estimated.fat)
              .clamp(0, 300)
              .toInt();

      final double confidence =
          _toDouble(extracted['confidence'])?.clamp(0.0, 1.0) ?? 0.85;

      return ParseResult(
        mealLabel: mealLabel,
        calories: calories.clamp(1, 5000).toInt(),
        confidence: confidence,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
      );
    } catch (e) {
      _debugLog('Google AI Studio parser exception: $e');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  Future<http.Response> _postGenerateContent({
    required http.Client httpClient,
    required Uri uri,
    required String input,
  }) {
    final Map<String, Object> payload = <String, Object>{
      'systemInstruction': <String, Object>{
        'parts': <Map<String, String>>[
          <String, String>{
            'text':
                'Extract meal label, calories, and macros from user text. Important: if input includes grams (like "200g chicken breast"), grams are portion size, not calories. Infer calories/macros from food type and portion. Return JSON only: {"mealLabel":"string","calories":number,"proteinG":number,"carbsG":number,"fatG":number,"confidence":0..1}.',
          },
        ],
      },
      'contents': <Map<String, Object>>[
        <String, Object>{
          'role': 'user',
          'parts': <Map<String, String>>[
            <String, String>{'text': input},
          ],
        },
      ],
      'generationConfig': <String, Object>{
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
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
        .timeout(const Duration(seconds: 15));
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
      final StringBuffer buffer = StringBuffer();
      for (final dynamic part in parts) {
        if (part is Map<String, dynamic>) {
          final dynamic text = part['text'];
          if (text is String) {
            buffer.write(text);
          }
        } else if (part is String) {
          buffer.write(part);
        }
      }
      final String value = buffer.toString().trim();
      return value.isEmpty ? null : value;
    }

    if (parts is Map<String, dynamic>) {
      final dynamic text = parts['text'];
      if (text is String) {
        return text;
      }
    }

    return null;
  }

  String _extractJsonObject(String input) {
    final int start = input.indexOf('{');
    final int end = input.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('No JSON object found in response.');
    }
    return input.substring(start, end + 1);
  }

  int? _toIntByKeys(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      final int? value = _toInt(map[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  ({int protein, int carbs, int fat}) _estimateMacrosForCalories(int calories) {
    final int protein = (calories * 0.30 / 4).round();
    final int carbs = (calories * 0.40 / 4).round();
    final int fat = (calories * 0.30 / 9).round();
    return (protein: protein, carbs: carbs, fat: fat);
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}
