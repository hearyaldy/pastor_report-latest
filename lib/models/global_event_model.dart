// lib/models/global_event_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final String? department;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  GlobalEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    this.department,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'department': department,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore document
  factory GlobalEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('GlobalEvent data is null');
    }

    return GlobalEvent(
      id: doc.id,
      title: data['title'] as String? ?? '',
      dateTime: (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      department: data['department'] as String?,
      notes: data['notes'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Create from JSON (for import, etc.)
  factory GlobalEvent.fromJson(Map<String, dynamic> json) {
    return GlobalEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dateTime: DateTime.parse(json['dateTime'] as String),
      department: json['department'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  // Copy with method for updates
  GlobalEvent copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    String? department,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GlobalEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      department: department ?? this.department,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}