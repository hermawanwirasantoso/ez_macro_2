import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../calorie_tracker/presentation/theme/app_theme.dart';

final NumberFormat _thousands = NumberFormat.decimalPattern('en_US');

/// Formats a whole number with thousands separators, e.g. 2,050.
String formatNumber(num value) => _thousands.format(value.round());

/// Formats a signed number, e.g. +120 or -1,400.
String formatSigned(num value) => value > 0 ? '+${formatNumber(value)}' : formatNumber(value);

/// Formats a signed weight change, e.g. +0.4 kg or -0.18 kg.
String formatWeightChange(double value, {String unit = 'kg'}) {
  String digits = value.abs().toStringAsFixed(2);
  if (digits.endsWith('0')) digits = digits.substring(0, digits.length - 1);
  return '${value > 0
      ? '+'
      : value < 0
      ? '-'
      : ''}$digits $unit';
}

/// Bar and text color for a day's calories against its goal: coral when over
/// by more than 10%, solid emerald within 10%, faded emerald when under.
Color calorieStatusColor(int calories, int goal) {
  if (goal > 0 && calories > goal * 1.1) return AppColors.calories;
  if (goal > 0 && calories < goal * 0.9) return AppColors.primaryLight.withValues(alpha: 0.5);
  return AppColors.primaryLight;
}

/// Rounded card used by every insights section.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Small label-over-value stat used in card rows.
class InsightStat extends StatelessWidget {
  const InsightStat({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueKey,
    this.valueColor,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? caption;
  final Key? valueKey;
  final Color? valueColor;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              key: valueKey,
              maxLines: 1,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: valueColor ?? AppColors.textPrimary(isDark),
              ),
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary(isDark)),
            ),
        ],
      ),
    );
  }
}

/// Thin rounded progress bar with an optional goal tick.
class InsightBar extends StatelessWidget {
  const InsightBar({super.key, required this.fraction, required this.color, this.markerFraction, this.height = 8});

  final double fraction;
  final Color color;

  /// Where to draw the goal tick, as a fraction of the full width.
  final double? markerFraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        return SizedBox(
          height: height + 4,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: AppColors.subtleFill(isDark),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              Container(
                height: height,
                width: width * fraction.clamp(0.0, 1.0),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
              ),
              if (markerFraction != null)
                Positioned(
                  left: (width * markerFraction!.clamp(0.0, 1.0) - 1).clamp(0.0, width - 2),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary(isDark).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal bar split into colored segments, e.g. a calorie share.
class SegmentedShareBar extends StatelessWidget {
  const SegmentedShareBar({super.key, required this.segments, this.height = 10});

  final List<MapEntry<Color, double>> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double total = segments.fold(0, (double sum, MapEntry<Color, double> s) => sum + s.value);
    if (total <= 0) return SizedBox(height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < segments.length; i++)
              if (segments[i].value > 0)
                Expanded(
                  flex: (segments[i].value / total * 1000).round().clamp(1, 1000),
                  child: Container(
                    margin: EdgeInsets.only(right: i == segments.length - 1 ? 0 : 2),
                    color: segments[i].key,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Small colored dot followed by a label, for chart legends.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
        ),
      ],
    );
  }
}
