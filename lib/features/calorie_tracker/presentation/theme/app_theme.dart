import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFF8B5CF6); // Purple

  // Macro Colors
  static const Color calories = Color(0xFFFF6B4A); // Vibrant Coral / Energy
  static const Color caloriesLight = Color(0xFFFF8A65);
  static const Color protein = Color(0xFF0EA5E9); // Ocean Blue / Cyan
  static const Color proteinDark = Color(0xFF0284C7);
  static const Color carbs = Color(0xFFF59E0B); // Amber / Gold
  static const Color carbsDark = Color(0xFFD97706);
  static const Color fat = Color(0xFFF43F5E); // Rose / Pink
  static const Color fatDark = Color(0xFFE11D48);

  // Status & Utility
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color streak = Color(0xFFFF7A00);

  // Dark Theme
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkBackgroundGrad1 = Color(0xFF0F172A);
  static const Color darkBackgroundGrad2 = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF161F36);
  static const Color darkCard = Color(0xFF131B2E);
  static const Color darkBorder = Color(0x1FFFFFFF);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme (Warm Yellowish White / Cozy Cream & Linen)
  static const Color lightBackground = Color(0xFFF4EFE6);
  static const Color lightBackgroundGrad1 = Color(0xFFFAF6EE);
  static const Color lightBackgroundGrad2 = Color(0xFFECE4D5);
  static const Color lightSurface = Color(0xFFFCFAF5);
  static const Color lightCard = Color(0xFFFFFDF8);
  static const Color lightBorder = Color(0x1A5C472E);
  static const Color lightTextPrimary = Color(0xFF26211B);
  static const Color lightTextSecondary = Color(0xFF70665B);
}

class AppTheme {
  static ThemeData getTheme({required bool isDarkMode}) {
    final Brightness brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerLowest: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        elevation: isDarkMode ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.35),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.8,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(
            color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
