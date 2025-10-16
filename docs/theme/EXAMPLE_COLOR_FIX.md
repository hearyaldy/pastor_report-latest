# Example: Fixing Calendar Screen Colors

This document shows a concrete example of fixing hardcoded colors in `calendar_screen.dart`.

## 🎯 Issues Found

The calendar screen has **40+ hardcoded color issues** that make it difficult to use in dark mode:

1. AppBar using `AppColors.primaryLight` (navy blue on dark background)
2. Calendar markers using hardcoded colors
3. Grey shades for text and icons (too light for dark mode)
4. Orange/Indigo colors for appointments/events not adapting

## 🔧 Step-by-Step Fix

### Step 1: Add Import

```dart
// Add at the top of calendar_screen.dart
import 'package:pastor_report/utils/theme_colors.dart';
```

### Step 2: Fix AppBar

```dart
// ❌ Before (Line 707)
AppBar(
  title: const Text('Calendar'),
  backgroundColor: AppColors.primaryLight,  // Dark navy - invisible in dark mode
  foregroundColor: Colors.white,
  // ...
)

// ✅ After
AppBar(
  title: const Text('Calendar'),
  backgroundColor: context.colors.primary,  // Adapts: Navy → Sky Blue
  foregroundColor: context.colors.onPrimary,  // Always readable
  // ...
)
```

### Step 3: Fix Calendar Decorations

```dart
// ❌ Before (Lines 750-760)
calendarStyle: CalendarStyle(
  markerDecoration: BoxDecoration(
    color: AppColors.primaryLight,  // Too dark in dark mode
    shape: BoxShape.circle,
  ),
  selectedDecoration: BoxDecoration(
    color: AppColors.primaryLight,  // Too dark in dark mode
    shape: BoxShape.circle,
  ),
  todayDecoration: BoxDecoration(
    color: AppColors.primaryLight.withOpacity(0.5),  // Too dark
    shape: BoxShape.circle,
  ),
),

// ✅ After
calendarStyle: CalendarStyle(
  markerDecoration: BoxDecoration(
    color: context.colors.primary,  // Adapts to theme
    shape: BoxShape.circle,
  ),
  selectedDecoration: BoxDecoration(
    color: context.colors.primary,  // Adapts to theme
    shape: BoxShape.circle,
  ),
  todayDecoration: BoxDecoration(
    color: context.colors.withAlpha(context.colors.primary, 0.5),
    shape: BoxShape.circle,
  ),
),
```

### Step 4: Fix Type-Specific Colors (Appointments vs Events)

```dart
// ❌ Before (Lines 505-507, 839-841)
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: item.type == 'appointment'
        ? Colors.orange.shade100  // Too light for dark mode
        : Colors.indigo.shade100,  // Too light for dark mode
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(
    item.type == 'appointment'
        ? Icons.calendar_today
        : _getEventIcon(item.title),
    color: item.type == 'appointment'
        ? Colors.orange.shade700  // Too dark for dark mode
        : Colors.indigo.shade700,  // Too dark for dark mode
  ),
)

// ✅ After
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: item.type == 'appointment'
        ? context.colors.appointmentBackground  // Orange100 → Orange900
        : context.colors.eventBackground,  // Indigo100 → Indigo900
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(
    item.type == 'appointment'
        ? Icons.calendar_today
        : _getEventIcon(item.title),
    color: item.type == 'appointment'
        ? context.colors.appointmentForeground  // Orange700 → Orange300
        : context.colors.eventForeground,  // Indigo700 → Indigo300
  ),
)
```

### Step 5: Fix Text Colors

```dart
// ❌ Before (Lines 566-571)
Row(
  children: [
    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
    const SizedBox(width: 4),
    Text(
      DateFormat('MMM dd, yyyy • h:mm a').format(item.dateTime),
      style: TextStyle(color: Colors.grey.shade700),
    ),
  ],
)

// ✅ After
Row(
  children: [
    Icon(Icons.access_time, size: 16, color: context.colors.iconSecondary),
    const SizedBox(width: 4),
    Text(
      DateFormat('MMM dd, yyyy • h:mm a').format(item.dateTime),
      style: TextStyle(color: context.colors.textSecondary),
    ),
  ],
)
```

### Step 6: Fix Section Headers

```dart
// ❌ Before (Line 612)
Text(
  'Description',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.grey.shade800,  // Too dark text color
  ),
),

// ✅ After
Text(
  'Description',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: context.colors.textPrimary,  // Adapts to theme
  ),
),
```

### Step 7: Fix Empty State

