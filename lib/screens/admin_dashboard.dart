// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Admin!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Button to navigate to the Departments page
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/departments');
              },
              icon: const Icon(Icons.dashboard),
              label: const Text('Go to Departments'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50), // Make button full-width
              ),
            ),
            const SizedBox(height: 16),
            // Additional button or link examples
            ElevatedButton.icon(
              onPressed: () {
                // Add navigation to settings or other admin functionalities
                Navigator.pushNamed(context, '/settings');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50), // Make button full-width
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Placeholder for future admin functionalities
                // For example, user management or reports
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Feature Coming Soon'),
                    content: const Text('More admin features will be added here.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.info),
              label: const Text('More Features'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50), // Make button full-width
              ),
            ),
          ],
        ),
      ),
    );
  }
}