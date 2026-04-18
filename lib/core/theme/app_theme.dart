import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData getTheme(ThemePreset preset, String fontFamily) {
    final brightness = preset.brightness;
    final primary = preset.primary;
    final background = AppColors.getBackground(brightness);
    final surface = AppColors.getSurface(brightness);
    final textPrimary = AppColors.getTextPrimary(brightness);
    final textSecondary = AppColors.getTextSecondary(brightness);

    TextTheme resolveTextTheme(String font) {
      switch (font) {
        case 'Inter':
          return GoogleFonts.interTextTheme();
        case 'Montserrat':
          return GoogleFonts.montserratTextTheme();
        case 'Roboto':
          return GoogleFonts.robotoTextTheme();
        case 'Be Vietnam Pro':
          return GoogleFonts.beVietnamProTextTheme();
        case 'Quicksand':
        default:
          return GoogleFonts.quicksandTextTheme();
      }
    }

    final baseTextTheme = resolveTextTheme(fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: preset.secondary,
        surface: surface,
        error: AppColors.expense,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 28,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontFamily: fontFamily,
        ),
        labelSmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontFamily: fontFamily,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: fontFamily,
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
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
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
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: textSecondary.withOpacity(0.2)),
        ),
        labelStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        secondaryLabelStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    );
  }
}
