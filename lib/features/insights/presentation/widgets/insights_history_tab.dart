import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../calorie_tracker/domain/daily_log.dart';
import '../../../calorie_tracker/presentation/theme/app_theme.dart';
import '../../domain/insights_report.dart';
import 'insight_widgets.dart';

/// Every logged day, newest first, grouped into Monday-to-Sunday weeks with
/// the week's average. Tapping a day expands its food list.
class InsightsHistoryTab extends StatefulWidget {
  const InsightsHistoryTab({super.key, required this.logs, this.referenceDate});

  final List<DailyLog> logs;
  final DateTime? referenceDate;

  @override
  State<InsightsHistoryTab> createState() => _InsightsHistoryTabState();
}

class _InsightsHistoryTabState extends State<InsightsHistoryTab> {
  final Set<DateTime> _expanded = <DateTime>{};
  late List<DaySummary> _days;
  late List<WeekSummary> _weeks;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant InsightsHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logs != widget.logs) _compute();
  }

  void _compute() {
    _days = InsightsCalculator.loggedDays(widget.logs);
    _weeks = InsightsCalculator.groupByWeek(_days);
  }

  void _toggle(DateTime day) {
    setState(() {
      if (!_expanded.remove(day)) _expanded.add(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_days.isEmpty) return _EmptyHistory(isDark: isDark);

    final DateTime now = widget.referenceDate ?? DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime thisMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));

    // Flatten into summary, then a header followed by its days for each week.
    final List<Widget Function()> items = <Widget Function()>[
      () => _HistorySummary(days: _days, today: today),
    ];
    for (int w = 0; w < _weeks.length; w++) {
      final WeekSummary week = _weeks[w];
      items.add(() => _WeekHeader(index: w, week: week, today: today, thisMonday: thisMonday, isDark: isDark));
      for (final DaySummary day in week.days) {
        items.add(() => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HistoryDayTile(
                day: day,
                today: today,
                expanded: _expanded.contains(day.date),
                onTap: () => _toggle(day.date),
              ),
            ));
      }
    }

    return ListView.builder(
      key: const Key('historyScrollView'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) => items[index](),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.history_rounded, size: 40, color: AppColors.textSecondary(isDark)),
            const SizedBox(height: 12),
            Text(
              'No history yet',
              key: const Key('historyEmptyText'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary(isDark)),
            ),
            const SizedBox(height: 4),
            Text(
              'Every day you log food will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Totals over every completed logged day; today is still in progress.
class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.days, required this.today});

  final List<DaySummary> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final List<DaySummary> completed = days.where((DaySummary d) => d.date != today).toList();
    final NutritionAverages avg = NutritionAverages.of(completed);
    final int onTarget = completed.where((DaySummary d) => d.isOnTarget).length;
    return InsightCard(
      key: const Key('historySummary'),
      title: 'All history',
      subtitle: 'Since ${DateFormat('MMM d, yyyy').format(days.last.date)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: InsightStat(label: 'Days logged', value: formatNumber(avg.daysLogged))),
          Expanded(
            child: InsightStat(
              label: 'Avg intake',
              value: avg.hasData ? formatNumber(avg.calories) : '—',
              valueKey: const Key('historyAvgCaloriesText'),
              caption: 'kcal/day',
            ),
          ),
          Expanded(
            child: InsightStat(
              label: 'On target',
              value: avg.hasData ? '${(onTarget * 100 / avg.daysLogged).round()}%' : '—',
              caption: 'within 10%',
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.index,
    required this.week,
    required this.today,
    required this.thisMonday,
    required this.isDark,
  });

  final int index;
  final WeekSummary week;
  final DateTime today;
  final DateTime thisMonday;
  final bool isDark;

  String get _label {
    final int weeksAgo = (thisMonday.difference(week.start).inHours / (24 * 7)).round();
    if (weeksAgo == 0) return 'This week';
    if (weeksAgo == 1) return 'Last week';
    final DateTime end = week.end;
    return week.start.year != thisMonday.year
        ? '${DateFormat('MMM d').format(week.start)} – ${DateFormat('MMM d, yyyy').format(end)}'
        : '${DateFormat('MMM d').format(week.start)} – ${DateFormat(week.start.month == end.month ? 'd' : 'MMM d').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final NutritionAverages avg = NutritionAverages.of(week.days.where((DaySummary d) => d.date != today));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary(isDark)),
            ),
          ),
          Text(
            avg.hasData
                ? 'avg ${formatNumber(avg.calories)} kcal · ${avg.daysLogged} ${avg.daysLogged == 1 ? 'day' : 'days'}'
                : 'in progress',
            key: Key('historyWeekAvg_$index'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
          ),
        ],
      ),
    );
  }
}

class _HistoryDayTile extends StatelessWidget {
  const _HistoryDayTile({
    required this.day,
    required this.today,
    required this.expanded,
    required this.onTap,
  });

  final DaySummary day;
  final DateTime today;
  final bool expanded;
  final VoidCallback onTap;

  String get _title {
    final int daysAgo = (today.difference(day.date).inHours / 24).round();
    if (daysAgo == 0) return 'Today so far';
    if (daysAgo == 1) return 'Yesterday';
    return DateFormat('EEEE').format(day.date);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String dateKey = DailyLog.formatDateKey(day.date);
    final List<FoodLogEntry> entries = List<FoodLogEntry>.of(day.entries)
      ..sort((FoodLogEntry a, FoodLogEntry b) => a.timestamp.compareTo(b.timestamp));

    return Material(
      color: AppColors.card(isDark),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('historyDay_$dateKey'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.subtleFill(isDark),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          DateFormat('MMM').format(day.date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                        Text(
                          '${day.date.day}',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary(isDark)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _title,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                              ),
                            ),
                            Text(
                              formatNumber(day.calories),
                              key: Key('historyDayCalories_$dateKey'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: day.isOverTarget ? AppColors.calories : AppColors.textPrimary(isDark),
                              ),
                            ),
                            Text(
                              ' / ${formatNumber(day.goal)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        InsightBar(
                          fraction: day.goal > 0 ? day.calories / (day.goal * 1.25) : 0,
                          color: calorieStatusColor(day.calories, day.goal),
                          markerFraction: 0.8,
                          height: 6,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'P ${day.proteinG}g · C ${day.carbsG}g · F ${day.fatG}g',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                              ),
                            ),
                            Text(
                              '${entries.length} ${entries.length == 1 ? 'item' : 'items'}',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                            ),
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textSecondary(isDark)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (expanded) ...<Widget>[
                const SizedBox(height: 10),
                Divider(height: 1, color: AppColors.border(isDark)),
                const SizedBox(height: 6),
                for (final FoodLogEntry entry in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: entry.mealType.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                entry.mealLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                              ),
                              Text(
                                '${entry.mealType.displayName} · ${DateFormat.Hm().format(entry.timestamp)} · ${entry.portionDisplay}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(isDark)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${formatNumber(entry.calories)} kcal',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
