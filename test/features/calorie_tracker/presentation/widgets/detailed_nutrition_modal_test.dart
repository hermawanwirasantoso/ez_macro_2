import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/domain/tracker_state.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/theme/app_theme.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/detailed_nutrition_modal.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/hero_calorie_card.dart';

void main() {
  Widget buildTestWidget({
    required CalorieTrackerState state,
    bool isDark = true,
  }) {
    return MaterialApp(
      theme: AppTheme.getTheme(isDarkMode: isDark),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Center(
              child: ElevatedButton(
                key: const Key('openModalButton'),
                onPressed: () {
                  DetailedNutritionModal.show(context, trackerState: state);
                },
                child: const Text('Open Modal'),
              ),
            );
          },
        ),
      ),
    );
  }

  group('DetailedNutritionModal', () {
    testWidgets('renders all detailed nutrition cards and entries breakdown', (
      WidgetTester tester,
    ) async {
      final CalorieTrackerState state = CalorieTrackerState(
        dailyGoal: 2000,
        targetProteinG: 150,
        targetCarbsG: 200,
        targetFatG: 60,
      );

      state.addCalories(
        calories: 550,
        mealLabel: 'Avocado Toast & Eggs',
        proteinG: 24,
        carbsG: 45,
        fatG: 22,
        saturatedFatG: 5,
        fiberG: 9,
        addedSugarG: 2,
        sodiumMg: 480,
        mealType: MealType.breakfast,
      );

      state.addCalories(
        calories: 650,
        mealLabel: 'Salmon Rice Bowl',
        proteinG: 42,
        carbsG: 65,
        fatG: 18,
        saturatedFatG: 4,
        fiberG: 5,
        addedSugarG: 3,
        sodiumMg: 620,
        mealType: MealType.lunch,
      );

      await tester.pumpWidget(buildTestWidget(state: state));
      await tester.tap(find.byKey(const Key('openModalButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detailedNutritionSheet')), findsOneWidget);
      expect(find.text('Detailed Nutrition'), findsOneWidget);

      // Primary macros summary
      expect(find.text('1200 / 2000 kcal'), findsOneWidget);
      expect(find.text('66g'), findsOneWidget); // Total Protein
      expect(find.text('110g'), findsOneWidget); // Total Carbs
      expect(find.text('40g'), findsOneWidget); // Total Fat

      // Detailed nutrients
      expect(find.byKey(const Key('detailedSaturatedFatRow')), findsOneWidget);
      expect(find.text('Saturated Fat'), findsOneWidget);
      expect(find.text('9 g'), findsOneWidget); // 5 + 4

      expect(find.byKey(const Key('detailedFiberRow')), findsOneWidget);
      expect(find.text('Dietary Fiber'), findsOneWidget);
      expect(find.text('14 g'), findsOneWidget); // 9 + 5

      expect(find.byKey(const Key('detailedAddedSugarRow')), findsOneWidget);
      expect(find.text('Added Sugar'), findsOneWidget);
      expect(find.text('5 g'), findsOneWidget); // 2 + 3

      expect(find.byKey(const Key('detailedSodiumRow')), findsOneWidget);
      expect(find.text('Sodium'), findsOneWidget);
      expect(find.text('1100 mg'), findsOneWidget); // 480 + 620

      // Entries breakdown
      final Finder item1 = find.byKey(const Key('detailedEntryItem_1'));
      await tester.scrollUntilVisible(
        item1,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Entries Breakdown (2)'), findsOneWidget);
      expect(find.byKey(const Key('detailedEntryItem_0')), findsOneWidget);
      expect(item1, findsOneWidget);
      expect(find.text('Salmon Rice Bowl'), findsOneWidget);
      expect(find.text('Avocado Toast & Eggs'), findsOneWidget);
    });

    testWidgets('shows empty state when no entries exist', (
      WidgetTester tester,
    ) async {
      final CalorieTrackerState emptyState = CalorieTrackerState(
        dailyGoal: 2200,
      );

      await tester.pumpWidget(buildTestWidget(state: emptyState));
      await tester.tap(find.byKey(const Key('openModalButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detailedNutritionSheet')), findsOneWidget);
      final Finder emptyText = find.text('No food entries logged for this date.');
      await tester.scrollUntilVisible(
        emptyText,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(emptyText, findsOneWidget);
      expect(find.text('0 g'), findsNWidgets(3)); // Sat fat, fiber, added sugar
      expect(find.text('0 mg'), findsOneWidget); // Sodium
    });

    testWidgets('close button dismisses the bottom sheet', (
      WidgetTester tester,
    ) async {
      final CalorieTrackerState state = CalorieTrackerState();
      await tester.pumpWidget(buildTestWidget(state: state));
      await tester.tap(find.byKey(const Key('openModalButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detailedNutritionSheet')), findsOneWidget);

      await tester.tap(find.byKey(const Key('closeDetailedNutritionButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detailedNutritionSheet')), findsNothing);
    });

    testWidgets('HeroCalorieCard Detailed Nutrition button triggers callback', (
      WidgetTester tester,
    ) async {
      bool opened = false;
      final CalorieTrackerState state = CalorieTrackerState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroCalorieCard(
                trackerState: state,
                showSpreadDetails: false,
                onToggleSpread: (_) {},
                onOpenTargetEditor: () {},
                onOpenDetailedNutrition: () {
                  opened = true;
                },
              ),
            ),
          ),
        ),
      );

      final Finder button = find.byKey(const Key('detailedNutritionButton'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });
  });
}
