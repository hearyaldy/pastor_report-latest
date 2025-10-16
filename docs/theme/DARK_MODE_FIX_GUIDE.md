# Dark Mode Fix - Implementation Guide

## Overview
This guide outlines the systematic approach to fix dark mode issues across all screens in the Pastor Report app.

## Files Modified

### ✅ Already Fixed
1. **lib/utils/theme.dart** - Enhanced dark theme
2. **lib/providers/theme_provider.dart** - Theme management (already working)
3. **lib/screens/profile_screen.dart** - Theme controls added
4. **lib/screens/settings_screen.dart** - Theme controls (already working)
5. **lib/screens/dashboard_screen_improved.dart** - Partially fixed (background, search bar, cards)

## Common Dark Mode Issues & Solutions

### 1. Hardcoded Background Colors
```dart
// ❌ BAD - Hardcoded white/grey
Scaffold(
  backgroundColor: Colors.white,  // or Colors.grey[50]
  body: ...
)

// ✅ GOOD - Theme-aware
Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  body: ...
)
```

### 2. Hardcoded Card/Container Colors
```dart
// ❌ BAD
Container(
  color: Colors.white,
  child: ...
)

// ✅ GOOD
Container(
  color: Theme.of(context).cardColor,
  child: ...
)
```

### 3. Hardcoded Text Colors
```dart
// ❌ BAD
Text(
  'Hello',
  style: TextStyle(color: Colors.black),  // or Colors.grey[800]
)

// ✅ GOOD
Text(
  'Hello',
  style: TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
  ),
)
```

### 4. Hardcoded Border/Divider Colors
```dart
// ❌ BAD
Border.all(color: Colors.grey[200]!)

// ✅ GOOD
Border.all(color: Theme.of(context).dividerColor)
```

### 5. Icon Colors
```dart
// ❌ BAD
Icon(Icons.home, color: Colors.grey[600])

// ✅ GOOD
Icon(Icons.home, color: Theme.of(context).iconTheme.color)
```

## Automated Fix Script

Run this command to automatically fix common issues:

```bash
chmod +x fix_dark_mode.sh
./fix_dark_mode.sh
```

## Manual Fixes Needed

Some patterns require manual fixing:

### 1. Gradient Backgrounds
Keep gradients but consider dark mode variations:
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        AppColors.primaryLight,
        AppColors.primaryDark,
      ],
    ),
  ),
)
```

### 2. Modal Bottom Sheets
```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
  builder: (context) => ...
)
```

### 3. Alert Dialogs
Alert dialogs should automatically adapt, but if you're customizing:
```dart
AlertDialog(
  backgroundColor: Theme.of(context).dialogBackgroundColor,
  ...
)
```

## Screen-by-Screen Checklist

### Critical Screens (High Priority)
- [x] dashboard_screen_improved.dart - Partially done
- [ ] welcome_screen.dart
- [ ] home_screen.dart
- [ ] main_screen.dart
- [ ] activities_list_screen.dart
- [ ] departments_list_screen.dart

### Medium Priority
- [ ] borang_b_screen.dart
- [ ] borang_b_list_screen.dart
- [ ] calendar_screen.dart
- [ ] events_screen.dart
- [ ] todos_screen.dart
- [ ] appointments_screen.dart

### Low Priority (Admin Screens)
- [ ] admin_dashboard_improved.dart
- [ ] user_management_screen.dart
- [ ] mission_management_screen.dart
- [ ] region_management_screen.dart
- [ ] district_management_screen.dart

## Testing Checklist

After fixes, test each screen in both themes:

1. **Visual Check**
   - [ ] Background is appropriate color
   - [ ] Text is readable
   - [ ] Cards/containers stand out from background
   - [ ] Borders/dividers are visible

2. **Interactive Elements**
   - [ ] Buttons are visible
   - [ ] Input fields have proper contrast
   - [ ] Icons are visible
   - [ ] Links/tappable elements are distinguishable

3. **Special Cases**
   - [ ] Modal bottom sheets
   - [ ] Alert dialogs
   - [ ] Snackbars
   - [ ] Navigation drawers (if any)

## Common Color Mappings

| Light Mode | Dark Mode | Use Theme Property |
|------------|-----------|-------------------|
| `Colors.white` | `Color(0xFF1E1E1E)` | `Theme.of(context).cardColor` |
| `Colors.grey[50]` | `Color(0xFF121212)` | `Theme.of(context).scaffoldBackgroundColor` |
| `Colors.grey[200]` | `Color(0xFF424242)` | `Theme.of(context).dividerColor` |
| `Colors.black` | `Colors.white` | `Theme.of(context).colorScheme.onSurface` |
| `Colors.grey[600]` | `Colors.white70` | `Theme.of(context).textTheme.bodySmall?.color` |
| `Colors.grey[800]` | `Colors.white` | `Theme.of(context).colorScheme.onSurface` |

## Helper Utility

Use the `ThemeHelper` extension for convenience:

```dart
import 'package:pastor_report/utils/theme_helper.dart';

// In your widget:
Container(
  color: context.cardColor,  // Instead of Theme.of(context).cardColor
  child: Text(
    'Hello',
    style: TextStyle(color: context.textColor),
  ),
)
```

## Quick Reference

### Most Common Replacements

1. **Scaffold Background**
   ```dart
   backgroundColor: Theme.of(context).scaffoldBackgroundColor
   ```

2. **Card/Container**
   ```dart
   color: Theme.of(context).cardColor
   ```

3. **Primary Text**
   ```dart
   color: Theme.of(context).colorScheme.onSurface
   ```

4. **Secondary Text**
   ```dart
   color: Theme.of(context).textTheme.bodySmall?.color
   ```

5. **Dividers**
   ```dart
   color: Theme.of(context).dividerColor
   ```

## Validation

Run these commands to validate:

```bash
# Check for remaining hardcoded colors
grep -r "Colors\.white" lib/screens/*.dart | wc -l
grep -r "Colors\.grey\[" lib/screens/*.dart | wc -l

# Analyze for errors
flutter analyze lib/screens/

# Run the app in dark mode
flutter run --dart-define=DARK_MODE=true
```

## Notes

- Gradient backgrounds (like in app bars) can remain as-is since they're intentionally colored
- Colored badges and status indicators should keep their semantic colors (red for error, green for success, etc.)
- Brand colors (primary, accent) should remain consistent across themes
- Focus on backgrounds, text, and interactive elements first

## Progress Tracking

**Dashboard Screen**: 60% complete
- ✅ Scaffold background
- ✅ Search bar
- ✅ Stat cards
- ✅ Tab buttons
- ✅ Activity cards
- ⏳ Remaining containers/forms

**Overall Progress**: 15% (6 of 40 screens touched)

## Next Steps

1. Complete dashboard screen fixes
2. Fix welcome and authentication screens
3. Fix list screens (activities, departments, todos)
4. Fix form screens (Borang B, appointments, events)
5. Fix admin screens
6. Comprehensive testing in both modes

---

**Last Updated**: October 2025
**Status**: In Progress
