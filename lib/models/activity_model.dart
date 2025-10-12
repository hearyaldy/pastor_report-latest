// lib/models/activity_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for pastor's daily activities
class Activity {
  final String id;
  final DateTime date;
  final String activities;
  final double mileage; // in kilometers
  final String note;
  final String? location; // Location/destination
  final DateTime createdAt;
  final DateTime? updatedAt;

  Activity({
    required this.id,
    required this.date,
    required this.activities,
    required this.mileage,
    required this.note,
    this.location,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create Activity from JSON
  factory Activity.fromJson(Map<String, dynamic> json) {
    // Helper function to convert Timestamp or String to DateTime
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      return DateTime.now();
    }

    return Activity(
      id: json['id'] as String,
      date: parseDateTime(json['date']),
      activities: json['activities'] as String,
      mileage: (json['mileage'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      location: json['location'] as String?,
      createdAt: parseDateTime(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? parseDateTime(json['updatedAt']) : null,
    );
  }

  /// Convert Activity to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'activities': activities,
      'mileage': mileage,
      'note': note,
      'location': location,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Activity copyWith({
    String? id,
    DateTime? date,
    String? activities,
    double? mileage,
    String? note,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      date: date ?? this.date,
      activities: activities ?? this.activities,
      mileage: mileage ?? this.mileage,
      note: note ?? this.note,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate cost based on km rate
  double calculateCost(double kmRate) {
    return mileage * kmRate;
  }

  @override
  String toString() {
    return 'Activity(id: $id, date: $date, activities: $activities, mileage: $mileage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Activity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
