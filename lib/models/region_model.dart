import 'package:cloud_firestore/cloud_firestore.dart';

class Region {
  final String id;
  final String name;
  final String code;
  final String missionId;
  final DateTime createdAt;
  final String createdBy;

  Region({
    required this.id,
    required this.name,
    required this.code,
    required this.missionId,
    required this.createdAt,
    required this.createdBy,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'missionId': missionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  // Create from Firestore document
  factory Region.fromMap(Map<String, dynamic> map) {
    return Region(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      missionId: map['missionId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  // Create from Firestore DocumentSnapshot
  factory Region.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Region.fromMap(data);
  }

  // Copy with method for updates
  Region copyWith({
    String? id,
    String? name,
    String? code,
    String? missionId,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Region(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      missionId: missionId ?? this.missionId,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'Region(id: $id, name: $name, code: $code, missionId: $missionId)';
  }
}
