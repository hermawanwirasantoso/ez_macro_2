import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/nutrition_label_image.dart';

/// Provides a nutrition-facts photo from the camera or gallery.
abstract class NutritionLabelImageSource {
  const NutritionLabelImageSource();

  factory NutritionLabelImageSource.device({ImagePicker? picker}) =
      DeviceNutritionLabelImageSource;

  factory NutritionLabelImageSource.fake({
    NutritionLabelImage? image,
    Object? error,
  }) = FakeNutritionLabelImageSource;

  Future<NutritionLabelImage?> pick({required NutritionLabelPickSource source});
}

class DeviceNutritionLabelImageSource implements NutritionLabelImageSource {
  DeviceNutritionLabelImageSource({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<NutritionLabelImage?> pick({
    required NutritionLabelPickSource source,
  }) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source == NutritionLabelPickSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 75,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) {
        return null;
      }

      final List<int> bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }

      return NutritionLabelImage(
        bytes: bytes,
        mimeType: _mimeTypeFor(path: file.path, declaredMimeType: file.mimeType),
      );
    } catch (e) {
      _debugLog('Failed to pick nutrition label image: $e');
      return null;
    }
  }

  String _mimeTypeFor({required String path, String? declaredMimeType}) {
    final String declared = (declaredMimeType ?? '').trim().toLowerCase();
    if (declared.startsWith('image/')) {
      return declared;
    }

    final String lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerPath.endsWith('.heic') || lowerPath.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  void _debugLog(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }
}

class FakeNutritionLabelImageSource implements NutritionLabelImageSource {
  FakeNutritionLabelImageSource({
    this.image,
    this.error,
  });

  NutritionLabelImage? image;
  Object? error;
  NutritionLabelPickSource? lastSource;
  int pickCount = 0;

  @override
  Future<NutritionLabelImage?> pick({
    required NutritionLabelPickSource source,
  }) async {
    pickCount += 1;
    lastSource = source;
    if (error != null) {
      throw error!;
    }
    return image;
  }
}
