import 'dart:convert';

import 'daily_log.dart';
import 'meal_type.dart';

/// A reusable food saved by the user for quick logging later.
class SavedFood {
  SavedFood({
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
    DateTime? updatedAt,
  })  : id = id ?? _generateId(),
        updatedAt = updatedAt ?? DateTime.now();

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
  final DateTime updatedAt;

  static String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Formatted portion label (e.g., "1 serving", "100 g", "1.5 cups", "2 servings").
  String get portionDisplay {
    final String cleanUnit = portionUnit.trim().isEmpty ? 'serving' : portionUnit.trim();
    final String sizeStr = portionSize == portionSize.toInt().toDouble()
        ? '${portionSize.toInt()}'
        : '$portionSize';

    if (cleanUnit.toLowerCase() == 'serving' || cleanUnit.toLowerCase() == 'portion') {
      if (portionSize == 1.0) {
        return '1 $cleanUnit';
      } else {
        return '$sizeStr ${cleanUnit}s';
      }
    }
    return '$sizeStr $cleanUnit';
  }

  /// Creates a daily log entry from this reusable food, with optional portion scaling.
  FoodLogEntry toFoodLogEntry({
    MealType? mealType,
    DateTime? timestamp,
    double portionMultiplier = 1.0,
    double? chosenPortionSize,
  }) {
    final double effectiveMultiplier;
    if (chosenPortionSize != null && portionSize > 0) {
      effectiveMultiplier = chosenPortionSize / portionSize;
    } else {
      effectiveMultiplier = portionMultiplier <= 0 ? 1.0 : portionMultiplier;
    }

    return FoodLogEntry(
      mealLabel: name,
      calories: (calories * effectiveMultiplier).round().clamp(0, 99999),
      proteinG: (proteinG * effectiveMultiplier).round().clamp(0, 9999),
      carbsG: (carbsG * effectiveMultiplier).round().clamp(0, 9999),
      fatG: (fatG * effectiveMultiplier).round().clamp(0, 9999),
      saturatedFatG: (saturatedFatG * effectiveMultiplier).round().clamp(0, 9999),
      fiberG: (fiberG * effectiveMultiplier).round().clamp(0, 9999),
      addedSugarG: (addedSugarG * effectiveMultiplier).round().clamp(0, 9999),
      sodiumMg: (sodiumMg * effectiveMultiplier).round().clamp(0, 99999),
      sourceLabel: 'Saved',
      mealType: mealType,
      timestamp: timestamp,
    );
  }

  SavedFood copyWith({
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
    DateTime? updatedAt,
  }) {
    return SavedFood(
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
      updatedAt: updatedAt ?? this.updatedAt,
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
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedFood.fromMap(Map<String, dynamic> map) {
    return SavedFood(
      id: map['id'] as String?,
      name: (map['name'] as String?)?.trim() ?? '',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (map['fatG'] as num?)?.toInt() ?? 0,
      saturatedFatG: (map['saturatedFatG'] as num?)?.toInt() ??
          (map['saturated_fat_g'] as num?)?.toInt() ??
          0,
      fiberG: (map['fiberG'] as num?)?.toInt() ??
          (map['fiber_g'] as num?)?.toInt() ??
          0,
      addedSugarG: (map['addedSugarG'] as num?)?.toInt() ??
          (map['added_sugar_g'] as num?)?.toInt() ??
          0,
      sodiumMg: (map['sodiumMg'] as num?)?.toInt() ??
          (map['sodium_mg'] as num?)?.toInt() ??
          0,
      portionSize: (map['portionSize'] as num?)?.toDouble() ??
          (map['servingSize'] as num?)?.toDouble() ??
          1.0,
      portionUnit: (map['portionUnit'] as String?)?.trim() ??
          (map['servingUnit'] as String?)?.trim() ??
          'serving',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory SavedFood.fromJson(String source) =>
      SavedFood.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedFood &&
        other.id == id &&
        other.name == name &&
        other.calories == calories &&
        other.proteinG == proteinG &&
        other.carbsG == carbsG &&
        other.fatG == fatG &&
        other.saturatedFatG == saturatedFatG &&
        other.fiberG == fiberG &&
        other.addedSugarG == addedSugarG &&
        other.sodiumMg == sodiumMg &&
        other.portionSize == portionSize &&
        other.portionUnit == portionUnit &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        calories,
        proteinG,
        carbsG,
        fatG,
        saturatedFatG,
        fiberG,
        addedSugarG,
        sodiumMg,
        portionSize,
        portionUnit,
        updatedAt,
      );
}