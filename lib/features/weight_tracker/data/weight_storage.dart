import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/weight_entry.dart';
import '../domain/weight_goal.dart';

/// Abstract storage interface for weight logs and goal preferences.
abstract class WeightStorage {
  const WeightStorage();

  factory WeightStorage.preferences() => PreferencesWeightStorage();

  factory WeightStorage.inMemory({
    List<WeightEntry>? initialEntries,
    WeightGoal? initialGoal,
  }) =>
      InMemoryWeightStorage(
        initialEntries: initialEntries,
        initialGoal: initialGoal,
      );

  /// Loads all weight entries sorted chronologically (latest first).
  Future<List<WeightEntry>> loadEntries();

  /// Saves or updates a weight entry.
  Future<void> saveEntry(WeightEntry entry);

  /// Deletes a weight entry by its [id].
  Future<void> deleteEntry(String id);

  /// Loads the stored user weight goal and height settings.
  Future<WeightGoal> loadGoal();

  /// Saves the user weight goal and height settings.
  Future<void> saveGoal(WeightGoal goal);

  /// Clears all weight entries and resets goals.
  Future<void> clearAll();
}

/// Production implementation of [WeightStorage] backed by [SharedPreferences].
class PreferencesWeightStorage implements WeightStorage {
  const PreferencesWeightStorage();

  static const String _entriesKey = 'ez_macro_weight_entries_v1';
  static const String _goalKey = 'ez_macro_weight_goal_v1';

  static final Map<String, WeightEntry> _memoryEntries = <String, WeightEntry>{};
  static WeightGoal? _memoryGoal;
  static SharedPreferences? _cachedPrefs;

  Future<SharedPreferences?> _getPrefs() async {
    if (_cachedPrefs != null) return _cachedPrefs;
    try {
      _cachedPrefs = await SharedPreferences.getInstance();
      return _cachedPrefs;
    } catch (e) {
      _debugLog('Could not initialize SharedPreferences for weight storage: $e');
      return null;
    }
  }

  @override
  Future<List<WeightEntry>> loadEntries() async {
    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        final String? jsonStr = prefs.getString(_entriesKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final dynamic decoded = json.decode(jsonStr);
          if (decoded is List<dynamic>) {
            final Map<String, WeightEntry> parsed = <String, WeightEntry>{};
            for (final dynamic item in decoded) {
              if (item is Map<String, dynamic>) {
                final WeightEntry entry = WeightEntry.fromMap(item);
                parsed[entry.id] = entry;
              }
            }
            _memoryEntries
              ..clear()
              ..addAll(parsed);
          }
        }
      }
    } catch (e) {
      _debugLog('Failed to load weight entries from preferences: $e');
    }

    return _sortedEntries();
  }

  @override
  Future<void> saveEntry(WeightEntry entry) async {
    _memoryEntries[entry.id] = entry;
    try {
      await _persistEntries();
    } catch (e) {
      _debugLog('Failed to save weight entry ${entry.id}: $e');
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    _memoryEntries.remove(id);
    try {
      await _persistEntries();
    } catch (e) {
      _debugLog('Failed to delete weight entry $id: $e');
    }
  }

  Future<void> _persistEntries() async {
    final SharedPreferences? prefs = await _getPrefs();
    if (prefs != null) {
      final String jsonStr = json.encode(
        _memoryEntries.values.map((WeightEntry e) => e.toMap()).toList(),
      );
      await prefs.setString(_entriesKey, jsonStr);
    }
  }

  List<WeightEntry> _sortedEntries() {
    final List<WeightEntry> sorted = _memoryEntries.values.toList()
      ..sort((WeightEntry a, WeightEntry b) => b.date.compareTo(a.date));
    return sorted;
  }

  @override
  Future<WeightGoal> loadGoal() async {
    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        final String? jsonStr = prefs.getString(_goalKey);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final WeightGoal goal = WeightGoal.fromJson(jsonStr);
          _memoryGoal = goal;
          return goal;
        }
      }
    } catch (e) {
      _debugLog('Failed to load weight goal from preferences: $e');
    }
    return _memoryGoal ?? const WeightGoal();
  }

  @override
  Future<void> saveGoal(WeightGoal goal) async {
    _memoryGoal = goal;
    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.setString(_goalKey, goal.toJson());
      }
    } catch (e) {
      _debugLog('Failed to save weight goal: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    _memoryEntries.clear();
    _memoryGoal = const WeightGoal();
    _cachedPrefs = null;

    try {
      final SharedPreferences? prefs = await _getPrefs();
      if (prefs != null) {
        await prefs.remove(_entriesKey);
        await prefs.remove(_goalKey);
      }
    } catch (e) {
      _debugLog('Failed to clear weight data: $e');
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }
}

/// In-memory implementation of [WeightStorage] for hermetic testing.
class InMemoryWeightStorage implements WeightStorage {
  InMemoryWeightStorage({
    List<WeightEntry>? initialEntries,
    WeightGoal? initialGoal,
  })  : _entries = <String, WeightEntry>{
          for (final WeightEntry e in initialEntries ?? <WeightEntry>[]) e.id: e,
        },
        _goal = initialGoal ?? const WeightGoal();

  final Map<String, WeightEntry> _entries;
  WeightGoal _goal;

  @override
  Future<List<WeightEntry>> loadEntries() async {
    final List<WeightEntry> sorted = _entries.values.toList()
      ..sort((WeightEntry a, WeightEntry b) => b.date.compareTo(a.date));
    return sorted;
  }

  @override
  Future<void> saveEntry(WeightEntry entry) async {
    _entries[entry.id] = entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.remove(id);
  }

  @override
  Future<WeightGoal> loadGoal() async {
    return _goal;
  }

  @override
  Future<void> saveGoal(WeightGoal goal) async {
    _goal = goal;
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
    _goal = const WeightGoal();
  }
}
