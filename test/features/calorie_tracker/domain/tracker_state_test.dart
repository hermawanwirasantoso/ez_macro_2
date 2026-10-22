import 'package:flutter_test/flutter_test.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/tracker_state.dart';

void main() {
  group('FoodLogEntry.asNewLogAgain', () {
    test('creates a copy with a fresh id but identical nutrition data', () {
      final FoodLogEntry original = FoodLogEntry(
        mealLabel: 'Chicken Bowl',
        calories: 540,
        proteinG: 42,
        carbsG: 55,
        fatG: 16,
        saturatedFatG: 4,
        fiberG: 7,
        addedSugarG: 3,
        sodiumMg: 620,
        portionSize: 1.5,
        portionUnit: 'bowl',
        rangeText: '500-580 kcal',
        sourceLabel: 'AI',
        spreadPercent: 0.08,
        mealType: MealType.dinner,
      );

      final FoodLogEntry copy = original.asNewLogAgain();

      expect(copy.id, isNot(original.id));
      expect(copy.mealLabel, original.mealLabel);
      expect(copy.calories, original.calories);
      expect(copy.proteinG, original.proteinG);
      expect(copy.carbsG, original.carbsG);
      expect(copy.fatG, original.fatG);
      expect(copy.saturatedFatG, original.saturatedFatG);
      expect(copy.fiberG, original.fiberG);
      expect(copy.addedSugarG, original.addedSugarG);
      expect(copy.sodiumMg, original.sodiumMg);
      expect(copy.portionSize, original.portionSize);
      expect(copy.portionUnit, original.portionUnit);
      expect(copy.rangeText, original.rangeText);
      expect(copy.sourceLabel, original.sourceLabel);
      expect(copy.spreadPercent, original.spreadPercent);
      expect(copy.mealType, MealType.dinner);
    });
  });

  group('CalorieTrackerState.addCopiedEntries', () {
    test('adds copies with fresh ids and recalculates totals', () async {
      final CalorieStorage storage = CalorieStorage.inMemory();
      final CalorieTrackerState state = CalorieTrackerState(storage: storage);

      final FoodLogEntry first = FoodLogEntry(
        mealLabel: 'Oatmeal',
        calories: 300,
        proteinG: 10,
        carbsG: 50,
        fatG: 6,
        mealType: MealType.breakfast,
      );
      final FoodLogEntry second = FoodLogEntry(
        mealLabel: 'Chicken Bowl',
        calories: 540,
        proteinG: 42,
        carbsG: 55,
        fatG: 16,
        mealType: MealType.dinner,
      );

      state.addCopiedEntries(<FoodLogEntry>[first, second]);
      await Future<void>.delayed(Duration.zero);

      expect(state.entries, hasLength(2));
      expect(state.entries.map((FoodLogEntry e) => e.id).toSet(), hasLength(2));
      expect(state.entries.map((FoodLogEntry e) => e.id), isNot(contains(first.id)));
      expect(state.entries.map((FoodLogEntry e) => e.id), isNot(contains(second.id)));
      expect(state.consumedCalories, 840);
      expect(state.proteinG, 52);
      expect(state.carbsG, 105);
      expect(state.fatG, 22);

      final DailyLog? saved = await storage.loadDayLog(state.selectedDate);
      expect(saved, isNotNull);
      expect(saved!.entries, hasLength(2));
    });

    test('is a no-op for an empty list', () async {
      final CalorieTrackerState state =
          CalorieTrackerState(storage: CalorieStorage.inMemory());

      state.addCopiedEntries(<FoodLogEntry>[]);
      await Future<void>.delayed(Duration.zero);

      expect(state.entries, isEmpty);
      expect(state.consumedCalories, 0);
    });

    test('appends copies on top of existing entries', () async {
      final CalorieTrackerState state =
          CalorieTrackerState(storage: CalorieStorage.inMemory());

      state.addCalories(calories: 200, mealLabel: 'Existing Snack');
      await Future<void>.delayed(Duration.zero);

      final FoodLogEntry copied = FoodLogEntry(
        mealLabel: 'Copied Lunch',
        calories: 650,
        mealType: MealType.lunch,
      );
      state.addCopiedEntries(<FoodLogEntry>[copied]);
      await Future<void>.delayed(Duration.zero);

      expect(state.entries, hasLength(2));
      expect(state.consumedCalories, 850);
      expect(state.entries.first.mealLabel, 'Copied Lunch');
      expect(state.entries.last.mealLabel, 'Existing Snack');
    });
  });

  group('CalorieTrackerState.restoreEntries', () {
    test('puts a removed entry back at its position on the same day', () async {
      final CalorieTrackerState state = CalorieTrackerState(storage: CalorieStorage.inMemory());
      state.addCalories(calories: 300, mealLabel: 'Breakfast');
      state.addCalories(calories: 600, mealLabel: 'Lunch');
      state.addCalories(calories: 700, mealLabel: 'Dinner');

      final FoodLogEntry removed = state.removeEntryAt(1)!;
      expect(removed.mealLabel, 'Lunch');
      expect(state.consumedCalories, 1000);

      await state.restoreEntries(<FoodLogEntry>[removed], date: state.selectedDate, index: 1);
      expect(state.entries.map((FoodLogEntry e) => e.mealLabel), <String>['Dinner', 'Lunch', 'Breakfast']);
      expect(state.consumedCalories, 1600);

      // A second undo of the same entry is ignored.
      await state.restoreEntries(<FoodLogEntry>[removed], date: state.selectedDate, index: 1);
      expect(state.entries, hasLength(3));
    });

    test('restores a cleared day after newer entries', () async {
      final CalorieTrackerState state = CalorieTrackerState(storage: CalorieStorage.inMemory());
      state.addCalories(calories: 300, mealLabel: 'Breakfast');
      state.addCalories(calories: 600, mealLabel: 'Lunch');
      final List<FoodLogEntry> cleared = List<FoodLogEntry>.of(state.entries);

      state.clearCurrentDay();
      state.addCalories(calories: 150, mealLabel: 'Snack');
      await state.restoreEntries(cleared, date: state.selectedDate);

      expect(state.entries.map((FoodLogEntry e) => e.mealLabel), <String>['Snack', 'Lunch', 'Breakfast']);
      expect(state.consumedCalories, 1050);
    });

    test('writes to storage when another day is being viewed', () async {
      final CalorieStorage storage = CalorieStorage.inMemory();
      final DateTime today = DateTime.now();
      final CalorieTrackerState state = CalorieTrackerState(storage: storage, selectedDate: today);
      state.addCalories(calories: 450, mealLabel: 'Pasta');
      final FoodLogEntry removed = state.removeEntryAt(0)!;
      await state.saveToStorage();

      await state.loadForDate(today.subtract(const Duration(days: 1)));
      await state.restoreEntries(<FoodLogEntry>[removed], date: today, index: 0);

      expect(state.entries, isEmpty);
      final DailyLog? todayLog = await storage.loadDayLog(today);
      expect(todayLog!.entries.single.mealLabel, 'Pasta');
    });
  });
}
