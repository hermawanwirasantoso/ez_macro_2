import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/user_settings.dart';
import '../../weight_tracker/domain/weight_entry.dart';
import '../../weight_tracker/domain/weight_goal.dart';
import '../../weight_tracker/domain/weight_unit.dart';
import 'weekly_insights.dart';

/// Aggregated insights over a rolling 30-day window, including weight trend
/// and an estimated date for reaching the weight goal.
class MonthlyInsights {
  const MonthlyInsights({
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
    required this.bestStreakInWindow,
    required this.startWeightKg,
    required this.currentWeightKg,
    required this.actualWeightDeltaKg,
    required this.estimatedWeightDeltaKg,
    required this.weightTrendKgPerWeek,
    required this.trendSampleDays,
    required this.projectedDaysToGoal,
    required this.projectedGoalDate,
    required this.remainingToGoalKg,
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

  /// Longest unbroken logging streak that occurred inside the window.
  final int bestStreakInWindow;

  final double? startWeightKg;
  final double? currentWeightKg;
  final double? actualWeightDeltaKg;
  final double estimatedWeightDeltaKg;

  /// Least-squares weight trend in kg per week, or null when there is not
  /// enough weigh-in data for a meaningful trend.
  final double? weightTrendKgPerWeek;

  /// Number of distinct days covered by the weigh-ins used for the trend.
  final int trendSampleDays;

  /// Days until the goal weight at the current trend pace; null when the
  /// trend is missing, flat, or moving away from the goal.
  final int? projectedDaysToGoal;
  final DateTime? projectedGoalDate;

  /// Remaining distance to the goal in kg (absolute value); null without a
  /// goal or a current weight.
  final double? remainingToGoalKg;

  final List<InsightBadge> insightBadges;

  double get loggingAdherenceRatio =>
      totalDays > 0 ? (daysLogged / totalDays) : 0.0;
  int get loggingAdherencePercent => (loggingAdherenceRatio * 100).round();

  bool get isDeficit => netCalorieDelta < 0;
  bool get isSurplus => netCalorieDelta > 0;
  bool get hasGoalProjection => projectedDaysToGoal != null;

  double? get weightTrendKgPerWeekRounded => weightTrendKgPerWeek == null
      ? null
      : double.parse(weightTrendKgPerWeek!.toStringAsFixed(2));
}

class MonthlyInsightsCalculator {
  const MonthlyInsightsCalculator();

  static const int windowDays = 30;

  /// Minimum span between first and last weigh-in for the trend to count.
  static const int minTrendSpanDays = 7;

  static MonthlyInsights compute({
    required List<DailyLog> logs,
    required List<WeightEntry> weightEntries,
    required UserSettings settings,
    WeightGoal goal = const WeightGoal(),
    DateTime? referenceDate,
  }) {
    final DateTime ref = referenceDate ?? DateTime.now();
    final DateTime end = DateTime(ref.year, ref.month, ref.day, 23, 59, 59);
    final DateTime start =
        DateTime(ref.year, ref.month, ref.day).subtract(Duration(days: windowDays - 1));

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

    final double estimatedWeightDeltaKg =
        double.parse((netCalorieDelta / 7700.0).toStringAsFixed(2));

    final int bestStreakInWindow = _bestStreakInWindow(recentLogs);

    // Weigh-ins within the window, deduplicated per day (last entry wins).
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
      final double firstKg = first.unit.convertTo(first.weight, WeightUnit.kg);
      final double lastKg = last.unit.convertTo(last.weight, WeightUnit.kg);
      startWeightKg = firstKg;
      currentWeightKg = lastKg;
      actualWeightDeltaKg = double.parse((lastKg - firstKg).toStringAsFixed(2));
    }

    final double? trendPerDay = _linearTrendKgPerDay(recentWeights);
    final int trendSampleDays = _distinctDayCount(recentWeights);
    final double? weightTrendKgPerWeek = trendPerDay == null ? null : trendPerDay * 7;

    // Goal projection.
    int? projectedDaysToGoal;
    DateTime? projectedGoalDate;
    double? remainingToGoalKg;

    if (goal.hasGoal && currentWeightKg != null) {
      final double targetKg =
          goal.unit.convertTo(goal.targetWeight!, WeightUnit.kg);
      final double remaining = targetKg - currentWeightKg;
      remainingToGoalKg = double.parse(remaining.abs().toStringAsFixed(2));

      if (trendPerDay != null &&
          trendPerDay.abs() >= 0.005 &&
          remaining.abs() >= 0.05 &&
          remaining.sign == trendPerDay.sign) {
        final int days = (remaining / trendPerDay).abs().ceil();
        if (days > 0 && days <= 3650) {
          projectedDaysToGoal = days;
          final DateTime today = DateTime(ref.year, ref.month, ref.day);
          projectedGoalDate = today.add(Duration(days: days));
        }
      }
    }

    final List<InsightBadge> badges = _buildBadges(
      daysLogged: daysLogged,
      proteinAdherencePercent: proteinAdherencePercent,
      proteinHitDays: proteinHitDays,
      bestStreakInWindow: bestStreakInWindow,
      netCalorieDelta: netCalorieDelta,
      weightTrendKgPerWeek: weightTrendKgPerWeek,
      goal: goal,
      remainingToGoalKg: remainingToGoalKg,
      hasGoalProjection: projectedDaysToGoal != null,
    );

    return MonthlyInsights(
      daysLogged: daysLogged,
      totalDays: windowDays,
      totalCaloriesConsumed: totalCalories,
      averageDailyCalories: avgCalories,
      targetDailyCalories: settings.dailyGoal,
      netCalorieDelta: netCalorieDelta,
      averageProteinG: avgProtein,
      averageCarbsG: avgCarbs,
      averageFatG: avgFat,
      proteinAdherencePercent: proteinAdherencePercent,
      bestStreakInWindow: bestStreakInWindow,
      startWeightKg: startWeightKg,
      currentWeightKg: currentWeightKg,
      actualWeightDeltaKg: actualWeightDeltaKg,
      estimatedWeightDeltaKg: estimatedWeightDeltaKg,
      weightTrendKgPerWeek: weightTrendKgPerWeek,
      trendSampleDays: trendSampleDays,
      projectedDaysToGoal: projectedDaysToGoal,
      projectedGoalDate: projectedGoalDate,
      remainingToGoalKg: remainingToGoalKg,
      insightBadges: badges,
    );
  }

  /// Longest run of consecutive calendar days with logs inside [logs].
  static int _bestStreakInWindow(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;

    final Set<DateTime> days = logs
        .map((DailyLog log) => DateTime(log.date.year, log.date.month, log.date.day))
        .toSet();
    final List<DateTime> sorted = days.toList()..sort();

    int best = 1;
    int current = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  /// Least-squares slope (kg/day) of the weigh-ins. Requires at least two
  /// distinct days spanning [minTrendSpanDays].
  static double? _linearTrendKgPerDay(List<WeightEntry> sortedEntries) {
    if (sortedEntries.length < 2) return null;

    final DateTime firstDay = DateTime(
      sortedEntries.first.date.year,
      sortedEntries.first.date.month,
      sortedEntries.first.date.day,
    );
    final DateTime lastDay = DateTime(
      sortedEntries.last.date.year,
      sortedEntries.last.date.month,
      sortedEntries.last.date.day,
    );
    final int spanDays = lastDay.difference(firstDay).inDays;
    if (spanDays < minTrendSpanDays) return null;

    // Collapse to one weight per day (last entry of the day wins).
    final Map<int, double> kgByDay = <int, double>{};
    for (final WeightEntry entry in sortedEntries) {
      final DateTime day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      kgByDay[day.difference(firstDay).inDays] =
          entry.unit.convertTo(entry.weight, WeightUnit.kg);
    }
    if (kgByDay.length < 2) return null;

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumXX = 0;
    final int n = kgByDay.length;
    kgByDay.forEach((int x, double y) {
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    });

    final double denominator = n * sumXX - sumX * sumX;
    if (denominator == 0) return null;
    return (n * sumXY - sumX * sumY) / denominator;
  }

  static int _distinctDayCount(List<WeightEntry> entries) {
    return entries
        .map((WeightEntry e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .length;
  }

  static List<InsightBadge> _buildBadges({
    required int daysLogged,
    required int proteinAdherencePercent,
    required int proteinHitDays,
    required int bestStreakInWindow,
    required int netCalorieDelta,
    required double? weightTrendKgPerWeek,
    required WeightGoal goal,
    required double? remainingToGoalKg,
    required bool hasGoalProjection,
  }) {
    final List<InsightBadge> badges = <InsightBadge>[];

    if (daysLogged >= 25) {
      badges.add(
        InsightBadge(
          title: 'Iron Month',
          emoji: '🔥',
          description: 'Logged meals on $daysLogged of the last 30 days!',
        ),
      );
    } else if (daysLogged >= 20) {
      badges.add(
        InsightBadge(
          title: 'Rock Solid Routine',
          emoji: '⚡',
          description: 'Consistent tracking on $daysLogged of the last 30 days.',
        ),
      );
    }

    if (bestStreakInWindow >= 14) {
      badges.add(
        InsightBadge(
          title: '$bestStreakInWindow-Day Streak This Month',
          emoji: '🏆',
          description:
              'Your longest unbroken run this month was $bestStreakInWindow days.',
        ),
      );
    }

    if (proteinAdherencePercent >= 80 && daysLogged >= 12) {
      badges.add(
        InsightBadge(
          title: 'Protein Consistency',
          emoji: '🥩',
          description:
              'Hit your protein target on $proteinHitDays of $daysLogged logged days.',
        ),
      );
    }

    if (daysLogged >= 15 && netCalorieDelta < -3500) {
      badges.add(
        InsightBadge(
          title: 'Deep Monthly Deficit',
          emoji: '📉',
          description:
              '${netCalorieDelta.abs()} kcal net deficit across the last 30 days.',
        ),
      );
    }

    if (weightTrendKgPerWeek != null && goal.hasGoal) {
      final double weekly = weightTrendKgPerWeek;
      final bool losing = weekly < 0;
      final double pace = weekly.abs();
      if (hasGoalProjection && pace >= 0.2 && pace <= 1.5) {
        badges.add(
          InsightBadge(
            title: losing ? 'Healthy Cutting Pace' : 'Healthy Gaining Pace',
            emoji: losing ? '🐢' : '🌱',
            description:
                'Trending ${weekly > 0 ? "+" : ""}${weekly.toStringAsFixed(2)} kg/week toward your goal.',
          ),
        );
      } else if (!hasGoalProjection && remainingToGoalKg != null && remainingToGoalKg >= 0.05) {
        badges.add(
          const InsightBadge(
            title: 'Course Correction',
            emoji: '⚠️',
            description:
                'Your current trend is not moving toward your goal weight yet.',
          ),
        );
      }
    }

    return badges;
  }
}
