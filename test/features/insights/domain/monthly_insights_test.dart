import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';
import 'package:ez_macro_2/features/insights/domain/monthly_insights.dart';
import 'package:ez_macro_2/features/insights/domain/weekly_insights.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_goal.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlyInsightsCalculator', () {
    final DateTime refDate = DateTime(2026, 8, 20);

    test('computes 30-day averages, streak, trend, and goal projection', () {
      final List<DailyLog> logs = <DailyLog>[
        for (int i = 0; i < 25; i++)
          DailyLog(
            dateString: DailyLog.formatDateKey(refDate.subtract(Duration(days: i))),
            entries: <FoodLogEntry>[
              FoodLogEntry(
                calories: 1900,
                mealLabel: 'Meal',
                proteinG: 160,
                carbsG: 180,
                fatG: 50,
              ),
            ],
          ),
      ];

      final List<WeightEntry> weights = <WeightEntry>[
        WeightEntry(id: 'w0', weight: 80.0, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 28))),
        WeightEntry(id: 'w1', weight: 79.5, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 21))),
        WeightEntry(id: 'w2', weight: 79.0, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 14))),
        WeightEntry(id: 'w3', weight: 78.5, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 7))),
        WeightEntry(id: 'w4', weight: 78.0, unit: WeightUnit.kg, date: refDate),
      ];

      const UserSettings settings = UserSettings(
        dailyGoal: 2200,
        targetProteinG: 150,
      );
      const WeightGoal goal = WeightGoal(
        targetWeight: 75.0,
        startingWeight: 80.0,
        unit: WeightUnit.kg,
      );

      final MonthlyInsights insights = MonthlyInsightsCalculator.compute(
        logs: logs,
        weightEntries: weights,
        settings: settings,
        goal: goal,
        referenceDate: refDate,
      );

      expect(insights.daysLogged, 25);
      expect(insights.totalDays, 30);
      expect(insights.loggingAdherencePercent, 83);
      expect(insights.averageDailyCalories, 1900);
      expect(insights.netCalorieDelta, 25 * (1900 - 2200));
      expect(insights.isDeficit, isTrue);
      expect(insights.averageProteinG, 160);
      expect(insights.proteinAdherencePercent, 100);
      expect(insights.bestStreakInWindow, 25);

      expect(insights.startWeightKg, 80.0);
      expect(insights.currentWeightKg, 78.0);
      expect(insights.actualWeightDeltaKg, -2.0);
      expect(insights.weightTrendKgPerWeekRounded, -0.5);
      expect(insights.trendSampleDays, 5);
      expect(insights.remainingToGoalKg, 3.0);
      expect(insights.projectedDaysToGoal, 42);
      expect(insights.projectedGoalDate, DateTime(2026, 10, 1));
      expect(insights.hasGoalProjection, isTrue);

      expect(insights.insightBadges.any((InsightBadge b) => b.title == 'Iron Month'), isTrue);
      expect(insights.insightBadges.any((InsightBadge b) => b.title.contains('Streak This Month')), isTrue);
      expect(insights.insightBadges.any((InsightBadge b) => b.title == 'Protein Consistency'), isTrue);
      expect(insights.insightBadges.any((InsightBadge b) => b.title == 'Healthy Cutting Pace'), isTrue);
    });

    test('handles empty logs without division by zero', () {
      final MonthlyInsights insights = MonthlyInsightsCalculator.compute(
        logs: <DailyLog>[],
        weightEntries: <WeightEntry>[],
        settings: const UserSettings(),
        referenceDate: refDate,
      );

      expect(insights.daysLogged, 0);
      expect(insights.averageDailyCalories, 0);
      expect(insights.netCalorieDelta, 0);
      expect(insights.bestStreakInWindow, 0);
      expect(insights.startWeightKg, isNull);
      expect(insights.weightTrendKgPerWeek, isNull);
      expect(insights.projectedDaysToGoal, isNull);
      expect(insights.insightBadges, isEmpty);
    });

    test('does not project when trend is away from the goal', () {
      final List<WeightEntry> weights = <WeightEntry>[
        WeightEntry(id: 'w0', weight: 80.0, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 21))),
        WeightEntry(id: 'w1', weight: 81.0, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 14))),
        WeightEntry(id: 'w2', weight: 82.0, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 7))),
        WeightEntry(id: 'w3', weight: 83.0, unit: WeightUnit.kg, date: refDate),
      ];

      final MonthlyInsights insights = MonthlyInsightsCalculator.compute(
        logs: <DailyLog>[],
        weightEntries: weights,
        settings: const UserSettings(),
        goal: const WeightGoal(targetWeight: 75.0, startingWeight: 80.0),
        referenceDate: refDate,
      );

      expect(insights.weightTrendKgPerWeek, greaterThan(0));
      expect(insights.hasGoalProjection, isFalse);
      expect(insights.remainingToGoalKg, 8.0);
      expect(
        insights.insightBadges.any((InsightBadge b) => b.title == 'Course Correction'),
        isTrue,
      );
    });

    test('requires a 7-day weigh-in span before computing a trend', () {
      final List<WeightEntry> weights = <WeightEntry>[
        WeightEntry(id: 'w0', weight: 80.0, unit: WeightUnit.kg, date: refDate.subtract(const Duration(days: 3))),
        WeightEntry(id: 'w1', weight: 79.5, unit: WeightUnit.kg, date: refDate),
      ];

      final MonthlyInsights insights = MonthlyInsightsCalculator.compute(
        logs: <DailyLog>[],
        weightEntries: weights,
        settings: const UserSettings(),
        referenceDate: refDate,
      );

      expect(insights.actualWeightDeltaKg, -0.5);
      expect(insights.weightTrendKgPerWeek, isNull);
      expect(insights.hasGoalProjection, isFalse);
    });

    test('computes the longest consecutive logging streak in the window', () {
      final List<DailyLog> logs = <DailyLog>[
        for (int i in <int>[0, 1, 2, 6, 7, 8, 9, 10])
          DailyLog(
            dateString: DailyLog.formatDateKey(refDate.subtract(Duration(days: i))),
            entries: <FoodLogEntry>[
              FoodLogEntry(calories: 2000, mealLabel: 'Meal'),
            ],
          ),
      ];

      final MonthlyInsights insights = MonthlyInsightsCalculator.compute(
        logs: logs,
        weightEntries: <WeightEntry>[],
        settings: const UserSettings(),
        referenceDate: refDate,
      );

      expect(insights.daysLogged, 8);
      expect(insights.bestStreakInWindow, 5);
    });
  });
}
