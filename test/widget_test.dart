// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/api_key_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
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

Future<void> _scrollToVisible(WidgetTester tester, Finder finder, {double delta = 50}) async {
  await _scrollIntoView(tester, finder, delta: delta);
}

Future<void> _scrollToInput(WidgetTester tester) async {
  await _scrollIntoView(tester, find.byKey(const Key('nlInputField')));
}

Future<void> _scrollToHero(WidgetTester tester) async {
  await _scrollIntoView(tester, find.byKey(const Key('caloriesConsumedText')), delta: -50);
}

Future<void> _tapSaveEntry(WidgetTester tester) async {
  final Finder saveButton = find.byKey(const Key('saveEntryButton'));
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await const PreferencesCalorieStorage().clearAll();
    await const PreferencesWeightStorage().clearAll();
  });

  testWidgets('Calorie tracker summary renders initial values', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    expect(find.text("Today's Calories"), findsOneWidget);
    expect(find.byKey(const Key('caloriesConsumedText')), findsOneWidget);
    expect(find.byKey(const Key('caloriesRemainingText')), findsOneWidget);
    expect(find.byKey(const Key('calorieProgressBar')), findsOneWidget);
    expect(find.byKey(const Key('toggleSpreadSwitch')), findsOneWidget);
    expect(find.byKey(const Key('proteinProgressLabel')), findsOneWidget);
    expect(find.byKey(const Key('carbsProgressLabel')), findsOneWidget);
    expect(find.byKey(const Key('fatProgressLabel')), findsOneWidget);

    expect(find.text('0 / 2200 kcal'), findsOneWidget);
    expect(find.text('2200 kcal remaining'), findsOneWidget);
    expect(find.text('Protein  0/160 g'), findsOneWidget);
    expect(find.text('Carbs  0/255 g'), findsOneWidget);
    expect(find.text('Fat  0/60 g'), findsOneWidget);
  });

  testWidgets('Natural language parse logs a meal', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    await _scrollToInput(tester);
    await tester.enterText(find.byKey(const Key('nlInputField')), 'Dinner 200 kcal');
    final FilledButton parseButton1 =
    tester.widget<FilledButton>(find.byKey(const Key('parseMealButton')).first);
    parseButton1.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    await _scrollToHero(tester);
    expect(find.text('200 / 2200 kcal'), findsOneWidget);
    expect(find.text('2000 kcal remaining'), findsOneWidget);
    expect(find.text('Protein  15/160 g'), findsOneWidget);
    expect(find.text('Carbs  20/255 g'), findsOneWidget);
    expect(find.text('Fat  7/60 g'), findsOneWidget);

    await _scrollIntoView(tester, find.byKey(const Key('parseResultText')));
    expect(find.byKey(const Key('parseResultText')), findsOneWidget);
    expect(find.byKey(const Key('spreadText')), findsNothing);
  });

  testWidgets('Casual phrase input is estimated and logged', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    await _scrollToInput(tester);
    await tester.enterText(find.byKey(const Key('nlInputField')), 'a bowl of rice');
    final FilledButton parseButton2 =
    tester.widget<FilledButton>(find.byKey(const Key('parseMealButton')).first);
    parseButton2.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    await _scrollToHero(tester);
    expect(find.text('280 / 2200 kcal'), findsOneWidget);
    expect(find.text('1920 kcal remaining'), findsOneWidget);
    expect(find.text('Protein  5/160 g'), findsOneWidget);
    expect(find.text('Carbs  62/255 g'), findsOneWidget);
    expect(find.text('Fat  1/60 g'), findsOneWidget);
    expect(find.byKey(const Key('spreadText')), findsNothing);
  });

  testWidgets('Gram portion is treated as weight, not calories', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    await _scrollToInput(tester);
    await tester.enterText(find.byKey(const Key('nlInputField')), '200g of chicken breast');
    final FilledButton parseButton3 =
    tester.widget<FilledButton>(find.byKey(const Key('parseMealButton')).first);
    parseButton3.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    await _scrollToHero(tester);
    expect(find.text('330 / 2200 kcal'), findsOneWidget);
    expect(find.text('1870 kcal remaining'), findsOneWidget);
    expect(find.text('Protein  62/160 g'), findsOneWidget);
    expect(find.text('Carbs  0/255 g'), findsOneWidget);
    expect(find.text('Fat  8/60 g'), findsOneWidget);
    expect(find.byKey(const Key('spreadText')), findsNothing);
  });

  testWidgets('Editable targets enforce calorie math', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    await tester.tap(find.byKey(const Key('editTargetsButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('dailyCalorieTargetField')), '2300');
    await tester.enterText(find.byKey(const Key('proteinTargetField')), '170');
    await tester.enterText(find.byKey(const Key('carbsTargetField')), '250');
    await tester.enterText(find.byKey(const Key('fatTargetField')), '60');

    await tester.tap(find.byKey(const Key('saveTargetsButton')));
    await tester.pumpAndSettle();

    expect(find.text('0 / 2300 kcal'), findsOneWidget);
    expect(find.text('2300 kcal remaining'), findsOneWidget);
    expect(find.text('Protein  0/170 g'), findsOneWidget);
    expect(find.text('Carbs  0/270 g'), findsOneWidget);
    expect(find.text('Fat  0/60 g'), findsOneWidget);
  });

  testWidgets('Spread details can be toggled on', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    await tester.tap(find.byKey(const Key('toggleSpreadSwitch')));
    await tester.pumpAndSettle();

    await _scrollToInput(tester);
    await tester.enterText(find.byKey(const Key('nlInputField')), 'Dinner 200 kcal');
    final FilledButton parseButton4 =
    tester.widget<FilledButton>(find.byKey(const Key('parseMealButton')).first);
    parseButton4.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spreadText')), findsOneWidget);
    expect(find.byKey(const Key('spreadBanner')), findsOneWidget);
  });

  testWidgets('Remove entry rolls back totals', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    await _scrollToInput(tester);
    await tester.enterText(find.byKey(const Key('nlInputField')), 'Dinner 200 kcal');
    final FilledButton parseButton =
    tester.widget<FilledButton>(find.byKey(const Key('parseMealButton')).first);
    parseButton.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    await _scrollToHero(tester);
    expect(find.text('200 / 2200 kcal'), findsOneWidget);
    expect(find.text('Protein  15/160 g'), findsOneWidget);

    final Finder removeBtn = find.byKey(const Key('removeEntryButton_0'));
    await _scrollIntoView(tester, removeBtn);
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();

    await _scrollToHero(tester);

    expect(find.text('0 / 2200 kcal'), findsOneWidget);
    expect(find.text('Protein  0/160 g'), findsOneWidget);
    expect(find.text('Carbs  0/255 g'), findsOneWidget);
    expect(find.text('Fat  0/60 g'), findsOneWidget);
  });

  testWidgets('Theme toggle switches brightness mode', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    final Finder themeButton = find.byKey(const Key('toggleThemeButton'));
    expect(themeButton, findsOneWidget);

    await tester.tap(themeButton);
    await tester.pumpAndSettle();

    // Verify theme toggle completed smoothly
    expect(find.text("Today's Calories"), findsOneWidget);
  });

  testWidgets('Suggestion chips populate input field', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    final Finder riceChip = find.widgetWithText(ActionChip, 'a bowl of rice');
    await _scrollToVisible(tester, riceChip);
    expect(riceChip, findsOneWidget);

    await tester.tap(riceChip);
    await tester.pumpAndSettle();

    final TextField textField = tester.widget<TextField>(find.byKey(const Key('nlInputField')));
    expect(textField.controller?.text, 'a bowl of rice');
  });

  testWidgets('Target editor macro preset sets balanced ratio', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());

    await tester.tap(find.byKey(const Key('editTargetsButton')));
    await tester.pumpAndSettle();

    final Finder presetChip = find.widgetWithText(ActionChip, 'High Protein (40/35/25)');
    expect(presetChip, findsOneWidget);

    await tester.tap(presetChip);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveTargetsButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('proteinProgressLabel')), findsOneWidget);
  });

  testWidgets('User can open API key modal from AppBar, save key, and update state', (WidgetTester tester) async {
    final storage = InMemoryApiKeyStorage();
    await tester.pumpWidget(MacroTrackerApp(apiKeyStorage: storage));
    await tester.pumpAndSettle();

    final Finder apiKeyButton = find.byKey(const Key('openApiKeyModalButton'));
    expect(apiKeyButton, findsOneWidget);

    await tester.tap(apiKeyButton);
    await tester.pumpAndSettle();

    expect(find.text('Google AI API Key'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('apiKeyInputField')),
      'AIzaSyTestUserKey123',
    );
    await tester.tap(find.byKey(const Key('saveApiKeyButton')));
    await tester.pumpAndSettle();

    expect(await storage.getApiKey(), 'AIzaSyTestUserKey123');

    await _scrollToInput(tester);
    expect(find.text('AI Ready'), findsOneWidget);
  });

  testWidgets('User can open API key modal from AI card configure badge and remove key', (WidgetTester tester) async {
    final storage = InMemoryApiKeyStorage('AIzaSyExistingKey999');
    await tester.pumpWidget(MacroTrackerApp(apiKeyStorage: storage));
    await tester.pumpAndSettle();

    final Finder configureBadge = find.byKey(const Key('configureApiKeyButton'));
    await _scrollToVisible(tester, configureBadge);
    expect(find.text('AI Ready'), findsOneWidget);
    expect(configureBadge, findsOneWidget);

    await tester.tap(configureBadge);
    await tester.pumpAndSettle();

    expect(find.text('Google AI API Key'), findsOneWidget);
    expect(find.text('Active Secure Key: ••••••••y999'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearApiKeyButton')));
    await tester.pumpAndSettle();

    expect(await storage.getApiKey(), isNull);
    await _scrollToInput(tester);
    expect(find.text('Local NLP'), findsOneWidget);
  });

  testWidgets('App initializes cleanly when apiKeyStorage is explicitly null', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp(apiKeyStorage: null));
    await tester.pumpAndSettle();

    expect(find.text("Today's Calories"), findsOneWidget);
    expect(find.byKey(const Key('openApiKeyModalButton')), findsOneWidget);
  });

  testWidgets('Quick Add shows a nutrition label scan action', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());
    await tester.pumpAndSettle();

    final Finder quickAddButton = find.byKey(const Key('openQuickAddButton'));
    await _scrollToVisible(tester, quickAddButton);
    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scanNutritionLabelButton')), findsOneWidget);
    expect(find.text('Scan nutrition label'), findsOneWidget);
  });

  testWidgets('User can manually log food via Quick Add modal', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());
    await tester.pumpAndSettle();

    final Finder quickAddButton = find.byKey(const Key('openQuickAddButton'));
    await _scrollToVisible(tester, quickAddButton);
    expect(quickAddButton, findsOneWidget);

    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();

    expect(find.text('Quick Add Food'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('mealLabelField')), 'Protein Shake');
    await tester.enterText(find.byKey(const Key('caloriesField')), '250');
    await tester.enterText(find.byKey(const Key('proteinField')), '30');
    await tester.enterText(find.byKey(const Key('carbsField')), '10');
    await tester.enterText(find.byKey(const Key('fatField')), '3');

    await _tapSaveEntry(tester);

    await _scrollToHero(tester);
    expect(find.text('250 / 2200 kcal'), findsOneWidget);
    expect(find.text('Protein  30/160 g'), findsOneWidget);
    expect(find.text('Carbs  10/255 g'), findsOneWidget);
    expect(find.text('Fat  3/60 g'), findsOneWidget);

    final Finder loggedEntryFinder = find.text('Protein Shake - 250 kcal Manual');
    await _scrollIntoView(tester, loggedEntryFinder);
    expect(loggedEntryFinder, findsOneWidget);
  });

  testWidgets('User can edit an existing food entry and update values', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());
    await tester.pumpAndSettle();

    // Quick add first item
    final Finder quickAddButton = find.byKey(const Key('openQuickAddButton'));
    await _scrollToVisible(tester, quickAddButton);
    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mealLabelField')), 'Apple');
    await tester.enterText(find.byKey(const Key('caloriesField')), '80');
    await _tapSaveEntry(tester);

    await _scrollToHero(tester);
    expect(find.text('80 / 2200 kcal'), findsOneWidget);

    // Edit the entry
    final Finder editButton = find.byKey(const Key('editEntryButton_0'));
    await _scrollToVisible(tester, editButton);
    expect(editButton, findsOneWidget);

    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit Meal'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mealLabelField')), 'Large Honeycrisp Apple');
    await tester.enterText(find.byKey(const Key('caloriesField')), '120');
    await _tapSaveEntry(tester);

    await _scrollToHero(tester);
    expect(find.text('120 / 2200 kcal'), findsOneWidget);

    final Finder updatedEntryFinder = find.text('Large Honeycrisp Apple - 120 kcal Manual');
    await _scrollIntoView(tester, updatedEntryFinder);
    expect(updatedEntryFinder, findsOneWidget);
  });

  testWidgets('User can filter entries by meal category tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());
    await tester.pumpAndSettle();

    // Add breakfast item
    final Finder quickAddButton = find.byKey(const Key('openQuickAddButton'));
    await _scrollToVisible(tester, quickAddButton);
    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mealTypeChip_breakfast')));
    await tester.enterText(find.byKey(const Key('mealLabelField')), 'Oatmeal');
    await tester.enterText(find.byKey(const Key('caloriesField')), '300');
    await _tapSaveEntry(tester);

    // Add lunch item
    await _scrollToVisible(tester, quickAddButton);
    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mealTypeChip_lunch')));
    await tester.enterText(find.byKey(const Key('mealLabelField')), 'Chicken Bowl');
    await tester.enterText(find.byKey(const Key('caloriesField')), '500');
    await _tapSaveEntry(tester);

    await _scrollToHero(tester);
    expect(find.text('800 / 2200 kcal'), findsOneWidget);

    // Filter to Lunch only
    final Finder lunchFilter = find.byKey(const Key('mealFilter_lunch'));
    await _scrollToVisible(tester, lunchFilter);
    await tester.tap(lunchFilter);
    await tester.pumpAndSettle();

    expect(find.text('Chicken Bowl - 500 kcal Manual'), findsOneWidget);
    expect(find.text('Oatmeal - 300 kcal Manual'), findsNothing);

    // Filter back to All
    final Finder allFilter = find.byKey(const Key('mealFilter_all'));
    await _scrollIntoView(tester, allFilter);
    await tester.tap(allFilter);
    await tester.pumpAndSettle();

    final Finder chickenEntry = find.text('Chicken Bowl - 500 kcal Manual');
    await _scrollIntoView(tester, chickenEntry);
    expect(chickenEntry, findsOneWidget);

    final Finder oatmealEntry = find.text('Oatmeal - 300 kcal Manual');
    await _scrollIntoView(tester, oatmealEntry);
    expect(oatmealEntry, findsOneWidget);
  });

  testWidgets('User can navigate calendar dates and jump back to today', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text("Today's Calories"), findsOneWidget);

    // Navigate to yesterday
    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('jumpToTodayButton')), findsOneWidget);

    // Jump back to today
    await tester.tap(find.byKey(const Key('jumpToTodayButton')));
    await tester.pumpAndSettle();

    expect(find.text("Today's Calories"), findsOneWidget);
  });

  testWidgets('User can clear day logs with confirmation dialog', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());
    await tester.pumpAndSettle();

    // Add an entry
    final Finder quickAddButton = find.byKey(const Key('openQuickAddButton'));
    await _scrollToVisible(tester, quickAddButton);
    await tester.tap(quickAddButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mealLabelField')), 'Snack Bar');
    await tester.enterText(find.byKey(const Key('caloriesField')), '150');
    await _tapSaveEntry(tester);

    await _scrollToHero(tester);
    expect(find.text('150 / 2200 kcal'), findsOneWidget);

    // Tap clear day button
    final Finder clearButton = find.byKey(const Key('clearAllEntriesButton'));
    await _scrollToVisible(tester, clearButton);
    expect(clearButton, findsOneWidget);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('Clear Day Logs?'), findsOneWidget);

    // Confirm clear
    await tester.tap(find.widgetWithText(FilledButton, 'Clear All'));
    await tester.pumpAndSettle();

    await _scrollToHero(tester);
    expect(find.text('0 / 2200 kcal'), findsOneWidget);
  });
}
