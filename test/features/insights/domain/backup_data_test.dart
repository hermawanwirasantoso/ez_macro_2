import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';
import 'package:ez_macro_2/features/insights/domain/backup_data.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_goal.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';

void main() {
  group('BackupService tests', () {
    test('JSON Export and Restore preserves full data roundtrip', () async {
      final CalorieStorage sourceCalorie = CalorieStorage.inMemory(
        initialSettings: const UserSettings(dailyGoal: 2500, targetProteinG: 200),
      );
      final InMemoryWeightStorage sourceWeight = InMemoryWeightStorage();

      await sourceCalorie.saveDayLog(
        DailyLog(
          dateString: '2026-08-20',
          entries: <FoodLogEntry>[
            FoodLogEntry(calories: 600, mealLabel: 'Chicken Rice', proteinG: 50, carbsG: 70, fatG: 12),
          ],
        ),
      );

      await sourceCalorie.saveSavedFood(
        SavedFood(
          id: 'custom_1',
          name: 'Protein Oatmeal',
          calories: 350,
          proteinG: 30,
          carbsG: 45,
          fatG: 6,
        ),
      );

      await sourceWeight.saveEntry(
        WeightEntry(
          id: 'w_1',
          weight: 78.5,
          unit: WeightUnit.kg,
          date: DateTime(2026, 8, 20),
          note: 'Morning weigh in',
        ),
      );

      await sourceWeight.saveGoal(
        const WeightGoal(
          targetWeight: 72.0,
          startingWeight: 80.0,
          heightCm: 178.0,
        ),
      );

      // Export to JSON string
      final String jsonStr = await BackupService.exportToJsonString(
        calorieStorage: sourceCalorie,
        weightStorage: sourceWeight,
      );

      expect(jsonStr, contains('Chicken Rice'));
      expect(jsonStr, contains('Protein Oatmeal'));
      expect(jsonStr, contains('Morning weigh in'));

      // Validate & Parse
      final BackupData? parsed = BackupService.validateAndParse(jsonStr);
      expect(parsed, isNotNull);
      expect(parsed!.dailyLogs.length, 1);
      expect(parsed.savedFoods.length, 1);
      expect(parsed.weightEntries.length, 1);
      expect(parsed.weightGoal?.targetWeight, 72.0);

      // Restore into fresh empty storages
      final CalorieStorage targetCalorie = CalorieStorage.inMemory();
      final InMemoryWeightStorage targetWeight = InMemoryWeightStorage();

      await BackupService.restoreData(
        data: parsed,
        calorieStorage: targetCalorie,
        weightStorage: targetWeight,
        merge: false,
      );

      final UserSettings restoredSettings = await targetCalorie.loadSettings();
      expect(restoredSettings.dailyGoal, 2500);

      final List<DailyLog> restoredLogs = await targetCalorie.loadAllLogs();
      expect(restoredLogs.length, 1);
      expect(restoredLogs.first.entries.first.mealLabel, 'Chicken Rice');

      final List<SavedFood> restoredFoods = await targetCalorie.loadSavedFoods();
      expect(restoredFoods.length, 1);
      expect(restoredFoods.first.name, 'Protein Oatmeal');

      final List<WeightEntry> restoredWeights = await targetWeight.loadEntries();
      expect(restoredWeights.length, 1);
      expect(restoredWeights.first.weight, 78.5);

      final WeightGoal restoredGoal = await targetWeight.loadGoal();
      expect(restoredGoal.targetWeight, 72.0);
    });

    test('CSV exports generate valid CSV headers and rows', () async {
      final CalorieStorage calorieStorage = CalorieStorage.inMemory();
      final InMemoryWeightStorage weightStorage = InMemoryWeightStorage();

      await calorieStorage.saveDayLog(
        DailyLog(
          dateString: '2026-08-20',
          entries: <FoodLogEntry>[
            FoodLogEntry(calories: 500, mealLabel: 'Steak', proteinG: 40, carbsG: 0, fatG: 20),
          ],
        ),
      );

      await weightStorage.saveEntry(
        WeightEntry(
          id: 'w1',
          weight: 76.2,
          unit: WeightUnit.kg,
          date: DateTime(2026, 8, 20),
          note: 'Post run, fasted',
        ),
      );

      final String caloriesCsv = await BackupService.exportCaloriesCsv(calorieStorage: calorieStorage);
      expect(caloriesCsv, startsWith('Date,Total Calories,Protein (g)'));
      expect(caloriesCsv, contains('2026-08-20,500,40,0,20'));

      final String weightCsv = await BackupService.exportWeightCsv(weightStorage: weightStorage);
      expect(weightCsv, startsWith('Date,Weight,Unit,Body Fat %,Note'));
      expect(weightCsv, contains('76.2,kg,,"Post run, fasted"'));
    });

    test('validateAndParse returns null on invalid/corrupted json', () {
      expect(BackupService.validateAndParse('not a json'), isNull);
      expect(BackupService.validateAndParse('{"version": "invalid_type"}'), isNull);
    });
  });
}
