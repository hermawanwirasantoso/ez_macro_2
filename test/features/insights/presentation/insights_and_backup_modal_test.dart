import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';
import 'package:ez_macro_2/features/insights/presentation/insights_and_backup_modal.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';
import 'package:ez_macro_2/main.dart';

Future<void> _scrollInsights(WidgetTester tester, Finder finder, {double delta = 50}) async {
  final Finder scrollableFinder = find.descendant(
    of: find.byKey(const Key('weeklyInsightsScrollView')),
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

Future<void> _scrollDataBackup(WidgetTester tester, Finder finder, {double delta = 50}) async {
  final Finder scrollableFinder = find.descendant(
    of: find.byKey(const Key('dataBackupScrollView')),
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
  testWidgets('InsightsAndBackupModal renders Weekly Insights with computed metrics',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory(
      initialSettings: const UserSettings(dailyGoal: 2200, targetProteinG: 160),
    );
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();

    final DateTime today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      await calorieStorage.saveDayLog(
        DailyLog(
          dateString: DailyLog.formatDateKey(today.subtract(Duration(days: i))),
          entries: <FoodLogEntry>[
            FoodLogEntry(calories: 2000, mealLabel: 'Meal', proteinG: 170, carbsG: 200, fatG: 50),
          ],
        ),
      );
    }

    await weightStorage.saveEntry(
      WeightEntry(
        id: 'w1',
        weight: 75.0,
        unit: WeightUnit.kg,
        date: today.subtract(const Duration(days: 6)),
      ),
    );
    await weightStorage.saveEntry(
      WeightEntry(
        id: 'w2',
        weight: 74.6,
        unit: WeightUnit.kg,
        date: today,
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
              ),
              child: const Text('Open Insights'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open modal
    await tester.tap(find.text('Open Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Insights & Data'), findsOneWidget);
    expect(find.text('7-DAY PERFORMANCE'), findsOneWidget);
    expect(find.byKey(const Key('daysLoggedBadgeText')), findsOneWidget);
    expect(find.text('7/7 Days Logged'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    expect(find.text('-1400 kcal'), findsOneWidget); // 14000 - 15400

    expect(find.text('Weight vs Calorie Trend'), findsOneWidget);
    expect(find.text('-0.18 kg'), findsOneWidget);
    expect(find.text('-0.4 kg'), findsOneWidget);

    expect(find.text('Daily Macro Averages'), findsOneWidget);

    await _scrollInsights(tester, find.text('Weekly Achievements & Insights'));
    expect(find.text('Weekly Achievements & Insights'), findsOneWidget);
  });

  testWidgets('InsightsAndBackupModal switches to Data & Backup tab and exports data',
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

    // Switch to Data & Backup tab
    await tester.tap(find.text('Data & Backup'));
    await tester.pumpAndSettle();

    expect(find.text('Full Database Backup (JSON)'), findsOneWidget);
    expect(find.byKey(const Key('exportJsonBackupButton')), findsOneWidget);
    expect(find.byKey(const Key('restoreFromBackupButton')), findsOneWidget);
    expect(find.byKey(const Key('exportNutritionCsvButton')), findsOneWidget);
    expect(find.byKey(const Key('exportWeightCsvButton')), findsOneWidget);

    // Export JSON Backup
    await tester.tap(find.byKey(const Key('exportJsonBackupButton')));
    await tester.pump();
    expect(clipboardContent, contains('"version": 1'));

    // Export Nutrition CSV
    await tester.tap(find.byKey(const Key('exportNutritionCsvButton')));
    await tester.pump();
    expect(clipboardContent, startsWith('Date,Total Calories'));
  });

  testWidgets('Restore dialog validates JSON backup and performs merge restore',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();
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

    await tester.tap(find.text('Data & Backup'));
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

    await tester.tap(find.text('Data & Backup'));
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
