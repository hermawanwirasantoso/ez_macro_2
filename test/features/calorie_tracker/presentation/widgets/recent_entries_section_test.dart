import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/recent_entries_section.dart';

void main() {
  testWidgets('RecentEntriesSection shows search bar when >= 3 entries and filters list',
      (WidgetTester tester) async {
    final List<FoodLogEntry> entries = <FoodLogEntry>[
      FoodLogEntry(id: '1', mealLabel: 'Scrambled Eggs', calories: 220, proteinG: 14, carbsG: 2, fatG: 16, mealType: MealType.breakfast),
      FoodLogEntry(id: '2', mealLabel: 'Chicken Salad', calories: 350, proteinG: 35, carbsG: 12, fatG: 10, mealType: MealType.lunch),
      FoodLogEntry(id: '3', mealLabel: 'Steak with Asparagus', calories: 500, proteinG: 45, carbsG: 5, fatG: 25, mealType: MealType.dinner),
    ];

    int? removedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecentEntriesSection(
              entries: entries,
              onRemoveEntry: (int index) => removedIndex = index,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('searchEntriesInput')), findsOneWidget);
    expect(find.textContaining('Scrambled Eggs'), findsOneWidget);
    expect(find.textContaining('Chicken Salad'), findsOneWidget);
    expect(find.textContaining('Steak with Asparagus'), findsOneWidget);

    // Search for "Chicken"
    await tester.enterText(find.byKey(const Key('searchEntriesInput')), 'Chicken');
    await tester.pumpAndSettle();

    expect(find.textContaining('Chicken Salad'), findsOneWidget);
    expect(find.textContaining('Scrambled Eggs'), findsNothing);
    expect(find.textContaining('Steak with Asparagus'), findsNothing);

    // Delete filtered entry (original index = 1)
    await tester.tap(find.byKey(const Key('removeEntryButton_1')));
    await tester.pumpAndSettle();
    expect(removedIndex, 1);

    // Search for non-existent item
    await tester.enterText(find.byKey(const Key('searchEntriesInput')), 'Pizza');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('noMatchingRecentEntriesBox')), findsOneWidget);

    // Clear search
    await tester.tap(find.byKey(const Key('clearSearchEntriesButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Scrambled Eggs'), findsOneWidget);
    expect(find.textContaining('Chicken Salad'), findsOneWidget);
    expect(find.textContaining('Steak with Asparagus'), findsOneWidget);
  });
}
