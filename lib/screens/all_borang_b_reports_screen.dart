import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';

class AllBorangBReportsScreen extends StatefulWidget {
  const AllBorangBReportsScreen({super.key});

  @override
  State<AllBorangBReportsScreen> createState() =>
      _AllBorangBReportsScreenState();
}

class _AllBorangBReportsScreenState extends State<AllBorangBReportsScreen> {
  final BorangBFirestoreService _firestoreService =
      BorangBFirestoreService.instance;
  List<BorangBData> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports() async {
    setState(() => _isLoading = true);
    try {
      // This method will be created in the service
      final reports = await _firestoreService.getAllReports();
      if (mounted) {
        setState(() {
          _reports = reports..sort((a, b) => b.month.compareTo(a.month));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading all Borang B reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _viewReport(BorangBData report) {
    Navigator.pushNamed(
      context,
      '/borang-b-preview',
      arguments: {
        'data': report,
        'month': report.month,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Borang B Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Text('No reports found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(
                          'Report for ${DateFormat('MMMM yyyy').format(report.month)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Submitted by: ${report.userName}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _viewReport(report),
                      ),
                    );
                  },
                ),
    );
  }
}
