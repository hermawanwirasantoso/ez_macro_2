import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen camera scanner. Pops with the detected barcode string, or
/// null when dismissed without a scan.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) {
      return;
    }
    final String? value = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MobileScanner(
              key: const Key('barcodeCameraPreview'),
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (BuildContext context, MobileScannerException error) {
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.videocam_off_rounded,
                          size: 48, color: Colors.white54),
                      const SizedBox(height: 16),
                      Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission is required to scan barcodes. Enable it in your system settings.'
                            : 'Could not start the camera on this device.',
                        key: const Key('barcodeCameraError'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const _ScanFrameOverlay(),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: <Widget>[
                  _CircleButton(
                    key: const Key('closeBarcodeScannerButton'),
                    icon: Icons.close_rounded,
                    tooltip: 'Close scanner',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _CircleButton(
                    key: const Key('toggleTorchButton'),
                    icon: Icons.flashlight_on_rounded,
                    tooltip: 'Toggle torch',
                    onTap: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Point the camera at the product barcode',
                    key: Key('barcodeScanHint'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'EAN, UPC and Code 128 are supported',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double frameWidth = constraints.maxWidth * 0.72;
          final double frameHeight = frameWidth * 0.62;
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _ScanFramePainter(
              frameSize: Size(frameWidth, frameHeight),
            ),
          );
        },
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({required this.frameSize});

  final Size frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect frame = Alignment.center.inscribe(
      frameSize,
      Offset.zero & size,
    );
    final RRect rounded = RRect.fromRectAndRadius(frame, const Radius.circular(20));

    final Path dimPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rounded)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      dimPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final Paint borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)],
      ).createShader(frame)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(rounded, borderPaint);
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.frameSize != frameSize;
}
