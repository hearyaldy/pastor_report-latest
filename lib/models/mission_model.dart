// lib/models/mission_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/department_model.dart';

class Mission {
  final String id;
  final String name;
  final String? code;
  final String? description;
  final String? logoUrl;
  final List<Department>? departments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Mission({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.logoUrl,
    this.departments,
    this.createdAt,
    this.updatedAt,
  });

  factory Mission.fromMap(Map<String, dynamic> map, String id) {
    DateTime? createdAt;
    if (map['createdAt'] != null) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    }

    DateTime? updatedAt;
    if (map['updatedAt'] != null) {
      updatedAt = (map['updatedAt'] as Timestamp).toDate();
    }

    // Note: Departments are loaded separately via the MissionService
    return Mission(
      id: id,
      name: map['name'] ?? '',
      code: map['code'],
      description: map['description'],
      logoUrl: map['logoUrl'],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'description': description,
      'logoUrl': logoUrl,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Serialize to a cache-friendly map (without FieldValue instances)
  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'logoUrl': logoUrl,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from cache map
  factory Mission.fromCacheMap(Map<String, dynamic> map) {
    return Mission(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'],
      description: map['description'],
      logoUrl: map['logoUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }

  // Create a copy of this Mission with optional updated fields
  Mission copyWith({
    String? name,
    String? code,
    String? description,
    String? logoUrl,
    List<Department>? departments,
  }) {
    return Mission(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      departments: departments ?? this.departments,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
