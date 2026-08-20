import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';
import 'package:ez_macro_2/features/tdee_calculator/presentation/tdee_calculator_screen.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/main.dart';

Future<void> _scrollTo(WidgetTester tester, Finder finder, {double delta = 50}) async {
  final Finder scrollableFinder = find.descendant(
    of: find.byKey(const Key('tdeeCalculatorScrollView')),
    matching: find.byType(Scrollable),
  );
  if (tester.any(finder)) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: scrollableFinder.first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TdeeCalculatorScreen renders all 4 questions and live preview on single screen',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: TdeeCalculatorScreen(
          calorieStorage: calorieStorage,
          weightStorage: weightStorage,
          isDarkMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('⚡ Quick TDEE & Macro Setup'), findsOneWidget);
    expect(find.text('1. Biological Profile'), findsOneWidget);
    expect(find.byKey(const Key('tdeeSexSegmentedButton')), findsOneWidget);
    expect(find.byKey(const Key('ageDisplayValue')), findsOneWidget);

    expect(find.text('2. Body Stats'), findsOneWidget);
    expect(find.byKey(const Key('tdeeHeightField')), findsOneWidget);
    expect(find.byKey(const Key('tdeeWeightField')), findsOneWidget);

    expect(find.text('3. Daily Activity Level'), findsOneWidget);
    expect(find.byKey(const Key('activityLevelOption_sedentary')), findsOneWidget);
    expect(find.byKey(const Key('activityLevelOption_moderate')), findsOneWidget);

    await _scrollTo(tester, find.text('4. Primary Goal'));
    expect(find.text('4. Primary Goal'), findsOneWidget);
    expect(find.byKey(const Key('fitnessGoalOption_cut')), findsOneWidget);
    expect(find.byKey(const Key('fitnessGoalOption_maintain')), findsOneWidget);
    expect(find.byKey(const Key('fitnessGoalOption_bulk')), findsOneWidget);

    // Live result preview
    await _scrollTo(tester, find.byKey(const Key('tdeeResultCard')));
    expect(find.byKey(const Key('tdeeResultCard')), findsOneWidget);
    expect(find.byKey(const Key('tdeeCalculatedCaloriesText')), findsOneWidget);

    await _scrollTo(tester, find.byKey(const Key('applyTdeeTargetsButton')));
    expect(find.byKey(const Key('applyTdeeTargetsButton')), findsOneWidget);
    expect(find.byKey(const Key('skipTdeeOnboardingButton')), findsOneWidget);
  });

  testWidgets('Changing stats reactively updates live calculation card',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: TdeeCalculatorScreen(
          calorieStorage: calorieStorage,
          weightStorage: weightStorage,
          isDarkMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default: Male 75kg, 175cm, 25yo, Moderate (1.55), Cut (-400) -> 2272 kcal
    await _scrollTo(tester, find.text('2272'));
    expect(find.text('2272'), findsOneWidget);

    // Switch goal to Maintain (0 delta) -> 2672 kcal
    await _scrollTo(tester, find.byKey(const Key('fitnessGoalOption_maintain')), delta: -50);
    await tester.tap(find.byKey(const Key('fitnessGoalOption_maintain')));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('2672'));
    expect(find.text('2672'), findsOneWidget);

    // Switch goal to Bulk (+300 delta) -> 2972 kcal
    await _scrollTo(tester, find.byKey(const Key('fitnessGoalOption_bulk')), delta: -50);
    await tester.tap(find.byKey(const Key('fitnessGoalOption_bulk')));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('2972'));
    expect(find.text('2972'), findsOneWidget);

    // Increase age from 25 to 26
    await _scrollTo(tester, find.byKey(const Key('incrementAgeButton')), delta: -50);
    await tester.tap(find.byKey(const Key('incrementAgeButton')));
    await tester.pumpAndSettle();
    expect(find.text('26'), findsOneWidget);
  });

  testWidgets('Apply & Start Tracking saves targets and marks onboarding completed',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();
    bool onCompleteCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TdeeCalculatorScreen(
          calorieStorage: calorieStorage,
          weightStorage: weightStorage,
          isDarkMode: true,
          onComplete: () {
            onCompleteCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Apply
    final Finder applyBtn = find.byKey(const Key('applyTdeeTargetsButton'));
    await _scrollTo(tester, applyBtn);
    await tester.tap(applyBtn);
    await tester.pumpAndSettle();

    expect(onCompleteCalled, isTrue);

    final UserSettings settings = await calorieStorage.loadSettings();
    expect(settings.hasCompletedOnboarding, isTrue);
    expect(settings.dailyGoal, 2272);
    expect(settings.targetProteinG, 227);
    expect(settings.targetFatG, 63);

    // Weight goal was initialized
    final goal = await weightStorage.loadGoal();
    expect(goal, isNotNull);
    expect(goal!.startingWeight, 75.0);
  });

  testWidgets('Skip button marks onboarding completed without changing default targets',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();
    bool onCompleteCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TdeeCalculatorScreen(
          calorieStorage: calorieStorage,
          weightStorage: weightStorage,
          isDarkMode: true,
          onComplete: () {
            onCompleteCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder skipBtn = find.byKey(const Key('skipTdeeOnboardingButton'));
    await _scrollTo(tester, skipBtn);
    await tester.tap(skipBtn);
    await tester.pumpAndSettle();

    expect(onCompleteCalled, isTrue);

    final UserSettings settings = await calorieStorage.loadSettings();
    expect(settings.hasCompletedOnboarding, isTrue);
    expect(settings.dailyGoal, 2200); // kept default
  });

  testWidgets('TargetEditorModal can launch TDEE calculator modal and autofill targets',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();

    await tester.pumpWidget(
      MacroTrackerApp(
        calorieStorage: calorieStorage,
        showOnboarding: false,
      ),
    );
    await tester.pumpAndSettle();

    // Open Target Editor Modal
    await tester.tap(find.byKey(const Key('editTargetsButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('openTdeeCalculatorButton')), findsOneWidget);

    // Tap Calculate with TDEE
    await tester.tap(find.byKey(const Key('openTdeeCalculatorButton')));
    await tester.pumpAndSettle();

    expect(find.text('⚡ Quick TDEE & Macro Setup'), findsOneWidget);

    // Tap Apply inside modal
    final Finder applyBtn = find.byKey(const Key('applyTdeeTargetsButton'));
    await _scrollTo(tester, applyBtn);
    await tester.tap(applyBtn);
    await tester.pumpAndSettle();

    // Target editor input fields are autofilled
    final TextField calField = tester.widget<TextField>(find.byKey(const Key('dailyCalorieTargetField')));
    expect(calField.controller?.text, '2272');

    final TextField proteinField = tester.widget<TextField>(find.byKey(const Key('proteinTargetField')));
    expect(proteinField.controller?.text, '227');

    // Save targets
    final Finder saveTargetsBtn = find.byKey(const Key('saveTargetsButton'));
    await tester.ensureVisible(saveTargetsBtn);
    await tester.tap(saveTargetsBtn);
    await tester.pumpAndSettle();

    expect(find.text('0 / 2271 kcal'), findsOneWidget);
  });
}
