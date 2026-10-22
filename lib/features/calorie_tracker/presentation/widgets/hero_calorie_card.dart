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
    final int goal = trackerState.dailyGoal;
    final int consumed = trackerState.consumedCalories;
    final double rawProgress = goal <= 0 ? 0 : consumed / goal;
    final bool isOver = goal > 0 && consumed > goal;
    final int caloriePercent = (rawProgress * 100).round();
    final double spread = showSpreadDetails ? trackerState.averageSpreadPercent : 0;
    final int calLow =
        (consumed * (1 - trackerState.averageSpreadPercent)).round().clamp(0, 99999);
    final int calHigh =
        (consumed * (1 + trackerState.averageSpreadPercent)).round().clamp(0, 99999);
    final Color statusColor = isOver ? AppColors.calories : AppColors.primaryLight;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border(isDark)),
        boxShadow: AppColors.cardShadow(isDark),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: section label + targets
          Row(
            children: <Widget>[
              Text(
                'Daily goal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('editTargetsButton'),
                onPressed: onOpenTargetEditor,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Targets'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandText(isDark),
                  backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.09),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ring + totals
          Row(
            children: <Widget>[
              CalorieRing(
                key: const Key('calorieProgressBar'),
                progress: rawProgress,
                spread: spread,
                color: statusColor,
                size: 104,
                strokeWidth: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '$caloriePercent%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    Text(
                      'of goal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Eaten',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '$consumed',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                                color: AppColors.textPrimary(isDark),
                              ),
                            ),
                            TextSpan(
                              text: ' / $goal kcal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                        key: const Key('caloriesConsumedText'),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isOver ? AppColors.calories : AppColors.primary)
                            .withValues(alpha: isDark ? 0.16 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            isOver ? Icons.trending_up_rounded : Icons.flag_rounded,
                            size: 14,
                            color: isOver ? AppColors.calories : AppColors.brandText(isDark),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isOver
                                  ? '${consumed - goal} kcal over'
                                  : '${trackerState.remainingCalories} kcal remaining',
                              key: const Key('caloriesRemainingText'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isOver ? AppColors.calories : AppColors.brandText(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showSpreadDetails && trackerState.spreadSamples > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Calorie range: $calLow-$calHigh kcal',
                        key: const Key('calorieSpreadText'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.border(isDark)),
          const SizedBox(height: 14),

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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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

          if (showSpreadDetails && trackerState.spreadSamples > 0) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              key: const Key('spreadBanner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.insights_rounded, size: 18, color: AppColors.brandText(isDark)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Uncertainty bars use avg spread from ${trackerState.spreadSamples} logs: +/-${(trackerState.averageSpreadPercent * 100).round()}%.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 6),

          // Footer: range toggle + details link
          Row(
            children: <Widget>[
              SizedBox(
                width: 44,
                height: 30,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    key: const Key('toggleSpreadSwitch'),
                    value: showSpreadDetails,
                    onChanged: onToggleSpread,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => onToggleSpread(!showSpreadDetails),
                  child: Text(
                    'Estimate range',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ),
              if (onOpenDetailedNutrition != null)
                TextButton(
                  key: const Key('detailedNutritionButton'),
                  onPressed: onOpenDetailedNutrition,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandText(isDark),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Nutrition details'),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
