import 'dart:convert';
import 'package:intl/intl.dart';

import 'meal_type.dart';

/// Represents a single food or drink entry in the calorie log.
class FoodLogEntry {
  FoodLogEntry({
    String? id,
    required this.mealLabel,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.saturatedFatG = 0,
    this.fiberG = 0,
    this.addedSugarG = 0,
    this.sodiumMg = 0,
    this.portionSize = 1.0,
    this.portionUnit = 'serving',
    this.rangeText,
    this.sourceLabel,
    this.spreadPercent,
    MealType? mealType,
    DateTime? timestamp,
  })  : id = id ?? _generateId(),
        mealType = mealType ?? MealType.forTime(timestamp),
        timestamp = timestamp ?? DateTime.now();

  final String id;
  final String mealLabel;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int saturatedFatG;
  final int fiberG;
  final int addedSugarG;
  final int sodiumMg;
  final double portionSize;
  final String portionUnit;
  final String? rangeText;
  final String? sourceLabel;
  final double? spreadPercent;
  final MealType mealType;
  final DateTime timestamp;

  static String _generateId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
  }

  String get portionDisplay {
    final String sizeStr = portionSize == portionSize.toInt().toDouble()
        ? '${portionSize.toInt()}'
        : portionSize.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final String unitStr =
        portionUnit.trim().isEmpty ? 'serving' : portionUnit.trim();
    return '$sizeStr $unitStr';
  }

  String get displayText {
    final StringBuffer buffer = StringBuffer('$mealLabel - $calories kcal');
    if (rangeText != null && rangeText!.isNotEmpty) {
      buffer.write(' [$rangeText]');
    }
    if (sourceLabel != null && sourceLabel!.isNotEmpty) {
      buffer.write(' $sourceLabel');
    }
    return buffer.toString();
  }

  FoodLogEntry copyWith({
    String? id,
    String? mealLabel,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? saturatedFatG,
    int? fiberG,
    int? addedSugarG,
    int? sodiumMg,
    double? portionSize,
    String? portionUnit,
    String? rangeText,
    String? sourceLabel,
    double? spreadPercent,
    MealType? mealType,
    DateTime? timestamp,
  }) {
    return FoodLogEntry(
      id: id ?? this.id,
      mealLabel: mealLabel ?? this.mealLabel,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      fiberG: fiberG ?? this.fiberG,
      addedSugarG: addedSugarG ?? this.addedSugarG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      portionSize: portionSize ?? this.portionSize,
      portionUnit: portionUnit ?? this.portionUnit,
      rangeText: rangeText ?? this.rangeText,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      spreadPercent: spreadPercent ?? this.spreadPercent,
      mealType: mealType ?? this.mealType,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'mealLabel': mealLabel,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'saturatedFatG': saturatedFatG,
      'fiberG': fiberG,
      'addedSugarG': addedSugarG,
      'sodiumMg': sodiumMg,
      'portionSize': portionSize,
      'portionUnit': portionUnit,
      'rangeText': rangeText,
      'sourceLabel': sourceLabel,
      'spreadPercent': spreadPercent,
      'mealType': mealType.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory FoodLogEntry.fromMap(Map<String, dynamic> map) {
    return FoodLogEntry(
      id: map['id'] as String?,
      mealLabel: (map['mealLabel'] as String?) ?? '',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (map['fatG'] as num?)?.toInt() ?? 0,
      saturatedFatG: (map['saturatedFatG'] as num?)?.toInt() ??
          (map['saturated_fat_g'] as num?)?.toInt() ??
          0,
      fiberG: (map['fiberG'] as num?)?.toInt() ??
          (map['fiber_g'] as num?)?.toInt() ??
          0,
      addedSugarG: (map['addedSugarG'] as num?)?.toInt() ??
          (map['added_sugar_g'] as num?)?.toInt() ??
          0,
      sodiumMg: (map['sodiumMg'] as num?)?.toInt() ??
          (map['sodium_mg'] as num?)?.toInt() ??
          0,
      portionSize: (map['portionSize'] as num?)?.toDouble() ??
          (map['portion_size'] as num?)?.toDouble() ??
          (map['servingSize'] as num?)?.toDouble() ??
          (map['serving_size'] as num?)?.toDouble() ??
          1.0,
      portionUnit: (map['portionUnit'] as String?)?.trim() ??
          (map['portion_unit'] as String?)?.trim() ??
          (map['servingUnit'] as String?)?.trim() ??
          (map['serving_unit'] as String?)?.trim() ??
          'serving',
      rangeText: map['rangeText'] as String?,
      sourceLabel: map['sourceLabel'] as String?,
      spreadPercent: (map['spreadPercent'] as num?)?.toDouble(),
      mealType: MealType.fromString(map['mealType'] as String?),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory FoodLogEntry.fromJson(String source) =>
      FoodLogEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// Represents the complete log for a single calendar date.
class DailyLog {
  DailyLog({
    required this.dateString,
    this.dailyGoal = 2200,
    this.targetProteinG = 160,
    this.targetCarbsG = 255,
    this.targetFatG = 60,
    List<FoodLogEntry>? entries,
  }) : entries = entries ?? <FoodLogEntry>[];

  final String dateString; // Format: YYYY-MM-DD
  int dailyGoal;
  int targetProteinG;
  int targetCarbsG;
  int targetFatG;
  final List<FoodLogEntry> entries;

  static String formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDisplayDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return "Today, ${DateFormat('MMM d').format(date)}";
    } else if (target == today.subtract(const Duration(days: 1))) {
      return "Yesterday, ${DateFormat('MMM d').format(date)}";
    } else if (target == today.add(const Duration(days: 1))) {
      return "Tomorrow, ${DateFormat('MMM d').format(date)}";
    } else {
      return DateFormat('EEE, MMM d').format(date);
    }
  }

  DateTime get date => DateTime.tryParse(dateString) ?? DateTime.now();

  int get consumedCalories =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.calories);

  int get totalCalories => consumedCalories;

  int get proteinG =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.proteinG);

  int get totalProteinG => proteinG;

  int get carbsG =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.carbsG);

  int get totalCarbsG => carbsG;

  int get fatG =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.fatG);

  int get totalFatG => fatG;

  int get totalSaturatedFatG => saturatedFatG;
  int get totalFiberG => fiberG;
  int get totalAddedSugarG => addedSugarG;
  int get totalSodiumMg => sodiumMg;

  int get saturatedFatG =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.saturatedFatG);

  int get fiberG =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.fiberG);

  int get addedSugarG =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.addedSugarG);

  int get sodiumMg =>
      entries.fold<int>(0, (int sum, FoodLogEntry item) => sum + item.sodiumMg);

  int get remainingCalories =>
      (dailyGoal - consumedCalories).clamp(0, 99999).toInt();

  int get caloriesFromTargets =>
      (targetProteinG * 4) + (targetCarbsG * 4) + (targetFatG * 9);

  double get averageSpreadPercent {
    final List<FoodLogEntry> sampled = entries
        .where((FoodLogEntry e) => e.spreadPercent != null && e.spreadPercent! > 0)
        .toList();
    if (sampled.isEmpty) return 0.0;
    final double total = sampled.fold<double>(
        0.0, (double sum, FoodLogEntry e) => sum + e.spreadPercent!);
    return total / sampled.length;
  }

  int caloriesForMealType(MealType type) {
    return entries
        .where((FoodLogEntry e) => e.mealType == type)
        .fold<int>(0, (int sum, FoodLogEntry e) => sum + e.calories);
  }

  List<FoodLogEntry> entriesForMealType(MealType? type) {
    if (type == null) return List<FoodLogEntry>.unmodifiable(entries);
    return entries.where((FoodLogEntry e) => e.mealType == type).toList();
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'dateString': dateString,
      'dailyGoal': dailyGoal,
      'targetProteinG': targetProteinG,
      'targetCarbsG': targetCarbsG,
      'targetFatG': targetFatG,
      'entries': entries.map((FoodLogEntry e) => e.toMap()).toList(),
    };
  }

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      dateString: map['dateString'] as String? ?? formatDateKey(DateTime.now()),
      dailyGoal: (map['dailyGoal'] as num?)?.toInt() ?? 2200,
      targetProteinG: (map['targetProteinG'] as num?)?.toInt() ?? 160,
      targetCarbsG: (map['targetCarbsG'] as num?)?.toInt() ?? 255,
      targetFatG: (map['targetFatG'] as num?)?.toInt() ?? 60,
      entries: (map['entries'] as List<dynamic>?)
              ?.map((dynamic e) =>
                  FoodLogEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          <FoodLogEntry>[],
    );
  }

  String toJson() => json.encode(toMap());

  factory DailyLog.fromJson(String source) =>
      DailyLog.fromMap(json.decode(source) as Map<String, dynamic>);
}
