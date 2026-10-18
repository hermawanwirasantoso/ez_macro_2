import 'dart:convert';

import 'package:ez_macro_2/features/calorie_tracker/data/claude_calorie_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/nutrition_label_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _messageResponse(
  Map<String, Object> result, {
  String stopReason = 'end_turn',
}) {
  return http.Response(
    jsonEncode({
      'id': 'msg_test',
      'type': 'message',
      'role': 'assistant',
      'model': 'claude-haiku-5-5',
      'stop_reason': stopReason,
      'content': [
        {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
        {'type': 'text', 'text': jsonEncode(result)},
      ],
    }),
    200,
  );
}

void main() {
  group('ClaudeCalorieParser', () {
    test('posts to the Messages API with the key only in x-api-key', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
        expect(request.url.toString(), isNot(contains('test-claude-key')));
        expect(request.headers['x-api-key'], 'sk-ant-test-claude-key');
        expect(request.headers['anthropic-version'], '2023-06-01');
        expect(request.headers.containsKey('anthropic-beta'), isFalse);
        expect(request.headers.containsKey('Authorization'), isFalse);

        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'claude-haiku-5-5');
        expect(body.containsKey('fallbacks'), isFalse);
        expect(body.containsKey('thinking'), isFalse);
        expect(body['system'], isA<String>());

        final Map<String, dynamic> outputConfig =
            body['output_config'] as Map<String, dynamic>;
        expect(outputConfig['effort'], 'medium');
        final Map<String, dynamic> format =
            outputConfig['format'] as Map<String, dynamic>;
        expect(format['type'], 'json_schema');
        expect(
          (format['schema'] as Map<String, dynamic>)['additionalProperties'],
          isFalse,
        );

        final List<dynamic> messages = body['messages'] as List<dynamic>;
        expect(messages, hasLength(1));
        expect(messages.first['role'], 'user');
        expect(messages.first['content'], 'salmon salad');

        return _messageResponse({
          'mealLabel': 'Grilled Salmon Salad',
          'portionSize': 1,
          'portionUnit': 'serving',
          'calories': 420,
          'proteinG': 38,
          'carbsG': 12,
          'fatG': 22,
          'saturatedFatG': 4,
          'fiberG': 5,
          'addedSugarG': 2,
          'sodiumMg': 480,
          'confidence': 0.95,
        });
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-test-claude-key',
        client: mockClient,
      );

      final result = await parser.parse('  salmon salad  ');
      expect(result, isNotNull);
      expect(result!.mealLabel, 'Grilled Salmon Salad');
      expect(result.calories, 420);
      expect(result.proteinG, 38);
      expect(result.carbsG, 12);
      expect(result.fatG, 22);
      expect(result.sodiumMg, 480);
      expect(result.confidence, 0.95);
    });

    test(
      'opts into server-side fallbacks when overridden to Opus 5.5',
      () async {
        final mockClient = MockClient((request) async {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'claude-opus-5-5');
          expect(body['fallbacks'], 'default');
          expect((body['output_config'] as Map)['effort'], 'low');
          expect(
            request.headers['anthropic-beta'],
            'server-side-fallback-2026-07-01',
          );
          return _messageResponse({'mealLabel': 'Apple', 'calories': 95});
        });

        final parser = ClaudeCalorieParser(
          apiKey: 'sk-ant-key',
          model: 'claude-opus-5-5',
          client: mockClient,
        );

        final result = await parser.parse('apple');
        expect(result?.calories, 95);
      },
    );

    test('defaults effort per model and honors an explicit effort', () {
      expect(ClaudeCalorieParser(apiKey: 'k').effort, 'medium');
      expect(
        ClaudeCalorieParser(apiKey: 'k', model: 'claude-sonnet-5-5').effort,
        'low',
      );
      expect(
        ClaudeCalorieParser(apiKey: 'k', model: 'claude-opus-5-5').effort,
        'low',
      );
      expect(ClaudeCalorieParser(apiKey: 'k', effort: 'high').effort, 'high');
    });

    test('uses a custom base URL', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://proxy.example.com/v1/messages');
        return _messageResponse({'mealLabel': 'Toast', 'calories': 80});
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-key',
        baseUrl: 'https://proxy.example.com/',
        client: mockClient,
      );

      expect((await parser.parse('toast'))?.calories, 80);
    });

    test('returns null when Claude declines the request', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'message',
            'stop_reason': 'refusal',
            'stop_details': {'type': 'refusal', 'category': null},
            'content': <Object>[],
          }),
          200,
        );
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-key',
        client: mockClient,
      );

      expect(await parser.parse('burger'), isNull);
    });

    test('returns null on HTTP 401 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'type': 'error',
            'error': {
              'type': 'authentication_error',
              'message': 'invalid x-api-key',
            },
          }),
          401,
        );
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-invalid',
        client: mockClient,
      );

      expect(await parser.parse('burger'), isNull);
    });

    test('returns null on network failure', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('offline');
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-key',
        client: mockClient,
      );

      expect(await parser.parse('burger'), isNull);
    });

    test('returns null on empty input without calling the API', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount += 1;
        return http.Response('should not be called', 500);
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-key',
        client: mockClient,
      );

      expect(await parser.parse('   '), isNull);
      expect(requestCount, 0);
    });

    test('sends a nutrition label photo as a base64 image block', () async {
      Map<String, dynamic>? requestBody;

      final mockClient = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _messageResponse({
          'mealLabel': 'Greek Yogurt (170g)',
          'portionSize': 170,
          'portionUnit': 'g',
          'calories': 100,
          'proteinG': 17,
          'carbsG': 6,
          'fatG': 0,
          'confidence': 0.97,
        });
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3, 4],
          mimeType: 'image/png',
        ),
        hint: 'Fage 0%',
      );

      expect(result, isNotNull);
      expect(result!.mealLabel, 'Greek Yogurt (170g)');
      expect(result.calories, 100);
      expect(result.portionSize, 170);
      expect(result.portionUnit, 'g');

      final List<dynamic> content =
          (requestBody!['messages'] as List<dynamic>).first['content']
              as List<dynamic>;
      final Map<String, dynamic> imageBlock =
          content.first as Map<String, dynamic>;
      expect(imageBlock['type'], 'image');
      expect(imageBlock['source'], {
        'type': 'base64',
        'media_type': 'image/png',
        'data': base64Encode(<int>[1, 2, 3, 4]),
      });
      final Map<String, dynamic> textBlock =
          content.last as Map<String, dynamic>;
      expect(textBlock['type'], 'text');
      expect(textBlock['text'], contains('Fage 0%'));
    });

    test('leaves HEIC label photos to the next parser', () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount += 1;
        return http.Response('should not be called', 500);
      });

      final parser = ClaudeCalorieParser(
        apiKey: 'sk-ant-key',
        client: mockClient,
      );

      final result = await parser.parseNutritionLabel(
        const NutritionLabelImage(
          bytes: <int>[1, 2, 3],
          mimeType: 'image/heic',
        ),
      );

      expect(result, isNull);
      expect(requestCount, 0);
    });
  });
}
