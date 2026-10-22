import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accents (Emerald)
  static const Color primary = Color(0xFF0B8F63); // Emerald — fills & buttons (white text passes AA large)
  static const Color primaryLight = Color(0xFF16A877); // Brighter emerald for icons & accents
  static const Color primaryDark = Color(0xFF047857); // Deep emerald for text on light surfaces
  static const Color accent = Color(0xFF0F766E); // Teal — pairs with primary in subtle gradients
  static const Color brandGlow = Color(0xFF4ADE9F); // Mint highlight for text on dark surfaces

  // Macro Colors
  static const Color calories = Color(0xFFFF6B4A); // Vibrant Coral / Energy
  static const Color caloriesLight = Color(0xFFFF8A65);
  static const Color protein = Color(0xFF0EA5E9); // Ocean Blue / Cyan
  static const Color proteinDark = Color(0xFF0284C7);
  static const Color carbs = Color(0xFFF59E0B); // Amber / Gold
  static const Color carbsDark = Color(0xFFD97706);
  static const Color fat = Color(0xFFF43F5E); // Rose / Pink
  static const Color fatDark = Color(0xFFE11D48);

  // Secondary nutrients (fiber, sugar, sodium, saturated fat)
  static const Color fiber = Color(0xFF65A30D);
  static const Color sugar = Color(0xFFEC4899);
  static const Color sodium = Color(0xFF06B6D4);
  static const Color saturatedFat = Color(0xFFF97316);

  // Status & Utility
  static const Color success = Color(0xFF1F9D55);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color streak = Color(0xFFFF7A00);

  // Dark Theme (Deep forest charcoal)
  static const Color darkBackground = Color(0xFF0B1210);
  static const Color darkBackgroundGrad1 = Color(0xFF0F1915);
  static const Color darkBackgroundGrad2 = Color(0xFF08100D);
  static const Color darkSurface = Color(0xFF16211C);
  static const Color darkCard = Color(0xFF121C18);
  static const Color darkBorder = Color(0x17FFFFFF);
  static const Color darkTextPrimary = Color(0xFFECF3EF);
  static const Color darkTextSecondary = Color(0xFF93A59C);

  // Light Theme (Warm cream & linen)
  static const Color lightBackground = Color(0xFFF4F1E8);
  static const Color lightBackgroundGrad1 = Color(0xFFF8F6EF);
  static const Color lightBackgroundGrad2 = Color(0xFFEEEADF);
  static const Color lightSurface = Color(0xFFFBFAF5);
  static const Color lightCard = Color(0xFFFFFEFA);
  static const Color lightBorder = Color(0x1A2E3B33);
  static const Color lightTextPrimary = Color(0xFF1A221E);
  static const Color lightTextSecondary = Color(0xFF65716A);

  // Mode-aware shorthands for widgets that already know `isDark`.
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;

  /// Brand-colored text/icons that stay legible on both dark and cream surfaces.
  static Color brandText(bool isDark) => isDark ? brandGlow : primaryDark;

  /// Subtle neutral fill for inset areas (tracks, chips, wells).
  static Color subtleFill(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF2E3B33).withValues(alpha: 0.05);

  /// Soft drop shadow tuned per mode.
  static List<BoxShadow> cardShadow(bool isDark) => <BoxShadow>[
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.28) : const Color(0xFF3A4A3F).withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}

class AppTheme {
  static const String fontFamily = 'PlusJakartaSans';

  static ThemeData getTheme({required bool isDarkMode}) {
    final Brightness brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final Color textPrimary = AppColors.textPrimary(isDarkMode);
    final Color textSecondary = AppColors.textSecondary(isDarkMode);
    final Color border = AppColors.border(isDarkMode);

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      error: AppColors.error,
      surface: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border,
      surfaceContainerLowest: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      surfaceContainerHighest: isDarkMode ? const Color(0xFF1C2823) : const Color(0xFFEDE9DE),
    );

    final TextTheme baseText = (isDarkMode ? Typography.whiteMountainView : Typography.blackMountainView)
        .apply(fontFamily: fontFamily, bodyColor: textPrimary, displayColor: textPrimary);
    final TextTheme textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodySmall: baseText.bodySmall?.copyWith(color: textSecondary),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1),
    );

    TextStyle font(double size, FontWeight weight, {Color? color, double? letterSpacing}) => TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
        );

    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primaryLight,
        selectionColor: AppColors.primaryLight.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.primaryLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: font(20, FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card(isDarkMode),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.subtleFill(isDarkMode),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: font(14, FontWeight.w500, color: textSecondary.withValues(alpha: 0.75)),
        labelStyle: font(14, FontWeight.w500, color: textSecondary),
        floatingLabelStyle: font(14, FontWeight.w700, color: AppColors.brandText(isDarkMode)),
        helperStyle: font(12, FontWeight.w500, color: textSecondary),
        errorStyle: font(12, FontWeight.w600, color: AppColors.error),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: buttonShape,
          textStyle: font(15, FontWeight.w700, letterSpacing: 0.1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: buttonShape,
          textStyle: font(15, FontWeight.w700, letterSpacing: 0.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: isDarkMode ? Colors.white.withValues(alpha: 0.16) : const Color(0x332E3B33)),
          shape: buttonShape,
          textStyle: font(15, FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandText(isDarkMode),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: font(14, FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card(isDarkMode),
        selectedColor: AppColors.primary.withValues(alpha: isDarkMode ? 0.28 : 0.14),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: font(12, FontWeight.w600, color: textPrimary),
        secondaryLabelStyle: font(12, FontWeight.w700, color: AppColors.brandText(isDarkMode)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        checkmarkColor: AppColors.brandText(isDarkMode),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? Colors.white : (isDarkMode ? const Color(0xFF8A9A92) : Colors.white)),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : (isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFD9D4C7))),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? AppColors.primary : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearTrackColor: AppColors.subtleFill(isDarkMode),
        circularTrackColor: AppColors.subtleFill(isDarkMode),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryLight,
        thumbColor: AppColors.primaryLight,
        inactiveTrackColor: AppColors.subtleFill(isDarkMode),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        indicatorColor: AppColors.primaryLight,
        dividerColor: border,
        labelStyle: font(14, FontWeight.w700),
        unselectedLabelStyle: font(14, FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.primary.withValues(alpha: isDarkMode ? 0.3 : 0.14),
          selectedForegroundColor: AppColors.brandText(isDarkMode),
          side: BorderSide(color: border),
          textStyle: font(13, FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: isDarkMode ? 0.24 : 0.14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) => font(
              12,
              states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
              color: states.contains(WidgetState.selected) ? textPrimary : textSecondary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected) ? AppColors.brandText(isDarkMode) : textSecondary,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDarkMode ? const Color(0xFF1F2C26) : const Color(0xFF1A221E),
        contentTextStyle: font(14, FontWeight.w600, color: Colors.white),
        actionTextColor: AppColors.brandGlow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: font(19, FontWeight.w800, color: textPrimary, letterSpacing: -0.3),
        contentTextStyle: font(14, FontWeight.w500, color: textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border)),
        textStyle: font(14, FontWeight.w600, color: textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF26332D) : const Color(0xFF1A221E),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: font(12, FontWeight.w600, color: Colors.white),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        titleTextStyle: font(15, FontWeight.w700, color: textPrimary),
        subtitleTextStyle: font(12.5, FontWeight.w500, color: textSecondary),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        headerHeadlineStyle: font(26, FontWeight.w800, letterSpacing: -0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
