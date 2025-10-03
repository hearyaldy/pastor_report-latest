// lib/services/borang_b_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/models/user_model.dart';

class BorangBService {
  static BorangBService? _instance;
  static BorangBService get instance {
    _instance ??= BorangBService._();
    return _instance!;
  }

  BorangBService._();

  /// Generate Borang B report using the template
  Future<File> generateBorangB({
    required BorangBData borangBData,
    required UserModel user,
    required DateTime month,
  }) async {
    try {
      debugPrint('📋 Generating Borang B report for ${DateFormat('MMMM yyyy').format(month)}');

      // Load the template from assets
      final ByteData data = await rootBundle.load(
        'assets/SAB Ministerial Pastoral Monthly Report-New - Borang A & B.xlsx',
      );
      final bytes = data.buffer.asUint8List();

      debugPrint('📄 Loading Excel template...');
      final excel = Excel.decodeBytes(bytes);

      // Get the Borang B sheet (adjust sheet name as needed)
      // Common sheet names might be: 'Borang B', 'Sheet2', 'Form B', etc.
      Sheet? sheet;

      // Try to find Borang B sheet
      for (var sheetName in excel.tables.keys) {
        debugPrint('Found sheet: $sheetName');
        if (sheetName.toLowerCase().contains('borang b') ||
            sheetName.toLowerCase().contains('form b')) {
          sheet = excel.tables[sheetName];
          debugPrint('Using sheet: $sheetName for Borang B');
          break;
        }
      }

      // If no specific sheet found, use the second sheet or first available
      if (sheet == null) {
        final sheetNames = excel.tables.keys.toList();
        if (sheetNames.length > 1) {
          sheet = excel.tables[sheetNames[1]]; // Try second sheet
          debugPrint('Using second sheet: ${sheetNames[1]}');
        } else if (sheetNames.isNotEmpty) {
          sheet = excel.tables[sheetNames[0]]; // Use first sheet
          debugPrint('Using first sheet: ${sheetNames[0]}');
        } else {
          throw Exception('No sheets found in template');
        }
      }

      if (sheet == null) {
        throw Exception('Could not find or create sheet');
      }

      // Fill in the template with data
      await _fillBorangBTemplate(
        sheet: sheet,
        borangBData: borangBData,
        user: user,
        month: month,
      );

      // Save the filled template
      debugPrint('💾 Saving Borang B file...');
      final directory = await getTemporaryDirectory();
      final fileName =
          'Borang_B_${user.displayName}_${DateFormat('yyyy_MM').format(month)}.xlsx';
      final file = File('${directory.path}/$fileName');

      final encodedBytes = excel.encode();
      if (encodedBytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      await file.writeAsBytes(encodedBytes);
      debugPrint('✅ Borang B saved to: ${file.path}');

      return file;
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating Borang B: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fill the Borang B template with ministry data
  Future<void> _fillBorangBTemplate({
    required Sheet sheet,
    required BorangBData borangBData,
    required UserModel user,
    required DateTime month,
  }) async {
    debugPrint('📝 Filling Borang B template...');

    // Fill user information
    _setCellValue(sheet, 'B2', user.displayName);
    _setCellValue(sheet, 'B3', user.role ?? '');
    _setCellValue(sheet, 'B4', user.mission ?? '');
    _setCellValue(sheet, 'B5', DateFormat('MMMM yyyy').format(month));

    // Church Membership Statistics (starting around row 8)
    _setCellValue(sheet, 'C8', borangBData.membersBeginning.toString());
    _setCellValue(sheet, 'C9', borangBData.membersReceived.toString());
    _setCellValue(sheet, 'C10', borangBData.membersTransferredIn.toString());
    _setCellValue(sheet, 'C11', borangBData.membersTransferredOut.toString());
    _setCellValue(sheet, 'C12', borangBData.membersDropped.toString());
    _setCellValue(sheet, 'C13', borangBData.membersDeceased.toString());
    _setCellValue(sheet, 'C14', borangBData.membersEnd.toString());

    // Baptisms & Professions (around row 16)
    _setCellValue(sheet, 'C16', borangBData.baptisms.toString());
    _setCellValue(sheet, 'C17', borangBData.professionOfFaith.toString());

    // Church Services (around row 19)
    _setCellValue(sheet, 'C19', borangBData.sabbathServices.toString());
    _setCellValue(sheet, 'C20', borangBData.prayerMeetings.toString());
    _setCellValue(sheet, 'C21', borangBData.bibleStudies.toString());
    _setCellValue(sheet, 'C22', borangBData.evangelisticMeetings.toString());

    // Visitations (around row 24)
    _setCellValue(sheet, 'C24', borangBData.homeVisitations.toString());
    _setCellValue(sheet, 'C25', borangBData.hospitalVisitations.toString());
    _setCellValue(sheet, 'C26', borangBData.prisonVisitations.toString());

    // Special Events (around row 28)
    _setCellValue(sheet, 'C28', borangBData.weddings.toString());
    _setCellValue(sheet, 'C29', borangBData.funerals.toString());
    _setCellValue(sheet, 'C30', borangBData.dedications.toString());

    // Literature (around row 32)
    _setCellValue(sheet, 'C32', borangBData.booksDistributed.toString());
    _setCellValue(sheet, 'C33', borangBData.magazinesDistributed.toString());
    _setCellValue(sheet, 'C34', borangBData.tractsDistributed.toString());

    // Financial (around row 36)
    _setCellValue(sheet, 'C36', borangBData.tithe.toStringAsFixed(2));
    _setCellValue(sheet, 'C37', borangBData.offerings.toStringAsFixed(2));

    // Text fields (around row 39)
    _setCellValue(sheet, 'B39', borangBData.otherActivities);
    _setCellValue(sheet, 'B41', borangBData.challenges);
    _setCellValue(sheet, 'B43', borangBData.remarks);

    // Footer
    _setCellValue(
      sheet,
      'B45',
      'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );

    debugPrint('✅ Template filled with Borang B data');
  }

  /// Helper method to set cell value by cell reference (e.g., "A1", "B5")
  void _setCellValue(Sheet sheet, String cellRef, String value) {
    try {
      final cellIndex = CellIndex.indexByString(cellRef);
      final cell = sheet.cell(cellIndex);
      cell.value = TextCellValue(value);
    } catch (e) {
      debugPrint('⚠️ Warning: Could not set cell $cellRef: $e');
    }
  }

  /// Generate a blank Borang B template for users to download
  Future<File> downloadTemplate() async {
    try {
      debugPrint('📥 Downloading Borang B template...');

      final ByteData data = await rootBundle.load(
        'assets/SAB Ministerial Pastoral Monthly Report-New - Borang A & B.xlsx',
      );
      final bytes = data.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final fileName = 'Borang_B_Template.xlsx';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(bytes);
      debugPrint('✅ Template downloaded to: ${file.path}');

      return file;
    } catch (e) {
      debugPrint('❌ Error downloading template: $e');
      rethrow;
    }
  }

  /// Get a preview of what data will be in the report
  Map<String, dynamic> getReportPreview({
    required BorangBData borangBData,
    required UserModel user,
    required DateTime month,
  }) {
    return {
      'userName': user.displayName,
      'position': user.role ?? '',
      'mission': user.mission ?? '',
      'month': DateFormat('MMMM yyyy').format(month),
      'baptisms': borangBData.baptisms,
      'membersEnd': borangBData.membersEnd,
      'totalVisitations': borangBData.totalVisitations,
      'totalLiterature': borangBData.totalLiterature,
      'totalFinancial': borangBData.totalFinancial.toStringAsFixed(2),
    };
  }
}
