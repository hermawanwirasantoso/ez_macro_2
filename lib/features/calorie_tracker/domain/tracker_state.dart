import 'daily_log.dart';
import 'meal_type.dart';
import 'user_settings.dart';
import '../data/calorie_storage.dart';

export 'daily_log.dart' show FoodLogEntry, DailyLog;
export 'meal_type.dart';
export 'user_settings.dart';

/// Central state management for daily calorie and macro tracking.
///
/// Supports multi-day browsing, meal category filtering, active streak tracking,
/// and automatic persistent storage integration.
class CalorieTrackerState {
  CalorieTrackerState({
    this.dailyGoal = 2200,
    this.targetProteinG = 160,
    this.targetCarbsG = 255,
    this.targetFatG = 60,
    this.consumedCalories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.saturatedFatG = 0,
    this.fiberG = 0,
    this.addedSugarG = 0,
    this.sodiumMg = 0,
    this.totalSpreadPercent = 0,
    this.spreadSamples = 0,
    this.streakDays = 0,
    DateTime? selectedDate,
    this.selectedMealFilter,
    List<FoodLogEntry>? entries,
    this.storage,
  })  : selectedDate = selectedDate ?? DateTime.now(),
        entries = entries ?? <FoodLogEntry>[];

  int dailyGoal;
  int targetProteinG;
  int targetCarbsG;
  int targetFatG;
  int consumedCalories;
  int proteinG;
  int carbsG;
  int fatG;
  int saturatedFatG;
  int fiberG;
  int addedSugarG;
  int sodiumMg;
  double totalSpreadPercent;
  int spreadSamples;
  int streakDays;
  DateTime selectedDate;
  MealType? selectedMealFilter;
  final List<FoodLogEntry> entries;
  CalorieStorage? storage;

  void attachStorage(CalorieStorage storage) {
    this.storage = storage;
  }

  int get remainingCalories => (dailyGoal - consumedCalories).clamp(0, 99999).toInt();
  int get caloriesFromTargets =>
      (targetProteinG * 4) + (targetCarbsG * 4) + (targetFatG * 9);
  double get averageSpreadPercent =>
      spreadSamples == 0 ? 0 : totalSpreadPercent / spreadSamples;

