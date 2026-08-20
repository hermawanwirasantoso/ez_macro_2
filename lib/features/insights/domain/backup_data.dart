import 'dart:convert';
import '../../calorie_tracker/data/calorie_storage.dart';
import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/saved_food.dart';
import '../../calorie_tracker/domain/user_settings.dart';
import '../../weight_tracker/data/weight_storage.dart';
import '../../weight_tracker/domain/weight_entry.dart';
import '../../weight_tracker/domain/weight_goal.dart';

class BackupData {
  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.settings,
    required this.dailyLogs,
    required this.savedFoods,
    required this.weightEntries,
    this.weightGoal,
  });

  final int version;
  final DateTime exportedAt;
  final UserSettings settings;
  final List<DailyLog> dailyLogs;
  final List<SavedFood> savedFoods;
  final List<WeightEntry> weightEntries;
  final WeightGoal? weightGoal;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'settings': settings.toMap(),
      'dailyLogs': dailyLogs.map((DailyLog log) => log.toMap()).toList(),
      'savedFoods': savedFoods.map((SavedFood food) => food.toMap()).toList(),
      'weightEntries': weightEntries.map((WeightEntry entry) => entry.toMap()).toList(),
      'weightGoal': weightGoal?.toMap(),
    };
  }

  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());

  factory BackupData.fromMap(Map<String, dynamic> map) {
    return BackupData(
      version: (map['version'] as num?)?.toInt() ?? 1,
      exportedAt: DateTime.tryParse(map['exportedAt'] as String? ?? '') ?? DateTime.now(),
      settings: map['settings'] != null
          ? UserSettings.fromMap(map['settings'] as Map<String, dynamic>)
          : const UserSettings(),
      dailyLogs: (map['dailyLogs'] as List<dynamic>?)
              ?.map((dynamic e) => DailyLog.fromMap(e as Map<String, dynamic>))
              .toList() ??
          <DailyLog>[],
      savedFoods: (map['savedFoods'] as List<dynamic>?)
              ?.map((dynamic e) => SavedFood.fromMap(e as Map<String, dynamic>))
              .toList() ??
          <SavedFood>[],
      weightEntries: (map['weightEntries'] as List<dynamic>?)
              ?.map((dynamic e) => WeightEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          <WeightEntry>[],
      weightGoal: map['weightGoal'] != null
          ? WeightGoal.fromMap(map['weightGoal'] as Map<String, dynamic>)
          : null,
    );
  }

  factory BackupData.fromJson(String source) =>
      BackupData.fromMap(json.decode(source) as Map<String, dynamic>);
}

class BackupService {
  const BackupService();

  /// Exports full database snapshot into formatted JSON string.
  static Future<String> exportToJsonString({
    required CalorieStorage calorieStorage,
    required WeightStorage weightStorage,
  }) async {
    final UserSettings settings = await calorieStorage.loadSettings();
    final List<DailyLog> dailyLogs = await calorieStorage.loadAllLogs();
    final List<SavedFood> savedFoods = await calorieStorage.loadSavedFoods();
    final List<WeightEntry> weightEntries = await weightStorage.loadEntries();
    final WeightGoal? weightGoal = await weightStorage.loadGoal();

    final BackupData backup = BackupData(
      version: 1,
      exportedAt: DateTime.now(),
      settings: settings,
      dailyLogs: dailyLogs,
      savedFoods: savedFoods,
      weightEntries: weightEntries,
      weightGoal: weightGoal,
    );

    return backup.toJson();
  }

  /// Exports daily nutrition history as CSV.
  static Future<String> exportCaloriesCsv({
    required CalorieStorage calorieStorage,
  }) async {
    final List<DailyLog> logs = await calorieStorage.loadAllLogs();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Date,Total Calories,Protein (g),Carbs (g),Fat (g),Saturated Fat (g),Fiber (g),Sugar (g),Sodium (mg),Entries Count');

    for (final DailyLog log in logs) {
      final String dateStr =
          '${log.date.year.toString().padLeft(4, '0')}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}';
      buffer.writeln(
        '$dateStr,${log.totalCalories},${log.totalProteinG},${log.totalCarbsG},${log.totalFatG},${log.totalSaturatedFatG},${log.totalFiberG},${log.totalAddedSugarG},${log.totalSodiumMg},${log.entries.length}',
      );
    }

    return buffer.toString();
  }

  /// Exports weight tracking history as CSV.
  static Future<String> exportWeightCsv({
    required WeightStorage weightStorage,
  }) async {
    final List<WeightEntry> entries = await weightStorage.loadEntries();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Date,Weight,Unit,Body Fat %,Note');

    for (final WeightEntry entry in entries) {
      final String dateStr = entry.date.toIso8601String();
      final String cleanNote = (entry.note ?? '').replaceAll('"', '""');
      final String noteFormatted = cleanNote.contains(',') ? '"$cleanNote"' : cleanNote;
      buffer.writeln(
        '$dateStr,${entry.weight},${entry.unit.displayName},${entry.bodyFatPercentage ?? ''},$noteFormatted',
      );
    }

    return buffer.toString();
  }

  /// Validates and parses a JSON backup string. Returns null if invalid.
  static BackupData? validateAndParse(String jsonString) {
    try {
      final dynamic decoded = json.decode(jsonString.trim());
      if (decoded is! Map<String, dynamic>) return null;
      return BackupData.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Restores data from a [BackupData] payload into storages.
  static Future<void> restoreData({
    required BackupData data,
    required CalorieStorage calorieStorage,
    required WeightStorage weightStorage,
    bool merge = true,
  }) async {
    if (!merge) {
      await calorieStorage.clearAll();
      await weightStorage.clearAll();
    }

    // Save user settings
    await calorieStorage.saveSettings(data.settings);

    // Save daily logs
    for (final DailyLog log in data.dailyLogs) {
      await calorieStorage.saveDayLog(log);
    }

    // Save custom foods
    for (final SavedFood food in data.savedFoods) {
      await calorieStorage.saveSavedFood(food);
    }

    // Save weight entries
    for (final WeightEntry entry in data.weightEntries) {
      await weightStorage.saveEntry(entry);
    }

    // Save weight goal if present
    if (data.weightGoal != null) {
      await weightStorage.saveGoal(data.weightGoal!);
    }
  }

  /// Clears all database data.
  static Future<void> clearAllData({
    required CalorieStorage calorieStorage,
    required WeightStorage weightStorage,
  }) async {
    await calorieStorage.clearAll();
    await weightStorage.clearAll();
  }
}
