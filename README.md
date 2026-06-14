# Pastor Report

A comprehensive church management app for the Sabah Adventist Mission (SAM/NSM), enabling pastors, church treasurers, and mission administrators to track pastoral activities, submit monthly reports, manage church finances, and coordinate mission-wide events.

## Features

### Authentication & Onboarding
- Email/password registration with Firebase Auth and email verification
- Multi-step onboarding flow: select Region → District → Church, with option to request a new location if not listed
- Role assignment during onboarding; admins approve and assign final roles

### Role-Based Access Control
Ten roles with hierarchical permissions:

| Role | Level | Key Capabilities |
|------|-------|-----------------|
| Super Admin | 5 | Full access; manage all roles and missions |
| Admin | 4 | Manage users, missions, data import |
| Mission Admin | 3 | Manage staff and users within their mission |
| Ministerial Secretary | 3 | Access all Borang B reports across the mission |
| Director | 3 | Mission-level read/write access |
| Officer | 3 | Mission-level read-only access |
| Editor | 2 | Edit content within assigned mission |
| District Pastor | 2 | Manage district-level reports |
| Church Treasurer | 1 | Submit and view church financial reports |
| User | 1 | Submit personal reports and view own data |

### Pastoral Activities
- Log and categorise pastoral activities (visits, meetings, evangelism, etc.)
- Edit and delete activity records
- Export activity logs

### Monthly Report — Borang B
- Digital Borang B (SAB Ministerial Pastoral Monthly Report) form
- Month-by-month data entry with auto-save to Firestore
- PDF export and sharing
- List view of all submitted reports per user
- Ministerial Secretary can view all Borang B reports across the mission

### Financial Reporting (Treasurer Module)
- Church treasurer dashboard with monthly report overview
- FAM (Financial Accounting Method) form for detailed church finances
- PDF and Excel export of financial reports
- Admin view of financial reports across all churches, filterable by region, district, and mission
- Edit and approval workflow for submitted reports

### Events & Calendar
- Create and manage local events with date, time, and location
- Mission-wide global events managed by admins
- Calendar view (monthly/weekly) with events and appointments highlighted
- Special events imported from PDF/JSON assets

### Appointments
- Track pastoral appointments with contacts
- View upcoming and past appointments in a dedicated screen

### To-Do List
- Personal task management with completion tracking
- Persisted locally with SharedPreferences

### Departments
- Browse church departments with associated resources
- In-app WebView for opening department web links
- Admin: add, edit, and manage department URLs

### Church Hierarchy Management (Admin)
- Manage Regions, Districts, and Churches in a hierarchical structure
- Mission management: create, edit, assign staff to missions
- Staff directory and assignment management
- District Pastor assignment per district

### User & Staff Management (Admin)
- View, search, and filter all users
- Assign roles and missions to users
- Manage premium status
- Staff import from CSV/JSON assets
- Data import tool for bulk-loading churches and staff records

### Resource Management (Admin)
- Upload and manage shared resources accessible to users

### Reports Overview (Admin)
- View all financial reports across churches with filter by mission/region/district/month
- View all Borang B submissions in one screen

### Profile & Settings
- User profile with display name and profile photo (image picker + Firebase Storage)
- Dark/light theme toggle (persisted across sessions)
- About screen with app version info

### Offline Support
- Firestore offline persistence enabled with unlimited cache size
- App remains functional when offline; syncs when reconnected

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Android, iOS, Web, macOS, Linux, Windows) |
| Backend | Firebase Firestore + Firebase Auth |
| State Management | Provider (ChangeNotifier) |
| Export | `pdf` + `excel` packages |
| Calendar | `table_calendar` |
| WebView | `webview_flutter` |
| Local Storage | `shared_preferences` |
| File Handling | `file_picker`, `path_provider`, `share_plus`, `image_picker` |
| UI | Material Design 3 |

## Project Structure

