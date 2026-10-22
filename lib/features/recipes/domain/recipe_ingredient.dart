import 'dart:convert';
import '../../calorie_tracker/domain/saved_food.dart';

/// Represents an individual ingredient within a recipe with nutrient values and portion size.
class RecipeIngredient {
  RecipeIngredient({
    String? id,
    required this.name,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.saturatedFatG = 0,
    this.fiberG = 0,
    this.addedSugarG = 0,
    this.sodiumMg = 0,
    this.portionSize = 1.0,
    this.portionUnit = 'serving',
    this._baseFood,
  }) : id = id ?? _generateId();

  final String id;
  final String name;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int saturatedFatG;
  final int fiberG;
  final int addedSugarG;
  final int sodiumMg;
  final double portionSize;
  final String portionUnit;
  final SavedFood? _baseFood;

  static String _generateId() {
    return 'ing_${DateTime.now().microsecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
  }

  /// The reference nutrition this ingredient is scaled from (e.g. a saved food's "100 g = 165 kcal").
  /// Rescaling from it instead of the already-rounded totals keeps macros accurate across edits.
  /// Ingredients without one (custom or older recipes) use their own values as the reference.
  SavedFood get baseFood =>
      _baseFood ??
      SavedFood(
        name: name,
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        saturatedFatG: saturatedFatG,
        fiberG: fiberG,
        addedSugarG: addedSugarG,
        sodiumMg: sodiumMg,
        portionSize: portionSize,
        portionUnit: portionUnit,
      );

  /// Creates a recipe ingredient from a [SavedFood], optionally specifying a portion quantity.
  factory RecipeIngredient.fromSavedFood(SavedFood food, {double multiplier = 1.0}) {
    final double scale = multiplier <= 0 ? 1.0 : multiplier;
    return RecipeIngredient(
      name: food.name,
      calories: (food.calories * scale).round(),
      proteinG: (food.proteinG * scale).round(),
      carbsG: (food.carbsG * scale).round(),
      fatG: (food.fatG * scale).round(),
      saturatedFatG: (food.saturatedFatG * scale).round(),
      fiberG: (food.fiberG * scale).round(),
      addedSugarG: (food.addedSugarG * scale).round(),
      sodiumMg: (food.sodiumMg * scale).round(),
      portionSize: food.portionSize * scale,
      portionUnit: food.portionUnit,
      baseFood: food,
    );
  }

  /// Creates a copy of this ingredient set to [amount] (in [portionUnit]), with macros
  /// rescaled from [baseFood].
  RecipeIngredient withAmount(double amount) {
    final SavedFood base = baseFood;
    final double size = amount <= 0 ? 0.0 : amount;
    final double factor = base.portionSize > 0 ? size / base.portionSize : 0.0;
    return RecipeIngredient(
      id: id,
      name: name,
      calories: (base.calories * factor).round(),
      proteinG: (base.proteinG * factor).round(),
      carbsG: (base.carbsG * factor).round(),
      fatG: (base.fatG * factor).round(),
      saturatedFatG: (base.saturatedFatG * factor).round(),
      fiberG: (base.fiberG * factor).round(),
      addedSugarG: (base.addedSugarG * factor).round(),
      sodiumMg: (base.sodiumMg * factor).round(),
      portionSize: size,
      portionUnit: portionUnit,
      baseFood: base,
    );
  }

  /// Formatted portion label (e.g., "100 g", "2 scoops", "1 serving", "2 servings").
  String get portionDisplay {
    final String cleanUnit = portionUnit.trim().isEmpty ? 'serving' : portionUnit.trim();
    final String sizeStr = portionSize == portionSize.toInt().toDouble()
        ? '${portionSize.toInt()}'
        : portionSize.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

    final String lowerUnit = cleanUnit.toLowerCase();
    final bool isMetric = lowerUnit == 'g' ||
        lowerUnit == 'mg' ||
        lowerUnit == 'ml' ||
        lowerUnit == 'oz' ||
        lowerUnit == 'kcal';

    if (portionSize > 1.0 && !cleanUnit.endsWith('s') && !isMetric) {
      return '$sizeStr ${cleanUnit}s';
    }
    return '$sizeStr $cleanUnit';
  }

  /// Creates a copy of this ingredient scaled by [multiplier].
  RecipeIngredient scaledBy(double multiplier) {
    if ((multiplier - 1.0).abs() < 0.001) return this;
    return withAmount(portionSize * multiplier);
  }

  RecipeIngredient copyWith({
    String? id,
    String? name,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? saturatedFatG,
    int? fiberG,
    int? addedSugarG,
    int? sodiumMg,
    double? portionSize,
    String? portionUnit,
    SavedFood? baseFood,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      fiberG: fiberG ?? this.fiberG,
      addedSugarG: addedSugarG ?? this.addedSugarG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      portionSize: portionSize ?? this.portionSize,
      portionUnit: portionUnit ?? this.portionUnit,
      baseFood: baseFood ?? _baseFood,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'saturatedFatG': saturatedFatG,
      'fiberG': fiberG,
      'addedSugarG': addedSugarG,
      'sodiumMg': sodiumMg,
      'portionSize': portionSize,
      'portionUnit': portionUnit,
      if (_baseFood != null) 'baseFood': _baseFood.toMap(),
    };
  }

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      id: map['id'] as String?,
      name: map['name'] as String? ?? 'Ingredient',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (map['fatG'] as num?)?.toInt() ?? 0,
      saturatedFatG: (map['saturatedFatG'] as num?)?.toInt() ?? 0,
      fiberG: (map['fiberG'] as num?)?.toInt() ?? 0,
      addedSugarG: (map['addedSugarG'] as num?)?.toInt() ?? 0,
      sodiumMg: (map['sodiumMg'] as num?)?.toInt() ?? 0,
      portionSize: (map['portionSize'] as num?)?.toDouble() ?? 1.0,
      portionUnit: map['portionUnit'] as String? ?? 'serving',
      baseFood: map['baseFood'] != null
          ? SavedFood.fromMap(map['baseFood'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecipeIngredient.fromJson(String source) =>
      RecipeIngredient.fromMap(json.decode(source) as Map<String, dynamic>);
}
