import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/core/unique_id.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe.dart';
import 'package:ez_macro_2/features/recipes/domain/recipe_ingredient.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';

void main() {
  test('ids created in a tight loop are all unique', () {
    final Set<String> ids = <String>{for (int i = 0; i < 5000; i++) uniqueId()};
    expect(ids, hasLength(5000));
  });

  test('prefix is kept at the start of the id', () {
    expect(uniqueId('weight'), startsWith('weight_'));
    expect(uniqueId(), isNot(startsWith('_')));
  });

  test('models created back to back get distinct default ids', () {
    final DateTime now = DateTime.now();
    final List<String> ids = <String>[
      for (int i = 0; i < 300; i++) WeightEntry(weight: 80, date: now).id,
      for (int i = 0; i < 300; i++) SavedFood(name: 'Oats', calories: 150).id,
      for (int i = 0; i < 300; i++) Recipe(name: 'Bowl').id,
      for (int i = 0; i < 300; i++) RecipeIngredient(name: 'Rice', calories: 200).id,
      for (int i = 0; i < 300; i++) FoodLogEntry(mealLabel: 'Apple', calories: 95).id,
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });
}
