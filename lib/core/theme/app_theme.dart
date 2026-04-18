import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData getTheme(ColorPalette palette, bool isDarkMode, String fontFamily) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final primary = palette.primary;
    final background = AppColors.getBackground(brightness);
    final surface = AppColors.getSurface(brightness);
    final textPrimary = AppColors.getTextPrimary(brightness);
    final textSecondary = AppColors.getTextSecondary(brightness);

    final baseTheme = isDarkMode ? ThemeData.dark() : ThemeData.light();

    TextTheme resolveTextTheme(String font) {
      final baseText = baseTheme.textTheme;
      switch (font) {
        case 'Inter':
          return GoogleFonts.interTextTheme(baseText);
        case 'Montserrat':
          return GoogleFonts.montserratTextTheme(baseText);
        case 'Roboto':
          return GoogleFonts.robotoTextTheme(baseText);
        case 'Be Vietnam Pro':
          return GoogleFonts.beVietnamProTextTheme(baseText);
        case 'Comfortaa':
          return GoogleFonts.comfortaaTextTheme(baseText);
        case 'Lexend':
          return GoogleFonts.lexendTextTheme(baseText);
        case 'Bungee':
          return GoogleFonts.bungeeTextTheme(baseText);
        case 'Righteous':
          return GoogleFonts.righteousTextTheme(baseText);
        case 'Pacifico':
          return GoogleFonts.pacificoTextTheme(baseText);
        case 'Special Elite':
          return GoogleFonts.specialEliteTextTheme(baseText);
        case 'Quicksand':
        default:
          return GoogleFonts.quicksandTextTheme(baseText);
      }
    }

    final baseTextTheme = resolveTextTheme(fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: palette.secondary,
        surface: surface,
        error: AppColors.expense,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontSize: 14,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          color: textSecondary,
          fontSize: 12,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: textSecondary.withOpacity(0.2)),
        ),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: baseTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
