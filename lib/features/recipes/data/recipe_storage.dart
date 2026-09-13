import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/recipe.dart';

/// Abstract storage interface for creating, loading, and deleting saved recipes.
abstract class RecipeStorage {
  const RecipeStorage();

  /// Creates a default persistent [PreferencesRecipeStorage].
  factory RecipeStorage.preferences() => PreferencesRecipeStorage();

  /// Creates an in-memory [InMemoryRecipeStorage] for testing.
  factory RecipeStorage.inMemory({List<Recipe>? initialRecipes}) =>
      InMemoryRecipeStorage(initialRecipes: initialRecipes);

  /// Loads all saved recipes, sorted by most recently updated first.
  Future<List<Recipe>> loadRecipes();

  /// Adds or updates a saved recipe.
  Future<void> saveRecipe(Recipe recipe);

  /// Removes a saved recipe by its [id].
  Future<void> deleteRecipe(String id);

  /// Clears all saved recipes.
  Future<void> clearAll();
}

/// Persistent implementation of [RecipeStorage] using [SharedPreferences].
class PreferencesRecipeStorage implements RecipeStorage {
  const PreferencesRecipeStorage();

  static const String _recipesKey = 'ez_macro_saved_recipes';

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('PreferencesRecipeStorage: Failed to get SharedPreferences: $e');
      return null;
    }
  }

  @override
  Future<List<Recipe>> loadRecipes() async {
    final SharedPreferences? prefs = await _getPrefs();
    if (prefs == null) return <Recipe>[];

    final String? jsonString = prefs.getString(_recipesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return <Recipe>[];
    }

    try {
      final dynamic decoded = json.decode(jsonString);
      if (decoded is List) {
        final List<Recipe> recipes = decoded
            .map((dynamic item) => Recipe.fromMap(item as Map<String, dynamic>))
            .toList();
        recipes.sort((Recipe a, Recipe b) => b.updatedAt.compareTo(a.updatedAt));
        return recipes;
      }
    } catch (e) {
      debugPrint('PreferencesRecipeStorage: Error decoding recipes: $e');
    }
    return <Recipe>[];
  }

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    final SharedPreferences? prefs = await _getPrefs();
    if (prefs == null) return;

    final List<Recipe> current = await loadRecipes();
    final int existingIndex = current.indexWhere((Recipe r) => r.id == recipe.id);

    if (existingIndex >= 0) {
      current[existingIndex] = recipe.copyWith(updatedAt: DateTime.now());
    } else {
      current.add(recipe.copyWith(updatedAt: DateTime.now()));
    }

    final String encoded = json.encode(
      current.map((Recipe r) => r.toMap()).toList(),
    );
    await prefs.setString(_recipesKey, encoded);
  }

  @override
  Future<void> deleteRecipe(String id) async {
    final SharedPreferences? prefs = await _getPrefs();
    if (prefs == null) return;

    final List<Recipe> current = await loadRecipes();
    current.removeWhere((Recipe r) => r.id == id);

    final String encoded = json.encode(
      current.map((Recipe r) => r.toMap()).toList(),
    );
    await prefs.setString(_recipesKey, encoded);
  }

  @override
  Future<void> clearAll() async {
    final SharedPreferences? prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.remove(_recipesKey);
  }
}

/// In-memory implementation of [RecipeStorage] for testing.
class InMemoryRecipeStorage implements RecipeStorage {
  InMemoryRecipeStorage({List<Recipe>? initialRecipes}) {
    if (initialRecipes != null) {
      for (final Recipe r in initialRecipes) {
        _recipes[r.id] = r;
      }
    }
  }

  final Map<String, Recipe> _recipes = <String, Recipe>{};

  @override
  Future<List<Recipe>> loadRecipes() async {
    final List<Recipe> list = _recipes.values.toList()
      ..sort((Recipe a, Recipe b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    _recipes[recipe.id] = recipe.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> deleteRecipe(String id) async {
    _recipes.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _recipes.clear();
  }
}
