import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/main.dart';

Future<void> _scrollIntoView(WidgetTester tester, Finder finder, {double delta = 50}) async {
  if (tester.any(finder)) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollToInput(WidgetTester tester) async {
  await _scrollIntoView(tester, find.byKey(const Key('nlInputField')));
}

Future<void> _scrollToTop(WidgetTester tester) async {
  await _scrollIntoView(tester, find.byKey(const Key('caloriesConsumedText')), delta: -50);
}

void main() {
  group('Stored Food Autocomplete and Visual Feedback When Typing', () {
    testWidgets(
        'shows stored food suggestion chips when input is empty and filters suggestions when typing',
        (WidgetTester tester) async {
      final SavedFood salmon = SavedFood(
        id: 'food_salmon_1',
        name: 'Grilled Salmon',
        calories: 350,
        proteinG: 34,
        carbsG: 0,
        fatG: 22,
        portionSize: 150,
        portionUnit: 'g',
      );
      final SavedFood chicken = SavedFood(
        id: 'food_chicken_1',
        name: 'Chicken Breast',
        calories: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 4,
        portionSize: 100,
        portionUnit: 'g',
      );

      final CalorieStorage storage = CalorieStorage.inMemory(
        initialSavedFoods: <SavedFood>[salmon, chicken],
      );

      await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
      await tester.pumpAndSettle();
      await _scrollToInput(tester);

      // 1. When empty, stored food chip is visible
      expect(find.byKey(const Key('storedFoodChip_food_salmon_1')), findsOneWidget);
      expect(find.byKey(const Key('storedFoodChip_food_chicken_1')), findsOneWidget);

      // 2. When typing 'salm', only matching stored food suggestion is shown
      await tester.enterText(find.byKey(const Key('nlInputField')), 'salm');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('storedFoodSuggestionsList')), findsOneWidget);
      expect(find.byKey(const Key('storedFoodSuggestion_food_salmon_1')), findsOneWidget);
      expect(find.byKey(const Key('storedFoodBadge_food_salmon_1')), findsOneWidget);
      expect(find.textContaining('Stored Data • No API Call'), findsOneWidget);
      expect(find.byKey(const Key('storedFoodSuggestion_food_chicken_1')), findsNothing);

      // 3. Tap the stored food suggestion to open the portion pop up
      await tester.tap(find.byKey(const Key('storedFoodSuggestion_food_salmon_1')));
      await tester.pumpAndSettle();

      // Verify the portion pop up is displayed with food details and base portion
      expect(find.byKey(const Key('portionModalFoodTitle')), findsOneWidget);
      expect(find.text('Grilled Salmon'), findsWidgets);
      expect(find.byKey(const Key('portionModalCaloriesText')), findsOneWidget);
      expect(find.text('350'), findsWidgets);
      expect(find.byKey(const Key('confirmAddStoredFoodButton')), findsOneWidget);

      // 4. Tap 'Add to Log' to add it as it is (same portion)
      await tester.tap(find.byKey(const Key('confirmAddStoredFoodButton')));
      await tester.pumpAndSettle();

      // 5. Entry is logged directly from saved food without API calls
      await _scrollToTop(tester);
      expect(find.text('350 / 2200 kcal'), findsOneWidget);

      final Finder salmonEntry = find.textContaining('Grilled Salmon');
      await _scrollIntoView(tester, salmonEntry);
      expect(salmonEntry, findsWidgets);
    });

    testWidgets(
        'typing scaled portion of stored food displays live stored food match banner with scaled calories',
        (WidgetTester tester) async {
      final SavedFood chicken = SavedFood(
        id: 'food_chicken_2',
        name: 'Chicken Breast',
        calories: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 4,
        portionSize: 100,
        portionUnit: 'g',
      );

      final CalorieStorage storage = CalorieStorage.inMemory(
        initialSavedFoods: <SavedFood>[chicken],
      );

      await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
      await tester.pumpAndSettle();
      await _scrollToInput(tester);

      // Type scaled portion: 200g chicken breast (2x -> 330 kcal)
      await tester.enterText(find.byKey(const Key('nlInputField')), '200g chicken breast');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('storedFoodMatchBanner')), findsOneWidget);
      expect(find.textContaining('Using Stored Food: Chicken Breast'), findsOneWidget);
      expect(find.textContaining('330 kcal'), findsWidgets);
      expect(find.text('NO API'), findsOneWidget);

      final Finder parseBtn = find.byKey(const Key('parseMealButton'));
      await _scrollIntoView(tester, parseBtn);
      await tester.tap(parseBtn);
      await tester.pumpAndSettle();

      await _scrollToTop(tester);
      expect(find.text('330 / 2200 kcal'), findsOneWidget);
    });

    testWidgets(
        'typing in FoodEntryModal food name field displays stored food chip and autofills data on selection',
        (WidgetTester tester) async {
      final SavedFood oatmeal = SavedFood(
        id: 'food_oatmeal_1',
        name: 'Protein Oatmeal',
        calories: 280,
        proteinG: 22,
        carbsG: 38,
        fatG: 5,
        portionSize: 1.0,
        portionUnit: 'bowl',
      );

      final CalorieStorage storage = CalorieStorage.inMemory(
        initialSavedFoods: <SavedFood>[oatmeal],
      );

      await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
      await tester.pumpAndSettle();

      // Open manual entry modal
      final Finder quickAddBtn = find.byKey(const Key('openQuickAddButton'));
      await _scrollIntoView(tester, quickAddBtn);
      await tester.tap(quickAddBtn);
      await tester.pumpAndSettle();

      // Type partial name in mealLabelField
      await tester.enterText(find.byKey(const Key('mealLabelField')), 'oat');
      await tester.pumpAndSettle();

      final Finder chip = find.byKey(const Key('modalStoredFoodChip_food_oatmeal_1'));
      expect(chip, findsOneWidget);

      // Tap chip to fill stored food
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byKey(const Key('mealLabelField'))).controller?.text,
        'Protein Oatmeal',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '280',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '22',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('carbsField'))).controller?.text,
        '38',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '5',
      );
    });

    testWidgets(
        'tapping stored food chip shows pop up allowing user to edit portion multiplier before logging',
        (WidgetTester tester) async {
      final SavedFood chicken = SavedFood(
        id: 'food_chicken_3',
        name: 'Grilled Chicken',
        calories: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 4,
        portionSize: 100,
        portionUnit: 'g',
      );

      final CalorieStorage storage = CalorieStorage.inMemory(
        initialSavedFoods: <SavedFood>[chicken],
      );

      await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
      await tester.pumpAndSettle();
      await _scrollToInput(tester);

      // Tap stored food chip directly
      await tester.tap(find.byKey(const Key('storedFoodChip_food_chicken_3')));
      await tester.pumpAndSettle();

      // Verify portion pop up is visible
      expect(find.byKey(const Key('portionModalFoodTitle')), findsOneWidget);
      expect(find.text('Grilled Chicken'), findsWidgets);
      expect(find.text('165'), findsWidgets);

      // User selects 2x portion chip (100g -> 200g, 165 kcal -> 330 kcal)
      await tester.tap(find.byKey(const Key('portionModalChip_2')));
      await tester.pumpAndSettle();

      expect(find.text('330'), findsWidgets);
      expect(
        tester.widget<TextField>(find.byKey(const Key('portionModalQuantityField'))).controller?.text,
        '200',
      );

      // Tap Add button
      await tester.tap(find.byKey(const Key('confirmAddStoredFoodButton')));
      await tester.pumpAndSettle();

      // Verify 330 kcal logged to tracker
      await _scrollToTop(tester);
      expect(find.text('330 / 2200 kcal'), findsOneWidget);

      final Finder chickenEntry = find.textContaining('Grilled Chicken');
      await _scrollIntoView(tester, chickenEntry);
      expect(chickenEntry, findsWidgets);
    });

    testWidgets(
        'tapping adjust portion banner button shows pop up and allows editing portion size via steppers',
        (WidgetTester tester) async {
      final SavedFood rice = SavedFood(
        id: 'food_rice_1',
        name: 'Jasmine Rice',
        calories: 200,
        proteinG: 4,
        carbsG: 45,
        fatG: 1,
        portionSize: 1.0,
        portionUnit: 'cup',
      );

      final CalorieStorage storage = CalorieStorage.inMemory(
        initialSavedFoods: <SavedFood>[rice],
      );

      await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
      await tester.pumpAndSettle();
      await _scrollToInput(tester);

      // Type name to trigger direct match banner
      await tester.enterText(find.byKey(const Key('nlInputField')), 'Jasmine Rice');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('storedFoodMatchBanner')), findsOneWidget);

      // Tap adjust portion button on banner
      await tester.tap(find.byKey(const Key('adjustPortionBannerButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('portionModalFoodTitle')), findsOneWidget);

      // Increase portion via increment stepper button
      await tester.tap(find.byKey(const Key('portionModalIncrementButton')));
      await tester.pumpAndSettle();

      // 1.0 cup + 0.5 step = 1.5 cups (300 kcal)
      expect(find.text('300'), findsWidgets);

      // Log food
      await tester.tap(find.byKey(const Key('confirmAddStoredFoodButton')));
      await tester.pumpAndSettle();

      await _scrollToTop(tester);
      expect(find.text('300 / 2200 kcal'), findsOneWidget);
    });
  });
}
