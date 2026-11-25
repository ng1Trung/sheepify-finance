import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../../presentation/widgets/common/sheep_widgets.dart';

class AppTheme {
  static ThemeData getTheme(
    ColorPalette palette,
    bool isDarkMode,
    String fontFamily,
  ) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;
    final primary = palette.primary;
    final interactiveAccent = AppColors.getInteractiveAccent(
      brightness,
      primary,
    );
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
        case 'Be Vietnam Pro':
          return GoogleFonts.beVietnamProTextTheme(baseText);
        case 'Quicksand':
          return GoogleFonts.quicksandTextTheme(baseText);
        default:
          return GoogleFonts.interTextTheme(baseText);
      }
    }

    final baseTextTheme = resolveTextTheme(fontFamily);

    final outlineColor = AppColors.getBorder(brightness);
    final primaryFill = AppColors.getPrimaryFill(brightness);
    final onPrimaryFill = AppColors.getOnPrimaryFill(brightness);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SheepRadius.md),
    );
    final buttonText = baseTextTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: SheepTypeScale.bodyLarge,
      letterSpacing: 0,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      dividerColor: outlineColor,
      cardColor: surface,
      primaryColor: interactiveAccent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: interactiveAccent,
        secondary: const Color(0xFF757575),
        surface: surface,
        error: AppColors.expense,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: SheepTypeScale.headline,
          letterSpacing: 0,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: SheepTypeScale.headline,
          letterSpacing: 0,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600, // SemiBold
          fontSize: SheepTypeScale.title,
          letterSpacing: 0,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500, // Medium
          fontSize: SheepTypeScale.bodyLarge,
          letterSpacing: 0.5,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500, // Medium
          fontSize: SheepTypeScale.body,
          letterSpacing: 0.5,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          color: textSecondary,
          fontSize: SheepTypeScale.meta,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: SheepTypeScale.title,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryFill,
          foregroundColor: onPrimaryFill,
          elevation: 0,
          minimumSize: const Size.fromHeight(SheepControl.height),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryFill,
          foregroundColor: onPrimaryFill,
          minimumSize: const Size(64, SheepControl.height),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(64, SheepControl.height),
          side: BorderSide(color: outlineColor),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, SheepControl.height),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryFill,
        foregroundColor: onPrimaryFill,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        shape: const CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SheepRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SheepRadius.sheet),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: controlShape,
        iconColor: textSecondary,
        minVerticalPadding: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheepRadius.md),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheepRadius.md),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SheepRadius.md),
          borderSide: BorderSide(color: interactiveAccent, width: 1.5),
        ),
        labelStyle: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.getSubtleSurface(brightness),
        selectedColor: interactiveAccent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SheepRadius.md),
          side: BorderSide(color: outlineColor),
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
