# Pastor Report

A comprehensive church management application for tracking pastoral activities, events, appointments, and generating monthly reports (Borang B).

## Features

- **User Authentication** - Secure login and registration with Firebase Auth
- **Dashboard** - Modern UI with quick access to events and appointments
- **Department Management** - Organize church activities by departments
- **Mission-Based Structure** - Filter and manage content by mission stations
- **Borang B Reports** - Generate monthly pastoral activity reports
- **Profile Management** - User profiles with admin access controls
- **Offline Support** - Works with Firebase offline persistence

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase account and project setup
- Android Studio / Xcode for mobile development

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
   - See [docs/firebase/FIREBASE_SETUP.md](docs/firebase/FIREBASE_SETUP.md) for detailed setup instructions

4. Run the app:
```bash
flutter run
```

## Documentation

### Firebase
- [Firebase Setup Guide](docs/firebase/FIREBASE_SETUP.md)
- [Firebase Status](docs/firebase/FIREBASE_STATUS.md)
- [Firestore Security Rules](docs/firebase/FIRESTORE_SECURITY_RULES.md)
- [Firebase Optimization](docs/firebase/FIREBASE_OPTIMIZATION.md)

### UI & Dashboard
- [Modern UI Update](docs/ui/MODERN_UI_UPDATE.md)
- [Dashboard Guide](docs/ui/MODERN_DASHBOARD_GUIDE.md)
- [Quick Start Guide](docs/ui/QUICK_START_NEW_UI.md)
- [Release Notes v2.0.0](docs/ui/RELEASE_NOTES_v2.0.0.md)

### Features
- [Mission & Department System](docs/features/MISSION_DEPARTMENT_IMPLEMENTATION.md)
- [Department README](docs/features/DEPARTMENT_README.md)
- [Borang B Feature](docs/features/BORANG_B_FEATURE.md)
- [Mission Filtering](docs/features/MISSION_FILTERING_SUMMARY.md)

### Implementation Guides
- [Quick Start](docs/guides/QUICK_START.md)
- [Implementation Guide](docs/guides/README_IMPLEMENTATION.md)
- [Cache Guide](docs/guides/QUICK_CACHE_GUIDE.md)

## Building for Production

### Android
```bash
flutter build appbundle --release
```

The app is configured with production signing. See the keystore configuration in `android/key.properties`.

### iOS
```bash
flutter build ipa --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # UI screens
├── services/                 # Business logic and Firebase services
├── models/                   # Data models
└── widgets/                  # Reusable widgets

docs/
├── firebase/                 # Firebase documentation
├── ui/                       # UI/UX documentation
├── features/                 # Feature documentation
└── guides/                   # Implementation guides
```

## Tech Stack

- **Framework:** Flutter
- **Backend:** Firebase (Firestore, Auth)
- **State Management:** Provider
- **UI:** Material Design 3

## Version

Current Version: **2.0.0+2**

## License

Copyright © 2025 HaweeInc. All rights reserved.

## Support

For issues and questions, please refer to the documentation in the `docs/` folder.
