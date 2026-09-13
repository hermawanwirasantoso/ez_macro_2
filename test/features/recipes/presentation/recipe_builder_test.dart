import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/food_entry_modal.dart';
import 'package:ez_macro_2/features/recipes/data/recipe_storage.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe_ingredient.dart';
import 'package:ez_macro_2/features/recipes/presentation/recipe_builder_modal.dart';
import 'package:ez_macro_2/features/recipes/presentation/recipe_list_modal.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/main.dart';

void main() {
  testWidgets('RecipeBuilderModal creates recipe, adds ingredients, updates live macros, and saves',
      (WidgetTester tester) async {
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => RecipeBuilderModal.show(
                context,
                recipeStorage: recipeStorage,
                savedFoods: <SavedFood>[
                  SavedFood(
                    name: 'Whey Protein',
                    calories: 120,
                    proteinG: 24,
                    carbsG: 2,
                    fatG: 1,
                    portionSize: 1,
                    portionUnit: 'scoop',
                  ),
                ],
              ),
              child: const Text('Open Builder'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Builder'));
    await tester.pumpAndSettle();

    expect(find.text('Recipe Builder'), findsOneWidget);

    // Enter Recipe Name
    await tester.enterText(find.byKey(const Key('recipeNameInput')), 'Post Workout Shake');
    await tester.pumpAndSettle();

    // Increase Servings to 2
    await tester.tap(find.byKey(const Key('recipeIncreaseServingsBtn')));
    await tester.pumpAndSettle();
    expect(find.text('2 servings'), findsOneWidget);

    // Tap Add Ingredient
    await tester.tap(find.byKey(const Key('addIngredientButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('addIngredientSheetTitle')), findsOneWidget);

    // Select Saved Food
    expect(find.byKey(const Key('savedFoodItem_0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('savedFoodItem_0')));
    await tester.pumpAndSettle();

    // Verify ingredient is in list
    expect(find.text('Whey Protein'), findsOneWidget);
    expect(find.text('Batch total: 120 kcal'), findsOneWidget);
    // Per serving (120 / 2 = 60 kcal, 24 / 2 = 12g P)
    expect(find.text('60'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    // Add second ingredient custom
    await tester.tap(find.byKey(const Key('addIngredientButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Ingredient'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('customIngredientNameInput')), 'Banana');
    await tester.enterText(find.byKey(const Key('customIngredientCaloriesInput')), '100');
    await tester.enterText(find.byKey(const Key('customIngredientCarbsInput')), '26');
    await tester.enterText(find.byKey(const Key('customIngredientProteinInput')), '1');
    await tester.enterText(find.byKey(const Key('customIngredientFatInput')), '0');

    await tester.tap(find.byKey(const Key('submitCustomIngredientButton')));
    await tester.pumpAndSettle();

    expect(find.text('Banana'), findsOneWidget);
    // Total batch = 120 + 100 = 220 kcal. Per serving = 110 kcal.
    expect(find.text('Batch total: 220 kcal'), findsOneWidget);
    expect(find.text('110'), findsOneWidget);

    // Save recipe
    await tester.tap(find.byKey(const Key('saveRecipeSubmitButton')));
    await tester.pumpAndSettle();

    final List<Recipe> saved = await recipeStorage.loadRecipes();
    expect(saved.length, 1);
    expect(saved.first.name, 'Post Workout Shake');
    expect(saved.first.servings, 2);
    expect(saved.first.ingredients.length, 2);
  });

  testWidgets('RecipeListModal logs 1 serving and custom serving to callback',
      (WidgetTester tester) async {
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage(
      initialRecipes: <Recipe>[
        Recipe(
          id: 'r1',
          name: 'Chicken Rice Prep',
          servings: 4,
          ingredients: <RecipeIngredient>[
            RecipeIngredient(name: 'Chicken', calories: 800, proteinG: 120, carbsG: 0, fatG: 20),
            RecipeIngredient(name: 'Rice', calories: 800, proteinG: 16, carbsG: 180, fatG: 4),
          ],
        ),
      ],
    );

    Recipe? loggedRecipe;
    double? loggedServings;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => RecipeListModal.show(
                context,
                recipeStorage: recipeStorage,
                defaultMealType: MealType.lunch,
                onLogRecipe: (Recipe r, double servings, MealType m) {
                  loggedRecipe = r;
                  loggedServings = servings;
                },
              ),
              child: const Text('Open Recipe List'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Recipe List'));
    await tester.pumpAndSettle();

    expect(find.text('Recipes & Meal Templates'), findsOneWidget);
    expect(find.text('Chicken Rice Prep'), findsOneWidget);
    expect(find.text('🔥 400 kcal'), findsOneWidget);
    expect(find.text('🥩 34g P'), findsOneWidget);

    // Log 1 serving
    await tester.tap(find.byKey(const Key('quickLogRecipeBtn_0')));
    await tester.pumpAndSettle();

    expect(loggedRecipe?.name, 'Chicken Rice Prep');
    expect(loggedServings, 1.0);
  });

  testWidgets('RecipeListModal custom serving dialog logs scaled servings',
      (WidgetTester tester) async {
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage(
      initialRecipes: <Recipe>[
        Recipe(
          id: 'r1',
          name: 'Oats Bowl',
          servings: 1,
          ingredients: <RecipeIngredient>[
            RecipeIngredient(name: 'Oats', calories: 300, proteinG: 10, carbsG: 50, fatG: 5),
          ],
        ),
      ],
    );

    Recipe? loggedRecipe;
    double? loggedServings;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => RecipeListModal.show(
                context,
                recipeStorage: recipeStorage,
                onLogRecipe: (Recipe r, double servings, MealType m) {
                  loggedRecipe = r;
                  loggedServings = servings;
                },
              ),
              child: const Text('Open Recipe List'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Recipe List'));
    await tester.pumpAndSettle();

    // Tap Custom
    await tester.tap(find.byKey(const Key('customServingsRecipeBtn_0')));
    await tester.pumpAndSettle();

    expect(find.text('Log Oats Bowl'), findsOneWidget);
    expect(find.text('1.0 serving'), findsOneWidget);

    // Increase to 2.0 servings
    await tester.tap(find.byKey(const Key('customServingPlusBtn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customServingPlusBtn')));
    await tester.pumpAndSettle();
    expect(find.text('2.0 servings'), findsOneWidget);

    // Confirm log
    await tester.tap(find.byKey(const Key('confirmCustomServingLogBtn')));
    await tester.pumpAndSettle();

    expect(loggedRecipe?.name, 'Oats Bowl');
    expect(loggedServings, 2.0);
  });

  testWidgets('FoodEntryModal allows logging from recipes',
      (WidgetTester tester) async {
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage(
      initialRecipes: <Recipe>[
        Recipe(
          id: 'r1',
          name: 'Protein Shake',
          servings: 1,
          ingredients: <RecipeIngredient>[
            RecipeIngredient(name: 'Whey', calories: 200, proteinG: 40, carbsG: 4, fatG: 2),
          ],
        ),
      ],
    );

    FoodLogEntry? resultEntry;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () async {
                resultEntry = await FoodEntryModal.showAdd(
                  context,
                  recipeStorage: recipeStorage,
                );
              },
              child: const Text('Open Food Entry'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Food Entry'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('openRecipesFromFoodEntryModalButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('openRecipesFromFoodEntryModalButton')));
    await tester.pumpAndSettle();

    expect(find.text('Protein Shake'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quickLogRecipeBtn_0')));
    await tester.pumpAndSettle();

    expect(resultEntry?.mealLabel, 'Protein Shake');
    expect(resultEntry?.calories, 200);
    expect(resultEntry?.proteinG, 40);
  });

  testWidgets('AppBar action opens RecipeListModal in MacroTrackerApp',
      (WidgetTester tester) async {
    final CalorieStorage calorieStorage = CalorieStorage.inMemory();
    final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage();

    await tester.pumpWidget(
      MacroTrackerApp(
        calorieStorage: calorieStorage,
        weightStorage: weightStorage,
        recipeStorage: recipeStorage,
        showOnboarding: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('openRecipesModalButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('openRecipesModalButton')));
    await tester.pumpAndSettle();

    expect(find.text('Recipes & Meal Templates'), findsOneWidget);
  });

  testWidgets('RecipeBuilderModal searches saved foods, displays match count, handles empty state, and clears',
      (WidgetTester tester) async {
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final List<SavedFood> savedFoods = <SavedFood>[
      SavedFood(name: 'Chicken Breast', calories: 165, proteinG: 31, carbsG: 0, fatG: 4),
      SavedFood(name: 'Rolled Oats', calories: 150, proteinG: 5, carbsG: 27, fatG: 3),
      SavedFood(name: 'Greek Yogurt', calories: 130, proteinG: 18, carbsG: 6, fatG: 1),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => RecipeBuilderModal.show(
                context,
                recipeStorage: recipeStorage,
                savedFoods: savedFoods,
              ),
              child: const Text('Open Builder'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Builder'));
    await tester.pumpAndSettle();

    // Tap Add Ingredient
    await tester.tap(find.byKey(const Key('addIngredientButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savedFoodSearchInput')), findsOneWidget);
    expect(find.text('Chicken Breast'), findsOneWidget);
    expect(find.text('Rolled Oats'), findsOneWidget);
    expect(find.text('Greek Yogurt'), findsOneWidget);

    // Search for "Oats"
    await tester.enterText(find.byKey(const Key('savedFoodSearchInput')), 'Oats');
    await tester.pumpAndSettle();

    expect(find.text('Rolled Oats'), findsOneWidget);
    expect(find.text('Chicken Breast'), findsNothing);
    expect(find.text('Greek Yogurt'), findsNothing);
    expect(find.text('Showing 1 of 3 foods'), findsOneWidget);

    // Search for non-existent item
    await tester.enterText(find.byKey(const Key('savedFoodSearchInput')), 'Salmon');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('noMatchingSavedFoodsText')), findsOneWidget);
    expect(find.text('Rolled Oats'), findsNothing);

    // Clear search
    await tester.tap(find.byKey(const Key('clearSavedFoodSearchButton')));
    await tester.pumpAndSettle();

    expect(find.text('Chicken Breast'), findsOneWidget);
    expect(find.text('Rolled Oats'), findsOneWidget);
    expect(find.text('Greek Yogurt'), findsOneWidget);

    // Filter "Chicken" and select it
    await tester.enterText(find.byKey(const Key('savedFoodSearchInput')), 'chicken');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('savedFoodItem_0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('savedFoodItem_0')));
    await tester.pumpAndSettle();

    // Verify ingredient is added
    expect(find.text('Chicken Breast'), findsOneWidget);
  });

  testWidgets('RecipeBuilderModal ingredient search filters added ingredients',
      (WidgetTester tester) async {
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final Recipe initialRecipe = Recipe(
      id: 'test_r',
      name: 'Power Bowl',
      servings: 1,
      ingredients: <RecipeIngredient>[
        RecipeIngredient(name: 'Brown Rice', calories: 215, proteinG: 5, carbsG: 45, fatG: 2),
        RecipeIngredient(name: 'Chicken Breast', calories: 165, proteinG: 31, carbsG: 0, fatG: 4),
        RecipeIngredient(name: 'Avocado', calories: 160, proteinG: 2, carbsG: 9, fatG: 15),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => RecipeBuilderModal.show(
                context,
                recipeStorage: recipeStorage,
                initialRecipe: initialRecipe,
              ),
              child: const Text('Open Builder'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Builder'));
    await tester.pumpAndSettle();

    // 3 ingredients triggers search input
    expect(find.byKey(const Key('recipeIngredientSearchInput')), findsOneWidget);
    expect(find.text('Brown Rice'), findsOneWidget);
    expect(find.text('Chicken Breast'), findsOneWidget);
    expect(find.text('Avocado'), findsOneWidget);

    // Filter for "Rice"
    await tester.enterText(find.byKey(const Key('recipeIngredientSearchInput')), 'Rice');
    await tester.pumpAndSettle();

    expect(find.text('Brown Rice'), findsOneWidget);
    expect(find.text('Chicken Breast'), findsNothing);
    expect(find.text('Avocado'), findsNothing);

    // Search non-existent
    await tester.enterText(find.byKey(const Key('recipeIngredientSearchInput')), 'Tofu');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('noMatchingRecipeIngredientsBox')), findsOneWidget);

    // Clear
    await tester.tap(find.byKey(const Key('clearRecipeIngredientSearchBtn')));
    await tester.pumpAndSettle();

    expect(find.text('Brown Rice'), findsOneWidget);
    expect(find.text('Chicken Breast'), findsOneWidget);
    expect(find.text('Avocado'), findsOneWidget);
  });

  testWidgets('RecipeListModal searches recipes by title and ingredient name',
      (WidgetTester tester) async {
    final InMemoryRecipeStorage recipeStorage = InMemoryRecipeStorage(
      initialRecipes: <Recipe>[
        Recipe(
          id: 'r1',
          name: 'Morning Oatmeal',
          description: 'Quick oats with honey',
          servings: 1,
          ingredients: <RecipeIngredient>[
            RecipeIngredient(name: 'Rolled Oats', calories: 150, proteinG: 5, carbsG: 27, fatG: 3),
            RecipeIngredient(name: 'Honey', calories: 60, proteinG: 0, carbsG: 17, fatG: 0),
          ],
        ),
        Recipe(
          id: 'r2',
          name: 'Protein Shake',
          description: 'Post-workout fuel',
          servings: 1,
          ingredients: <RecipeIngredient>[
            RecipeIngredient(name: 'Whey Isolate', calories: 120, proteinG: 25, carbsG: 2, fatG: 1),
            RecipeIngredient(name: 'Almond Milk', calories: 30, proteinG: 1, carbsG: 1, fatG: 2),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => RecipeListModal.show(
                context,
                recipeStorage: recipeStorage,
              ),
              child: const Text('Open Recipes'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Recipes'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recipeSearchInput')), findsOneWidget);
    expect(find.text('Morning Oatmeal'), findsOneWidget);
    expect(find.text('Protein Shake'), findsOneWidget);

    // Search by title "Morning"
    await tester.enterText(find.byKey(const Key('recipeSearchInput')), 'Morning');
    await tester.pumpAndSettle();

    expect(find.text('Morning Oatmeal'), findsOneWidget);
    expect(find.text('Protein Shake'), findsNothing);
    expect(find.text('Showing 1 of 2 recipes'), findsOneWidget);

    // Search by ingredient name "Whey"
    await tester.enterText(find.byKey(const Key('recipeSearchInput')), 'Whey');
    await tester.pumpAndSettle();

    expect(find.text('Protein Shake'), findsOneWidget);
    expect(find.text('Morning Oatmeal'), findsNothing);

    // Search for non-existent recipe
    await tester.enterText(find.byKey(const Key('recipeSearchInput')), 'Pizza');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('noMatchingRecipesText')), findsOneWidget);

    // Clear search with clear button
    await tester.tap(find.byKey(const Key('clearRecipeSearchButton')));
    await tester.pumpAndSettle();

    expect(find.text('Morning Oatmeal'), findsOneWidget);
    expect(find.text('Protein Shake'), findsOneWidget);
  });
}