```
lib/
├── main.dart                         # App entry, Firebase init, routing
├── firebase_options.dart             # Firebase config (generated)
├── theme_manager.dart                # Theme helpers
├── models/                           # Data models
│   ├── user_model.dart               # UserModel + UserRole enum
│   ├── borang_b_model.dart
│   ├── financial_report_model.dart
│   ├── fam_model.dart
│   ├── church_model.dart
│   ├── district_model.dart
│   ├── region_model.dart
│   ├── mission_model.dart
│   ├── staff_model.dart
│   ├── activity_model.dart
│   ├── event_model.dart
│   ├── global_event_model.dart
│   ├── appointment_model.dart
│   ├── department_model.dart
│   ├── todo_model.dart
│   ├── team_member_model.dart
│   ├── resource_model.dart
│   └── location_request_model.dart
├── providers/                        # ChangeNotifier providers
│   ├── auth_provider.dart
│   ├── theme_provider.dart
│   ├── mission_provider.dart
│   └── management_data_provider.dart
├── screens/                          # UI screens
│   ├── admin/                        # Admin-only screens
│   │   ├── church_management_screen.dart
│   │   ├── data_import_screen.dart
│   │   ├── financial_reports_screen.dart
│   │   ├── financial_reports_all_tab.dart
│   │   └── resource_management_screen.dart
│   ├── treasurer/                    # Treasurer module
│   │   ├── treasurer_dashboard.dart
│   │   ├── financial_report_form.dart
│   │   ├── fam_form.dart
│   │   └── export_report_screen.dart
│   ├── splash_screen.dart
│   ├── welcome_screen.dart
│   ├── simplified_registration_screen.dart
│   ├── comprehensive_onboarding_screen.dart
│   ├── main_screen.dart
│   ├── home_screen.dart
│   ├── dashboard_screen_improved.dart
│   ├── admin_dashboard_improved.dart
│   ├── ministerial_secretary_dashboard.dart
│   ├── activities_list_screen.dart
│   ├── add_edit_activity_screen.dart
│   ├── borang_b_screen.dart
│   ├── borang_b_list_screen.dart
│   ├── borang_b_preview_screen.dart
│   ├── all_borang_b_reports_screen.dart
│   ├── financial_reports_list_screen.dart
│   ├── financial_report_edit_screen.dart
│   ├── calendar_screen.dart
│   ├── events_screen.dart
│   ├── global_events_management_screen.dart
│   ├── appointments_screen.dart
│   ├── todos_screen.dart
│   ├── departments_screen.dart
│   ├── department_management_screen.dart
│   ├── mission_management_screen.dart
│   ├── district_management_screen.dart
│   ├── region_management_screen.dart
│   ├── staff_management_screen.dart
│   ├── user_management_screen.dart
│   ├── my_ministry_screen.dart
│   ├── my_mission_screen.dart
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   ├── admin_utilities_screen.dart
│   ├── inapp_webview_screen.dart
│   └── about_screen.dart
├── services/                         # Business logic & Firebase services
│   ├── auth_service.dart
│   ├── role_service.dart
│   ├── church_service.dart
│   ├── district_service.dart
│   ├── region_service.dart
│   ├── mission_service.dart
│   ├── staff_service.dart
│   ├── department_service.dart
│   ├── event_service.dart
│   ├── global_event_service.dart
│   ├── activity_storage_service.dart
│   ├── activity_export_service.dart
│   ├── appointment_storage_service.dart
│   ├── todo_storage_service.dart
│   ├── borang_b_service.dart
│   ├── borang_b_firestore_service.dart
│   ├── borang_b_storage_service.dart
│   ├── borang_b_backup_service.dart
│   ├── financial_report_service.dart
│   ├── fam_service.dart
│   ├── resource_service.dart
│   ├── data_import_service.dart
│   ├── user_management_service.dart
│   ├── location_request_service.dart
│   ├── profile_picture_service.dart
│   ├── cache_service.dart
│   ├── settings_service.dart
│   ├── email_domain_service.dart
│   └── optimized_data_service.dart
├── widgets/                          # Reusable widgets
│   ├── custom_drawer.dart
│   ├── navigation_drawer.dart
│   ├── custom_text_field.dart
│   ├── borang_b_bottom_sheet.dart
│   ├── header.dart
│   └── loading_overlay.dart
└── utils/                            # Utilities & constants
    ├── constants.dart                # Route names, app constants
    ├── app_colors.dart
    ├── theme.dart / theme_helper.dart
    ├── validators.dart
    ├── date_utils.dart
    ├── responsive.dart
    └── keyboard_utils.dart

assets/
├── SAB Ministerial Pastoral Monthly Report-New - Borang A & B.xlsx
├── churches_SAB.json
├── NSM_Churches_Updated.json
├── NSM STAFF.json
├── sabah_mission_staff.csv
├── Special_events.pdf
└── special_events_2025.json

functions/
└── index.js                          # Firebase Cloud Functions
```

## Getting Started

### Prerequisites

- Flutter SDK (3.x stable)
- Firebase project with Firestore and Auth enabled
- Android Studio or Xcode for mobile builds

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd pastor_report-latest
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Place your `google-services.json` in `android/app/`
   - Place your `GoogleService-Info.plist` in `ios/Runner/`
   - Update `lib/firebase_options.dart` with your project config

4. Run the app:
```bash
flutter run
```

## Building for Production

### Android
```bash
flutter build appbundle --release
```

Signing is configured via `android/key.properties`. See `upload-keystore.jks` for the keystore.

### iOS
```bash
flutter build ipa --release
```

### Web
```bash
flutter build web --release
```

## Firebase Security Rules

Firestore security rules are in `firestore.rules`. They enforce role-based access:
- Users can only read/write their own data
- Mission-scoped reads for staff and resources
- Admin and SuperAdmin have elevated write access

## Version

Current Version: **3.0.8+19**

## License

Copyright © 2025 HaweeInc. All rights reserved.
