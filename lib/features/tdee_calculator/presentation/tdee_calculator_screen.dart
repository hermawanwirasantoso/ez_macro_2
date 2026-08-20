import 'package:flutter/material.dart';
import '../../calorie_tracker/data/calorie_storage.dart';
import '../../calorie_tracker/domain/user_settings.dart';
import '../../calorie_tracker/presentation/theme/app_theme.dart';
import '../../weight_tracker/data/weight_storage.dart';
import '../../weight_tracker/domain/weight_entry.dart';
import '../../weight_tracker/domain/weight_goal.dart';
import '../../weight_tracker/domain/weight_unit.dart';
import '../domain/tdee_calculator.dart';
import '../domain/tdee_models.dart';

class TdeeCalculatorScreen extends StatefulWidget {
  const TdeeCalculatorScreen({
    super.key,
    this.calorieStorage,
    this.weightStorage,
    this.onComplete,
    this.isModal = false,
    this.initialWeightKg,
    this.initialHeightCm,
    this.isDarkMode = true,
  });

  final CalorieStorage? calorieStorage;
  final WeightStorage? weightStorage;
  final VoidCallback? onComplete;
  final bool isModal;
  final double? initialWeightKg;
  final double? initialHeightCm;
  final bool isDarkMode;

  static Future<TdeeCalculationResult?> showAsModal(
    BuildContext context, {
    double? initialWeightKg,
    double? initialHeightCm,
  }) {
    return showModalBottomSheet<TdeeCalculationResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: TdeeCalculatorScreen(
          isModal: true,
          initialWeightKg: initialWeightKg,
          initialHeightCm: initialHeightCm,
        ),
      ),
    );
  }

  @override
  State<TdeeCalculatorScreen> createState() => _TdeeCalculatorScreenState();
}

class _TdeeCalculatorScreenState extends State<TdeeCalculatorScreen> {
  BiologicalSex _sex = BiologicalSex.male;
  int _age = 25;

  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  WeightUnit _weightUnit = WeightUnit.kg;
  ActivityLevel _activityLevel = ActivityLevel.moderate;
  FitnessGoal _goal = FitnessGoal.cut;
  MacroSplitPreference _macroSplit = MacroSplitPreference.highProtein;

