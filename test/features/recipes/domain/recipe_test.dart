import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe_ingredient.dart';

void main() {
  group('RecipeIngredient', () {
    test('creates ingredient correctly and handles scaling', () {
      final RecipeIngredient ing = RecipeIngredient(
        name: 'Rolled Oats',
        calories: 300,
        proteinG: 10,
        carbsG: 54,
        fatG: 5,
        portionSize: 80,
        portionUnit: 'g',
      );

      expect(ing.portionDisplay, '80 g');

      final RecipeIngredient scaled = ing.scaledBy(1.5);
      expect(scaled.calories, 450);
      expect(scaled.proteinG, 15);
      expect(scaled.carbsG, 81);
      expect(scaled.portionSize, 120.0);
    });

    test('creates ingredient from SavedFood with multiplier', () {
      final SavedFood saved = SavedFood(
        name: 'Whey Protein',
        calories: 120,
        proteinG: 24,
        carbsG: 2,
        fatG: 1,
        portionSize: 1,
        portionUnit: 'scoop',
      );

      final RecipeIngredient ing = RecipeIngredient.fromSavedFood(saved, multiplier: 2.0);
      expect(ing.name, 'Whey Protein');
      expect(ing.calories, 240);
      expect(ing.proteinG, 48);
      expect(ing.portionSize, 2.0);
      expect(ing.portionDisplay, '2 scoops');
    });

    test('withAmount rescales from the saved food without compounding rounding', () {
      final SavedFood chicken = SavedFood(
        name: 'Chicken Breast',
        calories: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 4,
        portionSize: 100,
        portionUnit: 'g',
      );

      final RecipeIngredient tiny = RecipeIngredient.fromSavedFood(chicken).withAmount(1);
      expect(tiny.calories, 2);
      expect(tiny.proteinG, 0);

      final RecipeIngredient big = tiny.withAmount(250);
      expect(big.portionSize, 250);
      expect(big.portionDisplay, '250 g');
      expect(big.calories, 413);
      expect(big.proteinG, 78);
      expect(big.fatG, 10);
      expect(big.id, tiny.id);
    });

    test('withAmount on an ingredient without a base food uses its own values as reference', () {
      final RecipeIngredient rice = RecipeIngredient(
        name: 'Cooked Rice',
        calories: 130,
        carbsG: 28,
        portionSize: 100,
        portionUnit: 'g',
      );

      final RecipeIngredient scaled = rice.withAmount(5).withAmount(300);
      expect(scaled.calories, 390);
      expect(scaled.carbsG, 84);
      expect(scaled.baseFood.portionSize, 100);
    });

    test('serializes base food to and from JSON, and loads ingredients saved without one', () {
      final RecipeIngredient ing = RecipeIngredient.fromSavedFood(
        SavedFood(name: 'Oats', calories: 380, proteinG: 13, carbsG: 68, fatG: 7, portionSize: 100, portionUnit: 'g'),
      ).withAmount(60);

      final RecipeIngredient restored = RecipeIngredient.fromJson(ing.toJson());
      expect(restored.calories, 228);
      expect(restored.baseFood.portionSize, 100);
      expect(restored.baseFood.calories, 380);
      expect(restored.withAmount(80).calories, 304);

      final RecipeIngredient legacy = RecipeIngredient.fromMap(<String, dynamic>{
        'name': 'Honey',
        'calories': 60,
        'carbsG': 17,
        'portionSize': 20,
        'portionUnit': 'g',
      });
      expect(legacy.toMap().containsKey('baseFood'), isFalse);
      expect(legacy.withAmount(40).calories, 120);
    });

    test('serializes to and from JSON', () {
      final RecipeIngredient ing = RecipeIngredient(
        name: 'Peanut Butter',
        calories: 190,
        proteinG: 8,
        carbsG: 6,
        fatG: 16,
        portionSize: 32,
        portionUnit: 'g',
      );

      final String jsonStr = ing.toJson();
      final RecipeIngredient restored = RecipeIngredient.fromJson(jsonStr);

      expect(restored.name, 'Peanut Butter');
      expect(restored.calories, 190);
      expect(restored.proteinG, 8);
      expect(restored.carbsG, 6);
      expect(restored.fatG, 16);
      expect(restored.portionSize, 32.0);
      expect(restored.portionUnit, 'g');
    });
  });

  group('Recipe', () {
    test('computes total batch and per-serving macros accurately', () {
      final Recipe recipe = Recipe(
        name: 'Protein Oatmeal Batch',
        servings: 2,
        ingredients: <RecipeIngredient>[
          RecipeIngredient(
            name: 'Oats',
            calories: 300,
            proteinG: 10,
            carbsG: 54,
            fatG: 5,
            fiberG: 8,
          ),
          RecipeIngredient(
            name: 'Whey Protein',
            calories: 240,
            proteinG: 48,
            carbsG: 4,
            fatG: 2,
            fiberG: 0,
          ),
          RecipeIngredient(
            name: 'Peanut Butter',
            calories: 190,
            proteinG: 8,
            carbsG: 6,
            fatG: 16,
            fiberG: 2,
          ),
        ],
      );

      // Total Batch (300 + 240 + 190 = 730 kcal)
      expect(recipe.totalCalories, 730);
      expect(recipe.totalProteinG, 66); // 10 + 48 + 8
      expect(recipe.totalCarbsG, 64);   // 54 + 4 + 6
      expect(recipe.totalFatG, 23);     // 5 + 2 + 16
      expect(recipe.totalFiberG, 10);   // 8 + 0 + 2

      // Per Serving (Divided by 2)
      expect(recipe.caloriesPerServing, 365); // 730 / 2
      expect(recipe.proteinPerServing, 33);   // 66 / 2
      expect(recipe.carbsPerServing, 32);     // 64 / 2
      expect(recipe.fatPerServing, 12);       // 23 / 2 (round)
      expect(recipe.fiberPerServing, 5);      // 10 / 2
    });

    test('toFoodLogEntry creates log entry scaled by logged servings', () {
      final Recipe recipe = Recipe(
        name: 'Meal Prep Chicken Bowl',
        servings: 4,
        ingredients: <RecipeIngredient>[
          RecipeIngredient(name: 'Chicken', calories: 800, proteinG: 120, carbsG: 0, fatG: 20),
          RecipeIngredient(name: 'Rice', calories: 800, proteinG: 16, carbsG: 180, fatG: 4),
        ],
      );

      expect(recipe.caloriesPerServing, 400); // 1600 / 4
      expect(recipe.proteinPerServing, 34);   // 136 / 4

      final FoodLogEntry singleServing = recipe.toFoodLogEntry(
        loggedServings: 1.0,
        mealType: MealType.lunch,
      );
      expect(singleServing.mealLabel, 'Meal Prep Chicken Bowl');
      expect(singleServing.calories, 400);
      expect(singleServing.proteinG, 34);
      expect(singleServing.mealType, MealType.lunch);

      final FoodLogEntry doubleServing = recipe.toFoodLogEntry(
        loggedServings: 2.0,
      );
      expect(doubleServing.calories, 800);
      expect(doubleServing.proteinG, 68);
    });

    test('serializes to and from JSON', () {
      final Recipe recipe = Recipe(
        name: 'Berry Shake',
        description: 'Post workout smoothie',
        servings: 1,
        ingredients: <RecipeIngredient>[
          RecipeIngredient(name: 'Milk', calories: 150, proteinG: 8, carbsG: 12, fatG: 8),
          RecipeIngredient(name: 'Berries', calories: 70, proteinG: 1, carbsG: 15, fatG: 0),
        ],
      );

      final String jsonStr = recipe.toJson();
      final Recipe restored = Recipe.fromJson(jsonStr);

      expect(restored.name, 'Berry Shake');
      expect(restored.description, 'Post workout smoothie');
      expect(restored.servings, 1);
      expect(restored.ingredients.length, 2);
      expect(restored.totalCalories, 220);
    });
  });
}
