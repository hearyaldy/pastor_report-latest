// lib/widgets/custom_drawer.dart
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final bool isAdmin;

  const CustomDrawer({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.red,
            ),
            child: Text(
              isAdmin ? 'Admin Menu' : 'User Menu',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pushNamed(context, '/'); // Navigate to home
            },
          ),
          if (isAdmin) // Show additional options if the user is an admin
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin Settings'),
              onTap: () {
                Navigator.pushNamed(context, '/admin');
              },
            ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
    );
  }
}
