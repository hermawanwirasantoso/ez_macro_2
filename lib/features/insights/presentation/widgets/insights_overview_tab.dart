import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../calorie_tracker/domain/daily_log.dart';
import '../../../calorie_tracker/domain/meal_type.dart';
import '../../../calorie_tracker/domain/user_settings.dart';
import '../../../calorie_tracker/presentation/theme/app_theme.dart';
import '../../../weight_tracker/domain/weight_entry.dart';
import '../../../weight_tracker/domain/weight_goal.dart';
import '../../../weight_tracker/domain/weight_unit.dart';
import '../../domain/insights_report.dart';
import 'daily_calorie_chart.dart';
import 'insight_widgets.dart';

/// Period stats, daily chart, weekly averages, macros, meals, top foods,
/// weight and highlights for a selectable 7/30/90-day window.
class InsightsOverviewTab extends StatefulWidget {
  const InsightsOverviewTab({
    super.key,
    required this.logs,
    required this.weightEntries,
    required this.settings,
    required this.goal,
    this.referenceDate,
  });

  final List<DailyLog> logs;
  final List<WeightEntry> weightEntries;
  final UserSettings settings;
  final WeightGoal goal;
  final DateTime? referenceDate;

  @override
  State<InsightsOverviewTab> createState() => _InsightsOverviewTabState();
}

class _InsightsOverviewTabState extends State<InsightsOverviewTab> {
  static const List<int> _periods = <int>[7, 30, 90];

