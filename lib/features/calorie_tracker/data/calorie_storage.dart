import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/daily_log.dart';
import '../domain/saved_food.dart';
import '../domain/user_settings.dart';

/// Abstract storage interface for saving and retrieving calorie logs and settings.
abstract class CalorieStorage {
  const CalorieStorage();

  /// Creates a default persistent [PreferencesCalorieStorage].
  factory CalorieStorage.preferences() => PreferencesCalorieStorage();

  /// Creates an in-memory [InMemoryCalorieStorage] for testing.
  factory CalorieStorage.inMemory({
    UserSettings? initialSettings,
    Map<String, DailyLog>? initialLogs,
    List<SavedFood>? initialSavedFoods,
  }) =>
      InMemoryCalorieStorage(
        initialSettings: initialSettings,
        initialLogs: initialLogs,
        initialSavedFoods: initialSavedFoods,
      );

  /// Loads the [DailyLog] for the specified [date]. Returns null if not found.
  Future<DailyLog?> loadDayLog(DateTime date);

  /// Persists the given [DailyLog].
  Future<void> saveDayLog(DailyLog log);

  /// Deletes the log for the given [date].
  Future<void> deleteDayLog(DateTime date);

  /// Loads all saved daily logs, sorted by date descending.
  Future<List<DailyLog>> loadAllLogs();

  /// Loads reusable foods saved by the user, most recently updated first.
  Future<List<SavedFood>> loadSavedFoods();

  /// Adds or updates a reusable food in the saved-food catalog.
  Future<void> saveSavedFood(SavedFood food);

  /// Removes a reusable food from the saved-food catalog.
  Future<void> deleteSavedFood(String id);

  /// Loads user macro settings and preferences.
  Future<UserSettings> loadSettings();

  /// Saves user macro settings and preferences.
  Future<void> saveSettings(UserSettings settings);

  /// Calculates the current consecutive logging streak in days.
  Future<int> calculateStreak({DateTime? referenceDate});

  /// Clears all saved logs and resets settings.
  Future<void> clearAll();
}

/// Production implementation of [CalorieStorage] backed by [SharedPreferences].
///
/// Features an in-memory session cache fallback to ensure non-blocking and
/// crash-free operation across unit tests, hot-reloads, and platform channels.
class PreferencesCalorieStorage implements CalorieStorage {
  const PreferencesCalorieStorage();

  static const String _settingsKey = 'ez_macro_user_settings_v1';
  static const String _logKeyPrefix = 'ez_macro_day_log_';
  static const String _loggedDatesKey = 'ez_macro_logged_dates_index_v1';
  static const String _savedFoodsKey = 'ez_macro_saved_foods_v1';

