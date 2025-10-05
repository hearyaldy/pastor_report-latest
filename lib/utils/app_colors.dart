// lib/utils/app_colors.dart
import 'package:flutter/material.dart';

// Extension to add the withValues method to Color class
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromARGB(
      alpha != null ? (alpha * 255).round() : this.alpha,
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
    );
  }
}

/// Class containing color constants used throughout the app
class AppColors {
  // Primary colors
  static const Color primaryLight = Color(0xFF3F51B5); // Indigo
  static const Color primaryDark = Color(0xFF303F9F);
  static const Color accent = Color(0xFFFF4081);

  // Neutral colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFBDBDBD);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Chart colors
  static final List<Color> chartColors = [
    const Color(0xFF3F51B5), // Indigo
    const Color(0xFF009688), // Teal
    const Color(0xFFE91E63), // Pink
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF795548), // Brown
    const Color(0xFF607D8B), // Blue grey
  ];
}
