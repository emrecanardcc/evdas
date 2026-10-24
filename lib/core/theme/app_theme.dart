import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'customization_models.dart';

class AppTheme {
  static ThemeData get lightTheme => buildTheme(
        type: AppThemeType.light,
        accentColor: AppColors.primary,
        font: AppFontFamily.plusJakartaSans,
      );

  static ThemeData get darkTheme => buildTheme(
        type: AppThemeType.slateDark,
        accentColor: AppColors.primary,
        font: AppFontFamily.plusJakartaSans,
      );

  static ThemeData buildTheme({
    required AppThemeType type,
    required Color accentColor,
    required AppFontFamily font,
  }) {
    final isAmoled = type == AppThemeType.amoledDark;
    final isLight = type == AppThemeType.light;
    final isDark = !isLight;

    // Renk Tanımları
    final bgColor = isLight
        ? AppColors.backgroundLight
        : isAmoled
            ? Colors.black // AMOLED Saf Siyah (#000000)
            : AppColors.backgroundDark; // Slate Gece

    final surfaceColor = isLight
        ? AppColors.surfaceLight
        : isAmoled
            ? const Color(0xFF0F0F0F) // Saf Siyah Kart Arka Planı
            : AppColors.surfaceDark;

    final elevatedColor = isLight
        ? AppColors.surfaceElevatedLight
        : isAmoled
            ? const Color(0xFF171717)
            : AppColors.surfaceElevatedDark;

    final borderColor = isLight
        ? AppColors.borderLight
        : isAmoled
            ? const Color(0xFF262626)
            : AppColors.borderDark;

    final textPrimary = isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark;
    final textSecondary = isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark;

    String? fontFamilyName;
    try {
      fontFamilyName = GoogleFonts.getFont(font.displayName).fontFamily;
    } catch (_) {
      fontFamilyName = font.displayName;
    }

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamilyName,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: accentColor,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accentColor,
        onPrimary: Colors.white,
        secondary: accentColor.withValues(alpha: 0.8),
        onSecondary: Colors.white,
        error: AppColors.negative,
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: textPrimary,
        outline: borderColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        indicatorColor: accentColor.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: surfaceColor,
        elevation: 10,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
