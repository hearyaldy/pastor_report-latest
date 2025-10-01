// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/providers/theme_provider.dart';
import 'package:pastor_report/providers/mission_provider.dart';
import 'package:pastor_report/screens/splash_screen.dart';
import 'package:pastor_report/screens/main_screen.dart';
import 'package:pastor_report/screens/modern_sign_in_screen.dart';
import 'package:pastor_report/screens/registration_screen.dart';
import 'package:pastor_report/screens/settings_screen.dart';
import 'package:pastor_report/screens/admin_dashboard.dart';
import 'package:pastor_report/screens/admin_utilities_screen.dart';
import 'package:pastor_report/screens/inapp_webview_screen.dart';
import 'package:pastor_report/screens/onboarding_screen.dart';
import 'package:pastor_report/screens/mission_management_screen.dart';
import 'package:pastor_report/utils/constants.dart';
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MissionProvider()..initialize()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getThemeData(),
            themeMode: themeProvider.themeMode,
            initialRoute: AppConstants.routeSplash,
            routes: {
              AppConstants.routeSplash: (context) => const SplashScreen(),
              AppConstants.routeHome: (context) => const MainScreen(),
              AppConstants.routeLogin: (context) => const ModernSignInScreen(),
              AppConstants.routeRegister: (context) =>
                  const RegistrationScreen(),
              AppConstants.routeSettings: (context) => const SettingsScreen(),
              AppConstants.routeAdmin: (context) => const AdminDashboard(),
              AppConstants.routeOnboarding: (context) =>
                  const OnboardingScreen(),
              AppConstants.routeAdminUtilities: (context) =>
                  const AdminUtilitiesScreen(),
              AppConstants.routeMissionManagement: (context) =>
                  const MissionManagementScreen(),
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
          );
        },
      ),
    );
  }
}
