import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/services/staff_service.dart';

class StaffDataFixer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final StaffService _staffService = StaffService.instance;

  /// Fix staff records where the 'notes' field was incorrectly set as an array
  /// instead of a string, which causes type casting errors
  static Future<Map<String, dynamic>> fixStaffNotesData() async {
    try {
      print('StaffDataFixer: Starting notes field fix...');

      int corrected = 0;
      int errors = 0;
      int skipped = 0;

      // Get all staff records
      final staffSnapshot = await _firestore.collection('staff').get();

      for (var doc in staffSnapshot.docs) {
        try {
          final data = doc.data();

          // Check if the 'notes' field is an array/list
          if (data.containsKey('notes') && data['notes'] != null) {
            if (data['notes'] is List) {
              // Convert list to string by joining elements
              List<dynamic> notesList = data['notes'] as List<dynamic>;
              String notesString = notesList.join('\n');

              // Update the document to change array back to string
              await _firestore.collection('staff').doc(doc.id).update({
                'notes': notesString,
              });

              print('Fixed notes for staff: ${doc.id}');
              corrected++;
            } else {
              // Already a string, skip
              skipped++;
            }
          } else {
            // No notes field or null, skip
            skipped++;
          }
        } catch (e) {
          print('Error fixing staff ${doc.id}: $e');
          errors++;
        }
      }

      print(
          'StaffDataFixer: Fix completed. Corrected: $corrected, Errors: $errors, Skipped: $skipped');
      return {
        'success': true,
        'corrected': corrected,
        'errors': errors,
        'skipped': skipped,
        'message': 'Fixed $corrected staff records with array notes fields.'
      };
    } catch (e) {
      print('StaffDataFixer: Error during fix: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error fixing staff notes: $e'
      };
    }
  }
}
