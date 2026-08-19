import 'package:flutter/material.dart';
import '../../domain/daily_log.dart';
import '../../domain/meal_type.dart';
import '../theme/app_theme.dart';

class RecentEntriesSection extends StatelessWidget {
  const RecentEntriesSection({
    super.key,
    required this.entries,
    required this.onRemoveEntry,
    this.onEditEntry,
    this.onClearAll,
    this.selectedMealFilter,
  });

  final List<FoodLogEntry> entries;
  final ValueChanged<int> onRemoveEntry;
  final ValueChanged<int>? onEditEntry;
  final VoidCallback? onClearAll;
  final MealType? selectedMealFilter;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              selectedMealFilter == null
                  ? 'Recent Entries'
                  : '${selectedMealFilter!.displayName} Entries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length}',
                  key: const Key('entriesCountBadge'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            const Spacer(),
            if (entries.isNotEmpty && onClearAll != null)
              TextButton.icon(
                key: const Key('clearAllEntriesButton'),
                onPressed: onClearAll,
                icon: const Icon(Icons.clear_all, size: 16, color: AppColors.fat),
                label: const Text(
                  'Clear Day',
                  style: TextStyle(fontSize: 12, color: AppColors.fat, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_outlined,
                    size: 28,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedMealFilter == null
                      ? 'No meals logged yet. Try: "100g chicken breast with broccoli"'
                      : 'No ${selectedMealFilter!.displayName.toLowerCase()} meals logged yet.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final FoodLogEntry entry = entries[index];
              final Color mealColor = entry.mealType.color;

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.15)
                          : const Color(0xFF64748B).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    onTap: onEditEntry != null ? () => onEditEntry!(index) : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: mealColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        entry.mealType.icon,
                        size: 20,
                        color: mealColor,
                      ),
                    ),
                    title: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            entry.displayText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: mealColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.mealType.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: mealColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: <Widget>[
                          _miniMacroBadge('P: ${entry.proteinG}g', AppColors.protein),
                          const SizedBox(width: 4),
                          _miniMacroBadge('C: ${entry.carbsG}g', AppColors.carbs),
                          const SizedBox(width: 4),
                          _miniMacroBadge('F: ${entry.fatG}g', AppColors.fat),
                          if (entry.sourceLabel != null && entry.sourceLabel!.isNotEmpty) ...<Widget>[
                            const SizedBox(width: 6),
                            Text(
                              entry.sourceLabel!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (onEditEntry != null)
                          IconButton(
                            key: Key('editEntryButton_$index'),
                            onPressed: () => onEditEntry!(index),
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'Edit entry',
                          ),
                        IconButton(
                          key: Key('removeEntryButton_$index'),
                          onPressed: () => onRemoveEntry(index),
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.fat),
                          tooltip: 'Remove entry',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _miniMacroBadge(String text, Color color) {
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
