// lib/utils/theme_helper.dart
import 'package:flutter/material.dart';

/// Helper extension to get theme-aware colors
extension ThemeHelper on BuildContext {
  /// Get the current theme's background color
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;

  /// Get the current theme's surface color (for cards, etc.)
  Color get surfaceColor => Theme.of(this).colorScheme.surface;

  /// Get the current theme's primary color
  Color get primaryColor => Theme.of(this).colorScheme.primary;

  /// Get the current theme's text color
  Color get textColor => Theme.of(this).colorScheme.onSurface;

  /// Get the current theme's secondary text color
  Color get secondaryTextColor => Theme.of(this).textTheme.bodySmall?.color ?? Colors.grey;

  /// Check if currently in dark mode
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Get divider color
  Color get dividerColor => Theme.of(this).dividerColor;

  /// Get card color
  Color get cardColor => Theme.of(this).cardTheme.color ?? surfaceColor;

  /// Get inverse surface color (opposite of current surface)
  Color get inverseSurface {
    return isDarkMode ? Colors.white : Colors.black;
  }

  /// Get theme-aware white (white in light, dark surface in dark)
  Color get adaptiveWhite {
    return isDarkMode ? surfaceColor : Colors.white;
  }

  /// Get theme-aware black (black in light, white in dark)
  Color get adaptiveBlack {
    return isDarkMode ? Colors.white : Colors.black;
  }

  /// Get contrasting color for overlays
  Color get overlayColor {
    return isDarkMode
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);
  }
}

/// Mixin to add theme-aware colors to StatefulWidget States
mixin ThemeAwareMixin<T extends StatefulWidget> on State<T> {
  Color get backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(context).colorScheme.surface;
  Color get primaryColor => Theme.of(context).colorScheme.primary;
  Color get textColor => Theme.of(context).colorScheme.onSurface;
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get cardColor => Theme.of(context).cardTheme.color ?? surfaceColor;
}
