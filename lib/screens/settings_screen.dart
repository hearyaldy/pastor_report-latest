// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Theme Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        _darkMode ? Icons.dark_mode : Icons.light_mode,
                        color: AppColors.primaryLight,
                      ),
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Toggle between light and dark theme'),
                      trailing: Switch(
                        value: _darkMode,
                        onChanged: (bool value) {
                          setState(() {
                            _darkMode = value;
                          });
                          // TODO: Implement theme change
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dark mode coming soon!'),
                              duration: Duration(seconds: 2),
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
                      leading: Icon(Icons.format_size, color: AppColors.primaryLight),
                      title: const Text('Font Size'),
                      subtitle: const Text('Adjust text size throughout the app'),
                      trailing: DropdownButton<String>(
                        value: _fontSize,
                        items: const [
                          DropdownMenuItem(value: 'Small', child: Text('Small')),
                          DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'Large', child: Text('Large')),
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
                      leading: Icon(Icons.font_download, color: AppColors.primaryLight),
                      title: const Text('Font Family'),
                      subtitle: const Text('Choose your preferred font style'),
                      trailing: DropdownButton<String>(
                        value: _fontFamily,
                        items: const [
                          DropdownMenuItem(value: 'Default', child: Text('Default')),
                          DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                          DropdownMenuItem(value: 'OpenSans', child: Text('Open Sans')),
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
            Card(
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
                      leading: Icon(Icons.palette, color: AppColors.primaryLight),
                      title: const Text('Primary Color'),
                      subtitle: const Text('Customize the app\'s primary color'),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, width: 2),
                        ),
                      ),
                      onTap: () {
                        // TODO: Implement color picker
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Color picker coming soon!'),
                            duration: Duration(seconds: 2),
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

            // App Information Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.info, color: AppColors.primaryLight),
                      title: const Text('Version'),
                      subtitle: Text(AppConstants.appVersion),
                      contentPadding: EdgeInsets.zero,
                    ),
                    ListTile(
                      leading: const Icon(Icons.apps, color: AppColors.primaryLight),
                      title: const Text('App Name'),
                      subtitle: Text(AppConstants.appName),
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
}
