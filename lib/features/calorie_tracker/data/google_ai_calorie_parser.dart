import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/calorie_parser.dart';
import '../domain/nutrition_label_image.dart';
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

  static const String _textSystemInstruction =
      'Extract meal label, calories, macronutrients, and complete nutrition details (saturated fat, fiber, added sugar, sodium) from user text. Important: if input includes grams (like "200g chicken breast"), grams are portion size, not calories. Infer calories and detailed nutrition from food type and portion. Return JSON only: {"mealLabel":"string","calories":number,"proteinG":number,"carbsG":number,"fatG":number,"saturatedFatG":number,"fiberG":number,"addedSugarG":number,"sodiumMg":number,"confidence":0..1}.';

  static const String _labelSystemInstruction =
      'Read the nutrition facts label in the image. Extract the product or food name, calories, protein, carbs, fat, saturated fat, dietary fiber, added sugar, and sodium for one serving shown on the label. Prefer per-serving values, not per container, unless the label only shows per container. If a product name is not visible, use a short generic name. Return JSON only: {"mealLabel":"string","calories":number,"proteinG":number,"carbsG":number,"fatG":number,"saturatedFatG":number,"fiberG":number,"addedSugarG":number,"sodiumMg":number,"confidence":0..1}.';

  @override
  Future<ParseResult?> parse(String input) async {
    final String trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      return null;
    }

    return _generateContent(
      systemInstruction: _textSystemInstruction,
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
        ? 'Extract nutrition facts for one serving from this label photo.'
        : 'Extract nutrition facts for one serving from this label photo. Product hint: $trimmedHint';

    return _generateContent(
      systemInstruction: _labelSystemInstruction,
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

  Future<http.Response> _postGenerateContent({
    required http.Client httpClient,
    required Uri uri,
    required String systemInstruction,
    required List<Map<String, Object>> parts,
    required Duration timeout,
  }) {
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

      final Map<String, dynamic>? extracted = _extractJsonMap(contentText);
      if (extracted == null) {
        continue;
      }

      final ParseResult? result = _buildParseResult(extracted);
      if (result != null) {
        return result;
      }
    }

    _debugLog('Google AI Studio failed to parse candidates: $candidates');
    return null;
  }

  ParseResult? _buildParseResult(Map<String, dynamic> extracted) {
    final String? labelCandidate = _toStringByKeys(extracted, <String>[
      'mealLabel',
      'meal_label',
      'mealName',
      'meal_name',
      'foodName',
      'food_name',
      'productName',
      'product_name',
      'name',
      'meal',
      'food',
      'product',
      'item',
      'label',
      'title',
      'description',
    ]);
    final String rawLabel = labelCandidate?.trim() ?? '';
    final String mealLabel = rawLabel.isEmpty ? 'Meal' : rawLabel;

    final int? calories = _toIntByKeys(extracted, <String>[
      'calories',
      'calorie',
      'kcal',
      'calories_kcal',
      'energy',
      'energy_kcal',
      'energyKcal',
      'total_calories',
      'totalCalories',
      'calories_per_serving',
      'caloriesPerServing',
      'calories_per_container',
      'caloriesPerContainer',
      'cals',
    ]);

    if (calories == null || calories <= 0) {
      _debugLog('Google AI Studio response missing calories field: $extracted');
      return null;
    }

    final ({int protein, int carbs, int fat}) estimated =
        _estimateMacrosForCalories(calories);

    final int proteinG = (_toIntByKeys(extracted, <String>[
              'proteinG',
              'protein_g',
              'protein',
              'proteins',
              'total_protein',
              'totalProtein',
              'protein_grams',
              'proteinGrams',
            ]) ??
            estimated.protein)
        .clamp(0, 400)
        .toInt();

    final int carbsG = (_toIntByKeys(extracted, <String>[
              'carbsG',
              'carbs_g',
              'carbs',
              'carb',
              'carbohydrate',
              'carbohydrates',
              'carbohydrate_g',
              'carbohydrateG',
              'total_carbohydrate',
              'totalCarbohydrate',
              'total_carbs',
              'totalCarbs',
              'carbs_grams',
              'carbsGrams',
              'net_carbs',
              'netCarbs',
            ]) ??
            estimated.carbs)
        .clamp(0, 600)
        .toInt();

    final int fatG = (_toIntByKeys(extracted, <String>[
              'fatG',
              'fat_g',
              'fat',
              'fats',
              'total_fat',
              'totalFat',
              'fat_grams',
              'fatGrams',
            ]) ??
            estimated.fat)
        .clamp(0, 300)
        .toInt();

    final int saturatedFatG = (_toIntByKeys(extracted, <String>[
              'saturatedFatG',
              'saturated_fat_g',
              'saturated_fat',
              'saturatedFat',
              'sat_fat_g',
              'sat_fat',
              'satFat',
              'saturated_fat_grams',
              'saturatedFatGrams',
              'saturated',
            ]) ??
            0)
        .clamp(0, 200)
        .toInt();

    final int fiberG = (_toIntByKeys(extracted, <String>[
              'fiberG',
              'fiber_g',
              'fiber',
              'fibers',
              'dietary_fiber',
              'dietaryFiber',
              'total_fiber',
              'totalFiber',
              'dietary_fiber_g',
              'dietaryFiberG',
              'fiber_grams',
              'fiberGrams',
            ]) ??
            0)
        .clamp(0, 200)
        .toInt();

    final int addedSugarG = (_toIntByKeys(extracted, <String>[
              'addedSugarG',
              'added_sugar_g',
              'added_sugar',
              'added_sugars',
              'addedSugar',
              'addedSugars',
              'added_sugar_grams',
              'addedSugarGrams',
              'sugarG',
              'sugar_g',
              'sugar',
              'sugars',
              'total_sugar',
              'totalSugars',
            ]) ??
            0)
        .clamp(0, 500)
        .toInt();

    final int sodiumMg = (_toIntByKeys(extracted, <String>[
              'sodiumMg',
              'sodium_mg',
              'sodium',
              'sodium_milligrams',
              'sodiumMilligrams',
              'salt_mg',
              'salt',
            ]) ??
            0)
        .clamp(0, 20000)
        .toInt();

    final double confidence =
        _toDoubleByKeys(extracted, <String>[
              'confidence',
              'score',
              'accuracy',
              'probability',
            ])?.clamp(0.0, 1.0) ??
            0.85;

    return ParseResult(
      mealLabel: mealLabel,
      calories: calories.clamp(1, 5000).toInt(),
      confidence: confidence,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      saturatedFatG: saturatedFatG,
      fiberG: fiberG,
      addedSugarG: addedSugarG,
      sodiumMg: sodiumMg,
    );
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
      final StringBuffer nonThoughtBuffer = StringBuffer();
      final StringBuffer allBuffer = StringBuffer();

      for (final dynamic part in parts) {
        if (part is Map) {
          final dynamic text = part['text'];
          final bool isThought =
              part['thought'] == true || part['thought'] == 'true';
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

  Map<String, dynamic>? _extractJsonMap(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    // Attempt 1: Direct JSON decode
    try {
      final dynamic decoded = jsonDecode(trimmed);
      final Map<String, dynamic>? map = _findRelevantMap(decoded);
      if (map != null) {
        return map;
      }
    } catch (_) {}

    // Attempt 2: Strip markdown code fences ```json ... ``` or ``` ... ```
    final RegExp codeBlockRegex = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      caseSensitive: false,
    );
    for (final RegExpMatch match in codeBlockRegex.allMatches(trimmed)) {
      final String? blockContent = match.group(1)?.trim();
      if (blockContent != null && blockContent.isNotEmpty) {
        try {
          final dynamic decoded = jsonDecode(blockContent);
          final Map<String, dynamic>? map = _findRelevantMap(decoded);
          if (map != null) {
            return map;
          }
        } catch (_) {}
      }
    }

    // Attempt 3: Find outermost balanced { ... } or substring from first { to last }
    final int firstBrace = trimmed.indexOf('{');
    final int lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      try {
        final dynamic decoded =
            jsonDecode(trimmed.substring(firstBrace, lastBrace + 1));
        final Map<String, dynamic>? map = _findRelevantMap(decoded);
        if (map != null) {
          return map;
        }
      } catch (_) {}

      // Try balanced braces extraction from each '{'
      for (int i = 0; i < trimmed.length; i++) {
        if (trimmed[i] == '{') {
          int depth = 0;
          bool inString = false;
          bool escape = false;
          for (int j = i; j < trimmed.length; j++) {
            final String char = trimmed[j];
            if (escape) {
              escape = false;
              continue;
            }
            if (char == '\\') {
              escape = true;
              continue;
            }
            if (char == '"') {
              inString = !inString;
              continue;
            }
            if (!inString) {
              if (char == '{') depth++;
              if (char == '}') {
                depth--;
                if (depth == 0) {
                  try {
                    final dynamic decoded =
                        jsonDecode(trimmed.substring(i, j + 1));
                    final Map<String, dynamic>? map = _findRelevantMap(decoded);
                    if (map != null) {
                      return map;
                    }
                  } catch (_) {}
                  break;
                }
              }
            }
          }
        }
      }
    }

    // Attempt 4: Try JSON array [ ... ]
    final int firstBracket = trimmed.indexOf('[');
    final int lastBracket = trimmed.lastIndexOf(']');
    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      try {
        final dynamic decoded =
            jsonDecode(trimmed.substring(firstBracket, lastBracket + 1));
        final Map<String, dynamic>? map = _findRelevantMap(decoded);
        if (map != null) {
          return map;
        }
      } catch (_) {}
    }

    return null;
  }

  Map<String, dynamic>? _findRelevantMap(dynamic decoded) {
    if (decoded is Map) {
      final Map<String, dynamic> map = decoded.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );

      if (_hasCalorieKey(map)) {
        return map;
      }

      for (final dynamic val in map.values) {
        if (val is Map) {
          final Map<String, dynamic>? nested = _findRelevantMap(val);
          if (nested != null) {
            return <String, dynamic>{
              ...map,
              ...nested,
            };
          }
        } else if (val is List) {
          final Map<String, dynamic>? fromList = _findRelevantMap(val);
          if (fromList != null) {
            return <String, dynamic>{
              ...map,
              ...fromList,
            };
          }
        }
      }

      return map;
    }

    if (decoded is List) {
      for (final dynamic item in decoded) {
        final Map<String, dynamic>? candidate = _findRelevantMap(item);
        if (candidate != null && _hasCalorieKey(candidate)) {
          return candidate;
        }
      }
      if (decoded.isNotEmpty && decoded.first is Map) {
        return _findRelevantMap(decoded.first);
      }
    }

    return null;
  }

  bool _hasCalorieKey(Map<String, dynamic> map) {
    const List<String> calorieKeys = <String>[
      'calories',
      'calorie',
      'kcal',
      'calorieskcal',
      'energy',
      'energykcal',
      'totalcalories',
      'caloriesperserving',
      'caloriespercontainer',
      'cals',
    ];
    return map.keys.any((String k) {
      final String normalized =
          k.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      return calorieKeys.contains(normalized);
    });
  }

  String? _toStringByKeys(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        final String val = map[key].toString().trim();
        if (val.isNotEmpty) {
          return val;
        }
      }
      final String lowerKey = key.toLowerCase();
      for (final MapEntry<String, dynamic> entry in map.entries) {
        if (entry.key.toLowerCase() == lowerKey && entry.value != null) {
          final String val = entry.value.toString().trim();
          if (val.isNotEmpty) {
            return val;
          }
        }
      }
    }
    return null;
  }

  int? _toIntByKeys(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        final int? value = _toInt(map[key]);
        if (value != null) {
          return value;
        }
      }
      final String lowerKey = key.toLowerCase();
      for (final MapEntry<String, dynamic> entry in map.entries) {
        if (entry.key.toLowerCase() == lowerKey && entry.value != null) {
          final int? value = _toInt(entry.value);
          if (value != null) {
            return value;
          }
        }
      }
    }
    return null;
  }

  double? _toDoubleByKeys(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        final double? value = _toDouble(map[key]);
        if (value != null) {
          return value;
        }
      }
      final String lowerKey = key.toLowerCase();
      for (final MapEntry<String, dynamic> entry in map.entries) {
        if (entry.key.toLowerCase() == lowerKey && entry.value != null) {
          final double? value = _toDouble(entry.value);
          if (value != null) {
            return value;
          }
        }
      }
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      final String trimmed = value.trim();
      final int? directInt = int.tryParse(trimmed);
      if (directInt != null) {
        return directInt;
      }
      final double? directDouble = double.tryParse(trimmed);
      if (directDouble != null) {
        return directDouble.round();
      }
      final RegExpMatch? match =
          RegExp(r'(\d+(?:\.\d+)?)').firstMatch(trimmed);
      if (match != null) {
        final double? parsed = double.tryParse(match.group(1) ?? '');
        if (parsed != null) {
          return parsed.round();
        }
      }
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final String trimmed = value.trim();
      final double? directDouble = double.tryParse(trimmed);
      if (directDouble != null) {
        return directDouble;
      }
      final RegExpMatch? match =
          RegExp(r'(\d+(?:\.\d+)?)').firstMatch(trimmed);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '');
      }
    }
    return null;
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
