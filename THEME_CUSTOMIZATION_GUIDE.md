# Theme Customization Guide - Pastor Report v3.0.2

## Overview
Pastor Report now features comprehensive theme customization with full dark mode support and color personalization. This guide explains how to use and customize the app's appearance.

## Features

### 🌓 Dark Mode Support
- **Automatic Theme Persistence**: Your theme preference is automatically saved
- **System-wide Theming**: All screens and components adapt to your theme choice
- **Optimized Colors**: Carefully designed color palette for both light and dark modes
- **Enhanced Readability**: Improved contrast ratios for better visibility

### 🎨 Color Customization
- **12 Preset Colors**: Choose from a curated palette of professional colors
- **Primary Color Theming**: Your chosen color applies throughout the app
- **Real-time Preview**: See changes instantly as you customize
- **Persistent Settings**: Your color choice is saved across app sessions

## How to Use

### Accessing Theme Settings

#### Option 1: From Profile Screen
1. Open the app and navigate to the **Profile** tab
2. Scroll to the **"Appearance"** section
3. Toggle **Dark Mode** on/off using the switch
4. Tap **Primary Color** to choose a custom color
5. Tap **More Settings** for additional customization options

#### Option 2: From Settings Screen
1. Go to **Settings** from the navigation menu
2. Find **"Display Settings"**
3. Toggle **Dark Mode** on/off
4. Customize **Primary Color** by tapping on it
5. Explore **Font Settings** (coming soon)

### Changing Theme Mode

**Light Mode to Dark Mode:**
1. Navigate to Profile or Settings
2. Find the "Dark Mode" switch
3. Toggle it **ON**
4. The app will immediately switch to dark theme
5. Confirmation message will appear

**Dark Mode to Light Mode:**
1. Follow the same steps
2. Toggle the switch **OFF**
3. App returns to light theme instantly

### Customizing Primary Color

1. **Access Color Picker:**
   - Profile Screen: Tap on the colored square next to "Primary Color"
   - Settings Screen: Tap "Primary Color" card

2. **Choose Your Color:**
   - A bottom sheet will appear with 12 color options
   - Currently selected color shows a checkmark
   - Tap any color to preview it

3. **Available Colors:**
   - Navy Blue (Default) - Professional and trustworthy
   - Green - Nature and growth
   - Red - Energy and passion
   - Purple - Creativity and wisdom
   - Deep Orange - Enthusiasm
   - Light Blue - Calm and clarity
   - Pink - Compassion
   - Brown - Stability
   - Blue Grey - Sophistication
   - Teal - Balance
   - Orange - Optimism
   - Blue - Trust and reliability

4. **Apply Color:**
   - Tap your chosen color
   - The app updates immediately
   - Confirmation message appears
   - Color is saved automatically

## Technical Implementation

### Theme Architecture

```
lib/
├── providers/
│   └── theme_provider.dart       # Theme state management
├── utils/
│   └── theme.dart                # Theme definitions and colors
└── theme_manager.dart            # Legacy theme manager
```

### Key Components

#### 1. ThemeProvider (State Management)
- Manages theme mode (light/dark)
- Handles primary color selection
- Persists preferences using SharedPreferences
- Notifies listeners of theme changes

#### 2. AppTheme (Theme Definitions)
- **Light Theme**: Bright, professional appearance
- **Dark Theme**: Comfortable night viewing with reduced eye strain
- **Material 3**: Modern design system
- **Component Themes**: Cards, buttons, inputs, navigation, etc.

#### 3. Color Palette

