# Dark Mode Color Visibility Issues

## 🔍 Analysis Summary

Found **37 files** with hardcoded colors that don't adapt to dark mode.

## 🚨 Critical Issues

### 1. AppColors.primaryLight (#1A4870 - Navy Blue)
**Problem**: Dark navy blue on dark background (#121212) = Very low contrast

**Files with this issue (37 files)**:
- calendar_screen.dart - AppBar, calendar markers, FAB
- dashboard_screen_improved.dart - AppBar, gradients, icons, borders
- appointments_screen.dart
- todos_screen.dart
- ministerial_secretary_dashboard.dart
- financial_reports_screen.dart
- my_mission_screen.dart
- all_borang_b_reports_screen.dart
- And 29 more files...

**Locations**:
```dart
// AppBar backgrounds
backgroundColor: AppColors.primaryLight,  // ❌ Dark navy on dark bg

// Calendar decorations
color: AppColors.primaryLight,  // ❌ Markers invisible

// Floating Action Buttons
backgroundColor: AppColors.primaryLight,  // ❌ Low contrast

// Gradients
LinearGradient([AppColors.primaryLight, ...])  // ❌ Too dark
```

### 2. Hardcoded Grey Shades
**Problem**: Light grey text (shade600, shade700) invisible on dark backgrounds

**Files with this issue (31 files)**:
- calendar_screen.dart - 15 occurrences
- dashboard_screen_improved.dart - 10 occurrences
- appointments_screen.dart
- ministerial_secretary_dashboard.dart
- And 27 more files...

**Examples**:
```dart
// Icon colors
Icon(Icons.access_time, color: Colors.grey.shade600)  // ❌ Too light

// Text colors
style: TextStyle(color: Colors.grey.shade700)  // ❌ Too light
style: TextStyle(color: Colors.grey.shade800)  // ❌ Too light

// Empty state icons
Icon(size: 64, color: Colors.grey.shade400)  // ❌ Barely visible
```

### 3. Semantic Color Coding (Orange/Indigo)
**Problem**: Used for appointments vs events, need dark mode variants

**Files**: calendar_screen.dart, appointments_screen.dart

**Examples**:
```dart
// Appointment indicators
color: Colors.orange.shade100  // ❌ Too light for dark mode
color: Colors.orange.shade700  // ❌ May be too dark

// Event indicators
color: Colors.indigo.shade100  // ❌ Too light for dark mode
color: Colors.indigo.shade700  // ❌ May be too dark
```

### 4. Direct Color Values
**Problem**: Hex colors that don't adapt

**Files**: 3 files
- department_management_screen.dart
- profile_screen.dart
- settings_screen.dart

```dart
Color(0xFF...)  // ❌ Fixed color regardless of theme
```

## 📊 Breakdown by Component

### AppBars (37 files)
- Using `AppColors.primaryLight` directly
- Should use: `Theme.of(context).appBarTheme.backgroundColor`

### Cards & Containers (20+ files)
- Using `Colors.grey.shade300` for borders
- Should use: `Theme.of(context).colorScheme.outline`

### Text Colors (31 files)
- Using `Colors.grey.shade600/700/800` for secondary text
- Should use: `Theme.of(context).colorScheme.onSurfaceVariant`

### Icons (31 files)
- Using `Colors.grey.shade600` for icon colors
- Should use: `Theme.of(context).colorScheme.onSurfaceVariant`

### Backgrounds (37 files)
- Using `AppColors.primaryLight` for backgrounds
- Should use: `Theme.of(context).colorScheme.primary`

## 🎯 Recommended Solutions

### 1. Theme-Aware Color Helper
Create `lib/utils/theme_colors.dart` with:
- `AppThemeColors` extension on BuildContext
- Semantic color getters (primary, surface, onSurface, etc.)
- Type-specific colors (appointment, event, success, error)

### 2. Migration Strategy
```dart
// ❌ Before
backgroundColor: AppColors.primaryLight,
color: Colors.grey.shade600,

// ✅ After
backgroundColor: context.colors.primary,
color: context.colors.textSecondary,
```

### 3. Semantic Colors
```dart
// For appointment/event distinction
context.colors.appointmentBackground  // Light: orange.100, Dark: orange.900
context.colors.appointmentForeground  // Light: orange.700, Dark: orange.300
context.colors.eventBackground        // Light: indigo.100, Dark: indigo.900
context.colors.eventForeground        // Light: indigo.700, Dark: indigo.300
```

## 📝 Priority Fix List

**High Priority** (Visibility Critical):
1. ✅ calendar_screen.dart - 40+ issues
2. ✅ dashboard_screen_improved.dart - 30+ issues
3. ✅ appointments_screen.dart
4. ✅ todos_screen.dart
5. ✅ ministerial_secretary_dashboard.dart

**Medium Priority**:
6. financial_reports_screen.dart
7. my_mission_screen.dart
8. all_borang_b_reports_screen.dart
9. activities_list_screen.dart

**Low Priority** (Less commonly viewed):
- Admin screens
- Management screens
- Settings screens

## 🛠️ Implementation Steps

1. ✅ Create `lib/utils/theme_colors.dart` helper
2. Fix high-priority screens (5 screens)
3. Test dark mode visibility
4. Fix medium-priority screens
5. Fix remaining screens
6. Add theme-aware documentation

---

**Next Steps**: See `lib/utils/theme_colors.dart` for the helper utility implementation.
