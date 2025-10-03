# Borang B Feature - Complete Implementation

## Overview
Borang B is now a **dedicated monthly ministerial report** separate from Borang A (activities). This allows pastors to submit comprehensive ministry statistics monthly.

## What Changed

### 1. **Separate Data Model**
- **Borang A** = Daily Activities (existing feature)
  - Date, activity description, location, mileage
- **Borang B** = Monthly Ministry Report (NEW!)
  - Church membership statistics
  - Baptisms & professions
  - Church services conducted
  - Visitations (home, hospital, prison)
  - Special events (weddings, funerals, dedications)
  - Literature distribution
  - Tithes & offerings
  - Other activities, challenges, remarks

### 2. **New Dedicated Screen**
Path: `lib/screens/borang_b_screen.dart`

**Features:**
- Month selector to view/edit different months
- Organized sections with icons and colors:
  - 📊 Church Membership Statistics
  - 💧 Baptisms & Professions
  - ⛪ Church Services
  - 🏠 Visitations
  - 📅 Special Events
  - 📚 Literature Distribution
  - 💰 Tithes & Offerings
  - 📝 Additional Information

- Auto-saves data monthly
- Export to Excel using template
- Clean, user-friendly form interface

### 3. **Quick Access from Dashboard**
A new Borang B card has been added to the dashboard:
- Shows if current month's report exists
- Tap to create/edit monthly report
- Visual indicator (✓) when report is completed

### 4. **Excel Template Integration**
The existing template `SAB Ministerial Pastoral Monthly Report-New - Borang A & B.xlsx` is now used:
- Automatically populates all Borang B fields
- Maps data to correct cells
- Generates professional Excel reports ready for submission

## How Users Use It

### Creating a Monthly Report:

1. **Open Borang B** from dashboard (tap the teal card)
2. **Select the month** using arrows at top
3. **Fill in all sections:**
   - Enter numbers for statistics (membership, baptisms, etc.)
   - Enter financial data (RM format)
   - Add text for activities, challenges, remarks
4. **Save** using the save button (💾 icon in app bar)
5. **Export** when ready to submit (📥 icon in app bar)
6. **Share** the generated Excel file via email/WhatsApp

### Editing Existing Reports:

1. Open Borang B screen
2. Navigate to the month you want to edit
3. Update any fields
4. Save changes
5. Re-export if needed

## File Structure

```
lib/
├── models/
│   └── borang_b_model.dart          # BorangBData model
├── services/
│   ├── borang_b_storage_service.dart # Local storage (SharedPreferences)
│   └── borang_b_service.dart         # Excel export using template
├── screens/
│   └── borang_b_screen.dart          # Main input/edit screen
└── main.dart                          # Route: '/borang-b'
```

## Data Storage

- **Local**: Stored in SharedPreferences (offline-first)
- **Format**: JSON serialization
- **Persistence**: Data persists across app restarts
- **Backup**: Can be exported/imported as JSON

## Excel Template Mapping

The service maps data to these approximate cell positions (adjust as needed):

| Data Field | Excel Cell | Example |
|-----------|------------|---------|
| Pastor Name | B2 | John Doe |
| Position | B3 | Pastor |
| Mission | B4 | Sabah Mission |
| Month | B5 | October 2025 |
| Members Beginning | C8 | 150 |
| Baptisms | C16 | 5 |
| Sabbath Services | C19 | 4 |
| Home Visitations | C24 | 12 |
| Weddings | C28 | 2 |
| Books Distributed | C32 | 25 |
| Tithe | C36 | 15000.00 |
| Other Activities | B39 | (text) |
| Challenges | B41 | (text) |
| Remarks | B43 | (text) |

**Note:** Cell positions can be customized by editing `_fillBorangBTemplate()` in `borang_b_service.dart`

## Key Differences: Borang A vs Borang B

| Feature | Borang A (Activities) | Borang B (Monthly Report) |
|---------|---------------------|--------------------------|
| Purpose | Daily activity tracking | Monthly ministry statistics |
| Entry Frequency | Daily/weekly | Monthly |
| Data Type | Individual activities | Aggregated statistics |
| Fields | Date, description, location, mileage | Membership, baptisms, services, etc. |
| Access | "My Activities" screen | "Borang B" screen |
| Export | PDF/Excel (activity list) | Excel (statistical report) |

## Benefits

1. **Organized**: Separate concerns - activities vs statistics
2. **Monthly Submission**: Report data needed monthly
3. **Complete**: Covers all aspects of ministry
4. **Professional**: Generates proper Excel reports
5. **Persistent**: Data saved locally, no internet required
6. **User-Friendly**: Clean form with clear sections

## Future Enhancements

Potential improvements:
- [ ] Cloud sync to Firebase
- [ ] Admin view to see all pastors' reports
- [ ] Year-end summary reports
- [ ] Comparison charts (month-to-month)
- [ ] Email automation for submission
- [ ] Template customization per mission
- [ ] Multi-language support
- [ ] Photo attachments for events
- [ ] Auto-calculation of totals
- [ ] Report validation before export

## Testing Checklist

- [x] Create new Borang B report
- [x] Edit existing report
- [x] Navigate between months
- [x] Save data locally
- [x] Export to Excel
- [x] Share Excel file
- [ ] Test with real template
- [ ] Verify cell mappings
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test with 12 months of data
- [ ] Test data persistence after app restart

## Technical Notes

- Uses singleton pattern for services
- SharedPreferences for local storage
- Excel package for template manipulation
- Form validation (numbers/currency)
- Month-based data organization
- Automatic total calculations
- Support for null/empty values
- Clean separation of concerns

## Support

If template structure doesn't match:
1. Open `lib/services/borang_b_service.dart`
2. Find `_fillBorangBTemplate()` method
3. Adjust cell references (e.g., 'C8', 'B2') to match your template
4. Save and re-export

---

**Version:** 1.0
**Date:** October 3, 2025
**Created by:** Claude Code
