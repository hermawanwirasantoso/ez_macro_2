import 'dart:convert';

import 'package:ez_macro_2/features/calorie_tracker/data/google_ai_calorie_parser.dart';
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
  });
}
