// lib/services/activity_export_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/models/activity_model.dart';
import 'package:pastor_report/models/user_model.dart';

class ActivityExportService {
  static ActivityExportService? _instance;
  static ActivityExportService get instance {
    _instance ??= ActivityExportService._();
    return _instance!;
  }

  ActivityExportService._();

  /// Generate PDF report
  Future<File> generatePDF({
    required List<Activity> activities,
    required UserModel user,
    required double kmCost,
    required DateTime month,
  }) async {
    try {
    debugPrint('📄 Generating PDF for ${activities.length} activities');
    final pdf = pw.Document();

    // Calculate totals
    final totalKm = activities.fold<double>(
      0.0,
      (sum, activity) => sum + activity.mileage,
    );
    final totalCost = totalKm * kmCost;

    // Add page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Monthly Activities Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // User Profile
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Pastor Information',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildInfoRow('Name', user.displayName),
                        ),
                      ],
                    ),
                    if (user.role != null && user.role!.isNotEmpty)
                      _buildInfoRow('Position', user.role!),
                    if (user.mission != null && user.mission!.isNotEmpty)
                      _buildInfoRow('Mission', user.mission!),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Summary Statistics
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Total Activities',
                      activities.length.toString(),
                    ),
                    _buildSummaryItem(
                      'Total Distance',
                      '${totalKm.toStringAsFixed(1)} km',
                    ),
                    _buildSummaryItem(
                      'Total Cost',
                      'RM${totalCost.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Activities Table
              pw.Text(
                'Activities Details',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildTableHeader('Date'),
                      _buildTableHeader('Activities'),
                      _buildTableHeader('Location'),
                      _buildTableHeader('KM'),
                      _buildTableHeader('Cost (RM)'),
                    ],
                  ),

                  // Data Rows
                  ...activities.map((activity) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(
                          DateFormat('dd/MM/yyyy').format(activity.date),
                        ),
                        _buildTableCell(activity.activities),
                        _buildTableCell(activity.location ?? '-'),
                        _buildTableCell(activity.mileage.toStringAsFixed(1)),
                        _buildTableCell(
                          activity.calculateCost(kmCost).toStringAsFixed(2),
                        ),
                      ],
                    );
                  }),

                  // Total Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue50,
                    ),
                    children: [
                      _buildTableCell(
                        'TOTAL',
                        bold: true,
                      ),
                      _buildTableCell(''),
                      _buildTableCell(''),
                      _buildTableCell(
                        totalKm.toStringAsFixed(1),
                        bold: true,
                      ),
                      _buildTableCell(
                        totalCost.toStringAsFixed(2),
                        bold: true,
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF
    debugPrint('💾 Saving PDF file...');
    final directory = await getTemporaryDirectory();
    final fileName = 'Activities_${DateFormat('yyyy_MM').format(month)}.pdf';
    final file = File('${directory.path}/$fileName');
    final pdfBytes = await pdf.save();
    await file.writeAsBytes(pdfBytes);
    debugPrint('✅ PDF saved to: ${file.path}');

    return file;
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate Excel report
  Future<File> generateExcel({
    required List<Activity> activities,
    required UserModel user,
    required double kmCost,
    required DateTime month,
  }) async {
    try {
    debugPrint('📊 Generating Excel for ${activities.length} activities');
    final excel = Excel.createExcel();
    final sheet = excel['Activities Report'];

    // Calculate totals
    final totalKm = activities.fold<double>(
      0.0,
      (sum, activity) => sum + activity.mileage,
    );
    final totalCost = totalKm * kmCost;

    int currentRow = 0;

    // Title
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
    );
    var titleCell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
    titleCell.value = TextCellValue('Monthly Activities Report');
    titleCell.cellStyle = CellStyle(
      fontSize: 16,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
    currentRow++;

    // Month
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
    );
    var monthCell = sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
    monthCell.value = TextCellValue(DateFormat('MMMM yyyy').format(month));
    monthCell.cellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
    );
    currentRow += 2;

    // User Info
    _addExcelRow(sheet, currentRow++, ['Pastor Information', '']);
    _addExcelRow(sheet, currentRow++, ['Name:', user.displayName]);
    if (user.role != null && user.role!.isNotEmpty) {
      _addExcelRow(sheet, currentRow++, ['Position:', user.role!]);
    }
    if (user.mission != null && user.mission!.isNotEmpty) {
      _addExcelRow(sheet, currentRow++, ['Mission:', user.mission!]);
    }
    currentRow++;

    // Summary
    _addExcelRow(sheet, currentRow++, ['Summary', '']);
    _addExcelRow(
        sheet, currentRow++, ['Total Activities:', activities.length.toString()]);
    _addExcelRow(sheet, currentRow++,
        ['Total Distance:', '${totalKm.toStringAsFixed(1)} km']);
    _addExcelRow(sheet, currentRow++,
        ['Total Cost:', 'RM${totalCost.toStringAsFixed(2)}']);
    _addExcelRow(sheet, currentRow++,
        ['Rate:', 'RM${kmCost.toStringAsFixed(2)}/km']);
    currentRow++;

    // Activities Table Header
    var headerRow = currentRow;
    _addExcelRow(
      sheet,
      headerRow,
      ['Date', 'Activities', 'Location', 'KM', 'Cost (RM)'],
      bold: true,
    );
    currentRow++;

    // Activities Data
    for (final activity in activities) {
      _addExcelRow(
        sheet,
        currentRow++,
        [
          DateFormat('dd/MM/yyyy').format(activity.date),
          activity.activities,
          activity.location ?? '-',
          activity.mileage.toStringAsFixed(1),
          activity.calculateCost(kmCost).toStringAsFixed(2),
        ],
      );
    }

    // Total Row
    _addExcelRow(
      sheet,
      currentRow++,
      [
        'TOTAL',
        '',
        '',
        totalKm.toStringAsFixed(1),
        totalCost.toStringAsFixed(2),
      ],
      bold: true,
    );

    currentRow += 2;

    // Footer
    _addExcelRow(
      sheet,
      currentRow,
      [
        'Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      ],
    );

    // Set column widths
    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 50);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 18);

    // Save Excel
    debugPrint('💾 Encoding Excel file...');
    final directory = await getTemporaryDirectory();
    final fileName = 'Activities_${DateFormat('yyyy_MM').format(month)}.xlsx';
    final file = File('${directory.path}/$fileName');
    final bytes = excel.encode();

    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }

    debugPrint('💾 Writing Excel file to disk...');
    await file.writeAsBytes(bytes);
    debugPrint('✅ Excel saved to: ${file.path}');

    return file;
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating Excel: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Helper methods for PDF
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(value),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // Helper method for Excel
  void _addExcelRow(
    Sheet sheet,
    int rowIndex,
    List<String> values, {
    bool bold = false,
  }) {
    for (int i = 0; i < values.length; i++) {
      var cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
      cell.value = TextCellValue(values[i]);
      if (bold) {
        cell.cellStyle = CellStyle(bold: true);
      }
    }
  }
}
