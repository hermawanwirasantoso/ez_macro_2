import 'package:http/http.dart' as http;

import '../data/fake_barcode_lookup.dart';
import '../data/open_food_facts_lookup.dart';
import 'product_info.dart';

/// Resolves a scanned barcode into packaged-food nutrition data.
abstract class BarcodeLookup {
  const BarcodeLookup();

  /// Production lookup backed by the free Open Food Facts database.
  factory BarcodeLookup.openFoodFacts({
    String baseUrl,
    http.Client? client,
    Duration timeout,
  }) = OpenFoodFactsBarcodeLookup;

  /// In-memory lookup for tests.
  factory BarcodeLookup.fake({
    Map<String, ProductInfo>? products,
    Object? error,
  }) = FakeBarcodeLookup;

  /// Returns nutrition for [barcode], or null when the product is unknown
  /// or the lookup fails.
  Future<ProductInfo?> lookup(String barcode);
}