**Light Theme:**
- Primary: Navy Blue (#1A4870)
- Accent: Sky Blue (#5B99C2)
- Background: Light Grey (#F5F7FA)
- Surface: White (#FFFFFF)

**Dark Theme:**
- Primary: Light Blue (#5B99C2)
- Primary Container: Navy Blue (#1A4870)
- Background: Near Black (#121212)
- Surface: Dark Grey (#1E1E1E)
- Enhanced contrast for readability

### Theme Properties

#### Light Theme Features:
- Clean white backgrounds
- High contrast text
- Subtle shadows and elevations
- Navy blue primary color
- Professional appearance

#### Dark Theme Features:
- True black background (#121212) for OLED efficiency
- Reduced eye strain in low light
- Adjusted color brightness
- Improved readability
- Card borders for better separation
- Optimized contrast ratios

## Best Practices

### When to Use Dark Mode:
✅ Low-light environments
✅ Evening/night usage
✅ Extended reading sessions
✅ Battery conservation (on OLED screens)
✅ Personal preference

### When to Use Light Mode:
✅ Bright daylight conditions
✅ Outdoor usage
✅ Quick reference checks
✅ Printing or sharing screenshots

### Color Selection Guidelines:

**Navy Blue (Default):**
- Best for: Professional, church/ministry context
- Recommended for: All users

**Green:**
- Best for: Growth-focused ministries
- Use when: Emphasizing nature, renewal

**Purple:**
- Best for: Creative ministries
- Use when: Highlighting worship, arts

**Blue:**
- Best for: Traditional settings
- Use when: Maintaining familiar feel

## Accessibility

### Contrast Ratios:
- All color combinations meet WCAG AA standards
- Text remains readable in both themes
- Interactive elements have clear focus states

### Visual Indicators:
- Icons accompany all theme controls
- Color previews for easy identification
- Real-time feedback for all changes

## Troubleshooting

### Theme Not Persisting:
**Issue:** Theme resets after closing app
**Solution:** Check app permissions for storage access

### Color Not Updating:
**Issue:** Selected color doesn't apply
**Solution:**
1. Close and restart the app
2. Clear app cache if needed
3. Reselect your preferred color

### Dark Mode Too Dark:
**Issue:** Hard to read in dark mode
**Solution:**
1. Try adjusting screen brightness
2. Use light mode in bright conditions
3. Consider a lighter primary color (Light Blue, Teal)

### Performance Issues:
**Issue:** Lag when switching themes
**Solution:** This is normal during transition, should resolve quickly

## Future Enhancements

### Coming Soon:
- ⏳ Font size adjustment
- ⏳ Font family selection
- ⏳ Automatic theme switching (time-based)
- ⏳ More color presets
- ⏳ Custom color picker
- ⏳ Theme presets (Professional, Vibrant, Minimal)
- ⏳ High contrast mode

## Integration with Other Features

### All Screens Support Theming:
- ✅ Dashboard and Home
- ✅ Profile and Settings
- ✅ Activities and Departments
- ✅ Calendar and Events
- ✅ Reports and Forms
- ✅ Admin Screens
- ✅ Authentication Screens

### Consistent Experience:
- Navigation bars adapt to theme
- Buttons and inputs themed appropriately
- Cards and surfaces properly colored
- Icons and text maintain visibility

## Developer Notes

### Adding New Colors:
1. Edit `lib/screens/settings_screen.dart`
2. Add color to `predefinedColors` list
3. Include descriptive comment
4. Test in both light and dark modes

### Modifying Theme:
1. Edit `lib/utils/theme.dart`
2. Update `lightTheme` or `darkTheme`
3. Test component appearance
4. Verify accessibility standards

### Theme Provider Usage:
```dart
// Access theme provider
final themeProvider = Provider.of<ThemeProvider>(context);

// Check current mode
bool isDark = themeProvider.isDarkMode;

// Toggle theme
await themeProvider.toggleDarkMode(true);

// Change primary color
await themeProvider.setPrimaryColor(Colors.blue);
```

## Support

For issues or suggestions regarding theme customization:
1. Check this guide first
2. Try troubleshooting steps
3. Report persistent issues via GitHub
4. Contact app support

---

**Version:** 3.0.2
**Last Updated:** October 2025
**Feature Status:** ✅ Fully Implemented
