import 'package:flutter/material.dart';

/// Theme-aware color helper for consistent color usage across light and dark modes.
///
/// Usage:
/// ```dart
/// // Get colors from context
/// final colors = context.colors;
///
/// // Use semantic colors
/// Container(
///   color: colors.primary,
///   child: Text('Hello', style: TextStyle(color: colors.onPrimary)),
/// )
///
/// // Use type-specific colors
/// Container(
///   color: colors.appointmentBackground,
///   child: Icon(Icons.calendar, color: colors.appointmentForeground),
/// )
/// ```
extension AppThemeColors on BuildContext {
  /// Get the theme-aware color palette
  ThemeColorPalette get colors => ThemeColorPalette(this);
}

class ThemeColorPalette {
  final BuildContext context;

  ThemeColorPalette(this.context);

  // ===== Core Theme Colors =====

  /// Primary brand color - adapts to theme
  /// Light: #1A4870 (Navy), Dark: #5B99C2 (Sky Blue)
  Color get primary => Theme.of(context).colorScheme.primary;

  /// Color to use on primary color (text/icons)
  Color get onPrimary => Theme.of(context).colorScheme.onPrimary;

  /// Darker/lighter variant of primary
  Color get primaryContainer => Theme.of(context).colorScheme.primaryContainer;

  /// Color to use on primary container
  Color get onPrimaryContainer => Theme.of(context).colorScheme.onPrimaryContainer;
  
  /// Darker variant of primary color
  Color get primaryDark => isDarkMode 
      ? const Color(0xFF2D5F8D) 
      : const Color(0xFF0F2C47);

  /// Background color for search fields
  Color get searchFieldBackground => isDarkMode
      ? const Color(0xFF2D2D2D)
      : const Color(0xFFFFFFFF);

  /// Shadow color for elevated elements
  Color get shadowColor => isDarkMode
      ? const Color(0xFF000000)
      : const Color(0xFF000000);

  /// Secondary accent color
  Color get secondary => Theme.of(context).colorScheme.secondary;

  /// Color to use on secondary color
  Color get onSecondary => Theme.of(context).colorScheme.onSecondary;

  /// Surface color (cards, sheets, etc.)
  /// Light: #FFFFFF, Dark: #1E1E1E
  Color get surface => Theme.of(context).colorScheme.surface;

  /// Color to use on surface
  Color get onSurface => Theme.of(context).colorScheme.onSurface;

  /// Background color for screens
  /// Light: #F5F7FA, Dark: #121212
  Color get background => Theme.of(context).colorScheme.surfaceContainerHighest;

  /// Outline/border color
  /// Light: #ECF0F1, Dark: #424242
  Color get outline => Theme.of(context).colorScheme.outline;

  // ===== Text Colors =====

  /// Primary text color
  /// Light: #2C3E50, Dark: #E1E1E1
  Color get textPrimary => Theme.of(context).colorScheme.onSurface;

  /// Secondary/muted text color
  /// Light: #7F8C8D, Dark: #B0B0B0
  Color get textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  /// Tertiary/very muted text color
  Color get textTertiary => isDarkMode
      ? const Color(0xFF808080)
      : const Color(0xFF95A5A6);

  /// Disabled text color
  Color get textDisabled => isDarkMode
      ? const Color(0xFF606060)
      : const Color(0xFFBDC3C7);

  // ===== Icon Colors =====

  /// Default icon color
  Color get iconPrimary => Theme.of(context).iconTheme.color ?? primary;

  /// Secondary/muted icon color
  Color get iconSecondary => textSecondary;

  /// Disabled icon color
  Color get iconDisabled => textDisabled;

  // ===== Status Colors =====

  /// Error color
  Color get error => Theme.of(context).colorScheme.error;

  /// Success color
  Color get success => isDarkMode
      ? const Color(0xFF4CAF50)
      : const Color(0xFF27AE60);

  /// Warning color
  Color get warning => isDarkMode
      ? const Color(0xFFFFB74D)
      : const Color(0xFFF39C12);

  /// Info color
  Color get info => isDarkMode
      ? const Color(0xFF64B5F6)
      : const Color(0xFF3498DB);

  // ===== Semantic Type Colors =====

  /// Appointment background color
  /// Light: Orange 100, Dark: Orange 900
  Color get appointmentBackground => isDarkMode
      ? const Color(0xFF4D2600)  // Orange 900
      : const Color(0xFFFFE0B2);  // Orange 100

