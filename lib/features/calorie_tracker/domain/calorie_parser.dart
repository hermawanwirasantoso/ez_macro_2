import 'parse_result.dart';

abstract class CalorieParser {
  const CalorieParser();

  Future<ParseResult?> parse(String input);
}

class RegexCalorieParser implements CalorieParser {
  const RegexCalorieParser();

  @override
  Future<ParseResult?> parse(String input) async {
    final String trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      return null;
    }

    final ({int calories, String matchedText})? calorieMatch =
        _extractExplicitCalories(trimmedInput);
    final ({int calories, int protein, int carbs, int fat, double confidence})?
    phraseEstimate = _estimateFromPhrase(trimmedInput);

    final int? parsedCalories = calorieMatch?.calories;
    if (parsedCalories == null && phraseEstimate == null) {
      return null;
    }

    final String normalizedMeal = trimmedInput
        .replaceFirst(calorieMatch?.matchedText ?? '', '')
        .replaceAll(RegExp(r'[-:,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final String mealLabel = normalizedMeal.isEmpty ? 'Meal' : normalizedMeal;
    final int safeCalories =
        (parsedCalories ?? phraseEstimate!.calories).clamp(1, 5000).toInt();
    final int? extractedProtein = _extractMacro(trimmedInput, 'p|protein');
    final int? extractedCarbs = _extractMacro(trimmedInput, 'c|carb|carbs');
    final int? extractedFat = _extractMacro(trimmedInput, 'f|fat');
    final ({int protein, int carbs, int fat}) estimated =
        _estimateMacrosForCalories(safeCalories);
    final int protein =
        (extractedProtein ?? phraseEstimate?.protein ?? estimated.protein)
            .clamp(0, 400)
            .toInt();
    final int carbs =
        (extractedCarbs ?? phraseEstimate?.carbs ?? estimated.carbs)
            .clamp(0, 600)
            .toInt();
    final int fat =
        (extractedFat ?? phraseEstimate?.fat ?? estimated.fat)
            .clamp(0, 300)
            .toInt();
    final double confidence = calorieMatch != null
        ? 0.88
        : (phraseEstimate?.confidence ?? 0.72).clamp(0.0, 1.0).toDouble();

    return ParseResult(
      mealLabel: mealLabel,
      calories: safeCalories,
      confidence: confidence,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
    );
  }

  ({int calories, int protein, int carbs, int fat, double confidence})?
  _estimateFromPhrase(String input) {
    final String normalized = input.toLowerCase();
    final _FoodProfile? profile = _matchFoodProfile(normalized);
    if (profile == null) {
      return null;
    }

    final double? grams = _extractGrams(normalized);
    final bool hasGramPortion = grams != null;
    final double quantity = hasGramPortion
        ? (grams / 100.0)
        : _extractServingQuantity(normalized);
    final int calories = (hasGramPortion
            ? profile.caloriesPer100g * quantity
            : profile.caloriesPerServing * quantity)
        .round()
        .clamp(1, 5000)
        .toInt();
    final int protein = (hasGramPortion
            ? profile.proteinPer100g * quantity
            : profile.proteinPerServing * quantity)
        .round()
        .clamp(0, 400)
        .toInt();
    final int carbs = (hasGramPortion
            ? profile.carbsPer100g * quantity
            : profile.carbsPerServing * quantity)
        .round()
        .clamp(0, 600)
        .toInt();
    final int fat = (hasGramPortion
            ? profile.fatPer100g * quantity
            : profile.fatPerServing * quantity)
        .round()
        .clamp(0, 300)
        .toInt();

    return (
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      confidence: hasGramPortion ? 0.72 : 0.55,
    );
  }

  ({int calories, String matchedText})? _extractExplicitCalories(String input) {
    final RegExpMatch? trailingUnit =
        RegExp(r'(\d{2,4})\s*(kcal|cal|calorie|calories)\b', caseSensitive: false)
            .firstMatch(input);
    if (trailingUnit != null) {
      final int? calories = int.tryParse(trailingUnit.group(1) ?? '');
      if (calories != null) {
        return (calories: calories, matchedText: trailingUnit.group(0) ?? '');
      }
    }

    final RegExpMatch? leadingUnit =
        RegExp(r'\b(kcal|cal|calorie|calories)\s*(\d{2,4})\b', caseSensitive: false)
            .firstMatch(input);
    if (leadingUnit != null) {
      final int? calories = int.tryParse(leadingUnit.group(2) ?? '');
      if (calories != null) {
        return (calories: calories, matchedText: leadingUnit.group(0) ?? '');
      }
    }

    return null;
  }

  _FoodProfile? _matchFoodProfile(String input) {
    if (input.contains('rice')) {
      return const _FoodProfile(
        caloriesPerServing: 280,
        proteinPerServing: 5,
        carbsPerServing: 62,
        fatPerServing: 1,
        caloriesPer100g: 130,
        proteinPer100g: 2,
        carbsPer100g: 28,
        fatPer100g: 0,
      );
    }
    if (input.contains('egg')) {
      return const _FoodProfile(
        caloriesPerServing: 78,
        proteinPerServing: 6,
        carbsPerServing: 1,
        fatPerServing: 5,
        caloriesPer100g: 143,
        proteinPer100g: 13,
        carbsPer100g: 1,
        fatPer100g: 10,
      );
    }
    if (input.contains('chicken breast')) {
      return const _FoodProfile(
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 4,
        caloriesPer100g: 165,
        proteinPer100g: 31,
        carbsPer100g: 0,
        fatPer100g: 4,
      );
    }
    if (input.contains('chicken')) {
      return const _FoodProfile(
        caloriesPerServing: 240,
        proteinPerServing: 35,
        carbsPerServing: 0,
        fatPerServing: 8,
        caloriesPer100g: 190,
        proteinPer100g: 27,
        carbsPer100g: 0,
        fatPer100g: 8,
      );
    }
    if (input.contains('banana')) {
      return const _FoodProfile(
        caloriesPerServing: 105,
        proteinPerServing: 1,
        carbsPerServing: 27,
        fatPerServing: 0,
        caloriesPer100g: 89,
        proteinPer100g: 1,
        carbsPer100g: 23,
        fatPer100g: 0,
      );
    }
    if (input.contains('apple')) {
      return const _FoodProfile(
        caloriesPerServing: 95,
        proteinPerServing: 0,
        carbsPerServing: 25,
        fatPerServing: 0,
        caloriesPer100g: 52,
        proteinPer100g: 0,
        carbsPer100g: 14,
        fatPer100g: 0,
      );
    }
    if (input.contains('bread') || input.contains('toast')) {
      return const _FoodProfile(
        caloriesPerServing: 80,
        proteinPerServing: 3,
        carbsPerServing: 15,
        fatPerServing: 1,
        caloriesPer100g: 265,
        proteinPer100g: 9,
        carbsPer100g: 49,
        fatPer100g: 3,
      );
    }
    if (input.contains('noodle') || input.contains('ramen')) {
      return const _FoodProfile(
        caloriesPerServing: 350,
        proteinPerServing: 9,
        carbsPerServing: 52,
        fatPerServing: 10,
        caloriesPer100g: 138,
        proteinPer100g: 5,
        carbsPer100g: 25,
        fatPer100g: 3,
      );
    }
    return null;
  }

  double _extractServingQuantity(String input) {
    double quantity = 1.0;
    final RegExpMatch? numericMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(input);
    if (numericMatch != null) {
      quantity = double.tryParse(numericMatch.group(1) ?? '1') ?? 1.0;
    } else {
      const Map<String, double> wordNumbers = <String, double>{
        'a': 1,
        'an': 1,
        'one': 1,
        'two': 2,
        'three': 3,
        'four': 4,
      };
      for (final MapEntry<String, double> entry in wordNumbers.entries) {
        if (RegExp('\\b${entry.key}\\b').hasMatch(input)) {
          quantity = entry.value;
          break;
        }
      }
    }

    if (RegExp(r'\bhalf\b').hasMatch(input)) {
      quantity *= 0.5;
    }

    if (RegExp(r'\bplate\b').hasMatch(input)) {
      quantity *= 1.2;
    }

    return quantity.clamp(0.25, 6.0);
  }

  double? _extractGrams(String input) {
    final RegExpMatch? match =
        RegExp(r'\b(\d+(?:\.\d+)?)\s*(g|gram|grams)\b', caseSensitive: false)
            .firstMatch(input);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1) ?? '');
  }

  int? _extractMacro(String input, String macroPattern) {
    final RegExp exp = RegExp(
      '(\\d{1,3})\\s*(g|gram|grams)?\\s*($macroPattern)\\b|($macroPattern)\\s*(\\d{1,3})\\s*(g|gram|grams)?',
      caseSensitive: false,
    );
    final RegExpMatch? match = exp.firstMatch(input);
    if (match == null) {
      return null;
    }

    final String? firstNumber = match.group(1);
    final String? secondNumber = match.group(5);
    final int? value = int.tryParse(firstNumber ?? secondNumber ?? '');
    return value?.clamp(0, 400).toInt();
  }

  ({int protein, int carbs, int fat}) _estimateMacrosForCalories(int calories) {
    final int protein = (calories * 0.30 / 4).round();
    final int carbs = (calories * 0.40 / 4).round();
    final int fat = (calories * 0.30 / 9).round();
    return (protein: protein, carbs: carbs, fat: fat);
  }
}

class _FoodProfile {
  const _FoodProfile({
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatPerServing,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final int caloriesPerServing;
  final int proteinPerServing;
  final int carbsPerServing;
  final int fatPerServing;
  final int caloriesPer100g;
  final int proteinPer100g;
  final int carbsPer100g;
  final int fatPer100g;
}

