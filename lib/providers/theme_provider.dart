// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastor_report/utils/theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Color _primaryColor = AppTheme.primary;

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadFromPreferences();
  }

  // Load saved theme preferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? false;
      final colorValue = prefs.getInt('primaryColor');

      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      if (colorValue != null) {
        _primaryColor = Color(colorValue);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    }
  }

  // Toggle dark mode
  Future<void> toggleDarkMode(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
    } catch (e) {
      debugPrint('Error saving dark mode preference: $e');
    }
  }

  // Set primary color
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('primaryColor', color.toARGB32());
    } catch (e) {
      debugPrint('Error saving color preference: $e');
    }
  }

  // Get theme data based on mode
  ThemeData getThemeData() {
    if (_themeMode == ThemeMode.dark) {
      return _buildDarkTheme();
    }
    return _buildLightTheme();
  }

  ThemeData _buildLightTheme() {
    return AppTheme.lightTheme.copyWith(
      colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
        primary: _primaryColor,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return AppTheme.darkTheme.copyWith(
      colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
        primary: _primaryColor,
      ),
    );
  }
}
