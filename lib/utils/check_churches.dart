import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Check what missionId values churches and districts have
class ChurchesChecker {
  static Future<void> checkChurchesMissionIds() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Check districts
      final districtsSnapshot = await firestore.collection('districts').limit(5).get();
      debugPrint('📍 Sample Districts:');
      for (var doc in districtsSnapshot.docs) {
        final data = doc.data();
        final districtName = data['name'] as String?;
        final missionId = data['missionId'] as String?;
        debugPrint('  District: $districtName');
        debugPrint('    missionId: "$missionId"');
        debugPrint('    ID: ${doc.id}');
      }

      // Check churches
      final churchesSnapshot = await firestore.collection('churches').limit(5).get();
      debugPrint('🏛️ Sample Churches:');
      for (var doc in churchesSnapshot.docs) {
        final data = doc.data();
        final churchName = data['churchName'] as String?;
        final missionId = data['missionId'] as String?;
        debugPrint('  Church: $churchName');
        debugPrint('    missionId: "$missionId"');
        debugPrint('    ID: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error checking: $e');
    }
  }
}
