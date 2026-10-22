import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/main.dart';

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  if (!tester.any(finder)) {
    await tester.scrollUntilVisible(finder, 80, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<List<String>> _todayLabels(CalorieStorage storage) async {
  final DailyLog? log = await storage.loadDayLog(DateTime.now());
  return log?.entries.map((FoodLogEntry e) => e.mealLabel).toList() ?? <String>[];
}

void main() {
  late CalorieStorage storage;

  setUp(() {
    final DateTime now = DateTime.now();
    storage = CalorieStorage.inMemory(
      initialLogs: <String, DailyLog>{
        DailyLog.formatDateKey(now): DailyLog(
          dateString: DailyLog.formatDateKey(now),
          entries: <FoodLogEntry>[
            FoodLogEntry(mealLabel: 'Oatmeal', calories: 300, mealType: MealType.breakfast),
            FoodLogEntry(mealLabel: 'Chicken Bowl', calories: 600, mealType: MealType.lunch),
          ],
        ),
      },
    );
  });

  testWidgets('removing under a meal filter removes the tapped entry, and Undo restores it',
      (WidgetTester tester) async {
    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage, showOnboarding: false));
    await tester.pumpAndSettle();

    final Finder lunchFilter = find.byKey(const Key('mealFilter_lunch'));
    await _scrollIntoView(tester, lunchFilter);
    await tester.tap(lunchFilter);
    await tester.pumpAndSettle();

    // Chicken Bowl is the only lunch entry, so it is index 0 in the filtered list.
    final Finder removeButton = find.byKey(const Key('removeEntryButton_0'));
    await _scrollIntoView(tester, removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(await _todayLabels(storage), <String>['Oatmeal']);
    expect(find.text('Removed Chicken Bowl.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('undoRemoveButton')));
    await tester.pumpAndSettle();

    expect(await _todayLabels(storage), <String>['Oatmeal', 'Chicken Bowl']);
  });

  testWidgets('clearing the day can be undone', (WidgetTester tester) async {
    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage, showOnboarding: false));
    await tester.pumpAndSettle();

    final Finder clearButton = find.byKey(const Key('clearAllEntriesButton'));
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(await _todayLabels(storage), isEmpty);

    await tester.tap(find.byKey(const Key('undoRemoveButton')));
    await tester.pumpAndSettle();

    expect(await _todayLabels(storage), <String>['Oatmeal', 'Chicken Bowl']);
  });
}