  // Shared in-memory session cache
  static final Map<String, DailyLog> _memoryLogs = <String, DailyLog>{};
  static final Map<String, SavedFood> _memorySavedFoods = <String, SavedFood>{};
  static UserSettings? _memorySettings;

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      _debugLog('Could not initialize SharedPreferences, using session cache: $e');
      return null;
    }
  }

  @override
  Future<DailyLog?> loadDayLog(DateTime date) async {
    final String dateKey = DailyLog.formatDateKey(date);

    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        final String? jsonStr = prefs.getString('$_logKeyPrefix$dateKey');
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final DailyLog log = DailyLog.fromJson(jsonStr);
          _memoryLogs[dateKey] = log;
          return log;
        }
      }
    } catch (e) {
      _debugLog('Failed to read day log for $dateKey from preferences: $e');
    }

    return _memoryLogs[dateKey];
  }

  @override
  Future<void> saveDayLog(DailyLog log) async {
    final String dateKey = log.dateString;
    _memoryLogs[dateKey] = log;

    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString('$_logKeyPrefix$dateKey', log.toJson());

        // Update index of logged dates
        final List<String> dates = prefs.getStringList(_loggedDatesKey) ?? <String>[];
        if (!dates.contains(dateKey)) {
          dates.add(dateKey);
          await prefs.setStringList(_loggedDatesKey, dates);
        }
      }
    } catch (e) {
      _debugLog('Failed to save day log for $dateKey to preferences: $e');
    }
  }

  @override
  Future<void> deleteDayLog(DateTime date) async {
    final String dateKey = DailyLog.formatDateKey(date);
    _memoryLogs.remove(dateKey);

    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.remove('$_logKeyPrefix$dateKey');
        final List<String> dates = prefs.getStringList(_loggedDatesKey) ?? <String>[];
        if (dates.contains(dateKey)) {
          dates.remove(dateKey);
          await prefs.setStringList(_loggedDatesKey, dates);
        }
      }
    } catch (e) {
      _debugLog('Failed to delete day log for $dateKey: $e');
    }
  }

  @override
  Future<List<DailyLog>> loadAllLogs() async {
    final Map<String, DailyLog> results = Map<String, DailyLog>.from(_memoryLogs);

    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        final List<String> dates = prefs.getStringList(_loggedDatesKey) ?? <String>[];
        for (final String dateKey in dates) {
          final String? jsonStr = prefs.getString('$_logKeyPrefix$dateKey');
          if (jsonStr != null && jsonStr.isNotEmpty) {
            results[dateKey] = DailyLog.fromJson(jsonStr);
          }
        }
      }
    } catch (e) {
      _debugLog('Failed to load all logs from preferences: $e');
    }

    final List<DailyLog> sorted = results.values.toList()
      ..sort((DailyLog a, DailyLog b) => b.dateString.compareTo(a.dateString));
    return sorted;
  }

  @override
  Future<List<SavedFood>> loadSavedFoods() async {
    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        final String? jsonStr = prefs.getString(_savedFoodsKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final dynamic decoded = json.decode(jsonStr);
          if (decoded is List<dynamic>) {
            final Map<String, SavedFood> parsed = <String, SavedFood>{};
            for (final dynamic item in decoded) {
              if (item is Map<String, dynamic>) {
                final SavedFood food = SavedFood.fromMap(item);
                if (food.id.isNotEmpty && food.name.isNotEmpty) {
                  parsed[food.id] = food;
                }
              }
            }
            _memorySavedFoods
              ..clear()
              ..addAll(parsed);
            return _sortedSavedFoods();
          }
        }
      }
    } catch (e) {
      _debugLog('Failed to load saved foods from preferences: $e');
    }

    return _sortedSavedFoods();
  }

  @override
  Future<void> saveSavedFood(SavedFood food) async {
    _memorySavedFoods[food.id] = food;

    try {
      await _persistSavedFoods();
    } catch (e) {
      _debugLog('Failed to save saved food ${food.id} to preferences: $e');
    }
  }

  @override
  Future<void> deleteSavedFood(String id) async {
    _memorySavedFoods.remove(id);

    try {
      await _persistSavedFoods();
    } catch (e) {
      _debugLog('Failed to delete saved food $id from preferences: $e');
    }
  }

  Future<void> _persistSavedFoods() async {
    final SharedPreferences? prefs = await _getPrefs();
    if (prefs != null) {
      final String jsonStr = json.encode(
        _memorySavedFoods.values.map((SavedFood food) => food.toMap()).toList(),
      );
      await prefs.setString(_savedFoodsKey, jsonStr);
    }
  }

  List<SavedFood> _sortedSavedFoods() {
    final List<SavedFood> sorted = _memorySavedFoods.values.toList()
      ..sort((SavedFood a, SavedFood b) {
        final int byDate = b.updatedAt.compareTo(a.updatedAt);
        if (byDate != 0) return byDate;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  @override
  Future<UserSettings> loadSettings() async {
    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        final String? jsonStr = prefs.getString(_settingsKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final UserSettings settings = UserSettings.fromJson(jsonStr);
          _memorySettings = settings;
          return settings;
        }
      }
    } catch (e) {
      _debugLog('Failed to load settings from preferences: $e');
    }
    return _memorySettings ?? const UserSettings();
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    _memorySettings = settings;
    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(_settingsKey, settings.toJson());
      }
    } catch (e) {
      _debugLog('Failed to save settings to preferences: $e');
    }
  }

  @override
  Future<int> calculateStreak({DateTime? referenceDate}) async {
    final List<DailyLog> allLogs = await loadAllLogs();
    final Set<String> activeDays = allLogs
        .where((DailyLog l) => l.entries.isNotEmpty)
        .map((DailyLog l) => l.dateString)
        .toSet();

    if (activeDays.isEmpty) {
      return 0;
    }

    final DateTime ref = referenceDate ?? DateTime.now();
    DateTime currentDay = DateTime(ref.year, ref.month, ref.day);
    String currentKey = DailyLog.formatDateKey(currentDay);

    int streak = 0;

    // If today has no entries yet, check if streak can continue from yesterday
    if (!activeDays.contains(currentKey)) {
      final DateTime yesterday = currentDay.subtract(const Duration(days: 1));
      final String yesterdayKey = DailyLog.formatDateKey(yesterday);
      if (!activeDays.contains(yesterdayKey)) {
        return 0;
      }
      currentDay = yesterday;
      currentKey = yesterdayKey;
    }

    // Count backwards day-by-day
    while (activeDays.contains(currentKey)) {
      streak += 1;
      currentDay = currentDay.subtract(const Duration(days: 1));
      currentKey = DailyLog.formatDateKey(currentDay);
    }

    return streak;
  }

  @override
  Future<void> clearAll() async {
    _memoryLogs.clear();
    _memorySavedFoods.clear();
    _memorySettings = const UserSettings();

    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        final List<String> dates = prefs.getStringList(_loggedDatesKey) ?? <String>[];
        for (final String d in dates) {
          await prefs.remove('$_logKeyPrefix$d');
        }
        await prefs.remove(_loggedDatesKey);
        await prefs.remove(_settingsKey);
        await prefs.remove(_savedFoodsKey);
      }
    } catch (e) {
      _debugLog('Failed to clear all data: $e');
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }
}

