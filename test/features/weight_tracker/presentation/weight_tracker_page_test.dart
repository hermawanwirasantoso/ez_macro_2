import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_goal.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';
import 'package:ez_macro_2/features/weight_tracker/presentation/weight_tracker_page.dart';
import 'package:ez_macro_2/main.dart';

void main() {
  testWidgets('WeightTrackerPage renders initial empty state', (WidgetTester tester) async {
    final InMemoryWeightStorage storage = InMemoryWeightStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackerPage(
          onToggleTheme: () {},
          isDarkMode: true,
          weightStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weight Tracker'), findsOneWidget);
    expect(find.byKey(const Key('heroWeightCard')), findsOneWidget);
    expect(find.byKey(const Key('currentWeightDisplay')), findsOneWidget);
    expect(find.text('--'), findsWidgets);
    expect(find.byKey(const Key('weightChartCard')), findsOneWidget);
    expect(find.text('No weight entries in this period'), findsOneWidget);
    expect(find.byKey(const Key('quickLogWeightButton')), findsOneWidget);
    expect(find.text('No weigh-ins recorded yet.\nTap "+ Log Weigh-in" to get started!'), findsOneWidget);
  });

  testWidgets('User can log a new weight entry with note and body fat', (WidgetTester tester) async {
    final InMemoryWeightStorage storage = InMemoryWeightStorage();

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackerPage(
          onToggleTheme: () {},
          isDarkMode: true,
          weightStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap quick log button
    await tester.tap(find.byKey(const Key('quickLogWeightButton')));
    await tester.pumpAndSettle();

    expect(find.text('Log Weight'), findsOneWidget);

    // Enter weight
    await tester.enterText(find.byKey(const Key('weightInputField')), '74.5');
    // Enter body fat
    await tester.enterText(find.byKey(const Key('bodyFatInputField')), '15.2');
    // Enter note
    await tester.enterText(find.byKey(const Key('weightNoteInputField')), 'Morning fasted');

    // Save
    await tester.tap(find.byKey(const Key('saveWeightEntryButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('currentWeightDisplay')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('currentWeightDisplay'))).data, '74.5');

    await tester.scrollUntilVisible(
      find.text('Morning fasted'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Morning fasted'), findsOneWidget);
    expect(find.text('15.2% BF'), findsOneWidget);
    expect(find.text('1 recorded'), findsOneWidget);
  });

  testWidgets('User sees delta badge when multiple entries exist', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final InMemoryWeightStorage storage = InMemoryWeightStorage(
      initialEntries: <WeightEntry>[
        WeightEntry(
          id: '1',
          weight: 75.0,
          date: now.subtract(const Duration(days: 1)),
        ),
        WeightEntry(
          id: '2',
          weight: 74.2,
          date: now,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackerPage(
          onToggleTheme: () {},
          isDarkMode: true,
          weightStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('currentWeightDisplay')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('currentWeightDisplay'))).data, '74.2');
    expect(find.byKey(const Key('weightDeltaBadge')), findsOneWidget);
    expect(find.text('-0.8 kg'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('2 recorded'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2 recorded'), findsOneWidget);
  });

  testWidgets('User can edit an existing weight entry', (WidgetTester tester) async {
    final WeightEntry entry = WeightEntry(
      id: 'entry_to_edit',
      weight: 75.0,
      date: DateTime.now(),
      note: 'Initial note',
    );
    final InMemoryWeightStorage storage = InMemoryWeightStorage(
      initialEntries: <WeightEntry>[entry],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackerPage(
          onToggleTheme: () {},
          isDarkMode: true,
          weightStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to tile if needed and tap
    final Finder tileFinder = find.byKey(const Key('weightEntryTile_entry_to_edit'));
    await tester.scrollUntilVisible(
      tileFinder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    expect(find.text('Edit Weigh-in'), findsOneWidget);

    // Update weight
    await tester.enterText(find.byKey(const Key('weightInputField')), '74.0');
    // Save
    await tester.tap(find.byKey(const Key('saveWeightEntryButton')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('currentWeightDisplay')),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('currentWeightDisplay')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('currentWeightDisplay'))).data, '74.0');
    expect(find.text('Updated to 74.0 kg.'), findsOneWidget);
  });

  testWidgets('User can delete a weight entry via edit modal', (WidgetTester tester) async {
    final WeightEntry entry = WeightEntry(
      id: 'entry_to_delete',
      weight: 75.0,
      date: DateTime.now(),
    );
    final InMemoryWeightStorage storage = InMemoryWeightStorage(
      initialEntries: <WeightEntry>[entry],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackerPage(
          onToggleTheme: () {},
          isDarkMode: true,
          weightStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder countFinder = find.text('1 recorded');
    await tester.scrollUntilVisible(
      countFinder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(countFinder, findsOneWidget);

    // Open edit modal
    final Finder tileFinder = find.byKey(const Key('weightEntryTile_entry_to_delete'));
    await tester.scrollUntilVisible(
      tileFinder,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    // Tap delete button
    await tester.tap(find.byKey(const Key('deleteWeightEntryButton')));
    await tester.pumpAndSettle();

    expect(find.text('Weigh-in deleted.'), findsOneWidget);
    expect(find.text('0 recorded'), findsOneWidget);
  });

  testWidgets('User can configure goals and see progress and BMI', (WidgetTester tester) async {
    final InMemoryWeightStorage storage = InMemoryWeightStorage(
      initialEntries: <WeightEntry>[
        WeightEntry(
          id: '1',
          weight: 75.0,
          date: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackerPage(
          onToggleTheme: () {},
          isDarkMode: true,
          weightStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open goal modal
    await tester.tap(find.byKey(const Key('openGoalModalButton')));
    await tester.pumpAndSettle();

    expect(find.text('Weight Goals & Metrics'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('targetWeightInputField')), '70.0');
    await tester.enterText(find.byKey(const Key('startingWeightInputField')), '80.0');
    await tester.enterText(find.byKey(const Key('heightInputField')), '175');

    await tester.tap(find.byKey(const Key('saveGoalButton')));
    await tester.pumpAndSettle();

    expect(find.text('Weight goal updated.'), findsOneWidget);
    expect(find.byKey(const Key('weightGoalProgressBar')), findsOneWidget);
    expect(find.text('Goal: 70.0 kg'), findsOneWidget);
    expect(find.text('5.0 kg to go'), findsOneWidget);
    expect(find.text('24.5 (Normal)'), findsOneWidget);
  });

  testWidgets('User can switch time range filters on the weight chart', (WidgetTester tester) async {
    final DateTime now = DateTime.now();
    final InMemoryWeightStorage storage = InMemoryWeightStorage(
      initialEntries: <WeightEntry>[
        WeightEntry(id: '1', weight: 75.0, date: now.subtract(const Duration(days: 15))),
        WeightEntry(id: '2', weight: 74.0, date: now.subtract(const Duration(days: 2))),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WeightTrackerPage(
          onToggleTheme: () {},
          isDarkMode: true,
          weightStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap 7D filter
    await tester.tap(find.byKey(const Key('rangeFilter_sevenDays')));
    await tester.pumpAndSettle();

    // Tap 90D filter
    await tester.tap(find.byKey(const Key('rangeFilter_ninetyDays')));
    await tester.pumpAndSettle();

    // Tap ALL filter
    await tester.tap(find.byKey(const Key('rangeFilter_all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weightChartCard')), findsOneWidget);
  });

  testWidgets('Bottom navigation bar switches between Calories and Weight tabs in MacroTrackerApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MacroTrackerApp());
    await tester.pumpAndSettle();

    // Verify initial tab is Calories
    expect(find.text("Today's Calories"), findsOneWidget);
    expect(find.byKey(const Key('mainBottomNavigationBar')), findsOneWidget);

    // Switch to Weight tab
    await tester.tap(find.byKey(const Key('navDestinationWeight')));
    await tester.pumpAndSettle();

    expect(find.text('Weight Tracker'), findsOneWidget);
    expect(find.byKey(const Key('heroWeightCard')), findsOneWidget);

    // Switch back to Calories tab
    await tester.tap(find.byKey(const Key('navDestinationCalories')));
    await tester.pumpAndSettle();

    expect(find.text("Today's Calories"), findsOneWidget);
  });
}
