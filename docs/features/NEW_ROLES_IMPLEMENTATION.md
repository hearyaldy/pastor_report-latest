# Officer and Director Roles Implementation

## Overview
Added two new mission-level roles: **Officer** and **Director**. These roles have similar permissions to Ministerial Secretary - they can access mission-level data without needing to select region/district/church during onboarding.

## Changes Made

### 1. User Model (`lib/models/user_model.dart`)
- ✅ Added `officer` and `director` to `UserRole` enum
- ✅ Updated `UserRoleExtension.displayName` to return "Officer" and "Director"
- ✅ Updated `UserRoleExtension.level` to set both roles at level 3 (mission-level access)
- ✅ Updated `canManageRole()` - MissionAdmin can now assign officer and director roles
- ✅ Added getter properties: `isOfficer` and `isDirector`
- ✅ Updated `canAccessBorangBReports` to include officer and director

### 2. Onboarding Screen (`lib/screens/comprehensive_onboarding_screen.dart`)
- ✅ Added officer and director cases to `_getRoleTitle()` switch statement
- ✅ Added `_isMissionLevelRole()` helper method to identify roles that don't need region/district/church
- ✅ Updated `_completeOnboarding()` to skip region/district validation for mission-level roles
- ✅ Modified submission logic to pass null for region/district when role is mission-level

### 3. Auth Service (`lib/services/auth_service.dart`)
- ✅ Made `region` and `district` parameters optional in `completeOnboarding()` method
- ✅ Updated logic to only add region/district to Firestore if they are provided

### 4. UI Updates - Role Colors & Icons

#### Profile Screen (`lib/screens/profile_screen.dart`)
- ✅ Officer: Cyan color, Badge icon
- ✅ Director: Deep Purple color, Supervisor Account icon

#### Dashboard Screen (`lib/screens/dashboard_screen_improved.dart`)
- ✅ Officer: Cyan color, Badge icon
- ✅ Director: Deep Purple color, Supervisor Account icon

#### User Management Screen (`lib/screens/user_management_screen.dart`)
- ✅ Officer: Cyan shade 700 color, Badge icon, Description: "Mission-level officer access"
- ✅ Director: Deep Purple shade 700 color, Supervisor Account icon, Description: "Mission-level director access"

### 5. Borang B Reports Access (`lib/screens/all_borang_b_reports_screen.dart`)
- ✅ Updated `_buildMissionFilter()` to recognize officer and director as mission-level staff
- ✅ Reports are automatically filtered to user's mission for these roles

### 6. Firestore Security Rules (`firestore.rules`)
- ✅ Added `isOfficer()` helper function
- ✅ Added `isDirector()` helper function
- ✅ Updated `borang_b_reports` collection rules:
  - List permission: Added officer and director
  - Get permission: Added officer and director
  - Update permission: Added officer and director
  - Delete permission: Added officer and director

## Role Hierarchy

```
Level 1: user, churchTreasurer (Church level)
Level 2: districtPastor (District level)
Level 3: ministerialSecretary, officer, director, missionAdmin, editor (Mission level)
Level 4: admin (Organization level)
Level 5: superAdmin (Full system access)
```

## Permissions Summary

### Officer & Director Roles Can:
- ✅ Access mission-level dashboard views
- ✅ View all Borang B reports from their mission
- ✅ Update any Borang B report
- ✅ Delete any Borang B report
- ✅ Skip region/district/church selection during onboarding
- ✅ Access "All Borang B Reports" screen with automatic mission filtering

### Officer & Director Roles Cannot:
- ❌ Assign roles to other users (only MissionAdmin and above can)
- ❌ Access admin-level features
- ❌ View reports from other missions (automatically filtered)

## Usage Guide

### For Admins Assigning Roles:
1. Navigate to User Management
2. Select a user
3. Choose "Officer" or "Director" from role dropdown
4. User will automatically get mission-level access

### For Users with Officer/Director Role:
1. During onboarding, they only need to:
   - Select their role
   - Their mission is already assigned
   - No need to select region/district/church
2. After onboarding:
   - Dashboard shows "All Borang B Reports" card
   - Can view all reports from their mission
   - Can manage (edit/delete) reports as needed

## Testing Checklist

- [ ] Assign Officer role to a test user
- [ ] Verify onboarding skips region/district/church selection
- [ ] Verify "All Borang B Reports" card appears on dashboard
- [ ] Verify reports are filtered to user's mission only
- [ ] Test report viewing, editing, and deleting permissions
- [ ] Repeat tests for Director role
- [ ] Verify role displays correctly in profile and dashboard
- [ ] Test that MissionAdmin can assign these roles
- [ ] Verify Firestore security rules allow appropriate access

## Migration Notes

**No database migration needed!** Existing users are not affected. New officer and director roles can be assigned immediately through the user management interface.

## Future Enhancements (Optional)

- Consider adding role-specific dashboard cards
- Add analytics/reporting features for mission-level staff
- Create role-specific notification preferences
- Add audit logging for actions performed by officer/director roles
