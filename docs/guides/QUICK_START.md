# Pastor Report App - Quick Start Guide

## 🚀 Quick Setup (5 Minutes)

### Step 1: Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### Step 2: Configure Firebase
```bash
cd /Users/hearyhealdysairin/Documents/Flutter/pastor_report-latest
flutterfire configure
```

Follow the prompts:
- Select or create a Firebase project
- Select platforms (Android, iOS)
- This will generate `firebase_options.dart`

### Step 3: Enable Firebase Services

Go to [Firebase Console](https://console.firebase.google.com/):

1. **Enable Authentication**:
   - Click "Authentication" → "Get Started"
   - Go to "Sign-in method" tab
   - Enable "Email/Password"
   - Click "Save"

2. **Create Firestore Database**:
   - Click "Firestore Database" → "Create database"
   - Choose "Test mode" (for now)
   - Select a location
   - Click "Enable"

### Step 4: Update Firebase Imports in main.dart

Edit `lib/main.dart` and update line 17:

```dart
import 'firebase_options.dart'; // Add this import

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform, // Add this line
);
```

### Step 5: Create Admin User

**In Firebase Console**:
1. Go to Authentication → Users → Add user
2. Email: `admin@yourchurch.com`
3. Password: Create a secure password
4. Copy the UID (e.g., `abc123def456`)

5. Go to Firestore Database → Start collection
6. Collection ID: `users`
7. Document ID: Paste the UID from step 4
8. Add fields:
   - `email` (string): `admin@yourchurch.com`
   - `displayName` (string): `Admin`
   - `isAdmin` (boolean): `true`
9. Click "Save"

### Step 6: Run the App

```bash
flutter pub get
flutter run
```

### Step 7: Test Login

- Email: `admin@yourchurch.com`
- Password: [password you created]

## ✅ You're Done!

The app should now:
- Log you in with Firebase
- Show "ADMIN" badge
- Display all departments
- Allow you to access forms
- Let you logout

## 📝 Next Steps

1. **Add Regular Users**: Create more users in Firebase Console with `isAdmin: false`

2. **Update URLs**: Edit `lib/utils/constants.dart` to replace placeholder URLs:
   - Ministerial
   - Education
   - Publishing
   - Personal Ministry
   - Adventist Community Services

3. **Set Production Rules**: In Firestore, go to Rules tab and paste:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

4. **Build Release APK**:
```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## 🆘 Troubleshooting

### "Firebase not initialized"
- Make sure you ran `flutterfire configure`
- Check that `firebase_options.dart` exists
- Verify the import in `main.dart`

### "User not found"
- Create the user in Firebase Console
- Make sure you added the user document in Firestore

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

## 📚 Full Documentation

- [FIREBASE_SETUP.md](FIREBASE_SETUP.md) - Detailed Firebase setup
- [README_IMPLEMENTATION.md](README_IMPLEMENTATION.md) - Complete implementation details

---

Need help? Check the Firebase Console logs or run `flutter doctor -v`
