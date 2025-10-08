import 'package:firebase_core/firebase_core.dart';
import 'package:pastor_report/firebase_options.dart';
import 'package:pastor_report/services/data_import_service.dart';

void main() async {
  print('🚀 Starting NSM Staff Data Import...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('📝 Initializing Data Import Service...');
    final dataImportService = DataImportService();

    print('👥 Importing NSM Staff Data...');
    final result = await dataImportService.importNSMStaffData();

    print('✅ Import completed successfully!');
    print('📊 Results:');
    print('   - Staff Created: ${result['staffCreated']}');
    print('   - Staff Skipped: ${result['staffSkipped']}');
    print('   - Total Imported: ${result['totalImported']}');
  } catch (e) {
    print('❌ Error during import: $e');
    rethrow;
  }
}
