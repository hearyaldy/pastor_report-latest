import 'package:firebase_core/firebase_core.dart';
import 'package:pastor_report/firebase_options.dart';
import 'package:pastor_report/utils/update_staff_regions_districts.dart';

void main() async {
  print('🚀 Starting Staff Region and District Update Process...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    print('✅ Firebase initialized successfully');

    // Create updater instance and run the update process
    final updater = StaffRegionDistrictUpdater();
    final results = await updater.updateStaffBasedOnUpdatedData();

    print('✅ Staff region and district update process completed!');
  } catch (e) {
    print('❌ Error during staff region and district update: $e');
    print(e.toString());
    print(e.stackTrace);
  }
}