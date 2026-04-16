import 'package:flutter/material.dart';

class AppColors {
  // Primary & Main Colors
  static const Color primary = Color(0xFF20C997); // Mint Green
  static const Color primaryLight = Color(0xFFE8FAF5);
  static const Color secondary = Color(0xFF00B4D8); // Soft Blue-Mint
  
  // Background & Surface
  static const Color background = Color(0xFFF8F9FA); // Off-white
  static const Color surface = Color(0xFFFFFFFF); // Pure white for cards
  
  // Status Colors
  static const Color expense = Color(0xFFFF6B6B); // Coral Red
  static const Color income = Color(0xFF20C997); // Same as primary
  static const Color savings = Color(0xFF3498DB); // Peter River Blue
  static const Color savingsLight = Color(0xFFE3F2FD);
  static const Color warning = Color(0xFFFFA07A); // Light Salmon
  
  // Text Colors
  static const Color textPrimary = Color(0xFF2B2D42); // Charcoal
  static const Color textSecondary = Color(0xFF8D99AE); // Light Grey
  static const Color textWhite = Colors.white;

  // Effects
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];
}