  @override
  void initState() {
    super.initState();
    final double initialWeight = widget.initialWeightKg ?? 75.0;
    final double initialHeight = widget.initialHeightCm ?? 175.0;

    _heightController = TextEditingController(text: initialHeight.toStringAsFixed(0));
    _weightController = TextEditingController(text: initialWeight.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double get _currentWeightKg {
    final double raw = double.tryParse(_weightController.text.trim()) ?? 75.0;
    if (_weightUnit == WeightUnit.lbs) {
      return raw * 0.45359237;
    }
    return raw;
  }

  double get _currentHeightCm {
    return double.tryParse(_heightController.text.trim()) ?? 175.0;
  }

  TdeeCalculationResult get _calculatedResult {
    return TdeeCalculator.calculate(
      sex: _sex,
      weightKg: _currentWeightKg,
      heightCm: _currentHeightCm,
      ageYears: _age,
      activityLevel: _activityLevel,
      goal: _goal,
      macroSplit: _macroSplit,
    );
  }

  Future<void> _applyAndSave() async {
    final TdeeCalculationResult result = _calculatedResult;
    final double weightKg = _currentWeightKg;
    final double heightCm = _currentHeightCm;

    if (widget.calorieStorage != null) {
      final UserSettings current = await widget.calorieStorage!.loadSettings();
      await widget.calorieStorage!.saveSettings(
        current.copyWith(
          dailyGoal: result.targetCalories,
          targetProteinG: result.proteinGrams,
          targetCarbsG: result.carbsGrams,
          targetFatG: result.fatGrams,
          hasCompletedOnboarding: true,
        ),
      );
    }

    if (widget.weightStorage != null) {
      // Save starting goal and initial entry
      final WeightGoal? existingGoal = await widget.weightStorage!.loadGoal();
      final double targetWeightKg = _goal == FitnessGoal.cut
          ? (weightKg - 5.0).clamp(30.0, 300.0)
          : (_goal == FitnessGoal.bulk ? weightKg + 5.0 : weightKg);

      await widget.weightStorage!.saveGoal(
        WeightGoal(
          targetWeight: targetWeightKg,
          startingWeight: weightKg,
          heightCm: heightCm,
          unit: _weightUnit,
        ),
      );

      final List<WeightEntry> entries = await widget.weightStorage!.loadEntries();
      if (entries.isEmpty) {
        await widget.weightStorage!.saveEntry(
          WeightEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            weight: weightKg,
            unit: _weightUnit,
            date: DateTime.now(),
            note: 'Initial weigh-in from TDEE Setup',
          ),
        );
      }
    }

    if (widget.isModal) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } else if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  Future<void> _skipOnboarding() async {
    if (widget.calorieStorage != null) {
      final UserSettings current = await widget.calorieStorage!.loadSettings();
      await widget.calorieStorage!.saveSettings(
        current.copyWith(hasCompletedOnboarding: true),
      );
    }

    if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark || widget.isDarkMode;
    final TdeeCalculationResult result = _calculatedResult;

    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackgroundGrad1 : AppColors.lightBackgroundGrad1,
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.zero,
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Drag handle for modal
            if (widget.isModal) ...<Widget>[
              const SizedBox(height: 12),
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
            ],

            // App Bar / Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                    child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '⚡ Quick TDEE & Macro Setup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '4 quick questions to personalize your daily targets',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isModal)
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),

            // Scrollable 4-Question Form + Live Result
            Expanded(
              child: ListView(
                key: const Key('tdeeCalculatorScrollView'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: <Widget>[
                  // Question 1: Biological Profile
                  _buildCard(
                    isDark: isDark,
                    title: '1. Biological Profile',
                    child: Row(
                      children: <Widget>[
                        // Sex Selector
                        Expanded(
                          flex: 3,
                          child: SegmentedButton<BiologicalSex>(
                            key: const Key('tdeeSexSegmentedButton'),
                            segments: const <ButtonSegment<BiologicalSex>>[
                              ButtonSegment<BiologicalSex>(
                                value: BiologicalSex.male,
                                label: Text('Male ♂'),
                              ),
                              ButtonSegment<BiologicalSex>(
                                value: BiologicalSex.female,
                                label: Text('Female ♀'),
                              ),
                            ],
                            selected: <BiologicalSex>{_sex},
                            onSelectionChanged: (Set<BiologicalSex> newSelection) {
                              setState(() {
                                _sex = newSelection.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Age Stepper
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                InkWell(
                                  key: const Key('decrementAgeButton'),
                                  onTap: () {
                                    if (_age > 14) {
                                      setState(() => _age--);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.remove, size: 16),
                                  ),
                                ),
                                Column(
                                  children: <Widget>[
                                    Text(
                                      '$_age',
                                      key: const Key('ageDisplayValue'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'yrs',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  key: const Key('incrementAgeButton'),
                                  onTap: () {
                                    if (_age < 99) {
                                      setState(() => _age++);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.add, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Question 2: Body Stats
                  _buildCard(
                    isDark: isDark,
                    title: '2. Body Stats',
                    child: Row(
                      children: <Widget>[
                        // Height Field
                        Expanded(
                          child: TextFormField(
                            key: const Key('tdeeHeightField'),
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Height',
                              suffixText: 'cm',
                              prefixIcon: const Icon(Icons.height_rounded, size: 18),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Weight Field
                        Expanded(
                          child: TextFormField(
                            key: const Key('tdeeWeightField'),
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Weight',
                              suffixText: _weightUnit.symbol,
                              prefixIcon: const Icon(Icons.monitor_weight_outlined, size: 18),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Question 3: Daily Activity Level
                  _buildCard(
                    isDark: isDark,
                    title: '3. Daily Activity Level',
                    child: Column(
                      children: ActivityLevel.values.take(4).map((ActivityLevel level) {
                        final bool isSelected = _activityLevel == level;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            key: Key('activityLevelOption_${level.name}'),
                            onTap: () => setState(() => _activityLevel = level),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Text(level.emoji, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          level.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? AppColors.primaryLight
                                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                          ),
                                        ),
                                        Text(
                                          level.description,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight, size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Question 4: Primary Goal
                  _buildCard(
                    isDark: isDark,
                    title: '4. Primary Goal',
                    child: Row(
                      children: FitnessGoal.values.map((FitnessGoal goal) {
                        final bool isSelected = _goal == goal;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              key: Key('fitnessGoalOption_${goal.name}'),
                              onTap: () => setState(() => _goal = goal),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                                      : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Text(goal.emoji, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(height: 6),
                                    Text(
                                      goal.title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.primaryLight
                                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      goal.calorieAdjustment == 0
                                          ? '0 kcal'
                                          : (goal.calorieAdjustment > 0
                                              ? '+${goal.calorieAdjustment} kcal'
                                              : '${goal.calorieAdjustment} kcal'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primaryLight
                                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 5: Live Result & Macro Distribution Card
                  Container(
                    key: const Key('tdeeResultCard'),
                    padding: const EdgeInsets.all(18),
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
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.3),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'YOUR PERSONALIZED TARGET',
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
                                'BMI ${result.bmi} • ${result.bmiCategory}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Big Target Calorie Number
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              '${result.targetCalories}',
                              key: const Key('tdeeCalculatedCaloriesText'),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'kcal / day',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // BMR & Maintenance Info
                        Text(
                          'BMR: ${result.bmr} kcal  •  Maintenance (TDEE): ${result.tdee} kcal',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Macro Breakdown Pill Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 8,
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  flex: (result.proteinCalories / result.targetCalories * 100).round(),
                                  child: Container(color: AppColors.protein),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  flex: (result.carbsCalories / result.targetCalories * 100).round(),
                                  child: Container(color: AppColors.carbs),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  flex: (result.fatCalories / result.targetCalories * 100).round(),
                                  child: Container(color: AppColors.fat),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Macro Details Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            _buildMacroMetric('Protein', '${result.proteinGrams}g', AppColors.protein),
                            _buildMacroMetric('Carbs', '${result.carbsGrams}g', AppColors.carbs),
                            _buildMacroMetric('Fat', '${result.fatGrams}g', AppColors.fat),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Macro Split Preset Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: MacroSplitPreference.values.map((MacroSplitPreference split) {
                              final bool isSelected = _macroSplit == split;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  key: Key('macroSplitChip_${split.name}'),
                                  selected: isSelected,
                                  label: Text(
                                    split.title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  onSelected: (bool selected) {
                                    if (selected) {
                                      setState(() => _macroSplit = split);
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  FilledButton(
                    key: const Key('applyTdeeTargetsButton'),
                    onPressed: _applyAndSave,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.check_circle_outline_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '⚡ Apply & Start Tracking',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),

                  if (!widget.isModal) ...<Widget>[
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        key: const Key('skipTdeeOnboardingButton'),
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip & Use Defaults (2,200 kcal)',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isModal) {
      return content;
    }

    return Scaffold(body: content);
  }

  Widget _buildCard({
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

  Widget _buildMacroMetric(String label, String value, Color color) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
