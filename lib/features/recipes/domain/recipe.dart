import 'dart:convert';
import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/meal_type.dart';
import 'recipe_ingredient.dart';

/// Represents a multi-ingredient recipe with batch yield and computed per-serving macros.
class Recipe {
  Recipe({
    String? id,
    required this.name,
    this.description = '',
    int servings = 1,
    List<RecipeIngredient>? ingredients,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _generateId(),
        servings = servings <= 0 ? 1 : servings,
        ingredients = ingredients ?? <RecipeIngredient>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String description;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String _generateId() {
    return 'rcp_${DateTime.now().microsecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
  }

  // --- Total Batch Macros ---

  int get totalCalories =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.calories);

  int get totalProteinG =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.proteinG);

  int get totalCarbsG =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.carbsG);

  int get totalFatG =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.fatG);

  int get totalSaturatedFatG =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.saturatedFatG);

  int get totalFiberG =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.fiberG);

  int get totalAddedSugarG =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.addedSugarG);

  int get totalSodiumMg =>
      ingredients.fold<int>(0, (int sum, RecipeIngredient item) => sum + item.sodiumMg);

  // --- Per-Serving Macros ---

  int get caloriesPerServing =>
      (totalCalories / (servings > 0 ? servings : 1)).round();

  int get proteinPerServing =>
      (totalProteinG / (servings > 0 ? servings : 1)).round();

  int get carbsPerServing =>
      (totalCarbsG / (servings > 0 ? servings : 1)).round();

  int get fatPerServing =>
      (totalFatG / (servings > 0 ? servings : 1)).round();

  int get saturatedFatPerServing =>
      (totalSaturatedFatG / (servings > 0 ? servings : 1)).round();

  int get fiberPerServing =>
      (totalFiberG / (servings > 0 ? servings : 1)).round();

  int get addedSugarPerServing =>
      (totalAddedSugarG / (servings > 0 ? servings : 1)).round();

  int get sodiumPerServing =>
      (totalSodiumMg / (servings > 0 ? servings : 1)).round();

  /// Converts this recipe into a [FoodLogEntry] based on the number of servings logged.
  FoodLogEntry toFoodLogEntry({
    double loggedServings = 1.0,
    MealType? mealType,
    DateTime? timestamp,
  }) {
    final double scale = loggedServings <= 0 ? 1.0 : loggedServings;
    return FoodLogEntry(
      mealLabel: name,
      calories: (caloriesPerServing * scale).round(),
      proteinG: (proteinPerServing * scale).round(),
      carbsG: (carbsPerServing * scale).round(),
      fatG: (fatPerServing * scale).round(),
      saturatedFatG: (saturatedFatPerServing * scale).round(),
      fiberG: (fiberPerServing * scale).round(),
      addedSugarG: (addedSugarPerServing * scale).round(),
      sodiumMg: (sodiumPerServing * scale).round(),
      portionSize: scale,
      portionUnit: scale == 1.0 ? 'serving' : 'servings',
      sourceLabel: 'Recipe ($servings total yield)',
      mealType: mealType ?? MealType.forTime(timestamp),
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    int? servings,
    List<RecipeIngredient>? ingredients,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      servings: servings ?? this.servings,
      ingredients: ingredients ?? this.ingredients,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'servings': servings,
      'ingredients': ingredients.map((RecipeIngredient i) => i.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'Unnamed Recipe',
      description: map['description'] as String? ?? '',
      servings: (map['servings'] as num?)?.toInt() ?? 1,
      ingredients: (map['ingredients'] as List<dynamic>?)
              ?.map((dynamic e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
              .toList() ??
          <RecipeIngredient>[],
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Recipe.fromJson(String source) =>
      Recipe.fromMap(json.decode(source) as Map<String, dynamic>);
}