/// In-memory implementation of [CalorieStorage] for unit tests.
class InMemoryCalorieStorage implements CalorieStorage {
  InMemoryCalorieStorage({
    UserSettings? initialSettings,
    Map<String, DailyLog>? initialLogs,
    List<SavedFood>? initialSavedFoods,
  })  : _settings = initialSettings ?? const UserSettings(),
        _logs = initialLogs != null ? Map<String, DailyLog>.from(initialLogs) : <String, DailyLog>{},
        _savedFoods = <String, SavedFood>{
          for (final SavedFood food in initialSavedFoods ?? <SavedFood>[]) food.id: food,
        };

  UserSettings _settings;
  final Map<String, DailyLog> _logs;
  final Map<String, SavedFood> _savedFoods;

  @override
  Future<DailyLog?> loadDayLog(DateTime date) async {
    final String dateKey = DailyLog.formatDateKey(date);
    return _logs[dateKey];
  }

  @override
  Future<void> saveDayLog(DailyLog log) async {
    _logs[log.dateString] = log;
  }

  @override
  Future<void> deleteDayLog(DateTime date) async {
    final String dateKey = DailyLog.formatDateKey(date);
    _logs.remove(dateKey);
  }

  @override
  Future<List<DailyLog>> loadAllLogs() async {
    final List<DailyLog> sorted = _logs.values.toList()
      ..sort((DailyLog a, DailyLog b) => b.dateString.compareTo(a.dateString));
    return sorted;
  }

  @override
  Future<List<SavedFood>> loadSavedFoods() async {
    final List<SavedFood> sorted = _savedFoods.values.toList()
      ..sort((SavedFood a, SavedFood b) {
        final int byDate = b.updatedAt.compareTo(a.updatedAt);
        if (byDate != 0) return byDate;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  @override
  Future<void> saveSavedFood(SavedFood food) async {
    _savedFoods[food.id] = food;
  }

  @override
  Future<void> deleteSavedFood(String id) async {
    _savedFoods.remove(id);
  }

  @override
  Future<UserSettings> loadSettings() async {
    return _settings;
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    _settings = settings;
  }

  @override
  Future<int> calculateStreak({DateTime? referenceDate}) async {
    final Set<String> activeDays = _logs.values
        .where((DailyLog l) => l.entries.isNotEmpty)
        .map((DailyLog l) => l.dateString)
        .toSet();

    if (activeDays.isEmpty) {
      return 0;
    }

    final DateTime ref = referenceDate ?? DateTime.now();
    DateTime currentDay = DateTime(ref.year, ref.month, ref.day);
    String currentKey = DailyLog.formatDateKey(currentDay);

    int streak = 0;

    if (!activeDays.contains(currentKey)) {
      final DateTime yesterday = currentDay.subtract(const Duration(days: 1));
      final String yesterdayKey = DailyLog.formatDateKey(yesterday);
      if (!activeDays.contains(yesterdayKey)) {
        return 0;
      }
      currentDay = yesterday;
      currentKey = yesterdayKey;
    }

    while (activeDays.contains(currentKey)) {
      streak += 1;
      currentDay = currentDay.subtract(const Duration(days: 1));
      currentKey = DailyLog.formatDateKey(currentDay);
    }

    return streak;
  }

  @override
  Future<void> clearAll() async {
    _logs.clear();
    _savedFoods.clear();
    _settings = const UserSettings();
  }
}
