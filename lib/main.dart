// lib/main.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/screens/sign_in_screen.dart';
import 'package:pastor_report/screens/admin_dashboard.dart';
import 'package:pastor_report/screens/departments_screen.dart';
import 'package:pastor_report/screens/settings_screen.dart'; // Ensure this path is correct
import 'package:pastor_report/screens/inapp_webview_screen.dart';

void main() {
  runApp(const PastorReportApp());
}

class PastorReportApp extends StatelessWidget {
  const PastorReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pastor Report',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SignInScreen(),
        '/admin': (context) => const AdminDashboard(),
        '/departments': (context) => const DepartmentsScreen(isAdmin: true),
        '/settings': (context) => const SettingsScreen(), // Ensure this matches the class name exactly
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/inapp_webview') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => InAppWebViewScreen(
              initialUrl: args['url']!,
              initialDepartmentName: args['departmentName']!, departments: const [],
            ),
          );
        }
        return null;
      },
    );
  }
}
