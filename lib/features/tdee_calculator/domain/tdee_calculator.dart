import 'tdee_models.dart';

/// Scientific TDEE and Macro calculation engine based on the Mifflin-St Jeor equation.
class TdeeCalculator {
  const TdeeCalculator();

  /// Calculates Basal Metabolic Rate (BMR) using Mifflin-St Jeor.
  ///
  /// For Men:   BMR = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) + 5
  /// For Women: BMR = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 161
  static int calculateBmr({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
  }) {
    final double base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * ageYears);
    final double bmr = sex == BiologicalSex.male ? base + 5.0 : base - 161.0;
    return bmr.round().clamp(500, 5000);
  }

  /// Calculates Total Daily Energy Expenditure (TDEE).
  static int calculateTdee({
    required int bmr,
    required ActivityLevel activityLevel,
  }) {
    return (bmr * activityLevel.multiplier).round();
  }

  /// Calculates Body Mass Index (BMI).
  static double calculateBmi({
    required double weightKg,
    required double heightCm,
  }) {
    if (heightCm <= 0) return 0.0;
    final double heightM = heightCm / 100.0;
    final double bmi = weightKg / (heightM * heightM);
    return double.parse(bmi.toStringAsFixed(1));
  }

  /// Full scientific calculation returning BMR, TDEE, target calories, and macro breakdown.
  static TdeeCalculationResult calculate({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required ActivityLevel activityLevel,
    required FitnessGoal goal,
    MacroSplitPreference macroSplit = MacroSplitPreference.highProtein,
  }) {
    final int bmr = calculateBmr(
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
    );

    final int tdee = calculateTdee(bmr: bmr, activityLevel: activityLevel);

    // Target Calories adjusted for goal (minimum safe floor of 1,200 kcal for women, 1,500 for men)
    final int rawTarget = tdee + goal.calorieAdjustment;
    final int safeFloor = sex == BiologicalSex.female ? 1200 : 1500;
    final int targetCalories = rawTarget < safeFloor ? safeFloor : rawTarget;

    // Macro distributions
    final int proteinGrams = ((targetCalories * macroSplit.proteinRatio) / 4.0).round();
    final int fatGrams = ((targetCalories * macroSplit.fatRatio) / 9.0).round();
    final int carbsGrams = (((targetCalories - (proteinGrams * 4) - (fatGrams * 9)) / 4.0).round())
        .clamp(0, 1000);

    final double bmi = calculateBmi(weightKg: weightKg, heightCm: heightCm);

    return TdeeCalculationResult(
      bmr: bmr,
      tdee: tdee,
      targetCalories: targetCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      bmi: bmi,
    );
  }
}