  bool get isToday {
    final DateTime now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  String get formattedDate => DailyLog.formatDisplayDate(selectedDate);
  String get dateKey => DailyLog.formatDateKey(selectedDate);

  List<FoodLogEntry> get filteredEntries {
    if (selectedMealFilter == null) {
      return List<FoodLogEntry>.unmodifiable(entries);
    }
    return entries.where((FoodLogEntry e) => e.mealType == selectedMealFilter).toList();
  }

  int caloriesForMealType(MealType type) {
    return entries
        .where((FoodLogEntry e) => e.mealType == type)
        .fold<int>(0, (int sum, FoodLogEntry e) => sum + e.calories);
  }

  /// Initializes the state by loading user settings and today's log from storage.
  Future<void> initFromStorage({CalorieStorage? storage}) async {
    if (storage != null) {
      this.storage = storage;
    }
    if (this.storage == null) return;

    try {
      final UserSettings settings = await this.storage!.loadSettings();
      dailyGoal = settings.dailyGoal;
      targetProteinG = settings.targetProteinG;
      targetCarbsG = settings.targetCarbsG;
      targetFatG = settings.targetFatG;

      final DailyLog? log = await this.storage!.loadDayLog(selectedDate);
      if (log != null) {
        dailyGoal = log.dailyGoal;
        targetProteinG = log.targetProteinG;
        targetCarbsG = log.targetCarbsG;
        targetFatG = log.targetFatG;

        if (entries.isEmpty) {
          entries.addAll(log.entries);
          _recalculateTotals();
        }
      } else if (entries.isNotEmpty) {
        await saveToStorage();
      }
      await refreshStreak();
    } catch (_) {
      // Gracefully maintain in-memory state on storage errors
    }
  }

  /// Loads daily log for a specific calendar [date].
  Future<void> loadForDate(DateTime date) async {
    selectedDate = date;
    if (storage == null) return;

    try {
      final DailyLog? log = await storage!.loadDayLog(date);
      if (log != null) {
        dailyGoal = log.dailyGoal;
        targetProteinG = log.targetProteinG;
        targetCarbsG = log.targetCarbsG;
        targetFatG = log.targetFatG;

        entries.clear();
        entries.addAll(log.entries);
        _recalculateTotals();
      } else {
        // New/empty day, retain active targets but clear entries
        entries.clear();
        _recalculateTotals();
      }
    } catch (_) {
      // Retain current in-memory values
    }
  }

  /// Refreshes the consecutive logging streak calculation.
  Future<void> refreshStreak() async {
    if (storage == null) return;
    try {
      streakDays = await storage!.calculateStreak();
    } catch (_) {
      // Keep in-memory streak
    }
  }

  /// Persists current daily log and user settings to storage.
  Future<void> saveToStorage() async {
    if (storage == null) return;

    try {
      final DailyLog dayLog = DailyLog(
        dateString: dateKey,
        dailyGoal: dailyGoal,
        targetProteinG: targetProteinG,
        targetCarbsG: targetCarbsG,
        targetFatG: targetFatG,
        entries: List<FoodLogEntry>.from(entries),
      );
      await storage!.saveDayLog(dayLog);

      final UserSettings settings = UserSettings(
        dailyGoal: dailyGoal,
        targetProteinG: targetProteinG,
        targetCarbsG: targetCarbsG,
        targetFatG: targetFatG,
      );
      await storage!.saveSettings(settings);
      await refreshStreak();
    } catch (_) {
      // Non-blocking fallback
    }
  }

  void _recalculateTotals() {
    consumedCalories = 0;
    proteinG = 0;
    carbsG = 0;
    fatG = 0;
    saturatedFatG = 0;
    fiberG = 0;
    addedSugarG = 0;
    sodiumMg = 0;
    totalSpreadPercent = 0;
    spreadSamples = 0;

    for (final FoodLogEntry entry in entries) {
      consumedCalories += entry.calories;
      proteinG += entry.proteinG;
      carbsG += entry.carbsG;
      fatG += entry.fatG;
      saturatedFatG += entry.saturatedFatG;
      fiberG += entry.fiberG;
      addedSugarG += entry.addedSugarG;
      sodiumMg += entry.sodiumMg;

      if (entry.spreadPercent != null && entry.spreadPercent! > 0) {
        totalSpreadPercent += entry.spreadPercent!;
        spreadSamples += 1;
      }
    }
  }

  bool updateTargets({
    required int dailyGoal,
    required int proteinG,
    required int carbsG,
    required int fatG,
  }) {
    this.dailyGoal = dailyGoal.clamp(900, 6000).toInt();
    targetProteinG = proteinG.clamp(0, 400).toInt();
    targetFatG = fatG.clamp(0, 300).toInt();

    final int proposedCarbs = carbsG.clamp(0, 600).toInt();
    final int adjustedCarbs =
        ((this.dailyGoal - (targetProteinG * 4) - (targetFatG * 9)) / 4)
            .round()
            .clamp(0, 600)
            .toInt();
    final bool carbsAdjusted = adjustedCarbs != proposedCarbs;
    targetCarbsG = adjustedCarbs;

    // Keep displayed calorie target aligned with the macro targets.
    this.dailyGoal = caloriesFromTargets;

    saveToStorage();
    return carbsAdjusted;
  }

  void addCalories({
    required int calories,
    required String mealLabel,
    int proteinG = 0,
    int carbsG = 0,
    int fatG = 0,
    int saturatedFatG = 0,
    int fiberG = 0,
    int addedSugarG = 0,
    int sodiumMg = 0,
    String? rangeText,
    String? sourceLabel,
    double? spreadPercent,
    MealType? mealType,
    DateTime? timestamp,
  }) {
    consumedCalories += calories;
    this.proteinG += proteinG;
    this.carbsG += carbsG;
    this.fatG += fatG;
    this.saturatedFatG += saturatedFatG;
    this.fiberG += fiberG;
    this.addedSugarG += addedSugarG;
    this.sodiumMg += sodiumMg;
    if (spreadPercent != null) {
      totalSpreadPercent += spreadPercent.clamp(0, 1).toDouble();
      spreadSamples += 1;
    }

    final FoodLogEntry newEntry = FoodLogEntry(
      mealLabel: mealLabel,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      saturatedFatG: saturatedFatG,
      fiberG: fiberG,
      addedSugarG: addedSugarG,
      sodiumMg: sodiumMg,
      rangeText: rangeText,
      sourceLabel: sourceLabel,
      spreadPercent: spreadPercent,
      mealType: mealType,
      timestamp: timestamp ?? selectedDate,
    );

    entries.insert(0, newEntry);
    saveToStorage();
  }

  void editEntry(int index, FoodLogEntry updated) {
    if (index < 0 || index >= entries.length) return;
    entries[index] = updated;
    _recalculateTotals();
    saveToStorage();
  }

  FoodLogEntry? removeEntryAt(int index) {
    if (index < 0 || index >= entries.length) {
      return null;
    }

    final FoodLogEntry removed = entries.removeAt(index);
    _recalculateTotals();
    saveToStorage();

    return removed;
  }

  FoodLogEntry? removeEntryById(String id) {
    final int index = entries.indexWhere((FoodLogEntry e) => e.id == id);
    if (index != -1) {
      return removeEntryAt(index);
    }
    return null;
  }

  void clearCurrentDay() {
    entries.clear();
    _recalculateTotals();
    saveToStorage();
  }

  void setMealFilter(MealType? filter) {
    selectedMealFilter = filter;
  }

  Future<void> goToPreviousDay() async {
    final DateTime prev = selectedDate.subtract(const Duration(days: 1));
    await loadForDate(prev);
  }

  Future<void> goToNextDay() async {
    final DateTime next = selectedDate.add(const Duration(days: 1));
    await loadForDate(next);
  }

  Future<void> goToToday() async {
    await loadForDate(DateTime.now());
  }
}
