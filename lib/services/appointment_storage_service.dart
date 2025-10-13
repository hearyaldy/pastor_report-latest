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

  /// Create a new appointment
  Future<String> createAppointment({
    required String title,
    required DateTime dateTime,
    String? description,
    String? location,
    String? contactPerson,
    String? contactPhone,
    bool isCompleted = false,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final appointmentData = {
        'userId': _userId,
        'title': title,
        'description': description,
        'dateTime': Timestamp.fromDate(dateTime),
        'location': location,
        'contactPerson': contactPerson,
        'contactPhone': contactPhone,
        'isCompleted': isCompleted,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint('📝 Creating new appointment for user: $_userId');
      final docRef =
          await _firestore.collection(_appointmentsCollection).add(appointmentData);
      debugPrint('✅ Appointment created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating appointment: $e');
      rethrow;
    }
  }

  /// Update an existing appointment
  Future<void> updateAppointment({
    required String appointmentId,
    String? title,
    DateTime? dateTime,
    String? description,
    String? location,
    String? contactPerson,
    String? contactPhone,
    bool? isCompleted,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updateData['title'] = title;
      if (dateTime != null) updateData['dateTime'] = Timestamp.fromDate(dateTime);
      if (description != null) updateData['description'] = description;
      if (location != null) updateData['location'] = location;
      if (contactPerson != null) updateData['contactPerson'] = contactPerson;
      if (contactPhone != null) updateData['contactPhone'] = contactPhone;
      if (isCompleted != null) updateData['isCompleted'] = isCompleted;

      debugPrint('🔄 Updating appointment: $appointmentId');
      await _firestore
          .collection(_appointmentsCollection)
          .doc(appointmentId)
          .update(updateData);
      debugPrint('✅ Appointment updated: $appointmentId');
    } catch (e) {
      debugPrint('❌ Error updating appointment: $e');
      rethrow;
    }
  }

  /// Delete an appointment
  Future<void> deleteAppointment(String id) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🗑️ Deleting appointment: $id');
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

      final data = docSnap.data()!;
      final isCurrentlyCompleted = data['isCompleted'] as bool? ?? false;

      debugPrint('🔄 Toggling appointment: $id to completed: ${!isCurrentlyCompleted}');
      await docRef.update({
        'isCompleted': !isCurrentlyCompleted,
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
