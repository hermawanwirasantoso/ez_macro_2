import 'package:flutter/material.dart';

import '../../domain/weight_goal.dart';
import '../../domain/weight_unit.dart';
import '../../../calorie_tracker/presentation/theme/app_theme.dart';

class WeightGoalModal extends StatefulWidget {
  const WeightGoalModal({
    super.key,
    required this.initialGoal,
    this.latestWeight,
  });

  final WeightGoal initialGoal;
  final double? latestWeight;

  static Future<WeightGoal?> show(
    BuildContext context, {
    required WeightGoal initialGoal,
    double? latestWeight,
  }) {
    return showModalBottomSheet<WeightGoal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => WeightGoalModal(
        initialGoal: initialGoal,
        latestWeight: latestWeight,
      ),
    );
  }

  @override
  State<WeightGoalModal> createState() => _WeightGoalModalState();
}

class _WeightGoalModalState extends State<WeightGoalModal> {
  late final TextEditingController _targetWeightController;
  late final TextEditingController _startingWeightController;
  late final TextEditingController _heightController;
  late WeightUnit _unit;

  @override
  void initState() {
    super.initState();
    final WeightGoal goal = widget.initialGoal;
    _unit = goal.unit;

    _targetWeightController = TextEditingController(
      text: goal.targetWeight != null
          ? goal.targetWeight!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')
          : '',
    );

    _startingWeightController = TextEditingController(
      text: goal.startingWeight != null
          ? goal.startingWeight!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')
          : (widget.latestWeight != null
              ? widget.latestWeight!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')
              : ''),
    );

    _heightController = TextEditingController(
      text: goal.heightCm != null
          ? goal.heightCm!.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')
          : '',
    );
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    _startingWeightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _onSave() {
    final double? target = double.tryParse(_targetWeightController.text.trim());
    final double? starting = double.tryParse(_startingWeightController.text.trim());
    final double? height = double.tryParse(_heightController.text.trim());

    final WeightGoal updated = WeightGoal(
      targetWeight: (target != null && target > 0) ? target : null,
      startingWeight: (starting != null && starting > 0) ? starting : null,
      unit: _unit,
      heightCm: (height != null && height > 0) ? height : null,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final EdgeInsets bottomInsets = MediaQuery.of(context).viewInsets;

    final double? target = double.tryParse(_targetWeightController.text.trim());
    final double? start = double.tryParse(_startingWeightController.text.trim());
    final double? height = double.tryParse(_heightController.text.trim());

    String? goalInsight;
    if (target != null && start != null && target > 0 && start > 0) {
      final double diff = target - start;
      if (diff < -0.05) {
        goalInsight = 'Goal: Lose ${(-diff).toStringAsFixed(1)} ${_unit.displayName}';
      } else if (diff > 0.05) {
        goalInsight = 'Goal: Gain ${diff.toStringAsFixed(1)} ${_unit.displayName}';
      } else {
        goalInsight = 'Goal: Maintain weight';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.flag_rounded,
                      size: 20,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Weight Goals & Metrics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                // Preferred unit toggle
                SegmentedButton<WeightUnit>(
                  segments: const <ButtonSegment<WeightUnit>>[
                    ButtonSegment<WeightUnit>(value: WeightUnit.kg, label: Text('kg')),
                    ButtonSegment<WeightUnit>(value: WeightUnit.lbs, label: Text('lbs')),
                  ],
                  selected: <WeightUnit>{_unit},
                  onSelectionChanged: (Set<WeightUnit> newSelection) {
                    setState(() {
                      _unit = newSelection.first;
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Target Weight
            TextField(
              key: const Key('targetWeightInputField'),
              controller: _targetWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Target Weight',
                suffixText: _unit.displayName,
                prefixIcon: const Icon(Icons.track_changes_rounded),
                hintText: 'e.g. 70.0',
              ),
            ),
            const SizedBox(height: 14),

            // Starting Reference Weight
            TextField(
              key: const Key('startingWeightInputField'),
              controller: _startingWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Starting Reference Weight',
                suffixText: _unit.displayName,
                prefixIcon: const Icon(Icons.play_circle_outline_rounded),
                hintText: 'e.g. 76.5',
              ),
            ),
            const SizedBox(height: 14),

            // Height for BMI tracking
            TextField(
              key: const Key('heightInputField'),
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Height (cm) for BMI Calculation',
                suffixText: 'cm',
                prefixIcon: Icon(Icons.height_rounded),
                hintText: 'e.g. 178',
              ),
            ),
            const SizedBox(height: 16),

            // Goal Insight Banner
            if (goalInsight != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.insights_rounded, size: 18, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        goalInsight,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Save Button
            FilledButton.icon(
              key: const Key('saveGoalButton'),
              onPressed: _onSave,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save Settings & Goal'),
            ),
          ],
        ),
      ),
    );
  }
}
