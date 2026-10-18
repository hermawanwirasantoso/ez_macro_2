import 'dart:convert';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_json_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalorieJsonParser', () {
    test('parses simple valid JSON correctly', () {
      final String jsonStr = jsonEncode(<String, dynamic>{
        'mealLabel': 'Chicken Salad',
        'calories': 350,
        'proteinG': 30,
        'carbsG': 10,
        'fatG': 12,
        'portionSize': 1.5,
        'portionUnit': 'bowl',
        'confidence': 0.9,
      });

      final ParseResult? result = CalorieJsonParser.fromModelText(jsonStr);
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Chicken Salad');
      expect(result.calories, 350);
      expect(result.proteinG, 30);
      expect(result.carbsG, 10);
      expect(result.fatG, 12);
      expect(result.portionSize, 1.5);
      expect(result.portionUnit, 'bowl');
      expect(result.confidence, 0.9);
    });

    test('extracts numbers from nested value/unit maps', () {
      final String jsonStr = jsonEncode(<String, dynamic>{
        'mealLabel': 'Sirloin Steak',
        'calories': <String, dynamic>{'value': 450, 'unit': 'kcal'},
        'proteinG': <String, dynamic>{'amount': 50.4, 'unit': 'g'},
        'carbsG': <String, dynamic>{'val': 0, 'unit': 'g'},
        'fatG': <String, dynamic>{'quantity': 22, 'unit': 'g'},
        'saturatedFatG': <String, dynamic>{'total': 9.2},
        'fiberG': <String, dynamic>{'number': 0},
        'addedSugarG': <String, dynamic>{'qty': 0},
        'sodiumMg': <String, dynamic>{'value': 320, 'unit': 'mg'},
        'portionSize': <String, dynamic>{'amount': 250},
        'portionUnit': <String, dynamic>{'name': 'grams'},
      });

      final ParseResult? result = CalorieJsonParser.fromModelText(jsonStr);
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Sirloin Steak');
      expect(result.calories, 450);
      expect(result.proteinG, 50);
      expect(result.carbsG, 0);
      expect(result.fatG, 22);
      expect(result.saturatedFatG, 9);
      expect(result.fiberG, 0);
      expect(result.addedSugarG, 0);
      expect(result.sodiumMg, 320);
      expect(result.portionSize, 250.0);
      expect(result.portionUnit, 'grams');
    });

    test('skips intermediate non-calorie JSON objects and finds actual calorie map', () {
      const String modelOutput = '''
I will think about this query.
Here is intermediate scratchpad data:
{"step": 1, "thought": "user entered 2 eggs", "food_candidates": ["egg_boiled", "egg_fried"]}
{"calculation": {"egg_weight_g": 50, "count": 2}}

Now the final answer:
{
  "mealLabel": "2 Boiled Eggs",
  "calories": 140,
  "proteinG": 12,
  "carbsG": 1,
  "fatG": 10,
  "portionSize": 2,
  "portionUnit": "pieces",
  "confidence": 0.95
}
''';

      final ParseResult? result = CalorieJsonParser.fromModelText(modelOutput);
      expect(result, isNotNull);
      expect(result!.mealLabel, '2 Boiled Eggs');
      expect(result.calories, 140);
      expect(result.proteinG, 12);
      expect(result.carbsG, 1);
      expect(result.fatG, 10);
      expect(result.portionSize, 2.0);
      expect(result.portionUnit, 'pieces');
    });

    test('extracts calorie JSON enclosed in markdown code fences despite surrounding reasoning', () {
      const String modelOutput = '''
Thought:
The user wants information for an apple.
Intermediate schema:
{"type": "lookup", "target": "apple"}

```json
{
  "mealLabel": "Medium Apple",
  "calories": 95,
  "proteinG": 0.5,
  "carbsG": 25,
  "fatG": 0.3,
  "portionSize": 1,
  "portionUnit": "medium"
}
```
Done calculating!
''';

      final ParseResult? result = CalorieJsonParser.fromModelText(modelOutput);
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Medium Apple');
      expect(result.calories, 95);
      expect(result.carbsG, 25);
    });

    test('returns null when JSON object does not contain parseable calorie field', () {
      final String jsonStr = jsonEncode(<String, dynamic>{
        'mealLabel': 'Random Non-Food Object',
        'notes': 'Nothing here',
      });

      expect(CalorieJsonParser.fromModelText(jsonStr), isNull);
    });

    test('returns null when calories is null or non-numeric', () {
      final String jsonStr = jsonEncode(<String, dynamic>{
        'mealLabel': 'Empty Calories Item',
        'calories': null,
      });

      expect(CalorieJsonParser.fromModelText(jsonStr), isNull);

      final String nonNumeric = jsonEncode(<String, dynamic>{
        'mealLabel': 'Invalid Item',
        'calories': 'not a number',
      });

      expect(CalorieJsonParser.fromModelText(nonNumeric), isNull);
    });

    test('extracts calorie map when nested inside foods array', () {
      final String jsonStr = jsonEncode(<String, dynamic>{
        'foods': <Map<String, dynamic>>[
          <String, dynamic>{
            'mealLabel': 'Banana',
            'calories': 105,
            'proteinG': 1.3,
            'carbsG': 27,
            'fatG': 0.3,
          },
        ],
      });

      final ParseResult? result = CalorieJsonParser.fromModelText(jsonStr);
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Banana');
      expect(result.calories, 105);
      expect(result.carbsG, 27);
    });

    test('extracts calorie map when nested inside nutrition property', () {
      final String jsonStr = jsonEncode(<String, dynamic>{
        'foodName': 'Avocado Toast',
        'nutrition': <String, dynamic>{
          'calories': 280,
          'protein': 7,
          'carbs': 24,
          'fat': 18,
        },
      });

      final ParseResult? result = CalorieJsonParser.fromModelText(jsonStr);
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Avocado Toast');
      expect(result.calories, 280);
      expect(result.fatG, 18);
    });
  });
}
