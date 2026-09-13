import 'package:flutter/material.dart';
import '../../calorie_tracker/domain/saved_food.dart';
import '../../calorie_tracker/presentation/theme/app_theme.dart';
import '../data/recipe_storage.dart';
import '../domain/recipe.dart';
import '../domain/recipe_ingredient.dart';

/// Bottom sheet modal for creating or editing a multi-ingredient recipe.
class RecipeBuilderModal extends StatefulWidget {
  const RecipeBuilderModal({
    super.key,
    this.initialRecipe,
    this.savedFoods = const <SavedFood>[],
    required this.recipeStorage,
  });

  final Recipe? initialRecipe;
  final List<SavedFood> savedFoods;
  final RecipeStorage recipeStorage;

  static Future<Recipe?> show(
    BuildContext context, {
    Recipe? initialRecipe,
    List<SavedFood> savedFoods = const <SavedFood>[],
    required RecipeStorage recipeStorage,
  }) {
    return showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => RecipeBuilderModal(
        initialRecipe: initialRecipe,
        savedFoods: savedFoods,
        recipeStorage: recipeStorage,
      ),
    );
  }

  @override
  State<RecipeBuilderModal> createState() => _RecipeBuilderModalState();
}

class _RecipeBuilderModalState extends State<RecipeBuilderModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final TextEditingController _ingredientSearchController = TextEditingController();
  String _ingredientSearchQuery = '';
  late int _servings;
  late List<RecipeIngredient> _ingredients;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialRecipe?.name ?? '');
    _descController = TextEditingController(text: widget.initialRecipe?.description ?? '');
    _servings = widget.initialRecipe?.servings ?? 1;
    _ingredients = widget.initialRecipe != null
        ? List<RecipeIngredient>.from(widget.initialRecipe!.ingredients)
        : <RecipeIngredient>[];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _ingredientSearchController.dispose();
    super.dispose();
  }

  int get _totalCalories =>
      _ingredients.fold<int>(0, (int sum, RecipeIngredient i) => sum + i.calories);
  int get _totalProtein =>
      _ingredients.fold<int>(0, (int sum, RecipeIngredient i) => sum + i.proteinG);
  int get _totalCarbs =>
      _ingredients.fold<int>(0, (int sum, RecipeIngredient i) => sum + i.carbsG);
  int get _totalFat =>
      _ingredients.fold<int>(0, (int sum, RecipeIngredient i) => sum + i.fatG);

  int get _perServingCalories =>
      (_totalCalories / (_servings > 0 ? _servings : 1)).round();
  int get _perServingProtein =>
      (_totalProtein / (_servings > 0 ? _servings : 1)).round();
  int get _perServingCarbs =>
      (_totalCarbs / (_servings > 0 ? _servings : 1)).round();
  int get _perServingFat =>
      (_totalFat / (_servings > 0 ? _servings : 1)).round();

  void _addIngredient(RecipeIngredient ingredient) {
    setState(() {
      _ingredients.add(ingredient);
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _openAddIngredientDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _AddIngredientSheet(
        savedFoods: widget.savedFoods,
        onIngredientAdded: _addIngredient,
      ),
    );
  }

  Future<void> _saveRecipe() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name')),
      );
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final Recipe recipe = Recipe(
      id: widget.initialRecipe?.id,
      name: name,
      description: _descController.text.trim(),
      servings: _servings,
      ingredients: _ingredients,
      createdAt: widget.initialRecipe?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await widget.recipeStorage.saveRecipe(recipe);

    if (mounted) {
      Navigator.of(context).pop(recipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackgroundGrad1 : AppColors.lightBackgroundGrad1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              // Drag Handle
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

              // Title Row
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
                            widget.initialRecipe != null ? 'Edit Recipe' : 'Recipe Builder',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Combine ingredients & calculate batch yield',
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
              const SizedBox(height: 8),

              Expanded(
                child: ListView(
                  key: const Key('recipeBuilderScrollView'),
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    // Recipe Name Input
                    TextField(
                      key: const Key('recipeNameInput'),
                      controller: _nameController,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Recipe Title',
                        hintText: 'e.g. High Protein Oatmeal, Bulk Chicken Bowl',
                        prefixIcon: const Icon(Icons.menu_book_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Servings Stepper Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.pie_chart_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Servings Yield',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                Text(
                                  'Divide batch into portions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('recipeDecreaseServingsBtn'),
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                            onPressed: _servings > 1
                                ? () => setState(() => _servings--)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_servings ${_servings == 1 ? 'serving' : 'servings'}',
                              key: const Key('recipeServingsCountText'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('recipeIncreaseServingsBtn'),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                            onPressed: _servings < 20
                                ? () => setState(() => _servings++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Macro Summary Card
                    _buildMacroSummaryCard(isDark),
                    const SizedBox(height: 20),

                    // Ingredients Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Ingredients (${_ingredients.length})',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        ElevatedButton.icon(
                          key: const Key('addIngredientButton'),
                          onPressed: _openAddIngredientDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Ingredient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_ingredients.length >= 3 || _ingredientSearchQuery.isNotEmpty) ...<Widget>[
                      TextField(
                        key: const Key('recipeIngredientSearchInput'),
                        controller: _ingredientSearchController,
                        onChanged: (String val) {
                          setState(() {
                            _ingredientSearchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search added ingredients...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _ingredientSearchController.text.isNotEmpty
                              ? IconButton(
                                  key: const Key('clearRecipeIngredientSearchBtn'),
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _ingredientSearchController.clear();
                                      _ingredientSearchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Ingredients List
                    if (_ingredients.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            Icon(
                              Icons.egg_alt_outlined,
                              size: 36,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No ingredients added yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add Ingredient" to build your recipe.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...<Widget>[
                      () {
                        final String ingQuery = _ingredientSearchQuery.trim().toLowerCase();
                        final List<MapEntry<int, RecipeIngredient>> displayedIngredients = _ingredients
                            .asMap()
                            .entries
                            .where((MapEntry<int, RecipeIngredient> e) =>
                                ingQuery.isEmpty || e.value.name.toLowerCase().contains(ingQuery))
                            .toList();

                        if (displayedIngredients.isEmpty) {
                          return Container(
                            key: const Key('noMatchingRecipeIngredientsBox'),
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'No ingredients match "$_ingredientSearchQuery"',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: displayedIngredients.map((MapEntry<int, RecipeIngredient> entry) {
                            final int index = entry.key;
                            final RecipeIngredient ing = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          ing.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${ing.portionDisplay} • ${ing.calories} kcal • ${ing.proteinG}g P • ${ing.carbsG}g C • ${ing.fatG}g F',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    key: Key('deleteIngredientBtn_$index'),
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () => _removeIngredient(index),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }(),
                    ],
                  ],
                ),
              ),

              // Save Recipe Footer Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    key: const Key('saveRecipeSubmitButton'),
                    onPressed: _isSaving ? null : _saveRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.initialRecipe != null ? 'Update Recipe' : '💾 Save Recipe',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? <Color>[const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : <Color>[const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'PER SERVING MACROS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.primaryLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Batch total: $_totalCalories kcal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _macroStatCol('Calories', '$_perServingCalories', 'kcal', AppColors.primaryLight),
              _macroStatCol('Protein', '$_perServingProtein', 'g', const Color(0xFF38BDF8)),
              _macroStatCol('Carbs', '$_perServingCarbs', 'g', const Color(0xFFFB923C)),
              _macroStatCol('Fat', '$_perServingFat', 'g', const Color(0xFF4ADE80)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroStatCol(String label, String value, String unit, Color color) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          '$label ($unit)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

/// Dialog to select an ingredient from SavedFood or create custom ingredient.
class _AddIngredientSheet extends StatefulWidget {
  const _AddIngredientSheet({
    required this.savedFoods,
    required this.onIngredientAdded,
  });

  final List<SavedFood> savedFoods;
  final ValueChanged<RecipeIngredient> onIngredientAdded;

  @override
  State<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends State<_AddIngredientSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _savedFoodSearchController = TextEditingController();
  String _savedFoodSearchQuery = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _calsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _portionSizeController = TextEditingController(text: '100');
  final TextEditingController _portionUnitController = TextEditingController(text: 'g');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.savedFoods.isNotEmpty ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _savedFoodSearchController.dispose();
    _nameController.dispose();
    _calsController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _portionSizeController.dispose();
    _portionUnitController.dispose();
    super.dispose();
  }

  void _addCustomIngredient() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;

    final int cals = int.tryParse(_calsController.text.trim()) ?? 0;
    final int p = int.tryParse(_proteinController.text.trim()) ?? 0;
    final int c = int.tryParse(_carbsController.text.trim()) ?? 0;
    final int f = int.tryParse(_fatController.text.trim()) ?? 0;
    final double portionSize = double.tryParse(_portionSizeController.text.trim()) ?? 1.0;
    final String portionUnit = _portionUnitController.text.trim().isEmpty ? 'serving' : _portionUnitController.text.trim();

    widget.onIngredientAdded(
      RecipeIngredient(
        name: name,
        calories: cals,
        proteinG: p,
        carbsG: c,
        fatG: f,
        portionSize: portionSize,
        portionUnit: portionUnit,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasSavedFoods = widget.savedFoods.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
            Text(
              'Add Ingredient',
              key: const Key('addIngredientSheetTitle'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),

            if (hasSavedFoods) ...<Widget>[
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                unselectedLabelColor: Colors.grey,
                tabs: const <Widget>[
                  Tab(text: 'Saved Foods'),
                  Tab(text: 'Custom Ingredient'),
                ],
              ),
            ],

            Expanded(
              child: hasSavedFoods
                  ? TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _buildSavedFoodsList(isDark),
                        _buildCustomForm(isDark),
                      ],
                    )
                  : _buildCustomForm(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedFoodsList(bool isDark) {
    final String query = _savedFoodSearchQuery.trim().toLowerCase();
    final List<SavedFood> filteredFoods = query.isEmpty
        ? widget.savedFoods
        : widget.savedFoods.where((SavedFood food) {
            return food.name.toLowerCase().contains(query) ||
                food.portionUnit.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('savedFoodSearchInput'),
            controller: _savedFoodSearchController,
            onChanged: (String val) {
              setState(() {
                _savedFoodSearchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search saved foods (e.g. Chicken, Oats)...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _savedFoodSearchController.text.isNotEmpty
                  ? IconButton(
                      key: const Key('clearSavedFoodSearchButton'),
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _savedFoodSearchController.clear();
                          _savedFoodSearchQuery = '';
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
        if (query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: <Widget>[
                Text(
                  'Showing ${filteredFoods.length} of ${widget.savedFoods.length} foods',
                  key: const Key('savedFoodsSearchCountText'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: filteredFoods.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No saved foods found',
                          key: const Key('noMatchingSavedFoodsText'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No foods match "$_savedFoodSearchQuery". Check the spelling or switch to "Custom Ingredient".',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filteredFoods.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SavedFood food = filteredFoods[index];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        key: Key('savedFoodItem_$index'),
                        title: Text(
                          food.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${food.portionDisplay} • ${food.calories} kcal • ${food.proteinG}g P',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                        onTap: () {
                          widget.onIngredientAdded(RecipeIngredient.fromSavedFood(food));
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomForm(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        TextField(
          key: const Key('customIngredientNameInput'),
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Ingredient Name',
            hintText: 'e.g. Rolled Oats, Chicken Breast',
            filled: true,
            fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('customIngredientPortionSizeInput'),
                controller: _portionSizeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('customIngredientPortionUnitInput'),
                controller: _portionUnitController,
                decoration: InputDecoration(
                  labelText: 'Unit (e.g. g, scoop)',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('customIngredientCaloriesInput'),
                controller: _calsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Calories (kcal)',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('customIngredientProteinInput'),
                controller: _proteinController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Protein (g)',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('customIngredientCarbsInput'),
                controller: _carbsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Carbs (g)',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('customIngredientFatInput'),
                controller: _fatController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Fat (g)',
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            key: const Key('submitCustomIngredientButton'),
            onPressed: _addCustomIngredient,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add to Recipe', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
