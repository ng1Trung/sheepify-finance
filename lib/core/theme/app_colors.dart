import 'package:flutter/material.dart';

class ColorPalette {
  final String name;
  final Color primary;
  final Color secondary;

  const ColorPalette({
    required this.name,
    required this.primary,
    this.secondary = const Color(0xFF00B4D8),
  });
}

class AppColors {
  // Palette definitions
  static const List<ColorPalette> palettes = [
    ColorPalette(name: 'Sheep Green', primary: Color(0xFF20C997)),
    ColorPalette(name: 'Rose Petal', primary: Color(0xFFFF85A1)),
    ColorPalette(name: 'Sunset Glow', primary: Color(0xFFFF9E7D)),
    ColorPalette(name: 'Ruby Red', primary: Color(0xFFEE6055)),
    ColorPalette(name: 'Golden Hour', primary: Color(0xFFFFD97D)),
    ColorPalette(name: 'Deep Ocean', primary: Color(0xFF4EA8DE)),
    ColorPalette(name: 'Lavender Night', primary: Color(0xFFB79CED)),
  ];

  static ColorPalette getPalette(String name) {
    return palettes.firstWhere((p) => p.name == name, orElse: () => palettes[0]);
  }

  // Base Colors
  static const Color primary = Color(0xFF20C997);
  static const Color primaryLight = Color(0xFFE8FAF4);
  static const Color expense = Color(0xFFFF6B6B);
  static const Color income = Color(0xFF20C997);
  static const Color savings = Color(0xFF3498DB);
  
  // Backward compatibility constants (Light Mode defaults)
  static const Color bgLight = Color(0xFFF8F9FA);
  static const Color surfLight = Color(0xFFFFFFFF);
  static const Color textPriLight = Color(0xFF2B2D42);
  static const Color textSecLight = Color(0xFF8D99AE);

  // Dynamic Background & Surface
  static Color getBackground(Brightness b) => b == Brightness.light ? bgLight : const Color(0xFF0D0D0D);
  static Color getSurface(Brightness b) => b == Brightness.light ? surfLight : const Color(0xFF1A1A1A);
  static Color getTextPrimary(Brightness b) => b == Brightness.light ? textPriLight : const Color(0xFFFFFFFF);
  static Color getTextSecondary(Brightness b) => b == Brightness.light ? textSecLight : const Color(0xFFAAAAAA);

  // Effects
  static List<BoxShadow> getSoftShadow(Brightness b) => [
    BoxShadow(
      color: b == Brightness.light ? Colors.black.withOpacity(0.03) : Colors.black.withOpacity(0.2),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  // Static getter for backward compatibility
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];
}
