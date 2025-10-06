import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/staff_model.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:uuid/uuid.dart';

class StaffService {
  static StaffService? _instance;
  static StaffService get instance {
    _instance ??= StaffService._();
    return _instance!;
  }

  StaffService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _staffCollection =
      FirebaseFirestore.instance.collection('staff');

  /// Stream all staff globally
  Stream<List<Staff>> streamAllStaff() {
    return _staffCollection.orderBy('name').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList());
  }

  /// Stream staff by mission
  Stream<List<Staff>> streamStaffByMission(String missionIdentifier) {
    print('StaffService: Streaming staff for mission: $missionIdentifier');

    // We need to create an async wrapper to handle the asynchronous mission resolution
    final controller = StreamController<List<Staff>>();

    // Handle the mission resolution and query setup asynchronously
    () async {
      // Try to resolve the mission name first
      final resolvedName =
          await MissionService.instance.getMissionNameFromId(missionIdentifier);
      final possibleMissions = <String>[missionIdentifier];

      if (resolvedName != null && resolvedName != missionIdentifier) {
        possibleMissions.add(resolvedName);
        print(
            'StaffService: Resolved mission ID to name: $missionIdentifier -> $resolvedName');
      }

      // Setup the query with both original ID and resolved name
      final stream = _staffCollection
          .where('mission', whereIn: possibleMissions)
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
        final result =
            snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
        print(
            'StaffService: Found ${result.length} staff members for mission: $missionIdentifier');
        return result;
      });

      // Forward all data from the query to our controller
      final subscription = stream.listen(
        (data) => controller.add(data),
        onError: (error) => controller.addError(error),
        onDone: () => controller.close(),
      );

      // Make sure we clean up when the controller is done
      controller.onCancel = () => subscription.cancel();
    }();

    // Return the stream from our controller
    return controller.stream;
  }

  /// Stream staff by multiple missions (for users with access to multiple missions)
  Stream<List<Staff>> streamStaffByMissions(List<String> missions) {
    if (missions.isEmpty) {
      return Stream.value([]);
    }

    print('StaffService: Streaming staff for multiple missions: $missions');

    // We need to create an async wrapper to handle the asynchronous mission resolution
    final controller = StreamController<List<Staff>>();

    // Handle the mission resolution and query setup asynchronously
    () async {
      // Try to resolve all mission names
      final possibleMissions = <String>[];

      // Add all original mission IDs
      possibleMissions.addAll(missions);

      // Try to resolve each mission name
      for (final missionId in missions) {
        final resolvedName =
            await MissionService.instance.getMissionNameFromId(missionId);
        if (resolvedName != null && !possibleMissions.contains(resolvedName)) {
          possibleMissions.add(resolvedName);
          print(
              'StaffService: Resolved mission ID to name: $missionId -> $resolvedName');
        }
      }

      // Setup the query with both original IDs and resolved names
      // Note: Firestore 'whereIn' has a limit of 10 items, so we might need to split queries
      // if we have too many missions after resolution
      if (possibleMissions.length <= 10) {
        // Single query if within limit
        final stream = _staffCollection
            .where('mission', whereIn: possibleMissions)
            .orderBy('name')
            .snapshots()
            .map((snapshot) {
          final result =
              snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
          print(
              'StaffService: Found ${result.length} staff members for missions: $missions');
          return result;
        });

        // Forward all data from the query to our controller
        final subscription = stream.listen(
          (data) => controller.add(data),
          onError: (error) => controller.addError(error),
          onDone: () => controller.close(),
        );

        // Make sure we clean up when the controller is done
        controller.onCancel = () => subscription.cancel();
      } else {
        // Multiple queries needed if exceeds limit
        print(
            'StaffService: Too many mission combinations (${possibleMissions.length}), splitting queries');

        // Track all unique staff to avoid duplicates from multiple queries
        final allStaff = <String, Staff>{};

        // Split into chunks of 10
        for (var i = 0; i < possibleMissions.length; i += 10) {
          final end = (i + 10 < possibleMissions.length)
              ? i + 10
              : possibleMissions.length;
          final chunk = possibleMissions.sublist(i, end);

          // Get staff for this chunk of missions
          final querySnapshot = await _staffCollection
              .where('mission', whereIn: chunk)
              .orderBy('name')
              .get();

          // Add to our results, avoiding duplicates
          for (final doc in querySnapshot.docs) {
            final staff = Staff.fromFirestore(doc);
            allStaff[staff.id] = staff;
          }
        }

        // Emit the combined result once
        controller.add(allStaff.values.toList());

        // Close the controller as we've handled everything synchronously
        controller.close();
      }
    }();

    // Return the stream from our controller
    return controller.stream;
  }

  /// Stream staff by district
  Stream<List<Staff>> streamStaffByDistrict(String districtId) {
    print('StaffService: Streaming staff for district: $districtId');
    return _staffCollection
        .where('district', isEqualTo: districtId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final staff = snapshot.docs.map((doc) {
        return Staff.fromFirestore(doc);
      }).toList();
      print(
          'StaffService: Found ${staff.length} staff members for district: $districtId');
      return staff;
    });
  }

  /// Get all staff (Future)
  Future<List<Staff>> getAllStaff() async {
    try {
      final snapshot = await _staffCollection.orderBy('name').get();
      return snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all staff: $e');
      return [];
    }
  }

  /// Get staff by mission (Future)
  Future<List<Staff>> getStaffByMission(String mission) async {
    try {
      final snapshot = await _staffCollection
          .where('mission', isEqualTo: mission)
          .orderBy('name')
          .get();
      return snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting staff by mission: $e');
      return [];
    }
  }

  /// Add a staff member
  Future<bool> addStaff(Staff staff) async {
    try {
      final id = staff.id.isEmpty ? const Uuid().v4() : staff.id;
      final staffWithId = staff.copyWith(id: id);

      await _staffCollection.doc(id).set(staffWithId.toJson());
      debugPrint('✅ Staff added: ${staff.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding staff: $e');
      return false;
    }
  }

  /// Update a staff member
  Future<bool> updateStaff(Staff staff) async {
    try {
      await _staffCollection.doc(staff.id).update(
            staff.copyWith(updatedAt: DateTime.now()).toJson(),
          );
      debugPrint('✅ Staff updated: ${staff.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating staff: $e');
      return false;
    }
  }

  /// Delete a staff member
  Future<bool> deleteStaff(String staffId) async {
    try {
      await _staffCollection.doc(staffId).delete();
      debugPrint('🗑️ Staff deleted: $staffId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting staff: $e');
      return false;
    }
  }

  /// Get staff by ID
  Future<Staff?> getStaffById(String staffId) async {
    try {
      final doc = await _staffCollection.doc(staffId).get();
      if (doc.exists) {
        return Staff.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting staff by ID: $e');
      return null;
    }
  }

  /// Bulk import staff from CSV data
  /// CSV format: name,role,email,phone,mission,department,district,region,notes
  Future<Map<String, dynamic>> importStaffFromCSV(
    String csvData,
    String createdBy,
  ) async {
    try {
      final lines = csvData.trim().split('\n');
      if (lines.isEmpty) {
        return {'success': false, 'message': 'Empty CSV file', 'imported': 0};
      }

      // Parse header
      final headers =
          lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();
      final requiredFields = ['name', 'role', 'mission'];

      // Validate headers
      for (final field in requiredFields) {
        if (!headers.contains(field)) {
          return {
            'success': false,
            'message': 'Missing required field: $field',
            'imported': 0
          };
        }
      }

      int imported = 0;
      int failed = 0;
      final errors = <String>[];

      // Process data rows
      for (int i = 1; i < lines.length; i++) {
        try {
          final values = lines[i].split(',').map((v) => v.trim()).toList();

          if (values.length != headers.length) {
            errors.add('Row ${i + 1}: Column count mismatch');
            failed++;
            continue;
          }

          // Create map from headers and values
          final rowData = <String, String>{};
          for (int j = 0; j < headers.length; j++) {
            rowData[headers[j]] = values[j];
          }

          // Validate required fields
          bool hasAllRequired = true;
          for (final field in requiredFields) {
            if (rowData[field]?.isEmpty ?? true) {
              errors.add('Row ${i + 1}: Missing $field');
              hasAllRequired = false;
              break;
            }
          }

          if (!hasAllRequired) {
            failed++;
            continue;
          }

          // Create staff object
          final staff = Staff(
            id: const Uuid().v4(),
            name: rowData['name']!,
            role: rowData['role']!,
            email: rowData['email']!,
            phone: rowData['phone']!,
            mission: rowData['mission']!,
            department: rowData['department'],
            district: rowData['district'],
            region: rowData['region'],
            notes: rowData['notes'],
            createdAt: DateTime.now(),
            createdBy: createdBy,
          );

          // Add to Firestore
          await addStaff(staff);
          imported++;
        } catch (e) {
          errors.add('Row ${i + 1}: $e');
          failed++;
        }
      }

      return {
        'success': true,
        'imported': imported,
        'failed': failed,
        'errors': errors,
        'message':
            'Imported $imported staff members${failed > 0 ? ', $failed failed' : ''}',
      };
    } catch (e) {
      debugPrint('❌ Error importing CSV: $e');
      return {
        'success': false,
        'message': 'Error parsing CSV: $e',
        'imported': 0
      };
    }
  }

  /// Export staff to CSV format
  Future<String> exportStaffToCSV(List<Staff> staffList) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        'name,role,email,phone,mission,department,district,region,notes');

    // Data rows
    for (final staff in staffList) {
      buffer.write('${_escapeCsv(staff.name)},');
      buffer.write('${_escapeCsv(staff.role)},');
      buffer.write('${_escapeCsv(staff.email)},');
      buffer.write('${_escapeCsv(staff.phone)},');
      buffer.write('${_escapeCsv(staff.mission)},');
      buffer.write('${_escapeCsv(staff.department ?? '')},');
      buffer.write('${_escapeCsv(staff.district ?? '')},');
      buffer.write('${_escapeCsv(staff.region ?? '')},');
      buffer.write(_escapeCsv(staff.notes ?? ''));
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Escape CSV values (handle commas and quotes)
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Get statistics by mission
  Future<Map<String, dynamic>> getStatisticsByMission(String mission) async {
    try {
      final staff = await getStaffByMission(mission);

      // Group by role
      final roleCount = <String, int>{};
      for (final s in staff) {
        roleCount[s.role] = (roleCount[s.role] ?? 0) + 1;
      }

      // Group by department
      final deptCount = <String, int>{};
      for (final s in staff) {
        if (s.department != null && s.department!.isNotEmpty) {
          deptCount[s.department!] = (deptCount[s.department!] ?? 0) + 1;
        }
      }

      return {
        'totalStaff': staff.length,
        'byRole': roleCount,
        'byDepartment': deptCount,
      };
    } catch (e) {
      debugPrint('❌ Error getting statistics: $e');
      return {'totalStaff': 0, 'byRole': {}, 'byDepartment': {}};
    }
  }
}
