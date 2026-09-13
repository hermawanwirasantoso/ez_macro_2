import 'package:flutter/material.dart';
import '../../domain/daily_log.dart';
import '../../domain/meal_type.dart';
import '../theme/app_theme.dart';

class RecentEntriesSection extends StatefulWidget {
  const RecentEntriesSection({
    super.key,
    required this.entries,
    required this.onRemoveEntry,
    this.onEditEntry,
    this.onLogAgain,
    this.onCopyDayToToday,
    this.onClearAll,
    this.selectedMealFilter,
  });

  final List<FoodLogEntry> entries;
  final ValueChanged<int> onRemoveEntry;
  final ValueChanged<int>? onEditEntry;
  final ValueChanged<int>? onLogAgain;
  final VoidCallback? onCopyDayToToday;
  final VoidCallback? onClearAll;
  final MealType? selectedMealFilter;

  @override
  State<RecentEntriesSection> createState() => _RecentEntriesSectionState();
}

class _RecentEntriesSectionState extends State<RecentEntriesSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String query = _searchQuery.trim().toLowerCase();
    final List<MapEntry<int, FoodLogEntry>> displayedEntries = widget.entries
        .asMap()
        .entries
        .where((MapEntry<int, FoodLogEntry> e) =>
            query.isEmpty || e.value.mealLabel.toLowerCase().contains(query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              widget.selectedMealFilter == null
                  ? 'Recent Entries'
                  : '${widget.selectedMealFilter!.displayName} Entries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (widget.entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  query.isEmpty
                      ? '${widget.entries.length}'
                      : '${displayedEntries.length}/${widget.entries.length}',
                  key: const Key('entriesCountBadge'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            const Spacer(),
            if (widget.entries.isNotEmpty && widget.onCopyDayToToday != null)
              TextButton.icon(
                key: const Key('copyDayToTodayButton'),
                onPressed: widget.onCopyDayToToday,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 16, color: AppColors.primary),
                label: const Text(
                  'Copy to Today',
                  style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            if (widget.entries.isNotEmpty && widget.onClearAll != null)
              TextButton.icon(
                key: const Key('clearAllEntriesButton'),
                onPressed: widget.onClearAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.clear_all, size: 16, color: AppColors.fat),
                label: const Text(
                  'Clear Day',
                  style: TextStyle(fontSize: 12, color: AppColors.fat, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.entries.length >= 3 || _searchQuery.isNotEmpty) ...<Widget>[
          TextField(
            key: const Key('searchEntriesInput'),
            controller: _searchController,
            onChanged: (String val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search logged meals...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const Key('clearSearchEntriesButton'),
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.entries.isEmpty)
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
                  widget.selectedMealFilter == null
                      ? 'No meals logged yet. Try: "100g chicken breast with broccoli"'
                      : 'No ${widget.selectedMealFilter!.displayName.toLowerCase()} meals logged yet.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else if (displayedEntries.isEmpty)
          Container(
            key: const Key('noMatchingRecentEntriesBox'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Center(
              child: Text(
                'No entries match "$_searchQuery"',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedEntries.length,
            separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final int originalIndex = displayedEntries[index].key;
              final FoodLogEntry entry = displayedEntries[index].value;
              final Color mealColor = entry.mealType.color;

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightBorder,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.15)
                          : const Color(0xFF5A4D3A).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    onTap: widget.onEditEntry != null ? () => widget.onEditEntry!(originalIndex) : null,
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
                          _miniMacroBadge(
                            entry.portionDisplay,
                            isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 4),
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
                        if (widget.onLogAgain != null)
                          IconButton(
                            key: Key('logAgainEntryButton_$originalIndex'),
                            onPressed: () => widget.onLogAgain!(originalIndex),
                            icon: const Icon(Icons.replay_rounded, size: 18, color: AppColors.success),
                            tooltip: 'Log again',
                          ),
                        if (widget.onEditEntry != null)
                          IconButton(
                            key: Key('editEntryButton_$originalIndex'),
                            onPressed: () => widget.onEditEntry!(originalIndex),
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                            tooltip: 'Edit entry',
                          ),
                        IconButton(
                          key: Key('removeEntryButton_$originalIndex'),
                          onPressed: () => widget.onRemoveEntry(originalIndex),
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
