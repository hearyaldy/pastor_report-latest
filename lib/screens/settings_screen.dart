// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/providers/theme_provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/screens/comprehensive_onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fontSize = 'Normal';
  String _fontFamily = 'Default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Theme Card
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Display Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return ListTile(
                          leading: Icon(
                            themeProvider.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: themeProvider.primaryColor,
                          ),
                          title: const Text('Dark Mode'),
                          subtitle:
                              const Text('Toggle between light and dark theme'),
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            onChanged: (bool value) {
                              themeProvider.toggleDarkMode(value);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(value
                                      ? 'Dark mode enabled'
                                      : 'Light mode enabled'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Font Settings Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Font Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.format_size,
                          color: AppColors.primaryLight),
                      title: const Text('Font Size'),
                      subtitle:
                          const Text('Adjust text size throughout the app'),
                      trailing: DropdownButton<String>(
                        value: _fontSize,
                        items: const [
                          DropdownMenuItem(
                              value: 'Small', child: Text('Small')),
                          DropdownMenuItem(
                              value: 'Normal', child: Text('Normal')),
                          DropdownMenuItem(
                              value: 'Large', child: Text('Large')),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _fontSize = value ?? 'Normal';
                          });
                          // TODO: Implement font size change
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Font size: $value - Coming soon!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.font_download,
                          color: AppColors.primaryLight),
                      title: const Text('Font Family'),
                      subtitle: const Text('Choose your preferred font style'),
                      trailing: DropdownButton<String>(
                        value: _fontFamily,
                        items: const [
                          DropdownMenuItem(
                              value: 'Default', child: Text('Default')),
                          DropdownMenuItem(
                              value: 'Roboto', child: Text('Roboto')),
                          DropdownMenuItem(
                              value: 'OpenSans', child: Text('Open Sans')),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _fontFamily = value ?? 'Default';
                          });
                          // TODO: Implement font family change
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Font: $value - Coming soon!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Color Theme Card
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Color Theme',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.palette,
                              color: themeProvider.primaryColor),
                          title: const Text('Primary Color'),
                          subtitle:
                              const Text('Customize the app\'s primary color'),
                          trailing: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: themeProvider.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 2),
                            ),
                          ),
                          onTap: () {
                            _showColorPicker(context, themeProvider);
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Profile & Organization Settings Card - Visible to all users based on role
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final userRole = authProvider.user?.userRole;
                if (userRole == null) return const SizedBox.shrink();

                String cardTitle;
                String listTitle;
                String subtitle;

                switch (userRole) {
                  case UserRole.superAdmin:
                    cardTitle = 'Admin Settings';
                    listTitle = 'Manage Organizational Hierarchy';
                    subtitle = 'Manage regions, districts, and churches';
                    break;
                  case UserRole.admin:
                  case UserRole.missionAdmin:
                    cardTitle = 'Organization Management';
                    listTitle = 'Manage Organization';
                    subtitle =
                        'Update regions, districts, and churches in your mission';
                    break;
                  case UserRole.districtPastor:
                    cardTitle = 'District Management';
                    listTitle = 'Manage District';
                    subtitle =
                        'Update churches and financial reports in your district';
                    break;
                  default:
                    cardTitle = 'Profile Settings';
                    listTitle = 'Update Profile';
                    subtitle = 'Complete or update your profile information';
                    break;
                }

                return Column(
                  children: [
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cardTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              leading: Icon(Icons.admin_panel_settings,
                                  color: AppColors.primaryLight),
                              title: Text(listTitle),
                              subtitle: Text(subtitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ComprehensiveOnboardingScreen(),
                                  ),
                                );
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // About Card
            Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.info_outline,
                          color: AppColors.primaryLight),
                      title: const Text('App Information'),
                      subtitle: const Text('Learn about PastorPro'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(context, AppConstants.routeAbout);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    ListTile(
                      leading: Icon(Icons.new_releases,
                          color: AppColors.primaryLight),
                      title: const Text('App Version'),
                      subtitle: const Text(AppConstants.appVersion),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider themeProvider) {
    final List<Color> predefinedColors = [
      const Color(0xFF1A4870), // Navy Blue (Default)
      const Color(0xFF2E7D32), // Green
      const Color(0xFFD32F2F), // Red
      const Color(0xFF7B1FA2), // Purple
      const Color(0xFFE64A19), // Deep Orange
      const Color(0xFF0288D1), // Light Blue
      const Color(0xFFC2185B), // Pink
      const Color(0xFF5D4037), // Brown
      const Color(0xFF455A64), // Blue Grey
      const Color(0xFF00796B), // Teal
      const Color(0xFFF57C00), // Orange
      const Color(0xFF1976D2), // Blue
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Primary Color',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: predefinedColors.map((color) {
                  final isSelected =
                      color.toARGB32() == themeProvider.primaryColor.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      themeProvider.setPrimaryColor(color);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Primary color updated!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected ? Colors.white : Colors.grey.shade300,
                          width: isSelected ? 4 : 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 32,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
