# Firestore Security Rules for Mission-Based Structure

This document explains the Firestore security rules configured for the Pastor Report application's mission-based data structure.

## Overview

The security rules have been updated to support both the legacy flat department structure and the new hierarchical mission-based structure. The rules implement several levels of access control:

1. Public access for reading department/mission information
2. Admin-only access for creating/updating missions and departments
3. User-specific permissions based on mission membership
4. Potential for future report-level permissions

## Rule Structure

### Helper Functions

```javascript
// Checks if a user is authenticated
function isAuthenticated() {
  return request.auth != null;
}

// Checks if a user has admin privileges
function isAdmin() {
  return isAuthenticated() &&
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
}

// Checks if a user belongs to a specific mission
function isMissionMember(missionName) {
  return isAuthenticated() &&
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.mission == missionName;
}
```

### Collection Rules

#### Users Collection

- Any authenticated user can read user documents
- Users can create and update their own documents
- Only admins can change the isAdmin field
- Only admins can delete user documents

#### Departments Collection (Legacy)

- Anyone can read departments
- Only admins can create, update, or delete departments

#### Missions Collection (New Structure)

- Anyone can read mission details
- Only admins can create, update, or delete missions

#### Departments Subcollection (within Missions)

- Anyone can read mission departments
- Only admins can create, update, or delete departments

#### Future: Reports Subcollection

- Only mission members and admins can read mission reports
- Only mission members and admins can create reports
- Only report creators and admins can update or delete reports

## Access Control Matrix

| Action | Public | Authenticated User | Mission Member | Admin |
|--------|--------|-------------------|---------------|-------|
| Read Departments | ✓ | ✓ | ✓ | ✓ |
| Create/Update/Delete Departments | ✗ | ✗ | ✗ | ✓ |
| Read Missions | ✓ | ✓ | ✓ | ✓ |
| Create/Update/Delete Missions | ✗ | ✗ | ✗ | ✓ |
| Read Mission Departments | ✓ | ✓ | ✓ | ✓ |
| Create/Update/Delete Mission Departments | ✗ | ✗ | ✗ | ✓ |
| Read Mission Reports | ✗ | ✗ | ✓ | ✓ |
| Create Mission Reports | ✗ | ✗ | ✓ | ✓ |
| Update/Delete Own Reports | ✗ | ✗ | ✓ | ✓ |
| Update/Delete Any Report | ✗ | ✗ | ✗ | ✓ |

## Security Considerations

1. The rules assume that department and mission data is not sensitive and can be publicly read
2. Create, update, and delete operations are restricted to admin users
3. Future report data is protected at the mission level
4. User data is protected but allows for profile management

## Testing Rules

To test these rules:

1. Try accessing missions collection as an unauthenticated user (should allow read)
2. Try modifying missions as a non-admin user (should deny)
3. Try modifying missions as an admin user (should allow)
4. Check mission-specific report access with users from different missions

## Future Enhancements

1. Role-based access control within missions
2. Time-limited access tokens for temporary access
3. Rate limiting for report submissions
4. Audit logging for admin actions