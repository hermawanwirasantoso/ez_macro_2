import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/barcode_lookup.dart';
import '../domain/product_info.dart';

/// Looks up packaged-food nutrition from the free Open Food Facts API.
///
/// No API key is required. Values are taken per serving when the product
/// declares a serving size, otherwise per 100 g.
class OpenFoodFactsBarcodeLookup implements BarcodeLookup {
  OpenFoodFactsBarcodeLookup({
    this.baseUrl = 'https://world.openfoodfacts.org',
    this.client,
    this.timeout = const Duration(seconds: 12),
  });

  static const String _requestedFields =
      'code,product_name,product_name_en,brands,serving_size,serving_quantity,nutriments';

  final String baseUrl;
  final http.Client? client;
  final Duration timeout;

  @override
  Future<ProductInfo?> lookup(String barcode) async {
    final String code = barcode.trim();
    if (code.isEmpty || !RegExp(r'^[0-9A-Za-z-]+$').hasMatch(code)) {
      return null;
    }

    final http.Client httpClient = client ?? http.Client();
    try {
      final Uri uri = Uri.parse(
        '${baseUrl.trim().replaceAll(RegExp(r'/+$'), '')}/api/v2/product/$code.json',
      ).replace(queryParameters: <String, String>{'fields': _requestedFields});

      final http.Response response = await httpClient
          .get(uri, headers: <String, String>{
            'User-Agent': 'ez_macro/1.0 (Flutter barcode lookup)',
            'Accept': 'application/json',
          })
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debugLog('Open Food Facts failed with ${response.statusCode}');
        return null;
      }

      return OpenFoodFactsProductParser.parse(response.body);
    } catch (e) {
      _debugLog('Open Food Facts lookup exception: $e');
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}

/// Pure parsing of Open Food Facts product payloads (unit-testable).
class OpenFoodFactsProductParser {
  const OpenFoodFactsProductParser._();

  static ProductInfo? parse(String responseBody) {
    dynamic payload;
    try {
      payload = jsonDecode(responseBody);
    } catch (_) {
      return null;
    }

    if (payload is! Map) {
      return null;
    }

    final dynamic product = payload['product'];
    if (product is! Map) {
      return null;
    }

    final String code = (payload['code'] ?? product['code'] ?? '').toString();

    final dynamic nutriments = product['nutriments'];
    final Map<String, dynamic> nutrimentsMap = nutriments is Map
        ? nutriments.map((dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value))
        : <String, dynamic>{};

    final double? servingQuantity = _toDouble(product['serving_quantity']);
    final String servingSizeText =
        (product['serving_size'] ?? '').toString().trim();
    final bool hasServing =
        servingQuantity != null && servingQuantity > 0;

    final String suffix = hasServing ? '_serving' : '_100g';
    final double basis = hasServing ? servingQuantity : 100.0;

    int? calories = _readEnergyKcal(nutrimentsMap, suffix);
    if (calories == null && hasServing) {
      // Fall back to per-100g energy scaled to the serving size.
      final int? perHundred = _readEnergyKcal(nutrimentsMap, '_100g');
      if (perHundred != null) {
        calories = (perHundred * servingQuantity / 100).round();
      }
    }

    final String name = _firstNonEmpty(<String>[
      (product['product_name'] ?? '').toString(),
      (product['product_name_en'] ?? '').toString(),
    ]);
    final String brand = _firstNonEmpty(<String>[
      (product['brands'] ?? '').toString(),
    ]);

    return ProductInfo(
      barcode: code,
      name: name,
      brand: brand.isEmpty ? null : brand.split(',').first.trim(),
      calories: (calories ?? 0).clamp(0, 5000),
      proteinG: _grams(nutrimentsMap, 'proteins', suffix, basis, max: 400),
      carbsG: _grams(nutrimentsMap, 'carbohydrates', suffix, basis, max: 600),
      fatG: _grams(nutrimentsMap, 'fat', suffix, basis, max: 300),
      saturatedFatG:
          _grams(nutrimentsMap, 'saturated-fat', suffix, basis, max: 200),
      fiberG: _grams(nutrimentsMap, 'fiber', suffix, basis, max: 200),
      sugarsG: _grams(nutrimentsMap, 'sugars', suffix, basis, max: 500),
      sodiumMg: _sodiumMg(nutrimentsMap, suffix, basis),
      portionSize: hasServing ? servingQuantity : 100.0,
      portionUnit: hasServing
          ? _unitFromServingText(servingSizeText)
          : 'g',
    );
  }

  static int? _readEnergyKcal(Map<String, dynamic> nutriments, String suffix) {
    final double? kcal = _toDouble(nutriments['energy-kcal$suffix']);
    if (kcal != null) {
      return kcal.round();
    }
    final double? kJ = _toDouble(nutriments['energy$suffix']);
    if (kJ != null) {
      return (kJ / 4.184).round();
    }
    return null;
  }

  static int _grams(
    Map<String, dynamic> nutriments,
    String key,
    String suffix,
    double basis, {
    required int max,
  }) {
    final double? direct = _toDouble(nutriments['$key$suffix']);
    if (direct != null) {
      return direct.round().clamp(0, max);
    }
    final double? perHundred = _toDouble(nutriments['${key}_100g']);
    if (perHundred != null && basis > 0 && suffix == '_serving') {
      return (perHundred * basis / 100).round().clamp(0, max);
    }
    return 0;
  }

  static int _sodiumMg(Map<String, dynamic> nutriments, String suffix, double basis) {
    final double? sodiumG = _toDouble(nutriments['sodium$suffix']);
    if (sodiumG != null) {
      return (sodiumG * 1000).round().clamp(0, 20000);
    }
    final double? saltG = _toDouble(nutriments['salt$suffix']);
    if (saltG != null) {
      // Salt is ~40% sodium by mass.
      return (saltG * 400).round().clamp(0, 20000);
    }
    final double? perHundredSodium = _toDouble(nutriments['sodium_100g']);
    if (perHundredSodium != null && basis > 0 && suffix == '_serving') {
      return (perHundredSodium * basis / 100 * 1000).round().clamp(0, 20000);
    }
    final double? perHundredSalt = _toDouble(nutriments['salt_100g']);
    if (perHundredSalt != null && basis > 0 && suffix == '_serving') {
      return (perHundredSalt * basis / 100 * 400).round().clamp(0, 20000);
    }
    return 0;
  }

  /// Extracts a unit like "g" or "pieces" from serving text such as "30 g"
  /// or "2 pieces (40 g)".
  static String _unitFromServingText(String servingSizeText) {
    if (servingSizeText.isEmpty) {
      return 'g';
    }
    final RegExpMatch? match =
        RegExp(r'^\s*[\d.,x\s]+\s*([A-Za-z]+)').firstMatch(servingSizeText);
    final String unit = match?.group(1)?.trim().toLowerCase() ?? '';
    if (unit.isEmpty) {
      return 'g';
    }
    if (unit == 'ml' || unit == 'l' || unit == 'cl' || unit == 'fl') {
      return unit;
    }
    if (unit == 'g' || unit == 'kg' || unit == 'mg' || unit == 'oz') {
      return unit;
    }
    return unit;
  }

  static String _firstNonEmpty(List<String> values) {
    for (final String value in values) {
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final String trimmed = value.trim();
      final double? parsed = double.tryParse(trimmed);
      if (parsed != null) {
        return parsed;
      }
      final RegExpMatch? match =
          RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(trimmed);
      if (match != null) {
        return double.tryParse(match.group(0)!.replaceAll(',', '.'));
      }
    }
    return null;
  }
}
