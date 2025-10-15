import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Service to migrate regions from semantic IDs to UUID-based IDs
class RegionMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Migrate all regions to use UUID-based IDs
  ///
  /// This will:
  /// 1. Find all regions with non-UUID IDs (semantic IDs like "nsm_region_1")
  /// 2. Create new region documents with UUID IDs
  /// 3. Update all districts to reference the new UUID
  /// 4. Update all churches to reference the new UUID
  /// 5. Delete the old semantic ID regions
  Future<Map<String, dynamic>> migrateRegionsToUUIDs() async {
    try {
      print('RegionMigration: Starting migration to UUID-based IDs...');

      // Get all regions
      final regionsSnapshot = await _firestore.collection('regions').get();

      print('  Found ${regionsSnapshot.docs.length} total regions');

      int migrated = 0;
      int skipped = 0;
      final migrations = <String, String>{}; // old ID -> new UUID mapping

      for (var regionDoc in regionsSnapshot.docs) {
        final oldId = regionDoc.id;
        final data = regionDoc.data();

        // Check if this is already a UUID (UUIDs have dashes)
        if (_isUUID(oldId)) {
          print('  ✓ SKIP: ${data['name']} - Already has UUID: $oldId');
          skipped++;
          continue;
        }

        // This is a semantic ID - needs migration
        final newUUID = _uuid.v4();
        migrations[oldId] = newUUID;

        print('\n  → MIGRATE: ${data['name']}');
        print('    Old ID: $oldId');
        print('    New UUID: $newUUID');

        // Create new region with UUID
        await _firestore.collection('regions').doc(newUUID).set({
          ...data,
          'id': newUUID,
        });

        print('    ✓ Created new region with UUID');

        // Update all districts that reference this region
        final districtQuery = await _firestore
            .collection('districts')
            .where('regionId', isEqualTo: oldId)
            .get();

        for (var districtDoc in districtQuery.docs) {
          await _firestore.collection('districts').doc(districtDoc.id).update({
            'regionId': newUUID,
          });
        }
        print('    ✓ Updated ${districtQuery.docs.length} districts');

        // Update all churches that reference this region
        final churchQuery = await _firestore
            .collection('churches')
            .where('regionId', isEqualTo: oldId)
            .get();

        for (var churchDoc in churchQuery.docs) {
          await _firestore.collection('churches').doc(churchDoc.id).update({
            'regionId': newUUID,
          });
        }
        print('    ✓ Updated ${churchQuery.docs.length} churches');

        // Delete the old semantic ID region
        await _firestore.collection('regions').doc(oldId).delete();
        print('    ✓ Deleted old region with semantic ID');

        migrated++;
      }

      print('\n=== Migration Complete ===');
      print('  Migrated: $migrated regions');
      print('  Skipped (already UUID): $skipped regions');
      print('  Total: ${migrated + skipped} regions');

      return {
        'success': true,
        'message': 'Migration completed successfully',
        'migrated': migrated,
        'skipped': skipped,
        'total': migrated + skipped,
        'migrations': migrations,
      };
    } catch (e) {
      print('RegionMigration ERROR: $e');
      return {
        'success': false,
        'message': 'Error during migration: $e',
      };
    }
  }

  /// Check if a string is a valid UUID format
  bool _isUUID(String id) {
    // UUIDs have format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidPattern.hasMatch(id);
  }
}
