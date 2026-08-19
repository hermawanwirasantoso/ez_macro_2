import 'package:flutter/material.dart';

import '../../domain/tracker_state.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet displaying complete detailed nutritional breakdown for a day.
class DetailedNutritionModal extends StatelessWidget {
  const DetailedNutritionModal({
    super.key,
    required this.trackerState,
  });

  final CalorieTrackerState trackerState;

  static Future<void> show(
    BuildContext context, {
    required CalorieTrackerState trackerState,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          DetailedNutritionModal(trackerState: trackerState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int totalFat = trackerState.fatG;
    final int satFat = trackerState.saturatedFatG;
    final int totalCarbs = trackerState.carbsG;
    final int addedSugar = trackerState.addedSugarG;
    final int fiber = trackerState.fiberG;
    final int sodium = trackerState.sodiumMg;

    final int satFatPercent = totalFat > 0
        ? ((satFat / totalFat) * 100).round().clamp(0, 100)
        : 0;
    final int addedSugarPercent = totalCarbs > 0
        ? ((addedSugar / totalCarbs) * 100).round().clamp(0, 100)
        : 0;

    return Container(
      key: const Key('detailedNutritionSheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Detailed Nutrition',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      trackerState.formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('closeDetailedNutritionButton'),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: <Widget>[
                // Energy & Primary Macros Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Energy & Primary Macros',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            '${trackerState.consumedCalories} / ${trackerState.dailyGoal} kcal',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.calories,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _macroStatBox(
                              label: 'Protein',
                              value: '${trackerState.proteinG}g',
                              color: AppColors.protein,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _macroStatBox(
                              label: 'Carbs',
                              value: '${trackerState.carbsG}g',
                              color: AppColors.carbs,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _macroStatBox(
                              label: 'Total Fat',
                              value: '${trackerState.fatG}g',
                              color: AppColors.fat,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Additional Nutrition Section Header
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Additional Nutrition Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Additional Nutrition Grid / Cards
                _nutrientRowCard(
                  key: const Key('detailedSaturatedFatRow'),
                  name: 'Saturated Fat',
                  value: '$satFat g',
                  subtitle: totalFat > 0
                      ? '$satFatPercent% of total fat'
                      : 'Fat sub-component',
                  icon: Icons.water_drop_outlined,
                  color: const Color(0xFFF97316),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _nutrientRowCard(
                  key: const Key('detailedFiberRow'),
                  name: 'Dietary Fiber',
                  value: '$fiber g',
                  subtitle: 'Daily target ~25-30g recommended',
                  icon: Icons.grass_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _nutrientRowCard(
                  key: const Key('detailedAddedSugarRow'),
                  name: 'Added Sugar',
                  value: '$addedSugar g',
                  subtitle: totalCarbs > 0
                      ? '$addedSugarPercent% of total carbohydrates'
                      : 'Carbohydrate sub-component',
                  icon: Icons.cookie_outlined,
                  color: const Color(0xFFEC4899),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _nutrientRowCard(
                  key: const Key('detailedSodiumRow'),
                  name: 'Sodium',
                  value: '$sodium mg',
                  subtitle: sodium > 2300
                      ? 'Above 2,300 mg daily benchmark'
                      : 'Within 2,300 mg daily benchmark',
                  icon: Icons.grain_rounded,
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                ),

                const SizedBox(height: 18),

                // Logged Entries Breakdown
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Entries Breakdown (${trackerState.entries.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (trackerState.entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No food entries logged for this date.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...trackerState.entries.asMap().entries.map((
                    MapEntry<int, FoodLogEntry> entryMap,
                  ) {
                    final int idx = entryMap.key;
                    final FoodLogEntry entry = entryMap.value;
                    return Container(
                      key: Key('detailedEntryItem_$idx'),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  entry.mealLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.calories} kcal',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.calories,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: <Widget>[
                              _chipBadge('P: ${entry.proteinG}g', AppColors.protein),
                              _chipBadge('C: ${entry.carbsG}g', AppColors.carbs),
                              _chipBadge('F: ${entry.fatG}g', AppColors.fat),
                              if (entry.saturatedFatG > 0)
                                _chipBadge(
                                  'Sat Fat: ${entry.saturatedFatG}g',
                                  const Color(0xFFF97316),
                                ),
                              if (entry.fiberG > 0)
                                _chipBadge(
                                  'Fiber: ${entry.fiberG}g',
                                  const Color(0xFF10B981),
                                ),
                              if (entry.addedSugarG > 0)
                                _chipBadge(
                                  'Sugar: ${entry.addedSugarG}g',
                                  const Color(0xFFEC4899),
                                ),
                              if (entry.sodiumMg > 0)
                                _chipBadge(
                                  'Sodium: ${entry.sodiumMg}mg',
                                  const Color(0xFF06B6D4),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _macroStatBox({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _nutrientRowCard({
    required Key key,
    required String name,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _chipBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
