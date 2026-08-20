import 'dart:convert';
import 'package:intl/intl.dart';

import 'weight_unit.dart';

/// Represents a single recorded body weight measurement.
class WeightEntry {
  WeightEntry({
    String? id,
    required this.weight,
    this.unit = WeightUnit.kg,
    required this.date,
    this.note,
    this.bodyFatPercentage,
    DateTime? createdAt,
  })  : id = id ?? _generateId(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final double weight;
  final WeightUnit unit;
  final DateTime date;
  final String? note;
  final double? bodyFatPercentage;
  final DateTime createdAt;

  static String _generateId() {
    return 'weight_${DateTime.now().microsecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
  }

  /// Formatted weight with 1 decimal place, e.g. "72.4 kg".
  String get displayWeight => '${weight.toStringAsFixed(1)} ${unit.displayName}';

  /// Formats date for display, e.g. "Today, Oct 12" or "Mon, Oct 12".
  String get formattedDisplayDate {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return "Today, ${DateFormat('MMM d').format(date)}";
    } else if (target == today.subtract(const Duration(days: 1))) {
      return "Yesterday, ${DateFormat('MMM d').format(date)}";
    } else {
      return DateFormat('EEE, MMM d').format(date);
    }
  }

  String get dateKey => DateFormat('yyyy-MM-dd').format(date);

  WeightEntry copyWith({
    String? id,
    double? weight,
    WeightUnit? unit,
    DateTime? date,
    String? note,
    double? bodyFatPercentage,
    DateTime? createdAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      weight: weight ?? this.weight,
      unit: unit ?? this.unit,
      date: date ?? this.date,
      note: note ?? this.note,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'weight': weight,
      'unit': unit.name,
      'date': date.toIso8601String(),
      'note': note,
      'bodyFatPercentage': bodyFatPercentage,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'] as String?,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      unit: WeightUnit.fromString(map['unit'] as String?),
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String?,
      bodyFatPercentage: (map['bodyFatPercentage'] as num?)?.toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory WeightEntry.fromJson(String source) =>
      WeightEntry.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeightEntry &&
        other.id == id &&
        other.weight == weight &&
        other.unit == unit &&
        other.date == date &&
        other.note == note &&
        other.bodyFatPercentage == bodyFatPercentage;
  }

  @override
  int get hashCode {
    return Object.hash(id, weight, unit, date, note, bodyFatPercentage);
  }
}
