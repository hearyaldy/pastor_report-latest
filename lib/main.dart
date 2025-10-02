// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/providers/theme_provider.dart';
import 'package:pastor_report/providers/mission_provider.dart';
import 'package:pastor_report/services/cache_service.dart';
import 'package:pastor_report/services/activity_storage_service.dart';
import 'package:pastor_report/services/settings_service.dart';
import 'package:pastor_report/models/activity_model.dart';
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
import 'package:pastor_report/screens/activities_list_screen.dart';
import 'package:pastor_report/screens/add_edit_activity_screen.dart';
import 'package:pastor_report/screens/departments_list_screen.dart';
import 'package:pastor_report/screens/todos_screen.dart';
import 'package:pastor_report/screens/appointments_screen.dart';
import 'package:pastor_report/screens/events_screen.dart';
import 'package:pastor_report/services/todo_storage_service.dart';
import 'package:pastor_report/services/appointment_storage_service.dart';
import 'package:pastor_report/services/event_service.dart';
import 'package:pastor_report/services/role_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence and caching
  await _enableFirestoreCache();

  // Initialize cache service
  await CacheService.instance.initialize();

  // Initialize activity storage service
  await ActivityStorageService.instance.initialize();

  // Initialize settings service
  await SettingsService.instance.initialize();

  // Initialize todo, appointment, and event services
  await TodoStorageService.instance.initialize();
  await AppointmentStorageService.instance.initialize();
  await EventService.instance.initialize();

  // Initialize SuperAdmin (heary@hopetv.asia)
  await RoleService.instance.initializeSuperAdmin();

  runApp(const PastorReportApp());
}

/// Enable Firestore caching to reduce reads
Future<void> _enableFirestoreCache() async {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Failed to enable Firestore caching: $e');
  }
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
              '/activities': (context) => const ActivitiesListScreen(),
              '/add-activity': (context) => const AddEditActivityScreen(),
              '/departments': (context) => const DepartmentsListScreen(),
              '/todos': (context) => const TodosScreen(),
              '/appointments': (context) => const AppointmentsScreen(),
              '/events': (context) => const EventsScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/edit-activity') {
                final activity = settings.arguments as Activity?;
                return MaterialPageRoute(
                  builder: (context) => AddEditActivityScreen(activity: activity),
                );
              }
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
