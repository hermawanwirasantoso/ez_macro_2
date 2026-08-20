import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/user_settings.dart';
import '../../weight_tracker/domain/weight_entry.dart';
import '../../weight_tracker/domain/weight_unit.dart';

class InsightBadge {
  const InsightBadge({
    required this.title,
    required this.emoji,
    required this.description,
  });

  final String title;
  final String emoji;
  final String description;
}

class WeeklyInsights {
  const WeeklyInsights({
    required this.daysLogged,
    required this.totalDays,
    required this.totalCaloriesConsumed,
    required this.averageDailyCalories,
    required this.targetDailyCalories,
    required this.netCalorieDelta,
    required this.averageProteinG,
    required this.averageCarbsG,
    required this.averageFatG,
    required this.proteinAdherencePercent,
    required this.startWeightKg,
    required this.currentWeightKg,
    required this.actualWeightDeltaKg,
    required this.estimatedWeightDeltaKg,
    required this.streak,
    required this.insightBadges,
  });

  final int daysLogged;
  final int totalDays;
  final int totalCaloriesConsumed;
  final int averageDailyCalories;
  final int targetDailyCalories;
  final int netCalorieDelta;
  final int averageProteinG;
  final int averageCarbsG;
  final int averageFatG;
  final int proteinAdherencePercent;
  final double? startWeightKg;
  final double? currentWeightKg;
  final double? actualWeightDeltaKg;
  final double estimatedWeightDeltaKg;
  final int streak;
  final List<InsightBadge> insightBadges;

  double get loggingAdherenceRatio => totalDays > 0 ? (daysLogged / totalDays) : 0.0;
  int get loggingAdherencePercent => (loggingAdherenceRatio * 100).round();

  bool get isDeficit => netCalorieDelta < 0;
  bool get isSurplus => netCalorieDelta > 0;
}

class WeeklyInsightsCalculator {
  const WeeklyInsightsCalculator();

  static WeeklyInsights compute({
    required List<DailyLog> logs,
    required List<WeightEntry> weightEntries,
    required UserSettings settings,
    int streak = 0,
    DateTime? referenceDate,
  }) {
    final DateTime ref = referenceDate ?? DateTime.now();
    final DateTime end = DateTime(ref.year, ref.month, ref.day, 23, 59, 59);
    final DateTime start = DateTime(ref.year, ref.month, ref.day).subtract(const Duration(days: 6));

    // Filter logs within the 7-day window
    final List<DailyLog> recentLogs = logs.where((DailyLog log) {
      final DateTime logDate = DateTime(log.date.year, log.date.month, log.date.day);
      return !logDate.isBefore(start) && !logDate.isAfter(end);
    }).toList();

    int totalCalories = 0;
    int totalProtein = 0;
    int totalCarbs = 0;
    int totalFat = 0;
    int proteinHitDays = 0;

    for (final DailyLog log in recentLogs) {
      totalCalories += log.totalCalories;
      totalProtein += log.totalProteinG;
      totalCarbs += log.totalCarbsG;
      totalFat += log.totalFatG;

      if (settings.targetProteinG > 0 &&
          log.totalProteinG >= (settings.targetProteinG * 0.90).round()) {
        proteinHitDays++;
      }
    }

    final int daysLogged = recentLogs.length;
    final int avgCalories = daysLogged > 0 ? (totalCalories / daysLogged).round() : 0;
    final int avgProtein = daysLogged > 0 ? (totalProtein / daysLogged).round() : 0;
    final int avgCarbs = daysLogged > 0 ? (totalCarbs / daysLogged).round() : 0;
    final int avgFat = daysLogged > 0 ? (totalFat / daysLogged).round() : 0;

    final int netCalorieDelta = daysLogged > 0
        ? totalCalories - (settings.dailyGoal * daysLogged)
        : 0;

    final int proteinAdherencePercent =
        daysLogged > 0 ? ((proteinHitDays / daysLogged) * 100).round() : 0;

    // Estimate fat change: 7,700 kcal ~ 1 kg fat
    final double estimatedWeightDeltaKg = double.parse((netCalorieDelta / 7700.0).toStringAsFixed(2));

    // Weight logs within the 7-day window
    final List<WeightEntry> recentWeights = weightEntries.where((WeightEntry entry) {
      final DateTime entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return !entryDate.isBefore(start) && !entryDate.isAfter(end);
    }).toList()
      ..sort((WeightEntry a, WeightEntry b) => a.date.compareTo(b.date));

    double? startWeightKg;
    double? currentWeightKg;
    double? actualWeightDeltaKg;

    if (recentWeights.isNotEmpty) {
      final WeightEntry first = recentWeights.first;
      final WeightEntry last = recentWeights.last;
      startWeightKg = first.unit == WeightUnit.lbs ? first.weight * 0.453592 : first.weight;
      currentWeightKg = last.unit == WeightUnit.lbs ? last.weight * 0.453592 : last.weight;
      actualWeightDeltaKg = double.parse((currentWeightKg - startWeightKg).toStringAsFixed(2));
    }

    // Award smart insight badges
    final List<InsightBadge> badges = <InsightBadge>[];

    if (daysLogged == 7) {
      badges.add(
        const InsightBadge(
          title: 'Consistency Champion',
          emoji: '🔥',
          description: 'Logged meals on all 7 days this week!',
        ),
      );
    } else if (daysLogged >= 5) {
      badges.add(
        const InsightBadge(
          title: 'Strong Routine',
          emoji: '⚡',
          description: 'Consistent tracking on 5+ days this week.',
        ),
      );
    }

    if (proteinAdherencePercent >= 80 && daysLogged >= 3) {
      badges.add(
        InsightBadge(
          title: 'Protein Powerhouse',
          emoji: '🥩',
          description: 'Hit your protein target on $proteinHitDays of $daysLogged days.',
        ),
      );
    }

    if (daysLogged >= 4) {
      if (netCalorieDelta < -1000) {
        badges.add(
          InsightBadge(
            title: 'Steady Deficit',
            emoji: '📉',
            description: '${netCalorieDelta.abs()} kcal net weekly deficit achieved.',
          ),
        );
      } else if (netCalorieDelta > 1000) {
        badges.add(
          InsightBadge(
            title: 'Lean Surplus',
            emoji: '📈',
            description: '+$netCalorieDelta kcal surplus to fuel muscle recovery.',
          ),
        );
      } else {
        badges.add(
          const InsightBadge(
            title: 'Calorie Precision',
            emoji: '⚖️',
            description: 'Balanced daily intake within maintenance bounds.',
          ),
        );
      }
    }

    if (streak >= 7) {
      badges.add(
        InsightBadge(
          title: '$streak-Day Streak',
          emoji: '🏆',
          description: 'Unbroken daily streak spanning $streak consecutive days.',
        ),
      );
    }

    return WeeklyInsights(
      daysLogged: daysLogged,
      totalDays: 7,
      totalCaloriesConsumed: totalCalories,
      averageDailyCalories: avgCalories,
      targetDailyCalories: settings.dailyGoal,
      netCalorieDelta: netCalorieDelta,
      averageProteinG: avgProtein,
      averageCarbsG: avgCarbs,
      averageFatG: avgFat,
      proteinAdherencePercent: proteinAdherencePercent,
      startWeightKg: startWeightKg,
      currentWeightKg: currentWeightKg,
      actualWeightDeltaKg: actualWeightDeltaKg,
      estimatedWeightDeltaKg: estimatedWeightDeltaKg,
      streak: streak,
      insightBadges: badges,
    );
  }
}
