import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';
import 'package:ez_macro_2/features/insights/domain/weekly_insights.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';

void main() {
  group('WeeklyInsightsCalculator tests', () {
    final DateTime refDate = DateTime(2026, 8, 20);

    test('Computes 7-day averages, net deficit, and macros accurately', () {
      final List<DailyLog> logs = <DailyLog>[
        // 7 consecutive days of logs
        for (int i = 0; i < 7; i++)
          DailyLog(
            dateString: DailyLog.formatDateKey(refDate.subtract(Duration(days: i))),
            entries: <FoodLogEntry>[
              FoodLogEntry(
                calories: 2000,
                mealLabel: 'Meal',
                proteinG: 180,
                carbsG: 200,
                fatG: 50,
              ),
            ],
          ),
      ];

      final List<WeightEntry> weights = <WeightEntry>[
        WeightEntry(
          id: 'w1',
          weight: 75.5,
          unit: WeightUnit.kg,
          date: refDate.subtract(const Duration(days: 6)),
        ),
        WeightEntry(
          id: 'w2',
          weight: 75.0,
          unit: WeightUnit.kg,
          date: refDate,
        ),
      ];

      const UserSettings settings = UserSettings(
        dailyGoal: 2200,
        targetProteinG: 170,
        targetCarbsG: 230,
        targetFatG: 60,
      );

      final WeeklyInsights insights = WeeklyInsightsCalculator.compute(
        logs: logs,
        weightEntries: weights,
        settings: settings,
        streak: 7,
        referenceDate: refDate,
      );

      expect(insights.daysLogged, 7);
      expect(insights.totalDays, 7);
      expect(insights.loggingAdherencePercent, 100);
      expect(insights.totalCaloriesConsumed, 14000);
      expect(insights.averageDailyCalories, 2000);
      expect(insights.netCalorieDelta, -1400); // 14000 - (2200*7 = 15400) = -1400
      expect(insights.isDeficit, isTrue);

      expect(insights.averageProteinG, 180);
      expect(insights.averageCarbsG, 200);
      expect(insights.averageFatG, 50);
      expect(insights.proteinAdherencePercent, 100);

      expect(insights.startWeightKg, 75.5);
      expect(insights.currentWeightKg, 75.0);
      expect(insights.actualWeightDeltaKg, -0.5);
      expect(insights.estimatedWeightDeltaKg, -0.18); // -1400 / 7700 = -0.18

      expect(insights.insightBadges.any((b) => b.title == 'Consistency Champion'), isTrue);
      expect(insights.insightBadges.any((b) => b.title == 'Protein Powerhouse'), isTrue);
      expect(insights.insightBadges.any((b) => b.title == 'Steady Deficit'), isTrue);
      expect(insights.insightBadges.any((b) => b.title == '7-Day Streak'), isTrue);
    });

    test('Handles empty logs cleanly without division by zero', () {
      final WeeklyInsights insights = WeeklyInsightsCalculator.compute(
        logs: <DailyLog>[],
        weightEntries: <WeightEntry>[],
        settings: const UserSettings(),
        referenceDate: refDate,
      );

      expect(insights.daysLogged, 0);
      expect(insights.averageDailyCalories, 0);
      expect(insights.netCalorieDelta, 0);
      expect(insights.startWeightKg, isNull);
      expect(insights.currentWeightKg, isNull);
      expect(insights.actualWeightDeltaKg, isNull);
      expect(insights.estimatedWeightDeltaKg, 0.0);
      expect(insights.insightBadges, isEmpty);
    });
  });
}
