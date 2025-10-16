# Theme-Aware Colors Usage Guide

## 📚 Quick Reference

The `theme_colors.dart` helper provides easy access to theme-aware colors that automatically adapt between light and dark modes.

## 🚀 Basic Usage

### 1. Import the Helper
```dart
import 'package:pastor_report/utils/theme_colors.dart';
```

### 2. Access Colors via Context
```dart
// Get the color palette
final colors = context.colors;

// Use colors
Container(
  color: colors.surface,
  child: Text(
    'Hello',
    style: TextStyle(color: colors.textPrimary),
  ),
)
```

## 🎨 Color Categories

### Core Theme Colors

| Property | Light Mode | Dark Mode | Usage |
|----------|-----------|-----------|-------|
| `colors.primary` | Navy (#1A4870) | Sky Blue (#5B99C2) | Primary actions, AppBars |
| `colors.onPrimary` | White | White | Text/icons on primary |
| `colors.surface` | White | Dark Gray (#1E1E1E) | Cards, sheets, dialogs |
| `colors.onSurface` | Dark Gray | Light Gray | Text/icons on surface |
| `colors.background` | Light Gray | Very Dark (#121212) | Screen background |
| `colors.outline` | Light Gray | Gray (#424242) | Borders, dividers |

### Text Colors

| Property | Description | Light | Dark |
|----------|-------------|-------|------|
| `colors.textPrimary` | Main text | #2C3E50 | #E1E1E1 |
| `colors.textSecondary` | Muted text | #7F8C8D | #B0B0B0 |
| `colors.textTertiary` | Very muted text | #95A5A6 | #808080 |
| `colors.textDisabled` | Disabled text | #BDC3C7 | #606060 |

### Icon Colors

| Property | Usage |
|----------|-------|
| `colors.iconPrimary` | Main icons |
| `colors.iconSecondary` | Muted icons |
| `colors.iconDisabled` | Disabled icons |

### Status Colors

| Property | Light | Dark | Usage |
|----------|-------|------|-------|
| `colors.success` | #27AE60 | #4CAF50 | Success messages |
| `colors.error` | Theme error | Theme error | Error messages |
| `colors.warning` | #F39C12 | #FFB74D | Warnings |
| `colors.info` | #3498DB | #64B5F6 | Info messages |

### Type-Specific Colors

| Property | Light BG | Dark BG | Light FG | Dark FG |
|----------|----------|---------|----------|---------|
| `colors.appointmentBackground` | Orange 100 | Orange 900 | - | - |
| `colors.appointmentForeground` | Orange 700 | Orange 300 | ✓ | ✓ |
| `colors.eventBackground` | Indigo 100 | Indigo 900 | - | - |
| `colors.eventForeground` | Indigo 700 | Indigo 300 | ✓ | ✓ |
| `colors.todoBackground` | Blue 50 | Blue 900 | - | - |
| `colors.todoForeground` | Blue 700 | Blue 300 | ✓ | ✓ |
| `colors.activityBackground` | Green 50 | Green 900 | - | - |
| `colors.activityForeground` | Green 700 | Green 300 | ✓ | ✓ |

### Utility Colors

| Property | Usage |
|----------|-------|
| `colors.emptyStateIcon` | Icons for empty states |
| `colors.emptyStateText` | Text for empty states |
| `colors.divider` | Divider lines |
| `colors.cardBackground` | Card background |
| `colors.cardBorder` | Card borders |

## 🔄 Migration Examples

### Before and After

#### AppBar
```dart
// ❌ Before - Hardcoded
AppBar(
  backgroundColor: AppColors.primaryLight,
  foregroundColor: Colors.white,
)

// ✅ After - Theme-aware
AppBar(
  backgroundColor: context.colors.primary,
  foregroundColor: context.colors.onPrimary,
)
```

#### Text Styling
```dart
// ❌ Before
Text(
  'Secondary text',
  style: TextStyle(color: Colors.grey.shade600),
)

// ✅ After
Text(
  'Secondary text',
  style: TextStyle(color: context.colors.textSecondary),
)
```

#### Icons
```dart
// ❌ Before
Icon(Icons.info, color: Colors.grey.shade600)

// ✅ After
Icon(Icons.info, color: context.colors.iconSecondary)
```

#### Type-Specific Styling (Appointments)
```dart
// ❌ Before
Container(
  decoration: BoxDecoration(
    color: Colors.orange.shade100,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(
    Icons.calendar_today,
    color: Colors.orange.shade700,
  ),
)

// ✅ After
Container(
  decoration: BoxDecoration(
    color: context.colors.appointmentBackground,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(
    Icons.calendar_today,
    color: context.colors.appointmentForeground,
  ),
)
```

#### Empty States
```dart
// ❌ Before
Column(
  children: [
    Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
    Text('No items', style: TextStyle(color: Colors.grey.shade600)),
  ],
)

// ✅ After
Column(
  children: [
    Icon(Icons.inbox, size: 64, color: context.colors.emptyStateIcon),
    Text('No items', style: TextStyle(color: context.colors.emptyStateText)),
  ],
)
```

#### Borders
```dart
// ❌ Before
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.grey.shade300),
  ),
)

// ✅ After
Container(
  decoration: BoxDecoration(
    border: Border.all(color: context.colors.outline),
  ),
)
```

#### Gradients
```dart
// ❌ Before
LinearGradient(
  colors: [
    AppColors.primaryLight,
    AppColors.primaryLight.withOpacity(0.8),
  ],
)

// ✅ After
LinearGradient(
  colors: context.colors.primaryGradient,
)
```

## 🛠️ Utility Methods

### Check Theme Mode
```dart
if (context.colors.isDarkMode) {
  // Dark mode specific logic
}

if (context.colors.isLightMode) {
  // Light mode specific logic
}
```

### Adaptive Colors
```dart
// Provide different colors for light/dark mode
final color = context.colors.adaptive(
  light: Color(0xFF1A4870),
  dark: Color(0xFF5B99C2),
);
```

### Calculate Text Color for Background
```dart
// Automatically choose black or white text based on background
final backgroundColor = Colors.blue;
final textColor = context.colors.onColor(backgroundColor);
```

### Create Shades
```dart
// Get lighter/darker version based on theme
final shadedColor = context.colors.shade(
  Colors.blue,
  amount: 0.2,  // 0.0 to 1.0
);
```

### Semi-Transparent Colors
```dart
final transparentColor = context.colors.withAlpha(
  context.colors.primary,
  0.5,  // 50% opacity
);
```

## 🎯 Best Practices

### 1. Always Use Theme Colors
```dart
// ❌ Don't
backgroundColor: Color(0xFF1A4870),

// ✅ Do
backgroundColor: context.colors.primary,
```

### 2. Use Semantic Names
```dart
// ❌ Don't
color: Colors.grey.shade600,

// ✅ Do
color: context.colors.textSecondary,
```

### 3. Use Type-Specific Colors
```dart
// ❌ Don't
color: Colors.orange.shade100,

// ✅ Do
color: context.colors.appointmentBackground,
```

### 4. Avoid Hardcoded Opacity
```dart
// ❌ Don't
color: AppColors.primaryLight.withOpacity(0.3),

// ✅ Do
color: context.colors.withAlpha(context.colors.primary, 0.3),
```

## 📦 Using with Mixins

### For StatefulWidget
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with ThemeColorsMixin {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surface,  // Direct access without context
      child: Text(
        'Hello',
        style: TextStyle(
          color: isDarkMode ? colors.textPrimary : colors.textSecondary,
        ),
      ),
    );
  }
}
```

## 🐛 Common Mistakes

### 1. Forgetting to Import
```dart
// Add this at the top
import 'package:pastor_report/utils/theme_colors.dart';
```

### 2. Using AppColors Directly
```dart
// ❌ Don't
import 'package:pastor_report/utils/constants.dart';
backgroundColor: AppColors.primaryLight,

// ✅ Do
import 'package:pastor_report/utils/theme_colors.dart';
backgroundColor: context.colors.primary,
```

### 3. Mixing Hardcoded and Theme Colors
```dart
// ❌ Don't mix
Container(
  color: context.colors.surface,  // Theme-aware
  child: Text('Text', style: TextStyle(color: Colors.grey)),  // Hardcoded!
)

// ✅ Do use consistent theme colors
Container(
  color: context.colors.surface,
  child: Text('Text', style: TextStyle(color: context.colors.textPrimary)),
)
```

## 📝 Migration Checklist

When updating a screen:
- [ ] Import `theme_colors.dart`
- [ ] Replace `AppColors.primaryLight` → `context.colors.primary`
- [ ] Replace `Colors.grey.shade600` → `context.colors.textSecondary`
- [ ] Replace `Colors.grey.shade700` → `context.colors.textSecondary`
- [ ] Replace `Colors.grey.shade800` → `context.colors.textPrimary`
- [ ] Replace `Colors.grey.shade400` → `context.colors.emptyStateIcon`
- [ ] Replace `Colors.grey.shade300` → `context.colors.outline`
- [ ] Replace type-specific colors (orange/indigo) → semantic colors
- [ ] Test in both light and dark modes
- [ ] Verify contrast and readability

---

**Next**: See example fixes in the screens or refer to `DARK_MODE_COLOR_ISSUES.md` for a list of files to update.
