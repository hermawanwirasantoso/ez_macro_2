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

          final String title = type == null ? 'All Meals' : type.displayName;
          final IconData icon = type == null ? Icons.all_inclusive_rounded : type.icon;
          final Color categoryColor = type == null ? AppColors.primary : type.color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              key: Key('mealFilter_${type?.name ?? "all"}'),
              onTap: () => onSelectFilter(type),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? categoryColor.withValues(alpha: isDark ? 0.25 : 0.15)
                      : (isDark ? AppColors.darkCard : AppColors.lightCard),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? categoryColor
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected
                          ? categoryColor
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? (isDark ? Colors.white : categoryColor)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? categoryColor.withValues(alpha: 0.2)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$calories',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark ? Colors.white : categoryColor)
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
