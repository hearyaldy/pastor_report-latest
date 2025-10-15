import 'package:firebase_core/firebase_core.dart';
import 'package:pastor_report/firebase_options.dart';
import 'package:pastor_report/services/data_import_service.dart';

void main() async {
  print('🚀 Starting Staff Database Update Process...');
  print('This will update both Sabah Mission and North Sabah Mission staff');
  print('with the corrected region and district information.');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('✅ Firebase initialized successfully');
    print('');

    // Initialize the import service
    final dataImportService = DataImportService.instance;
    
    // Update North Sabah Mission staff with corrected assignments
    print('🏢 UPDATING NORTH SABAH MISSION STAFF...');
    final nsmResult = await dataImportService.importNSMStaffData();
    print('✅ NSM Staff Import Results:');
    print('   - Staff Created: ${nsmResult['staffCreated']}');
    print('   - Staff Skipped: ${nsmResult['staffSkipped']}');
    print('   - Total Imported: ${nsmResult['totalImported']}');
    print('');

    // Update Sabah Mission staff with information from churches_SAB.json
    print('🏢 UPDATING SABAH MISSION STAFF...');
    final sabahResult = await dataImportService.importSabahStaffData();
    print('✅ Sabah Mission Staff Import Results:');
    print('   - Staff Created: ${sabahResult['staffCreated']}');
    print('   - Staff Skipped: ${sabahResult['staffSkipped']}');
    print('   - Total Imported: ${sabahResult['totalImported']}');
    print('');

    print('🎉 Staff database update completed successfully!');
    print('');
    print('📊 Summary:');
    print('   - NSM Staff Imported: ${nsmResult['totalImported']}');
    print('   - Sabah Mission Staff Imported: ${sabahResult['totalImported']}');
    print('   - Total Staff Added to Database: ${nsmResult['totalImported'] + sabahResult['totalImported']}');
  } catch (e) {
    print('❌ Error during staff database update: $e');
    print(e.toString());
    print(e.stackTrace);
  }
}