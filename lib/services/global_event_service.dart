// lib/services/global_event_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/global_event_model.dart';

class GlobalEventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static GlobalEventService? _instance;
  static GlobalEventService get instance {
    _instance ??= GlobalEventService._();
    return _instance!;
  }

  GlobalEventService._();

  CollectionReference get _collection => _firestore.collection('global_events');

  /// Add a new global event
  Future<bool> addEvent(GlobalEvent event) async {
    try {
      await _collection.doc(event.id).set(event.toJson());
      return true;
    } catch (e) {
      print('Error adding global event: $e');
      return false;
    }
  }

  /// Update an existing global event
  Future<bool> updateEvent(GlobalEvent event) async {
    try {
      await _collection.doc(event.id).update({
        ...event.toJson(),
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error updating global event: $e');
      return false;
    }
  }

  /// Delete a global event
  Future<bool> deleteEvent(String eventId) async {
    try {
      await _collection.doc(eventId).delete();
      return true;
    } catch (e) {
      print('Error deleting global event: $e');
      return false;
    }
  }

  /// Get a specific event by ID
  Future<GlobalEvent?> getEventById(String eventId) async {
    try {
      final doc = await _collection.doc(eventId).get();
      if (doc.exists) {
        return GlobalEvent.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting global event: $e');
      return null;
    }
  }

  /// Stream all global events (ordered by date/time, most recent first)
  Stream<List<GlobalEvent>> streamAllEvents() {
    return _collection
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GlobalEvent.fromFirestore(doc))
            .toList());
  }

  /// Stream events by department
  Stream<List<GlobalEvent>> streamEventsByDepartment(String department) {
    return _collection
        .where('department', isEqualTo: department)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GlobalEvent.fromFirestore(doc))
            .toList());
  }

  /// Get all events (Future)
  Future<List<GlobalEvent>> getAllEvents() async {
    try {
      print('GlobalEventService: Getting all events from Firestore...');
      final snapshot = await _collection
          .orderBy('dateTime', descending: false)
          .get();
      print('GlobalEventService: Retrieved ${snapshot.docs.length} event documents');
      final events = snapshot.docs
          .map((doc) => GlobalEvent.fromFirestore(doc))
          .toList();
      print('GlobalEventService: Converted to ${events.length} GlobalEvent objects');
      return events;
    } catch (e) {
      print('Error getting all global events: $e');
      return [];
    }
  }

  /// Get events for a specific date range
  Future<List<GlobalEvent>> getEventsInRange(DateTime start, DateTime end) async {
    try {
      final snapshot = await _collection
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dateTime',
              isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('dateTime', descending: false)
          .get();
      return snapshot.docs
          .map((doc) => GlobalEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting events in range: $e');
      return [];
    }
  }
}