import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/main.dart';

Future<void> _scrollToInput(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('nlInputField')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('user can save a custom food and reuse it from Quick Add',
      (WidgetTester tester) async {
    final CalorieStorage storage = CalorieStorage.inMemory();

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    await _scrollToInput(tester);
    await tester.tap(find.byKey(const Key('openQuickAddButton')));
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
    expect(find.text('540 / 2200 kcal'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openQuickAddButton')));
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

    expect(find.text('1080 / 2200 kcal'), findsOneWidget);
    expect(find.text('Homemade Burrito - 540 kcal Saved'), findsOneWidget);
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
    await _scrollToInput(tester);
    await tester.tap(find.byKey(const Key('openQuickAddButton')));
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
    await _scrollToInput(tester);
    await tester.tap(find.byKey(const Key('openQuickAddButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deleteSavedFood_saved_to_remove')));
    await tester.pumpAndSettle();

    expect(await storage.loadSavedFoods(), isEmpty);
    expect(find.byKey(const Key('savedFoodTile_saved_to_remove')), findsNothing);
  });
}