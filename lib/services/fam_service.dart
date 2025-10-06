import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/fam_model.dart';

class FAMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'fam_data';

  // Create FAM data for a financial report
  Future<void> createFAMData(FinancialActivityManagement famData) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(famData.id)
          .set(famData.toMap());
    } catch (e) {
      throw Exception('Failed to create FAM data: $e');
    }
  }

  // Update FAM data
  Future<void> updateFAMData(FinancialActivityManagement famData) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(famData.id)
          .update(famData.toMap());
    } catch (e) {
      throw Exception('Failed to update FAM data: $e');
    }
  }

  // Get FAM data by report ID
  Future<FinancialActivityManagement?> getFAMDataByReportId(
      String reportId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('reportId', isEqualTo: reportId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return FinancialActivityManagement.fromMap(
            querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get FAM data: $e');
    }
  }

  // Get FAM data by ID
  Future<FinancialActivityManagement?> getFAMData(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return FinancialActivityManagement.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get FAM data: $e');
    }
  }

  // Delete FAM data
  Future<void> deleteFAMData(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete FAM data: $e');
    }
  }

  // Get all FAM data for a church
  Future<List<FinancialActivityManagement>> getFAMDataByChurchId(
      String churchId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('churchId', isEqualTo: churchId)
          .get();

      return querySnapshot.docs
          .map((doc) => FinancialActivityManagement.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get FAM data for church: $e');
    }
  }
}
