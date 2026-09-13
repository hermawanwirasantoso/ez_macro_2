import '../domain/barcode_lookup.dart';
import '../domain/product_info.dart';

/// In-memory [BarcodeLookup] used by widget tests.
class FakeBarcodeLookup implements BarcodeLookup {
  FakeBarcodeLookup({
    Map<String, ProductInfo>? products,
    this.error,
  }) : products = Map<String, ProductInfo>.from(products ?? const <String, ProductInfo>{});

  final Map<String, ProductInfo> products;
  Object? error;
  final List<String> requestedBarcodes = <String>[];

  @override
  Future<ProductInfo?> lookup(String barcode) async {
    requestedBarcodes.add(barcode);
    if (error != null) {
      throw error!;
    }
    return products[barcode.trim()];
  }
}
