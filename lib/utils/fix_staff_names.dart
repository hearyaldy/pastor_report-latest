import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Fix staff name mismatches to match churches_SAB.json
class StaffNameFixer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Known name corrections based on churches_SAB.json
  static final Map<String, String> nameCorrections = {
    // Firestore name → Correct name from JSON
    'Jeremiah Sam': 'Jeremiah Sam John',
    'Clario Taipin Gadoit': 'Cleario Taipin',
    'Erick Roy Paul': 'Erick RoyPaul',
    'Micheal Chin Hon Kee': 'Micheal Chin',
    // Note: The rest may not be in churches_SAB.json as district pastors
    // They might be new pastors or have different roles
  };

  /// Preview name corrections
  static Future<void> previewNameCorrections() async {
    debugPrint('\n📋 NAME CORRECTIONS PREVIEW:');
    debugPrint('=' * 80);

    try {
      final staffSnapshot = await _firestore.collection('staff').get();
      int foundCount = 0;

      for (var entry in nameCorrections.entries) {
        final oldName = entry.key;
        final newName = entry.value;

        // Find staff with old name
        final staffDoc = staffSnapshot.docs.where(
          (doc) => (doc.data()['name'] ?? '').toString() == oldName,
        );

        if (staffDoc.isNotEmpty) {
          foundCount++;
          debugPrint('\n✓ Found: $oldName');
          debugPrint('  Will rename to: $newName');
          debugPrint('  Staff ID: ${staffDoc.first.id}');
        } else {
          debugPrint('\n✗ Not found: $oldName');
        }
      }

      debugPrint('\n${'=' * 80}');
      debugPrint(
          'Total corrections to apply: $foundCount / ${nameCorrections.length}');
    } catch (e) {
      debugPrint('❌ Error previewing corrections: $e');
    }
  }

  /// Apply name corrections
  static Future<Map<String, dynamic>> applyNameCorrections() async {
    debugPrint('\n🔧 APPLYING NAME CORRECTIONS:');
    debugPrint('=' * 80);

    final results = {
      'total_corrections': nameCorrections.length,
      'applied': 0,
      'not_found': <String>[],
      'errors': <String>[],
    };

    try {
      final staffSnapshot = await _firestore.collection('staff').get();

      for (var entry in nameCorrections.entries) {
        final oldName = entry.key;
        final newName = entry.value;

        try {
          // Find staff with old name
          final staffDocs = staffSnapshot.docs.where(
            (doc) => (doc.data()['name'] ?? '').toString() == oldName,
          );

          if (staffDocs.isEmpty) {
            (results['not_found'] as List).add(oldName);
            debugPrint('✗ Not found: $oldName');
            continue;
          }

          // Update the name
          for (var staffDoc in staffDocs) {
            await _firestore.collection('staff').doc(staffDoc.id).update({
              'name': newName,
            });

            results['applied'] = (results['applied'] as int) + 1;
            debugPrint('✓ Renamed: $oldName → $newName');
          }
        } catch (e) {
          (results['errors'] as List).add('Error updating $oldName: $e');
          debugPrint('❌ Error updating $oldName: $e');
        }
      }

      debugPrint('\n${'=' * 80}');
      debugPrint('✅ CORRECTIONS COMPLETE:');
      debugPrint('Total: ${results['total_corrections']}');
      debugPrint('Applied: ${results['applied']}');
      debugPrint('Not Found: ${(results['not_found'] as List).length}');
      debugPrint('Errors: ${(results['errors'] as List).length}');

      return results;
    } catch (e) {
      debugPrint('❌ Error applying corrections: $e');
      rethrow;
    }
  }

  /// Find potential name matches in JSON file
  /// This helps identify other mismatches
  static void suggestNameMatches() {
    debugPrint('\n💡 SUGGESTED NAME MATCHES:');
    debugPrint('=' * 80);
    debugPrint('');
    debugPrint('Check churches_SAB.json for these staff members:');
    debugPrint('');
    debugPrint('Already identified:');
    debugPrint('  • Jeremiah Sam → Jeremiah Sam John ✓');
    debugPrint('  • Clario Taipin Gadoit → Cleario Taipin ✓');
    debugPrint('');
    debugPrint('Need to check manually:');
    debugPrint('  • Alexander Maxon Horis');
    debugPrint('  • Lovell Juil');
    debugPrint(
        '  • A Harnnie Severinus (might be "A Hairrie Severinus" or different person)');
    debugPrint('  • Timothy Chin Wei Jun');
    debugPrint('  • Ariman Paulus');
    debugPrint('  • Justin Wong Chong Yung');
    debugPrint('  • Melrindro Rojiin Lukas');
    debugPrint('  • Soliun Sandayan');
    debugPrint('  • Ronald Longgou (check for "Ronald Majinau"?)');
    debugPrint('  • Francis Lajanim');
    debugPrint('  • Adriel Charles Jr');
    debugPrint('  • Junniel Mac Daniel Gara');
    debugPrint('  • Erick Roy Paul');
    debugPrint('  • Micheal Chin Hon Kee');
    debugPrint('  • Richard Ban Solynsem');
    debugPrint('');
    debugPrint('How to fix:');
    debugPrint('  1. Search churches_SAB.json for similar names');
    debugPrint('  2. Add corrections to nameCorrections map');
    debugPrint('  3. Run "Apply Name Corrections"');
    debugPrint('  4. Re-run "Import Staff Assignments"');
    debugPrint('');
    debugPrint('=' * 80);
  }
}
