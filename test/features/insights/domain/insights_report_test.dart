import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';
import 'package:ez_macro_2/features/insights/domain/insights_report.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_goal.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';

// Thursday.
final DateTime ref = DateTime(2026, 8, 20);

DateTime daysAgo(int n) => DateTime(ref.year, ref.month, ref.day - n);

DailyLog dayLog(
  int daysBack,
  int calories, {
  int protein = 0,
  int carbs = 0,
  int fat = 0,
  int goal = 2200,
  String label = 'Meal',
  MealType mealType = MealType.lunch,
}) {
  return DailyLog(
    dateString: DailyLog.formatDateKey(daysAgo(daysBack)),
    dailyGoal: goal,
    entries: <FoodLogEntry>[
      FoodLogEntry(
        mealLabel: label,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        mealType: mealType,
      ),
    ],
  );
}

WeightEntry weighIn(String id, double kg, int daysBack) =>
    WeightEntry(id: id, weight: kg, unit: WeightUnit.kg, date: daysAgo(daysBack));

void main() {
  const UserSettings settings = UserSettings(dailyGoal: 2200, targetProteinG: 160);

  group('InsightsCalculator.report', () {
    test('averages logged days and computes net balance for the window', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: <DailyLog>[
          for (int i = 1; i <= 7; i++) dayLog(i, 2000, protein: 180, carbs: 200, fat: 50),
        ],
        weightEntries: <WeightEntry>[weighIn('a', 75.5, 6), weighIn('b', 75.0, 0)],
        settings: settings,
        referenceDate: ref,
      );

      expect(report.days, hasLength(7));
      expect(report.start, daysAgo(7));
      expect(report.end, daysAgo(1));
      expect(report.todayLogged, isFalse);
      expect(report.averages.daysLogged, 7);
      expect(report.averages.calories, 2000);
      expect(report.averages.proteinG, 180);
      expect(report.averages.carbsG, 200);
      expect(report.averages.fatG, 50);
      expect(report.averages.goal, 2200);
      expect(report.averages.netDelta, -1400);
      expect(report.estimatedWeightChangeKg, -0.18);
      expect(report.proteinHitDays, 7);
      expect(report.daysOnTarget, 7);
      expect(report.bestStreak, 7);
      expect(report.currentStreak, 7);

      expect(report.weight.windowDays, 30);
      expect(report.weight.startKg, 75.5);
      expect(report.weight.currentKg, 75.0);
      expect(report.weight.changeKg, -0.5);
      // A 6-day span is too short for a trend.
      expect(report.weight.trendKgPerWeek, isNull);
    });

    test('ignores today, unlogged days, and emptied days in averages', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: <DailyLog>[
          dayLog(0, 500),
          dayLog(1, 1800),
          dayLog(3, 2200),
          DailyLog(dateString: DailyLog.formatDateKey(daysAgo(2))),
        ],
        weightEntries: const <WeightEntry>[],
        settings: settings,
        referenceDate: ref,
      );

      expect(report.averages.daysLogged, 2);
      expect(report.averages.calories, 2000);
      expect(report.days.where((DaySummary d) => d.isLogged), hasLength(2));
      expect(report.days[5].isLogged, isFalse);
      expect(report.days[5].goal, 2200);
      expect(report.todayLogged, isTrue);
      expect(report.currentStreak, 2);
    });

    test('compares with the previous window of the same length', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: <DailyLog>[
          for (int i = 1; i <= 7; i++) dayLog(i, 2000),
          for (int i = 8; i <= 14; i++) dayLog(i, 2400),
        ],
        weightEntries: const <WeightEntry>[],
        settings: settings,
        referenceDate: ref,
      );

      expect(report.previousAverages.calories, 2400);
      expect(report.changeVsPrevious, -400);
      expect(
        report.highlights.any((InsightHighlight h) =>
            h.kind == InsightHighlightKind.comparison && h.text.contains('400 kcal/day less')),
        isTrue,
      );
    });

    test('splits weekday and weekend averages', () {
      // The window runs Thu Aug 13 to Wed Aug 19; Aug 15 and 16 are the weekend.
      final InsightsReport report = InsightsCalculator.report(
        logs: <DailyLog>[
          for (int i = 1; i <= 7; i++)
            dayLog(i, daysAgo(i).weekday >= DateTime.saturday ? 2600 : 1800),
        ],
        weightEntries: const <WeightEntry>[],
        settings: settings,
        referenceDate: ref,
      );

      expect(report.weekendAverages.daysLogged, 2);
      expect(report.weekendAverages.calories, 2600);
      expect(report.weekdayAverages.daysLogged, 5);
      expect(report.weekdayAverages.calories, 1800);
      expect(
        report.highlights.any((InsightHighlight h) =>
            h.kind == InsightHighlightKind.weekend && h.text.contains('800 kcal higher')),
        isTrue,
      );
    });

    test('ranks top foods and totals calories per meal', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: <DailyLog>[
          DailyLog(
            dateString: DailyLog.formatDateKey(daysAgo(1)),
            entries: <FoodLogEntry>[
              FoodLogEntry(mealLabel: 'Oatmeal', calories: 300, mealType: MealType.breakfast),
              FoodLogEntry(mealLabel: 'Chicken Bowl', calories: 600, mealType: MealType.lunch),
            ],
          ),
          DailyLog(
            dateString: DailyLog.formatDateKey(daysAgo(2)),
            entries: <FoodLogEntry>[
              FoodLogEntry(mealLabel: 'oatmeal ', calories: 300, mealType: MealType.breakfast),
              FoodLogEntry(mealLabel: 'Chicken Bowl', calories: 600, mealType: MealType.lunch),
              FoodLogEntry(mealLabel: 'Oatmeal', calories: 300, mealType: MealType.breakfast),
            ],
          ),
        ],
        weightEntries: const <WeightEntry>[],
        settings: settings,
        referenceDate: ref,
      );

      expect(report.topFoods.first.name, 'Oatmeal');
      expect(report.topFoods.first.timesLogged, 3);
      expect(report.topFoods.first.averageCalories, 300);
      expect(report.topFoods[1].name, 'Chicken Bowl');
      expect(report.topFoods[1].timesLogged, 2);
      expect(report.mealCalories[MealType.breakfast], 900);
      expect(report.mealCalories[MealType.lunch], 1200);
      expect(
        report.highlights.any((InsightHighlight h) =>
            h.kind == InsightHighlightKind.meal && h.text.startsWith('Lunch')),
        isTrue,
      );
    });

    test('projects the goal date from the weight trend', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: const <DailyLog>[],
        weightEntries: <WeightEntry>[
          for (int i = 0; i < 5; i++) weighIn('w$i', 80.0 - i * 0.5, 28 - i * 7),
        ],
        settings: settings,
        goal: const WeightGoal(targetWeight: 75.0, startingWeight: 80.0, unit: WeightUnit.kg),
        referenceDate: ref,
      );

      expect(report.weight.startKg, 80.0);
      expect(report.weight.currentKg, 78.0);
      expect(report.weight.changeKg, -2.0);
      expect(report.weight.trendKgPerWeek, -0.5);
      expect(report.weight.trendSampleDays, 5);
      expect(report.weight.remainingToGoalKg, 3.0);
      expect(report.weight.projectedDaysToGoal, 42);
      expect(report.weight.projectedGoalDate, DateTime(2026, 10, 1));
    });

    test('does not project when the trend moves away from the goal', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: const <DailyLog>[],
        weightEntries: <WeightEntry>[weighIn('a', 82.0, 14), weighIn('b', 83.0, 0)],
        settings: settings,
        goal: const WeightGoal(targetWeight: 75.0, startingWeight: 83.0, unit: WeightUnit.kg),
        referenceDate: ref,
      );

      expect(report.weight.trendKgPerWeek, greaterThan(0));
      expect(report.weight.remainingToGoalKg, 8.0);
      expect(report.weight.hasGoalProjection, isFalse);
    });

    test('uses the longer window for weight on 90-day reports', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: const <DailyLog>[],
        weightEntries: <WeightEntry>[weighIn('a', 84.0, 80), weighIn('b', 82.0, 0)],
        settings: settings,
        windowDays: 90,
        referenceDate: ref,
      );

      expect(report.days, hasLength(90));
      expect(report.weight.windowDays, 90);
      expect(report.weight.changeKg, -2.0);
    });

    test('finds the longest streak inside the window', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: <DailyLog>[
          for (final int i in <int>[1, 2, 5, 6, 7, 8, 9, 13]) dayLog(i, 2000),
        ],
        weightEntries: const <WeightEntry>[],
        settings: settings,
        windowDays: 30,
        referenceDate: ref,
      );

      expect(report.averages.daysLogged, 8);
      expect(report.bestStreak, 5);
      expect(report.currentStreak, 2);
    });

    test('handles no data without dividing by zero', () {
      final InsightsReport report = InsightsCalculator.report(
        logs: const <DailyLog>[],
        weightEntries: const <WeightEntry>[],
        settings: settings,
        referenceDate: ref,
      );

      expect(report.averages.hasData, isFalse);
      expect(report.averages.calories, 0);
      expect(report.estimatedWeightChangeKg, 0.0);
      expect(report.changeVsPrevious, isNull);
      expect(report.bestStreak, 0);
      expect(report.topFoods, isEmpty);
      expect(report.weight.hasWeighIns, isFalse);
      expect(report.highlights, isEmpty);
    });
  });

  group('InsightsCalculator weeks and history', () {
    test('recentWeeks groups Monday-to-Sunday weeks, newest first', () {
      final List<WeekSummary> weeks = InsightsCalculator.recentWeeks(
        logs: <DailyLog>[
          dayLog(3, 1800), // Mon Aug 17
          dayLog(1, 2200), // Wed Aug 19
          dayLog(0, 900), // Today, still in progress
          dayLog(5, 2500), // Sat Aug 15
        ],
        settings: settings,
        referenceDate: ref,
      );

      expect(weeks, hasLength(8));
      expect(weeks[0].start, DateTime(2026, 8, 17));
      expect(weeks[0].end, DateTime(2026, 8, 23));
      expect(weeks[0].days, hasLength(3));
      expect(weeks[0].averages.daysLogged, 2);
      expect(weeks[0].averages.calories, 2000);
      expect(weeks[1].start, DateTime(2026, 8, 10));
      expect(weeks[1].days, hasLength(7));
      expect(weeks[1].averages.calories, 2500);
      expect(weeks[2].averages.hasData, isFalse);
    });

    test('loggedDays and groupByWeek list history newest first', () {
      final List<DaySummary> days = InsightsCalculator.loggedDays(<DailyLog>[
        dayLog(10, 2100),
        dayLog(0, 1900),
        dayLog(1, 2000),
        DailyLog(dateString: DailyLog.formatDateKey(daysAgo(2))),
      ]);

      expect(days.map((DaySummary d) => d.date), <DateTime>[daysAgo(0), daysAgo(1), daysAgo(10)]);

      final List<WeekSummary> weeks = InsightsCalculator.groupByWeek(days);
      expect(weeks, hasLength(2));
      expect(weeks[0].start, DateTime(2026, 8, 17));
      expect(weeks[0].averages.calories, 1950);
      expect(weeks[1].start, DateTime(2026, 8, 10));
      expect(weeks[1].days.single.calories, 2100);
    });
  });
}
