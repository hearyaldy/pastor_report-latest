import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/appointment_model.dart';

/// Cloud storage service for appointments using Firebase Firestore
class AppointmentStorageService {
  static const String _appointmentsCollection = 'appointments';
  static final AppointmentStorageService instance =
      AppointmentStorageService._();

  AppointmentStorageService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's ID
  String? get _userId => _auth.currentUser?.uid;

  Future<void> initialize() async {
    debugPrint('✅ AppointmentStorageService initialized with Firestore');
  }

  /// Get all appointments
  Future<List<Appointment>> getAppointments() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final snapshot = await _firestore
          .collection(_appointmentsCollection)
          .where('userId', isEqualTo: _userId)
          .orderBy('dateTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Appointment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading appointments: $e');
      return [];
    }
  }

  /// Get appointments stream for real-time updates
  Stream<List<Appointment>> getAppointmentsStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_appointmentsCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Save or update an appointment
  Future<void> saveAppointment(Appointment appointment) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final appointmentData = appointment.toJson();

      if (appointment.id.isEmpty) {
        // New appointment - include userId and createdAt
        appointmentData['userId'] = _userId;
        appointmentData['createdAt'] = FieldValue.serverTimestamp();
        appointmentData['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection(_appointmentsCollection)
            .add(appointmentData);
        debugPrint('✅ Appointment added');
      } else {
        // Update existing appointment - don't update userId, id, or createdAt
        appointmentData['updatedAt'] = FieldValue.serverTimestamp();
        // Remove immutable fields from update data
        appointmentData.remove('userId');
        appointmentData.remove('id');
        appointmentData.remove('createdAt');
        await _firestore
            .collection(_appointmentsCollection)
            .doc(appointment.id)
            .update(appointmentData);
        debugPrint('✅ Appointment updated: ${appointment.id}');
      }
    } catch (e) {
      debugPrint('❌ Error saving appointment: $e');
      rethrow;
    }
  }

  /// Delete an appointment
  Future<void> deleteAppointment(String id) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection(_appointmentsCollection).doc(id).delete();
      debugPrint('✅ Appointment deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting appointment: $e');
      rethrow;
    }
  }

  /// Toggle appointment completion status
  Future<void> toggleAppointmentComplete(String id) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final docRef = _firestore.collection(_appointmentsCollection).doc(id);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        throw Exception('Appointment not found');
      }

      final appointment =
          Appointment.fromJson({...docSnap.data()!, 'id': docSnap.id});
      final updatedAppointment = appointment.copyWith(
        isCompleted: !appointment.isCompleted,
      );

      await docRef.update({
        'isCompleted': updatedAppointment.isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Appointment toggled: $id');
    } catch (e) {
      debugPrint('❌ Error toggling appointment: $e');
      rethrow;
    }
  }

  /// Get upcoming appointments (future and not completed)
  Future<List<Appointment>> getUpcomingAppointments() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection(_appointmentsCollection)
          .where('userId', isEqualTo: _userId)
          .where('dateTime', isGreaterThan: now)
          .where('isCompleted', isEqualTo: false)
          .orderBy('dateTime', descending: false) // Nearest first
          .get();

      return snapshot.docs
          .map((doc) => Appointment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading upcoming appointments: $e');
      return [];
    }
  }

  /// Get today's appointments
  Future<List<Appointment>> getTodayAppointments() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection(_appointmentsCollection)
          .where('userId', isEqualTo: _userId)
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('dateTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => Appointment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading today appointments: $e');
      return [];
    }
  }

  /// Get past appointments
  Future<List<Appointment>> getPastAppointments() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection(_appointmentsCollection)
          .where('userId', isEqualTo: _userId)
          .where('dateTime', isLessThan: now)
          .orderBy('dateTime', descending: true) // Recent first
          .get();

      return snapshot.docs
          .map((doc) => Appointment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading past appointments: $e');
      return [];
    }
  }
}