```dart
// ❌ Before (Lines 802-812)
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(
      _selectedView == 'appointment'
          ? Icons.calendar_today
          : _selectedView == 'event'
              ? Icons.event
              : Icons.calendar_month,
      size: 64,
      color: Colors.grey.shade400,  // Barely visible in dark mode
    ),
    const SizedBox(height: 16),
    Text(
      _selectedView == 'all'
          ? 'No appointments or events for this day'
          : 'No ${_selectedView}s for this day',
      style: TextStyle(
        color: Colors.grey.shade600,  // Too light in dark mode
        fontSize: 16,
      ),
    ),
  ],
)

// ✅ After
Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(
      _selectedView == 'appointment'
          ? Icons.calendar_today
          : _selectedView == 'event'
              ? Icons.event
              : Icons.calendar_month,
      size: 64,
      color: context.colors.emptyStateIcon,  // Visible in both modes
    ),
    const SizedBox(height: 16),
    Text(
      _selectedView == 'all'
          ? 'No appointments or events for this day'
          : 'No ${_selectedView}s for this day',
      style: TextStyle(
        color: context.colors.emptyStateText,  // Readable in both modes
        fontSize: 16,
      ),
    ),
  ],
)
```

### Step 8: Fix Floating Action Button

```dart
// ❌ Before (Lines 957-958)
floatingActionButton: FloatingActionButton(
  onPressed: () { /* ... */ },
  backgroundColor: AppColors.primaryLight,  // Too dark in dark mode
  foregroundColor: Colors.white,
  child: const Icon(Icons.add),
),

// ✅ After
floatingActionButton: FloatingActionButton(
  onPressed: () { /* ... */ },
  backgroundColor: context.colors.primary,  // Adapts to theme
  foregroundColor: context.colors.onPrimary,
  child: const Icon(Icons.add),
),
```

## 📊 Summary of Changes

| Component | Before | After | Benefit |
|-----------|--------|-------|---------|
| AppBar | `AppColors.primaryLight` | `context.colors.primary` | Visible in dark mode |
| Calendar markers | `AppColors.primaryLight` | `context.colors.primary` | Clear indication |
| Appointment bg | `Colors.orange.shade100` | `context.colors.appointmentBackground` | Proper contrast |
| Event bg | `Colors.indigo.shade100` | `context.colors.eventBackground` | Proper contrast |
| Text (secondary) | `Colors.grey.shade600/700` | `context.colors.textSecondary` | Readable |
| Icons | `Colors.grey.shade600` | `context.colors.iconSecondary` | Visible |
| Empty state icon | `Colors.grey.shade400` | `context.colors.emptyStateIcon` | Clear indication |
| FAB | `AppColors.primaryLight` | `context.colors.primary` | Prominent |

## 🎨 Visual Comparison

### Light Mode
**Before**: Works fine ✅
**After**: Works fine ✅
(No visual regression)

### Dark Mode
**Before**:
- AppBar: Dark navy on dark background = 😞 Hard to see
- Markers: Dark navy dots = 😞 Invisible
- Text: Light grey = 😞 Hard to read
- Appointments: Light orange = 😞 Washed out
- FAB: Dark navy = 😞 Low contrast

**After**:
- AppBar: Sky blue on dark background = ✅ Clear
- Markers: Sky blue dots = ✅ Visible
- Text: Light grey adapted = ✅ Readable
- Appointments: Dark orange with light text = ✅ Clear
- FAB: Sky blue = ✅ High contrast

## ✅ Testing Checklist

After making these changes:

- [ ] Light mode: Verify all colors look correct
- [ ] Dark mode: Verify all colors are visible and readable
- [ ] Toggle theme: Ensure smooth transition
- [ ] Appointments: Check orange colors are distinct
- [ ] Events: Check indigo colors are distinct
- [ ] Empty state: Verify icon and text are visible
- [ ] Calendar markers: Check visibility on both themes
- [ ] Floating action button: Test visibility and contrast

## 🔁 Apply to Other Screens

Use the same pattern for other screens:

1. **dashboard_screen_improved.dart** (30+ issues)
2. **appointments_screen.dart** (similar patterns)
3. **todos_screen.dart** (similar patterns)
4. **ministerial_secretary_dashboard.dart** (similar patterns)

Follow the same steps:
1. Add import
2. Replace `AppColors.primaryLight` → `context.colors.primary`
3. Replace grey shades → semantic colors
4. Replace type-specific hardcoded colors → semantic type colors
5. Test in both modes

## 📝 Notes

- Always test in **both light and dark modes** after making changes
- Use **semantic color names** rather than color values
- Keep **visual hierarchy** consistent across themes
- Maintain **sufficient contrast** for accessibility
- Use the **theme colors extension** for all color decisions

---

**Next**: Apply these same fixes to the other high-priority screens listed in `DARK_MODE_COLOR_ISSUES.md`.
