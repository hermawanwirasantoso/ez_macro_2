import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// App bar title: a brand-gradient icon tile followed by the page name.
class AppHeaderTitle extends StatelessWidget {
  const AppHeaderTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.primaryLight, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.6),
          ),
        ),
      ],
    );
  }
}

/// Square tonal icon button used in page headers.
class HeaderActionButton extends StatelessWidget {
  const HeaderActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconColor,
    this.child,
  }) : assert(icon != null || child != null);

  final String tooltip;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? iconColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.subtleFill(isDark),
          fixedSize: const Size(40, 40),
          minimumSize: const Size(40, 40),
          // The default 48dp tap target padding would squeeze the page title.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border(isDark)),
          ),
        ),
        icon: child ?? Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary(isDark)),
      ),
    );
  }
}
