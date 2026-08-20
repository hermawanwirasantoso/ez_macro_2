import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/parse_result.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food_matcher.dart';

void main() {
  group('SavedFoodMatcher', () {
    final SavedFood chickenBreast = SavedFood(
      id: 'saved_chicken',
      name: 'Chicken Breast',
      calories: 165,
      proteinG: 31,
      carbsG: 0,
      fatG: 4,
      saturatedFatG: 1,
      fiberG: 0,
      addedSugarG: 0,
      sodiumMg: 70,
      portionSize: 100,
      portionUnit: 'g',
    );

    final SavedFood oatmeal = SavedFood(
      id: 'saved_oats',
      name: 'Oatmeal',
      calories: 150,
      proteinG: 5,
      carbsG: 27,
      fatG: 3,
      saturatedFatG: 1,
      fiberG: 4,
      addedSugarG: 1,
      sodiumMg: 2,
      portionSize: 1.0,
      portionUnit: 'cup',
    );

    final SavedFood egg = SavedFood(
      id: 'saved_egg',
      name: 'Egg',
      calories: 70,
      proteinG: 6,
      carbsG: 0,
      fatG: 5,
      saturatedFatG: 2,
      fiberG: 0,
      addedSugarG: 0,
      sodiumMg: 65,
      portionSize: 1.0,
      portionUnit: 'piece',
    );

    final SavedFood proteinShake = SavedFood(
      id: 'saved_shake',
      name: 'Whey Protein Shake',
      calories: 120,
      proteinG: 24,
      carbsG: 3,
      fatG: 2,
      saturatedFatG: 1,
      fiberG: 1,
      addedSugarG: 0,
      sodiumMg: 150,
      portionSize: 1.0,
      portionUnit: 'scoop',
    );

    final List<SavedFood> catalog = <SavedFood>[
      chickenBreast,
      oatmeal,
      egg,
      proteinShake,
    ];

    test('returns null when input is empty or saved foods list is empty', () {
      expect(SavedFoodMatcher.findMatch('', catalog), isNull);
      expect(SavedFoodMatcher.findMatch('   ', catalog), isNull);
      expect(SavedFoodMatcher.findMatch('chicken breast', <SavedFood>[]), isNull);
    });

    test('matches exact food name case-insensitively with 100% confidence', () {
      final ParseResult? match1 =
          SavedFoodMatcher.findMatch('Chicken Breast', catalog);
      expect(match1, isNotNull);
      expect(match1!.mealLabel, 'Chicken Breast');
      expect(match1.calories, 165);
      expect(match1.proteinG, 31);
      expect(match1.carbsG, 0);
      expect(match1.fatG, 4);
      expect(match1.saturatedFatG, 1);
      expect(match1.fiberG, 0);
      expect(match1.sodiumMg, 70);
      expect(match1.portionSize, 100.0);
      expect(match1.portionUnit, 'g');
      expect(match1.confidence, 1.0);

      final ParseResult? match2 =
          SavedFoodMatcher.findMatch('chicken breast', catalog);
      expect(match2, isNotNull);
      expect(match2!.calories, 165);
    });

    test('matches prefix portion with units and scales nutrition', () {
      // 200g of 100g base portion = 2x multiplier
      final ParseResult? match =
          SavedFoodMatcher.findMatch('200g chicken breast', catalog);
      expect(match, isNotNull);
      expect(match!.mealLabel, 'Chicken Breast');
      expect(match.calories, 330);
      expect(match.proteinG, 62);
      expect(match.carbsG, 0);
      expect(match.fatG, 8);
      expect(match.saturatedFatG, 2);
      expect(match.sodiumMg, 140);
      expect(match.portionSize, 200.0);
      expect(match.portionUnit, 'g');
      expect(match.confidence, 1.0);
    });

    test('matches prefix portion with words like "grams" or "of"', () {
      final ParseResult? match =
          SavedFoodMatcher.findMatch('200 grams of chicken breast', catalog);
      expect(match, isNotNull);
      expect(match!.calories, 330);
      expect(match.portionSize, 200.0);
      expect(match.portionUnit, 'g');
    });

    test('matches prefix cups and scales volume portions', () {
      // 1.5 cups of 1.0 cup base portion = 1.5x multiplier
      final ParseResult? match =
          SavedFoodMatcher.findMatch('1.5 cups oatmeal', catalog);
      expect(match, isNotNull);
      expect(match!.mealLabel, 'Oatmeal');
      expect(match.calories, 225); // 150 * 1.5
      expect(match.proteinG, 8); // 5 * 1.5
      expect(match.carbsG, 41); // 27 * 1.5
      expect(match.fiberG, 6); // 4 * 1.5
      expect(match.portionSize, 1.5);
      expect(match.portionUnit, 'cup');
    });

    test('matches fractional prefix portions like 1/2 cup', () {
      final ParseResult? match =
          SavedFoodMatcher.findMatch('1/2 cup oatmeal', catalog);
      expect(match, isNotNull);
      expect(match!.calories, 75);
      expect(match.portionSize, 0.5);
      expect(match.portionUnit, 'cup');
    });

    test('matches prefix count with plural and singular word forms', () {
      // 2 eggs from 1 piece egg = 2x multiplier
      final ParseResult? match1 =
          SavedFoodMatcher.findMatch('2 eggs', catalog);
      expect(match1, isNotNull);
      expect(match1!.mealLabel, 'Egg');
      expect(match1.calories, 140);
      expect(match1.proteinG, 12);
      expect(match1.fatG, 10);
      expect(match1.portionSize, 2.0);

      final ParseResult? match2 =
          SavedFoodMatcher.findMatch('1 egg', catalog);
      expect(match2, isNotNull);
      expect(match2!.calories, 70);
      expect(match2.portionSize, 1.0);
    });

    test('matches suffix portions with units or parentheses', () {
      final ParseResult? match1 =
          SavedFoodMatcher.findMatch('chicken breast 200g', catalog);
      expect(match1, isNotNull);
      expect(match1!.calories, 330);
      expect(match1.portionSize, 200.0);

      final ParseResult? match2 =
          SavedFoodMatcher.findMatch('chicken breast (200g)', catalog);
      expect(match2, isNotNull);
      expect(match2!.calories, 330);

      final ParseResult? match3 =
          SavedFoodMatcher.findMatch('chicken breast, 200g', catalog);
      expect(match3, isNotNull);
      expect(match3!.calories, 330);

      final ParseResult? match4 =
          SavedFoodMatcher.findMatch('chicken breast - 200g', catalog);
      expect(match4, isNotNull);
      expect(match4!.calories, 330);
    });

    test('matches suffix multipliers like "2x" or "x2"', () {
      final ParseResult? match1 =
          SavedFoodMatcher.findMatch('Whey Protein Shake 2x', catalog);
      expect(match1, isNotNull);
      expect(match1!.mealLabel, 'Whey Protein Shake');
      expect(match1.calories, 240);
      expect(match1.proteinG, 48);
      expect(match1.portionSize, 2.0);

      final ParseResult? match2 =
          SavedFoodMatcher.findMatch('Whey Protein Shake x2', catalog);
      expect(match2, isNotNull);
      expect(match2!.calories, 240);
    });

    test('prioritizes specific multi-word saved foods over generic single-word foods', () {
      final SavedFood genericChicken = SavedFood(
        id: 'generic_chicken',
        name: 'Chicken',
        calories: 200,
        portionSize: 100,
        portionUnit: 'g',
      );
      final List<SavedFood> extendedCatalog = <SavedFood>[
        genericChicken,
        chickenBreast,
      ];

      final ParseResult? match =
          SavedFoodMatcher.findMatch('200g Chicken Breast', extendedCatalog);
      expect(match, isNotNull);
      expect(match!.mealLabel, 'Chicken Breast');
      expect(match.calories, 330); // Uses chickenBreast (165*2), not genericChicken (200*2)
    });

    test('does NOT match food phrases with non-portion trailing words', () {
      // "chicken breast sandwich" is a different food, should NOT match "chicken breast"
      expect(
        SavedFoodMatcher.findMatch('chicken breast sandwich', catalog),
        isNull,
      );
      // "oatmeal with milk and honey" should NOT match "oatmeal"
      expect(
        SavedFoodMatcher.findMatch('oatmeal with milk and honey', catalog),
        isNull,
      );
    });
  });
}
