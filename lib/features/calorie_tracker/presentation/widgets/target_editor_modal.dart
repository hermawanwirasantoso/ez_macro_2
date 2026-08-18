import 'package:flutter/material.dart';
import '../../domain/tracker_state.dart';
import '../theme/app_theme.dart';

class TargetEditorModal extends StatefulWidget {
  const TargetEditorModal({
    super.key,
    required this.trackerState,
  });

  final CalorieTrackerState trackerState;

  static Future<bool?> show(BuildContext context, CalorieTrackerState state) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => TargetEditorModal(trackerState: state),
    );
  }

  @override
  State<TargetEditorModal> createState() => _TargetEditorModalState();
}

class _TargetEditorModalState extends State<TargetEditorModal> {
  late final TextEditingController _calorieController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    _calorieController = TextEditingController(text: widget.trackerState.dailyGoal.toString());
    _proteinController = TextEditingController(text: widget.trackerState.targetProteinG.toString());
    _carbsController = TextEditingController(text: widget.trackerState.targetCarbsG.toString());
    _fatController = TextEditingController(text: widget.trackerState.targetFatG.toString());
  }

  void _applyMacroPreset(double pRatio, double cRatio, double fRatio) {
    final int cal = int.tryParse(_calorieController.text.trim()) ?? widget.trackerState.dailyGoal;
    final int pG = ((cal * pRatio) / 4).round();
    final int fG = ((cal * fRatio) / 9).round();
    final int cG = ((cal - (pG * 4) - (fG * 9)) / 4).round();

    setState(() {
      _proteinController.text = pG.toString();
      _carbsController.text = cG.toString();
      _fatController.text = fG.toString();
    });
  }

  @override
  void dispose() {
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Title & Subtitle
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Edit Daily Targets',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Customize your daily caloric and macronutrient goals',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Presets
            Text(
              'Preset Macro Splits',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ActionChip(
                  label: const Text('Balanced (30/40/30)'),
                  onPressed: () => _applyMacroPreset(0.30, 0.40, 0.30),
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                ActionChip(
                  label: const Text('High Protein (40/35/25)'),
                  onPressed: () => _applyMacroPreset(0.40, 0.35, 0.25),
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                ActionChip(
                  label: const Text('Low Carb (30/15/55)'),
                  onPressed: () => _applyMacroPreset(0.30, 0.15, 0.55),
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Daily Calories Field
            TextField(
              key: const Key('dailyCalorieTargetField'),
              controller: _calorieController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily calories target',
                prefixIcon: Icon(Icons.local_fire_department, color: AppColors.calories),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Macro Inputs Row (Protein, Carbs, Fat)
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('proteinTargetField'),
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('carbsTargetField'),
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Carbs (g)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('fatTargetField'),
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fat (g)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Explanation note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Calories are always enforced using 4/4/9 math. Carbs may auto-adjust.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Cancel / Save Buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('saveTargetsButton'),
                    onPressed: () {
                      final int calories =
                          int.tryParse(_calorieController.text.trim()) ??
                              widget.trackerState.dailyGoal;
                      final int protein =
                          int.tryParse(_proteinController.text.trim()) ??
                              widget.trackerState.targetProteinG;
                      final int carbs =
                          int.tryParse(_carbsController.text.trim()) ??
                              widget.trackerState.targetCarbsG;
                      final int fat = int.tryParse(_fatController.text.trim()) ??
                          widget.trackerState.targetFatG;

                      final bool wasAdjusted = widget.trackerState.updateTargets(
                        dailyGoal: calories,
                        proteinG: protein,
                        carbsG: carbs,
                        fatG: fat,
                      );

                      if (wasAdjusted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Carbs adjusted to ${widget.trackerState.targetCarbsG}g to match calorie math.',
                            ),
                          ),
                        );
                      }

                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Save Targets'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
