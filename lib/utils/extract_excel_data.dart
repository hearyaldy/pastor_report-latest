import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';

/// Utility to extract staff/coworker data from the Excel file
Future<void> extractStaffData() async {
  try {
    // Load the Excel file from assets
    final ByteData data = await rootBundle.load(
      'assets/SAB Ministerial Pastoral Monthly Report-New - Borang A & B.xlsx',
    );
    final bytes = data.buffer.asUint8List();

    // Parse Excel
    final excel = Excel.decodeBytes(bytes);

    // Print all sheet names to find the correct one
    print('📊 Available sheets:');
    for (var sheetName in excel.tables.keys) {
      print('  - $sheetName');
    }

    // Look for Name List or Coworker sheet
    String? targetSheet;
    for (var sheetName in excel.tables.keys) {
      final lowerName = sheetName.toLowerCase();
      if (lowerName.contains('name') ||
          lowerName.contains('coworker') ||
          lowerName.contains('staff') ||
          lowerName.contains('list')) {
        targetSheet = sheetName;
        break;
      }
    }

    if (targetSheet == null) {
      print('❌ Could not find Name List/Coworker sheet');
      return;
    }

    print('\n📋 Reading sheet: $targetSheet');

    final sheet = excel.tables[targetSheet];
    if (sheet == null) {
      print('❌ Sheet is null');
      return;
    }

    print('\n📊 Sheet has ${sheet.maxRows} rows and ${sheet.maxColumns} columns');

    // Find header row (look for "NAME" or "BIL")
    int headerRow = 0;
    for (var row = 0; row < 10; row++) {
      for (var col = 0; col < sheet.maxColumns; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        final value = cell?.value?.toString().toUpperCase() ?? '';
        if (value.contains('NAME') || value.contains('NAMA')) {
          headerRow = row;
          break;
        }
      }
      if (headerRow > 0) break;
    }

    print('\n📌 Headers found at row $headerRow:');
    final headers = <String>[];
    for (var i = 0; i < (sheet.maxColumns); i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow));
      final value = cell?.value?.toString() ?? '';
      headers.add(value);
      print('  Column $i: $value');
    }

    // Print sample data (first 5 rows after header)
    final dataStartRow = headerRow + 1;
    print('\n📄 Sample data (first 5 rows after header):');
    for (var row = dataStartRow; row < (dataStartRow + 5 < sheet.maxRows ? dataStartRow + 5 : sheet.maxRows); row++) {
      print('\n  Row $row:');
      for (var col = 0; col < (sheet.maxColumns); col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        final header = headers.length > col ? headers[col] : 'Column $col';
        final value = cell?.value?.toString() ?? '';
        if (value.isNotEmpty) {
          print('    $header: $value');
        }
      }
    }

    // Generate CSV
    print('\n📝 Generating CSV format...\n');
    print('name,role,email,phone,mission,department,district,region,notes');

    // Try to map columns based on headers
    final nameIdx = _findColumnIndex(headers, ['name', 'nama']);
    final roleIdx = _findColumnIndex(headers, ['role', 'position', 'jawatan']);
    final emailIdx = _findColumnIndex(headers, ['email', 'e-mail']);
    final phoneIdx = _findColumnIndex(headers, ['phone', 'telefon', 'tel', 'no']);
    final districtIdx = _findColumnIndex(headers, ['district', 'daerah']);
    final regionIdx = _findColumnIndex(headers, ['region', 'kawasan']);

    if (nameIdx == -1) {
      print('❌ Could not find Name column');
      return;
    }

    for (var row = dataStartRow; row < sheet.maxRows; row++) {
      final name = _getCellValue(sheet, row, nameIdx);
      if (name.isEmpty) continue;

      final role = _getCellValue(sheet, row, roleIdx);
      final email = _getCellValue(sheet, row, emailIdx);
      final phone = _getCellValue(sheet, row, phoneIdx);
      final district = _getCellValue(sheet, row, districtIdx);
      final region = _getCellValue(sheet, row, regionIdx);

      // Use default role if not specified
      final finalRole = role.isEmpty ? 'Pastor' : role;

      print('$name,$finalRole,$email,$phone,Sabah Mission,,$district,$region,');
    }

    print('\n✅ Extraction complete!');

  } catch (e) {
    print('❌ Error: $e');
  }
}

int _findColumnIndex(List<String> headers, List<String> searchTerms) {
  for (var i = 0; i < headers.length; i++) {
    final header = headers[i].toLowerCase();
    for (var term in searchTerms) {
      if (header.contains(term.toLowerCase())) {
        return i;
      }
    }
  }
  return -1;
}

String _getCellValue(Sheet sheet, int row, int col) {
  if (col == -1) return '';
  final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
  return cell?.value?.toString().trim() ?? '';
}
