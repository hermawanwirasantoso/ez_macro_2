import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/tracker_state.dart';
import '../theme/app_theme.dart';

class DateNavigationBar extends StatelessWidget {
  const DateNavigationBar({
    super.key,
    required this.trackerState,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onSelectDate,
    required this.onJumpToToday,
  });

  final CalorieTrackerState trackerState;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onJumpToToday;

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: trackerState.selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      builder: (BuildContext context, Widget? child) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primaryLight,
                    onPrimary: Colors.white,
                    surface: AppColors.darkSurface,
                    onSurface: AppColors.darkTextPrimary,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.lightSurface,
                    onSurface: AppColors.lightTextPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onSelectDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int streak = trackerState.streakDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                trackerState.isToday ? "Today's Calories" : trackerState.formattedDate,
                key: const Key('dateTitleText'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),
            if (streak > 0)
              Container(
                key: const Key('streakBadge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.streak.withValues(alpha: isDark ? 0.16 : 0.11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '$streak-day streak',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.streak,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            // Day stepper pill: ‹ date ›
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.card(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(isDark)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _StepperButton(
                    key: const Key('previousDayButton'),
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Previous day',
                    onTap: onPreviousDay,
                    isDark: isDark,
                  ),
                  InkWell(
                    key: const Key('selectDateButton'),
                    onTap: () => _pickDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.brandText(isDark)),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('EEE, MMM d').format(trackerState.selectedDate),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _StepperButton(
                    key: const Key('nextDayButton'),
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Next day',
                    onTap: onNextDay,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            if (!trackerState.isToday) ...<Widget>[
              const SizedBox(width: 8),
              InkWell(
                key: const Key('jumpToTodayButton'),
                onTap: onJumpToToday,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandText(isDark),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.textSecondary(isDark)),
        ),
      ),
    );
  }
}
