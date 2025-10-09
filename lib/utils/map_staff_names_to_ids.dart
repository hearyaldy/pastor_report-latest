import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility to map staff district/region names to correct IDs
class StaffNameToIdMapper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Map staff district/region names to correct Firestore IDs
  static Future<Map<String, dynamic>> mapNamesToIds() async {
    debugPrint('🔄 Mapping staff district/region names to IDs...');

    final results = {
      'total_staff': 0,
      'staff_updated': 0,
      'staff_skipped': 0,
      'errors': <String>[],
    };

    try {
      // Get all regions and districts with their names
      final regionsSnapshot = await _firestore.collection('regions').get();
      final districtsSnapshot = await _firestore.collection('districts').get();

      // Create name-to-ID mappings (case-insensitive)
      final Map<String, String> regionNameToId = {};
      final Map<String, String> districtNameToId = {};

      for (var doc in regionsSnapshot.docs) {
        final name = (doc.data()['name'] ?? '').toString().toUpperCase();
        if (name.isNotEmpty) {
          regionNameToId[name] = doc.id;
        }
      }

      for (var doc in districtsSnapshot.docs) {
        final name = (doc.data()['name'] ?? '').toString().toUpperCase();
        if (name.isNotEmpty) {
          districtNameToId[name] = doc.id;
        }
      }

      debugPrint('📊 Built mappings:');
      debugPrint('  Regions: ${regionNameToId.length}');
      debugPrint('  Districts: ${districtNameToId.length}');

      // Get all staff
      final staffSnapshot = await _firestore.collection('staff').get();
      results['total_staff'] = staffSnapshot.docs.length;

      // Process each staff
      for (var staffDoc in staffSnapshot.docs) {
        try {
          final data = staffDoc.data();
          final staffName = data['name'] ?? 'Unknown';
          final regionValue = data['region'] as String?;
          final districtValue = data['district'] as String?;

          bool needsUpdate = false;
          final Map<String, dynamic> updates = {};

          // Check if region is a name (not a UUID)
          if (regionValue != null && regionValue.isNotEmpty) {
            // UUIDs contain dashes, names don't (usually)
            if (!regionValue.contains('-')) {
              // It's likely a name, try to map it
              final regionKey = regionValue.toUpperCase();
              if (regionNameToId.containsKey(regionKey)) {
                updates['region'] = regionNameToId[regionKey];
                needsUpdate = true;
                debugPrint(
                    '  ✓ $staffName: Region "$regionValue" → ${regionNameToId[regionKey]}');
              } else {
                debugPrint('  ⚠️ $staffName: No match for region "$regionValue"');
              }
            }
          }

          // Check if district is a name (not a UUID)
          if (districtValue != null && districtValue.isNotEmpty) {
            // UUIDs contain dashes, names don't (usually)
            if (!districtValue.contains('-')) {
              // It's likely a name, try to map it
              final districtKey = districtValue.toUpperCase();
              if (districtNameToId.containsKey(districtKey)) {
                updates['district'] = districtNameToId[districtKey];
                needsUpdate = true;
                debugPrint(
                    '  ✓ $staffName: District "$districtValue" → ${districtNameToId[districtKey]}');
              } else {
                // Try with underscores replaced by spaces
                final districtKeyAlt = districtKey.replaceAll('_', ' ');
                if (districtNameToId.containsKey(districtKeyAlt)) {
                  updates['district'] = districtNameToId[districtKeyAlt];
                  needsUpdate = true;
                  debugPrint(
                      '  ✓ $staffName: District "$districtValue" → ${districtNameToId[districtKeyAlt]}');
                } else {
                  debugPrint(
                      '  ⚠️ $staffName: No match for district "$districtValue"');
                }
              }
            }
          }

          // Update if needed
          if (needsUpdate) {
            await _firestore
                .collection('staff')
                .doc(staffDoc.id)
                .update(updates);
            results['staff_updated'] = (results['staff_updated'] as int) + 1;
          } else {
            results['staff_skipped'] = (results['staff_skipped'] as int) + 1;
          }
        } catch (e) {
          (results['errors'] as List)
              .add('Error updating ${staffDoc.id}: $e');
          debugPrint('  ❌ Error updating ${staffDoc.id}: $e');
        }
      }

      debugPrint('\n✅ MAPPING COMPLETE:');
      debugPrint('Total Staff: ${results['total_staff']}');
      debugPrint('Staff Updated: ${results['staff_updated']}');
      debugPrint('Staff Skipped: ${results['staff_skipped']}');
      debugPrint('Errors: ${(results['errors'] as List).length}');

      return results;
    } catch (e) {
      debugPrint('❌ Error mapping names to IDs: $e');
      rethrow;
    }
  }

  /// Preview what would be mapped without updating
  static Future<void> previewMapping() async {
    debugPrint('👁️ PREVIEW: What would be mapped...\n');

    try {
      // Get all regions and districts with their names
      final regionsSnapshot = await _firestore.collection('regions').get();
      final districtsSnapshot = await _firestore.collection('districts').get();

      // Create name-to-ID mappings (case-insensitive)
      final Map<String, String> regionNameToId = {};
      final Map<String, String> districtNameToId = {};

      for (var doc in regionsSnapshot.docs) {
        final name = (doc.data()['name'] ?? '').toString().toUpperCase();
        if (name.isNotEmpty) {
          regionNameToId[name] = doc.id;
        }
      }

      for (var doc in districtsSnapshot.docs) {
        final name = (doc.data()['name'] ?? '').toString().toUpperCase();
        if (name.isNotEmpty) {
          districtNameToId[name] = doc.id;
        }
      }

      // Get all staff
      final staffSnapshot = await _firestore.collection('staff').get();

      int wouldUpdate = 0;
      int wouldSkip = 0;

      for (var staffDoc in staffSnapshot.docs) {
        final data = staffDoc.data();
        final staffName = data['name'] ?? 'Unknown';
        final regionValue = data['region'] as String?;
        final districtValue = data['district'] as String?;

        bool willUpdate = false;
        final List<String> changes = [];

        // Check region
        if (regionValue != null &&
            regionValue.isNotEmpty &&
            !regionValue.contains('-')) {
          final regionKey = regionValue.toUpperCase();
          if (regionNameToId.containsKey(regionKey)) {
            changes.add('Region: "$regionValue" → ${regionNameToId[regionKey]}');
            willUpdate = true;
          }
        }

        // Check district
        if (districtValue != null &&
            districtValue.isNotEmpty &&
            !districtValue.contains('-')) {
          final districtKey = districtValue.toUpperCase();
          if (districtNameToId.containsKey(districtKey)) {
            changes.add(
                'District: "$districtValue" → ${districtNameToId[districtKey]}');
            willUpdate = true;
          } else {
            final districtKeyAlt = districtKey.replaceAll('_', ' ');
            if (districtNameToId.containsKey(districtKeyAlt)) {
              changes.add(
                  'District: "$districtValue" → ${districtNameToId[districtKeyAlt]}');
              willUpdate = true;
            }
          }
        }

        if (willUpdate) {
          debugPrint('$staffName:');
          for (var change in changes) {
            debugPrint('  • $change');
          }
          wouldUpdate++;
        } else {
          wouldSkip++;
        }
      }

      debugPrint('\n📊 PREVIEW SUMMARY:');
      debugPrint('Total Staff: ${staffSnapshot.docs.length}');
      debugPrint('Would Update: $wouldUpdate');
      debugPrint('Would Skip: $wouldSkip');
    } catch (e) {
      debugPrint('❌ Error previewing mapping: $e');
    }
  }
}
