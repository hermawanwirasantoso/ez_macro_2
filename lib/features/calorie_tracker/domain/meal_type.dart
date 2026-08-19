import 'package:flutter/material.dart';

/// Categories of meals tracked throughout the day.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  other;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
      case MealType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.wb_twilight_rounded;
      case MealType.lunch:
        return Icons.wb_sunny_rounded;
      case MealType.dinner:
        return Icons.nights_stay_rounded;
      case MealType.snack:
        return Icons.cookie_outlined;
      case MealType.other:
        return Icons.restaurant_menu_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MealType.breakfast:
        return const Color(0xFFF59E0B); // Amber / Morning
      case MealType.lunch:
        return const Color(0xFF10B981); // Emerald / Midday
      case MealType.dinner:
        return const Color(0xFF6366F1); // Indigo / Evening
      case MealType.snack:
        return const Color(0xFFEC4899); // Pink / Snack
      case MealType.other:
        return const Color(0xFF64748B); // Slate / Other
    }
  }

  static MealType fromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return MealType.other;
    }
    final String clean = value.trim().toLowerCase();
    for (final MealType type in MealType.values) {
      if (type.name.toLowerCase() == clean ||
          type.displayName.toLowerCase() == clean) {
        return type;
      }
    }
    return MealType.other;
  }

  /// Suggests a meal type based on the given or current time of day.
  static MealType forTime([DateTime? time]) {
    final DateTime now = time ?? DateTime.now();
    final int hour = now.hour;
    if (hour >= 5 && hour < 11) {
      return MealType.breakfast;
    } else if (hour >= 11 && hour < 16) {
      return MealType.lunch;
    } else if (hour >= 16 && hour < 22) {
      return MealType.dinner;
    } else {
      return MealType.snack;
    }
  }
}
