enum BiologicalSex {
  male,
  female;

  String get displayName => this == BiologicalSex.male ? 'Male' : 'Female';
  String get emoji => this == BiologicalSex.male ? '♂' : '♀';
}

enum ActivityLevel {
  sedentary(1.2, 'Sedentary', '🪑', 'Desk job, little or no exercise'),
  light(1.375, 'Lightly Active', '🚶', '1–3 light workouts or daily walking'),
  moderate(1.55, 'Moderately Active', '🏃', '3–5 moderate training sessions/wk'),
  veryActive(1.725, 'Very Active', '⚡', '6–7 intense workouts / physical work'),
  extraActive(1.9, 'Extremely Active', '🔥', 'Hard daily training + physical job');

  const ActivityLevel(this.multiplier, this.title, this.emoji, this.description);

  final double multiplier;
  final String title;
  final String emoji;
  final String description;
}

enum FitnessGoal {
  cut(-400, 'Lose Fat', '📉', '400 kcal deficit, high protein to preserve muscle'),
  maintain(0, 'Maintain', '⚖️', 'Balanced maintenance calories for recomp'),
  bulk(300, 'Build Muscle', '📈', '300 kcal lean surplus, fuel hypertrophy');

  const FitnessGoal(this.calorieAdjustment, this.title, this.emoji, this.description);

  final int calorieAdjustment;
  final String title;
  final String emoji;
  final String description;
}

enum MacroSplitPreference {
  highProtein('High Protein', '40% P / 35% C / 25% F', 0.40, 0.35, 0.25),
  balanced('Balanced', '30% P / 40% C / 30% F', 0.30, 0.40, 0.30),
  lowCarb('Low Carb', '35% P / 20% C / 45% F', 0.35, 0.20, 0.45);

  const MacroSplitPreference(
    this.title,
    this.subtitle,
    this.proteinRatio,
    this.carbsRatio,
    this.fatRatio,
  );

  final String title;
  final String subtitle;
  final double proteinRatio;
  final double carbsRatio;
  final double fatRatio;
}

class TdeeCalculationResult {
  const TdeeCalculationResult({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.bmi,
  });

  final int bmr;
  final int tdee;
  final int targetCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final double bmi;

  int get proteinCalories => proteinGrams * 4;
  int get carbsCalories => carbsGrams * 4;
  int get fatCalories => fatGrams * 9;

  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }
}
