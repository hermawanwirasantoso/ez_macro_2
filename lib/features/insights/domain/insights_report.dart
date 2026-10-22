import 'package:intl/intl.dart' show NumberFormat;

import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/meal_type.dart';
import '../../calorie_tracker/domain/user_settings.dart';
import '../../weight_tracker/domain/weight_entry.dart';
import '../../weight_tracker/domain/weight_goal.dart';
import '../../weight_tracker/domain/weight_unit.dart';

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

final NumberFormat _thousands = NumberFormat.decimalPattern('en_US');
String _n(int value) => _thousands.format(value);

/// Nutrition totals for one calendar day. Days without entries are kept as
/// unlogged summaries so charts can show the gaps.
class DaySummary {
  const DaySummary({
    required this.date,
    required this.goal,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.entries = const <FoodLogEntry>[],
  });

  factory DaySummary.fromLog(DailyLog log) {
    return DaySummary(
      date: _dayOf(log.date),
      goal: log.dailyGoal,
      calories: log.totalCalories,
      proteinG: log.totalProteinG,
      carbsG: log.totalCarbsG,
      fatG: log.totalFatG,
      entries: List<FoodLogEntry>.unmodifiable(log.entries),
    );
  }

  final DateTime date;

  /// The calorie goal that applied on this day.
  final int goal;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final List<FoodLogEntry> entries;

  bool get isLogged => entries.isNotEmpty;
  int get delta => calories - goal;

  /// Within 10% of the day's goal either way.
  bool get isOnTarget => goal > 0 && (calories - goal).abs() <= goal * 0.1;
  bool get isOverTarget => goal > 0 && calories > goal * 1.1;

  bool get isWeekend => date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

/// Per-day averages over the logged days of a set of [DaySummary]s.
/// Unlogged days are ignored so a skipped day does not drag the average down.
class NutritionAverages {
  const NutritionAverages({
    this.daysLogged = 0,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.goal = 0,
    this.netDelta = 0,
  });

  factory NutritionAverages.of(Iterable<DaySummary> days) {
    final List<DaySummary> logged = days.where((DaySummary d) => d.isLogged).toList();
    if (logged.isEmpty) return const NutritionAverages();

    int calories = 0;
    int protein = 0;
    int carbs = 0;
    int fat = 0;
    int goal = 0;
    for (final DaySummary day in logged) {
      calories += day.calories;
      protein += day.proteinG;
      carbs += day.carbsG;
      fat += day.fatG;
      goal += day.goal;
    }
    final int n = logged.length;
    return NutritionAverages(
      daysLogged: n,
      calories: (calories / n).round(),
      proteinG: (protein / n).round(),
      carbsG: (carbs / n).round(),
      fatG: (fat / n).round(),
      goal: (goal / n).round(),
      netDelta: calories - goal,
    );
  }

  final int daysLogged;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  /// Average goal over the logged days.
  final int goal;

  /// Total calories minus total goal across the logged days.
  final int netDelta;

  bool get hasData => daysLogged > 0;
}

/// One Monday-to-Sunday week. [days] stops at the reference date, so the
/// current week may hold fewer than seven days.
class WeekSummary {
  WeekSummary({required this.start, required this.days})
      : averages = NutritionAverages.of(days);

  final DateTime start;
  final List<DaySummary> days;
  final NutritionAverages averages;

  DateTime get end => DateTime(start.year, start.month, start.day + 6);
}

/// How often a food was logged in a period.
class FoodFrequency {
  const FoodFrequency({
    required this.name,
    required this.timesLogged,
    required this.totalCalories,
  });

  final String name;
  final int timesLogged;
  final int totalCalories;

  int get averageCalories => timesLogged > 0 ? (totalCalories / timesLogged).round() : 0;
}

/// Weigh-in progress over a window, with a least-squares trend and a goal
/// projection when the trend points toward the goal.
class WeightProgress {
  const WeightProgress({
    this.windowDays = 0,
    this.startKg,
    this.currentKg,
    this.changeKg,
    this.trendKgPerWeek,
    this.trendSampleDays = 0,
    this.remainingToGoalKg,
    this.projectedDaysToGoal,
    this.projectedGoalDate,
  });

