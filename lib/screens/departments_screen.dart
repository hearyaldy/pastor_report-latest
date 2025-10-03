// lib/screens/departments_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/screens/inapp_webview_screen.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/services/department_service.dart';

class DepartmentsScreen extends StatefulWidget {
  final bool isAdmin;

  const DepartmentsScreen({super.key, required this.isAdmin});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  // Utility function to get the current formatted date
  String _getCurrentDate() {
    final now = DateTime.now();
    return '${_getDayOfWeek(now.weekday)} | ${now.day}-${now.month}-${now.year}';
  }

  // Utility function to get the day of the week
  String _getDayOfWeek(int weekday) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[weekday % 7];
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.routeWelcome,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          // Show admin badge if user is admin
          if (widget.isAdmin)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                label: Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.red,
                padding: EdgeInsets.all(0),
              ),
            ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with image, app name, and date
          Stack(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/header_image.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 5,
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${authProvider.user?.displayName ?? "User"}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCurrentDate(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          // List of departments
          Expanded(
            child: StreamBuilder<List<Department>>(
              stream: DepartmentService().getDepartmentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No departments found'),
                        SizedBox(height: 8),
                        Text(
                          'Ask admin to add departments',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final departments = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: departments.length,
                  itemBuilder: (context, index) {
                    final department = departments[index];
                    return Card(
                      color: AppColors.cardBackground,
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          department.icon,
                          color: AppColors.primaryLight,
                          size: 32,
                        ),
                        title: Text(
                          department.name,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: AppColors.primaryLight,
                          size: 18,
                        ),
                        onTap: () {
                          // Navigate to the in-app WebView with the department link and name
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InAppWebViewScreen(
                                initialUrl: department.formUrl,
                                initialDepartmentName: department.name,
                                departments: departments.map((dept) => {
                                  'name': dept.name,
                                  'icon': dept.icon,
                                  'link': dept.formUrl,
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Bottom navigation bar with settings button
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        selectedItemColor: AppColors.primaryLight,
        onTap: (index) {
          if (index == 0) {
            // Already on home/departments
          } else if (index == 1) {
            Navigator.pushNamed(context, AppConstants.routeSettings);
          }
        },
      ),
    );
  }
}
