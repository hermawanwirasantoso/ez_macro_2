import 'package:flutter_test/flutter_test.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_goal.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_tracker_state.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';

void main() {
  group('WeightUnit', () {
    test('converts kg to lbs and vice versa accurately', () {
      expect(WeightUnit.kg.convertTo(1.0, WeightUnit.lbs), closeTo(2.20462, 0.001));
      expect(WeightUnit.lbs.convertTo(2.20462, WeightUnit.kg), closeTo(1.0, 0.001));
      expect(WeightUnit.kg.convertTo(70.0, WeightUnit.kg), 70.0);
    });

    test('fromString parses various representations', () {
      expect(WeightUnit.fromString('kg'), WeightUnit.kg);
      expect(WeightUnit.fromString('lbs'), WeightUnit.lbs);
      expect(WeightUnit.fromString('lb'), WeightUnit.lbs);
      expect(WeightUnit.fromString('pounds'), WeightUnit.lbs);
      expect(WeightUnit.fromString(null), WeightUnit.kg);
    });
  });

  group('WeightGoal calculations', () {
    test('calculates BMI correctly', () {
      const WeightGoal goal = WeightGoal(
        targetWeight: 70.0,
        startingWeight: 80.0,
        heightCm: 175.0,
      );

      final double? bmi = goal.calculateBmi(70.0, WeightUnit.kg);
      expect(bmi, isNotNull);
      expect(bmi!, closeTo(22.85, 0.05));
      expect(WeightGoal.getBmiCategory(bmi), 'Normal');
    });

    test('BMI categories', () {
      expect(WeightGoal.getBmiCategory(17.5), 'Underweight');
      expect(WeightGoal.getBmiCategory(22.0), 'Normal');
      expect(WeightGoal.getBmiCategory(27.0), 'Overweight');
      expect(WeightGoal.getBmiCategory(32.0), 'Obese');
    });

    test('calculates progress for weight loss goal', () {
      const WeightGoal goal = WeightGoal(
        targetWeight: 70.0,
        startingWeight: 80.0,
        unit: WeightUnit.kg,
      );

      // At start
      expect(goal.calculateProgress(80.0, WeightUnit.kg), 0.0);
      // Halfway
      expect(goal.calculateProgress(75.0, WeightUnit.kg), closeTo(0.5, 0.01));
      // Completed
      expect(goal.calculateProgress(70.0, WeightUnit.kg), 1.0);
      // Past goal
      expect(goal.calculateProgress(68.0, WeightUnit.kg), 1.0);
      // Gained weight above start
      expect(goal.calculateProgress(82.0, WeightUnit.kg), 0.0);
    });

    test('calculates progress for weight gain / bulking goal', () {
      const WeightGoal goal = WeightGoal(
        targetWeight: 80.0,
        startingWeight: 70.0,
        unit: WeightUnit.kg,
      );

      // At start
      expect(goal.calculateProgress(70.0, WeightUnit.kg), 0.0);
      // Halfway
      expect(goal.calculateProgress(75.0, WeightUnit.kg), closeTo(0.5, 0.01));
      // Completed
      expect(goal.calculateProgress(80.0, WeightUnit.kg), 1.0);
      // Past goal
      expect(goal.calculateProgress(82.0, WeightUnit.kg), 1.0);
    });

    test('calculates remaining distance', () {
      const WeightGoal goal = WeightGoal(
        targetWeight: 70.0,
        startingWeight: 80.0,
        unit: WeightUnit.kg,
      );

      expect(goal.calculateRemaining(75.5, WeightUnit.kg), closeTo(5.5, 0.01));
    });
  });

  group('WeightTrackerState', () {
    late InMemoryWeightStorage storage;
    late WeightTrackerState state;

    setUp(() {
      storage = InMemoryWeightStorage();
      state = WeightTrackerState(storage: storage);
    });

    test('starts with empty list and default goal', () {
      expect(state.entries, isEmpty);
      expect(state.latestEntry, isNull);
      expect(state.previousEntry, isNull);
      expect(state.currentWeight, isNull);
      expect(state.lastEntryDelta, isNull);
      expect(state.totalChange, isNull);
    });

    test('adds entries and correctly sorts by date descending', () async {
      final WeightEntry oldEntry = WeightEntry(
        id: '1',
        weight: 78.0,
        date: DateTime(2026, 8, 1),
      );
      final WeightEntry newEntry = WeightEntry(
        id: '2',
        weight: 76.5,
        date: DateTime(2026, 8, 10),
      );

      await state.addEntry(oldEntry);
      await state.addEntry(newEntry);

      expect(state.entries.length, 2);
      expect(state.latestEntry?.id, '2');
      expect(state.previousEntry?.id, '1');
      expect(state.currentWeight, 76.5);
      expect(state.lastEntryDelta, closeTo(-1.5, 0.01));
    });

    test('calculates totalChange relative to starting weight if set', () async {
      await state.setGoal(const WeightGoal(
        targetWeight: 70.0,
        startingWeight: 80.0,
      ));

      await state.addEntry(WeightEntry(
        id: '1',
        weight: 76.0,
        date: DateTime(2026, 8, 10),
      ));

      expect(state.totalChange, closeTo(-4.0, 0.01));
      expect(state.goalProgress, closeTo(0.4, 0.01));
      expect(state.remainingToGoal, closeTo(6.0, 0.01));
    });

    test('filters chart entries and calculates min, max, avg, rangeChange', () async {
      final DateTime now = DateTime.now();

      await state.addEntry(WeightEntry(
        id: '1',
        weight: 75.0,
        date: now.subtract(const Duration(days: 20)),
      ));
      await state.addEntry(WeightEntry(
        id: '2',
        weight: 74.0,
        date: now.subtract(const Duration(days: 10)),
      ));
      await state.addEntry(WeightEntry(
        id: '3',
        weight: 73.5,
        date: now,
      ));

      // 30 Days filter includes all 3 entries
      state.setRange(WeightTimeRange.thirtyDays);
      expect(state.chartEntries.length, 3);
      // chart entries are sorted chronologically ascending (oldest first)
      expect(state.chartEntries.first.id, '1');
      expect(state.chartEntries.last.id, '3');

      expect(state.minWeightInRange, 73.5);
      expect(state.maxWeightInRange, 75.0);
      expect(state.averageWeightInRange, closeTo(74.167, 0.05));
      expect(state.rangeChange, closeTo(-1.5, 0.01));

      // 7 Days filter includes only entry 3
      state.setRange(WeightTimeRange.sevenDays);
      expect(state.chartEntries.length, 1);
      expect(state.chartEntries.first.id, '3');
    });

    test('can edit and delete entries', () async {
      final WeightEntry entry = WeightEntry(
        id: 'edit_me',
        weight: 75.0,
        date: DateTime(2026, 8, 5),
      );
      await state.addEntry(entry);
      expect(state.latestEntry?.weight, 75.0);

      await state.editEntry(entry.copyWith(weight: 74.5));
      expect(state.latestEntry?.weight, 74.5);

      await state.deleteEntry('edit_me');
      expect(state.entries, isEmpty);
    });
  });
}
