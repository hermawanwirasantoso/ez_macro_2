import 'package:flutter/material.dart';
import '../../domain/tracker_state.dart';
import '../theme/app_theme.dart';

class MealCategoryTabs extends StatelessWidget {
  const MealCategoryTabs({
    super.key,
    required this.trackerState,
    required this.selectedFilter,
    required this.onSelectFilter,
  });

  final CalorieTrackerState trackerState;
  final MealType? selectedFilter;
  final ValueChanged<MealType?> onSelectFilter;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<MealType?> filters = <MealType?>[
      null,
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((MealType? type) {
          final bool isSelected = selectedFilter == type;
          final int calories = type == null
              ? trackerState.consumedCalories
              : trackerState.caloriesForMealType(type);

          final String title = type == null ? 'All meals' : type.displayName;
          final IconData icon = type == null ? Icons.restaurant_rounded : type.icon;
          final Color categoryColor = type == null ? AppColors.primaryLight : type.color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('mealFilter_${type?.name ?? "all"}'),
                onTap: () => onSelectFilter(type),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? categoryColor.withValues(alpha: isDark ? 0.2 : 0.13)
                        : AppColors.card(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? categoryColor.withValues(alpha: 0.55) : AppColors.border(isDark),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? categoryColor : AppColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.textPrimary(isDark) : AppColors.textSecondary(isDark),
                        ),
                      ),
                      if (calories > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        Text(
                          '$calories',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? categoryColor : AppColors.textSecondary(isDark).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
