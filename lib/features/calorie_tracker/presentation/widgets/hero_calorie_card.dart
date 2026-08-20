import 'package:flutter/material.dart';
import '../../domain/tracker_state.dart';
import '../theme/app_theme.dart';
import 'macro_progress_widget.dart';

class HeroCalorieCard extends StatelessWidget {
  const HeroCalorieCard({
    super.key,
    required this.trackerState,
    required this.showSpreadDetails,
    required this.onToggleSpread,
    required this.onOpenTargetEditor,
    this.onOpenDetailedNutrition,
  });

  final CalorieTrackerState trackerState;
  final bool showSpreadDetails;
  final ValueChanged<bool> onToggleSpread;
  final VoidCallback onOpenTargetEditor;
  final VoidCallback? onOpenDetailedNutrition;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double calorieProgress = trackerState.dailyGoal <= 0
        ? 0
        : (trackerState.consumedCalories / trackerState.dailyGoal).clamp(0, 1).toDouble();
    final int caloriePercent = (calorieProgress * 100).round();
    final double spread = showSpreadDetails ? trackerState.averageSpreadPercent : 0;
    final int calLow =
        (trackerState.consumedCalories * (1 - trackerState.averageSpreadPercent))
            .round()
            .clamp(0, 99999);
    final int calHigh =
        (trackerState.consumedCalories * (1 + trackerState.averageSpreadPercent))
            .round()
            .clamp(0, 99999);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  const Color(0xFF1E293B).withValues(alpha: 0.9),
                  const Color(0xFF0F172A).withValues(alpha: 0.95),
                ]
              : const <Color>[
                  AppColors.lightCard,
                  AppColors.lightBackgroundGrad1,
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.12)
                : const Color(0xFF5A4D3A).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header Row: Consumed Text + Target Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${trackerState.consumedCalories} / ${trackerState.dailyGoal} kcal',
                        key: const Key('caloriesConsumedText'),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.calories.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 14,
                                  color: AppColors.calories,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${trackerState.remainingCalories} kcal remaining',
                                  key: const Key('caloriesRemainingText'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.calories,
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
                TextButton.icon(
                  key: const Key('editTargetsButton'),
                  onPressed: onOpenTargetEditor,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Targets'),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.08),
                    foregroundColor: isDark ? Colors.white : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            if (showSpreadDetails && trackerState.spreadSamples > 0) ...<Widget>[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Calorie range: $calLow-$calHigh kcal',
                  key: const Key('calorieSpreadText'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Uncertainty Spread Switch Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.bubble_chart_outlined,
                    size: 18,
                    color: showSpreadDetails
                        ? AppColors.primary
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Show uncertainty spread',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch.adaptive(
                      key: const Key('toggleSpreadSwitch'),
                      value: showSpreadDetails,
                      activeTrackColor: AppColors.primary,
                      onChanged: onToggleSpread,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Main Calorie Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Daily Energy Goal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      '$caloriePercent%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                UncertaintyProgressBar(
                  key: const Key('calorieProgressBar'),
                  progress: calorieProgress,
                  spread: spread,
                  color: AppColors.primary,
                  gradientColors: const <Color>[
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                  ],
                  minHeight: 12,
                ),
              ],
            ),

            if (showSpreadDetails && trackerState.spreadSamples > 0) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                key: const Key('spreadBanner'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.insights, size: 18, color: AppColors.primaryLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Uncertainty bars use avg spread from ${trackerState.spreadSamples} logs: +/-${(trackerState.averageSpreadPercent * 100).round()}%.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Macros Title
            Row(
              children: <Widget>[
                Text(
                  'Macronutrients',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                if (onOpenDetailedNutrition != null)
                  InkWell(
                    key: const Key('detailedNutritionButton'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: onOpenDetailedNutrition,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.analytics_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Detailed Nutrition',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    'Goal Balance',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // 3 Macro Progress Cards
            MacroCardItem(
              label: 'Protein',
              consumed: trackerState.proteinG,
              target: trackerState.targetProteinG,
              color: AppColors.protein,
              labelKey: const Key('proteinProgressLabel'),
              icon: Icons.fitness_center_rounded,
              showSpread: showSpreadDetails,
              averageSpread: trackerState.averageSpreadPercent,
            ),
            const SizedBox(height: 8),
            MacroCardItem(
              label: 'Carbs',
              consumed: trackerState.carbsG,
              target: trackerState.targetCarbsG,
              color: AppColors.carbs,
              labelKey: const Key('carbsProgressLabel'),
              icon: Icons.grain_rounded,
              showSpread: showSpreadDetails,
              averageSpread: trackerState.averageSpreadPercent,
            ),
            const SizedBox(height: 8),
            MacroCardItem(
              label: 'Fat',
              consumed: trackerState.fatG,
              target: trackerState.targetFatG,
              color: AppColors.fat,
              labelKey: const Key('fatProgressLabel'),
              icon: Icons.water_drop_rounded,
              showSpread: showSpreadDetails,
              averageSpread: trackerState.averageSpreadPercent,
            ),
          ],
        ),
      ),
    );
  }
}
