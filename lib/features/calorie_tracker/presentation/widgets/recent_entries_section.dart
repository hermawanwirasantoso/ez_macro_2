import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            Flexible(
              child: Text(
                widget.selectedMealFilter == null ? 'Food log' : widget.selectedMealFilter!.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.subtleFill(isDark),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  query.isEmpty
                      ? '${widget.entries.length}'
                      : '${displayedEntries.length}/${widget.entries.length}',
                  key: const Key('entriesCountBadge'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ),
            const Spacer(),
            if (widget.entries.isNotEmpty && widget.onCopyDayToToday != null)
              _HeaderTextAction(
                key: const Key('copyDayToTodayButton'),
                icon: Icons.copy_all_rounded,
                label: 'Copy to today',
                color: AppColors.brandText(isDark),
                onPressed: widget.onCopyDayToToday!,
              ),
            if (widget.entries.isNotEmpty && widget.onClearAll != null)
              _HeaderTextAction(
                key: const Key('clearAllEntriesButton'),
                icon: Icons.delete_sweep_outlined,
                label: 'Clear',
                color: AppColors.fat,
                onPressed: widget.onClearAll!,
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
              hintText: 'Search logged meals',
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const Key('clearSearchEntriesButton'),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      tooltip: 'Clear search',
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              fillColor: AppColors.card(isDark),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.card(isDark),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border(isDark)),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.ramen_dining_rounded, size: 28, color: AppColors.brandText(isDark)),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.selectedMealFilter == null
                      ? 'No meals logged yet. Try: "100g chicken breast with broccoli"'
                      : 'No ${widget.selectedMealFilter!.displayName.toLowerCase()} meals logged yet.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(isDark),
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
              color: AppColors.card(isDark),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border(isDark)),
            ),
            child: Center(
              child: Text(
                'No entries match "$_searchQuery"',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            key: const Key('recentEntriesList'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedEntries.length,
            separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final int originalIndex = displayedEntries[index].key;
              return _EntryCard(
                key: Key('entryTile_$originalIndex'),
                entry: displayedEntries[index].value,
                index: originalIndex,
                isDark: isDark,
                onEdit: widget.onEditEntry,
                onLogAgain: widget.onLogAgain,
                onRemove: widget.onRemoveEntry,
              );
            },
          ),
      ],
    );
  }
}

class _HeaderTextAction extends StatelessWidget {
  const _HeaderTextAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.isDark,
    required this.onRemove,
    this.onEdit,
    this.onLogAgain,
  });

  final FoodLogEntry entry;
  final int index;
  final bool isDark;
  final ValueChanged<int> onRemove;
  final ValueChanged<int>? onEdit;
  final ValueChanged<int>? onLogAgain;

  @override
  Widget build(BuildContext context) {
    final Color mealColor = entry.mealType.color;
    final List<String> meta = <String>[
      entry.mealType.displayName,
      DateFormat.Hm().format(entry.timestamp),
      entry.portionDisplay,
      if (entry.sourceLabel != null && entry.sourceLabel!.isNotEmpty) entry.sourceLabel!,
    ];

    return Material(
      color: AppColors.card(isDark),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onEdit != null ? () => onEdit!(index) : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: mealColor.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(entry.mealType.icon, size: 20, color: mealColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.mealLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          meta.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '${entry.calories}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        Text(
                          entry.rangeText != null && entry.rangeText!.isNotEmpty ? entry.rangeText! : 'kcal',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _macroPill('P ${entry.proteinG}g', AppColors.protein),
                  const SizedBox(width: 5),
                  _macroPill('C ${entry.carbsG}g', AppColors.carbs),
                  const SizedBox(width: 5),
                  _macroPill('F ${entry.fatG}g', AppColors.fat),
                  const Spacer(),
                  if (onLogAgain != null)
                    _EntryAction(
                      key: Key('logAgainEntryButton_$index'),
                      icon: Icons.replay_rounded,
                      tooltip: 'Log again',
                      color: AppColors.brandText(isDark),
                      onPressed: () => onLogAgain!(index),
                    ),
                  if (onEdit != null)
                    _EntryAction(
                      key: Key('editEntryButton_$index'),
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit entry',
                      color: AppColors.textSecondary(isDark),
                      onPressed: () => onEdit!(index),
                    ),
                  _EntryAction(
                    key: Key('removeEntryButton_$index'),
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Remove entry',
                    color: AppColors.fat,
                    onPressed: () => onRemove(index),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _EntryAction extends StatelessWidget {
  const _EntryAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 19, color: color),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
