import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

class Staff {
  final String id;
  final String name;
  final String role;
  final String email;
  final String phone;
  final String mission;
  final String department;
  final String? district;
  final String? region;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.mission,
    required this.department,
    this.district,
    this.region,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'email': email,
      'phone': phone,
      'mission': mission,
      'department': department,
      'district': district,
      'region': region,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}

class DataImportService {
  static final DataImportService instance = DataImportService._internal();
  factory DataImportService() => instance;
  DataImportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, int>> importNSMStaffData() async {
    const String missionId =
        'M89PoDdB5sNCoDl8qTNS'; // North Sabah Mission Firestore ID
    const String missionName = 'North Sabah Mission';

    int staffCreated = 0;
    int staffSkipped = 0;

    try {
      // Load the JSON data from file system
      final String jsonFilePath = 'assets/NSM STAFF.json';
      final File jsonFile = File(jsonFilePath);
      final String jsonString = await jsonFile.readAsString();
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Delete all existing staff for this mission
      final existingStaff = await _firestore
          .collection('staff')
          .where('mission', isEqualTo: missionName)
          .get();

      for (var doc in existingStaff.docs) {
        await doc.reference.delete();
      }

      // Import officers
      if (jsonData.containsKey('officers')) {
        final officers = jsonData['officers'] as List<dynamic>;
        for (var officer in officers) {
          final staff = Staff(
            id: const Uuid().v4(),
            name: officer['name'] as String,
            role: officer['position']
                as String, // Use position as role for display
            email: officer['email'] as String,
            phone: officer['phone'] as String,
            mission: missionName,
            department: 'Executive',
            createdAt: DateTime.now(),
            createdBy: 'system_import',
          );
          await _firestore.collection('staff').doc(staff.id).set(staff.toMap());
          staffCreated++;
        }
      }

      // Import department directors
      if (jsonData.containsKey('department_directors')) {
        final directors = jsonData['department_directors'] as List<dynamic>;
        for (var director in directors) {
          final staff = Staff(
            id: const Uuid().v4(),
            name: director['name'] as String,
            role: director['position'] as String,
            email: director['email'] as String,
            phone: director['phone'] as String,
            mission: missionName,
            department: 'Department Directors',
            createdAt: DateTime.now(),
            createdBy: 'system_import',
          );
          await _firestore.collection('staff').doc(staff.id).set(staff.toMap());
          staffCreated++;
        }
      }

      // Import administrative assistants
      if (jsonData.containsKey('administrative_assistants')) {
        final assistants =
            jsonData['administrative_assistants'] as List<dynamic>;
        for (var assistant in assistants) {
          final staff = Staff(
            id: const Uuid().v4(),
            name: assistant['name'] as String,
            role: assistant['position'] as String,
            email: assistant['email'] as String,
            phone: assistant['phone'] as String,
            mission: missionName,
            department: 'Administrative',
            createdAt: DateTime.now(),
            createdBy: 'system_import',
          );
          await _firestore.collection('staff').doc(staff.id).set(staff.toMap());
          staffCreated++;
        }
      }

      // Import finance office staff
      if (jsonData.containsKey('finance_office')) {
        final financeStaff = jsonData['finance_office'] as List<dynamic>;
        for (var staffMember in financeStaff) {
          final staff = Staff(
            id: const Uuid().v4(),
            name: staffMember['name'] as String,
            role: staffMember['position'] as String,
            email: staffMember['email'] as String,
            phone: staffMember['phone'] as String,
            mission: missionName,
            department: 'Finance',
            createdAt: DateTime.now(),
            createdBy: 'system_import',
          );
          await _firestore.collection('staff').doc(staff.id).set(staff.toMap());
          staffCreated++;
        }
      }

      // Import field pastors by region
      if (jsonData.containsKey('field_pastors')) {
        final fieldPastors = jsonData['field_pastors'] as Map<String, dynamic>;
        for (var regionEntry in fieldPastors.entries) {
          final regionName = regionEntry.key; // e.g., "REGION 1"
          final pastors = regionEntry.value as List<dynamic>;

          for (var pastor in pastors) {
            final staff = Staff(
              id: const Uuid().v4(),
              name: pastor['name'] as String,
              role: 'Field Pastor',
              email: pastor['email'] as String,
              phone: pastor['phone'] as String,
              mission: missionName,
              department: 'Field Ministry',
              region: regionName,
              district:
                  pastor['assignment'] as String, // Use assignment as district
              notes: 'Region: $regionName, Assignment: ${pastor['assignment']}',
              createdAt: DateTime.now(),
              createdBy: 'system_import',
            );
            await _firestore
                .collection('staff')
                .doc(staff.id)
                .set(staff.toMap());
            staffCreated++;
          }
        }
      }

      return {
        'staffCreated': staffCreated,
        'staffSkipped': staffSkipped,
        'totalImported': staffCreated,
      };
    } catch (e) {
      throw 'Failed to import NSM staff data: $e';
    }
  }
}

void main() async {
  print('🚀 Starting NSM Staff Data Import...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyB1Z7SAsV8g5UcnZMLJmtj4UZfMzA7juRk',
        appId: '1:695678872591:web:0cd71e5809edd908f4c77a',
        messagingSenderId: '695678872591',
        projectId: 'pastor-report-e4c52',
        authDomain: 'pastor-report-e4c52.firebaseapp.com',
        storageBucket: 'pastor-report-e4c52.firebasestorage.app',
        measurementId: 'G-F9KBEM9XGJ',
      ),
    );

    print('📝 Initializing Data Import Service...');
    final dataImportService = DataImportService();

    print('👥 Importing NSM Staff Data...');
    final result = await dataImportService.importNSMStaffData();

    print('✅ Import completed successfully!');
    print('📊 Results:');
    print('   - Staff Created: ${result['staffCreated']}');
    print('   - Staff Skipped: ${result['staffSkipped']}');
    print('   - Total Imported: ${result['totalImported']}');
  } catch (e) {
    print('❌ Error during import: $e');
    rethrow;
  }
}