  final int windowDays;
  final double? startKg;
  final double? currentKg;
  final double? changeKg;
  final double? trendKgPerWeek;
  final int trendSampleDays;
  final double? remainingToGoalKg;
  final int? projectedDaysToGoal;
  final DateTime? projectedGoalDate;

  bool get hasWeighIns => currentKg != null;
  bool get hasGoalProjection => projectedDaysToGoal != null;
}

enum InsightHighlightKind { comparison, weekend, protein, target, meal, streak, consistency }

/// A short, data-backed observation about the period.
class InsightHighlight {
  const InsightHighlight(this.kind, this.text);

  final InsightHighlightKind kind;
  final String text;
}

/// Everything the insights overview shows for one rolling window of
/// completed days.
class InsightsReport {
  const InsightsReport({
    required this.windowDays,
    required this.days,
    required this.averages,
    required this.previousAverages,
    required this.weekdayAverages,
    required this.weekendAverages,
    required this.targetProteinG,
    required this.targetCarbsG,
    required this.targetFatG,
    required this.proteinHitDays,
    required this.daysOnTarget,
    required this.bestStreak,
    required this.currentStreak,
    required this.mealCalories,
    required this.topFoods,
    required this.weight,
    this.todayLogged = false,
  });

  final int windowDays;

  /// One summary per completed day, oldest first, ending the day before the
  /// reference date. Today is left out because it is still in progress.
  final List<DaySummary> days;

  /// Whether today already has entries (shown elsewhere, not averaged here).
  final bool todayLogged;
  final NutritionAverages averages;

  /// Averages for the same-length window just before this one.
  final NutritionAverages previousAverages;
  final NutritionAverages weekdayAverages;
  final NutritionAverages weekendAverages;
  final int targetProteinG;
  final int targetCarbsG;
  final int targetFatG;
  final int proteinHitDays;
  final int daysOnTarget;
  final int bestStreak;
  final int currentStreak;

  /// Total calories per meal type across the window.
  final Map<MealType, int> mealCalories;
  final List<FoodFrequency> topFoods;
  final WeightProgress weight;

  List<InsightHighlight> get highlights => InsightsCalculator._highlights(this);

  DateTime get start => days.first.date;
  DateTime get end => days.last.date;

  /// Fat-mass change implied by the net calorie balance (7,700 kcal per kg).
  double get estimatedWeightChangeKg =>
      double.parse((averages.netDelta / 7700.0).toStringAsFixed(2));

  /// Change in average daily calories versus the previous window, or null
  /// when either window has no logged days.
  int? get changeVsPrevious => averages.hasData && previousAverages.hasData
      ? averages.calories - previousAverages.calories
      : null;
}

class InsightsCalculator {
  const InsightsCalculator._();

  /// Weigh-in trends need at least this span between first and last weigh-in.
  static const int minTrendSpanDays = 7;

  /// Weight progress always looks back at least this far, since a 7-day
  /// window rarely holds enough weigh-ins for a trend.
  static const int minWeightWindowDays = 30;

