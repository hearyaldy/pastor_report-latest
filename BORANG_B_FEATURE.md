# Borang B Export Feature

## Overview
This document describes the new Borang B export feature that uses the Excel template "SAB Ministerial Pastoral Monthly Report-New - Borang A & B.xlsx" to generate monthly pastoral reports.

## What's New

### 1. Template Integration
- Added the Excel template to `assets/` folder
- Registered the template in `pubspec.yaml`
- Template path: `assets/SAB Ministerial Pastoral Monthly Report-New - Borang A & B.xlsx`

### 2. New Service: BorangBService
**File:** `lib/services/borang_b_service.dart`

**Features:**
- Loads the Excel template from assets
- Automatically detects the "Borang B" sheet (or uses second/first sheet as fallback)
- Fills the template with:
  - Pastor information (name, position, mission)
  - Month/year
  - All activities with dates, descriptions, locations
  - Mileage and cost calculations
  - Summary totals
- Generates a properly formatted Excel file ready for submission

**Key Methods:**
- `generateBorangB()` - Main method to generate the report
- `downloadTemplate()` - Download blank template for reference
- `getReportPreview()` - Get preview data before exporting

### 3. Updated Activities Screen
**File:** `lib/screens/activities_list_screen.dart`

**Changes:**
- Added import for `BorangBService`
- Added `_exportToBorangB()` method
- Converted export buttons to a PopupMenuButton with three options:
  1. 📄 Export to PDF
  2. 📊 Export to Excel
  3. 📋 Export Borang B (NEW!)

## How to Use

### For Users:
1. Go to "My Activities" screen
2. Ensure you have activities for the month you want to export
3. Tap the download icon (⬇️) in the app bar
4. Select "Export Borang B"
5. The app will:
   - Generate the report using the template
   - Fill in all your information
   - Open share dialog to save or share the file

### For Developers:

#### Using the Service Directly:
```dart
import 'package:pastor_report/services/borang_b_service.dart';

// Generate Borang B
final file = await BorangBService.instance.generateBorangB(
  activities: myActivities,
  user: currentUser,
  kmCost: 0.50,
  month: DateTime(2025, 10),
);

// Share or save the file
await Share.shareXFiles([XFile(file.path)]);
```

#### Get Preview Data:
```dart
final preview = BorangBService.instance.getReportPreview(
  activities: myActivities,
  user: currentUser,
  kmCost: 0.50,
  month: DateTime(2025, 10),
);

print(preview['totalActivities']); // Number of activities
print(preview['totalKm']); // Total kilometers
print(preview['totalCost']); // Total cost
```

## Template Structure

### Expected Sheet Layout:
The service attempts to populate the following cells (adjust as needed):

| Cell | Content |
|------|---------|
| B2 | Pastor Name |
| B3 | Position/Role |
| B4 | Mission |
| B5 | Month & Year |
| A8+ | Activity Dates |
| B8+ | Activity Descriptions |
| C8+ | Locations |
| D8+ | Mileage (km) |
| E8+ | Cost (RM) |

### Customization:
If your template has a different structure, update the `_fillBorangBTemplate()` method in `borang_b_service.dart`:

```dart
// Example: Change the name cell from B2 to C3
_setCellValue(sheet, 'C3', user.displayName);

// Example: Change activities start row from 7 to 9
int startRow = 9; // Activities start at row 10 (0-indexed)
```

## Data Mapping

### From Activity Model to Borang B:
- **Date**: `activity.date` → formatted as "dd/MM/yyyy"
- **Description**: `activity.activities`
- **Location**: `activity.location` (or "-" if null)
- **Mileage**: `activity.mileage` → formatted as "X.X km"
- **Cost**: `activity.calculateCost(kmCost)` → formatted as "RM X.XX"

### Calculations:
- **Total KM**: Sum of all activity mileage
- **Total Cost**: Total KM × KM Rate
- **Generated Date**: Current timestamp

## File Naming Convention
Generated files are named:
```
Borang_B_[PastorName]_[YYYY_MM].xlsx
```

Example: `Borang_B_John_Doe_2025_10.xlsx`

## Error Handling

The service includes comprehensive error handling:
- Template not found → throws exception with clear message
- Sheet not found → automatically tries alternative sheets
- Cell update errors → logs warnings but continues
- Export errors → shows user-friendly error message

## Future Enhancements

### Possible improvements:
1. **Borang A Support**: Add support for the "Borang A" sheet
2. **Custom Templates**: Allow users to upload their own templates
3. **Template Editor**: In-app template field mapping
4. **Batch Export**: Export multiple months at once
5. **Cloud Storage**: Save reports to Firebase Storage
6. **Email Integration**: Automatically email reports to admin
7. **Template Validation**: Verify template structure before export

## Testing Checklist

- [ ] Export with activities
- [ ] Export with no activities (should show error)
- [ ] Export with single activity
- [ ] Export with 50+ activities (stress test)
- [ ] Verify all cells are populated correctly
- [ ] Check calculations (total KM, total cost)
- [ ] Test share functionality
- [ ] Test on both Android and iOS
- [ ] Verify file opens correctly in Excel/Sheets
- [ ] Check for special characters in activity descriptions

## Troubleshooting

### Issue: "No sheets found in template"
- **Cause**: Excel template is corrupted or empty
- **Solution**: Re-add the template file to assets/

### Issue: Cells not populating
- **Cause**: Template structure doesn't match expected layout
- **Solution**: Update cell references in `_fillBorangBTemplate()`

### Issue: Export fails with encoding error
- **Cause**: Special characters or corrupted data
- **Solution**: Check activity descriptions for invalid characters

## Technical Notes

- Uses the `excel` package for Excel manipulation
- Template is loaded from assets as ByteData
- Sheet detection is case-insensitive ("borang b", "Form B", etc.)
- All text values are stored as TextCellValue
- Number formatting is done before insertion (as strings)

## Credits

- Template: SAB Ministerial Pastoral Monthly Report (Borang A & B)
- Developer: Claude Code
- Date: October 3, 2025
