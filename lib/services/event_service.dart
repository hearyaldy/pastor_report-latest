import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pastor_report/models/event_model.dart';

/// Cloud storage service for events using Firebase Firestore
/// Supports both personal events (user-scoped) and global events (admin-created)
class EventService {
  static const String _personalEventsCollection = 'events';
  static const String _globalEventsCollection = 'global_events';
  static final EventService instance = EventService._();

  EventService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's ID
  String? get _userId => _auth.currentUser?.uid;

  Future<void> initialize() async {
    debugPrint('✅ EventService initialized with Firestore');
  }

  // ===== Personal Events (User-scoped) =====

  /// Get all personal events for the current user
  Future<List<Event>> getLocalEvents() async {
    try {
      if (_userId == null) {
        debugPrint('⚠️ No user logged in');
        return [];
      }

      final snapshot = await _firestore
          .collection(_personalEventsCollection)
          .where('userId', isEqualTo: _userId)
          .orderBy('startDate', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => Event.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading personal events: $e');
      return [];
    }
  }

  /// Get personal events stream for real-time updates
  Stream<List<Event>> getLocalEventsStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_personalEventsCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Event.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Save a personal event (create or update)
  Future<void> saveLocalEvent(Event event) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      // Ensure userId is set
      final eventWithUserId = event.copyWith(userId: _userId);

      final eventData = {
        'userId': _userId,
        'title': eventWithUserId.title,
        'description': eventWithUserId.description,
        'startDate': eventWithUserId.startDate.toIso8601String(),
        'endDate': eventWithUserId.endDate?.toIso8601String(),
        'location': eventWithUserId.location,
        'isGlobal': false, // Personal events are never global
        'imageUrl': eventWithUserId.imageUrl,
        'organizer': eventWithUserId.organizer,
        'createdAt': eventWithUserId.createdAt.toIso8601String(),
      };

      debugPrint('📝 Saving personal event for user: $_userId');
      await _firestore
          .collection(_personalEventsCollection)
          .doc(event.id)
          .set(eventData, SetOptions(merge: true));
      debugPrint('✅ Personal event saved with ID: ${event.id}');
    } catch (e) {
      debugPrint('❌ Error saving personal event: $e');
      rethrow;
    }
  }

  /// Delete a personal event
  Future<void> deleteLocalEvent(String id) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🗑️ Deleting personal event: $id');
      await _firestore.collection(_personalEventsCollection).doc(id).delete();
      debugPrint('✅ Personal event deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting personal event: $e');
      rethrow;
    }
  }

  // ===== Global Events (Admin-created, read by all) =====

  /// Get global events stream for real-time updates
  Stream<List<Event>> getGlobalEventsStream() {
    return _firestore
        .collection(_globalEventsCollection)
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Event.fromJson({
          'id': doc.id,
          ...data,
          'isGlobal': true,
        });
      }).toList();
    });
  }

  /// Get all global events
  Future<List<Event>> getGlobalEvents() async {
    try {
      final snapshot = await _firestore
          .collection(_globalEventsCollection)
          .orderBy('startDate', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Event.fromJson({
          'id': doc.id,
          ...data,
          'isGlobal': true,
        });
      }).toList();
    } catch (e) {
      debugPrint('❌ Error loading global events: $e');
      return [];
    }
  }

  // ===== Combined Events (Personal + Global) =====

  /// Get all events (personal + global)
  Future<List<Event>> getAllEvents() async {
    final localEvents = await getLocalEvents();
    final globalEvents = await getGlobalEvents();

    final allEvents = [...localEvents, ...globalEvents];
    allEvents.sort((a, b) => a.startDate.compareTo(b.startDate));

    return allEvents;
  }

  /// Get upcoming events (next N days)
  Future<List<Event>> getUpcomingEvents({int days = 7}) async {
    final allEvents = await getAllEvents();
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));

    return allEvents
        .where((event) =>
            event.startDate.isAfter(now) && event.startDate.isBefore(futureDate))
        .toList();
  }

  /// Get upcoming events stream (personal + global combined)
  Stream<List<Event>> getUpcomingEventsStream({int days = 30}) async* {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));

    // Get personal events
    final localEvents = await getLocalEvents();
    final upcomingLocal = localEvents
        .where((event) =>
            event.startDate.isAfter(now) && event.startDate.isBefore(futureDate))
        .toList();

    // Stream global events and combine
    await for (final globalEvents in getGlobalEventsStream()) {
      final upcomingGlobal = globalEvents
          .where((event) =>
              event.startDate.isAfter(now) && event.startDate.isBefore(futureDate))
          .toList();

      final combined = [...upcomingLocal, ...upcomingGlobal];
      combined.sort((a, b) => a.startDate.compareTo(b.startDate));

      yield combined;
    }
  }
}
