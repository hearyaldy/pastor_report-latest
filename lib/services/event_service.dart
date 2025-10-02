import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/event_model.dart';

class EventService {
  static const String _localEventsKey = 'local_events';
  static final EventService instance = EventService._();

  EventService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _globalEventsCollection = 'global_events';
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Local Events
  Future<List<Event>> getLocalEvents() async {
    if (_prefs == null) await initialize();

    final eventsJson = _prefs!.getString(_localEventsKey);
    if (eventsJson == null) return [];

    final List<dynamic> decoded = json.decode(eventsJson);
    return decoded.map((json) => Event.fromJson(json)).toList();
  }

  Future<void> saveLocalEvent(Event event) async {
    final events = await getLocalEvents();

    // Check if event already exists
    final index = events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      events[index] = event;
    } else {
      events.add(event);
    }

    await _saveLocalEvents(events);
  }

  Future<void> deleteLocalEvent(String id) async {
    final events = await getLocalEvents();
    events.removeWhere((event) => event.id == id);
    await _saveLocalEvents(events);
  }

  Future<void> _saveLocalEvents(List<Event> events) async {
    if (_prefs == null) await initialize();

    final encoded = json.encode(events.map((e) => e.toJson()).toList());
    await _prefs!.setString(_localEventsKey, encoded);
  }

  // Global Events (from Firestore)
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

  Future<List<Event>> getGlobalEvents() async {
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
  }

  // Get all events (local + global)
  Future<List<Event>> getAllEvents() async {
    final localEvents = await getLocalEvents();
    final globalEvents = await getGlobalEvents();

    final allEvents = [...localEvents, ...globalEvents];
    allEvents.sort((a, b) => a.startDate.compareTo(b.startDate));

    return allEvents;
  }

  // Get upcoming events (next 7 days)
  Future<List<Event>> getUpcomingEvents({int days = 7}) async {
    final allEvents = await getAllEvents();
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));

    return allEvents
        .where((event) =>
            event.startDate.isAfter(now) && event.startDate.isBefore(futureDate))
        .toList();
  }

  // Get upcoming events stream
  Stream<List<Event>> getUpcomingEventsStream({int days = 30}) async* {
    final now = DateTime.now();
    final futureDate = now.add(Duration(days: days));

    // Get local events
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
