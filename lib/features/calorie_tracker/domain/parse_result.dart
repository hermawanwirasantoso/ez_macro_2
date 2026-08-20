class ParseResult {
  const ParseResult({
    required this.mealLabel,
    required this.calories,
    required this.confidence,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.saturatedFatG = 0,
    this.fiberG = 0,
    this.addedSugarG = 0,
    this.sodiumMg = 0,
    this.portionSize = 1.0,
    this.portionUnit = 'serving',
  });

  final String mealLabel;
  final int calories;
  final double confidence;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int saturatedFatG;
  final int fiberG;
  final int addedSugarG;
  final int sodiumMg;
  final double portionSize;
  final String portionUnit;

  String get portionDisplay {
    final String sizeStr = portionSize == portionSize.toInt().toDouble()
        ? '${portionSize.toInt()}'
        : portionSize.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final String unitStr =
        portionUnit.trim().isEmpty ? 'serving' : portionUnit.trim();
    return '$sizeStr $unitStr';
  }

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
    int? saturatedFatG,
    int? fiberG,
    int? addedSugarG,
    int? sodiumMg,
    double? portionSize,
    String? portionUnit,
  }) {
    return ParseResult(
      mealLabel: mealLabel,
      calories: calories,
      confidence: confidence,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      fiberG: fiberG ?? this.fiberG,
      addedSugarG: addedSugarG ?? this.addedSugarG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      portionSize: portionSize ?? this.portionSize,
      portionUnit: portionUnit ?? this.portionUnit,
    );
  }
}

