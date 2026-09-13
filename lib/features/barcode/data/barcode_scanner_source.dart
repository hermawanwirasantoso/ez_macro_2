import 'package:flutter/material.dart';

import '../presentation/barcode_scanner_page.dart';

/// Obtains a raw barcode string from the user.
///
/// The device implementation opens a full-screen camera scanner; tests inject
/// a fake so no camera is required.
abstract class BarcodeScannerSource {
  const BarcodeScannerSource();

  factory BarcodeScannerSource.device() = DeviceBarcodeScannerSource;

  factory BarcodeScannerSource.fake({String? barcode, Object? error}) =
      FakeBarcodeScannerSource;

  /// Shows the scanner and returns the detected barcode, or null when the
  /// user cancels without scanning.
  Future<String?> scan(BuildContext context);
}

class DeviceBarcodeScannerSource implements BarcodeScannerSource {
  const DeviceBarcodeScannerSource();

  @override
  Future<String?> scan(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder<String>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation) {
          return const BarcodeScannerPage();
        },
        transitionsBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation, Widget child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class FakeBarcodeScannerSource implements BarcodeScannerSource {
  FakeBarcodeScannerSource({this.barcode, this.error});

  String? barcode;
  Object? error;
  int scanCount = 0;

  @override
  Future<String?> scan(BuildContext context) async {
    scanCount += 1;
    if (error != null) {
      throw error!;
    }
    return barcode;
  }
}
