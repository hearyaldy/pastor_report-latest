// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/services/department_service.dart';

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
                minimumSize:
                    const Size.fromHeight(50), // Make button full-width
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
                minimumSize:
                    const Size.fromHeight(50), // Make button full-width
              ),
            ),
            const SizedBox(height: 16),
            // Seed Departments Button (Run once, then can be removed)
            ElevatedButton.icon(
              onPressed: () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  await DepartmentService().seedDepartments();

                  if (!context.mounted) return;
                  Navigator.pop(context); // Close loading dialog

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Success'),
                      content: const Text(
                          '✅ Departments seeded successfully!\n\nYou can now remove this button.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context); // Close loading dialog

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Error'),
                      content: Text('Failed to seed departments:\n$e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Seed Departments (Run Once)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
