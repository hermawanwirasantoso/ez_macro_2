import '../../calorie_tracker/domain/parse_result.dart';

/// Nutrition data for a packaged product resolved from a barcode lookup.
///
/// Values describe one serving when the source provides serving data,
/// otherwise they describe 100 g of the product (see [portionSize] and
/// [portionUnit]).
class ProductInfo {
  const ProductInfo({
    required this.barcode,
    required this.name,
    this.brand,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.saturatedFatG = 0,
    this.fiberG = 0,
    this.sugarsG = 0,
    this.sodiumMg = 0,
    this.portionSize = 1.0,
    this.portionUnit = 'serving',
  });

  final String barcode;
  final String name;
  final String? brand;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int saturatedFatG;
  final int fiberG;
  final int sugarsG;
  final int sodiumMg;
  final double portionSize;
  final String portionUnit;

  bool get hasNutrition =>
      calories > 0 || proteinG > 0 || carbsG > 0 || fatG > 0;

  String get displayName {
    final String trimmedBrand = brand?.trim() ?? '';
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty && trimmedBrand.isEmpty) {
      return 'Product $barcode';
    }
    if (trimmedName.isEmpty) {
      return trimmedBrand;
    }
    return trimmedName;
  }

  String get portionDisplay {
    final String sizeStr = portionSize == portionSize.toInt().toDouble()
        ? '${portionSize.toInt()}'
        : portionSize.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final String unitStr =
        portionUnit.trim().isEmpty ? 'serving' : portionUnit.trim();
    return '$sizeStr $unitStr';
  }

  /// Converts to a [ParseResult] so the food entry form can reuse the same
  /// auto-fill path used for AI label scans. Barcode data is exact label
  /// data, so confidence is high.
  ParseResult toParseResult() {
    return ParseResult(
      mealLabel: displayName,
      calories: calories,
      confidence: 0.95,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      saturatedFatG: saturatedFatG,
      fiberG: fiberG,
      addedSugarG: sugarsG,
      sodiumMg: sodiumMg,
      portionSize: portionSize,
      portionUnit: portionUnit,
    );
  }

  ProductInfo copyWith({
    String? barcode,
    String? name,
    String? brand,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? saturatedFatG,
    int? fiberG,
    int? sugarsG,
    int? sodiumMg,
    double? portionSize,
    String? portionUnit,
  }) {
    return ProductInfo(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      fiberG: fiberG ?? this.fiberG,
      sugarsG: sugarsG ?? this.sugarsG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      portionSize: portionSize ?? this.portionSize,
      portionUnit: portionUnit ?? this.portionUnit,
    );
  }
}
