import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Diagnostic tool to understand staff data structure
class StaffDataDiagnostics {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Show sample staff records with all their fields
  static Future<void> showSampleStaffRecords({int sampleSize = 10}) async {
    debugPrint('🔍 SAMPLE STAFF RECORDS (First $sampleSize):');
    debugPrint('${'=' * 80}');

    try {
      final staffSnapshot = await _firestore
          .collection('staff')
          .limit(sampleSize)
          .get();

      for (var doc in staffSnapshot.docs) {
        final data = doc.data();
        debugPrint('\n📄 Staff ID: ${doc.id}');
        debugPrint('   Name: ${data['name'] ?? 'N/A'}');
        debugPrint('   Mission: ${data['mission'] ?? 'N/A'}');
        debugPrint('   Region: ${data['region'] ?? 'NULL'}');
        debugPrint('   District: ${data['district'] ?? 'NULL'}');
        debugPrint('   Role: ${data['role'] ?? 'N/A'}');
        debugPrint('   Email: ${data['email'] ?? 'N/A'}');
        debugPrint('   Department: ${data['department'] ?? 'N/A'}');

        // Show all fields
        debugPrint('   All fields: ${data.keys.join(', ')}');
      }

      debugPrint('\n${'=' * 80}');
    } catch (e) {
      debugPrint('❌ Error showing sample records: $e');
    }
  }

  /// Count staff by mission and show district/region status
  static Future<void> analyzeStaffByMission() async {
    debugPrint('\n📊 STAFF ANALYSIS BY MISSION:');
    debugPrint('${'=' * 80}');

    try {
      final staffSnapshot = await _firestore.collection('staff').get();
      final missionsSnapshot = await _firestore.collection('missions').get();

      // Create mission ID to name mapping
      final Map<String, String> missionNames = {};
      for (var doc in missionsSnapshot.docs) {
        missionNames[doc.id] = doc.data()['name'] ?? doc.id;
      }

      // Group staff by mission
      final Map<String, Map<String, int>> missionStats = {};

      for (var staffDoc in staffSnapshot.docs) {
        final data = staffDoc.data();
        final mission = data['mission'] ?? 'Unknown';
        final hasRegion = (data['region'] != null &&
                          (data['region'] as String).isNotEmpty);
        final hasDistrict = (data['district'] != null &&
                            (data['district'] as String).isNotEmpty);

        if (!missionStats.containsKey(mission)) {
          missionStats[mission] = {
            'total': 0,
            'with_region': 0,
            'with_district': 0,
            'with_both': 0,
            'with_neither': 0,
          };
        }

        missionStats[mission]!['total'] =
            (missionStats[mission]!['total'] ?? 0) + 1;

        if (hasRegion) {
          missionStats[mission]!['with_region'] =
              (missionStats[mission]!['with_region'] ?? 0) + 1;
        }

        if (hasDistrict) {
          missionStats[mission]!['with_district'] =
              (missionStats[mission]!['with_district'] ?? 0) + 1;
        }

        if (hasRegion && hasDistrict) {
          missionStats[mission]!['with_both'] =
              (missionStats[mission]!['with_both'] ?? 0) + 1;
        }

        if (!hasRegion && !hasDistrict) {
          missionStats[mission]!['with_neither'] =
              (missionStats[mission]!['with_neither'] ?? 0) + 1;
        }
      }

      // Print stats
      for (var entry in missionStats.entries) {
        final missionId = entry.key;
        final missionName = missionNames[missionId] ?? missionId;
        final stats = entry.value;

        debugPrint('\n🏢 $missionName ($missionId)');
        debugPrint('   Total Staff: ${stats['total']}');
        debugPrint('   With Region: ${stats['with_region']}');
        debugPrint('   With District: ${stats['with_district']}');
        debugPrint('   With Both: ${stats['with_both']}');
        debugPrint('   With Neither: ${stats['with_neither']}');

        final percentNeither = stats['with_neither']! * 100 / stats['total']!;
        debugPrint('   Missing Location: ${percentNeither.toStringAsFixed(1)}%');
      }

      debugPrint('\n${'=' * 80}');
    } catch (e) {
      debugPrint('❌ Error analyzing staff: $e');
    }
  }

  /// Check if there's an import file or backup data
  static Future<void> suggestDataSources() async {
    debugPrint('\n💡 DATA SOURCE SUGGESTIONS:');
    debugPrint('${'=' * 80}');
    debugPrint('');
    debugPrint('To populate staff district/region data, you can:');
    debugPrint('');
    debugPrint('1. Import from Excel/CSV file');
    debugPrint('   - If you have a spreadsheet with staff assignments');
    debugPrint('   - Use the Data Import utility in Admin Utilities');
    debugPrint('');
    debugPrint('2. Manually assign in Staff Management');
    debugPrint('   - Edit each staff member individually');
    debugPrint('   - Best for small numbers of staff');
    debugPrint('');
    debugPrint('3. Use role-based assignments');
    debugPrint('   - District Pastors auto-assigned to their district');
    debugPrint('   - Mission staff may not need district/region');
    debugPrint('');
    debugPrint('4. Check if data exists in another field');
    debugPrint('   - Sometimes data is stored in notes or other fields');
    debugPrint('   - Run "Show Sample Staff Records" to check');
    debugPrint('');
    debugPrint('${'=' * 80}');
  }
}
