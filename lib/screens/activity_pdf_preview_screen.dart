import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pastor_report/models/activity_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/activity_export_service.dart';
import 'package:pastor_report/utils/constants.dart';

class ActivityPdfPreviewScreen extends StatelessWidget {
  final List<Activity> activities;
  final UserModel user;
  final double kmCost;
  final DateTime month;

  const ActivityPdfPreviewScreen({
    super.key,
    required this.activities,
    required this.user,
    required this.kmCost,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Preview — ${DateFormat('MMMM yyyy').format(month)}',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (_) => ActivityExportService.instance.buildPDFBytes(
          activities: activities,
          user: user,
          kmCost: kmCost,
          month: month,
        ),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Activities_${DateFormat('yyyy_MM').format(month)}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
