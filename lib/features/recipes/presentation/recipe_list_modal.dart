import 'package:flutter/material.dart';
import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/meal_type.dart';
import '../../calorie_tracker/domain/saved_food.dart';
import '../../calorie_tracker/presentation/theme/app_theme.dart';
import '../data/recipe_storage.dart';
import '../domain/recipe.dart';
import '../domain/recipe_ingredient.dart';
import 'recipe_builder_modal.dart';

typedef RecipeLogCallback = void Function(
  Recipe recipe,
  double servings,
  MealType mealType,
);

/// Modal sheet displaying all saved recipes with quick logging and editing capabilities.
class RecipeListModal extends StatefulWidget {
  const RecipeListModal({
    super.key,
    required this.recipeStorage,
    this.savedFoods = const <SavedFood>[],
    this.defaultMealType,
    this.onLogRecipe,
  });

  final RecipeStorage recipeStorage;
  final List<SavedFood> savedFoods;
  final MealType? defaultMealType;
  final RecipeLogCallback? onLogRecipe;

  static Future<void> show(
    BuildContext context, {
    required RecipeStorage recipeStorage,
    List<SavedFood> savedFoods = const <SavedFood>[],
    MealType? defaultMealType,
    RecipeLogCallback? onLogRecipe,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => RecipeListModal(
        recipeStorage: recipeStorage,
        savedFoods: savedFoods,
        defaultMealType: defaultMealType,
        onLogRecipe: onLogRecipe,
      ),
    );
  }

  @override
  State<RecipeListModal> createState() => _RecipeListModalState();
}

class _RecipeListModalState extends State<RecipeListModal> {
  List<Recipe> _recipes = <Recipe>[];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    final List<Recipe> recipes = await widget.recipeStorage.loadRecipes();
    if (mounted) {
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    }
  }

  Future<void> _openRecipeBuilder([Recipe? existing]) async {
    final Recipe? saved = await RecipeBuilderModal.show(
      context,
      initialRecipe: existing,
      savedFoods: widget.savedFoods,
      recipeStorage: widget.recipeStorage,
    );
    if (saved != null) {
      await _loadRecipes();
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Recipe?'),
        content: Text('Are you sure you want to delete "${recipe.name}"?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirmDeleteRecipeBtn'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.recipeStorage.deleteRecipe(recipe.id);
      await _loadRecipes();
    }
  }

  void _logServing(Recipe recipe, double servings) {
    final MealType mealType = widget.defaultMealType ?? MealType.forTime();
    Navigator.of(context).pop();
    widget.onLogRecipe?.call(recipe, servings, mealType);
  }

  void _showCustomServingDialog(Recipe recipe) {
    double selectedServings = 1.0;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final int cals = (recipe.caloriesPerServing * selectedServings).round();
          final int protein = (recipe.proteinPerServing * selectedServings).round();
          final int carbs = (recipe.carbsPerServing * selectedServings).round();
          final int fat = (recipe.fatPerServing * selectedServings).round();

          return AlertDialog(
            title: Text('Log ${recipe.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Choose servings to log:',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      key: const Key('customServingMinusBtn'),
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: selectedServings > 0.5
                          ? () => setModalState(() => selectedServings -= 0.5)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$selectedServings ${selectedServings == 1.0 ? 'serving' : 'servings'}',
                        key: const Key('customServingValueText'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('customServingPlusBtn'),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: selectedServings < 10.0
                          ? () => setModalState(() => selectedServings += 0.5)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '🔥 $cals kcal • ${protein}g P • ${carbs}g C • ${fat}g F',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('confirmCustomServingLogBtn'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _logServing(recipe, selectedServings);
                },
                child: const Text('Log Food', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String query = _searchQuery.trim().toLowerCase();
    final List<Recipe> filteredRecipes = query.isEmpty
        ? _recipes
        : _recipes.where((Recipe recipe) {
            final bool nameMatch = recipe.name.toLowerCase().contains(query);
            final bool descMatch = recipe.description.toLowerCase().contains(query);
            final bool ingMatch = recipe.ingredients.any(
              (RecipeIngredient ing) => ing.name.toLowerCase().contains(query),
            );
            return nameMatch || descMatch || ingMatch;
          }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackgroundGrad1 : AppColors.lightBackgroundGrad1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Recipes & Meal Templates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          query.isEmpty
                              ? '${_recipes.length} saved ${_recipes.length == 1 ? 'recipe' : 'recipes'}'
                              : 'Showing ${filteredRecipes.length} of ${_recipes.length} recipes',
                          key: const Key('recipesCountSubtitleText'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (_recipes.isNotEmpty || query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: TextField(
                  key: const Key('recipeSearchInput'),
                  controller: _searchController,
                  onChanged: (String val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search recipes or ingredients...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            key: const Key('clearRecipeSearchButton'),
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Recipe List View
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recipes.isEmpty
                      ? _buildEmptyState(isDark)
                      : filteredRecipes.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 44,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No recipes found',
                                      key: const Key('noMatchingRecipesText'),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'No recipes match "$_searchQuery". Try another keyword or ingredient name.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      key: const Key('clearRecipeSearchTextBtn'),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      label: const Text('Clear search'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              key: const Key('recipeListView'),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: filteredRecipes.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Recipe recipe = filteredRecipes[index];
                                return _buildRecipeCard(recipe, isDark, index);
                              },
                            ),
            ),

            // Create Recipe Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  key: const Key('openCreateRecipeBtn'),
                  onPressed: () => _openRecipeBuilder(),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    '➕ Create New Recipe',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.soup_kitchen_outlined, size: 48, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),
            Text(
              'No Saved Recipes Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create meal templates and batch prep recipes to log full multi-ingredient meals in 1 tap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe, bool isDark, int index) {
    return Container(
      key: Key('recipeCard_$index'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header Row: Name + Yield Badge + Popup menu
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        recipe.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (recipe.description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          recipe.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${recipe.servings} ${recipe.servings == 1 ? 'serving' : 'servings'} yield',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (String value) {
                    if (value == 'edit') {
                      _openRecipeBuilder(recipe);
                    } else if (value == 'delete') {
                      _deleteRecipe(recipe);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Recipe'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Per Serving Macro Badges Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Text(
                    '🔥 ${recipe.caloriesPerServing} kcal',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryLight),
                  ),
                  Text(
                    '🥩 ${recipe.proteinPerServing}g P',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF38BDF8)),
                  ),
                  Text(
                    '🌾 ${recipe.carbsPerServing}g C',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFFB923C)),
                  ),
                  Text(
                    '🥑 ${recipe.fatPerServing}g F',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4ADE80)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons Row: Quick Log 1 Serving & Custom Servings
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    key: Key('quickLogRecipeBtn_$index'),
                    onPressed: () => _logServing(recipe, 1.0),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Log 1 Serving'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  key: Key('customServingsRecipeBtn_$index'),
                  onPressed: () => _showCustomServingDialog(recipe),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Custom'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
