import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';
import 'package:ez_macro_2/features/insights/presentation/insights_and_backup_modal.dart';
import 'package:ez_macro_2/features/recipes/data/recipe_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_goal.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';
import 'package:ez_macro_2/main.dart';

Future<void> _scrollTo(WidgetTester tester, String scrollViewKey, Finder finder) async {
  final Finder scrollableFinder = find.descendant(
    of: find.byKey(Key(scrollViewKey)),
    matching: find.byType(Scrollable),
  );
  if (!tester.any(finder)) {
    await tester.scrollUntilVisible(finder, 120, scrollable: scrollableFinder.first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollOverview(WidgetTester tester, Finder finder) =>
    _scrollTo(tester, 'overviewScrollView', finder);

Future<void> _scrollDataBackup(WidgetTester tester, Finder finder) =>
    _scrollTo(tester, 'dataBackupScrollView', finder);

DateTime _daysAgo(int n) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n);
}

Future<void> _openModal(
  WidgetTester tester, {
  required CalorieStorage calorieStorage,
  required WeightStorage weightStorage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => InsightsAndBackupModal.show(
              context,
              calorieStorage: calorieStorage,
              weightStorage: weightStorage,
            ),
            child: const Text('Open Insights'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Insights'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Overview shows completed-day averages, weekly averages, and highlights',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory(
      initialSettings: const UserSettings(dailyGoal: 2200, targetProteinG: 160),
    );
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();

    for (int i = 1; i <= 7; i++) {
      await calorieStorage.saveDayLog(
        DailyLog(
          dateString: DailyLog.formatDateKey(_daysAgo(i)),
          entries: <FoodLogEntry>[
            FoodLogEntry(calories: 2000, mealLabel: 'Meal', proteinG: 170, carbsG: 200, fatG: 50),
          ],
        ),
      );
    }
    // Today is still in progress and must not pull the averages down.
    await calorieStorage.saveDayLog(
      DailyLog(
        dateString: DailyLog.formatDateKey(_daysAgo(0)),
        entries: <FoodLogEntry>[FoodLogEntry(calories: 400, mealLabel: 'Breakfast')],
      ),
    );
    await weightStorage.saveEntry(
      WeightEntry(id: 'w1', weight: 75.0, unit: WeightUnit.kg, date: _daysAgo(6)),
    );
    await weightStorage.saveEntry(
      WeightEntry(id: 'w2', weight: 74.6, unit: WeightUnit.kg, date: _daysAgo(0)),
    );

    await _openModal(tester, calorieStorage: calorieStorage, weightStorage: weightStorage);

    expect(find.text('Insights & Data'), findsOneWidget);
    expect(find.text('7/7 days logged'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('avgCaloriesText'))).textSpan!.toPlainText(),
      contains('2,000'),
    );
    expect(find.text('-1,400 kcal'), findsOneWidget); // 14,000 - 15,400
    expect(find.text('-0.18 kg'), findsOneWidget);
    expect(find.byKey(const Key('todayExcludedNote')), findsOneWidget);

    await _scrollOverview(tester, find.byKey(const Key('weekRow_7')));
    expect(find.text('Weekly averages'), findsOneWidget);
    expect(find.text('Last week'), findsOneWidget);

    await _scrollOverview(tester, find.byKey(const Key('weightChangeText')));
    expect(find.text('-0.4 kg'), findsOneWidget);

    final Finder proteinHighlight = find.textContaining('Protein target (160 g) reached on 7 of 7');
    await _scrollOverview(tester, proteinHighlight);
    expect(proteinHighlight, findsOneWidget);
  });

  testWidgets('Period selector switches to 30 days and shows the goal projection',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory(
      initialSettings: const UserSettings(dailyGoal: 2200, targetProteinG: 150),
    );
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage(
      initialGoal: const WeightGoal(targetWeight: 75.0, startingWeight: 80.0, unit: WeightUnit.kg),
    );

    for (int i = 1; i <= 25; i++) {
      await calorieStorage.saveDayLog(
        DailyLog(
          dateString: DailyLog.formatDateKey(_daysAgo(i)),
          entries: <FoodLogEntry>[
            FoodLogEntry(calories: 1900, mealLabel: 'Meal', proteinG: 160, carbsG: 180, fatG: 50),
          ],
        ),
      );
    }
    for (int i = 0; i < 5; i++) {
      await weightStorage.saveEntry(
        WeightEntry(id: 'w$i', weight: 80.0 - (i * 0.5), unit: WeightUnit.kg, date: _daysAgo(28 - (i * 7))),
      );
    }

    await _openModal(tester, calorieStorage: calorieStorage, weightStorage: weightStorage);

    await tester.tap(find.byKey(const Key('insightsPeriod_30')));
    await tester.pumpAndSettle();

    expect(find.text('25/30 days logged'), findsOneWidget);
    expect(find.text('-7,500 kcal'), findsOneWidget); // 25 x (1,900 - 2,200)

    await _scrollOverview(tester, find.byKey(const Key('goalProjectionText')));
    expect(find.text('-0.5 kg/wk'), findsOneWidget);
    expect(find.textContaining('At this pace you reach your goal'), findsOneWidget);
  });

  testWidgets('History tab lists logged days by week and expands a day',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();

    await calorieStorage.saveDayLog(
      DailyLog(
        dateString: DailyLog.formatDateKey(_daysAgo(1)),
        entries: <FoodLogEntry>[
          FoodLogEntry(calories: 300, mealLabel: 'Oatmeal'),
          FoodLogEntry(calories: 600, mealLabel: 'Chicken Bowl'),
        ],
      ),
    );
    await calorieStorage.saveDayLog(
      DailyLog(
        dateString: DailyLog.formatDateKey(_daysAgo(10)),
        entries: <FoodLogEntry>[FoodLogEntry(calories: 2100, mealLabel: 'Pasta')],
      ),
    );

    await _openModal(tester, calorieStorage: calorieStorage, weightStorage: weightStorage);

    await tester.tap(find.byKey(const Key('historyTab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('historySummary')), findsOneWidget);
    expect(find.text('1,500'), findsOneWidget); // (900 + 2,100) / 2

    final Finder yesterday = find.byKey(Key('historyDay_${DailyLog.formatDateKey(_daysAgo(1))}'));
    expect(yesterday, findsOneWidget);
    expect(find.text('Oatmeal'), findsNothing);

    await tester.tap(yesterday);
    await tester.pumpAndSettle();
    expect(find.text('Oatmeal'), findsOneWidget);
    expect(find.text('Chicken Bowl'), findsOneWidget);
  });

  testWidgets('History tab shows an empty state without logs', (WidgetTester tester) async {
    await _openModal(
      tester,
      calorieStorage: CalorieStorage.inMemory(),
      weightStorage: InMemoryWeightStorage(),
    );

    await tester.tap(find.byKey(const Key('historyTab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('historyEmptyText')), findsOneWidget);
  });

  testWidgets('InsightsAndBackupModal switches to the Data tab and exports data',
      (WidgetTester tester) async {
    String clipboardContent = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardContent = (methodCall.arguments as Map<dynamic, dynamic>)['text'] as String? ?? '';
          return null;
        }
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardContent};
        }
        return null;
      },
    );

    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => InsightsAndBackupModal.show(
                context,
                calorieStorage: calorieStorage,
                weightStorage: weightStorage,
                recipeStorage: recipeStorage,
              ),
              child: const Text('Open Insights'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Insights'));
    await tester.pumpAndSettle();

    // Switch to the Data tab
    await tester.tap(find.byKey(const Key('dataBackupTab')));
    await tester.pumpAndSettle();

    expect(find.text('Full Database Backup (JSON)'), findsOneWidget);
    expect(find.byKey(const Key('exportJsonBackupButton')), findsOneWidget);
    expect(find.byKey(const Key('restoreFromBackupButton')), findsOneWidget);
    expect(find.byKey(const Key('exportNutritionCsvButton')), findsOneWidget);
    expect(find.byKey(const Key('exportWeightCsvButton')), findsOneWidget);

    // Export JSON Backup
    await tester.tap(find.byKey(const Key('exportJsonBackupButton')));
    await tester.pumpAndSettle();
    expect(clipboardContent, contains('"version": 1'));
    expect(find.text('✅ Full Backup (JSON) copied to clipboard!'), findsOneWidget);

    // Let the confirmation, shown inside the sheet, time out before the next tap.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Export Nutrition CSV
    await tester.tap(find.byKey(const Key('exportNutritionCsvButton')));
    await tester.pumpAndSettle();
    expect(clipboardContent, startsWith('Date,Total Calories'));
  });

  testWidgets('Restore dialog validates JSON backup and performs merge restore',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage();
    bool onRestoredCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => InsightsAndBackupModal.show(
                context,
                calorieStorage: calorieStorage,
                weightStorage: weightStorage,
                recipeStorage: recipeStorage,
                onDataRestored: () {
                  onRestoredCalled = true;
                },
              ),
              child: const Text('Open Insights'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Insights'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dataBackupTab')));
    await tester.pumpAndSettle();

    // Tap Restore Backup
    await tester.tap(find.byKey(const Key('restoreFromBackupButton')));
    await tester.pumpAndSettle();

    expect(find.text('Restore from Backup'), findsOneWidget);

    const String testBackupJson = '''
    {
      "version": 1,
      "settings": { "dailyGoal": 2350, "targetProteinG": 180, "targetCarbsG": 240, "targetFatG": 65 },
      "dailyLogs": [
        {
          "dateString": "2026-08-20",
          "dailyGoal": 2350,
          "entries": [
            { "calories": 500, "mealLabel": "Salmon Bowl", "proteinG": 40, "carbsG": 50, "fatG": 15 }
          ]
        }
      ],
      "savedFoods": [],
      "weightEntries": []
    }
    ''';

    await tester.enterText(find.byKey(const Key('restoreJsonInput')), testBackupJson);
    await tester.pumpAndSettle();

    expect(find.text('✅ Valid Backup Found:'), findsOneWidget);
    expect(find.text('• Daily food logs: 1'), findsOneWidget);

    // Tap Merge Restore
    await tester.tap(find.byKey(const Key('confirmRestoreMergeButton')));
    await tester.pumpAndSettle();

    expect(onRestoredCalled, isTrue);
    final UserSettings settings = await calorieStorage.loadSettings();
    expect(settings.dailyGoal, 2350);
  });

  testWidgets('Clear all data resets storages after confirmation dialog',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage();

    await calorieStorage.saveDayLog(
      DailyLog(
        dateString: '2026-08-20',
        entries: <FoodLogEntry>[
          FoodLogEntry(calories: 600, mealLabel: 'Pizza'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => InsightsAndBackupModal.show(
                context,
                calorieStorage: calorieStorage,
                weightStorage: weightStorage,
                recipeStorage: recipeStorage,
              ),
              child: const Text('Open Insights'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Insights'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dataBackupTab')));
    await tester.pumpAndSettle();

    final Finder clearBtn = find.byKey(const Key('clearAllDataButton'));
    await _scrollDataBackup(tester, clearBtn);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    expect(find.text('⚠️ Clear All App Data?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmClearAllButton')));
    await tester.pumpAndSettle();

    final List<DailyLog> remainingLogs = await calorieStorage.loadAllLogs();
    expect(remainingLogs, isEmpty);
  });

  testWidgets('AppBar action opens InsightsAndBackupModal in MacroTrackerApp',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();

    await tester.pumpWidget(
      MacroTrackerApp(
        calorieStorage: calorieStorage,
        weightStorage: weightStorage,
        showOnboarding: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('openInsightsModalButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('openInsightsModalButton')));
    await tester.pumpAndSettle();

    expect(find.text('Insights & Data'), findsOneWidget);
  });
}
