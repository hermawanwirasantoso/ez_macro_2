import 'package:ez_macro_2/features/calorie_tracker/data/chained_calorie_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/calorie_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/nutrition_label_image.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChainedCalorieParser', () {
    test('returns the first successful text parse and skips later parsers',
        () async {
      final _RecordingParser primary = _RecordingParser(
        result: const ParseResult(
          mealLabel: 'Gemini Meal',
          calories: 400,
          confidence: 0.9,
        ),
      );
      final _RecordingParser backup = _RecordingParser(
        result: const ParseResult(
          mealLabel: 'DeepSeek Meal',
          calories: 410,
          confidence: 0.8,
        ),
      );

      final parser = ChainedCalorieParser(<CalorieParser>[primary, backup]);
      final ParseResult? result = await parser.parse('chicken');

      expect(result?.mealLabel, 'Gemini Meal');
      expect(primary.parseCalls, 1);
      expect(backup.parseCalls, 0);
    });

    test('falls back to the next parser when the primary returns null',
        () async {
      final _RecordingParser primary = _RecordingParser();
      final _RecordingParser backup = _RecordingParser(
        result: const ParseResult(
          mealLabel: 'DeepSeek Meal',
          calories: 410,
          confidence: 0.8,
        ),
      );

      final parser = ChainedCalorieParser(<CalorieParser>[primary, backup]);
      final ParseResult? result = await parser.parse('chicken');

      expect(result?.mealLabel, 'DeepSeek Meal');
      expect(result?.calories, 410);
      expect(primary.parseCalls, 1);
      expect(backup.parseCalls, 1);
    });

    test('returns null when every parser fails', () async {
      final parser = ChainedCalorieParser(<CalorieParser>[
        _RecordingParser(),
        _RecordingParser(),
      ]);

      expect(await parser.parse('unknown food'), isNull);
    });

    test('falls back for nutrition label photos', () async {
      final _RecordingParser primary = _RecordingParser();
      final _RecordingParser backup = _RecordingParser(
        labelResult: const ParseResult(
          mealLabel: 'Backup Yogurt',
          calories: 100,
          confidence: 0.9,
        ),
      );

      final parser = ChainedCalorieParser(<CalorieParser>[primary, backup]);
      final ParseResult? result = await parser.parseNutritionLabel(
        const NutritionLabelImage(bytes: <int>[1, 2, 3]),
        hint: 'Fage',
      );

      expect(result?.mealLabel, 'Backup Yogurt');
      expect(primary.labelCalls, 1);
      expect(backup.labelCalls, 1);
    });
  });
}

class _RecordingParser implements CalorieParser {
  _RecordingParser({this.result, this.labelResult});

  final ParseResult? result;
  final ParseResult? labelResult;
  int parseCalls = 0;
  int labelCalls = 0;

  @override
  Future<ParseResult?> parse(String input) async {
    parseCalls += 1;
    return result;
  }

  @override
  Future<ParseResult?> parseNutritionLabel(
    NutritionLabelImage image, {
    String? hint,
  }) async {
    labelCalls += 1;
    return labelResult;
  }
}
