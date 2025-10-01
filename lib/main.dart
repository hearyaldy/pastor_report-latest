// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/screens/splash_screen.dart';
import 'package:pastor_report/screens/main_screen.dart';
import 'package:pastor_report/screens/modern_sign_in_screen.dart';
import 'package:pastor_report/screens/registration_screen.dart';
import 'package:pastor_report/screens/admin_dashboard.dart';
import 'package:pastor_report/screens/departments_screen.dart';
import 'package:pastor_report/screens/settings_screen.dart';
import 'package:pastor_report/screens/user_management_screen.dart';
import 'package:pastor_report/screens/department_management_screen.dart';
import 'package:pastor_report/screens/inapp_webview_screen.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PastorReportApp());
}

class PastorReportApp extends StatelessWidget {
  const PastorReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/dashboard': (context) => const MainScreen(),
          '/login': (context) => const ModernSignInScreen(),
          '/register': (context) => const RegistrationScreen(),
          AppConstants.routeAdmin: (context) => const AdminDashboard(),
          AppConstants.routeDepartments: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            return DepartmentsScreen(isAdmin: authProvider.isAdmin);
          },
          AppConstants.routeSettings: (context) => const SettingsScreen(),
          '/user_management': (context) => const UserManagementScreen(),
          '/department_management': (context) => const DepartmentManagementScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == AppConstants.routeInAppWebView) {
            final args = settings.arguments as Map<String, String>;
            return MaterialPageRoute(
              builder: (context) => InAppWebViewScreen(
                initialUrl: args['url']!,
                initialDepartmentName: args['departmentName']!,
                departments: const [],
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
