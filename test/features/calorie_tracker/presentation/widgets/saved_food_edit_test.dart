import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ez_macro_2/features/calorie_tracker/data/calorie_storage.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/daily_log.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/meal_type.dart';
import 'package:ez_macro_2/features/calorie_tracker/domain/saved_food.dart';
import 'package:ez_macro_2/features/calorie_tracker/presentation/widgets/food_entry_modal.dart';
import 'package:ez_macro_2/main.dart';

Finder _modalField(String key) => find.descendant(
  of: find.byType(FoodEntryModal).last,
  matching: find.byKey(Key(key)),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  if (!tester.any(finder)) {
    await tester.scrollUntilVisible(
      finder,
      50,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester, String id) async {
  await _tapVisible(tester, _modalField('savedFoodsExpansionTile'));
  await _tapVisible(tester, _modalField('editSavedFood_$id'));
}

Future<void> _openQuickAdd(
  WidgetTester tester, {
  required List<SavedFood> foods,
  required Future<void> Function(SavedFood) onSaveFood,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () => FoodEntryModal.showAdd(
                context,
                savedFoods: foods,
                onSaveFood: onSaveFood,
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    ),
  );
  await _tapVisible(tester, find.text('Open'));
}

void main() {
  final SavedFood original = SavedFood(
    id: 'manual_oats',
    name: 'Homemade Oats',
    calories: 200,
    proteinG: 10,
    carbsG: 30,
    fatG: 4,
    saturatedFatG: 1,
    fiberG: 3,
    addedSugarG: 2,
    sodiumMg: 100,
    portionSize: 100,
    portionUnit: 'g',
    updatedAt: DateTime(2026, 1, 1),
  );

  testWidgets('saved food edits update in place without changing past logs', (
    WidgetTester tester,
  ) async {
    final FoodLogEntry pastEntry = original
        .toFoodLogEntry(mealType: MealType.breakfast)
        .copyWith(sourceLabel: 'Manual');
    final DateTime today = DateTime.now();
    final SavedFood otherFood = SavedFood(
      id: 'other_food',
      name: 'Corrected Oats',
      calories: 80,
    );
    final CalorieStorage storage = CalorieStorage.inMemory(
      initialSavedFoods: <SavedFood>[original, otherFood],
      initialLogs: <String, DailyLog>{
        DailyLog.formatDateKey(today): DailyLog(
          dateString: DailyLog.formatDateKey(today),
          entries: <FoodLogEntry>[pastEntry],
        ),
      },
    );
    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('openQuickAddButton')));
    await _openEditor(tester, original.id);

    expect(find.text('Edit Saved Food'), findsOneWidget);
    expect(_modalField('mealTypeChip_breakfast'), findsNothing);
    expect(_modalField('scanNutritionLabelButton'), findsNothing);
    expect(_modalField('saveForFutureUseCheckbox'), findsNothing);
    expect(_modalField('portionSelectorCard'), findsNothing);
    final Map<String, String> corrections = <String, String>{
      'mealLabelField': 'Corrected Oats',
      'caloriesField': '250',
      'proteinField': '15',
      'carbsField': '35',
      'fatField': '6',
      'saturatedFatField': '2',
      'fiberField': '5',
      'addedSugarField': '3',
      'sodiumField': '150',
      'portionSizeField': '125',
      'portionUnitField': 'ml',
    };
    for (final MapEntry<String, String> field in corrections.entries) {
      await tester.enterText(_modalField(field.key), field.value);
    }
    await _tapVisible(tester, _modalField('saveEntryButton'));

    expect(find.text('Edit Saved Food'), findsNothing);
    final List<SavedFood> saved = await storage.loadSavedFoods();
    expect(saved, hasLength(2));
    final SavedFood edited = saved.firstWhere(
      (SavedFood f) => f.id == original.id,
    );
    expect(edited.name, 'Corrected Oats');
    expect(edited.calories, 250);
    expect(edited.proteinG, 15);
    expect(edited.carbsG, 35);
    expect(edited.fatG, 6);
    expect(edited.saturatedFatG, 2);
    expect(edited.fiberG, 5);
    expect(edited.addedSugarG, 3);
    expect(edited.sodiumMg, 150);
    expect(edited.portionSize, 125);
    expect(edited.portionUnit, 'ml');
    expect(edited.updatedAt.isAfter(original.updatedAt), isTrue);
    expect(
      saved.firstWhere((SavedFood f) => f.id == otherFood.id).calories,
      80,
    );
    expect(
      (await storage.loadDayLog(today))!.entries.single.toMap(),
      pastEntry.toMap(),
    );

    final Finder tile = _modalField('savedFoodTile_${original.id}');
    expect(
      find.descendant(of: tile, matching: find.text('Corrected Oats')),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text('Cancel').last);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MacroTrackerApp(calorieStorage: storage));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('openQuickAddButton')));
    await _tapVisible(tester, _modalField('savedFoodsExpansionTile'));
    await _tapVisible(tester, _modalField('savedFoodTile_${original.id}'));
    await _tapVisible(tester, _modalField('portionChip_2'));
    expect(
      tester.widget<TextField>(_modalField('caloriesField')).controller!.text,
      '500',
    );
    await _tapVisible(tester, _modalField('saveEntryButton'));

    final DailyLog log = (await storage.loadDayLog(today))!;
    expect(log.entries, hasLength(2));
    expect(log.consumedCalories, 700);
    final FoodLogEntry newEntry = log.entries.firstWhere(
      (FoodLogEntry e) => e.id != pastEntry.id,
    );
    expect(newEntry.mealLabel, 'Corrected Oats');
    expect(newEntry.portionSize, 250);
    expect(newEntry.portionUnit, 'ml');
    expect(newEntry.proteinG, 30);
    expect(
      log.entries.firstWhere((FoodLogEntry e) => e.id == pastEntry.id).toMap(),
      pastEntry.toMap(),
    );
  });

  testWidgets(
    'canceling a saved food edit preserves the food and quick-add draft',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int saves = 0;
      await _openQuickAdd(
        tester,
        foods: <SavedFood>[original],
        onSaveFood: (_) async {
          saves++;
        },
      );
      await tester.enterText(_modalField('mealLabelField'), 'Unsaved lunch');
      await _openEditor(tester, original.id);

      final Map<String, String> expected = <String, String>{
        'mealLabelField': original.name,
        'caloriesField': '200',
        'proteinField': '10',
        'carbsField': '30',
        'fatField': '4',
        'saturatedFatField': '1',
        'fiberField': '3',
        'addedSugarField': '2',
        'sodiumField': '100',
        'portionSizeField': '100',
        'portionUnitField': 'g',
      };
      for (final MapEntry<String, String> field in expected.entries) {
        expect(
          tester.widget<TextField>(_modalField(field.key)).controller!.text,
          field.value,
        );
      }
      await tester.enterText(_modalField('mealLabelField'), 'Discard this');
      await tester.enterText(_modalField('caloriesField'), '900');
      await _tapVisible(tester, find.text('Cancel').last);

      expect(saves, 0);
      expect(find.text(original.name), findsOneWidget);
      expect(
        tester
            .widget<TextField>(_modalField('mealLabelField'))
            .controller!
            .text,
        'Unsaved lunch',
      );
    },
  );

  testWidgets('saved food corrections are persisted to preferences', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ez_macro_saved_foods_v1': json.encode(<Map<String, dynamic>>[
        original.toMap(),
      ]),
    });
    final CalorieStorage storage = CalorieStorage.preferences();
    await _openQuickAdd(
      tester,
      foods: await storage.loadSavedFoods(),
      onSaveFood: storage.saveSavedFood,
    );
    await _openEditor(tester, original.id);
    await tester.enterText(_modalField('caloriesField'), '275');
    await _tapVisible(tester, _modalField('saveEntryButton'));

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<dynamic> persisted = json.decode(
      preferences.getString('ez_macro_saved_foods_v1')!,
    ) as List<dynamic>;
    expect(persisted, hasLength(1));
    expect(persisted.single['id'], original.id);
    expect(persisted.single['calories'], 275);
    final List<SavedFood> reloaded = await CalorieStorage.preferences()
        .loadSavedFoods();
    expect(reloaded.single.id, original.id);
    expect(reloaded.single.calories, 275);
  });

  testWidgets('invalid saved food corrections cannot be saved', (
    WidgetTester tester,
  ) async {
    int saves = 0;
    await _openQuickAdd(
      tester,
      foods: <SavedFood>[original],
      onSaveFood: (_) async {
        saves++;
      },
    );
    await _openEditor(tester, original.id);

    final List<(String, String, String)> invalidFields =
        <(String, String, String)>[
          ('mealLabelField', ' ', original.name),
          ('caloriesField', '0', '200'),
          ('caloriesField', 'abc', '200'),
          ('proteinField', '-10', '10'),
          ('sodiumField', 'NaN', '100'),
          ('portionSizeField', '0', '100'),
          ('portionSizeField', '-5', '100'),
          ('portionSizeField', 'abc', '100'),
          ('portionSizeField', 'NaN', '100'),
          ('portionSizeField', 'Infinity', '100'),
          ('portionUnitField', ' ', 'g'),
        ];
    for (final (String key, String invalid, String valid) in invalidFields) {
      await tester.enterText(_modalField(key), invalid);
      await _tapVisible(tester, _modalField('saveEntryButton'));
      expect(saves, 0, reason: '$key must reject $invalid');
      expect(find.text('Edit Saved Food'), findsOneWidget);
      await tester.enterText(_modalField(key), valid);
    }
  });

  testWidgets('a failed saved food update stays open and can be retried', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    SavedFood? saved;
    await _openQuickAdd(
      tester,
      foods: <SavedFood>[original],
      onSaveFood: (SavedFood food) async {
        attempts++;
        if (attempts == 1) throw StateError('Storage unavailable');
        saved = food;
      },
    );
    await _openEditor(tester, original.id);
    await tester.enterText(_modalField('caloriesField'), '250');
    await _tapVisible(tester, _modalField('saveEntryButton'));

    expect(find.text('Edit Saved Food'), findsOneWidget);
    expect(
      find.text('Could not update this saved food. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_modalField('caloriesField')).controller!.text,
      '250',
    );
    await _tapVisible(tester, _modalField('saveEntryButton'));
    expect(attempts, 2);
    expect(saved!.id, original.id);
    expect(saved!.calories, 250);
    expect(find.text('Edit Saved Food'), findsNothing);
  });

  testWidgets('save is disabled while a saved food update is pending', (
    WidgetTester tester,
  ) async {
    final Completer<void> pendingSave = Completer<void>();
    int saves = 0;
    await _openQuickAdd(
      tester,
      foods: <SavedFood>[original],
      onSaveFood: (_) {
        saves++;
        return pendingSave.future;
      },
    );
    await _openEditor(tester, original.id);
    await _tapVisible(tester, _modalField('saveEntryButton'));

    expect(saves, 1);
    expect(
      tester.widget<FilledButton>(_modalField('saveEntryButton')).onPressed,
      isNull,
    );
    expect(find.text('Saving...'), findsOneWidget);
    pendingSave.complete();
    await tester.pumpAndSettle();
    expect(find.text('Edit Saved Food'), findsNothing);
    expect(saves, 1);
  });

  testWidgets('editing the selected saved food refreshes its scaled draft', (
    WidgetTester tester,
  ) async {
    await _openQuickAdd(
      tester,
      foods: <SavedFood>[original],
      onSaveFood: (_) async {},
    );
    await _tapVisible(tester, _modalField('savedFoodsExpansionTile'));
    await _tapVisible(tester, _modalField('savedFoodTile_${original.id}'));
    await _tapVisible(tester, _modalField('portionChip_2'));
    await _openEditor(tester, original.id);
    await tester.enterText(_modalField('caloriesField'), '250');
    await tester.enterText(_modalField('portionSizeField'), '125');
    await _tapVisible(tester, _modalField('saveEntryButton'));

    expect(
      tester.widget<TextField>(_modalField('caloriesField')).controller!.text,
      '500',
    );
    expect(
      tester
          .widget<TextField>(_modalField('portionInputField'))
          .controller!
          .text,
      '250',
    );
    expect(find.text('Base: 125 g'), findsOneWidget);
  });
}
