# Cloud Functions for Pastor Report

This folder contains Firebase Cloud Functions for the Pastor Report app.

## Functions

### `deleteUserCompletely`
A callable HTTPS function that completely deletes a user from the system including:
1. All Borang B reports associated with the user
2. The user document from Firestore
3. The Firebase Authentication account

**Security:** The function checks that the caller has appropriate permissions based on the role hierarchy.

## Setup & Deployment

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Deploy to Firebase
```bash
# Make sure you're in the project root
cd ..

# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:deleteUserCompletely
```

### 3. Local Testing (Optional)
```bash
cd functions
npm run serve
```

This will start the Firebase emulator for local testing.

## Requirements
- Node.js 18 or higher
- Firebase CLI installed (`npm install -g firebase-tools`)
- Proper Firebase project configuration

## Important Notes
- The function uses Firebase Admin SDK which has elevated privileges
- Role-based access control is enforced within the function
- The function will fail if the caller doesn't have sufficient permissions
- All deletions are permanent and cannot be undone
