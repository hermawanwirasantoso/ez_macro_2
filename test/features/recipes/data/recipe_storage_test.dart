import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/recipes/data/recipe_storage.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe_ingredient.dart';

void main() {
  group('InMemoryRecipeStorage', () {
    late InMemoryRecipeStorage storage;

    setUp(() {
      storage = InMemoryRecipeStorage();
    });

    test('saves, loads, updates, and deletes recipes', () async {
      expect(await storage.loadRecipes(), isEmpty);

      final Recipe recipe1 = Recipe(
        id: 'r1',
        name: 'Avocado Toast',
        servings: 1,
        ingredients: <RecipeIngredient>[
          RecipeIngredient(name: 'Bread', calories: 160, carbsG: 30, proteinG: 6, fatG: 2),
          RecipeIngredient(name: 'Avocado', calories: 240, carbsG: 12, proteinG: 3, fatG: 22),
        ],
      );

      await storage.saveRecipe(recipe1);
      List<Recipe> list = await storage.loadRecipes();
      expect(list.length, 1);
      expect(list.first.name, 'Avocado Toast');
      expect(list.first.totalCalories, 400);

      // Update recipe
      final Recipe updated = recipe1.copyWith(
        name: 'Avocado Toast with Egg',
        ingredients: <RecipeIngredient>[
          ...recipe1.ingredients,
          RecipeIngredient(name: 'Egg', calories: 70, proteinG: 6, fatG: 5),
        ],
      );
      await storage.saveRecipe(updated);
      list = await storage.loadRecipes();
      expect(list.length, 1);
      expect(list.first.name, 'Avocado Toast with Egg');
      expect(list.first.totalCalories, 470);

      // Delete recipe
      await storage.deleteRecipe('r1');
      list = await storage.loadRecipes();
      expect(list, isEmpty);
    });

    test('clearAll removes all recipes', () async {
      await storage.saveRecipe(Recipe(id: 'r1', name: 'Meal 1'));
      await storage.saveRecipe(Recipe(id: 'r2', name: 'Meal 2'));

      expect((await storage.loadRecipes()).length, 2);

      await storage.clearAll();
      expect(await storage.loadRecipes(), isEmpty);
    });
  });
}
