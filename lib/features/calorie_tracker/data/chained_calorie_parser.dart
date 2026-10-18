import '../domain/calorie_parser.dart';
import '../domain/nutrition_label_image.dart';
import '../domain/parse_result.dart';

/// Tries parsers in order and returns the first non-null result.
class ChainedCalorieParser implements CalorieParser {
  const ChainedCalorieParser(this.parsers);

  final List<CalorieParser> parsers;

  @override
  Future<ParseResult?> parse(String input) async {
    for (final CalorieParser parser in parsers) {
      final ParseResult? result = await parser.parse(input);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  @override
  Future<ParseResult?> parseNutritionLabel(
    NutritionLabelImage image, {
    String? hint,
  }) async {
    for (final CalorieParser parser in parsers) {
      final ParseResult? result = await parser.parseNutritionLabel(
        image,
        hint: hint,
      );
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
