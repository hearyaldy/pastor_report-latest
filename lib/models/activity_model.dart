// lib/models/activity_model.dart

/// Model for pastor's daily activities
class Activity {
  final String id;
  final DateTime date;
  final String activities;
  final double mileage;
  final String note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Activity({
    required this.id,
    required this.date,
    required this.activities,
    required this.mileage,
    required this.note,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create Activity from JSON
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      activities: json['activities'] as String,
      mileage: (json['mileage'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      date: date ?? this.date,
      activities: activities ?? this.activities,
      mileage: mileage ?? this.mileage,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
