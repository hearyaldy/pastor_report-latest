import 'package:firebase_core/firebase_core.dart';
import 'package:pastor_report/services/user_staff_region_migration_service.dart';
import 'package:pastor_report/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Starting User/Staff Region Migration...\n');

  final migrationService = UserStaffRegionMigrationService();
  final result = await migrationService.migrateUserAndStaffRegionReferences();

  if (result['success'] == true) {
    print('\n✅ Migration Completed Successfully!');
    print('  Users Updated: ${result['usersUpdated']}');
    print('  Staff Updated: ${result['staffUpdated']}');
    print('  Total Updated: ${result['totalUpdated']}');
  } else {
    print('\n❌ Migration Failed: ${result['message']}');
  }
}
