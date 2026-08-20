import 'package:ez_macro_2/features/calorie_tracker/domain/calorie_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegexCalorieParser', () {
    const RegexCalorieParser parser = RegexCalorieParser();

    test('extracts gram portion from phrase (e.g. 200g chicken breast)', () async {
      final ParseResult? result = await parser.parse('200g chicken breast');
      expect(result, isNotNull);
      expect(result!.portionSize, 200.0);
      expect(result.portionUnit, 'g');
      expect(result.portionDisplay, '200 g');
      expect(result.calories, 330);
      expect(result.proteinG, 62);
    });

    test('extracts custom unit portions (e.g. 1.5 cup rice, 2 slices)', () async {
      final ParseResult? cupResult = await parser.parse('1.5 cup rice');
      expect(cupResult, isNotNull);
      expect(cupResult!.portionSize, 1.5);
      expect(cupResult.portionUnit, 'cup');
      expect(cupResult.portionDisplay, '1.5 cup');

      final ParseResult? sliceResult = await parser.parse('2 slices pizza 500 kcal');
      expect(sliceResult, isNotNull);
      expect(sliceResult!.portionSize, 2.0);
      expect(sliceResult.portionUnit, 'slice');
      expect(sliceResult.calories, 500);
    });

    test('defaults to serving when unit is omitted or word number is used', () async {
      final ParseResult? eggResult = await parser.parse('two eggs');
      expect(eggResult, isNotNull);
      expect(eggResult!.portionSize, 2.0);
      expect(eggResult.portionUnit, 'serving');
      expect(eggResult.calories, 156);
      expect(eggResult.proteinG, 12);

      final ParseResult? singleResult = await parser.parse('an egg');
      expect(singleResult, isNotNull);
      expect(singleResult!.portionSize, 1.0);
      expect(singleResult.portionUnit, 'serving');
    });

    test('returns null for empty input', () async {
      final ParseResult? result = await parser.parse('   ');
      expect(result, isNull);
    });
  });
}
