import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility to check and fix staff records with invalid region/district IDs
class StaffRegionDistrictFixer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check all staff records and report invalid region/district IDs
  static Future<Map<String, dynamic>> analyzeStaffRecords() async {
    debugPrint('🔍 Analyzing staff records for invalid region/district IDs...');

    final results = {
      'total_staff': 0,
      'staff_with_region': 0,
      'staff_with_district': 0,
      'invalid_regions': <Map<String, dynamic>>[],
      'invalid_districts': <Map<String, dynamic>>[],
      'valid_regions': 0,
      'valid_districts': 0,
    };

    try {
      // Get all staff
      final staffSnapshot = await _firestore.collection('staff').get();
      results['total_staff'] = staffSnapshot.docs.length;

      // Get all regions and districts for validation
      final regionsSnapshot = await _firestore.collection('regions').get();
      final districtsSnapshot = await _firestore.collection('districts').get();

      final validRegionIds =
          regionsSnapshot.docs.map((doc) => doc.id).toSet();
      final validDistrictIds =
          districtsSnapshot.docs.map((doc) => doc.id).toSet();

      debugPrint('📊 Found ${validRegionIds.length} valid regions');
      debugPrint('📊 Found ${validDistrictIds.length} valid districts');

      // Check each staff record
      for (var staffDoc in staffSnapshot.docs) {
        final data = staffDoc.data();
        final staffName = data['name'] ?? 'Unknown';
        final regionId = data['region'] as String?;
        final districtId = data['district'] as String?;
        final mission = data['mission'] ?? 'Unknown';

        // Check region
        if (regionId != null && regionId.isNotEmpty) {
          results['staff_with_region'] =
              (results['staff_with_region'] as int) + 1;

          if (!validRegionIds.contains(regionId)) {
            (results['invalid_regions'] as List).add({
              'staff_id': staffDoc.id,
              'staff_name': staffName,
              'mission': mission,
              'invalid_region_id': regionId,
            });
          } else {
            results['valid_regions'] = (results['valid_regions'] as int) + 1;
          }
        }

        // Check district
        if (districtId != null && districtId.isNotEmpty) {
          results['staff_with_district'] =
              (results['staff_with_district'] as int) + 1;

          if (!validDistrictIds.contains(districtId)) {
            (results['invalid_districts'] as List).add({
              'staff_id': staffDoc.id,
              'staff_name': staffName,
              'mission': mission,
              'invalid_district_id': districtId,
            });
          } else {
            results['valid_districts'] = (results['valid_districts'] as int) + 1;
          }
        }
      }

      // Print summary
      debugPrint('\n📋 ANALYSIS SUMMARY:');
      debugPrint('Total Staff: ${results['total_staff']}');
      debugPrint('Staff with Region: ${results['staff_with_region']}');
      debugPrint('Staff with District: ${results['staff_with_district']}');
      debugPrint('Valid Regions: ${results['valid_regions']}');
      debugPrint('Valid Districts: ${results['valid_districts']}');
      debugPrint(
          'Invalid Regions: ${(results['invalid_regions'] as List).length}');
      debugPrint(
          'Invalid Districts: ${(results['invalid_districts'] as List).length}');

      if ((results['invalid_regions'] as List).isNotEmpty) {
        debugPrint('\n⚠️ STAFF WITH INVALID REGION IDs:');
        for (var invalid in (results['invalid_regions'] as List)) {
          debugPrint(
              '  - ${invalid['staff_name']} (${invalid['mission']}): ${invalid['invalid_region_id']}');
        }
      }

      if ((results['invalid_districts'] as List).isNotEmpty) {
        debugPrint('\n⚠️ STAFF WITH INVALID DISTRICT IDs:');
        for (var invalid in (results['invalid_districts'] as List)) {
          debugPrint(
              '  - ${invalid['staff_name']} (${invalid['mission']}): ${invalid['invalid_district_id']}');
        }
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error analyzing staff records: $e');
      rethrow;
    }
  }

  /// Clear invalid region/district IDs from staff records
  static Future<int> clearInvalidIds() async {
    debugPrint('🧹 Clearing invalid region/district IDs from staff records...');

    int updatedCount = 0;

    try {
      final analysis = await analyzeStaffRecords();
      final invalidRegions = analysis['invalid_regions'] as List;
      final invalidDistricts = analysis['invalid_districts'] as List;

      // Clear invalid regions
      for (var invalid in invalidRegions) {
        final staffId = invalid['staff_id'] as String;
        await _firestore.collection('staff').doc(staffId).update({
          'region': null,
        });
        updatedCount++;
        debugPrint(
            'Cleared invalid region for ${invalid['staff_name']}: ${invalid['invalid_region_id']}');
      }

      // Clear invalid districts
      for (var invalid in invalidDistricts) {
        final staffId = invalid['staff_id'] as String;
        await _firestore.collection('staff').doc(staffId).update({
          'district': null,
        });
        updatedCount++;
        debugPrint(
            'Cleared invalid district for ${invalid['staff_name']}: ${invalid['invalid_district_id']}');
      }

      debugPrint('✅ Cleared $updatedCount invalid IDs');
      return updatedCount;
    } catch (e) {
      debugPrint('❌ Error clearing invalid IDs: $e');
      rethrow;
    }
  }

  /// List all valid regions and districts by mission
  static Future<void> listValidRegionsAndDistricts() async {
    debugPrint('\n📚 LISTING VALID REGIONS AND DISTRICTS BY MISSION:');

    try {
      final regionsSnapshot = await _firestore.collection('regions').get();
      final districtsSnapshot = await _firestore.collection('districts').get();
      final missionsSnapshot = await _firestore.collection('missions').get();

      // Group by mission
      for (var missionDoc in missionsSnapshot.docs) {
        final missionName = missionDoc.data()['name'] ?? missionDoc.id;
        debugPrint('\n🏢 Mission: $missionName (${missionDoc.id})');

        // Find regions for this mission
        final missionRegions = regionsSnapshot.docs.where((doc) {
          final data = doc.data();
          return data['missionId'] == missionDoc.id ||
              data['mission'] == missionDoc.id ||
              data['missionId'] == missionName ||
              data['mission'] == missionName;
        }).toList();

        if (missionRegions.isNotEmpty) {
          debugPrint('  Regions (${missionRegions.length}):');
          for (var region in missionRegions) {
            debugPrint('    - ${region.data()['name']} (ID: ${region.id})');
          }
        }

        // Find districts for this mission
        final missionDistricts = districtsSnapshot.docs.where((doc) {
          final data = doc.data();
          return data['missionId'] == missionDoc.id ||
              data['mission'] == missionDoc.id ||
              data['missionId'] == missionName ||
              data['mission'] == missionName;
        }).toList();

        if (missionDistricts.isNotEmpty) {
          debugPrint('  Districts (${missionDistricts.length}):');
          for (var district in missionDistricts) {
            debugPrint('    - ${district.data()['name']} (ID: ${district.id})');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error listing regions and districts: $e');
    }
  }
}
