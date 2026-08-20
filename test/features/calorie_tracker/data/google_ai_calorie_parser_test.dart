import 'dart:convert';

import 'package:ez_macro_2/features/calorie_tracker/data/google_ai_calorie_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/nutrition_label_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GoogleAiCalorieParser', () {
    test('parses response correctly with valid Google AI Studio JSON', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['x-goog-api-key'], 'test-api-key');
        expect(request.url.queryParameters['key'], 'test-api-key');
        expect(
          request.url.path,
          contains('/models/gemini-2.5-flash:generateContent'),
        );

        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'mealLabel': 'Grilled Salmon Salad',
                      'calories': 420,
                      'proteinG': 38,
                      'carbsG': 12,
                      'fatG': 22,
                      'confidence': 0.95,
                    }),
                  },
                ],
                'role': 'model',
              },
              'finishReason': 'STOP',
            },
          ],
        };
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        model: 'gemini-2.5-flash',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        client: mockClient,
      );

      final result = await parser.parse('salmon salad');
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Grilled Salmon Salad');
      expect(result.calories, 420);
      expect(result.proteinG, 38);
      expect(result.carbsG, 12);
      expect(result.fatG, 22);
      expect(result.confidence, 0.95);
    });

    test('handles JSON enclosed in markdown code fences', () async {
      final mockClient = MockClient((request) async {
        final rawJson = jsonEncode({
          'mealLabel': 'Oatmeal with blueberries',
          'calories': 250,
          'proteinG': 8,
          'carbsG': 45,
          'fatG': 4,
          'confidence': 0.88,
        });

        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': '```json\n$rawJson\n```',
                  },
                ],
                'role': 'model',
              },
            },
          ],
        };
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parse('oatmeal with blueberries');
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Oatmeal with blueberries');
      expect(result.calories, 250);
      expect(result.proteinG, 8);
      expect(result.carbsG, 45);
      expect(result.fatG, 4);
    });

    test('estimates macros if missing from response', () async {
      final mockClient = MockClient((request) async {
        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'mealLabel': 'Snack Bar',
                      'calories': 200,
                    }),
                  },
                ],
              },
            },
          ],
        };
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parse('snack bar');
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Snack Bar');
      expect(result.calories, 200);
      expect(result.proteinG, 15); // (200 * 0.30 / 4)
      expect(result.carbsG, 20); // (200 * 0.40 / 4)
      expect(result.fatG, 7); // (200 * 0.30 / 9)
    });

    test('returns null on HTTP 401 / 403 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('API_KEY_INVALID', 401);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'invalid-key',
        client: mockClient,
      );

      final result = await parser.parse('burger');
      expect(result, isNull);
    });

    test('returns null on empty input', () async {
      final parser = GoogleAiCalorieParser(apiKey: 'key');
      final result = await parser.parse('   ');
      expect(result, isNull);
    });

    test('parses a nutrition facts photo through the same generateContent call', () async {
      Map<String, dynamic>? requestBody;

      final mockClient = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, contains(':generateContent'));

        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'mealLabel': 'Greek Yogurt (170g)',
                      'calories': 100,
                      'proteinG': 17,
                      'carbsG': 6,
                      'fatG': 0,
                      'confidence': 0.97,
                    }),
                  },
                ],
                'role': 'model',
              },
            },
          ],
        };
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3, 4],
          mimeType: 'image/jpeg',
        ),
        hint: 'Fage 0%',
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Greek Yogurt (170g)');
      expect(result.calories, 100);
      expect(result.proteinG, 17);
      expect(result.carbsG, 6);
      expect(result.fatG, 0);
      expect(result.confidence, 0.97);

      expect(requestBody, isNotNull);
      final List<dynamic> contents = requestBody!['contents'] as List<dynamic>;
      final Map<String, dynamic> userContent =
          contents.first as Map<String, dynamic>;
      final List<dynamic> parts = userContent['parts'] as List<dynamic>;
      expect(
        parts.any((dynamic part) {
          if (part is! Map<String, dynamic>) {
            return false;
          }
          final dynamic inlineData = part['inline_data'] ?? part['inlineData'];
          return inlineData is Map<String, dynamic>;
        }),
        isTrue,
      );
    });

    test('returns null for an empty nutrition label photo', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount += 1;
        return http.Response('should not be called', 500);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(bytes: <int>[]),
      );

      expect(result, isNull);
      expect(requestCount, 0);
    });

    test('returns null when calories is missing or invalid', () async {
      final mockClient = MockClient((request) async {
        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'mealLabel': 'Unknown Item',
                    }),
                  },
                ],
              },
            },
          ],
        };
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parse('something');
      expect(result, isNull);
    });

    test('parses exact Gemini response with thoughtSignature and usage metadata from issue report', () async {
      const rawResponse = '''{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\\n  \\"mealLabel\\": \\"Protein Powder\\",\\n  \\"calories\\": 180,\\n  \\"proteinG\\": 22,\\n  \\"carbsG\\": 20,\\n  \\"fatG\\": 2,\\n  \\"confidence\\": 0.95\\n}",
            "thoughtSignature": "El4KXAERTTIPSud1YusXFJaCE92r5AJJNQBT9WWYqrmgs9USE+EggBuv96yyHfoWPaOiAQGAA213r3Ezn4+UexcIRxq8I83aFMaQGEvtOcBG0L0ctXkH0U+Ohl/VvVlx"
          }
        ],
        "role": "model"
      },
      "finishReason": "STOP"
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 1176,
    "candidatesTokenCount": 63,
    "totalTokenCount": 1239,
    "promptTokensDetails": [
      {
        "modality": "TEXT",
        "tokenCount": 112
      },
      {
        "modality": "IMAGE",
        "tokenCount": 1064
      }
    ]
  },
  "turnToken": "v1_ChdZMWVFYXQtMEpxRFNnOFVQMHQyXzhRTRIXWTFlRWF0LTBKcURTZzhVUDB0Ml84UU0"
}''';

      final mockClient = MockClient((request) async {
        return http.Response(rawResponse, 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/jpeg',
        ),
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Protein Powder');
      expect(result.calories, 180);
      expect(result.proteinG, 22);
      expect(result.carbsG, 20);
      expect(result.fatG, 2);
      expect(result.confidence, 0.95);
    });

    test('handles multi-part response with thought part before answer part', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'thought': true,
                  'text': 'The nutrition label shows 1 scoop (30g) has {"calories": 180}. Calculating macros...',
                },
                {
                  'text': jsonEncode({
                    'mealLabel': 'Whey Protein Isolate',
                    'calories': 180,
                    'proteinG': 25,
                    'carbsG': 2,
                    'fatG': 1,
                    'confidence': 0.98,
                  }),
                  'thoughtSignature': 'sig123',
                },
              ],
              'role': 'model',
            },
            'finishReason': 'STOP',
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/png',
        ),
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Whey Protein Isolate');
      expect(result.calories, 180);
      expect(result.proteinG, 25);
      expect(result.carbsG, 2);
      expect(result.fatG, 1);
      expect(result.confidence, 0.98);
    });

    test('handles string values with units and alternative keys', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'product_name': 'Almond Milk',
                    'kcal': '60 kcal',
                    'protein': '1g',
                    'carbohydrate': '8.5 g',
                    'fat': '2.5g',
                  }),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/jpeg',
        ),
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Almond Milk');
      expect(result.calories, 60);
      expect(result.proteinG, 1);
      expect(result.carbsG, 9); // 8.5 rounded
      expect(result.fatG, 3); // 2.5 rounded
    });

    test('handles nested nutrition object', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'foodName': 'Protein Bar',
                    'nutrition': {
                      'calories': 210,
                      'protein': 20,
                      'carbs': 22,
                      'fat': 7,
                    },
                  }),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/jpeg',
        ),
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Protein Bar');
      expect(result.calories, 210);
      expect(result.proteinG, 20);
      expect(result.carbsG, 22);
      expect(result.fatG, 7);
    });

    test('handles JSON array in candidate text', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'mealLabel': 'Chia Pudding',
                      'calories': 150,
                      'proteinG': 5,
                      'carbsG': 15,
                      'fatG': 8,
                    }
                  ]),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/jpeg',
        ),
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Chia Pudding');
      expect(result.calories, 150);
      expect(result.proteinG, 5);
      expect(result.carbsG, 15);
      expect(result.fatG, 8);
    });

    test('extracts complete detailed nutrition info (saturated fat, fiber, added sugar, sodium)', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'mealLabel': 'Greek Yogurt with Granola',
                    'calories': 320,
                    'proteinG': 22,
                    'carbsG': 36,
                    'fatG': 8,
                    'saturatedFatG': 3,
                    'fiberG': 6,
                    'addedSugarG': 9,
                    'sodiumMg': 140,
                    'confidence': 0.94,
                  }),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parse('greek yogurt with granola');
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Greek Yogurt with Granola');
      expect(result.calories, 320);
      expect(result.proteinG, 22);
      expect(result.carbsG, 36);
      expect(result.fatG, 8);
      expect(result.saturatedFatG, 3);
      expect(result.fiberG, 6);
      expect(result.addedSugarG, 9);
      expect(result.sodiumMg, 140);
    });

    test('extracts complete detailed nutrition from label scan with alternate key names', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'product_name': 'Oat Crunch Cereal',
                    'calories': 210,
                    'protein_g': 5,
                    'total_carbohydrate': 44,
                    'total_fat': 3,
                    'saturated_fat': 1,
                    'dietary_fiber': 4,
                    'added_sugars': 12,
                    'sodium_mg': 190,
                  }),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/jpeg',
        ),
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Oat Crunch Cereal');
      expect(result.calories, 210);
      expect(result.proteinG, 5);
      expect(result.carbsG, 44);
      expect(result.fatG, 3);
      expect(result.saturatedFatG, 1);
      expect(result.fiberG, 4);
      expect(result.addedSugarG, 12);
      expect(result.sodiumMg, 190);
    });

    test('extracts portion size and portion unit from text JSON', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'mealLabel': 'Grilled Chicken Breast',
                    'calories': 330,
                    'proteinG': 62,
                    'carbsG': 0,
                    'fatG': 8,
                    'portionSize': 200,
                    'portionUnit': 'g',
                    'confidence': 0.95,
                  }),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parse('200g chicken breast');
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Grilled Chicken Breast');
      expect(result.calories, 330);
      expect(result.portionSize, 200.0);
      expect(result.portionUnit, 'g');
      expect(result.portionDisplay, '200 g');
    });

    test('extracts portion size and portion unit from label scan with alternate key names', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'mealLabel': 'Almond Milk',
                    'calories': 60,
                    'proteinG': 2,
                    'carbsG': 8,
                    'fatG': 3,
                    'serving_size': 240,
                    'serving_unit': 'ml',
                  }),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/jpeg',
        ),
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Almond Milk');
      expect(result.calories, 60);
      expect(result.portionSize, 240.0);
      expect(result.portionUnit, 'ml');
      expect(result.portionDisplay, '240 ml');
    });

    test('defaults portion size to 1.0 and unit to serving when omitted', () async {
      final responsePayload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'mealLabel': 'Apple',
                    'calories': 95,
                    'proteinG': 0,
                    'carbsG': 25,
                    'fatG': 0,
                  }),
                },
              ],
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final parser = GoogleAiCalorieParser(
        apiKey: 'test-api-key',
        client: mockClient,
      );

      final result = await parser.parse('apple');
      expect(result, isNotNull);
      expect(result!.portionSize, 1.0);
      expect(result.portionUnit, 'serving');
      expect(result.portionDisplay, '1 serving');
    });
  });
}
