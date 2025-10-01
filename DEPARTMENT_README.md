# Mission-Based Department Management

## Overview
This feature update allows all missions to have their own set of departments with appropriate form links. This ensures that users from any mission will see departments specific to their mission when they log into the Pastor Report app.

## How It Works

### For Regular Users:
1. When you log in, the app checks your assigned mission
2. You will only see departments that belong to your specific mission
3. If no departments are found for your mission, you'll see a clear message

### For Administrators:

#### Using the Admin Utilities:
1. Log in with an admin account
2. Navigate to the Admin tab in the bottom navigation
3. Tap the tools (build) icon in the floating action button
4. This opens the Admin Utilities screen
5. Use the "Reseed Departments with Mission Data" feature to populate all missions with departments

#### What the Reseeding Does:
- Deletes all existing departments in the database
- Creates a fresh set of departments for each mission:
  - Sabah Mission
  - North Sabah Mission
  - Sarawak Mission
  - Peninsular Mission
- Each department includes:
  - Name
  - Icon
  - Form URL
  - Mission field (to associate with specific mission)

## Important Notes
- This is a one-time operation to set up mission-specific departments
- It should only be performed by an administrator
- All existing department data will be replaced with default values
- Custom form URLs will need to be updated after reseeding if they were customized

## Technical Implementation
For technical details about the implementation, refer to:
- `MISSION_DEPARTMENT_IMPLEMENTATION.md` for code changes
- `MISSION_FILTERING_SUMMARY.md` for mission filtering logic