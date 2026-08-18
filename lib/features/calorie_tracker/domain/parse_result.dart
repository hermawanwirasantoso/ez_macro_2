class ParseResult {
  const ParseResult({
    required this.mealLabel,
    required this.calories,
    required this.confidence,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  final String mealLabel;
  final int calories;
  final double confidence;
  final int proteinG;
  final int carbsG;
  final int fatG;

  double uncertaintyPercent({required bool isFallback}) {
    if (isFallback) {
      return 0.22;
    }
    if (confidence >= 0.85) {
      return 0.08;
    }
    if (confidence >= 0.70) {
      return 0.12;
    }
    return 0.18;
  }

  int caloriesLowerBound(double uncertaintyPercent) {
    return (calories * (1 - uncertaintyPercent)).round().clamp(0, 99999).toInt();
  }

  int caloriesUpperBound(double uncertaintyPercent) {
    return (calories * (1 + uncertaintyPercent)).round().clamp(0, 99999).toInt();
  }

  ParseResult withMacros({
    required int proteinG,
    required int carbsG,
    required int fatG,
  }) {
    return ParseResult(
      mealLabel: mealLabel,
      calories: calories,
      confidence: confidence,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );
  }
}

