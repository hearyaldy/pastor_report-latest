# Firebase Setup Guide for Pastor Report App

## Prerequisites
- Flutter SDK installed
- Firebase account (https://firebase.google.com/)
- Firebase CLI installed: `npm install -g firebase-tools`

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `pastor-report` (or your preferred name)
4. Follow the setup wizard (disable Google Analytics if not needed)

## Step 2: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

## Step 3: Configure Firebase for Your Flutter App

Run this command in your project root:

```bash
flutterfire configure
```

This will:
- Ask you to select your Firebase project
- Generate `firebase_options.dart` file
- Configure Firebase for iOS and Android

Select the platforms you want to support (iOS, Android, Web).

## Step 4: Update main.dart to Use Firebase Options

After running `flutterfire configure`, update `lib/main.dart`:

```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const PastorReportApp());
}
```

## Step 5: Enable Authentication in Firebase Console

1. Go to Firebase Console > Your Project
2. Click "Authentication" in left sidebar
3. Click "Get Started"
4. Go to "Sign-in method" tab
5. Enable "Email/Password" provider
6. Save

## Step 6: Set Up Firestore Database

1. In Firebase Console, click "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (or production mode with rules)
4. Select a Cloud Firestore location closest to you
5. Click "Enable"

### Firestore Security Rules

Go to "Rules" tab and update with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can read/write their own document
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Admin only can update isAdmin field
    match /users/{userId} {
      allow update: if request.auth != null &&
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
  }
}
```

## Step 7: Create Initial Admin User

### Option 1: Using Firebase Console

1. Go to Authentication > Users
2. Click "Add user"
3. Enter email and password
4. Note the UID

Then go to Firestore Database:
1. Click "Start collection" and name it `users`
2. Document ID: Use the UID from step 3
3. Add fields:
   - `email`: (string) admin email
   - `displayName`: (string) "Admin Name"
   - `isAdmin`: (boolean) true
4. Save

### Option 2: Using Code (Development Only)

Create a temporary registration screen or use this one-time setup:

```dart
// Run this once to create admin
await AuthProvider().register(
  email: 'admin@pastorreport.com',
  password: 'YourSecurePassword123!',
  displayName: 'Admin',
  isAdmin: true,
);
```

## Step 8: Android Configuration

The FlutterFire CLI should have handled this, but verify:

1. Check `android/app/google-services.json` exists
2. Check `android/build.gradle` has:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

3. Check `android/app/build.gradle` has at bottom:
```gradle
apply plugin: 'com.google.gms.google-services'
```

## Step 9: iOS Configuration

1. Check `ios/Runner/GoogleService-Info.plist` exists
2. Open `ios/Runner.xcworkspace` in Xcode
3. Verify GoogleService-Info.plist is added to the project

## Step 10: Test the Setup

1. Run `flutter pub get`
2. Run the app: `flutter run`
3. Try to sign in (should fail since no users yet)
4. Create an admin user using Firebase Console
5. Sign in with the admin credentials

## Troubleshooting

### Firebase not initialized error
- Make sure `Firebase.initializeApp()` is called before `runApp()`
- Ensure `firebase_options.dart` is generated and imported

### Authentication errors
- Check Firebase Console > Authentication is enabled
- Verify email/password provider is enabled

### Firestore permission denied
- Check Firestore security rules
- Ensure user is authenticated

### iOS build errors
- Run `cd ios && pod install`
- Clean build: `flutter clean && flutter pub get`

## Next Steps

- [ ] Set up proper Firestore security rules for production
- [ ] Enable password reset emails
- [ ] Configure email templates in Firebase Console
- [ ] Set up Firebase App Check for security
- [ ] Enable Firebase Analytics (optional)
- [ ] Set up Firebase Crashlytics (recommended)

## User Management

To create new users:
1. Admin creates user in Firebase Console > Authentication
2. Admin manually adds user document in Firestore with `isAdmin: false`
3. User receives email and can sign in

Or implement a registration screen (ensure proper authorization).
