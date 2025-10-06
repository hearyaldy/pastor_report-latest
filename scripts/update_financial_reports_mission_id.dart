import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Script to update existing financial reports with missionId
/// This is needed because earlier reports were created without missionId
void main() async {
  print('🔧 Starting Financial Reports missionId Update Script...\n');

  // Initialize Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  try {
    print('📊 Fetching all financial reports...');
    final reportsSnapshot = await firestore
        .collection('financial_reports')
        .where('missionId', isEqualTo: null)
        .get();

    print('Found ${reportsSnapshot.docs.length} reports without missionId\n');

    if (reportsSnapshot.docs.isEmpty) {
      print('✅ All reports already have missionId set!');
      exit(0);
    }

    int updated = 0;
    int failed = 0;

    for (var reportDoc in reportsSnapshot.docs) {
      try {
        final reportData = reportDoc.data();
        final churchId = reportData['churchId'] as String?;

        if (churchId == null) {
          print('⚠️  Report ${reportDoc.id} has no churchId, skipping...');
          failed++;
          continue;
        }

        // Get the church to find its missionId
        final churchDoc = await firestore.collection('churches').doc(churchId).get();

        if (!churchDoc.exists) {
          print('⚠️  Church $churchId not found for report ${reportDoc.id}, skipping...');
          failed++;
          continue;
        }

        final churchData = churchDoc.data()!;
        final missionId = churchData['missionId'] as String?;

        if (missionId == null) {
          print('⚠️  Church $churchId has no missionId, skipping report ${reportDoc.id}...');
          failed++;
          continue;
        }

        // Update the report with missionId
        await firestore.collection('financial_reports').doc(reportDoc.id).update({
          'missionId': missionId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        updated++;
        print('✅ Updated report ${reportDoc.id} with missionId: $missionId');
      } catch (e) {
        print('❌ Error updating report ${reportDoc.id}: $e');
        failed++;
      }
    }

    print('\n📈 Update Summary:');
    print('   ✅ Successfully updated: $updated reports');
    print('   ❌ Failed: $failed reports');
    print('   📊 Total processed: ${reportsSnapshot.docs.length} reports');

    if (updated > 0) {
      print('\n🎉 Financial reports updated successfully!');
      print('   Mission pages should now show all reports correctly.');
    }
  } catch (e) {
    print('❌ Fatal error: $e');
    exit(1);
  }

  exit(0);
}
