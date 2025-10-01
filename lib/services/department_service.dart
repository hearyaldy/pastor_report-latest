// lib/services/department_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/department_model.dart';

class DepartmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'departments';

  // Get all departments
  Stream<List<Department>> getDepartmentsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Department(
          id: doc.id,
          name: data['name'] ?? '',
          icon: Department.getIconFromString(data['icon'] ?? 'dashboard'),
          formUrl: data['formUrl'] ?? '',
        );
      }).toList();
    });
  }

  // Get all departments (one-time fetch)
  Future<List<Department>> getDepartments() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Department(
          id: doc.id,
          name: data['name'] ?? '',
          icon: Department.getIconFromString(data['icon'] ?? 'dashboard'),
          formUrl: data['formUrl'] ?? '',
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch departments: $e';
    }
  }

  // Add new department
  Future<void> addDepartment(Department department) async {
    try {
      await _firestore.collection(_collection).add({
        'name': department.name,
        'icon': Department.getIconString(department.icon),
        'formUrl': department.formUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to add department: $e';
    }
  }

  // Update department
  Future<void> updateDepartment(Department department) async {
    try {
      await _firestore.collection(_collection).doc(department.id).update({
        'name': department.name,
        'icon': Department.getIconString(department.icon),
        'formUrl': department.formUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update department: $e';
    }
  }

  // Delete department
  Future<void> deleteDepartment(String departmentId) async {
    try {
      await _firestore.collection(_collection).doc(departmentId).delete();
    } catch (e) {
      throw 'Failed to delete department: $e';
    }
  }

  // Seed initial departments (call once to populate database)
  Future<void> seedDepartments() async {
    try {
      // Check if departments already exist
      final snapshot = await _firestore.collection(_collection).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        return; // Already seeded
      }

      // Add default departments
      final departments = [
        {'name': 'Ministerial', 'icon': 'person', 'formUrl': 'https://forms.gle/MinisterialLink'},
        {'name': 'Stewardship', 'icon': 'account_balance', 'formUrl': 'https://forms.gle/Fwud8srq8aXikzY48'},
        {'name': 'Youth', 'icon': 'group', 'formUrl': 'https://tinyurl.com/laporan-jpba'},
        {'name': 'Communication', 'icon': 'message', 'formUrl': 'https://forms.gle/wMaDk2VUwhd8MwXk9'},
        {'name': 'Health Ministry', 'icon': 'local_hospital', 'formUrl': 'https://forms.gle/aR4mRU8HopXGQ6cq5'},
        {'name': 'Education', 'icon': 'school', 'formUrl': 'https://forms.gle/EducationLink'},
        {'name': 'Family Life', 'icon': 'family_restroom', 'formUrl': 'https://forms.gle/iak14RPeULZ18BCD6'},
        {'name': 'Women\'s Ministry (Q1 & Q2)', 'icon': 'woman', 'formUrl': 'https://forms.gle/ybAS4jRESNPQp71J7'},
        {'name': 'Women\'s Ministry (Q3 & Q4)', 'icon': 'woman', 'formUrl': 'https://forms.gle/1tzirnartRswrDbb6'},
        {'name': 'Children', 'icon': 'child_care', 'formUrl': 'http://tiny.cc/HANTARFILELAPORAN'},
        {'name': 'Publishing', 'icon': 'book', 'formUrl': 'https://forms.gle/PublishingLink'},
        {'name': 'Personal Ministry', 'icon': 'person_pin', 'formUrl': 'https://forms.gle/PersonalMinistryLink'},
        {'name': 'Sabbath School', 'icon': 'access_time', 'formUrl': 'https://docs.google.com/forms/d/1JTupBS6yVIePQmgTHih8ptlG9zxUSVv2aJzJc3c3V10/edit'},
        {'name': 'Adventist Community Services', 'icon': 'volunteer_activism', 'formUrl': 'https://forms.gle/AdventistCommunityServicesLink'},
      ];

      final batch = _firestore.batch();
      for (var dept in departments) {
        final docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, {
          ...dept,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw 'Failed to seed departments: $e';
    }
  }
}
