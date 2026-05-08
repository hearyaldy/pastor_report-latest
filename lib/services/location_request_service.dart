import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/location_request_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/district_service.dart';

class LocationRequestService {
  LocationRequestService._();
  static final LocationRequestService instance = LocationRequestService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'locationRequests';

  Future<void> requestRegion({
    required String name,
    required String missionId,
    required String requestedBy,
    required String requestedByName,
    String? note,
  }) async {
    final ref = _firestore.collection(_collection).doc();
    final request = LocationRequest(
      id: ref.id,
      type: LocationRequestType.region,
      name: name,
      missionId: missionId,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      status: LocationRequestStatus.pending,
      createdAt: DateTime.now(),
      note: note,
    );
    await ref.set(request.toMap());
  }

  Future<void> requestDistrict({
    required String name,
    required String missionId,
    required String regionId,
    required String regionName,
    required String requestedBy,
    required String requestedByName,
    String? note,
  }) async {
    final ref = _firestore.collection(_collection).doc();
    final request = LocationRequest(
      id: ref.id,
      type: LocationRequestType.district,
      name: name,
      missionId: missionId,
      regionId: regionId,
      regionName: regionName,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      status: LocationRequestStatus.pending,
      createdAt: DateTime.now(),
      note: note,
    );
    await ref.set(request.toMap());
  }

  Stream<List<LocationRequest>> streamPendingByMission(String missionId) {
    return _firestore
        .collection(_collection)
        .where('missionId', isEqualTo: missionId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LocationRequest.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> approve(LocationRequest request, String approvedBy) async {
    if (request.type == LocationRequestType.region) {
      final regionId = _firestore.collection('regions').doc().id;
      final code = request.name.trim().length >= 3
          ? request.name.trim().toUpperCase().substring(0, 3)
          : request.name.trim().toUpperCase();
      final region = Region(
        id: regionId,
        name: request.name.trim(),
        code: code,
        missionId: request.missionId,
        createdAt: DateTime.now(),
        createdBy: approvedBy,
      );
      await RegionService.instance.createRegion(region);
    } else {
      final districtId = _firestore.collection('districts').doc().id;
      final code = request.name.trim().length >= 3
          ? request.name.trim().toUpperCase().substring(0, 3)
          : request.name.trim().toUpperCase();
      final district = District(
        id: districtId,
        name: request.name.trim(),
        code: code,
        regionId: request.regionId!,
        missionId: request.missionId,
        createdAt: DateTime.now(),
        createdBy: approvedBy,
      );
      await DistrictService.instance.createDistrict(district);
    }

    await _firestore.collection(_collection).doc(request.id).update({
      'status': 'approved',
      'resolvedAt': Timestamp.now(),
      'resolvedBy': approvedBy,
    });
  }

  Future<void> reject(String requestId, String rejectedBy) async {
    await _firestore.collection(_collection).doc(requestId).update({
      'status': 'rejected',
      'resolvedAt': Timestamp.now(),
      'resolvedBy': rejectedBy,
    });
  }
}
