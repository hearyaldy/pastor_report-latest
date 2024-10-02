// lib/theme_manager.dart
import 'package:flutter/material.dart';

class ThemeManager {
  static final ValueNotifier<bool> isDarkTheme = ValueNotifier(false);

  // Custom MaterialColor for the primary swatch
  static const MaterialColor customLightSwatch = MaterialColor(
    0xFF1A4870, // Main color
    <int, Color>{
      50: Color(0xFFE3EAF2),
      100: Color(0xFFB8CCDF),
      200: Color(0xFF8AAACC),
      300: Color(0xFF5C88B9),
      400: Color(0xFF366FAC),
      500: Color(0xFF1A4870), // The primary color value
      600: Color(0xFF1A3E64),
      700: Color(0xFF163553),
      800: Color(0xFF142E46),
      900: Color(0xFF0F2032),
    },
  );

  static const MaterialColor customDarkSwatch = MaterialColor(
    0xFF1A487A,
    <int, Color>{
      50: Color(0xFFE3EAF2),
      100: Color(0xFFB8CCDF),
      200: Color(0xFF8AAACC),
      300: Color(0xFF5C88B9),
      400: Color(0xFF366FAC),
      500: Color(0xFF1A487A), // The primary color value
      600: Color(0xFF1A3E64),
      700: Color(0xFF163553),
      800: Color(0xFF142E46),
      900: Color(0xFF0F2032),
    },
  );

  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: customLightSwatch,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      primarySwatch: customDarkSwatch,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
    );
  }

  static ThemeData get currentTheme {
    return isDarkTheme.value ? darkTheme : lightTheme;
  }
}
