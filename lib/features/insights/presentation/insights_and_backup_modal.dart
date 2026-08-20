import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../calorie_tracker/data/calorie_storage.dart';
import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/user_settings.dart';
import '../../calorie_tracker/presentation/theme/app_theme.dart';
import '../../weight_tracker/data/weight_storage.dart';
import '../../weight_tracker/domain/weight_entry.dart';
import '../domain/backup_data.dart';
import '../domain/weekly_insights.dart';

class InsightsAndBackupModal extends StatefulWidget {
  const InsightsAndBackupModal({
    super.key,
    required this.calorieStorage,
    required this.weightStorage,
    this.onDataRestored,
  });

  final CalorieStorage calorieStorage;
  final WeightStorage weightStorage;
  final VoidCallback? onDataRestored;

  static Future<void> show(
    BuildContext context, {
    required CalorieStorage calorieStorage,
    required WeightStorage weightStorage,
    VoidCallback? onDataRestored,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => FractionallySizedBox(
        heightFactor: 0.90,
        child: InsightsAndBackupModal(
          calorieStorage: calorieStorage,
          weightStorage: weightStorage,
          onDataRestored: onDataRestored,
        ),
      ),
    );
  }

  @override
  State<InsightsAndBackupModal> createState() => _InsightsAndBackupModalState();
}

