import 'package:flutter/material.dart';

class ThemePreset {
  final String name;
  final Brightness brightness;
  final Color primary;
  final Color secondary;

  const ThemePreset({
    required this.name,
    required this.brightness,
    required this.primary,
    this.secondary = const Color(0xFF00B4D8),
  });
}

class AppColors {
  // Preset definitions
  static const List<ThemePreset> presets = [
    ThemePreset(name: 'Sheep Light', brightness: Brightness.light, primary: Color(0xFF20C997)),
    ThemePreset(name: 'Sheep Dark', brightness: Brightness.dark, primary: Color(0xFF20C997)),
    ThemePreset(name: 'Rose Petal', brightness: Brightness.light, primary: Color(0xFFFF85A1)),
    ThemePreset(name: 'Sunset Glow', brightness: Brightness.light, primary: Color(0xFFFF9E7D)),
    ThemePreset(name: 'Ruby Red', brightness: Brightness.light, primary: Color(0xFFEE6055)),
    ThemePreset(name: 'Golden Hour', brightness: Brightness.light, primary: Color(0xFFFFD97D)),
    ThemePreset(name: 'Deep Ocean', brightness: Brightness.light, primary: Color(0xFF4EA8DE)),
    ThemePreset(name: 'Lavender Night', brightness: Brightness.dark, primary: Color(0xFFB79CED)),
  ];

  static ThemePreset getPreset(String name) {
    return presets.firstWhere((p) => p.name == name, orElse: () => presets[0]);
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
  static Color getBackground(Brightness b) => b == Brightness.light ? bgLight : const Color(0xFF121212);
  static Color getSurface(Brightness b) => b == Brightness.light ? surfLight : const Color(0xFF1E1E1E);
  static Color getTextPrimary(Brightness b) => b == Brightness.light ? textPriLight : const Color(0xFFF1F1F1);
  static Color getTextSecondary(Brightness b) => b == Brightness.light ? textSecLight : const Color(0xFFABABAB);

  // Compatibility getters (proxies to methods, but might need context or brightness)
  // For static access without context, we default to Light.
  static Color get background => bgLight;
  static Color get surface => surfLight;
  static Color get textPrimary => textPriLight;
  static Color get textSecondary => textSecLight;

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