  static InsightsReport report({
    required List<DailyLog> logs,
    required List<WeightEntry> weightEntries,
    required UserSettings settings,
    WeightGoal goal = const WeightGoal(),
    int windowDays = 7,
    DateTime? referenceDate,
  }) {
    final DateTime today = _dayOf(referenceDate ?? DateTime.now());
    final DateTime yesterday = DateTime(today.year, today.month, today.day - 1);
    final Map<DateTime, DailyLog> byDay = _logsByDay(logs);

    final List<DaySummary> days = _window(byDay, settings, yesterday, windowDays);
    final List<DaySummary> previous = _window(
      byDay,
      settings,
      DateTime(yesterday.year, yesterday.month, yesterday.day - windowDays),
      windowDays,
    );
    final List<DaySummary> logged = days.where((DaySummary d) => d.isLogged).toList();

    final NutritionAverages averages = NutritionAverages.of(days);
    final NutritionAverages weekdayAverages =
        NutritionAverages.of(days.where((DaySummary d) => !d.isWeekend));
    final NutritionAverages weekendAverages =
        NutritionAverages.of(days.where((DaySummary d) => d.isWeekend));

    final int proteinHitDays = settings.targetProteinG > 0
        ? logged
            .where((DaySummary d) => d.proteinG >= (settings.targetProteinG * 0.9).round())
            .length
        : 0;
    final int daysOnTarget = logged.where((DaySummary d) => d.isOnTarget).length;

    final Map<MealType, int> mealCalories = <MealType, int>{};
    for (final DaySummary day in logged) {
      for (final FoodLogEntry entry in day.entries) {
        mealCalories[entry.mealType] = (mealCalories[entry.mealType] ?? 0) + entry.calories;
      }
    }

    final int bestStreak = _longestRun(days);
    final int currentStreak = _currentStreak(byDay, today);
    final List<FoodFrequency> topFoods = _topFoods(logged);
    final WeightProgress weight = _weightProgress(
      weightEntries,
      goal,
      today,
      windowDays < minWeightWindowDays ? minWeightWindowDays : windowDays,
    );

    return InsightsReport(
      windowDays: windowDays,
      days: days,
      averages: averages,
      previousAverages: NutritionAverages.of(previous),
      weekdayAverages: weekdayAverages,
      weekendAverages: weekendAverages,
      targetProteinG: settings.targetProteinG,
      targetCarbsG: settings.targetCarbsG,
      targetFatG: settings.targetFatG,
      proteinHitDays: proteinHitDays,
      daysOnTarget: daysOnTarget,
      bestStreak: bestStreak,
      currentStreak: currentStreak,
      mealCalories: mealCalories,
      topFoods: topFoods,
      weight: weight,
      todayLogged: byDay.containsKey(today),
    );
  }

  /// The last [count] Monday-to-Sunday weeks, newest first. Weeks hold
  /// completed days only, so the current week stops at yesterday.
  static List<WeekSummary> recentWeeks({
    required List<DailyLog> logs,
    required UserSettings settings,
    int count = 8,
    DateTime? referenceDate,
  }) {
    final DateTime today = _dayOf(referenceDate ?? DateTime.now());
    final Map<DateTime, DailyLog> byDay = _logsByDay(logs);
    final DateTime thisMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));

