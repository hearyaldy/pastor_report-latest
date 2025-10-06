import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/utils/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ExportReportScreen extends StatefulWidget {
  final Church church;
  final DateTime selectedMonth;

  const ExportReportScreen({
    super.key,
    required this.church,
    required this.selectedMonth,
  });

  @override
  State<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends State<ExportReportScreen> {
  final FinancialReportService _reportService = FinancialReportService();
  bool _isLoading = true;
  FinancialReport? _report;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final report = await _reportService.getReportByChurchAndMonth(
        widget.church.id,
        widget.selectedMonth,
      );

      setState(() {
        _report = report;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load report: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data to export')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Financial Report'];

      // Add title
      sheet.merge(CellIndex.indexByString("A1"), CellIndex.indexByString("E1"));
      final titleCell = sheet.cell(CellIndex.indexByString("A1"));
      titleCell.value =
          TextCellValue('${widget.church.churchName} - Financial Report');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Add report month
      sheet.merge(CellIndex.indexByString("A2"), CellIndex.indexByString("E2"));
      final monthCell = sheet.cell(CellIndex.indexByString("A2"));
      monthCell.value =
          TextCellValue(DateFormat('MMMM yyyy').format(_report!.month));
      monthCell.cellStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
      );

      // Add headers
      final headers = [
        'Category',
        'Amount (RM)',
        '',
        'Status',
        _report!.status.toUpperCase()
      ];
      for (var i = 0; i < headers.length; i++) {
        final cell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString("#DDDDDD"),
        );
      }

      // Add data
      final data = [
        ['Tithe', _report!.tithe.toString()],
        ['Offerings', _report!.offerings.toString()],
        ['Special Offerings', _report!.specialOfferings.toString()],
        ['TOTAL', _report!.totalFinancial.toString()],
      ];

      for (var i = 0; i < data.length; i++) {
        final rowIndex = 4 + i;
        final isBold = i == data.length - 1; // Make total row bold

        final categoryCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
        categoryCell.value = TextCellValue(data[i][0]);
        if (isBold) categoryCell.cellStyle = CellStyle(bold: true);

        final amountCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
        amountCell.value = TextCellValue(data[i][1]);
        if (isBold) amountCell.cellStyle = CellStyle(bold: true);
      }

      // Add notes if available
      if (_report!.notes != null && _report!.notes!.isNotEmpty) {
        final notesRow = 9;
        final notesHeaderCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: notesRow));
        notesHeaderCell.value = TextCellValue('Notes');
        notesHeaderCell.cellStyle = CellStyle(bold: true);

        sheet.merge(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: notesRow + 1),
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: notesRow + 1));
        final notesCell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: notesRow + 1));
        notesCell.value = TextCellValue(_report!.notes ?? '');
      }

      // Add submission info
      final submissionRow = 12;
      final submissionHeaderCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: submissionRow));
      submissionHeaderCell.value = TextCellValue('Submitted on:');
      submissionHeaderCell.cellStyle = CellStyle(bold: true);

      final submissionDateCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: submissionRow));
      submissionDateCell.value = TextCellValue(
          DateFormat('dd MMM yyyy, HH:mm').format(_report!.submittedAt));

      // Auto-size columns
      for (var i = 0; i < 5; i++) {
        sheet.setColumnWidth(i, 15.0);
      }

      // Save the file
      final directory = await getTemporaryDirectory();
      final fileName =
          '${widget.church.churchName.replaceAll(' ', '_')}_Financial_Report_${DateFormat('MMM_yyyy').format(_report!.month)}.xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Share the file
        await Share.shareXFiles(
          [XFile(filePath)],
          subject:
              '${widget.church.churchName} - Financial Report (${DateFormat('MMMM yyyy').format(_report!.month)})',
          text:
              'Please find attached the financial report for ${DateFormat('MMMM yyyy').format(_report!.month)}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting Excel: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data to export')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${widget.church.churchName} - Financial Report',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          DateFormat('MMMM yyyy').format(_report!.month),
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Status
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: _report!.status.toLowerCase() == 'approved'
                          ? PdfColors.green100
                          : _report!.status.toLowerCase() == 'submitted'
                              ? PdfColors.blue100
                              : PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'Status: ${_report!.status.toUpperCase()}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Financial data
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfRow('Tithe', _report!.tithe),
                          pw.Divider(),
                          _buildPdfRow('Offerings', _report!.offerings),
                          pw.Divider(),
                          _buildPdfRow(
                              'Special Offerings', _report!.specialOfferings),
                          pw.Divider(),
                          _buildPdfRow('TOTAL', _report!.totalFinancial,
                              isBold: true),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Notes section
                  if (_report!.notes != null && _report!.notes!.isNotEmpty) ...[
                    pw.Text(
                      'Notes:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(_report!.notes!),
                    ),
                    pw.SizedBox(height: 20),
                  ],

                  // Footer with submission info
                  pw.Divider(),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Submitted on: ${DateFormat('dd MMM yyyy, HH:mm').format(_report!.submittedAt)}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Generated on: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save the file
      final directory = await getTemporaryDirectory();
      final fileName =
          '${widget.church.churchName.replaceAll(' ', '_')}_Financial_Report_${DateFormat('MMM_yyyy').format(_report!.month)}.pdf';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject:
            '${widget.church.churchName} - Financial Report (${DateFormat('MMMM yyyy').format(_report!.month)})',
        text:
            'Please find attached the financial report for ${DateFormat('MMMM yyyy').format(_report!.month)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  pw.Widget _buildPdfRow(String label, double amount, {bool isBold = false}) {
    final textStyle = isBold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
        : const pw.TextStyle();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: textStyle),
        pw.Text('RM ${amount.toStringAsFixed(2)}', style: textStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        title: const Text('Export Financial Report'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildExportOptions(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Report',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptions() {
    return _report == null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.file_copy_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No Report Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No financial report found for ${DateFormat('MMMM yyyy').format(widget.selectedMonth)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        : Column(
            children: [
              // Report summary card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.church.churchName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Financial Report - ${DateFormat('MMMM yyyy').format(_report!.month)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Status', _report!.status.toUpperCase()),
                        _buildInfoRow(
                            'Tithe', 'RM ${_report!.tithe.toStringAsFixed(2)}'),
                        _buildInfoRow('Offerings',
                            'RM ${_report!.offerings.toStringAsFixed(2)}'),
                        _buildInfoRow('Special Offerings',
                            'RM ${_report!.specialOfferings.toStringAsFixed(2)}'),
                        const Divider(),
                        _buildInfoRow('Total',
                            'RM ${_report!.totalFinancial.toStringAsFixed(2)}',
                            isBold: true),
                      ],
                    ),
                  ),
                ),
              ),

              // Export options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildExportButton(
                            icon: Icons.picture_as_pdf,
                            label: 'Export as PDF',
                            color: Colors.red,
                            onTap: _isExporting ? null : _exportToPDF,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildExportButton(
                            icon: Icons.table_chart,
                            label: 'Export as Excel',
                            color: Colors.green,
                            onTap: _isExporting ? null : _exportToExcel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    final textStyle = isBold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text(value, style: textStyle),
        ],
      ),
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: painting.Border.all(color: color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isExporting
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 40,
                      color: color,
                    ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
