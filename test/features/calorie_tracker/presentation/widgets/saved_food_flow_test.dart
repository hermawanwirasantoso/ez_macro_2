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
  testWidgets('user can save a custom food and reuse it from Quick Add',
      (WidgetTester tester) async {
    final CalorieStorage storage = CalorieStorage.inMemory();

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    final Finder quickAddBtn = find.byKey(const Key('openQuickAddButton'));
    await _scrollIntoView(tester, quickAddBtn);
    await tester.tap(quickAddBtn);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mealLabelField')),
      'Homemade Burrito',
    );
    await tester.enterText(find.byKey(const Key('caloriesField')), '540');
    await tester.enterText(find.byKey(const Key('proteinField')), '32');
    await tester.enterText(find.byKey(const Key('carbsField')), '58');
    await tester.enterText(find.byKey(const Key('fatField')), '18');
    await tester.ensureVisible(find.byKey(const Key('saveForFutureUseCheckbox')));
    await tester.tap(find.byKey(const Key('saveForFutureUseCheckbox')));
    await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
    await tester.tap(find.byKey(const Key('saveEntryButton')));
    await tester.pumpAndSettle();

    final List<SavedFood> savedFoods = await storage.loadSavedFoods();
    expect(savedFoods, hasLength(1));
    expect(savedFoods.single.name, 'Homemade Burrito');
    await _scrollToTop(tester);
    expect(find.text('540 / 2200 kcal'), findsOneWidget);

    await _scrollIntoView(tester, quickAddBtn);
    await tester.tap(quickAddBtn);
    await tester.pumpAndSettle();

    final Finder savedFoodTile = find.byKey(
      Key('savedFoodTile_${savedFoods.single.id}'),
    );
    expect(savedFoodTile, findsOneWidget);

    await tester.tap(savedFoodTile);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
      '540',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
      '32',
    );

    await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
    await tester.tap(find.byKey(const Key('saveEntryButton')));
    await tester.pumpAndSettle();

    await _scrollToTop(tester);
    expect(find.text('1080 / 2200 kcal'), findsOneWidget);

    final Finder savedEntryFinder = find.text('Homemade Burrito - 540 kcal Saved');
    await _scrollIntoView(tester, savedEntryFinder);
    expect(savedEntryFinder, findsOneWidget);
  });

  testWidgets('user can choose custom portion when logging a saved food',
      (WidgetTester tester) async {
    final SavedFood savedFood = SavedFood(
      id: 'saved_protein_bar',
      name: 'Protein Bar',
      calories: 200,
      proteinG: 20,
      carbsG: 15,
      fatG: 6,
      portionSize: 1.0,
      portionUnit: 'bar',
    );
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialSavedFoods: <SavedFood>[savedFood],
    );

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    final Finder quickAddBtn = find.byKey(const Key('openQuickAddButton'));
    await _scrollIntoView(tester, quickAddBtn);
    await tester.tap(quickAddBtn);
    await tester.pumpAndSettle();

    // Tap the saved food tile
    await tester.tap(find.byKey(const Key('savedFoodTile_saved_protein_bar')));
    await tester.pumpAndSettle();

    // Verify portion section rendered with base info
    expect(find.byKey(const Key('portionSelectorCard')), findsOneWidget);
    expect(find.text('Base: 1 bar'), findsOneWidget);

    // Choose 2x portion (400 kcal, 40P, 30C, 12F)
    await tester.tap(find.byKey(const Key('portionChip_2')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
      '400',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
      '40',
    );

    // Save/Log
    await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
    await tester.tap(find.byKey(const Key('saveEntryButton')));
    await tester.pumpAndSettle();

    // Check dashboard totals
    await _scrollToTop(tester);
    expect(find.text('400 / 2200 kcal'), findsOneWidget);
    expect(find.text('Protein  40/160 g'), findsOneWidget);
    expect(find.text('Carbs  30/255 g'), findsOneWidget);
    expect(find.text('Fat  12/60 g'), findsOneWidget);
  });

  testWidgets('user can remove a saved food from Quick Add',
      (WidgetTester tester) async {
    final SavedFood savedFood = SavedFood(
      id: 'saved_to_remove',
      name: 'Saved Salad',
      calories: 220,
      proteinG: 10,
      carbsG: 20,
      fatG: 8,
    );
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialSavedFoods: <SavedFood>[savedFood],
    );

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    final Finder quickAddBtn = find.byKey(const Key('openQuickAddButton'));
    await _scrollIntoView(tester, quickAddBtn);
    await tester.tap(quickAddBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteSavedFood_saved_to_remove')));
    await tester.pumpAndSettle();

    expect(await storage.loadSavedFoods(), isEmpty);
    expect(find.byKey(const Key('savedFoodTile_saved_to_remove')), findsNothing);
  });

  testWidgets('user can edit a logged entry, scale portion, and save as custom food',
      (WidgetTester tester) async {
    final CalorieStorage storage = CalorieStorage.inMemory();

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();
    await _scrollToInput(tester);

    // Enter natural language meal
    await tester.enterText(find.byKey(const Key('nlInputField')), '200g chicken breast');
    final Finder parseBtn = find.byKey(const Key('parseMealButton'));
    await _scrollIntoView(tester, parseBtn);
    await tester.tap(parseBtn);
    await tester.pumpAndSettle();

    await _scrollToTop(tester);
    expect(find.text('330 / 2200 kcal'), findsOneWidget);

    final Finder portion200g = find.text('200 g');
    await _scrollIntoView(tester, portion200g);
    expect(portion200g, findsOneWidget);

    // Edit the entry
    final Finder editBtn = find.byKey(const Key('editEntryButton_0'));
    await _scrollIntoView(tester, editBtn);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    expect(find.text('Edit Meal'), findsOneWidget);
    expect(find.byKey(const Key('portionSelectorCard')), findsOneWidget);
    expect(find.text('Base: 200 g'), findsOneWidget);

    // Scale to 1.5x portion (300g, 495 kcal, 93P, 12F)
    await tester.tap(find.byKey(const Key('portionChip_1.5')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
      '495',
    );

    // Check save for future use
    await tester.ensureVisible(find.byKey(const Key('saveForFutureUseCheckbox')));
    await tester.tap(find.byKey(const Key('saveForFutureUseCheckbox')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
    await tester.tap(find.byKey(const Key('saveEntryButton')));
    await tester.pumpAndSettle();

    // Check updated totals
    await _scrollToTop(tester);
    expect(find.text('495 / 2200 kcal'), findsOneWidget);

    final Finder portion300g = find.text('300 g');
    await _scrollIntoView(tester, portion300g);
    expect(portion300g, findsOneWidget);

    // Check that custom food was saved
    final List<SavedFood> savedFoods = await storage.loadSavedFoods();
    expect(savedFoods, hasLength(1));
    expect(savedFoods.single.name, contains('chicken breast'));
  });
}