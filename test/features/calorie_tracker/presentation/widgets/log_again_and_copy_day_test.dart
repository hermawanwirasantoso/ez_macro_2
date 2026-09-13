import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
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

String _keyForDaysAgo(int days) {
  return DailyLog.formatDateKey(DateTime.now().subtract(Duration(days: days)));
}

DailyLog _dayLog(String dateKey, List<FoodLogEntry> entries) {
  return DailyLog(dateString: dateKey, entries: entries);
}

void main() {
  testWidgets('user can log the same entry again on the current day',
      (WidgetTester tester) async {
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialLogs: <String, DailyLog>{
        _keyForDaysAgo(0): _dayLog(_keyForDaysAgo(0), <FoodLogEntry>[
          FoodLogEntry(
            mealLabel: 'Oatmeal',
            calories: 300,
            proteinG: 10,
            carbsG: 50,
            fatG: 6,
            mealType: MealType.breakfast,
          ),
        ]),
      },
    );

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    expect(find.text('300 / 2200 kcal'), findsOneWidget);

    final Finder logAgainBtn = find.byKey(const Key('logAgainEntryButton_0'));
    await _scrollIntoView(tester, logAgainBtn);
    await tester.tap(logAgainBtn);
    await tester.pumpAndSettle();

    expect(find.text('Logged Oatmeal again.'), findsOneWidget);
    expect(find.text('Oatmeal - 300 kcal'), findsNWidgets(2));
    await _scrollIntoView(tester, find.byKey(const Key('caloriesConsumedText')), delta: -50);
    expect(find.text('600 / 2200 kcal'), findsOneWidget);

    final DailyLog? saved = await storage.loadDayLog(DateTime.now());
    expect(saved, isNotNull);
    expect(saved!.entries, hasLength(2));
    expect(saved.entries[0].id, isNot(saved.entries[1].id));
  });

  testWidgets('log again from a past day adds the entry to today',
      (WidgetTester tester) async {
    final String yesterdayKey = _keyForDaysAgo(1);
    final FoodLogEntry yesterdayEntry = FoodLogEntry(
      mealLabel: 'Chicken Bowl',
      calories: 540,
      proteinG: 42,
      carbsG: 55,
      fatG: 16,
      mealType: MealType.dinner,
    );
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialLogs: <String, DailyLog>{
        yesterdayKey: _dayLog(yesterdayKey, <FoodLogEntry>[yesterdayEntry]),
      },
    );

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();
    final Finder yesterdayEntryText = find.text('Chicken Bowl - 540 kcal');
    await _scrollIntoView(tester, yesterdayEntryText);
    expect(yesterdayEntryText, findsOneWidget);

    final Finder logAgainBtn = find.byKey(const Key('logAgainEntryButton_0'));
    await _scrollIntoView(tester, logAgainBtn);
    await tester.tap(logAgainBtn);
    await tester.pumpAndSettle();

    expect(find.text('Logged Chicken Bowl to today.'), findsOneWidget);
    await _scrollIntoView(
      tester,
      find.byKey(const Key('dateTitleText')),
      delta: -80,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('dateTitleText'))).data,
      "Today's Calories",
    );
    await _scrollIntoView(tester, find.text('Chicken Bowl - 540 kcal'));
    expect(find.text('Chicken Bowl - 540 kcal'), findsOneWidget);

    final DailyLog? today = await storage.loadDayLog(DateTime.now());
    final DailyLog? yesterday = await storage.loadDayLog(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(today!.entries, hasLength(1));
    expect(today.entries.single.mealLabel, 'Chicken Bowl');
    expect(today.entries.single.mealType, MealType.dinner);
    expect(today.entries.single.id, isNot(yesterdayEntry.id));
    expect(yesterday!.entries, hasLength(1));
  });

  testWidgets('user can copy a whole past day to today',
      (WidgetTester tester) async {
    final String yesterdayKey = _keyForDaysAgo(1);
    final FoodLogEntry breakfast = FoodLogEntry(
      mealLabel: 'Oatmeal',
      calories: 300,
      mealType: MealType.breakfast,
    );
    final FoodLogEntry dinner = FoodLogEntry(
      mealLabel: 'Chicken Bowl',
      calories: 540,
      mealType: MealType.dinner,
    );
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialLogs: <String, DailyLog>{
        yesterdayKey: _dayLog(yesterdayKey, <FoodLogEntry>[breakfast, dinner]),
      },
    );

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    final Finder copyBtn = find.byKey(const Key('copyDayToTodayButton'));
    await _scrollIntoView(tester, copyBtn);
    expect(copyBtn, findsOneWidget);
    await tester.tap(copyBtn);
    await tester.pumpAndSettle();

    expect(find.text('Copy Day to Today?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmCopyDayButton')));
    await tester.pumpAndSettle();

    expect(find.text('Copied 2 entries to today.'), findsOneWidget);
    await _scrollIntoView(
      tester,
      find.byKey(const Key('dateTitleText')),
      delta: -80,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('dateTitleText'))).data,
      "Today's Calories",
    );
    await _scrollIntoView(tester, find.text('Oatmeal - 300 kcal'));
    expect(find.text('Oatmeal - 300 kcal'), findsOneWidget);
    expect(find.text('Chicken Bowl - 540 kcal'), findsOneWidget);
    expect(find.byKey(const Key('copyDayToTodayButton')), findsNothing);

    final DailyLog? today = await storage.loadDayLog(DateTime.now());
    final DailyLog? yesterday = await storage.loadDayLog(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(today!.entries, hasLength(2));
    expect(yesterday!.entries, hasLength(2));
    final Set<String> todayIds =
        today.entries.map((FoodLogEntry e) => e.id).toSet();
    expect(todayIds, isNot(contains(breakfast.id)));
    expect(todayIds, isNot(contains(dinner.id)));
    expect(todayIds, hasLength(2));
  });

  testWidgets('copy day dialog can be cancelled', (WidgetTester tester) async {
    final String yesterdayKey = _keyForDaysAgo(1);
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialLogs: <String, DailyLog>{
        yesterdayKey: _dayLog(yesterdayKey, <FoodLogEntry>[
          FoodLogEntry(mealLabel: 'Oatmeal', calories: 300),
        ]),
      },
    );

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('previousDayButton')));
    await tester.pumpAndSettle();

    final Finder copyBtn = find.byKey(const Key('copyDayToTodayButton'));
    await _scrollIntoView(tester, copyBtn);
    await tester.tap(copyBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      await storage.loadDayLog(DateTime.now()),
      anyOf(isNull, predicate<DailyLog>((DailyLog log) => log.entries.isEmpty)),
    );
    expect(find.byKey(const Key('copyDayToTodayButton')), findsOneWidget);
  });

  testWidgets('copy to today button is hidden when viewing today',
      (WidgetTester tester) async {
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialLogs: <String, DailyLog>{
        _keyForDaysAgo(0): _dayLog(_keyForDaysAgo(0), <FoodLogEntry>[
          FoodLogEntry(mealLabel: 'Oatmeal', calories: 300),
        ]),
      },
    );

    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();

    await _scrollIntoView(
      tester,
      find.byKey(const Key('clearAllEntriesButton')),
    );
    expect(find.byKey(const Key('copyDayToTodayButton')), findsNothing);
  });
}
