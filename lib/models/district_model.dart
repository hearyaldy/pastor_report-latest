import 'package:cloud_firestore/cloud_firestore.dart';

class District {
  final String id;
  final String name;
  final String code;
  final String regionId;
  final String missionId;
  final String? pastorId; // District pastor assigned to this district
  final DateTime createdAt;
  final String createdBy;

  District({
    required this.id,
    required this.name,
    required this.code,
    required this.regionId,
    required this.missionId,
    this.pastorId,
    required this.createdAt,
    required this.createdBy,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'regionId': regionId,
      'missionId': missionId,
      'pastorId': pastorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  // Create from Firestore document
  factory District.fromMap(Map<String, dynamic> map) {
    return District(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      regionId: map['regionId'] ?? '',
      missionId: map['missionId'] ?? '',
      pastorId: map['pastorId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  // Create from Firestore DocumentSnapshot
  factory District.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return District.fromMap(data);
  }

  // Copy with method for updates
  District copyWith({
    String? id,
    String? name,
    String? code,
    String? regionId,
    String? missionId,
    String? pastorId,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return District(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      regionId: regionId ?? this.regionId,
      missionId: missionId ?? this.missionId,
      pastorId: pastorId ?? this.pastorId,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'District(id: $id, name: $name, code: $code, regionId: $regionId, missionId: $missionId, pastorId: $pastorId)';
  }
}
