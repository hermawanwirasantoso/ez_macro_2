import 'package:flutter/material.dart';

import '../data/weight_storage.dart';
import '../domain/weight_entry.dart';
import '../domain/weight_goal.dart';
import '../domain/weight_tracker_state.dart';
import '../domain/weight_unit.dart';
import 'widgets/weight_chart_widget.dart';
import 'widgets/weight_entry_modal.dart';
import 'widgets/weight_goal_modal.dart';
import '../../calorie_tracker/data/calorie_storage.dart';
import '../../calorie_tracker/presentation/theme/app_theme.dart';
import '../../insights/presentation/insights_and_backup_modal.dart';

class WeightTrackerPage extends StatefulWidget {
  const WeightTrackerPage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    WeightStorage? weightStorage,
    this.bottomNavigationBar,
  }) : weightStorage = weightStorage ?? const PreferencesWeightStorage();

  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final WeightStorage weightStorage;
  final Widget? bottomNavigationBar;

  @override
  State<WeightTrackerPage> createState() => _WeightTrackerPageState();
}

class _WeightTrackerPageState extends State<WeightTrackerPage> {
  late final WeightTrackerState _trackerState;

  @override
  void initState() {
    super.initState();
    _trackerState = WeightTrackerState(storage: widget.weightStorage);
    _loadData();
  }

  Future<void> _loadData() async {
    await _trackerState.initFromStorage();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openAddModal() async {
    final dynamic result = await WeightEntryModal.showAdd(
      context,
      defaultUnit: _trackerState.preferredUnit,
      defaultWeight: _trackerState.currentWeight,
    );

    if (result is WeightEntry && mounted) {
      await _trackerState.addEntry(result);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${result.displayWeight}.')),
      );
    }
  }

