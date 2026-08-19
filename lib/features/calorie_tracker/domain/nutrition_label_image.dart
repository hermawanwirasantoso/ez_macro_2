/// A photo of a packaged-food nutrition facts label.
class NutritionLabelImage {
  const NutritionLabelImage({
    required this.bytes,
    this.mimeType = 'image/jpeg',
  });

  final List<int> bytes;
  final String mimeType;

  bool get isEmpty => bytes.isEmpty;

  String get normalizedMimeType {
    final String trimmed = mimeType.trim().toLowerCase();
    if (trimmed == 'image/png' || trimmed == 'image/webp' || trimmed == 'image/heic') {
      return trimmed;
    }
    return 'image/jpeg';
  }
}

/// Where the nutrition-label photo should be chosen from.
enum NutritionLabelPickSource {
  camera,
  gallery,
}
