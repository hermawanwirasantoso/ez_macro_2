import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../calorie_tracker/presentation/theme/app_theme.dart';
import '../../domain/insights_report.dart';
import 'insight_widgets.dart';

/// Bar chart of daily calories against the goal line. Tapping or dragging
/// across the bars selects a day.
class DailyCalorieChart extends StatelessWidget {
  const DailyCalorieChart({
    super.key,
    required this.days,
    this.selectedIndex,
    this.onSelect,
    this.height = 190,
  });

  final List<DaySummary> days;
  final int? selectedIndex;
  final ValueChanged<int>? onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, height);

        void select(Offset position) {
          if (onSelect == null || days.isEmpty) return;
          final double slot = (size.width - _DailyCaloriePainter.leftPad - _DailyCaloriePainter.rightPad) / days.length;
          final int index =
              ((position.dx - _DailyCaloriePainter.leftPad) / slot).floor().clamp(0, days.length - 1);
          if (index != selectedIndex) onSelect!(index);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) => select(details.localPosition),
          onHorizontalDragUpdate: (DragUpdateDetails details) => select(details.localPosition),
          child: CustomPaint(
            size: size,
            painter: _DailyCaloriePainter(days: days, selectedIndex: selectedIndex, isDark: isDark),
          ),
        );
      },
    );
  }
}

class _DailyCaloriePainter extends CustomPainter {
  _DailyCaloriePainter({required this.days, required this.selectedIndex, required this.isDark});

  static const double leftPad = 34;
  static const double rightPad = 2;
  static const double topPad = 16;
  static const double bottomPad = 22;

  final List<DaySummary> days;
  final int? selectedIndex;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    final double chartRight = size.width - rightPad;
    final double chartBottom = size.height - bottomPad;
    final double chartHeight = chartBottom - topPad;
    final int n = days.length;
    final int goal = days.last.goal;

    final int maxCalories = days.fold(0, (int m, DaySummary d) => math.max(m, d.calories));
    final double maxY = math.max(1000, (math.max(maxCalories, goal) * 1.15 / 500).ceil() * 500).toDouble();
    double yFor(num value) => chartBottom - chartHeight * (value / maxY);

    final TextStyle axisStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary(isDark),
    );

    // Gridlines with compact kcal labels.
    final Paint gridPaint = Paint()
      ..color = AppColors.border(isDark)
      ..strokeWidth = 1;
    for (final double value in <double>[0, maxY / 2, maxY]) {
      final double y = yFor(value);
      canvas.drawLine(Offset(leftPad, y), Offset(chartRight, y), gridPaint);
      final TextPainter tp = _text(_compact(value), axisStyle);
      tp.paint(canvas, Offset(leftPad - 6 - tp.width, y - tp.height / 2));
    }

    // Bars.
    final double slot = (chartRight - leftPad) / n;
    final double barWidth = (slot * (n <= 7 ? 0.5 : (n <= 31 ? 0.62 : 0.72))).clamp(2.0, 28.0);
    final Radius radius = Radius.circular(math.min(barWidth / 2, 6));

    for (int i = 0; i < n; i++) {
      final DaySummary day = days[i];
      final double cx = leftPad + slot * (i + 0.5);

      if (i == selectedIndex) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - slot / 2 + 0.5, topPad - 8, cx + slot / 2 - 0.5, chartBottom),
            Radius.circular(math.min(slot / 2, 8)),
          ),
          Paint()..color = AppColors.subtleFill(isDark),
        );
      }

      if (!day.isLogged) {
        canvas.drawCircle(
          Offset(cx, chartBottom - 2),
          math.min(barWidth / 2, 2),
          Paint()..color = AppColors.textSecondary(isDark).withValues(alpha: 0.35),
        );
        continue;
      }

      final double top = math.min(yFor(day.calories), chartBottom - 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - barWidth / 2, top, cx + barWidth / 2, chartBottom),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()..color = calorieStatusColor(day.calories, day.goal),
      );
    }

    // Dashed goal line with a label at the right end.
    final double goalY = yFor(goal);
    final Paint goalPaint = Paint()
      ..color = AppColors.textPrimary(isDark).withValues(alpha: 0.45)
      ..strokeWidth = 1.2;
    for (double x = leftPad; x < chartRight; x += 7) {
      canvas.drawLine(Offset(x, goalY), Offset(math.min(x + 4, chartRight), goalY), goalPaint);
    }
    final TextPainter goalTp = _text(
      'Goal ${formatNumber(goal)}',
      axisStyle.copyWith(color: AppColors.textPrimary(isDark).withValues(alpha: 0.75), fontWeight: FontWeight.w700),
    );
    final Rect goalLabel = Rect.fromLTWH(
      chartRight - goalTp.width - 8,
      goalY - goalTp.height - 5,
      goalTp.width + 8,
      goalTp.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(goalLabel, const Radius.circular(6)),
      Paint()..color = AppColors.card(isDark).withValues(alpha: 0.9),
    );
    goalTp.paint(canvas, Offset(goalLabel.left + 4, goalLabel.top + 1));

    // Date labels, counted back from the last day so today is always labelled.
    final DateFormat format = n <= 7 ? DateFormat('E') : DateFormat('MMM d');
    final double labelSlot = _text(n <= 7 ? 'Wed' : 'Sep 30', axisStyle).width + 10;
    final int every = math.max(1, (labelSlot / slot).ceil());
    for (int i = n - 1; i >= 0; i -= every) {
      final bool selected = i == selectedIndex;
      final TextPainter tp = _text(
        format.format(days[i].date),
        selected ? axisStyle.copyWith(color: AppColors.textPrimary(isDark), fontWeight: FontWeight.w800) : axisStyle,
      );
      final double cx = leftPad + slot * (i + 0.5);
      final double x = (cx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartBottom + 6));
    }
  }

  static TextPainter _text(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static String _compact(double value) {
    if (value >= 1000) {
      final double k = value / 1000;
      return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _DailyCaloriePainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}
