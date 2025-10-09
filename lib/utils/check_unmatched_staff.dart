import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Check details of unmatched staff to understand why they weren't matched
class UnmatchedStaffChecker {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Show details of specific unmatched staff members
  static Future<void> checkUnmatchedStaff(List<String> unmatchedNames) async {
    debugPrint('\n🔍 CHECKING UNMATCHED STAFF DETAILS:');
    debugPrint('${'=' * 80}');

    try {
      final staffSnapshot = await _firestore.collection('staff').get();

      for (var name in unmatchedNames) {
        // Find the staff member
        final staffDoc = staffSnapshot.docs.firstWhere(
          (doc) => (doc.data()['name'] ?? '').toString() == name,
          orElse: () => throw Exception('Staff not found: $name'),
        );

        final data = staffDoc.data();

        debugPrint('\n👤 ${data['name']}');
        debugPrint('   Role: ${data['role'] ?? 'N/A'}');
        debugPrint('   Department: ${data['department'] ?? 'N/A'}');
        debugPrint('   Email: ${data['email'] ?? 'N/A'}');
        debugPrint('   Current Region: ${data['region'] ?? 'NULL'}');
        debugPrint('   Current District: ${data['district'] ?? 'NULL'}');

        // Suggest if they need district assignment
        final role = (data['role'] ?? '').toString().toLowerCase();
        if (role.contains('district pastor') || role.contains('lay pastor')) {
          debugPrint('   ⚠️ Should have district assignment!');
        } else if (role.contains('mission') || role.contains('director') ||
                   role.contains('officer')) {
          debugPrint('   ℹ️  Mission-level role - may not need district');
        }
      }

      debugPrint('\n${'=' * 80}');
    } catch (e) {
      debugPrint('❌ Error checking unmatched staff: $e');
    }
  }
}
