class FoodLogEntry {
  const FoodLogEntry({
    required this.mealLabel,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.rangeText,
    this.sourceLabel,
    this.spreadPercent,
  });

  final String mealLabel;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String? rangeText;
  final String? sourceLabel;
  final double? spreadPercent;

  String get displayText {
    final StringBuffer buffer = StringBuffer('$mealLabel - $calories kcal');
    if (rangeText != null && rangeText!.isNotEmpty) {
      buffer.write(' [$rangeText]');
    }
    if (sourceLabel != null && sourceLabel!.isNotEmpty) {
      buffer.write(' $sourceLabel');
    }
    return buffer.toString();
  }
}

class CalorieTrackerState {
  CalorieTrackerState({
    this.dailyGoal = 2200,
    this.targetProteinG = 160,
    this.targetCarbsG = 255,
    this.targetFatG = 60,
    this.consumedCalories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.totalSpreadPercent = 0,
    this.spreadSamples = 0,
    List<FoodLogEntry>? entries,
  }) : entries = entries ?? <FoodLogEntry>[];

  int dailyGoal;
  int targetProteinG;
  int targetCarbsG;
  int targetFatG;
  int consumedCalories;
  int proteinG;
  int carbsG;
  int fatG;
  double totalSpreadPercent;
  int spreadSamples;
  final List<FoodLogEntry> entries;

  int get remainingCalories => (dailyGoal - consumedCalories).clamp(0, 99999).toInt();
  int get caloriesFromTargets =>
      (targetProteinG * 4) + (targetCarbsG * 4) + (targetFatG * 9);
  double get averageSpreadPercent =>
      spreadSamples == 0 ? 0 : totalSpreadPercent / spreadSamples;

  bool updateTargets({
    required int dailyGoal,
    required int proteinG,
    required int carbsG,
    required int fatG,
  }) {
    this.dailyGoal = dailyGoal.clamp(900, 6000).toInt();
    targetProteinG = proteinG.clamp(0, 400).toInt();
    targetFatG = fatG.clamp(0, 300).toInt();

    final int proposedCarbs = carbsG.clamp(0, 600).toInt();
    final int adjustedCarbs =
        ((this.dailyGoal - (targetProteinG * 4) - (targetFatG * 9)) / 4)
            .round()
            .clamp(0, 600)
            .toInt();
    final bool carbsAdjusted = adjustedCarbs != proposedCarbs;
    targetCarbsG = adjustedCarbs;

    // Keep displayed calorie target aligned with the macro targets.
    this.dailyGoal = caloriesFromTargets;
    return carbsAdjusted;
  }

  void addCalories({
    required int calories,
    required String mealLabel,
    int proteinG = 0,
    int carbsG = 0,
    int fatG = 0,
    String? rangeText,
    String? sourceLabel,
    double? spreadPercent,
  }) {
    consumedCalories += calories;
    this.proteinG += proteinG;
    this.carbsG += carbsG;
    this.fatG += fatG;
    if (spreadPercent != null) {
      totalSpreadPercent += spreadPercent.clamp(0, 1).toDouble();
      spreadSamples += 1;
    }
    entries.insert(
      0,
      FoodLogEntry(
        mealLabel: mealLabel,
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        rangeText: rangeText,
        sourceLabel: sourceLabel,
        spreadPercent: spreadPercent,
      ),
    );
  }

  FoodLogEntry? removeEntryAt(int index) {
    if (index < 0 || index >= entries.length) {
      return null;
    }

    final FoodLogEntry removed = entries.removeAt(index);
    consumedCalories = (consumedCalories - removed.calories).clamp(0, 99999).toInt();
    proteinG = (proteinG - removed.proteinG).clamp(0, 99999).toInt();
    carbsG = (carbsG - removed.carbsG).clamp(0, 99999).toInt();
    fatG = (fatG - removed.fatG).clamp(0, 99999).toInt();

    if (removed.spreadPercent != null && spreadSamples > 0) {
      totalSpreadPercent =
          (totalSpreadPercent - removed.spreadPercent!).clamp(0, 99999).toDouble();
      spreadSamples -= 1;
    }

    return removed;
  }
}

