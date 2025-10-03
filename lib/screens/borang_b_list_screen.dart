import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_storage_service.dart';
import 'package:pastor_report/services/borang_b_backup_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/widgets/borang_b_bottom_sheet.dart';

class BorangBListScreen extends StatefulWidget {
  const BorangBListScreen({super.key});

  @override
  State<BorangBListScreen> createState() => _BorangBListScreenState();
}

class _BorangBListScreenState extends State<BorangBListScreen> {
  final BorangBStorageService _storageService = BorangBStorageService.instance;
  List<BorangBData> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    if (userId.isNotEmpty) {
      final reports = await _storageService.getAllReports();
      setState(() {
        _reports = reports.where((r) => r.userId == userId).toList()
          ..sort((a, b) => b.month.compareTo(a.month)); // Most recent first
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _deleteReport(BorangBData report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete the report for ${DateFormat('MMMM yyyy').format(report.month)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _storageService.deleteReport(report.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted successfully')),
        );
        _loadReports();
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

  void _editReport(BorangBData report) {
    Navigator.pushNamed(
      context,
      '/borang-b',
      arguments: report.month,
    ).then((_) => _loadReports());
  }

  void _createNewReport() async {
    // Show month selection bottom sheet first
    final selectedMonth = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => _buildMonthSelector(),
    );

    if (selectedMonth == null) return;

    // Then show the data input bottom sheet with selected month
    if (!mounted) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BorangBBottomSheet(initialMonth: selectedMonth),
    );

    if (result == true) {
      _loadReports();
    }
  }

  Widget _buildMonthSelector() {
    DateTime selectedMonth = DateTime.now();

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              const Text(
                'Select Month to Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Month Display with Navigation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          selectedMonth = DateTime(
                            selectedMonth.year,
                            selectedMonth.month - 1,
                          );
                        });
                      },
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          selectedMonth = DateTime(
                            selectedMonth.year,
                            selectedMonth.month + 1,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, selectedMonth),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm & Continue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showBackupOptions() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use backup features')),
      );
      return;
    }

    // Get backup status
    final status = await BorangBBackupService.instance.getBackupStatus(userId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(Icons.storage, color: AppColors.primaryLight, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Backup & Restore',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📱 Local Reports: ${status['localCount']}'),
                  Text('☁️ Cloud Reports: ${status['cloudCount']}'),
                  if (status['lastBackup'] != null)
                    Text(
                      '🕒 Last Backup: ${DateFormat('dd/MM/yyyy HH:mm').format(status['lastBackup'])}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Cloud Backup Section
            const Text(
              'Cloud Backup (Firestore):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _backupToCloud(userId);
                    },
                    icon: const Icon(Icons.cloud_upload, size: 18),
                    label: const Text('Backup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _restoreFromCloud(userId);
                    },
                    icon: const Icon(Icons.cloud_download, size: 18),
                    label: const Text('Restore'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _syncWithCloud(userId);
                    },
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // File Export/Import Section
            const Text(
              'File Export/Import:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _exportToFile(userId);
                    },
                    icon: const Icon(Icons.file_upload, size: 18),
                    label: const Text('Export to File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _importFromFile();
                    },
                    icon: const Icon(Icons.file_download, size: 18),
                    label: const Text('Import from File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _backupToCloud(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Backing up to cloud...')),
    );

    final success = await BorangBBackupService.instance.backupToCloud(userId);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Successfully backed up to cloud'
            : 'Failed to backup to cloud'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _restoreFromCloud(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Restoring from cloud...')),
    );

    final success = await BorangBBackupService.instance.restoreFromCloud(userId);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Successfully restored from cloud'
            : 'No new reports to restore'),
        backgroundColor: success ? Colors.green : Colors.orange,
      ),
    );

    if (success) {
      _loadReports();
    }
  }

  Future<void> _syncWithCloud(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Syncing with cloud...')),
    );

    final success = await BorangBBackupService.instance.syncWithCloud(userId);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Successfully synced with cloud'
            : 'Failed to sync with cloud'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _loadReports();
    }
  }

  Future<void> _exportToFile(String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Exporting to file...')),
    );

    final success = await BorangBBackupService.instance.exportToFile(userId);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Successfully exported reports'
            : 'Failed to export reports'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _importFromFile() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Importing from file...')),
    );

    final success = await BorangBBackupService.instance.importFromFile();

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Successfully imported reports'
            : 'Failed to import reports'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Reports'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud),
            onPressed: _showBackupOptions,
            tooltip: 'Backup & Restore',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    children: [
                      // Statistics Summary
                      _buildStatisticsSummary(),
                      const SizedBox(height: 16),

                      // Report List
                      ..._reports.map((report) => _buildReportCard(report)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewReport,
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    if (_reports.isEmpty) return const SizedBox.shrink();

    // Calculate totals
    final totalBaptisms = _reports.fold<int>(0, (sum, r) => sum + r.baptisms);
    final totalMembers = _reports.isNotEmpty ? _reports.first.membersEnd : 0;
    final totalVisitations = _reports.fold<int>(0, (sum, r) => sum + r.totalVisitations);
    final totalFinancial = _reports.fold<double>(0, (sum, r) => sum + r.totalFinancial);
    final totalLiterature = _reports.fold<int>(0, (sum, r) => sum + r.totalLiterature);

    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryLight,
              AppColors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Overall Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_reports.length} Reports',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white30, height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryStat(
                    Icons.people,
                    'Current Members',
                    totalMembers.toString(),
                  ),
                ),
                Expanded(
                  child: _buildSummaryStat(
                    Icons.water_drop,
                    'Total Baptisms',
                    totalBaptisms.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryStat(
                    Icons.home,
                    'Total Visits',
                    totalVisitations.toString(),
                  ),
                ),
                Expanded(
                  child: _buildSummaryStat(
                    Icons.book,
                    'Literature Dist.',
                    totalLiterature.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Total:',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'RM ${totalFinancial.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Reports Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first monthly report',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewReport,
            icon: const Icon(Icons.add),
            label: const Text('Create Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BorangBData report) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _viewReport(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: AppColors.primaryLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(report.month),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Created ${DateFormat('dd/MM/yyyy').format(report.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          _viewReport(report);
                          break;
                        case 'edit':
                          _editReport(report);
                          break;
                        case 'delete':
                          _deleteReport(report);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 20),
                            SizedBox(width: 8),
                            Text('View'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Summary Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.people,
                      'Members',
                      report.membersEnd.toString(),
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.water_drop,
                      'Baptisms',
                      report.baptisms.toString(),
                      Colors.cyan,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.home,
                      'Visits',
                      report.totalVisitations.toString(),
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Financial Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withAlpha(50)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money, color: Colors.teal, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Total:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'RM ${report.totalFinancial.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _viewReport(report),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editReport(report),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