  Future<void> _openEditModal(WeightEntry entry) async {
    final dynamic result = await WeightEntryModal.showEdit(
      context,
      entry,
      defaultUnit: _trackerState.preferredUnit,
    );

    if (result == null || !mounted) return;

    if (result == 'delete') {
      await _trackerState.deleteEntry(entry.id);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weigh-in deleted.')),
      );
    } else if (result is WeightEntry) {
      await _trackerState.editEntry(result);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated to ${result.displayWeight}.')),
      );
    }
  }

  Future<void> _openGoalModal() async {
    final WeightGoal? updated = await WeightGoalModal.show(
      context,
      initialGoal: _trackerState.goal,
      latestWeight: _trackerState.currentWeight,
    );

    if (updated != null && mounted) {
      await _trackerState.setGoal(updated);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight goal updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.monitor_weight_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Weight Tracker',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const Key('openGoalModalButton'),
              onPressed: _openGoalModal,
              icon: const Icon(
                Icons.flag_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              tooltip: 'Configure Weight Goals',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const Key('openInsightsModalButtonWeightPage'),
              onPressed: () {
                InsightsAndBackupModal.show(
                  context,
                  calorieStorage: const PreferencesCalorieStorage(),
                  weightStorage: widget.weightStorage,
                  onDataRestored: () {
                    _loadData();
                  },
                );
              },
              icon: const Icon(
                Icons.auto_graph_rounded,
                size: 18,
                color: AppColors.primaryLight,
              ),
              tooltip: 'Weekly Insights & Backup',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const Key('toggleThemeButtonWeightPage'),
              onPressed: widget.onToggleTheme,
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: widget.isDarkMode ? Colors.amber : AppColors.primaryDark,
              ),
              tooltip: 'Toggle theme',
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const <Color>[
                    AppColors.darkBackgroundGrad1,
                    AppColors.darkBackground,
                    AppColors.darkBackgroundGrad2,
                  ]
                : const <Color>[
                    AppColors.lightBackgroundGrad1,
                    AppColors.lightBackground,
                    AppColors.lightBackgroundGrad2,
                  ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: <Widget>[
              // Hero Summary Card
              _buildHeroCard(isDark),
              const SizedBox(height: 14),

              // Trend Graph Card
              WeightChartWidget(
                      trackerState: _trackerState,
                      onSelectRange: (WeightTimeRange range) {
                        setState(() {
                          _trackerState.setRange(range);
                        });
                      },
                      onTapAdd: _openAddModal,
                    ),
                    const SizedBox(height: 14),

                    // Quick Log Action Button
                    FilledButton.icon(
                      key: const Key('quickLogWeightButton'),
                      onPressed: _openAddModal,
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('Log Weigh-in'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Weigh-in History List Section
                    _buildHistorySection(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isDark) {
    final WeightEntry? latest = _trackerState.latestEntry;
    final WeightUnit unit = _trackerState.preferredUnit;
    final double? delta = _trackerState.lastEntryDelta;
    final double? total = _trackerState.totalChange;
    final double? bmi = _trackerState.currentBmi;
    final String? bmiCat = _trackerState.bmiCategory;
    final WeightGoal goal = _trackerState.goal;
    final double progress = _trackerState.goalProgress;
    final double? remaining = _trackerState.remainingToGoal;

    return Card(
      key: const Key('heroWeightCard'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Subheader & Goal action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'CURRENT WEIGHT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                if (latest != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      latest.formattedDisplayDate,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Large Weight Display & Delta badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  latest != null
                      ? latest.weight.toStringAsFixed(1)
                      : '--',
                  key: const Key('currentWeightDisplay'),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  latest?.unit.displayName ?? unit.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
                const Spacer(),
                // Delta pill compared to previous weigh-in
                if (delta != null)
                  Container(
                    key: const Key('weightDeltaBadge'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (delta < 0 ? AppColors.success : AppColors.fat).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (delta < 0 ? AppColors.success : AppColors.fat).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          delta < 0 ? Icons.trending_down_rounded : (delta > 0 ? Icons.trending_up_rounded : Icons.trending_flat_rounded),
                          size: 16,
                          color: delta < 0 ? AppColors.success : AppColors.fat,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)} ${latest?.unit.displayName ?? unit.displayName}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: delta < 0 ? AppColors.success : AppColors.fat,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Goal Progress Bar & Metrics
            if (goal.hasGoal) ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Goal: ${goal.targetWeight!.toStringAsFixed(1)} ${goal.unit.displayName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    remaining != null
                        ? '${remaining.toStringAsFixed(1)} ${goal.unit.displayName} to go'
                        : '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  key: const Key('weightGoalProgressBar'),
                  value: progress,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Stat pills row (Total change, BMI, start weight)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildSummaryPill(
                    'Total Change',
                    total != null
                        ? '${total >= 0 ? "+" : ""}${total.toStringAsFixed(1)} ${latest?.unit.displayName ?? unit.displayName}'
                        : '--',
                    isDark,
                    color: total == null || total == 0
                        ? null
                        : (total < 0 ? AppColors.success : AppColors.fat),
                  ),
                  _buildSummaryPill(
                    'BMI',
                    bmi != null ? '${bmi.toStringAsFixed(1)} ($bmiCat)' : 'Set height',
                    isDark,
                    color: bmi != null ? AppColors.protein : null,
                  ),
                  _buildSummaryPill(
                    'Start Weight',
                    goal.startingWeight != null
                        ? '${goal.startingWeight!.toStringAsFixed(1)} ${goal.unit.displayName}'
                        : (_trackerState.entries.isNotEmpty
                            ? '${_trackerState.entries.last.weight.toStringAsFixed(1)} ${_trackerState.entries.last.unit.displayName}'
                            : '--'),
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPill(String label, String value, bool isDark, {Color? color}) {
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
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(bool isDark) {
    final List<WeightEntry> entries = _trackerState.entries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Weigh-in History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              '${entries.length} recorded',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Text(
              'No weigh-ins recorded yet.\nTap "+ Log Weigh-in" to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final WeightEntry entry = entries[index];
              // Calculate delta relative to the entry logged chronologically before this one
              double? prevDelta;
              if (index < entries.length - 1) {
                final WeightEntry prev = entries[index + 1];
                final double prevConverted = prev.unit.convertTo(prev.weight, entry.unit);
                prevDelta = entry.weight - prevConverted;
              }

              return Dismissible(
                key: Key('dismissible_${entry.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: AppColors.fat.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) {
                  _trackerState.deleteEntry(entry.id);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Weigh-in removed.')),
                  );
                },
                child: Card(
                  key: Key('weightEntryTile_${entry.id}'),
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openEditModal(entry),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          // Icon container
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.scale_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Date & note
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.formattedDisplayDate,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: <Widget>[
                                    if (entry.note != null && entry.note!.isNotEmpty) ...<Widget>[
                                      Flexible(
                                        child: Text(
                                          entry.note!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (entry.bodyFatPercentage != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.protein.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          '${entry.bodyFatPercentage!.toStringAsFixed(1)}% BF',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.protein,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Weight and delta
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                entry.displayWeight,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (prevDelta != null)
                                Text(
                                  '${prevDelta >= 0 ? "+" : ""}${prevDelta.toStringAsFixed(1)} ${entry.unit.displayName}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: prevDelta == 0
                                        ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                                        : (prevDelta < 0 ? AppColors.success : AppColors.fat),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