  int _windowDays = 7;
  int? _selectedDay;
  late InsightsReport _report;
  late List<WeekSummary> _weeks;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant InsightsOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logs != widget.logs ||
        oldWidget.weightEntries != widget.weightEntries ||
        oldWidget.settings != widget.settings ||
        oldWidget.goal != widget.goal) {
      _compute();
    }
  }

  void _compute() {
    _report = InsightsCalculator.report(
      logs: widget.logs,
      weightEntries: widget.weightEntries,
      settings: widget.settings,
      goal: widget.goal,
      windowDays: _windowDays,
      referenceDate: widget.referenceDate,
    );
    _weeks = InsightsCalculator.recentWeeks(
      logs: widget.logs,
      settings: widget.settings,
      referenceDate: widget.referenceDate,
    );
    final int lastLogged = _report.days.lastIndexWhere((DaySummary d) => d.isLogged);
    _selectedDay = lastLogged >= 0 ? lastLogged : null;
  }

  void _setPeriod(int days) {
    if (days == _windowDays) return;
    setState(() {
      _windowDays = days;
      _compute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final InsightsReport report = _report;
    return ListView(
      key: const Key('overviewScrollView'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        _PeriodSelector(options: _periods, selected: _windowDays, onChanged: _setPeriod),
        const SizedBox(height: 14),
        _HeroSummary(report: report),
        const SizedBox(height: 14),
        _DailyChartCard(
          report: report,
          selectedIndex: _selectedDay,
          onSelect: (int index) => setState(() => _selectedDay = index),
        ),
        const SizedBox(height: 14),
        _WeeklyAveragesCard(weeks: _weeks, fallbackGoal: widget.settings.dailyGoal),
        if (report.averages.hasData) ...<Widget>[
          const SizedBox(height: 14),
          _MacroCard(report: report),
        ],
        if (report.mealCalories.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _MealCard(report: report),
        ],
        if (report.topFoods.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _TopFoodsCard(foods: report.topFoods),
        ],
        const SizedBox(height: 14),
        _WeightCard(weight: report.weight, goal: widget.goal),
        if (report.highlights.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _HighlightsCard(highlights: report.highlights),
        ],
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.options, required this.selected, required this.onChanged});

  final List<int> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Row(
        children: <Widget>[
          for (final int days in options)
            Expanded(
              child: GestureDetector(
                key: Key('insightsPeriod_$days'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: days == selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$days days',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: days == selected ? Colors.white : AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.report});

  final InsightsReport report;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final NutritionAverages avg = report.averages;
    final int goal = avg.hasData ? avg.goal : report.days.last.goal;
    final int? change = report.changeVsPrevious;
    final int net = avg.netDelta;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.09), AppColors.card(isDark)),
            AppColors.card(isDark),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Average intake',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary(isDark)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${avg.daysLogged}/${report.windowDays} days logged',
                  key: const Key('daysLoggedText'),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.brandText(isDark)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: avg.hasData ? formatNumber(avg.calories) : '—',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                TextSpan(
                  text: '  kcal/day',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                ),
              ],
            ),
            key: const Key('avgCaloriesText'),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                avg.hasData ? 'Goal ${formatNumber(goal)}' : 'No completed days logged in the last ${report.windowDays} days',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
              ),
              if (change != null)
                Row(
                  key: const Key('changeVsPreviousText'),
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      change == 0
                          ? Icons.drag_handle_rounded
                          : (change < 0 ? Icons.south_east_rounded : Icons.north_east_rounded),
                      size: 14,
                      color: AppColors.textPrimary(isDark),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${formatNumber(change.abs())} vs previous ${report.windowDays} days',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                    ),
                  ],
                ),
            ],
          ),
          if (avg.hasData) ...<Widget>[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.border(isDark)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: InsightStat(
                    label: 'Net balance',
                    value: '${formatSigned(net)} kcal',
                    valueKey: const Key('netBalanceText'),
                    valueColor: net > 0 ? AppColors.calories : AppColors.brandText(isDark),
                    caption: net > 0 ? 'surplus' : 'deficit',
                  ),
                ),
                Expanded(
                  child: InsightStat(
                    label: 'Est. change',
                    value: formatWeightChange(report.estimatedWeightChangeKg),
                    valueKey: const Key('estimatedChangeText'),
                    caption: 'from calories',
                  ),
                ),
                Expanded(
                  child: InsightStat(
                    label: 'On target',
                    value: '${report.daysOnTarget}/${avg.daysLogged} days',
                    valueKey: const Key('onTargetText'),
                    caption: 'within 10%',
                  ),
                ),
              ],
            ),
          ],
          if (report.todayLogged) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              key: const Key('todayExcludedNote'),
              children: <Widget>[
                Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary(isDark)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Today is still in progress, so it is not counted yet.',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary(isDark)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyChartCard extends StatelessWidget {
  const _DailyChartCard({required this.report, required this.selectedIndex, required this.onSelect});

  final InsightsReport report;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateFormat range = DateFormat('MMM d');
    return InsightCard(
      title: 'Daily calories',
      subtitle: '${range.format(report.start)} – ${range.format(report.end)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SelectedDayDetail(day: selectedIndex == null ? null : report.days[selectedIndex!]),
          const SizedBox(height: 12),
          DailyCalorieChart(
            key: const Key('dailyCalorieChart'),
            days: report.days,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              LegendDot(color: calorieStatusColor(0, 100), label: 'Under'),
              LegendDot(color: calorieStatusColor(100, 100), label: 'Within 10%'),
              LegendDot(color: calorieStatusColor(200, 100), label: 'Over'),
              Text(
                'Tap or drag the bars',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(isDark).withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedDayDetail extends StatelessWidget {
  const _SelectedDayDetail({required this.day});

  final DaySummary? day;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DaySummary? d = day;
    return Container(
      key: const Key('chartSelectedDayText'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.subtleFill(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: d == null
          ? Text(
              'Nothing logged in this period yet.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
            )
          : Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        DateFormat('EEE, MMM d').format(d.date),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary(isDark)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.isLogged
                            ? 'P ${d.proteinG}g · C ${d.carbsG}g · F ${d.fatG}g · ${d.entries.length} ${d.entries.length == 1 ? 'item' : 'items'}'
                            : 'Nothing logged',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
                if (d.isLogged)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${formatNumber(d.calories)} kcal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: d.isOverTarget ? AppColors.calories : AppColors.textPrimary(isDark),
                        ),
                      ),
                      Text(
                        d.goal > 0 ? '${(d.calories * 100 / d.goal).round()}% of ${formatNumber(d.goal)}' : '',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _WeeklyAveragesCard extends StatelessWidget {
  const _WeeklyAveragesCard({required this.weeks, required this.fallbackGoal});

  final List<WeekSummary> weeks;
  final int fallbackGoal;

  static String _label(int index, WeekSummary week) {
    if (index == 0) return 'This week';
    if (index == 1) return 'Last week';
    final DateTime end = week.end;
    return week.start.month == end.month
        ? '${DateFormat('MMM d').format(week.start)} – ${end.day}'
        : '${DateFormat('MMM d').format(week.start)} – ${DateFormat('MMM d').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    int scale = fallbackGoal;
    for (final WeekSummary week in weeks) {
      if (week.averages.calories > scale) scale = week.averages.calories;
      if (week.averages.goal > scale) scale = week.averages.goal;
    }
    final double maxValue = scale * 1.1;

    return InsightCard(
      title: 'Weekly averages',
      subtitle: 'Monday to Sunday, per completed logged day',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < weeks.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            _WeekRow(
              key: Key('weekRow_$i'),
              index: i,
              label: _label(i, weeks[i]),
              week: weeks[i],
              previous: i + 1 < weeks.length ? weeks[i + 1] : null,
              goal: weeks[i].averages.hasData ? weeks[i].averages.goal : fallbackGoal,
              maxValue: maxValue,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    super.key,
    required this.index,
    required this.label,
    required this.week,
    required this.previous,
    required this.goal,
    required this.maxValue,
    required this.isDark,
  });

  final int index;
  final String label;
  final WeekSummary week;
  final WeekSummary? previous;
  final int goal;
  final double maxValue;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final NutritionAverages avg = week.averages;
    final int? change = avg.hasData && (previous?.averages.hasData ?? false)
        ? avg.calories - previous!.averages.calories
        : null;

    return Row(
      children: <Widget>[
        SizedBox(
          width: 112,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
              ),
              Text(
                week.days.isEmpty
                    ? 'Starts today'
                    : (avg.hasData ? '${avg.daysLogged}/${week.days.length} days' : 'No logs'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary(isDark)),
              ),
            ],
          ),
        ),
        Expanded(
          child: InsightBar(
            fraction: avg.hasData ? avg.calories / maxValue : 0,
            color: calorieStatusColor(avg.calories, goal),
            markerFraction: goal / maxValue,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                avg.hasData ? formatNumber(avg.calories) : '—',
                key: Key('weekAvgText_$index'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: avg.hasData ? AppColors.textPrimary(isDark) : AppColors.textSecondary(isDark),
                ),
              ),
              if (change != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      change < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 11,
                      color: AppColors.textSecondary(isDark),
                    ),
                    Text(
                      formatNumber(change.abs()),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                    ),
                  ],
                )
              else
                Text(
                  'kcal',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary(isDark)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.report});

  final InsightsReport report;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final NutritionAverages avg = report.averages;
    final int proteinKcal = avg.proteinG * 4;
    final int carbsKcal = avg.carbsG * 4;
    final int fatKcal = avg.fatG * 9;
    final int macroKcal = proteinKcal + carbsKcal + fatKcal;
    int share(int kcal) => macroKcal > 0 ? (kcal * 100 / macroKcal).round() : 0;

    Widget row(String label, int value, int target, Color color, Key key) {
      return Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark))),
              const Spacer(),
              Text(
                target > 0 ? '$value / $target g' : '$value g',
                key: key,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InsightBar(fraction: target > 0 ? value / target : 0, color: color, markerFraction: target > 0 ? 1 : null, height: 7),
        ],
      );
    }

    return InsightCard(
      title: 'Macros',
      subtitle: 'Average per logged day vs your targets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          row('Protein', avg.proteinG, report.targetProteinG, AppColors.protein, const Key('avgProteinText')),
          const SizedBox(height: 12),
          row('Carbs', avg.carbsG, report.targetCarbsG, AppColors.carbs, const Key('avgCarbsText')),
          const SizedBox(height: 12),
          row('Fat', avg.fatG, report.targetFatG, AppColors.fat, const Key('avgFatText')),
          if (macroKcal > 0) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Calorie split',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 8),
            SegmentedShareBar(
              segments: <MapEntry<Color, double>>[
                MapEntry<Color, double>(AppColors.protein, proteinKcal.toDouble()),
                MapEntry<Color, double>(AppColors.carbs, carbsKcal.toDouble()),
                MapEntry<Color, double>(AppColors.fat, fatKcal.toDouble()),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: <Widget>[
                LegendDot(color: AppColors.protein, label: 'Protein ${share(proteinKcal)}%'),
                LegendDot(color: AppColors.carbs, label: 'Carbs ${share(carbsKcal)}%'),
                LegendDot(color: AppColors.fat, label: 'Fat ${share(fatKcal)}%'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.report});

  final InsightsReport report;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<MealType> meals = MealType.values.where((MealType m) => (report.mealCalories[m] ?? 0) > 0).toList();
    final int total = meals.fold(0, (int sum, MealType m) => sum + report.mealCalories[m]!);
    final int daysLogged = report.averages.daysLogged;

    return InsightCard(
      title: 'Calories by meal',
      subtitle: 'Average per logged day',
      child: Column(
        children: <Widget>[
          SegmentedShareBar(
            segments: <MapEntry<Color, double>>[
              for (final MealType meal in meals) MapEntry<Color, double>(meal.color, report.mealCalories[meal]!.toDouble()),
            ],
          ),
          const SizedBox(height: 12),
          for (final MealType meal in meals)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: meal.color.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(meal.icon, size: 16, color: meal.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meal.displayName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                    ),
                  ),
                  Text(
                    '${formatNumber(report.mealCalories[meal]! / daysLogged)} kcal',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${(report.mealCalories[meal]! * 100 / total).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary(isDark)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopFoodsCard extends StatelessWidget {
  const _TopFoodsCard({required this.foods});

  final List<FoodFrequency> foods;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InsightCard(
      title: 'Most logged foods',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < foods.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                key: Key('topFood_$i'),
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12) : AppColors.subtleFill(isDark),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? AppColors.brandText(isDark) : AppColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      foods[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(isDark)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${foods[i].timesLogged}×',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary(isDark)),
                      ),
                      Text(
                        '~${formatNumber(foods[i].averageCalories)} kcal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary(isDark)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.weight, required this.goal});

  final WeightProgress weight;
  final WeightGoal goal;

  String _projection(WeightUnit unit) {
    final String symbol = unit.displayName;
    if (weight.hasGoalProjection && weight.projectedGoalDate != null) {
      return 'At this pace you reach your goal around '
          '${DateFormat('MMM d, yyyy').format(weight.projectedGoalDate!)} (~${weight.projectedDaysToGoal} days).';
    }
    if (weight.remainingToGoalKg != null) {
      final String remaining =
          '${WeightUnit.kg.convertTo(weight.remainingToGoalKg!, unit).toStringAsFixed(1)} $symbol to goal';
      if (weight.trendKgPerWeek == null) {
        return '$remaining. Weigh in across at least a week to unlock a projection.';
      }
      return '$remaining. Your trend is not moving toward it yet.';
    }
    return 'Set a goal weight in the Weight tab to see a projected date.';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final WeightUnit unit = goal.unit;
    double inUnit(double kg) => WeightUnit.kg.convertTo(kg, unit);

    return InsightCard(
      title: 'Weight',
      subtitle: 'Last ${weight.windowDays} days',
      child: !weight.hasWeighIns
          ? Text(
              'No weigh-ins in the last ${weight.windowDays} days. Log your weight in the Weight tab to see your trend here.',
              key: const Key('weightEmptyText'),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary(isDark)),
            )
          : Column(
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: InsightStat(
                        label: 'Latest',
                        value: '${inUnit(weight.currentKg!).toStringAsFixed(1)} ${unit.displayName}',
                      ),
                    ),
                    Expanded(
                      child: InsightStat(
                        label: 'Change',
                        value: formatWeightChange(inUnit(weight.changeKg!), unit: unit.displayName),
                        valueKey: const Key('weightChangeText'),
                        caption: 'first to latest',
                      ),
                    ),
                    Expanded(
                      child: InsightStat(
                        label: 'Trend',
                        value: weight.trendKgPerWeek == null
                            ? '—'
                            : '${formatWeightChange(inUnit(weight.trendKgPerWeek!), unit: unit.displayName)}/wk',
                        valueKey: const Key('weightTrendText'),
                        caption: weight.trendKgPerWeek == null ? 'needs 7+ days' : '${weight.trendSampleDays} weigh-ins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: weight.hasGoalProjection
                        ? AppColors.success.withValues(alpha: isDark ? 0.14 : 0.08)
                        : AppColors.subtleFill(isDark),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        weight.hasGoalProjection ? Icons.flag_rounded : Icons.hourglass_empty_rounded,
                        size: 18,
                        color: weight.hasGoalProjection ? AppColors.success : AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _projection(unit),
                          key: const Key('goalProjectionText'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: weight.hasGoalProjection ? AppColors.brandText(isDark) : AppColors.textSecondary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.highlights});

  final List<InsightHighlight> highlights;

  static (IconData, Color) _style(InsightHighlightKind kind) {
    switch (kind) {
      case InsightHighlightKind.comparison:
        return (Icons.compare_arrows_rounded, AppColors.accent);
      case InsightHighlightKind.weekend:
        return (Icons.weekend_rounded, AppColors.carbs);
      case InsightHighlightKind.protein:
        return (Icons.fitness_center_rounded, AppColors.protein);
      case InsightHighlightKind.target:
        return (Icons.track_changes_rounded, AppColors.primaryLight);
      case InsightHighlightKind.meal:
        return (Icons.restaurant_rounded, AppColors.calories);
      case InsightHighlightKind.streak:
        return (Icons.local_fire_department_rounded, AppColors.streak);
      case InsightHighlightKind.consistency:
        return (Icons.edit_calendar_rounded, AppColors.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InsightCard(
      title: 'Highlights',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < highlights.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _style(highlights[i].kind).$2.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_style(highlights[i].kind).$1, size: 16, color: _style(highlights[i].kind).$2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        highlights[i].text,
                        style: TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500, color: AppColors.textPrimary(isDark)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
