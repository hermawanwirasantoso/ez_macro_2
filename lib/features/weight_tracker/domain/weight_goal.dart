import 'dart:convert';

import 'weight_unit.dart';

/// User's weight goals, starting reference, and height metrics.
class WeightGoal {
  const WeightGoal({
    this.targetWeight,
    this.startingWeight,
    this.unit = WeightUnit.kg,
    this.heightCm,
  });

  final double? targetWeight;
  final double? startingWeight;
  final WeightUnit unit;
  final double? heightCm;

  bool get hasGoal => targetWeight != null && targetWeight! > 0;
  bool get hasStart => startingWeight != null && startingWeight! > 0;

  /// Calculates BMI (Body Mass Index) given a current weight.
  /// Height must be configured in cm.
  double? calculateBmi(double currentWeight, WeightUnit currentUnit) {
    if (heightCm == null || heightCm! <= 0 || currentWeight <= 0) {
      return null;
    }
    final double weightInKg = currentUnit.convertTo(currentWeight, WeightUnit.kg);
    final double heightInMeters = heightCm! / 100.0;
    return weightInKg / (heightInMeters * heightInMeters);
  }

  /// Returns a category string for the given BMI value.
  static String getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  /// Calculates progress from starting weight toward target weight (0.0 to 1.0).
  double calculateProgress(double currentWeight, WeightUnit currentUnit) {
    if (targetWeight == null || startingWeight == null) return 0.0;

    final double start = startingWeight!;
    final double target = targetWeight!;
    final double current = currentUnit.convertTo(currentWeight, unit);

    if ((target - start).abs() < 0.01) return 1.0;

    // Weight loss goal (target < start)
    if (start > target) {
      if (current <= target) return 1.0;
      if (current >= start) return 0.0;
      return ((start - current) / (start - target)).clamp(0.0, 1.0);
    }
    // Weight gain goal (target > start)
    else {
      if (current >= target) return 1.0;
      if (current <= start) return 0.0;
      return ((current - start) / (target - start)).clamp(0.0, 1.0);
    }
  }

  /// Returns remaining weight to goal in the goal's unit.
  /// Negative means past goal.
  double? calculateRemaining(double currentWeight, WeightUnit currentUnit) {
    if (targetWeight == null) return null;
    final double current = currentUnit.convertTo(currentWeight, unit);
    return (current - targetWeight!).abs();
  }

  WeightGoal copyWith({
    double? targetWeight,
    double? startingWeight,
    WeightUnit? unit,
    double? heightCm,
    bool clearTargetWeight = false,
    bool clearStartingWeight = false,
    bool clearHeightCm = false,
  }) {
    return WeightGoal(
      targetWeight: clearTargetWeight ? null : (targetWeight ?? this.targetWeight),
      startingWeight: clearStartingWeight ? null : (startingWeight ?? this.startingWeight),
      unit: unit ?? this.unit,
      heightCm: clearHeightCm ? null : (heightCm ?? this.heightCm),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'targetWeight': targetWeight,
      'startingWeight': startingWeight,
      'unit': unit.name,
      'heightCm': heightCm,
    };
  }

  factory WeightGoal.fromMap(Map<String, dynamic> map) {
    return WeightGoal(
      targetWeight: (map['targetWeight'] as num?)?.toDouble(),
      startingWeight: (map['startingWeight'] as num?)?.toDouble(),
      unit: WeightUnit.fromString(map['unit'] as String?),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory WeightGoal.fromJson(String source) =>
      WeightGoal.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeightGoal &&
        other.targetWeight == targetWeight &&
        other.startingWeight == startingWeight &&
        other.unit == unit &&
        other.heightCm == heightCm;
  }

  @override
  int get hashCode => Object.hash(targetWeight, startingWeight, unit, heightCm);
}
