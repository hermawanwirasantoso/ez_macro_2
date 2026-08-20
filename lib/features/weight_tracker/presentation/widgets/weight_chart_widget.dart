import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/weight_entry.dart';
import '../../domain/weight_tracker_state.dart';
import '../../domain/weight_unit.dart';
import '../../../calorie_tracker/presentation/theme/app_theme.dart';

class WeightChartWidget extends StatefulWidget {
  const WeightChartWidget({
    super.key,
    required this.trackerState,
    required this.onSelectRange,
    this.onTapAdd,
  });

  final WeightTrackerState trackerState;
  final ValueChanged<WeightTimeRange> onSelectRange;
  final VoidCallback? onTapAdd;

  @override
  State<WeightChartWidget> createState() => _WeightChartWidgetState();
}

class _WeightChartWidgetState extends State<WeightChartWidget> {
  int? _selectedPointIndex;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<WeightEntry> chartEntries = widget.trackerState.chartEntries;
    final WeightUnit unit = widget.trackerState.preferredUnit;

    return Card(
      key: const Key('weightChartCard'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header Row: Title and Time Range Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.show_chart_rounded,
                      size: 20,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Weight Trend',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                _buildRangeSelector(isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Main Chart or Empty State
            if (chartEntries.isEmpty)
              _buildEmptyState(isDark)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Chart canvas
                  SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        return GestureDetector(
                          onTapDown: (TapDownDetails details) {
                            _handleChartTap(details.localPosition, constraints.maxWidth, chartEntries);
                          },
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, 190),
                            painter: _WeightLineChartPainter(
                              entries: chartEntries,
                              unit: unit,
                              targetWeight: widget.trackerState.goal.targetWeight != null
                                  ? widget.trackerState.goal.unit.convertTo(
                                      widget.trackerState.goal.targetWeight!,
                                      unit,
                                    )
                                  : null,
                              isDark: isDark,
                              selectedIndex: _selectedPointIndex,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Selected Point Inspector Tooltip
                  if (_selectedPointIndex != null &&
                      _selectedPointIndex! < chartEntries.length) ...<Widget>[
                    const SizedBox(height: 10),
                    _buildSelectedPointBadge(chartEntries[_selectedPointIndex!], unit, isDark),
                  ],

                  const SizedBox(height: 14),

                  // Stats Pills Row (Average, Min, Max, Range Change)
                  _buildStatsSummaryRow(isDark, unit),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _handleChartTap(Offset localPosition, double width, List<WeightEntry> entries) {
    if (entries.isEmpty) return;
    if (entries.length == 1) {
      setState(() {
        _selectedPointIndex = _selectedPointIndex == 0 ? null : 0;
      });
      return;
    }

    final double step = (width - 48) / (entries.length - 1);
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < entries.length; i++) {
      final double pointX = 24 + i * step;
      final double dist = (localPosition.dx - pointX).abs();
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    setState(() {
      _selectedPointIndex = _selectedPointIndex == closestIndex ? null : closestIndex;
    });
  }

  Widget _buildRangeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: WeightTimeRange.values.map((WeightTimeRange range) {
          final bool isSelected = widget.trackerState.selectedRange == range;
          return GestureDetector(
            key: Key('rangeFilter_${range.name}'),
            onTap: () {
              setState(() {
                _selectedPointIndex = null;
              });
              widget.onSelectRange(range);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                range.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedPointBadge(WeightEntry entry, WeightUnit unit, bool isDark) {
    final double converted = entry.unit.convertTo(entry.weight, unit);
    return Container(
      key: const Key('selectedPointBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            entry.formattedDisplayDate,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          Text(
            '${converted.toStringAsFixed(1)} ${unit.displayName}'
            '${entry.bodyFatPercentage != null ? " • ${entry.bodyFatPercentage!.toStringAsFixed(1)}% BF" : ""}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummaryRow(bool isDark, WeightUnit unit) {
    final double? avg = widget.trackerState.averageWeightInRange;
    final double? min = widget.trackerState.minWeightInRange;
    final double? max = widget.trackerState.maxWeightInRange;
    final double? change = widget.trackerState.rangeChange;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildStatPill('Average', avg != null ? '${avg.toStringAsFixed(1)} ${unit.displayName}' : '--', isDark),
          _buildStatPill('Min', min != null ? '${min.toStringAsFixed(1)}' : '--', isDark),
          _buildStatPill('Max', max != null ? '${max.toStringAsFixed(1)}' : '--', isDark),
          _buildStatPill(
            'Period Change',
            change != null
                ? '${change >= 0 ? "+" : ""}${change.toStringAsFixed(1)} ${unit.displayName}'
                : '--',
            isDark,
            valueColor: change == null || change == 0
                ? null
                : (change < 0 ? AppColors.success : AppColors.fat),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      height: 160,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.stacked_line_chart_rounded,
            size: 36,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 8),
          Text(
            'No weight entries in this period',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.onTapAdd != null)
            TextButton.icon(
              key: const Key('emptyStateAddButton'),
              onPressed: widget.onTapAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Log First Weigh-in', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _WeightLineChartPainter extends CustomPainter {
  _WeightLineChartPainter({
    required this.entries,
    required this.unit,
    this.targetWeight,
    required this.isDark,
    this.selectedIndex,
  });

  final List<WeightEntry> entries;
  final WeightUnit unit;
  final double? targetWeight;
  final bool isDark;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    const double paddingLeft = 28.0;
    const double paddingRight = 20.0;
    const double paddingTop = 18.0;
    const double paddingBottom = 26.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Convert values to chart unit
    final List<double> values = entries.map((WeightEntry e) => e.unit.convertTo(e.weight, unit)).toList();

    double minVal = values.reduce(math.min);
    double maxVal = values.reduce(math.max);

    if (targetWeight != null) {
      minVal = math.min(minVal, targetWeight!);
      maxVal = math.max(maxVal, targetWeight!);
    }

    // Add vertical headroom
    double range = maxVal - minVal;
    if (range < 1.0) {
      range = 2.0;
      minVal -= 1.0;
      maxVal += 1.0;
    } else {
      final double margin = range * 0.15;
      minVal -= margin;
      maxVal += margin;
      range = maxVal - minVal;
    }

    // Gridlines and Y-axis labels
    final Paint gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    final TextStyle axisTextStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w500,
      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
    );

    const int gridSteps = 3;
    for (int i = 0; i <= gridSteps; i++) {
      final double y = paddingTop + chartHeight * (1.0 - (i / gridSteps));
      final double val = minVal + (range * (i / gridSteps));

      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      final TextSpan span = TextSpan(text: val.toStringAsFixed(1), style: axisTextStyle);
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Target line if present
    if (targetWeight != null && targetWeight! >= minVal && targetWeight! <= maxVal) {
      final double targetY = paddingTop + chartHeight * (1.0 - ((targetWeight! - minVal) / range));
      final Paint targetLinePaint = Paint()
        ..color = AppColors.success.withValues(alpha: 0.7)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Draw dashed line
      const double dashWidth = 4.0;
      const double dashSpace = 4.0;
      double startX = paddingLeft;
      while (startX < size.width - paddingRight) {
        canvas.drawLine(
          Offset(startX, targetY),
          Offset(math.min(startX + dashWidth, size.width - paddingRight), targetY),
          targetLinePaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    // Points calculation
    final List<Offset> points = <Offset>[];
    if (entries.length == 1) {
      final double y = paddingTop + chartHeight * (1.0 - ((values[0] - minVal) / range));
      points.add(Offset(paddingLeft + chartWidth / 2, y));
    } else {
      final double stepX = chartWidth / (entries.length - 1);
      for (int i = 0; i < entries.length; i++) {
        final double x = paddingLeft + (i * stepX);
        final double y = paddingTop + chartHeight * (1.0 - ((values[i] - minVal) / range));
        points.add(Offset(x, y));
      }
    }

    // Draw Smooth Line Curve & Fill
    if (points.length > 1) {
      final Path linePath = Path();
      linePath.moveTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 1; i++) {
        final Offset p0 = points[i];
        final Offset p1 = points[i + 1];
        final double controlX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      // Gradient fill underneath
      final Path fillPath = Path.from(linePath);
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.lineTo(points.first.dx, paddingTop + chartHeight);
      fillPath.close();

      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.35),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);

      final Paint linePaint = Paint()
        ..color = AppColors.primaryLight
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, linePaint);
    }

    // Draw Dots and Labels
    final Paint pointPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final Paint pointBorderPaint = Paint()
      ..color = isDark ? AppColors.darkCard : Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Paint selectedPointPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final Offset pt = points[i];
      final bool isSelected = selectedIndex == i;

      // Outer border
      canvas.drawCircle(pt, isSelected ? 6.5 : 4.5, pointBorderPaint);
      // Inner fill
      canvas.drawCircle(pt, isSelected ? 5.0 : 3.5, isSelected ? selectedPointPaint : pointPaint);

      // Date labels along X axis for selected or interval entries
      final bool shouldDrawLabel = points.length <= 7 ||
          i == 0 ||
          i == points.length - 1 ||
          (points.length > 7 && i % (points.length ~/ 4) == 0);

      if (shouldDrawLabel) {
        final String dateLabel = DateFormat('M/d').format(entries[i].date);
        final TextSpan dateSpan = TextSpan(text: dateLabel, style: axisTextStyle);
        final TextPainter dateTp = TextPainter(
          text: dateSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        dateTp.paint(canvas, Offset(pt.dx - dateTp.width / 2, size.height - paddingBottom + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLineChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.unit != unit ||
        oldDelegate.targetWeight != targetWeight ||
        oldDelegate.isDark != isDark ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
