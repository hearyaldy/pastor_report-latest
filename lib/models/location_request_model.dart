import 'package:cloud_firestore/cloud_firestore.dart';

enum LocationRequestType { region, district }

enum LocationRequestStatus { pending, approved, rejected }

class LocationRequest {
  final String id;
  final LocationRequestType type;
  final String name;
  final String missionId;
  final String? regionId;
  final String? regionName;
  final String requestedBy;
  final String requestedByName;
  final LocationRequestStatus status;
  final DateTime createdAt;
  final String? note;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const LocationRequest({
    required this.id,
    required this.type,
    required this.name,
    required this.missionId,
    required this.requestedBy,
    required this.requestedByName,
    required this.status,
    required this.createdAt,
    this.regionId,
    this.regionName,
    this.note,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory LocationRequest.fromMap(Map<String, dynamic> map, String id) {
    return LocationRequest(
      id: id,
      type: map['type'] == 'district'
          ? LocationRequestType.district
          : LocationRequestType.region,
      name: map['name'] ?? '',
      missionId: map['missionId'] ?? '',
      regionId: map['regionId'],
      regionName: map['regionName'],
      requestedBy: map['requestedBy'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      status: _parseStatus(map['status']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'],
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: map['resolvedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type == LocationRequestType.district ? 'district' : 'region',
      'name': name,
      'missionId': missionId,
      if (regionId != null) 'regionId': regionId,
      if (regionName != null) 'regionName': regionName,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  static LocationRequestStatus _parseStatus(String? value) {
    switch (value) {
      case 'approved':
        return LocationRequestStatus.approved;
      case 'rejected':
        return LocationRequestStatus.rejected;
      default:
        return LocationRequestStatus.pending;
    }
  }
}