  /// Appointment foreground color (text/icons)
  /// Light: Orange 700, Dark: Orange 300
  Color get appointmentForeground => isDarkMode
      ? const Color(0xFFFFB74D)  // Orange 300
      : const Color(0xFFF57C00);  // Orange 700

  /// Event background color
  /// Light: Indigo 100, Dark: Indigo 900
  Color get eventBackground => isDarkMode
      ? const Color(0xFF1A237E)  // Indigo 900
      : const Color(0xFFC5CAE9);  // Indigo 100

  /// Event foreground color (text/icons)
  /// Light: Indigo 700, Dark: Indigo 300
  Color get eventForeground => isDarkMode
      ? const Color(0xFF9FA8DA)  // Indigo 300
      : const Color(0xFF303F9F);  // Indigo 700

  /// Todo/task background color
  /// Light: Blue 50, Dark: Blue 900
  Color get todoBackground => isDarkMode
      ? const Color(0xFF0D47A1)  // Blue 900
      : const Color(0xFFE3F2FD);  // Blue 50

  /// Todo/task foreground color
  /// Light: Blue 700, Dark: Blue 300
  Color get todoForeground => isDarkMode
      ? const Color(0xFF64B5F6)  // Blue 300
      : const Color(0xFF1976D2);  // Blue 700

  /// Activity background color
  /// Light: Green 50, Dark: Green 900
  Color get activityBackground => isDarkMode
      ? const Color(0xFF1B5E20)  // Green 900
      : const Color(0xFFE8F5E9);  // Green 50

  /// Activity foreground color
  /// Light: Green 700, Dark: Green 300
  Color get activityForeground => isDarkMode
      ? const Color(0xFF81C784)  // Green 300
      : const Color(0xFF388E3C);  // Green 700

  // ===== Empty State Colors =====

  /// Empty state icon color
  Color get emptyStateIcon => isDarkMode
      ? const Color(0xFF505050)
      : const Color(0xFFBDC3C7);

  /// Empty state text color
  Color get emptyStateText => textSecondary;

  // ===== Divider Colors =====

  /// Standard divider color
  Color get divider => Theme.of(context).dividerTheme.color ?? outline;

  // ===== Card Colors =====

  /// Card background
  Color get cardBackground => surface;

  /// Card border
  Color get cardBorder => isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : outline;

  // ===== Gradient Colors =====

  /// Primary gradient colors
  List<Color> get primaryGradient => isDarkMode
      ? [
          const Color(0xFF5B99C2),  // Sky Blue
          const Color(0xFF2D5F8D),  // Mid Blue
        ]
      : [
          const Color(0xFF1A4870),  // Navy
          const Color(0xFF0F2C47),  // Dark Navy
        ];

  /// Accent gradient colors
  List<Color> get accentGradient => isDarkMode
      ? [
          const Color(0xFF7DB3D5),  // Light Sky
          const Color(0xFF5B99C2),  // Sky Blue
        ]
      : [
          const Color(0xFF5B99C2),  // Sky Blue
          const Color(0xFF7DB3D5),  // Light Sky
        ];

  // ===== Utility Methods =====

  /// Check if current theme is dark mode
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  /// Check if current theme is light mode
  bool get isLightMode => !isDarkMode;

  /// Get adaptive color based on theme
  /// Returns lightColor for light mode, darkColor for dark mode
  Color adaptive({required Color light, required Color dark}) {
    return isDarkMode ? dark : light;
  }

  /// Get appropriate text color for a given background color
  /// Returns white for dark backgrounds, dark for light backgrounds
  Color onColor(Color backgroundColor) {
    // Calculate relative luminance
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Create a semi-transparent version of a color
  Color withAlpha(Color color, double alpha) {
    return color.withValues(alpha: alpha);
  }

  /// Get a lighter or darker shade of a color based on theme
  /// In light mode: returns darker shade
  /// In dark mode: returns lighter shade
  Color shade(Color color, {double amount = 0.2}) {
    if (isDarkMode) {
      // Lighten for dark mode
      return Color.lerp(color, Colors.white, amount)!;
    } else {
      // Darken for light mode
      return Color.lerp(color, Colors.black, amount)!;
    }
  }
}

/// Mixin to add color helpers to StatefulWidget states
mixin ThemeColorsMixin<T extends StatefulWidget> on State<T> {
  ThemeColorPalette get colors => context.colors;
  bool get isDarkMode => colors.isDarkMode;
  bool get isLightMode => colors.isLightMode;
}

/// Mixin to add color helpers to StatelessWidget
mixin ThemeColorsWidgetMixin on Widget {
  ThemeColorPalette colors(BuildContext context) => context.colors;
}
