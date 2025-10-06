import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Check missions collection structure
class MissionsChecker {
  static Future<void> checkMissions() async {
    final firestore = FirebaseFirestore.instance;

    try {
      debugPrint('🔍 Checking missions collection...');

      final missionsSnapshot = await firestore.collection('missions').get();

      debugPrint('📊 Total missions: ${missionsSnapshot.docs.length}');

      for (var doc in missionsSnapshot.docs) {
        final data = doc.data();
        debugPrint('');
        debugPrint('Mission ID: ${doc.id}');
        debugPrint('  name: ${data['name']}');
        debugPrint('  code: ${data['code']}');
        debugPrint('  description: ${data['description']}');
        debugPrint('  All fields: $data');
      }
    } catch (e) {
      debugPrint('❌ Error checking missions: $e');
    }
  }
}
