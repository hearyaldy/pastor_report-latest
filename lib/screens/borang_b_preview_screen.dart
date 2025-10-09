import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_service.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/constants.dart';

class BorangBPreviewScreen extends StatefulWidget {
  const BorangBPreviewScreen({super.key});

  @override
  State<BorangBPreviewScreen> createState() => _BorangBPreviewScreenState();
}

class _BorangBPreviewScreenState extends State<BorangBPreviewScreen> {
  final BorangBService _exportService = BorangBService.instance;
  bool _isExporting = false;

  Future<void> _showExportOptions(BorangBData data, DateTime month) async {
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Format'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'excel'),
            icon: const Icon(Icons.table_chart),
            label: const Text('Excel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'pdf'),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );

    if (format != null) {
      _exportReport(data, month, format);
    }
  }

  Future<void> _showShareOptions(BorangBData data, DateTime month) async {
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Report'),
        content: const Text('Choose format to share:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'csv'),
            icon: const Icon(Icons.table_chart),
            label: const Text('CSV'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'text'),
            icon: const Icon(Icons.text_snippet),
            label: const Text('Text Summary'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );

    if (format != null) {
      _shareReport(data, month, format);
    }
  }

  Future<void> _shareReport(
      BorangBData data, DateTime month, String format) async {
    setState(() => _isExporting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not found');
      }

      if (format == 'csv') {
        final csv = BorangBFirestoreService.instance.exportToCSV([data]);
        await Share.share(
          csv,
          subject: 'Borang B - ${DateFormat('MMMM yyyy').format(month)}',
        );
      } else {
        // Text summary
        final summary = _generateTextSummary(data, month, user);
        await Share.share(
          summary,
          subject: 'Borang B - ${DateFormat('MMMM yyyy').format(month)}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report shared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _generateTextSummary(BorangBData data, DateTime month, user) {
    return '''
BORANG B - MONTHLY PASTORAL REPORT
${DateFormat('MMMM yyyy').format(month)}

Pastor: ${user.displayName ?? 'N/A'}
Mission: ${user.mission ?? 'N/A'}
District: ${user.district ?? 'N/A'}

CHURCH MEMBERSHIP STATISTICS
- Members at Beginning: ${data.membersBeginning}
- Members Received: ${data.membersReceived}
- Transferred In: ${data.membersTransferredIn}
- Transferred Out: ${data.membersTransferredOut}
- Dropped/Removed: ${data.membersDropped}
- Deceased: ${data.membersDeceased}
- Members at End: ${data.membersEnd}

BAPTISMS & PROFESSIONS
- Baptisms: ${data.baptisms}
- Professions of Faith: ${data.professionOfFaith}

CHURCH SERVICES
- Sabbath Services: ${data.sabbathServices}
- Prayer Meetings: ${data.prayerMeetings}
- Bible Studies: ${data.bibleStudies}
- Evangelistic Meetings: ${data.evangelisticMeetings}

VISITATIONS
- Home Visitations: ${data.homeVisitations}
- Hospital Visitations: ${data.hospitalVisitations}
- Prison Visitations: ${data.prisonVisitations}

SPECIAL EVENTS
- Weddings: ${data.weddings}
- Funerals: ${data.funerals}
- Baby Dedications: ${data.dedications}

LITERATURE DISTRIBUTION
- Books Distributed: ${data.booksDistributed}
- Magazines Distributed: ${data.magazinesDistributed}
- Tracts Distributed: ${data.tractsDistributed}

TITHES & OFFERINGS
- Tithe: RM ${data.tithe.toStringAsFixed(2)}
- Offerings: RM ${data.offerings.toStringAsFixed(2)}
- Total: RM ${(data.tithe + data.offerings).toStringAsFixed(2)}

${data.otherActivities.isNotEmpty ? '\nOTHER ACTIVITIES\n${data.otherActivities}\n' : ''}${data.challenges.isNotEmpty ? '\nCHALLENGES FACED\n${data.challenges}\n' : ''}${data.remarks.isNotEmpty ? '\nREMARKS\n${data.remarks}' : ''}
''';
  }

  Future<void> _exportReport(
      BorangBData data, DateTime month, String format) async {
    setState(() => _isExporting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        throw Exception('User not found');
      }

      final File file;
      if (format == 'pdf') {
        file = await _exportService.generateBorangBPdf(
          borangBData: data,
          user: user,
          month: month,
        );
      } else {
        file = await _exportService.generateBorangB(
          borangBData: data,
          user: user,
          month: month,
        );
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Borang B - ${DateFormat('MMMM yyyy').format(month)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Borang B exported as ${format.toUpperCase()} successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final BorangBData data = args['data'] as BorangBData;
    final DateTime month = args['month'] as DateTime;
    final String? districtName = args['districtName'] as String?;
    final String? missionName = args['missionName'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text('Borang B - ${DateFormat('MMMM yyyy').format(month)}'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed:
                _isExporting ? null : () => _showShareOptions(data, month),
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed:
                _isExporting ? null : () => _showExportOptions(data, month),
            tooltip: 'Export',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(data, month, districtName, missionName),
            const SizedBox(height: 24),

            // Church Membership Statistics
            _buildTableSection(
              'Church Membership Statistics',
              Icons.people,
              Colors.blue,
              [
                _TableRow('Members at Beginning', data.membersBeginning),
                _TableRow('Members Received', data.membersReceived),
                _TableRow('Transferred In', data.membersTransferredIn),
                _TableRow('Transferred Out', data.membersTransferredOut),
                _TableRow('Dropped/Removed', data.membersDropped),
                _TableRow('Deceased', data.membersDeceased),
                _TableRow('Members at End', data.membersEnd, isBold: true),
              ],
            ),
            const SizedBox(height: 16),

            // Baptisms & Professions
            _buildTableSection(
              'Baptisms & Professions',
              Icons.water_drop,
              Colors.cyan,
              [
                _TableRow('Baptisms', data.baptisms),
                _TableRow('Professions of Faith', data.professionOfFaith),
              ],
            ),
            const SizedBox(height: 16),

            // Church Services
            _buildTableSection(
              'Church Services',
              Icons.church,
              Colors.purple,
              [
                _TableRow('Sabbath Services', data.sabbathServices),
                _TableRow('Prayer Meetings', data.prayerMeetings),
                _TableRow('Bible Studies', data.bibleStudies),
                _TableRow('Evangelistic Meetings', data.evangelisticMeetings),
              ],
            ),
            const SizedBox(height: 16),

            // Visitations
            _buildTableSection(
              'Visitations',
              Icons.home,
              Colors.green,
              [
                _TableRow('Home Visitations', data.homeVisitations),
                _TableRow('Hospital Visitations', data.hospitalVisitations),
                _TableRow('Prison Visitations', data.prisonVisitations),
              ],
            ),
            const SizedBox(height: 16),

            // Special Events
            _buildTableSection(
              'Special Events',
              Icons.event,
              Colors.orange,
              [
                _TableRow('Weddings', data.weddings),
                _TableRow('Funerals', data.funerals),
                _TableRow('Baby Dedications', data.dedications),
              ],
            ),
            const SizedBox(height: 16),

            // Literature Distribution
            _buildTableSection(
              'Literature Distribution',
              Icons.book,
              Colors.brown,
              [
                _TableRow('Books Distributed', data.booksDistributed),
                _TableRow('Magazines Distributed', data.magazinesDistributed),
                _TableRow('Tracts Distributed', data.tractsDistributed),
              ],
            ),
            const SizedBox(height: 16),

            // Tithes & Offerings
            _buildTableSection(
              'Tithes & Offerings',
              Icons.attach_money,
              Colors.teal,
              [
                _TableRow('Tithe', 'RM ${data.tithe.toStringAsFixed(2)}'),
                _TableRow(
                    'Offerings', 'RM ${data.offerings.toStringAsFixed(2)}'),
                _TableRow(
                  'Total',
                  'RM ${(data.tithe + data.offerings).toStringAsFixed(2)}',
                  isBold: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Additional Information
            if (data.otherActivities.isNotEmpty ||
                data.challenges.isNotEmpty ||
                data.remarks.isNotEmpty)
              _buildTextSection(
                'Additional Information',
                Icons.notes,
                Colors.indigo,
                [
                  if (data.otherActivities.isNotEmpty)
                    _buildTextItem('Other Activities', data.otherActivities),
                  if (data.challenges.isNotEmpty)
                    _buildTextItem('Challenges Faced', data.challenges),
                  if (data.remarks.isNotEmpty)
                    _buildTextItem('Remarks', data.remarks),
                ],
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed:
                _isExporting ? null : () => _showShareOptions(data, month),
            backgroundColor: Colors.blue.shade700,
            heroTag: 'share',
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed:
                _isExporting ? null : () => _showExportOptions(data, month),
            backgroundColor: AppColors.primaryLight,
            heroTag: 'export',
            icon: _isExporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BorangBData data, DateTime month, String? districtName,
      String? missionName) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BORANG B - MONTHLY PASTORAL REPORT',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Pastor', data.userName),
            _buildInfoRow('Mission', missionName ?? data.missionId ?? 'N/A'),
            _buildInfoRow('District', districtName ?? data.districtId ?? 'N/A'),
            _buildInfoRow('Month', DateFormat('MMMM yyyy').format(month)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection(
    String title,
    IconData icon,
    Color color,
    List<_TableRow> rows,
  ) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
            },
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300),
            ),
            children: rows.map((row) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      row.label,
                      style: TextStyle(
                        fontWeight:
                            row.isBold ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      row.value.toString(),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight:
                            row.isBold ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> items,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildTextItem(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _TableRow {
  final String label;
  final dynamic value;
  final bool isBold;

  _TableRow(this.label, this.value, {this.isBold = false});
}