    return <WeekSummary>[
      for (int w = 0; w < count; w++)
        _week(byDay, settings, DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * w), today),
    ];
  }

  /// Every day that has at least one entry, newest first.
  static List<DaySummary> loggedDays(List<DailyLog> logs) {
    return _logsByDay(logs).values.map(DaySummary.fromLog).toList()
      ..sort((DaySummary a, DaySummary b) => b.date.compareTo(a.date));
  }

  /// Groups [loggedDays] into Monday-to-Sunday weeks, newest first. Each week
  /// only holds its logged days.
  static List<WeekSummary> groupByWeek(List<DaySummary> loggedDays) {
    final Map<DateTime, List<DaySummary>> weeks = <DateTime, List<DaySummary>>{};
    for (final DaySummary day in loggedDays) {
      final DateTime monday = DateTime(day.date.year, day.date.month, day.date.day - (day.date.weekday - 1));
      weeks.putIfAbsent(monday, () => <DaySummary>[]).add(day);
    }
    final List<DateTime> starts = weeks.keys.toList()..sort((DateTime a, DateTime b) => b.compareTo(a));
    return <WeekSummary>[
      for (final DateTime start in starts)
        WeekSummary(
          start: start,
          days: weeks[start]!..sort((DaySummary a, DaySummary b) => b.date.compareTo(a.date)),
        ),
    ];
  }

  /// Logs keyed by calendar day, skipping days whose entries were all removed.
  static Map<DateTime, DailyLog> _logsByDay(List<DailyLog> logs) {
    return <DateTime, DailyLog>{
      for (final DailyLog log in logs)
        if (log.entries.isNotEmpty) _dayOf(log.date): log,
    };
  }

  static DaySummary _summaryFor(Map<DateTime, DailyLog> byDay, UserSettings settings, DateTime day) {
    final DailyLog? log = byDay[day];
    return log != null ? DaySummary.fromLog(log) : DaySummary(date: day, goal: settings.dailyGoal);
  }

  static List<DaySummary> _window(
    Map<DateTime, DailyLog> byDay,
    UserSettings settings,
    DateTime lastDay,
    int length,
  ) {
    return <DaySummary>[
      for (int i = length - 1; i >= 0; i--)
        _summaryFor(byDay, settings, DateTime(lastDay.year, lastDay.month, lastDay.day - i)),
    ];
  }

  static WeekSummary _week(
    Map<DateTime, DailyLog> byDay,
    UserSettings settings,
    DateTime monday,
    DateTime today,
  ) {
    final List<DaySummary> days = <DaySummary>[];
    for (int i = 0; i < 7; i++) {
      final DateTime day = DateTime(monday.year, monday.month, monday.day + i);
      if (!day.isBefore(today)) break;
      days.add(_summaryFor(byDay, settings, day));
    }
    return WeekSummary(start: monday, days: days);
  }

  /// Longest run of consecutive logged days inside [days].
  static int _longestRun(List<DaySummary> days) {
    int best = 0;
    int current = 0;
    for (final DaySummary day in days) {
      current = day.isLogged ? current + 1 : 0;
      if (current > best) best = current;
    }
    return best;
  }

  /// Consecutive logged days ending today, or yesterday when today is empty.
  static int _currentStreak(Map<DateTime, DailyLog> byDay, DateTime today) {
    DateTime day = byDay.containsKey(today) ? today : DateTime(today.year, today.month, today.day - 1);
    int streak = 0;
    while (byDay.containsKey(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  static List<FoodFrequency> _topFoods(List<DaySummary> logged, {int limit = 5}) {
    final Map<String, String> names = <String, String>{};
    final Map<String, int> counts = <String, int>{};
    final Map<String, int> calories = <String, int>{};

    // Oldest first, so the most recent spelling of a food wins.
    for (final DaySummary day in logged) {
      for (final FoodLogEntry entry in day.entries) {
        final String key = entry.mealLabel.trim().toLowerCase();
        if (key.isEmpty) continue;
        names[key] = entry.mealLabel.trim();
        counts[key] = (counts[key] ?? 0) + 1;
        calories[key] = (calories[key] ?? 0) + entry.calories;
      }
    }

    final List<String> keys = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : calories[b]!.compareTo(calories[a]!);
      });
    return <FoodFrequency>[
      for (final String key in keys.take(limit))
        FoodFrequency(name: names[key]!, timesLogged: counts[key]!, totalCalories: calories[key]!),
    ];
  }

  static WeightProgress _weightProgress(
    List<WeightEntry> entries,
    WeightGoal goal,
    DateTime today,
    int windowDays,
  ) {
    final DateTime start = DateTime(today.year, today.month, today.day - (windowDays - 1));
    final List<WeightEntry> recent = entries.where((WeightEntry e) {
      final DateTime day = _dayOf(e.date);
      return !day.isBefore(start) && !day.isAfter(today);
    }).toList()
      ..sort((WeightEntry a, WeightEntry b) => a.date.compareTo(b.date));

    if (recent.isEmpty) return WeightProgress(windowDays: windowDays);

    final double startKg = recent.first.unit.convertTo(recent.first.weight, WeightUnit.kg);
    final double currentKg = recent.last.unit.convertTo(recent.last.weight, WeightUnit.kg);
    final double? trendPerDay = linearTrendKgPerDay(recent);
    final int sampleDays = recent.map((WeightEntry e) => _dayOf(e.date)).toSet().length;

    double? remainingToGoalKg;
    int? projectedDays;
    DateTime? projectedDate;
    if (goal.hasGoal) {
      final double remaining = goal.unit.convertTo(goal.targetWeight!, WeightUnit.kg) - currentKg;
      remainingToGoalKg = double.parse(remaining.abs().toStringAsFixed(2));
      if (trendPerDay != null &&
          trendPerDay.abs() >= 0.005 &&
          remaining.abs() >= 0.05 &&
          remaining.sign == trendPerDay.sign) {
        final int days = (remaining / trendPerDay).abs().ceil();
        if (days > 0 && days <= 3650) {
          projectedDays = days;
          projectedDate = DateTime(today.year, today.month, today.day + days);
        }
      }
    }

    return WeightProgress(
      windowDays: windowDays,
      startKg: startKg,
      currentKg: currentKg,
      changeKg: double.parse((currentKg - startKg).toStringAsFixed(2)),
      trendKgPerWeek: trendPerDay == null ? null : double.parse((trendPerDay * 7).toStringAsFixed(2)),
      trendSampleDays: sampleDays,
      remainingToGoalKg: remainingToGoalKg,
      projectedDaysToGoal: projectedDays,
      projectedGoalDate: projectedDate,
    );
  }

  /// Least-squares slope (kg/day) of date-sorted weigh-ins, using the last
  /// weigh-in of each day. Null unless they span [minTrendSpanDays].
  static double? linearTrendKgPerDay(List<WeightEntry> sortedEntries) {
    if (sortedEntries.length < 2) return null;

    final DateTime firstDay = _dayOf(sortedEntries.first.date);
    final DateTime lastDay = _dayOf(sortedEntries.last.date);
    if (lastDay.difference(firstDay).inDays < minTrendSpanDays) return null;

    final Map<int, double> kgByDay = <int, double>{};
    for (final WeightEntry entry in sortedEntries) {
      // Rounded because a DST change makes some days 23 or 25 hours long.
      final int x = (_dayOf(entry.date).difference(firstDay).inHours / 24).round();
      kgByDay[x] = entry.unit.convertTo(entry.weight, WeightUnit.kg);
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

  static List<InsightHighlight> _highlights(InsightsReport r) {
    final List<InsightHighlight> out = <InsightHighlight>[];
    final NutritionAverages avg = r.averages;
    if (!avg.hasData) return out;

    final int? change = r.changeVsPrevious;
    if (change != null && change.abs() >= 50) {
      out.add(InsightHighlight(
        InsightHighlightKind.comparison,
        'You ate ${_n(change.abs())} kcal/day ${change < 0 ? 'less' : 'more'} than in the '
        'previous ${r.windowDays} days (${_n(avg.calories)} vs ${_n(r.previousAverages.calories)}).',
      ));
    }

    final NutritionAverages weekday = r.weekdayAverages;
    final NutritionAverages weekend = r.weekendAverages;
    if (weekday.hasData && weekend.hasData) {
      final int diff = weekend.calories - weekday.calories;
      if (diff.abs() >= 150) {
        out.add(InsightHighlight(
          InsightHighlightKind.weekend,
          'Weekends run ${_n(diff.abs())} kcal ${diff > 0 ? 'higher' : 'lower'} than weekdays '
          '(${_n(weekend.calories)} vs ${_n(weekday.calories)} kcal/day).',
        ));
      }
    }

    if (avg.daysLogged >= 2) {
      out.add(InsightHighlight(
        InsightHighlightKind.target,
        '${r.daysOnTarget} of ${avg.daysLogged} logged days landed within 10% of your calorie goal.',
      ));
      if (r.targetProteinG > 0) {
        out.add(InsightHighlight(
          InsightHighlightKind.protein,
          'Protein target (${r.targetProteinG} g) reached on ${r.proteinHitDays} of ${avg.daysLogged} logged days.',
        ));
      }
    }

    final int mealTotal = r.mealCalories.values.fold(0, (int a, int b) => a + b);
    if (mealTotal > 0 && r.mealCalories.length > 1) {
      final MapEntry<MealType, int> biggest =
          r.mealCalories.entries.reduce((MapEntry<MealType, int> a, MapEntry<MealType, int> b) => b.value > a.value ? b : a);
      out.add(InsightHighlight(
        InsightHighlightKind.meal,
        '${biggest.key.displayName} is your biggest meal at ${(biggest.value * 100 / mealTotal).round()}% of calories.',
      ));
    }

    if (r.bestStreak >= 3) {
      out.add(InsightHighlight(
        InsightHighlightKind.streak,
        'Longest logging streak in this period: ${r.bestStreak} days.',
      ));
    }

    if (avg.daysLogged < (r.windowDays / 2).ceil()) {
      out.add(InsightHighlight(
        InsightHighlightKind.consistency,
        'Only ${avg.daysLogged} of ${r.windowDays} days logged. Log more days for more reliable averages.',
      ));
    }
    return out;
  }
}
