import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to update user and staff region references after region UUID migration
class UserStaffRegionMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update all users and staff to use correct region IDs
  ///
  /// This handles cases where:
  /// 1. Region field contains old semantic ID (e.g., "nsm_region_1")
  /// 2. Region field contains region name (e.g., "Region 1")
  /// 3. Region field contains wrong UUID
  ///
  /// The migration will:
  /// - Find the correct region by matching against name, old ID, or partial match
  /// - Update the user/staff record with the correct region UUID
  Future<Map<String, dynamic>> migrateUserAndStaffRegionReferences() async {
    try {
      debugPrint('UserStaffRegionMigration: Starting migration...');

      // Get all regions to build a lookup map
      final regionsSnapshot = await _firestore.collection('regions').get();
      final regions = <String, Map<String, String>>{}; // regionId -> {name, missionId}
      final regionsByName = <String, String>{}; // regionName -> regionId
      final regionsByOldPattern = <String, String>{}; // pattern match -> regionId

      for (var doc in regionsSnapshot.docs) {
        final data = doc.data();
        final regionId = doc.id;
        final regionName = data['name'] as String?;
        final missionId = data['missionId'] as String?;

        if (regionName != null) {
          regions[regionId] = {
            'name': regionName,
            'missionId': missionId ?? '',
          };
          regionsByName[regionName.toLowerCase()] = regionId;

          // Also map common patterns (e.g., "Region 1" -> both UUID and old ID)
          final normalized = regionName.toLowerCase().replaceAll(' ', '');
          if (!regionsByOldPattern.containsKey(normalized)) {
            regionsByOldPattern[normalized] = regionId;
          }
        }
      }

      debugPrint('  Found ${regions.length} regions');

      int usersUpdated = 0;
      int staffUpdated = 0;
      int usersSkipped = 0;
      int staffSkipped = 0;

      // === Migrate Users ===
      debugPrint('\n=== Migrating Users ===');
      final usersSnapshot = await _firestore.collection('users').get();
      debugPrint('  Found ${usersSnapshot.docs.length} users');

      for (var userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final currentRegion = data['region'] as String?;

        if (currentRegion == null || currentRegion.isEmpty) {
          continue; // Skip users without region
        }

        // Check if current region value is valid
        if (regions.containsKey(currentRegion)) {
          usersSkipped++;
          continue; // Already has correct UUID
        }

        // Try to find the correct region
        String? correctRegionId;

        // 1. Try exact name match (case-insensitive)
        correctRegionId = regionsByName[currentRegion.toLowerCase()];

        // 2. Try pattern match (e.g., "Region1" or "region_1")
        if (correctRegionId == null) {
          final normalized = currentRegion.toLowerCase().replaceAll(' ', '');
          correctRegionId = regionsByOldPattern[normalized];
        }

        // 3. Try partial match in region names
        if (correctRegionId == null) {
          for (var entry in regions.entries) {
            final regionName = entry.value['name']!.toLowerCase();
            if (regionName.contains(currentRegion.toLowerCase()) ||
                currentRegion.toLowerCase().contains(regionName)) {
              correctRegionId = entry.key;
              break;
            }
          }
        }

        // 4. Try extracting number and matching (e.g., "nsm_region_5" -> "Region 5")
        if (correctRegionId == null) {
          final numberMatch = RegExp(r'\d+').firstMatch(currentRegion);
          if (numberMatch != null) {
            final number = numberMatch.group(0)!;
            for (var entry in regions.entries) {
              final regionName = entry.value['name']!.toLowerCase();
              if (regionName.contains('region $number') ||
                  regionName.contains('region$number')) {
                correctRegionId = entry.key;
                break;
              }
            }
          }
        }

        if (correctRegionId != null) {
          // Update the user with correct region ID
          await _firestore.collection('users').doc(userDoc.id).update({
            'region': correctRegionId,
          });

          debugPrint('  ✓ User ${data['email']}: "$currentRegion" → "${regions[correctRegionId]!['name']}"');
          usersUpdated++;
        } else {
          debugPrint('  ⚠ User ${data['email']}: Could not resolve "$currentRegion"');
          usersSkipped++;
        }
      }

      // === Migrate Staff ===
      debugPrint('\n=== Migrating Staff ===');
      final staffSnapshot = await _firestore.collection('staff').get();
      debugPrint('  Found ${staffSnapshot.docs.length} staff members');

      for (var staffDoc in staffSnapshot.docs) {
        final data = staffDoc.data();
        final currentRegion = data['region'] as String?;

        if (currentRegion == null || currentRegion.isEmpty) {
          continue; // Skip staff without region
        }

        // Check if current region value is valid
        if (regions.containsKey(currentRegion)) {
          staffSkipped++;
          continue; // Already has correct UUID
        }

        // Try to find the correct region
        String? correctRegionId;

        // 1. Try exact name match (case-insensitive)
        correctRegionId = regionsByName[currentRegion.toLowerCase()];

        // 2. Try pattern match
        if (correctRegionId == null) {
          final normalized = currentRegion.toLowerCase().replaceAll(' ', '');
          correctRegionId = regionsByOldPattern[normalized];
        }

        // 3. Try partial match in region names
        if (correctRegionId == null) {
          for (var entry in regions.entries) {
            final regionName = entry.value['name']!.toLowerCase();
            if (regionName.contains(currentRegion.toLowerCase()) ||
                currentRegion.toLowerCase().contains(regionName)) {
              correctRegionId = entry.key;
              break;
            }
          }
        }

        // 4. Try extracting number and matching
        if (correctRegionId == null) {
          final numberMatch = RegExp(r'\d+').firstMatch(currentRegion);
          if (numberMatch != null) {
            final number = numberMatch.group(0)!;
            for (var entry in regions.entries) {
              final regionName = entry.value['name']!.toLowerCase();
              if (regionName.contains('region $number') ||
                  regionName.contains('region$number')) {
                correctRegionId = entry.key;
                break;
              }
            }
          }
        }

        if (correctRegionId != null) {
          // Update the staff with correct region ID
          await _firestore.collection('staff').doc(staffDoc.id).update({
            'region': correctRegionId,
          });

          debugPrint('  ✓ Staff ${data['name']}: "$currentRegion" → "${regions[correctRegionId]!['name']}"');
          staffUpdated++;
        } else {
          debugPrint('  ⚠ Staff ${data['name']}: Could not resolve "$currentRegion"');
          staffSkipped++;
        }
      }

      debugPrint('\n=== Migration Complete ===');
      debugPrint('  Users: $usersUpdated updated, $usersSkipped skipped/unresolved');
      debugPrint('  Staff: $staffUpdated updated, $staffSkipped skipped/unresolved');

      return {
        'success': true,
        'message': 'Migration completed successfully',
        'usersUpdated': usersUpdated,
        'usersSkipped': usersSkipped,
        'staffUpdated': staffUpdated,
        'staffSkipped': staffSkipped,
        'totalUpdated': usersUpdated + staffUpdated,
      };
    } catch (e) {
      debugPrint('UserStaffRegionMigration ERROR: $e');
      return {
        'success': false,
        'message': 'Error during migration: $e',
      };
    }
  }
}
