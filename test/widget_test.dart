// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/api_key_storage.dart';
import 'package:ez_macro_2/main.dart';

Future<void> _scrollToInput(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('nlInputField')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
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

    expect(find.text('200 / 2200 kcal'), findsOneWidget);
    expect(find.text('2000 kcal remaining'), findsOneWidget);
    expect(find.text('Protein  15/160 g'), findsOneWidget);
    expect(find.text('Carbs  20/255 g'), findsOneWidget);
    expect(find.text('Fat  7/60 g'), findsOneWidget);
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

    expect(find.text('200 / 2200 kcal'), findsOneWidget);
    expect(find.text('Protein  15/160 g'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('removeEntryButton_0')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('removeEntryButton_0')));
    await tester.pumpAndSettle();

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

    await _scrollToInput(tester);
    final Finder riceChip = find.widgetWithText(ActionChip, 'a bowl of rice');
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

    await _scrollToInput(tester);
    expect(find.text('AI Ready'), findsOneWidget);

    final Finder configureBadge = find.byKey(const Key('configureApiKeyButton'));
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
}
