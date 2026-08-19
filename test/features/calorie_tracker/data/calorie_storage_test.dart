import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/user_settings.dart';

void main() {
  group('InMemoryCalorieStorage', () {
    late CalorieStorage storage;

    setUp(() {
      storage = CalorieStorage.inMemory();
    });

    test('initial settings match default UserSettings', () async {
      final UserSettings settings = await storage.loadSettings();
      expect(settings.dailyGoal, 2200);
      expect(settings.targetProteinG, 160);
      expect(settings.targetCarbsG, 255);
      expect(settings.targetFatG, 60);
      expect(settings.isDarkMode, isTrue);
    });

    test('saves and loads user settings', () async {
      const UserSettings custom = UserSettings(
        dailyGoal: 2500,
        targetProteinG: 180,
        targetCarbsG: 280,
        targetFatG: 70,
        isDarkMode: false,
      );
      await storage.saveSettings(custom);

      final UserSettings loaded = await storage.loadSettings();
      expect(loaded, custom);
      expect(loaded.dailyGoal, 2500);
      expect(loaded.isDarkMode, isFalse);
    });

    test('saves, loads, and deletes daily food logs', () async {
      final DateTime today = DateTime(2026, 8, 18);
      final String dateKey = DailyLog.formatDateKey(today);

      expect(await storage.loadDayLog(today), isNull);

      final DailyLog log = DailyLog(
        dateString: dateKey,
        dailyGoal: 2200,
        entries: <FoodLogEntry>[
          FoodLogEntry(
            mealLabel: 'Chicken & Rice',
            calories: 650,
            proteinG: 45,
            carbsG: 70,
            fatG: 12,
            saturatedFatG: 3,
            fiberG: 5,
            addedSugarG: 1,
            sodiumMg: 480,
            mealType: MealType.lunch,
          ),
          FoodLogEntry(
            mealLabel: 'Protein Shake',
            calories: 250,
            proteinG: 30,
            carbsG: 10,
            fatG: 3,
            saturatedFatG: 1,
            fiberG: 2,
            addedSugarG: 4,
            sodiumMg: 150,
            mealType: MealType.snack,
          ),
        ],
      );

      await storage.saveDayLog(log);

      final DailyLog? loaded = await storage.loadDayLog(today);
      expect(loaded, isNotNull);
      expect(loaded!.consumedCalories, 900);
      expect(loaded.proteinG, 75);
      expect(loaded.carbsG, 80);
      expect(loaded.fatG, 15);
      expect(loaded.saturatedFatG, 4);
      expect(loaded.fiberG, 7);
      expect(loaded.addedSugarG, 5);
      expect(loaded.sodiumMg, 630);
      expect(loaded.entries.length, 2);
      expect(loaded.caloriesForMealType(MealType.lunch), 650);
      expect(loaded.caloriesForMealType(MealType.snack), 250);

      // Delete log
      await storage.deleteDayLog(today);
      expect(await storage.loadDayLog(today), isNull);
    });

    test('calculates streak accurately across consecutive and non-consecutive days', () async {
      final DateTime refDate = DateTime(2026, 8, 18);

      // Case 1: No logs -> streak = 0
      expect(await storage.calculateStreak(referenceDate: refDate), 0);

      // Case 2: Log for today only -> streak = 1
      await storage.saveDayLog(
        DailyLog(
          dateString: DailyLog.formatDateKey(refDate),
          entries: <FoodLogEntry>[
            FoodLogEntry(mealLabel: 'Oatmeal', calories: 300),
          ],
        ),
      );
      expect(await storage.calculateStreak(referenceDate: refDate), 1);

      // Case 3: Log for today + yesterday + 2 days ago -> streak = 3
      final DateTime yesterday = refDate.subtract(const Duration(days: 1));
      final DateTime twoDaysAgo = refDate.subtract(const Duration(days: 2));

      await storage.saveDayLog(
        DailyLog(
          dateString: DailyLog.formatDateKey(yesterday),
          entries: <FoodLogEntry>[
            FoodLogEntry(mealLabel: 'Steak', calories: 700),
          ],
        ),
      );
      await storage.saveDayLog(
        DailyLog(
          dateString: DailyLog.formatDateKey(twoDaysAgo),
          entries: <FoodLogEntry>[
            FoodLogEntry(mealLabel: 'Eggs', calories: 400),
          ],
        ),
      );

      expect(await storage.calculateStreak(referenceDate: refDate), 3);

      // Case 4: Gap in streak (4 days ago logged, but 3 days ago missing) -> streak remains 3
      final DateTime fourDaysAgo = refDate.subtract(const Duration(days: 4));
      await storage.saveDayLog(
        DailyLog(
          dateString: DailyLog.formatDateKey(fourDaysAgo),
          entries: <FoodLogEntry>[
            FoodLogEntry(mealLabel: 'Salmon', calories: 500),
          ],
        ),
      );
      expect(await storage.calculateStreak(referenceDate: refDate), 3);

      // Case 5: Today not yet logged, but yesterday was logged -> streak carries over from yesterday
      final DateTime tomorrowRef = refDate.add(const Duration(days: 1));
      expect(await storage.calculateStreak(referenceDate: tomorrowRef), 3);
    });

    test('clearAll removes all logs and resets settings', () async {
      await storage.saveSettings(const UserSettings(dailyGoal: 3000));
      await storage.saveDayLog(
        DailyLog(
          dateString: '2026-08-18',
          entries: <FoodLogEntry>[
            FoodLogEntry(mealLabel: 'Snack', calories: 150),
          ],
        ),
      );

      await storage.clearAll();

      expect(await storage.loadAllLogs(), isEmpty);
      final UserSettings settings = await storage.loadSettings();
      expect(settings.dailyGoal, 2200);
    });
  });

  group('PreferencesCalorieStorage fallback', () {
    test('fallback memory cache works cleanly without native bindings', () async {
      final PreferencesCalorieStorage storage = PreferencesCalorieStorage();
      final DateTime today = DateTime(2026, 8, 18);

      final DailyLog log = DailyLog(
        dateString: DailyLog.formatDateKey(today),
        entries: <FoodLogEntry>[
          FoodLogEntry(mealLabel: 'Salad', calories: 200, mealType: MealType.lunch),
        ],
      );

      await storage.saveDayLog(log);
      final DailyLog? loaded = await storage.loadDayLog(today);
      expect(loaded, isNotNull);
      expect(loaded!.consumedCalories, 200);

      final int streak = await storage.calculateStreak(referenceDate: today);
      expect(streak, 1);

      await storage.deleteDayLog(today);
      expect(await storage.loadDayLog(today), isNull);
    });
  });

  group('SavedFood storage', () {
    test('serializes reusable nutrition with portion and converts it to a log entry', () {
      final SavedFood food = SavedFood(
        id: 'food_1',
        name: 'Homemade Burrito',
        calories: 540,
        proteinG: 32,
        carbsG: 58,
        fatG: 18,
        saturatedFatG: 6,
        fiberG: 8,
        addedSugarG: 2,
        sodiumMg: 750,
        portionSize: 1.0,
        portionUnit: 'serving',
        updatedAt: DateTime(2026, 8, 18, 12, 30),
      );

      expect(SavedFood.fromJson(food.toJson()), food);
      expect(food.portionDisplay, '1 serving');

      final FoodLogEntry entry = food.toFoodLogEntry(mealType: MealType.lunch);
      expect(entry.mealLabel, 'Homemade Burrito');
      expect(entry.calories, 540);
      expect(entry.proteinG, 32);
      expect(entry.carbsG, 58);
      expect(entry.fatG, 18);
      expect(entry.saturatedFatG, 6);
      expect(entry.fiberG, 8);
      expect(entry.addedSugarG, 2);
      expect(entry.sodiumMg, 750);
      expect(entry.sourceLabel, 'Saved');
      expect(entry.mealType, MealType.lunch);

      // Scaled with multiplier (e.g. 2 portions)
      final FoodLogEntry scaledEntry = food.toFoodLogEntry(
        mealType: MealType.lunch,
        portionMultiplier: 2.0,
      );
      expect(scaledEntry.calories, 1080);
      expect(scaledEntry.proteinG, 64);
      expect(scaledEntry.carbsG, 116);
      expect(scaledEntry.fatG, 36);
      expect(scaledEntry.saturatedFatG, 12);
      expect(scaledEntry.fiberG, 16);
      expect(scaledEntry.addedSugarG, 4);
      expect(scaledEntry.sodiumMg, 1500);

      // Custom portion size & unit (e.g. 100g base, chose 150g)
      final SavedFood gramFood = SavedFood(
        name: 'Chicken Breast',
        calories: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 4,
        saturatedFatG: 1,
        fiberG: 0,
        addedSugarG: 0,
        sodiumMg: 74,
        portionSize: 100.0,
        portionUnit: 'g',
      );
      expect(gramFood.portionDisplay, '100 g');
      final FoodLogEntry gramEntry = gramFood.toFoodLogEntry(chosenPortionSize: 150.0);
      expect(gramEntry.calories, 248);
      expect(gramEntry.proteinG, 47);
      expect(gramEntry.fatG, 6);
      expect(gramEntry.saturatedFatG, 2);
      expect(gramEntry.sodiumMg, 111);
    });

    test('backward compatibility: fromMap populates default portion when missing', () {
      final Map<String, dynamic> legacyMap = <String, dynamic>{
        'id': 'legacy_food',
        'name': 'Oatmeal',
        'calories': 150,
        'proteinG': 5,
        'carbsG': 27,
        'fatG': 3,
      };

      final SavedFood parsed = SavedFood.fromMap(legacyMap);
      expect(parsed.portionSize, 1.0);
      expect(parsed.portionUnit, 'serving');
      expect(parsed.portionDisplay, '1 serving');
    });

    test('saves, updates, loads, deletes, and clears reusable foods', () async {
      final CalorieStorage storage = CalorieStorage.inMemory();
      final SavedFood original = SavedFood(
        id: 'food_1',
        name: 'Overnight Oats',
        calories: 380,
        proteinG: 20,
        carbsG: 48,
        fatG: 12,
      );

      await storage.saveSavedFood(original);
      expect(await storage.loadSavedFoods(), <SavedFood>[original]);

      final SavedFood updated = original.copyWith(calories: 420);
      await storage.saveSavedFood(updated);
      final List<SavedFood> afterUpdate = await storage.loadSavedFoods();
      expect(afterUpdate, hasLength(1));
      expect(afterUpdate.single.calories, 420);

      await storage.deleteSavedFood(original.id);
      expect(await storage.loadSavedFoods(), isEmpty);

      await storage.saveSavedFood(original);
      await storage.clearAll();
      expect(await storage.loadSavedFoods(), isEmpty);
    });
  });
}
