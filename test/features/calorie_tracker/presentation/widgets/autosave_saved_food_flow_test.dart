import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/calorie_parser.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/nutrition_label_image.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/parse_result.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/main.dart';

class CountingMockCalorieParser implements CalorieParser {
  CountingMockCalorieParser({
    required this.onParse,
  });

  final Future<ParseResult?> Function(String input) onParse;
  int parseCallCount = 0;

  @override
  Future<ParseResult?> parse(String input) async {
    parseCallCount++;
    return onParse(input);
  }

  @override
  Future<ParseResult?> parseNutritionLabel(
    NutritionLabelImage image, {
    String? hint,
  }) async {
    return null;
  }
}

Future<void> _scrollToInput(WidgetTester tester) async {
  final Finder inputFinder = find.byKey(const Key('nlInputField'));
  if (tester.any(inputFinder)) {
    await tester.ensureVisible(inputFinder);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(
    inputFinder,
    50,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(inputFinder);
  await tester.pumpAndSettle();
}

Future<void> _scrollToTop(WidgetTester tester) async {
  final Finder heroFinder = find.byKey(const Key('caloriesConsumedText'));
  if (tester.any(heroFinder)) {
    await tester.ensureVisible(heroFinder);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(
    heroFinder,
    -50,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(heroFinder);
  await tester.pumpAndSettle();
}

void main() {
  group('Autosave high-confidence items and bypass LLM on future logs', () {
    testWidgets(
      'Autosaves 90%+ confident item so future logs of the item bypass LLM',
      (WidgetTester tester) async {
        final CalorieStorage storage = CalorieStorage.inMemory();
        final CountingMockCalorieParser mockParser = CountingMockCalorieParser(
          onParse: (String input) async {
            if (input.toLowerCase().contains('salmon')) {
              return const ParseResult(
                mealLabel: 'Grilled Salmon',
                calories: 350,
                confidence: 0.95, // >= 90%
                proteinG: 34,
                carbsG: 0,
                fatG: 22,
                saturatedFatG: 4,
                fiberG: 0,
                addedSugarG: 0,
                sodiumMg: 120,
                portionSize: 150,
                portionUnit: 'g',
              );
            }
            return null;
          },
        );

        await tester.pumpWidget(
          MacroTrackerApp(
            calorieStorage: storage,
            calorieParser: mockParser,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial log of "salmon" with 95% confidence
        await _scrollToInput(tester);
        await tester.enterText(find.byKey(const Key('nlInputField')), 'salmon');
        await tester.tap(find.byKey(const Key('parseMealButton')).first);
        await tester.pumpAndSettle();

        // Verify LLM mock was called once
        expect(mockParser.parseCallCount, 1);
        await _scrollToTop(tester);
        expect(find.text('350 / 2200 kcal'), findsOneWidget);

        final Finder parseResultFinder = find.byKey(const Key('parseResultText'));
        await tester.scrollUntilVisible(
          parseResultFinder,
          50,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('Grilled Salmon'), findsWidgets);
        expect(find.textContaining('350 kcal'), findsWidgets);

        // Verify food was automatically saved into storage
        final List<SavedFood> savedFoods = await storage.loadSavedFoods();
        expect(savedFoods, hasLength(1));
        expect(savedFoods.first.name, 'Grilled Salmon');
        expect(savedFoods.first.calories, 350);
        expect(savedFoods.first.portionSize, 150.0);
        expect(savedFoods.first.portionUnit, 'g');

        // 2. Second log of the same food with portion scaling: "300g grilled salmon" (2x portion)
        await _scrollToInput(tester);
        await tester.enterText(
          find.byKey(const Key('nlInputField')),
          '300g grilled salmon',
        );
        await tester.tap(find.byKey(const Key('parseMealButton')).first);
        await tester.pumpAndSettle();

        // CRITICAL VERIFICATION: LLM was NOT called again! parseCallCount is still 1!
        expect(mockParser.parseCallCount, 1);

        // Verify total calories increased by 700 (350 + 700 = 1050 kcal)
        await _scrollToTop(tester);
        expect(find.text('1050 / 2200 kcal'), findsOneWidget);

        await tester.scrollUntilVisible(
          parseResultFinder,
          50,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('700 kcal'), findsWidgets);
      },
    );

    testWidgets(
      'Does NOT autosave items with confidence below 90%',
      (WidgetTester tester) async {
        final CalorieStorage storage = CalorieStorage.inMemory();
        final CountingMockCalorieParser mockParser = CountingMockCalorieParser(
          onParse: (String input) async {
            return const ParseResult(
              mealLabel: 'Mystery Stew',
              calories: 400,
              confidence: 0.70, // < 90%
              proteinG: 20,
              carbsG: 30,
              fatG: 15,
              portionSize: 1,
              portionUnit: 'serving',
            );
          },
        );

        await tester.pumpWidget(
          MacroTrackerApp(
            calorieStorage: storage,
            calorieParser: mockParser,
          ),
        );
        await tester.pumpAndSettle();

        await _scrollToInput(tester);
        await tester.enterText(
          find.byKey(const Key('nlInputField')),
          'mystery stew',
        );
        await tester.tap(find.byKey(const Key('parseMealButton')).first);
        await tester.pumpAndSettle();

        expect(mockParser.parseCallCount, 1);

        // Verify it was NOT autosaved
        final List<SavedFood> savedFoods = await storage.loadSavedFoods();
        expect(savedFoods, isEmpty);

        // Logging again calls mock parser again because it was not saved
        await _scrollToInput(tester);
        await tester.enterText(
          find.byKey(const Key('nlInputField')),
          'mystery stew',
        );
        await tester.tap(find.byKey(const Key('parseMealButton')).first);
        await tester.pumpAndSettle();

        expect(mockParser.parseCallCount, 2);
      },
    );
  });
}
