// lib/utils/constants.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/models/department_model.dart';

// Extension to add the withValues method to Color class
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromARGB(
      alpha != null ? (alpha * 255).round() : this.alpha,
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
    );
  }
}

class AppConstants {
  // App Info
  static const String appName = 'PastorPro';
  static const String appVersion = '3.0.0';

  // Routes
  static const String routeSplash = '/splash';
  static const String routeHome = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeSettings = '/settings';
  static const String routeAdmin = '/admin';
  static const String routeDepartments = '/departments';
  static const String routeInAppWebView = '/inapp_webview';
  static const String routeOnboarding = '/onboarding';
  static const String routeAdminUtilities = '/admin_utilities';
  static const String routeMissionManagement = '/mission_management';

  // Storage Keys
  static const String keyRememberMe = 'remember_me';
  static const String keyUserEmail = 'user_email';
  static const String keyThemeMode = 'theme_mode';

  // Mission Options
  static const List<String> missions = [
    'Sabah Mission',
    'North Sabah Mission',
    'Sarawak Mission',
    'Peninsular Mission',
  ];

  // Role Options
  static const List<String> roles = [
    'Mission Officer',
    'Departmental Director',
    'District Pastor',
    'Lay Pastor',
    'Contract Pastor',
    'Mission Staff',
    'Volunteer',
  ];
}

class AppColors {
  // Light Theme Colors
  static const Color primaryLight = Color(0xFF1A4870);
  static const Color primaryDark = Color(0xFF1F316F);
  static const Color accent = Color(0xFF5B99C2);
  static const Color cardBackground = Color(0xFFF9DBBA);

  // Custom Material Swatch
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF1A4870,
    <int, Color>{
      50: Color(0xFFE3EAF2),
      100: Color(0xFFB8CCDF),
      200: Color(0xFF8AAACC),
      300: Color(0xFF5C88B9),
      400: Color(0xFF366FAC),
      500: Color(0xFF1A4870),
      600: Color(0xFF1A3E64),
      700: Color(0xFF163553),
      800: Color(0xFF142E46),
      900: Color(0xFF0F2032),
    },
  );
}

class DepartmentData {
  static final List<Department> departments = [
    Department(
      id: 'ministerial',
      name: 'Ministerial',
      icon: Icons.person,
      formUrl:
          'https://forms.gle/MinisterialLink', // TODO: Replace with actual URL
    ),
    Department(
      id: 'stewardship',
      name: 'Stewardship',
      icon: Icons.account_balance,
      formUrl: 'https://forms.gle/Fwud8srq8aXikzY48',
    ),
    Department(
      id: 'youth',
      name: 'Youth',
      icon: Icons.group,
      formUrl: 'https://tinyurl.com/laporan-jpba',
    ),
    Department(
      id: 'communication',
      name: 'Communication',
      icon: Icons.message,
      formUrl: 'https://forms.gle/wMaDk2VUwhd8MwXk9',
    ),
    Department(
      id: 'health',
      name: 'Health Ministry',
      icon: Icons.local_hospital,
      formUrl: 'https://forms.gle/aR4mRU8HopXGQ6cq5',
    ),
    Department(
      id: 'education',
      name: 'Education',
      icon: Icons.school,
      formUrl:
          'https://forms.gle/EducationLink', // TODO: Replace with actual URL
    ),
    Department(
      id: 'family',
      name: 'Family Life',
      icon: Icons.family_restroom,
      formUrl: 'https://forms.gle/iak14RPeULZ18BCD6',
    ),
    Department(
      id: 'women_q1q2',
      name: 'Women\'s Ministry (Q1 & Q2)',
      icon: Icons.woman,
      formUrl: 'https://forms.gle/ybAS4jRESNPQp71J7',
    ),
    Department(
      id: 'women_q3q4',
      name: 'Women\'s Ministry (Q3 & Q4)',
      icon: Icons.woman,
      formUrl: 'https://forms.gle/1tzirnartRswrDbb6',
    ),
    Department(
      id: 'children',
      name: 'Children',
      icon: Icons.child_care,
      formUrl: 'http://tiny.cc/HANTARFILELAPORAN',
    ),
    Department(
      id: 'publishing',
      name: 'Publishing',
      icon: Icons.book,
      formUrl:
          'https://forms.gle/PublishingLink', // TODO: Replace with actual URL
    ),
    Department(
      id: 'personal_ministry',
      name: 'Personal Ministry',
      icon: Icons.person_pin,
      formUrl:
          'https://forms.gle/PersonalMinistryLink', // TODO: Replace with actual URL
    ),
    Department(
      id: 'sabbath_school',
      name: 'Sabbath School',
      icon: Icons.access_time,
      formUrl:
          'https://docs.google.com/forms/d/1JTupBS6yVIePQmgTHih8ptlG9zxUSVv2aJzJc3c3V10/edit',
    ),
    Department(
      id: 'acs',
      name: 'Adventist Community Services',
      icon: Icons.volunteer_activism,
      formUrl:
          'https://forms.gle/AdventistCommunityServicesLink', // TODO: Replace with actual URL
    ),
  ];
}
