import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ez_macro_2/features/weight_tracker/data/weight_storage.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_entry.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_goal.dart';
import 'package:ez_macro_2/features/weight_tracker/domain/weight_unit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryWeightStorage', () {
    late InMemoryWeightStorage storage;

    setUp(() {
      storage = InMemoryWeightStorage();
    });

    test('starts empty and loads empty list', () async {
      final List<WeightEntry> entries = await storage.loadEntries();
      expect(entries, isEmpty);

      final WeightGoal goal = await storage.loadGoal();
      expect(goal.hasGoal, isFalse);
    });

    test('can save, load, and sort entries by date descending', () async {
      final WeightEntry entry1 = WeightEntry(
        id: '1',
        weight: 75.0,
        unit: WeightUnit.kg,
        date: DateTime(2026, 8, 1),
      );
      final WeightEntry entry2 = WeightEntry(
        id: '2',
        weight: 74.2,
        unit: WeightUnit.kg,
        date: DateTime(2026, 8, 5),
      );

      await storage.saveEntry(entry1);
      await storage.saveEntry(entry2);

      final List<WeightEntry> loaded = await storage.loadEntries();
      expect(loaded.length, 2);
      expect(loaded.first.id, '2');
      expect(loaded.last.id, '1');
    });

    test('can delete entry', () async {
      final WeightEntry entry = WeightEntry(
        id: '1',
        weight: 75.0,
        unit: WeightUnit.kg,
        date: DateTime(2026, 8, 1),
      );
      await storage.saveEntry(entry);
      expect((await storage.loadEntries()).length, 1);

      await storage.deleteEntry('1');
      expect((await storage.loadEntries()), isEmpty);
    });

    test('can save and load goal', () async {
      const WeightGoal goal = WeightGoal(
        targetWeight: 70.0,
        startingWeight: 78.0,
        unit: WeightUnit.kg,
        heightCm: 178.0,
      );

      await storage.saveGoal(goal);
      final WeightGoal loaded = await storage.loadGoal();
      expect(loaded.targetWeight, 70.0);
      expect(loaded.startingWeight, 78.0);
      expect(loaded.heightCm, 178.0);
    });

    test('clearAll wipes entries and resets goal', () async {
      await storage.saveEntry(WeightEntry(
        id: '1',
        weight: 75.0,
        unit: WeightUnit.kg,
        date: DateTime(2026, 8, 1),
      ));
      await storage.saveGoal(const WeightGoal(targetWeight: 70.0));

      await storage.clearAll();
      expect(await storage.loadEntries(), isEmpty);
      expect((await storage.loadGoal()).hasGoal, isFalse);
    });
  });

  group('PreferencesWeightStorage', () {
    late PreferencesWeightStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      storage = PreferencesWeightStorage();
      await storage.clearAll();
    });

    test('persists and retrieves entries via SharedPreferences', () async {
      final WeightEntry entry = WeightEntry(
        id: 'pref_1',
        weight: 80.5,
        unit: WeightUnit.kg,
        date: DateTime(2026, 8, 10, 8, 30),
        note: 'Morning fasted',
        bodyFatPercentage: 16.2,
      );

      await storage.saveEntry(entry);

      final List<WeightEntry> loaded = await storage.loadEntries();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'pref_1');
      expect(loaded.first.weight, 80.5);
      expect(loaded.first.note, 'Morning fasted');
      expect(loaded.first.bodyFatPercentage, 16.2);
    });

    test('persists and retrieves weight goals', () async {
      const WeightGoal goal = WeightGoal(
        targetWeight: 72.0,
        startingWeight: 82.0,
        unit: WeightUnit.kg,
        heightCm: 180.0,
      );

      await storage.saveGoal(goal);

      final WeightGoal loaded = await storage.loadGoal();
      expect(loaded.targetWeight, 72.0);
      expect(loaded.startingWeight, 82.0);
      expect(loaded.heightCm, 180.0);
      expect(loaded.unit, WeightUnit.kg);
    });
  });
}
