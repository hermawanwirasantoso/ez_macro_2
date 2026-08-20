import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/theme/app_theme.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/stored_food_portion_modal.dart';

void main() {
  group('StoredFoodPortionModal Widget Tests', () {
    final SavedFood testSalmon = SavedFood(
      id: 'saved_salmon_1',
      name: 'Atlantic Salmon',
      calories: 300,
      proteinG: 30,
      carbsG: 0,
      fatG: 20,
      saturatedFatG: 4,
      fiberG: 0,
      addedSugarG: 0,
      sodiumMg: 120,
      portionSize: 150,
      portionUnit: 'g',
    );

    testWidgets('renders all stored food details and base nutrition properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () => StoredFoodPortionModal.show(
                    context,
                    food: testSalmon,
                    defaultMealType: MealType.dinner,
                  ),
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('portionModalFoodTitle')), findsOneWidget);
      expect(find.text('Atlantic Salmon'), findsOneWidget);
      expect(find.text('Stored Food • No API Call'), findsOneWidget);

      expect(find.byKey(const Key('portionModalCaloriesText')), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);

      expect(find.text('30 g'), findsOneWidget);
      expect(find.text('0 g'), findsOneWidget);
      expect(find.text('20 g'), findsOneWidget);
      expect(find.text('Sat Fat: 4g'), findsOneWidget);
      expect(find.text('Sodium: 120mg'), findsOneWidget);

      expect(find.text('Base: 150 g'), findsWidgets);
      expect(
        tester.widget<TextField>(find.byKey(const Key('portionModalQuantityField'))).controller?.text,
        '150',
      );
    });

    testWidgets('allows adding food as-is with default portion',
        (WidgetTester tester) async {
      FoodLogEntry? loggedEntry;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () async {
                    loggedEntry = await StoredFoodPortionModal.show(
                      context,
                      food: testSalmon,
                      defaultMealType: MealType.dinner,
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Tap confirm button immediately without editing
      await tester.tap(find.byKey(const Key('confirmAddStoredFoodButton')));
      await tester.pumpAndSettle();

      expect(loggedEntry, isNotNull);
      expect(loggedEntry!.mealLabel, 'Atlantic Salmon');
      expect(loggedEntry!.calories, 300);
      expect(loggedEntry!.proteinG, 30);
      expect(loggedEntry!.fatG, 20);
      expect(loggedEntry!.portionSize, 150.0);
      expect(loggedEntry!.portionUnit, 'g');
      expect(loggedEntry!.mealType, MealType.dinner);
      expect(loggedEntry!.sourceLabel, 'Saved');
    });

    testWidgets('scales calories and macros dynamically with quick multiplier chips',
        (WidgetTester tester) async {
      FoodLogEntry? loggedEntry;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () async {
                    loggedEntry = await StoredFoodPortionModal.show(
                      context,
                      food: testSalmon,
                      defaultMealType: MealType.lunch,
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Select 2x multiplier
      await tester.tap(find.byKey(const Key('portionModalChip_2')));
      await tester.pumpAndSettle();

      expect(find.text('600'), findsWidgets);
      expect(find.text('60 g'), findsOneWidget); // Protein
      expect(find.text('40 g'), findsOneWidget); // Fat
      expect(find.text('Sat Fat: 8g'), findsOneWidget);
      expect(find.text('Sodium: 240mg'), findsOneWidget);
      expect(find.text('200% of base'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmAddStoredFoodButton')));
      await tester.pumpAndSettle();

      expect(loggedEntry, isNotNull);
      expect(loggedEntry!.calories, 600);
      expect(loggedEntry!.proteinG, 60);
      expect(loggedEntry!.fatG, 40);
      expect(loggedEntry!.portionSize, 300.0);
      expect(loggedEntry!.mealType, MealType.lunch);
    });

    testWidgets('allows adjusting portion size with steppers and manual text input',
        (WidgetTester tester) async {
      FoodLogEntry? loggedEntry;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () async {
                    loggedEntry = await StoredFoodPortionModal.show(
                      context,
                      food: testSalmon,
                      defaultMealType: MealType.breakfast,
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Tap decrement stepper (-25g for 150g -> 125g)
      await tester.tap(find.byKey(const Key('portionModalDecrementButton')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byKey(const Key('portionModalQuantityField'))).controller?.text,
        '125',
      );

      // Enter manual text '225'
      await tester.enterText(find.byKey(const Key('portionModalQuantityField')), '225');
      await tester.pumpAndSettle();

      // 225 / 150 = 1.5x -> 450 kcal
      expect(find.text('450'), findsWidgets);
      expect(find.text('45 g'), findsOneWidget);

      // Change meal type to snack
      await tester.tap(find.byKey(const Key('portionModalMealType_snack')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmAddStoredFoodButton')));
      await tester.pumpAndSettle();

      expect(loggedEntry, isNotNull);
      expect(loggedEntry!.calories, 450);
      expect(loggedEntry!.portionSize, 225.0);
      expect(loggedEntry!.mealType, MealType.snack);
    });

    testWidgets('shows validation error when entering non-positive portion',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () => StoredFoodPortionModal.show(
                    context,
                    food: testSalmon,
                  ),
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('portionModalQuantityField')), '0');
      await tester.pumpAndSettle();

      expect(find.text('Please enter a portion greater than 0.'), findsOneWidget);
    });

    testWidgets('triggers full edit callback when tapping Edit Details button',
        (WidgetTester tester) async {
      bool fullEditOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(isDarkMode: true),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () => StoredFoodPortionModal.show(
                    context,
                    food: testSalmon,
                    onOpenFullEdit: () {
                      fullEditOpened = true;
                    },
                  ),
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullEditStoredFoodButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fullEditStoredFoodButton')));
      await tester.pumpAndSettle();

      expect(fullEditOpened, isTrue);
    });
  });
}
