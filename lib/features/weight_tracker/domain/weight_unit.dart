/// Unit of weight measurement.
enum WeightUnit {
  kg,
  lbs;

  String get label => name;
  String get symbol => displayName;

  String get displayName {
    switch (this) {
      case WeightUnit.kg:
        return 'kg';
      case WeightUnit.lbs:
        return 'lbs';
    }
  }

  static WeightUnit fromString(String? value) {
    if (value == null) return WeightUnit.kg;
    final String clean = value.toLowerCase().trim();
    if (clean == 'lbs' || clean == 'lb' || clean == 'pound' || clean == 'pounds') {
      return WeightUnit.lbs;
    }
    return WeightUnit.kg;
  }

  /// Converts a weight value from this unit to another unit.
  double convertTo(double value, WeightUnit targetUnit) {
    if (this == targetUnit) return value;
    if (this == WeightUnit.kg && targetUnit == WeightUnit.lbs) {
      return value * 2.20462;
    }
    if (this == WeightUnit.lbs && targetUnit == WeightUnit.kg) {
      return value / 2.20462;
    }
    return value;
  }
}
