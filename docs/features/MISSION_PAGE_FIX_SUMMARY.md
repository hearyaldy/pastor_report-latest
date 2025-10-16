# Mission Page Financial Reports Fix

## Problem Identified

The Mission Page was not displaying all financial reports from churches because the `missionId` field was not being populated when financial reports were created.

### Root Cause

In `lib/screens/treasurer/treasurer_dashboard.dart` (lines 137-151), when creating a new `FinancialReport`, the following organizational hierarchy fields were being set:

- ✅ `churchId`
- ✅ `districtId`
- ✅ `regionId`
- ❌ `missionId` **MISSING**

### Impact

When the Mission Page queried for reports using:
```dart
await _financialService.getMissionAggregateByMonth(missionId, month);
```

It couldn't find any reports because the Firestore query:
```dart
.where('missionId', isEqualTo: missionId)
```

Would return no results since `missionId` was `null` in all existing reports.

## Solution Implemented

### 1. Fix Future Reports (Code Fix)

**File:** `lib/screens/treasurer/treasurer_dashboard.dart` (line 142)

Added the missing `missionId` field when creating financial reports:

```dart
final report = existingReport ??
    FinancialReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      churchId: _userChurch!.id,
      districtId: _userChurch!.districtId,
      regionId: _userChurch!.regionId,
      missionId: _userChurch!.missionId,  // ← ADDED THIS LINE
      month: _selectedMonth,
      year: _selectedMonth.year,
      // ... rest of the fields
    );
```

### 2. Fix Existing Reports (Data Migration)

**File:** `lib/screens/admin_utilities_screen.dart`

Added a new utility function accessible from the Admin Utilities screen:

**Location:** Admin Utilities → Financial Reports → "Fix Financial Reports Mission IDs"

This utility:
1. Finds all financial reports where `missionId` is `null`
2. For each report:
   - Gets the `churchId` from the report
   - Looks up the church document to find its `missionId`
   - Updates the report with the correct `missionId`
3. Provides feedback on how many reports were updated

## How to Use

### For Existing Reports

1. **Login as Admin**
2. **Navigate to:** Profile → Admin Utilities
3. **Scroll to:** Financial Reports section
4. **Click:** "Fix Financial Reports Mission IDs"
5. **Confirm** the action
6. **Wait** for the process to complete (shows progress)
7. **Verify** the Mission Page now displays all reports correctly

### For Future Reports

All new financial reports created after this fix will automatically include the `missionId` field.

## Verification Steps

After running the fix utility:

1. **Go to Mission Page** (My Mission screen)
2. **Select a month** that previously showed no data
3. **Verify** that financial data now appears:
   - Tithe amount
   - Offerings amount
   - Special offerings amount
   - Total amount
4. **Check different view levels:**
   - Mission level (shows all churches in mission)
   - District level (shows churches in selected district)
   - Church level (shows individual church data)

## Technical Details

### Database Structure

**Collection:** `financial_reports`

**Required Fields for Mission Queries:**
- `churchId` (string) - Individual church identifier
- `districtId` (string) - District the church belongs to
- `regionId` (string) - Region the district belongs to
- `missionId` (string) - **Mission the region belongs to** ← This was missing
- `month` (timestamp) - Reporting month
- `status` (string) - Report status (draft/submitted/approved)

### Query Logic

The Mission Page aggregates reports using:

```dart
await firestore
    .collection('financial_reports')
    .where('missionId', isEqualTo: missionId)
    .where('month', isGreaterThanOrEqualTo: startOfMonth)
    .where('month', isLessThanOrEqualTo: endOfMonth)
    .where('status', isEqualTo: 'submitted')
    .get();
```

Without `missionId`, this query returns 0 results.

## Files Modified

1. ✅ `lib/screens/treasurer/treasurer_dashboard.dart` - Add missionId to new reports
2. ✅ `lib/screens/admin_utilities_screen.dart` - Add fix utility for existing reports

## Testing Checklist

- [ ] Run the "Fix Financial Reports Mission IDs" utility
- [ ] Verify no errors during migration
- [ ] Check Mission Page shows financial data
- [ ] Create a new financial report as treasurer
- [ ] Verify new report includes missionId
- [ ] Verify new report appears on Mission Page immediately

## Notes

- This fix is **safe** and does not delete or modify existing financial data
- Only the `missionId` field is added/updated
- The `updatedAt` timestamp is also updated for tracking
- Reports without a valid church or mission will be skipped with a count
- The fix can be run multiple times safely (idempotent operation)

## Future Improvements

Consider adding:
1. Data validation on report creation to ensure all hierarchy fields are populated
2. Automated tests to prevent regression
3. Database migration scripts for large-scale updates
4. Logging for better debugging of report creation issues