class _InsightsAndBackupModalState extends State<InsightsAndBackupModal>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  late final TabController _tabController;
  WeeklyInsights? _insights;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInsights();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);
    try {
      final List<DailyLog> logs = await widget.calorieStorage.loadAllLogs();
      final List<WeightEntry> weights = await widget.weightStorage.loadEntries();
      final UserSettings settings = await widget.calorieStorage.loadSettings();
      final int streak = await widget.calorieStorage.calculateStreak();

      final WeeklyInsights insights = WeeklyInsightsCalculator.compute(
        logs: logs,
        weightEntries: weights,
        settings: settings,
        streak: streak,
      );

      if (mounted) {
        setState(() {
          _insights = insights;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportJsonBackup() async {
    final String jsonStr = await BackupService.exportToJsonString(
      calorieStorage: widget.calorieStorage,
      weightStorage: widget.weightStorage,
    );

    if (!mounted) return;

    try {
      await Clipboard.setData(ClipboardData(text: jsonStr));
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Full Backup (JSON) copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportNutritionCsv() async {
    final String csvStr = await BackupService.exportCaloriesCsv(
      calorieStorage: widget.calorieStorage,
    );

    if (!mounted) return;

    try {
      await Clipboard.setData(ClipboardData(text: csvStr));
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Nutrition CSV copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportWeightCsv() async {
    final String csvStr = await BackupService.exportWeightCsv(
      weightStorage: widget.weightStorage,
    );

    if (!mounted) return;

    try {
      await Clipboard.setData(ClipboardData(text: csvStr));
    } catch (_) {}

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Weight History CSV copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showRestoreDialog() async {
    final TextEditingController textController = TextEditingController();
    BackupData? validatedData;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setDialogState) {
            return AlertDialog(
              title: const Row(
                children: <Widget>[
                  Icon(Icons.restore_page_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Restore from Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Paste your EZ Macro JSON backup string below:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('restoreJsonInput'),
                      controller: textController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: '{\n  "version": 1,\n  "settings": { ... }\n}',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (String value) {
                        final BackupData? parsed = BackupService.validateAndParse(value);
                        setDialogState(() {
                          if (value.trim().isEmpty) {
                            validatedData = null;
                            errorText = null;
                          } else if (parsed == null) {
                            validatedData = null;
                            errorText = 'Invalid backup format or corrupt JSON.';
                          } else {
                            validatedData = parsed;
                            errorText = null;
                          }
                        });
                      },
                    ),
                    if (validatedData != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('✅ Valid Backup Found:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('• Daily food logs: ${validatedData!.dailyLogs.length}', style: const TextStyle(fontSize: 11)),
                            Text('• Saved custom foods: ${validatedData!.savedFoods.length}', style: const TextStyle(fontSize: 11)),
                            Text('• Weight logs: ${validatedData!.weightEntries.length}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('confirmRestoreMergeButton'),
                  onPressed: validatedData == null
                      ? null
                      : () async {
                          await BackupService.restoreData(
                            data: validatedData!,
                            calorieStorage: widget.calorieStorage,
                            weightStorage: widget.weightStorage,
                            merge: true,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          await _loadInsights();
                          widget.onDataRestored?.call();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Backup merged successfully!')),
                            );
                          }
                        },
                  child: const Text('Merge Restore'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showClearAllConfirmation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Clear All App Data?'),
          content: const Text(
            'This will permanently delete all daily food logs, weight entries, custom foods, and reset all goals.\n\nMake sure to export a backup first!',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirmClearAllButton'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear Everything'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await BackupService.clearAllData(
        calorieStorage: widget.calorieStorage,
        weightStorage: widget.weightStorage,
      );
      await _loadInsights();
      widget.onDataRestored?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ All data cleared and reset.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackgroundGrad1 : AppColors.lightBackgroundGrad1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 12),
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header Title Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[AppColors.primary, AppColors.accent],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Insights & Data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Weekly review, progress analytics, and backups',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  tabs: const <Widget>[
                    Tab(
                      key: Key('weeklyInsightsTab'),
                      icon: Icon(Icons.insights_rounded, size: 20),
                      text: 'Weekly Insights',
                    ),
                    Tab(
                      key: Key('dataBackupTab'),
                      icon: Icon(Icons.backup_table_rounded, size: 20),
                      text: 'Data & Backup',
                    ),
                  ],
                ),

                // Tab Views
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            _buildWeeklyInsightsTab(isDark),
                            _buildDataBackupTab(isDark),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyInsightsTab(bool isDark) {
    final WeeklyInsights insights = _insights ??
        const WeeklyInsights(
          daysLogged: 0,
          totalDays: 7,
          totalCaloriesConsumed: 0,
          averageDailyCalories: 0,
          targetDailyCalories: 2200,
          netCalorieDelta: 0,
          averageProteinG: 0,
          averageCarbsG: 0,
          averageFatG: 0,
          proteinAdherencePercent: 0,
          startWeightKg: null,
          currentWeightKg: null,
          actualWeightDeltaKg: null,
          estimatedWeightDeltaKg: 0.0,
          streak: 0,
          insightBadges: <InsightBadge>[],
        );

    return ListView(
      key: const Key('weeklyInsightsScrollView'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // Hero 7-Day Performance Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? <Color>[
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.darkCard,
                    ]
                  : <Color>[
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.lightCard,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    '7-DAY PERFORMANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${insights.daysLogged}/7 Days Logged',
                      key: const Key('daysLoggedBadgeText'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            '${insights.averageDailyCalories}',
                            key: const Key('avgDailyCaloriesText'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'kcal/day avg',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Target: ${insights.targetDailyCalories} kcal',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Net Deficit / Surplus pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: insights.netCalorieDelta <= 0
                          ? AppColors.carbs.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: insights.netCalorieDelta <= 0
                            ? AppColors.carbs.withValues(alpha: 0.4)
                            : AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          insights.netCalorieDelta == 0
                              ? '0 kcal'
                              : (insights.netCalorieDelta > 0
                                  ? '+${insights.netCalorieDelta} kcal'
                                  : '${insights.netCalorieDelta} kcal'),
                          key: const Key('netCalorieDeltaText'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: insights.netCalorieDelta <= 0 ? AppColors.carbs : AppColors.primaryLight,
                          ),
                        ),
                        Text(
                          insights.netCalorieDelta <= 0 ? 'Net Deficit' : 'Net Surplus',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Weight Correlation Card
        _buildSectionCard(
          isDark: isDark,
          title: 'Weight vs Calorie Trend',
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Estimated Fat Change', style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${insights.estimatedWeightDeltaKg > 0 ? "+" : ""}${insights.estimatedWeightDeltaKg} kg',
                      key: const Key('estimatedWeightDeltaText'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: insights.estimatedWeightDeltaKg <= 0 ? AppColors.carbs : AppColors.primaryLight,
                      ),
                    ),
                    const Text('from net calorie math', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Actual Scale Delta', style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      insights.actualWeightDeltaKg != null
                          ? '${insights.actualWeightDeltaKg! > 0 ? "+" : ""}${insights.actualWeightDeltaKg} kg'
                          : 'No weigh-in',
                      key: const Key('actualScaleDeltaText'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: (insights.actualWeightDeltaKg ?? 0) <= 0 ? AppColors.carbs : AppColors.primaryLight,
                      ),
                    ),
                    const Text('7-day scale trend', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Macro Daily Averages Card
        _buildSectionCard(
          isDark: isDark,
          title: 'Daily Macro Averages',
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildMacroStat('Protein', '${insights.averageProteinG}g', AppColors.protein),
                  _buildMacroStat('Carbs', '${insights.averageCarbsG}g', AppColors.carbs),
                  _buildMacroStat('Fat', '${insights.averageFatG}g', AppColors.fat),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.protein),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Protein adherence: ${insights.proteinAdherencePercent}% of logged days',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Smart Badges
        if (insights.insightBadges.isNotEmpty) ...<Widget>[
          _buildSectionCard(
            isDark: isDark,
            title: 'Weekly Achievements & Insights',
            child: Column(
              children: insights.insightBadges.map((InsightBadge badge) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(badge.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              badge.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              badge.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDataBackupTab(bool isDark) {
    return ListView(
      key: const Key('dataBackupScrollView'),
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // JSON Full Backup Card
        _buildSectionCard(
          isDark: isDark,
          title: 'Full Database Backup (JSON)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Exports a complete, portable snapshot containing all food logs, custom saved foods, weigh-ins, and target settings.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('exportJsonBackupButton'),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: const Text('Copy JSON Backup'),
                      onPressed: _exportJsonBackup,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('restoreFromBackupButton'),
                      icon: const Icon(Icons.restore_page_rounded, size: 16),
                      label: const Text('Restore Backup'),
                      onPressed: _showRestoreDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // CSV Spreadsheets Card
        _buildSectionCard(
          isDark: isDark,
          title: 'Spreadsheet Export (CSV)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Export clean spreadsheet files for Microsoft Excel, Google Sheets, or sharing with a coach.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('exportNutritionCsvButton'),
                      icon: const Icon(Icons.table_chart_rounded, size: 16),
                      label: const Text('Nutrition CSV'),
                      onPressed: _exportNutritionCsv,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('exportWeightCsvButton'),
                      icon: const Icon(Icons.monitor_weight_outlined, size: 16),
                      label: const Text('Weight CSV'),
                      onPressed: _exportWeightCsv,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Clear All Data
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Danger Zone',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Permanently reset all daily logs, saved foods, and weight records.',
                style: TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('clearAllDataButton'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text('Clear All Data'),
                onPressed: _showClearAllConfirmation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, Color color) {
    return Column(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
