import 'dart:convert';

import 'package:ez_macro_2/features/calorie_tracker/data/qwencloud_calorie_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/nutrition_label_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('QwenCloudCalorieParser', () {
    test('posts OpenAI-compatible chat completions to DashScope intl', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer test-qwen-key');
        expect(request.headers['Content-Type'], 'application/json');

        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'deepseek-v4.1-flash');
        expect(body['enable_thinking'], isFalse);
        expect(body['temperature'], 0);
        expect(
          (body['response_format'] as Map)['type'],
          'json_object',
        );

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': jsonEncode({
                    'mealLabel': 'Grilled Salmon Salad',
                    'calories': 420,
                    'proteinG': 38,
                    'carbsG': 12,
                    'fatG': 22,
                    'confidence': 0.95,
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final parser = QwenCloudCalorieParser(
        apiKey: 'test-qwen-key',
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
      final rawJson = jsonEncode({
        'mealLabel': 'Oatmeal with blueberries',
        'calories': 250,
        'proteinG': 8,
        'carbsG': 45,
        'fatG': 4,
        'confidence': 0.88,
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '```json\n$rawJson\n```',
                },
              },
            ],
          }),
          200,
        );
      });

      final parser = QwenCloudCalorieParser(
        apiKey: 'test-qwen-key',
        client: mockClient,
      );

      final result = await parser.parse('oatmeal with blueberries');
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Oatmeal with blueberries');
      expect(result.calories, 250);
    });

    test('returns null on HTTP 401 / 403 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('invalid api-key', 401);
      });

      final parser = QwenCloudCalorieParser(
        apiKey: 'invalid-key',
        client: mockClient,
      );

      final result = await parser.parse('burger');
      expect(result, isNull);
    });

    test('returns null on empty input', () async {
      final parser = QwenCloudCalorieParser(apiKey: 'key');
      final result = await parser.parse('   ');
      expect(result, isNull);
    });

    test('parses a nutrition facts photo with image_url content', () async {
      Map<String, dynamic>? requestBody;

      final mockClient = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, contains('/chat/completions'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'mealLabel': 'Greek Yogurt (170g)',
                    'calories': 100,
                    'proteinG': 17,
                    'carbsG': 6,
                    'fatG': 0,
                    'confidence': 0.97,
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final parser = QwenCloudCalorieParser(
        apiKey: 'test-qwen-key',
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

      expect(requestBody, isNotNull);
      final List<dynamic> messages = requestBody!['messages'] as List<dynamic>;
      final Map<String, dynamic> userMessage =
          messages.last as Map<String, dynamic>;
      final List<dynamic> content = userMessage['content'] as List<dynamic>;
      expect(
        content.any((dynamic part) {
          if (part is! Map<String, dynamic>) {
            return false;
          }
          return part['type'] == 'image_url';
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

      final parser = QwenCloudCalorieParser(
        apiKey: 'test-qwen-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(bytes: <int>[]),
      );

      expect(result, isNull);
      expect(requestCount, 0);
    });
  });
}
