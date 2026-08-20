import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/food_entry_modal.dart';

void main() {
  Widget buildTestHost(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('FoodEntryModal', () {
    testWidgets('renders add modal with empty fields and default meal type', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          const FoodEntryModal(initialMealType: MealType.breakfast),
        ),
      );

      expect(find.text('Quick Add Food'), findsOneWidget);
      expect(find.byKey(const Key('mealLabelField')), findsOneWidget);
      expect(find.byKey(const Key('caloriesField')), findsOneWidget);
      expect(find.byKey(const Key('proteinField')), findsOneWidget);
      expect(find.byKey(const Key('carbsField')), findsOneWidget);
      expect(find.byKey(const Key('fatField')), findsOneWidget);
      expect(find.text('Log Food'), findsOneWidget);
    });

    testWidgets('calculates calories from macros helper button', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          const FoodEntryModal(initialMealType: MealType.lunch),
        ),
      );

      // Enter protein: 30g (120 kcal), carbs: 40g (160 kcal), fat: 10g (90 kcal) => 370 kcal
      await tester.enterText(find.byKey(const Key('proteinField')), '30');
      await tester.enterText(find.byKey(const Key('carbsField')), '40');
      await tester.enterText(find.byKey(const Key('fatField')), '10');

      await tester.tap(find.byKey(const Key('calcCaloriesFromMacrosButton')));
      await tester.pumpAndSettle();

      final TextField caloriesInput = tester.widget<TextField>(find.byKey(const Key('caloriesField')));
      expect(caloriesInput.controller?.text, '370');
    });

    testWidgets('selecting a saved food fills all reusable nutrition fields', (WidgetTester tester) async {
      final SavedFood savedFood = SavedFood(
        id: 'saved_oats',
        name: 'Overnight Oats',
        calories: 380,
        proteinG: 20,
        carbsG: 48,
        fatG: 12,
      );

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            initialMealType: MealType.breakfast,
            savedFoods: <SavedFood>[savedFood],
            onSaveFood: (_) async {},
            onDeleteSavedFood: (_) async {},
          ),
        ),
      );

      expect(find.text('Saved Foods'), findsOneWidget);
      expect(find.text('Overnight Oats'), findsOneWidget);

      await tester.tap(find.byKey(const Key('savedFoodTile_saved_oats')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byKey(const Key('mealLabelField'))).controller?.text,
        'Overnight Oats',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '380',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '20',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('carbsField'))).controller?.text,
        '48',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '12',
      );
    });

    testWidgets('saving a new food invokes the future-use callback with custom portion', (WidgetTester tester) async {
      SavedFood? savedFood;

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            onSaveFood: (SavedFood food) async {
              savedFood = food;
            },
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('mealLabelField')), 'Homemade Burrito');
      await tester.enterText(find.byKey(const Key('caloriesField')), '540');
      await tester.enterText(find.byKey(const Key('proteinField')), '32');
      await tester.enterText(find.byKey(const Key('carbsField')), '58');
      await tester.enterText(find.byKey(const Key('fatField')), '18');
      await tester.ensureVisible(find.byKey(const Key('saveForFutureUseCheckbox')));
      await tester.tap(find.byKey(const Key('saveForFutureUseCheckbox')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('portionSizeField')), findsOneWidget);
      expect(find.byKey(const Key('portionUnitField')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('portionSizeField')), '1.5');
      await tester.enterText(find.byKey(const Key('portionUnitField')), 'wrap');

      await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
      await tester.tap(find.byKey(const Key('saveEntryButton')));
      await tester.pumpAndSettle();

      expect(savedFood, isNotNull);
      expect(savedFood!.name, 'Homemade Burrito');
      expect(savedFood!.calories, 540);
      expect(savedFood!.proteinG, 32);
      expect(savedFood!.carbsG, 58);
      expect(savedFood!.fatG, 18);
      expect(savedFood!.portionSize, 1.5);
      expect(savedFood!.portionUnit, 'wrap');
      expect(savedFood!.portionDisplay, '1.5 wrap');
    });

    testWidgets('selecting a saved food renders portion selector and scales with chips', (WidgetTester tester) async {
      final SavedFood savedFood = SavedFood(
        id: 'saved_oats',
        name: 'Overnight Oats',
        calories: 380,
        proteinG: 20,
        carbsG: 48,
        fatG: 12,
        portionSize: 1.0,
        portionUnit: 'serving',
      );

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            initialMealType: MealType.breakfast,
            savedFoods: <SavedFood>[savedFood],
            onSaveFood: (_) async {},
            onDeleteSavedFood: (_) async {},
          ),
        ),
      );

      expect(find.byKey(const Key('portionSelectorCard')), findsNothing);

      await tester.tap(find.byKey(const Key('savedFoodTile_saved_oats')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('portionSelectorCard')), findsOneWidget);
      expect(find.text('Base: 1 serving'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('portionInputField'))).controller?.text,
        '1',
      );

      // Select 2x chip -> calories = 760, protein = 40, carbs = 96, fat = 24
      await tester.tap(find.byKey(const Key('portionChip_2')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byKey(const Key('portionInputField'))).controller?.text,
        '2',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '760',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '40',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('carbsField'))).controller?.text,
        '96',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '24',
      );

      // Select 0.5x chip -> calories = 190, protein = 10, carbs = 24, fat = 6
      await tester.tap(find.byKey(const Key('portionChip_0.5')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byKey(const Key('portionInputField'))).controller?.text,
        '0.5',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '190',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '10',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('carbsField'))).controller?.text,
        '24',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '6',
      );
    });

    testWidgets('stepper and direct input adjust portion and recalculate macros', (WidgetTester tester) async {
      final SavedFood savedFood = SavedFood(
        id: 'saved_chicken',
        name: 'Chicken Breast',
        calories: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 4,
        portionSize: 100.0,
        portionUnit: 'g',
      );

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            initialMealType: MealType.dinner,
            savedFoods: <SavedFood>[savedFood],
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('savedFoodTile_saved_chicken')));
      await tester.pumpAndSettle();

      expect(find.text('Base: 100 g'), findsOneWidget);

      // Tap Increment button (+25g for 100g base -> 125g)
      await tester.tap(find.byKey(const Key('portionIncrementButton')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byKey(const Key('portionInputField'))).controller?.text,
        '125',
      );
      // 165 * 1.25 = 206 kcal, protein: 31 * 1.25 = 39, carbs: 0, fat: 4 * 1.25 = 5
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '206',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '39',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '5',
      );

      // Manually enter 200g
      await tester.enterText(find.byKey(const Key('portionInputField')), '200');
      await tester.pumpAndSettle();

      // 165 * 2 = 330 kcal, protein: 62, fat: 8
      expect(
        tester.widget<TextField>(find.byKey(const Key('caloriesField'))).controller?.text,
        '330',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('proteinField'))).controller?.text,
        '62',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('fatField'))).controller?.text,
        '8',
      );
    });

    testWidgets('shows validation error when food name or calories is missing', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHost(
          const FoodEntryModal(),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
      await tester.tap(find.byKey(const Key('saveEntryButton')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a food or meal name.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('mealLabelField')), 'Greek Yogurt');
      await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
      await tester.tap(find.byKey(const Key('saveEntryButton')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter valid calories (> 0).'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('caloriesField')), '100');
      await tester.enterText(find.byKey(const Key('proteinField')), '-1');
      await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
      await tester.tap(find.byKey(const Key('saveEntryButton')));
      await tester.pumpAndSettle();

      expect(find.text('Macro values cannot be negative.'), findsOneWidget);
    });

    testWidgets('renders edit modal with populated fields and delete button', (WidgetTester tester) async {
      final FoodLogEntry existing = FoodLogEntry(
        id: 'entry_123',
        mealLabel: 'Avocado Toast',
        calories: 320,
        proteinG: 10,
        carbsG: 35,
        fatG: 16,
        portionSize: 2.0,
        portionUnit: 'slices',
        mealType: MealType.breakfast,
      );

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(initialEntry: existing),
        ),
      );

      expect(find.text('Edit Meal'), findsOneWidget);
      expect(find.byKey(const Key('deleteEntryModalButton')), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.byKey(const Key('portionSelectorCard')), findsOneWidget);
      expect(find.text('Base: 2 slices'), findsOneWidget);

      final TextField nameField = tester.widget<TextField>(find.byKey(const Key('mealLabelField')));
      final TextField calField = tester.widget<TextField>(find.byKey(const Key('caloriesField')));
      final TextField portionField = tester.widget<TextField>(find.byKey(const Key('portionInputField')));

      expect(nameField.controller?.text, 'Avocado Toast');
      expect(calField.controller?.text, '320');
      expect(portionField.controller?.text, '2');
    });

    testWidgets('allows saving an edited entry as custom reusable food', (WidgetTester tester) async {
      SavedFood? savedFood;

      final FoodLogEntry existing = FoodLogEntry(
        id: 'entry_salmon',
        mealLabel: 'Salmon Rice Bowl',
        calories: 550,
        proteinG: 40,
        carbsG: 60,
        fatG: 15,
        portionSize: 1.0,
        portionUnit: 'bowl',
        mealType: MealType.dinner,
      );

      await tester.pumpWidget(
        buildTestHost(
          FoodEntryModal(
            initialEntry: existing,
            onSaveFood: (SavedFood food) async {
              savedFood = food;
            },
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('saveForFutureUseCheckbox')));
      await tester.tap(find.byKey(const Key('saveForFutureUseCheckbox')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('portionSizeField')));
      expect(find.byKey(const Key('portionSizeField')), findsOneWidget);
      expect(find.byKey(const Key('portionUnitField')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('portionUnitField')), 'bowl');

      await tester.ensureVisible(find.byKey(const Key('saveEntryButton')));
      await tester.tap(find.byKey(const Key('saveEntryButton')));
      await tester.pumpAndSettle();

      expect(savedFood, isNotNull);
      expect(savedFood!.name, 'Salmon Rice Bowl');
      expect(savedFood!.calories, 550);
      expect(savedFood!.proteinG, 40);
      expect(savedFood!.portionUnit, 'bowl');
    });
  });
}
