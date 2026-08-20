import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/tdee_calculator/domain/tdee_calculator.dart';
import 'package:ez_macro_2/features/tdee_calculator/domain/tdee_models.dart';

void main() {
  group('TdeeCalculator unit tests', () {
    test('Calculates BMR accurately for Male using Mifflin-St Jeor', () {
      // 75kg, 175cm, 25yo Male:
      // 10*75 + 6.25*175 - 5*25 + 5 = 750 + 1093.75 - 125 + 5 = 1723.75 -> 1724
      final int bmr = TdeeCalculator.calculateBmr(
        sex: BiologicalSex.male,
        weightKg: 75.0,
        heightCm: 175.0,
        ageYears: 25,
      );
      expect(bmr, 1724);
    });

    test('Calculates BMR accurately for Female using Mifflin-St Jeor', () {
      // 60kg, 165cm, 25yo Female:
      // 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25 -> 1345
      final int bmr = TdeeCalculator.calculateBmr(
        sex: BiologicalSex.female,
        weightKg: 60.0,
        heightCm: 165.0,
        ageYears: 25,
      );
      expect(bmr, 1345);
    });

    test('Calculates TDEE using correct activity multipliers', () {
      const int bmr = 1724;

      expect(TdeeCalculator.calculateTdee(bmr: bmr, activityLevel: ActivityLevel.sedentary), 2069);
      expect(TdeeCalculator.calculateTdee(bmr: bmr, activityLevel: ActivityLevel.light), 2371);
      expect(TdeeCalculator.calculateTdee(bmr: bmr, activityLevel: ActivityLevel.moderate), 2672);
      expect(TdeeCalculator.calculateTdee(bmr: bmr, activityLevel: ActivityLevel.veryActive), 2974);
    });

    test('Full calculation applies cut deficit, high protein split, and BMI', () {
      final TdeeCalculationResult result = TdeeCalculator.calculate(
        sex: BiologicalSex.male,
        weightKg: 75.0,
        heightCm: 175.0,
        ageYears: 25,
        activityLevel: ActivityLevel.moderate,
        goal: FitnessGoal.cut,
        macroSplit: MacroSplitPreference.highProtein,
      );

      expect(result.bmr, 1724);
      expect(result.tdee, 2672);
      expect(result.targetCalories, 2272); // 2672 - 400
      expect(result.proteinGrams, 227); // 40% of 2272 / 4
      expect(result.fatGrams, 63); // 25% of 2272 / 9
      expect(result.carbsGrams, 199); // remainder
      expect(result.bmi, 24.5);
      expect(result.bmiCategory, 'Normal weight');
    });

    test('Full calculation applies bulk surplus and balanced split', () {
      final TdeeCalculationResult result = TdeeCalculator.calculate(
        sex: BiologicalSex.female,
        weightKg: 60.0,
        heightCm: 165.0,
        ageYears: 25,
        activityLevel: ActivityLevel.light,
        goal: FitnessGoal.bulk,
        macroSplit: MacroSplitPreference.balanced,
      );

      expect(result.bmr, 1345);
      expect(result.tdee, 1849);
      expect(result.targetCalories, 2149); // 1849 + 300
      expect(result.proteinGrams, 161); // 30%
      expect(result.fatGrams, 72); // 30%
      expect(result.carbsGrams, 214); // remainder
      expect(result.bmi, 22.0);
      expect(result.bmiCategory, 'Normal weight');
    });

    test('Enforces safe minimum calorie floor', () {
      final TdeeCalculationResult result = TdeeCalculator.calculate(
        sex: BiologicalSex.female,
        weightKg: 40.0,
        heightCm: 145.0,
        ageYears: 60,
        activityLevel: ActivityLevel.sedentary,
        goal: FitnessGoal.cut,
      );

      expect(result.targetCalories, 1200); // minimum safe floor for females
    });
  });
}
