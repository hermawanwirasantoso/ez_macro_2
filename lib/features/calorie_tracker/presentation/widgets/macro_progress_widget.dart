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
                color: color.withValues(alpha: 0.12),
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
                    color: color.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(minHeight / 2),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1,
                    ),
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
                        colors: gradientColors ??
                            <Color>[color.withValues(alpha: 0.85), color],
                      ),
                      borderRadius: BorderRadius.circular(minHeight / 2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
    final int percent = (progress * 100).round();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label  $consumed/$target g',
                  key: labelKey,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (spread > 0) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Range: $low-$high g (+/-${(spread * 100).round()}%)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 11,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          UncertaintyProgressBar(
            key: Key('${labelKey.toString()}-bar'),
            progress: progress,
            spread: spread,
            color: color,
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}
