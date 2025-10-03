import 'package:flutter/services.dart';
import 'package:pastor_report/services/staff_service.dart';

/// Import Sabah Mission staff from CSV file to Firestore
/// Run this once to populate the database
Future<void> importSabahStaff(String userId) async {
  try {
    print('📂 Loading CSV file...');

    // Load CSV from assets
    final csvData = await rootBundle.loadString('assets/sabah_mission_staff.csv');

    print('📤 Importing to Firestore...');
    print('   Created by user: $userId');

    // Import using the staff service
    final result = await StaffService.instance.importStaffFromCSV(csvData, userId);

    if (result['success']) {
      print('✅ Import successful!');
      print('   Imported: ${result['imported']} staff members');
      if (result['failed'] > 0) {
        print('   Failed: ${result['failed']}');
        if (result['errors'] != null) {
          print('   Errors:');
          for (var error in (result['errors'] as List)) {
            print('     - $error');
          }
        }
      }
    } else {
      print('❌ Import failed: ${result['message']}');
    }
  } catch (e) {
    print('❌ Error importing staff: $e');
  }
}
