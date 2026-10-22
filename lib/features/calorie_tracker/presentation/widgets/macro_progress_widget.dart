import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UncertaintyProgressBar extends StatelessWidget {
  const UncertaintyProgressBar({
    super.key,
    required this.progress,
    required this.spread,
    required this.color,
    this.minHeight = 8,
    this.gradientColors,
  });

  final double progress;
  final double spread;
  final Color color;
  final double minHeight;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final double lower = (progress * (1 - spread)).clamp(0, 1).toDouble();
    final double upper = (progress * (1 + spread)).clamp(0, 1).toDouble();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double bandLeft = width * lower;
        final double bandWidth = (width * (upper - lower)).clamp(0, width).toDouble();

        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            // Base track background
            Container(
              height: minHeight,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(minHeight / 2),
              ),
            ),
            // Uncertainty spread zone
            if (spread > 0)
              Positioned(
                left: bandLeft,
                child: Container(
                  width: bandWidth,
                  height: minHeight,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(minHeight / 2),
                  ),
                ),
              ),
            // Animated progress fill
            TweenAnimationBuilder<double>(
              key: Key('${key.toString()}-fill'),
              tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double animatedValue, Widget? child) {
                return FractionallySizedBox(
                  widthFactor: animatedValue.clamp(0.0, 1.0),
                  child: Container(
                    height: minHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors ?? <Color>[color.withValues(alpha: 0.8), color],
                      ),
                      borderRadius: BorderRadius.circular(minHeight / 2),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Animated circular progress ring with an optional uncertainty band.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.progress,
    required this.color,
    this.spread = 0,
    this.size = 112,
    this.strokeWidth = 11,
    this.child,
  });

  final double progress;
  final Color color;
  final double spread;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: value,
              spread: spread,
              color: color,
              trackColor: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFF2E3B33).withValues(alpha: 0.08),
              strokeWidth: strokeWidth,
            ),
            child: Center(child: child),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.spread,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final double spread;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(strokeWidth / 2);
    const double start = -math.pi / 2;

    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (spread > 0 && progress > 0) {
      final double lower = (progress * (1 - spread)).clamp(0.0, 1.0);
      final double upper = (progress * (1 + spread)).clamp(0.0, 1.0);
      canvas.drawArc(
        arcRect,
        start + math.pi * 2 * lower,
        math.pi * 2 * (upper - lower),
        false,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }

    if (progress > 0) {
      final double sweep = math.pi * 2 * progress;
      canvas.drawArc(
        arcRect,
        start,
        sweep,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: math.pi * 2,
            transform: const GradientRotation(start),
            colors: <Color>[color.withValues(alpha: 0.75), color],
            stops: <double>[0, progress.clamp(0.01, 1.0)],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.spread != spread ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// Compact macro row: colored dot, "Label  consumed/target g", percent, and a slim bar.
class MacroCardItem extends StatelessWidget {
  const MacroCardItem({
    super.key,
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
    required this.labelKey,
    required this.icon,
    this.showSpread = false,
    this.averageSpread = 0.0,
    this.isCompact = false,
  });

  final String label;
  final int consumed;
  final int target;
  final Color color;
  final Key labelKey;
  final IconData icon;
  final bool showSpread;
  final double averageSpread;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final double progress = target <= 0 ? 0 : (consumed / target).clamp(0, 1).toDouble();
    final double spread = showSpread ? averageSpread : 0;
    final int low = (consumed * (1 - spread)).round().clamp(0, 99999).toInt();
    final int high = (consumed * (1 + spread)).round().clamp(0, 99999).toInt();
    final int percent = target <= 0 ? 0 : (consumed / target * 100).round();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label  $consumed/$target g',
                key: labelKey,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        if (spread > 0) ...<Widget>[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              'Range: $low-$high g (+/-${(spread * 100).round()}%)',
              style: TextStyle(color: AppColors.textSecondary(isDark), fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: UncertaintyProgressBar(
            key: Key('${labelKey.toString()}-bar'),
            progress: progress,
            spread: spread,
            color: color,
            minHeight: 7,
          ),
        ),
      ],
    );
  }
}
