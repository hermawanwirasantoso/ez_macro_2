import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/parse_result.dart';

class CalorieParsePrompts {
  static const String textSystemInstruction =
      'Extract meal label, portion size, portion unit, calories, macronutrients, and complete nutrition details (saturated fat, fiber, added sugar, sodium) from user text. If input includes portion or weight (e.g. "200g chicken breast", "1.5 cup rice", "2 eggs"), extract the portion size (number) and unit (string, e.g. "g", "cup", "piece", "oz", "serving"), and infer calories and nutrition for that portion. Return JSON only: {"mealLabel":"string","portionSize":number,"portionUnit":"string","calories":number,"proteinG":number,"carbsG":number,"fatG":number,"saturatedFatG":number,"fiberG":number,"addedSugarG":number,"sodiumMg":number,"confidence":0..1}. Default portionSize to 1 and portionUnit to "serving" if not specified.';

  static const String labelSystemInstruction =
      'Read the nutrition facts label in the image. Extract the product or food name, serving/portion size (number), portion unit (e.g. "g", "ml", "pieces", "oz", "cup", "serving"), calories, protein, carbs, fat, saturated fat, dietary fiber, added sugar, and sodium for one serving shown on the label. Return JSON only: {"mealLabel":"string","portionSize":number,"portionUnit":"string","calories":number,"proteinG":number,"carbsG":number,"fatG":number,"saturatedFatG":number,"fiberG":number,"addedSugarG":number,"sodiumMg":number,"confidence":0..1}. Default portionSize to 1 and portionUnit to "serving" if not specified.';

  static const String labelUserPrompt =
      'Extract nutrition facts for one serving from this label photo.';
}

class CalorieJsonParser {
  const CalorieJsonParser();

  static ParseResult? fromModelText(String input) {
    final Map<String, dynamic>? extracted = extractMap(input);
    if (extracted == null) {
      return null;
    }
    return toParseResult(extracted);
  }

  static Map<String, dynamic>? extractMap(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(trimmed);
      final Map<String, dynamic>? map = _findRelevantMap(decoded);
      if (map != null) {
        return map;
      }
    } catch (_) {}

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

  static ParseResult? toParseResult(Map<String, dynamic> extracted) {
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
      _debugLog('Calorie JSON missing calories field: $extracted');
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

    final double portionSize = (_toDoubleByKeys(extracted, <String>[
              'portionSize',
              'portion_size',
              'servingSize',
              'serving_size',
              'amount',
              'quantity',
              'portion',
              'serving',
              'serving_size_g',
              'servingSizeG',
            ]) ??
            1.0)
        .clamp(0.01, 99999.0);

    final String rawPortionUnit = (_toStringByKeys(extracted, <String>[
              'portionUnit',
              'portion_unit',
              'servingUnit',
              'serving_unit',
              'unit',
              'serving_size_unit',
              'portion_size_unit',
              'units',
              'serving_unit_name',
            ]) ??
            'serving')
        .trim();
    final String portionUnit =
        rawPortionUnit.isEmpty ? 'serving' : rawPortionUnit;

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
      portionSize: portionSize,
      portionUnit: portionUnit,
    );
  }

  static Map<String, dynamic>? _findRelevantMap(dynamic decoded) {
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

      return null;
    }

    if (decoded is List) {
      for (final dynamic item in decoded) {
        final Map<String, dynamic>? candidate = _findRelevantMap(item);
        if (candidate != null && _hasCalorieKey(candidate)) {
          return candidate;
        }
      }
    }

    return null;
  }

  static bool _hasCalorieKey(Map<String, dynamic> map) {
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
    for (final MapEntry<String, dynamic> entry in map.entries) {
      final String normalized =
          entry.key.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      if (calorieKeys.contains(normalized)) {
        if (entry.value != null && _toInt(entry.value) != null) {
          return true;
        }
      }
    }
    return false;
  }

  static String? _toStringByKeys(Map<String, dynamic> map, List<String> keys) {
    for (final String key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        final String? val = _toStringValue(map[key]);
        if (val != null) {
          return val;
        }
      }
      final String lowerKey = key.toLowerCase();
      for (final MapEntry<String, dynamic> entry in map.entries) {
        if (entry.key.toLowerCase() == lowerKey && entry.value != null) {
          final String? val = _toStringValue(entry.value);
          if (val != null) {
            return val;
          }
        }
      }
    }
    return null;
  }

  static String? _toStringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    }
    if (value is Map) {
      for (final String key in const <String>[
        'name',
        'unit',
        'label',
        'value',
        'text',
        'title',
      ]) {
        for (final MapEntry<dynamic, dynamic> entry in value.entries) {
          if (entry.key.toString().toLowerCase() == key && entry.value != null) {
            final String? res = _toStringValue(entry.value);
            if (res != null) {
              return res;
            }
          }
        }
      }
    }
    final String val = value.toString().trim();
    return val.isNotEmpty ? val : null;
  }

  static int? _toIntByKeys(Map<String, dynamic> map, List<String> keys) {
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

  static double? _toDoubleByKeys(Map<String, dynamic> map, List<String> keys) {
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

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is Map) {
      for (final String key in const <String>[
        'value',
        'amount',
        'val',
        'total',
        'quantity',
        'count',
        'number',
        'qty',
      ]) {
        for (final MapEntry<dynamic, dynamic> entry in value.entries) {
          if (entry.key.toString().toLowerCase() == key && entry.value != null) {
            final int? parsed = _toInt(entry.value);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      }
      for (final dynamic v in value.values) {
        final int? parsed = _toInt(v);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
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

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is Map) {
      for (final String key in const <String>[
        'value',
        'amount',
        'val',
        'total',
        'quantity',
        'count',
        'number',
        'qty',
      ]) {
        for (final MapEntry<dynamic, dynamic> entry in value.entries) {
          if (entry.key.toString().toLowerCase() == key && entry.value != null) {
            final double? parsed = _toDouble(entry.value);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      }
      for (final dynamic v in value.values) {
        final double? parsed = _toDouble(v);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
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

  static ({int protein, int carbs, int fat}) _estimateMacrosForCalories(
    int calories,
  ) {
    final int protein = (calories * 0.30 / 4).round();
    final int carbs = (calories * 0.40 / 4).round();
    final int fat = (calories * 0.30 / 9).round();
    return (protein: protein, carbs: carbs, fat: fat);
  }

  static void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}
