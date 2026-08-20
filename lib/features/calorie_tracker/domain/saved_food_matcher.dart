import 'parse_result.dart';
import 'saved_food.dart';

/// Intelligent local matcher that matches natural language meal descriptions
/// against user's saved foods to resolve nutrition instantly without LLM calls.
class SavedFoodMatcher {
  const SavedFoodMatcher._();

  /// Checks if [input] corresponds to any food in [savedFoods], with support for:
  /// - Exact and case-insensitive names
  /// - Plural/singular variations (e.g. "eggs" vs "egg", "berries" vs "berry")
  /// - Prefix portions with unit (e.g. "200g chicken breast", "1.5 cups oatmeal")
  /// - Prefix portion counts/multipliers (e.g. "2 chicken breast", "2x chicken breast", "1/2 cup oatmeal")
  /// - Suffix portions (e.g. "chicken breast 200g", "chicken breast (200g)", "chicken breast x2")
  ///
  /// Returns a [ParseResult] with 100% confidence (1.0) and scaled nutrients if matched,
  /// or `null` if no match is found (allowing the app to fall back to LLM).
  static ParseResult? findMatch(String input, List<SavedFood> savedFoods) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty || savedFoods.isEmpty) {
      return null;
    }

    // Sort by name length descending so multi-word/specific items match first
    final List<SavedFood> sortedFoods = List<SavedFood>.from(savedFoods)
      ..sort((SavedFood a, SavedFood b) => b.name.length.compareTo(a.name.length));

    final String inputNorm = _normalize(trimmed);

    for (final SavedFood food in sortedFoods) {
      final String foodNorm = _normalize(food.name);
      if (foodNorm.isEmpty) continue;

      // 1. Exact or plural/singular name match
      if (inputNorm == foodNorm || _isPluralOrSingularEquivalent(inputNorm, foodNorm)) {
        return _buildResult(
          food,
          multiplier: 1.0,
          portionSize: food.portionSize,
          portionUnit: food.portionUnit,
        );
      }

      // 2. Prefix portion with unit / count: e.g. "200g chicken breast", "2 cups rice", "2 eggs", "2x chicken", "1/2 cup oatmeal"
      final RegExp prefixRegExp = RegExp(
        r'^(\d+\s*/\s*\d+|\d+(?:\.\d+)?)\s*(grams?|g|ounces?|oz|cups?|scoops?|slices?|bowls?|pieces?|pcs?|bars?|servings?|portions?|tablespoons?|tbsp|teaspoons?|tsp|milliliters?|ml|x)?\s*(?:of\s+)?(.+)$',
        caseSensitive: false,
      );
      final RegExpMatch? prefixMatch = prefixRegExp.firstMatch(trimmed);
      if (prefixMatch != null) {
        final String qtyStr = prefixMatch.group(1) ?? '';
        final String? unitStr = prefixMatch.group(2);
        final String restText = (prefixMatch.group(3) ?? '').trim();
        final String restNorm = _normalize(restText);

        if (restNorm == foodNorm || _isPluralOrSingularEquivalent(restNorm, foodNorm)) {
          final double? qty = _parseQuantity(qtyStr);
          if (qty != null && qty > 0) {
            return _calculateScaledResult(food, qty: qty, unitStr: unitStr);
          }
        }
      }

      // 3. Suffix multiplier: e.g. "chicken breast 2x", "chicken breast x2"
      final RegExp suffixMultRegExp = RegExp(
        r'^(.+?)(?:\s*[-:,()]+\s*|\s+)(?:x\s*(\d+(?:\.\d+)?)|(\d+(?:\.\d+)?)\s*x)\s*\)?$',
        caseSensitive: false,
      );
      final RegExpMatch? suffixMultMatch = suffixMultRegExp.firstMatch(trimmed);
      if (suffixMultMatch != null) {
        final String leadText = (suffixMultMatch.group(1) ?? '').trim();
        final String leadNorm = _normalize(leadText);
        final String qtyStr = suffixMultMatch.group(2) ?? suffixMultMatch.group(3) ?? '';

        if (leadNorm == foodNorm || _isPluralOrSingularEquivalent(leadNorm, foodNorm)) {
          final double? qty = _parseQuantity(qtyStr);
          if (qty != null && qty > 0) {
            return _buildResult(
              food,
              multiplier: qty,
              portionSize: food.portionSize * qty,
              portionUnit: food.portionUnit,
            );
          }
        }
      }

      // 4. Suffix portion: e.g. "chicken breast 200g", "chicken breast (200g)", "chicken breast, 200g", "chicken breast - 200g", "eggs 2"
      final RegExp suffixRegExp = RegExp(
        r'^(.+?)(?:\s*[-:,()]+\s*|\s+)(\d+\s*/\s*\d+|\d+(?:\.\d+)?)\s*(grams?|g|ounces?|oz|cups?|scoops?|slices?|bowls?|pieces?|pcs?|bars?|servings?|portions?|tablespoons?|tbsp|teaspoons?|tsp|milliliters?|ml|x)?\s*\)?$',
        caseSensitive: false,
      );
      final RegExpMatch? suffixMatch = suffixRegExp.firstMatch(trimmed);
      if (suffixMatch != null) {
        final String leadText = (suffixMatch.group(1) ?? '').trim();
        final String leadNorm = _normalize(leadText);
        final String qtyStr = suffixMatch.group(2) ?? '';
        final String? unitStr = suffixMatch.group(3);

        if (leadNorm == foodNorm || _isPluralOrSingularEquivalent(leadNorm, foodNorm)) {
          final double? qty = _parseQuantity(qtyStr);
          if (qty != null && qty > 0) {
            return _calculateScaledResult(food, qty: qty, unitStr: unitStr);
          }
        }
      }
    }

    return null;
  }

  static double? _parseQuantity(String str) {
    final String clean = str.trim();
    if (clean.contains('/')) {
      final List<String> parts = clean.split('/');
      if (parts.length == 2) {
        final double? num = double.tryParse(parts[0].trim());
        final double? den = double.tryParse(parts[1].trim());
        if (num != null && den != null && den > 0) {
          return num / den;
        }
      }
    }
    return double.tryParse(clean);
  }

  static ParseResult _calculateScaledResult(
    SavedFood food, {
    required double qty,
    required String? unitStr,
  }) {
    final String cleanUnit = (unitStr ?? '').trim().toLowerCase();
    final String normInputUnit = _normalizeUnit(cleanUnit);
    final String normFoodUnit = _normalizeUnit(food.portionUnit);

    final double multiplier;
    final double portionSize;
    final String portionUnit;

    if (cleanUnit.isEmpty || cleanUnit == 'x') {
      // User entered a multiplier/count like "2 chicken breast" or "2x chicken breast"
      multiplier = qty;
      portionSize = food.portionSize * qty;
      portionUnit = food.portionUnit;
    } else if (normInputUnit == normFoodUnit) {
      // Units match (e.g. 200g and base is 100g)
      multiplier = food.portionSize > 0 ? (qty / food.portionSize) : qty;
      portionSize = qty;
      portionUnit = food.portionUnit;
    } else if (normFoodUnit == 'serving' ||
        normFoodUnit == 'portion' ||
        normFoodUnit == 'piece' ||
        normFoodUnit == 'item') {
      // Base unit is serving/piece and user specified a unit like "2 cups"
      multiplier = qty;
      portionSize = qty;
      portionUnit = unitStr!;
    } else {
      // Other unit specified
      multiplier = qty;
      portionSize = qty;
      portionUnit = unitStr!;
    }

    return _buildResult(
      food,
      multiplier: multiplier,
      portionSize: portionSize,
      portionUnit: portionUnit,
    );
  }

  static ParseResult _buildResult(
    SavedFood food, {
    required double multiplier,
    required double portionSize,
    required String portionUnit,
  }) {
    final double effectiveMultiplier = multiplier <= 0 ? 1.0 : multiplier;
    final double finalPortionSize = portionSize <= 0 ? food.portionSize : portionSize;
    final String finalPortionUnit =
        portionUnit.trim().isEmpty ? food.portionUnit : portionUnit.trim();

    return ParseResult(
      mealLabel: food.name,
      calories: (food.calories * effectiveMultiplier).round().clamp(1, 99999),
      confidence: 1.0,
      proteinG: (food.proteinG * effectiveMultiplier).round().clamp(0, 9999),
      carbsG: (food.carbsG * effectiveMultiplier).round().clamp(0, 9999),
      fatG: (food.fatG * effectiveMultiplier).round().clamp(0, 9999),
      saturatedFatG:
          (food.saturatedFatG * effectiveMultiplier).round().clamp(0, 9999),
      fiberG: (food.fiberG * effectiveMultiplier).round().clamp(0, 9999),
      addedSugarG:
          (food.addedSugarG * effectiveMultiplier).round().clamp(0, 9999),
      sodiumMg: (food.sodiumMg * effectiveMultiplier).round().clamp(0, 99999),
      portionSize: finalPortionSize,
      portionUnit: finalPortionUnit,
    );
  }

  static String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[-:,()_.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isPluralOrSingularEquivalent(String a, String b) {
    if (a == b) return true;
    if ('${a}s' == b || '${b}s' == a) return true;
    if ('${a}es' == b || '${b}es' == a) return true;
    if (a.endsWith('ies') && a.length > 3 && '${a.substring(0, a.length - 3)}y' == b) {
      return true;
    }
    if (b.endsWith('ies') && b.length > 3 && '${b.substring(0, b.length - 3)}y' == a) {
      return true;
    }
    return false;
  }

  static String _normalizeUnit(String raw) {
    final String clean = raw.trim().toLowerCase();
    if (clean.isEmpty) return 'serving';
    if (clean == 'g' || clean == 'gram' || clean == 'grams') return 'g';
    if (clean == 'oz' || clean == 'ounce' || clean == 'ounces') return 'oz';
    if (clean == 'cup' || clean == 'cups') return 'cup';
    if (clean == 'slice' || clean == 'slices') return 'slice';
    if (clean == 'scoop' || clean == 'scoops') return 'scoop';
    if (clean == 'piece' || clean == 'pieces' || clean == 'pc' || clean == 'pcs') return 'piece';
    if (clean == 'bowl' || clean == 'bowls') return 'bowl';
    if (clean == 'bar' || clean == 'bars') return 'bar';
    if (clean == 'serving' || clean == 'servings' || clean == 'portion' || clean == 'portions') return 'serving';
    if (clean == 'tbsp' || clean == 'tablespoon' || clean == 'tablespoons') return 'tbsp';
    if (clean == 'tsp' || clean == 'teaspoon' || clean == 'teaspoons') return 'tsp';
    if (clean == 'ml' || clean == 'milliliter' || clean == 'milliliters') return 'ml';
    return clean;
  }
}
