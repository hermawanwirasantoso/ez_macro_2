import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../calorie_tracker/data/calorie_storage.dart';
import '../../calorie_tracker/domain/daily_log.dart';
import '../../calorie_tracker/domain/user_settings.dart';
import '../../calorie_tracker/presentation/theme/app_theme.dart';
import '../../recipes/data/recipe_storage.dart';
import '../../weight_tracker/data/weight_storage.dart';
import '../../weight_tracker/domain/weight_entry.dart';
import '../../weight_tracker/domain/weight_goal.dart';
import '../domain/backup_data.dart';
import 'widgets/insight_widgets.dart';
import 'widgets/insights_history_tab.dart';
import 'widgets/insights_overview_tab.dart';

class InsightsAndBackupModal extends StatefulWidget {
  const InsightsAndBackupModal({
    super.key,
    required this.calorieStorage,
    required this.weightStorage,
    RecipeStorage? recipeStorage,
    this.onDataRestored,
  }) : recipeStorage = recipeStorage ?? const PreferencesRecipeStorage();

  final CalorieStorage calorieStorage;
  final WeightStorage weightStorage;
  final RecipeStorage recipeStorage;
  final VoidCallback? onDataRestored;

  static Future<void> show(
    BuildContext context, {
    required CalorieStorage calorieStorage,
    required WeightStorage weightStorage,
    RecipeStorage? recipeStorage,
    VoidCallback? onDataRestored,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: InsightsAndBackupModal(
          calorieStorage: calorieStorage,
          weightStorage: weightStorage,
          recipeStorage: recipeStorage,
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
  List<DailyLog> _logs = const <DailyLog>[];
  List<WeightEntry> _weights = const <WeightEntry>[];
  UserSettings _settings = const UserSettings();
  WeightGoal _goal = const WeightGoal();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Shown inside the sheet; the app's own messenger sits behind it.
  void _showSnackBar(String message) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final List<DailyLog> logs = await widget.calorieStorage.loadAllLogs();
      final List<WeightEntry> weights = await widget.weightStorage.loadEntries();
      final UserSettings settings = await widget.calorieStorage.loadSettings();
      final WeightGoal goal = await widget.weightStorage.loadGoal();

      if (mounted) {
        setState(() {
          _logs = logs;
          _weights = weights;
          _settings = settings;
          _goal = goal;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _copyToClipboard(Future<String> Function() export, String message) async {
    final String text = await export();
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}
    _showSnackBar(message);
  }

  Future<void> _exportJsonBackup() => _copyToClipboard(
        () => BackupService.exportToJsonString(
          calorieStorage: widget.calorieStorage,
          weightStorage: widget.weightStorage,
          recipeStorage: widget.recipeStorage,
        ),
        '✅ Full Backup (JSON) copied to clipboard!',
      );

  Future<void> _exportNutritionCsv() => _copyToClipboard(
        () => BackupService.exportCaloriesCsv(calorieStorage: widget.calorieStorage),
        '✅ Nutrition CSV copied to clipboard!',
      );

  Future<void> _exportWeightCsv() => _copyToClipboard(
        () => BackupService.exportWeightCsv(weightStorage: widget.weightStorage),
        '✅ Weight History CSV copied to clipboard!',
      );

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
                            if (validatedData!.recipes.isNotEmpty)
                              Text('• Saved recipes: ${validatedData!.recipes.length}', style: const TextStyle(fontSize: 11)),
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
                            recipeStorage: widget.recipeStorage,
                            merge: true,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          await _loadData();
                          widget.onDataRestored?.call();
                          _showSnackBar('✅ Backup merged successfully!');
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
        recipeStorage: widget.recipeStorage,
      );
      await _loadData();
      widget.onDataRestored?.call();
      _showSnackBar('🗑️ All data cleared and reset.');
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
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary(isDark).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[AppColors.primaryLight, AppColors.accent],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Insights & Data',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppColors.textPrimary(isDark),
                              ),
                            ),
                            Text(
                              'Trends, history, and backups',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                TabBar(
                  controller: _tabController,
                  tabs: const <Widget>[
                    Tab(key: Key('overviewTab'), text: 'Overview'),
                    Tab(key: Key('historyTab'), text: 'History'),
                    Tab(key: Key('dataBackupTab'), text: 'Data'),
                  ],
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: <Widget>[
                            InsightsOverviewTab(
                              logs: _logs,
                              weightEntries: _weights,
                              settings: _settings,
                              goal: _goal,
                            ),
                            InsightsHistoryTab(logs: _logs),
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

  Widget _buildDataBackupTab(bool isDark) {
    final int daysLogged = _logs.where((DailyLog log) => log.entries.isNotEmpty).length;
    final TextStyle bodyStyle = TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary(isDark));

    return ListView(
      key: const Key('dataBackupScrollView'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        InsightCard(
          title: 'Full Database Backup (JSON)',
          subtitle: '$daysLogged days of food logs · ${_weights.length} weigh-ins',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'A complete, portable snapshot of your food logs, saved foods, recipes, weigh-ins, and targets. '
                'Copy it somewhere safe, then paste it back with Restore.',
                style: bodyStyle,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('exportJsonBackupButton'),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: const Text('Copy JSON'),
                      onPressed: _exportJsonBackup,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('restoreFromBackupButton'),
                      icon: const Icon(Icons.restore_page_rounded, size: 16),
                      label: const Text('Restore'),
                      onPressed: _showRestoreDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InsightCard(
          title: 'Spreadsheet Export (CSV)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Daily totals and weigh-ins for Excel, Google Sheets, or sharing with a coach.',
                style: bodyStyle,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('exportNutritionCsvButton'),
                      icon: const Icon(Icons.table_chart_rounded, size: 16),
                      label: const Text('Nutrition'),
                      onPressed: _exportNutritionCsv,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('exportWeightCsvButton'),
                      icon: const Icon(Icons.monitor_weight_outlined, size: 16),
                      label: const Text('Weight'),
                      onPressed: _exportWeightCsv,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Permanently reset all daily logs, saved foods, and weight records.',
                style: bodyStyle,
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
}
