// lib/screens/ministerial_secretary_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/models/user_model.dart';

class MinisterialSecretaryDashboard extends StatefulWidget {
  const MinisterialSecretaryDashboard({super.key});

  @override
  State<MinisterialSecretaryDashboard> createState() =>
      _MinisterialSecretaryDashboardState();
}

class _MinisterialSecretaryDashboardState
    extends State<MinisterialSecretaryDashboard> {
  final BorangBFirestoreService _firestoreService =
      BorangBFirestoreService.instance;
  final UserManagementService _userService = UserManagementService();

  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  List<BorangBData> _reports = [];
  List<UserModel> _allStaff = [];
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null || user.mission == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load all staff in the mission
      final allUsers = await _userService.getUsers();
      _allStaff = allUsers.where((u) => u.mission == user.mission).toList();

      // Load reports for selected month
      _reports = await _firestoreService.getReportsByMissionAndMonth(
        user.mission!,
        _selectedMonth.year,
        _selectedMonth.month,
      );

      // Calculate statistics
      _statistics = await _firestoreService.getMissionStatsByMonth(
        user.mission!,
        _selectedMonth.year,
        _selectedMonth.month,
      );

      debugPrint(
          '📊 Loaded ${_reports.length} reports for ${DateFormat('MMM yyyy').format(_selectedMonth)}');
      debugPrint('👥 Total staff: ${_allStaff.length}');
    } catch (e) {
      debugPrint('❌ Error loading ministerial data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildViewAllReportsCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.article, color: AppColors.primaryLight),
        title: const Text('View All Borang B Reports'),
        subtitle: const Text('See a complete list of all submissions'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, '/all-borang-b-reports');
        },
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadData();
  }

  Future<void> _exportReports(String format) async {
    if (_reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reports to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final content = format == 'CSV'
          ? _firestoreService.exportToCSV(_reports)
          : _firestoreService.exportToJSON(_reports);

      await Share.share(
        content,
        subject:
            'Borang B Reports - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Exported ${_reports.length} reports as $format'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Check permissions
    if (!authProvider.isAuthenticated || user == null) {
      return Scaffold(
        body: _buildNotAuthorized('Please login to access this page'),
      );
    }

    if (!user.canAccessBorangBReports) {
      return Scaffold(
        body: _buildNotAuthorized(
            'You do not have permission to access Borang B reports'),
      );
    }

    if (user.mission == null) {
      return Scaffold(
        body: _buildNotAuthorized('No mission assigned to your account'),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(user),
            _buildMonthSelector(),
            SliverToBoxAdapter(child: _buildViewAllReportsCard()),
            _buildStatisticsSection(),
            _buildSubmissionTracker(),
            _buildReportsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAuthorized(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(UserModel user) {
    final missionName = MissionService().getMissionNameById(user.mission);

    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryLight,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Borang B Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    missionName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 20,
              child: Icon(
                Icons.assessment,
                size: 150,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.file_download, color: Colors.white),
          onSelected: _exportReports,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'CSV',
              child: Row(
                children: [
                  Icon(Icons.table_chart),
                  SizedBox(width: 12),
                  Text('Export as CSV'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'JSON',
              child: Row(
                children: [
                  Icon(Icons.code),
                  SizedBox(width: 12),
                  Text('Export as JSON'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filled(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => _changeMonth(-1),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                foregroundColor: AppColors.primaryLight,
              ),
            ),
            Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reporting Period',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            IconButton.filled(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => _changeMonth(1),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.1),
                foregroundColor: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final totalBaptisms = _statistics['totalBaptisms'] ?? 0;
    final totalProfessions = _statistics['totalProfessions'] ?? 0;
    final totalVisitations = _statistics['totalVisitations'] ?? 0;
    final totalLiterature = _statistics['totalLiterature'] ?? 0;
    final totalTithe = _statistics['totalTithe'] ?? 0.0;
    final totalOfferings = _statistics['totalOfferings'] ?? 0.0;
    final netMembershipChange = _statistics['netMembershipChange'] ?? 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                const Text(
                  'Mission Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 1: Baptisms and Professions
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Baptisms',
                    totalBaptisms.toString(),
                    Icons.water_drop,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Professions',
                    totalProfessions.toString(),
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Visitations and Literature
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Visitations',
                    totalVisitations.toString(),
                    Icons.home_work,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Literature',
                    totalLiterature.toString(),
                    Icons.menu_book,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 3: Financials
            Row(
              children: [
                Expanded(
                  child: _buildFinancialCard(
                    'Tithe',
                    totalTithe,
                    Icons.volunteer_activism,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFinancialCard(
                    'Offerings',
                    totalOfferings,
                    Icons.card_giftcard,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Membership change
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: netMembershipChange >= 0
                      ? [Colors.green, Colors.green.shade700]
                      : [Colors.red, Colors.red.shade700],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:
                        (netMembershipChange >= 0 ? Colors.green : Colors.red)
                            .withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        netMembershipChange >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Net Membership Change',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${netMembershipChange >= 0 ? '+' : ''}$netMembershipChange',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
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

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(
      String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'RM ${NumberFormat('#,##0.00').format(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTracker() {
    final submittedUserIds = _reports.map((r) => r.userId).toSet();
    final totalStaff = _allStaff.length;
    final submitted = submittedUserIds.length;
    final pending = totalStaff - submitted;
    final submissionRate =
        totalStaff > 0 ? (submitted / totalStaff * 100).toInt() : 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.task_alt, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                const Text(
                  'Submission Tracker',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSubmissionCount(
                          'Submitted', submitted, Colors.green),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      _buildSubmissionCount('Pending', pending, Colors.orange),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      _buildSubmissionCount(
                          'Total Staff', totalStaff, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalStaff > 0 ? submitted / totalStaff : 0,
                      minHeight: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        submissionRate >= 80
                            ? Colors.green
                            : submissionRate >= 50
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$submissionRate% Submission Rate',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // List of staff who haven't submitted
            if (pending > 0) ...[
              Text(
                'Pending Submissions ($pending)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _allStaff
                      .where((s) => !submittedUserIds.contains(s.uid))
                      .length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.orange.shade100),
                  itemBuilder: (context, index) {
                    final pendingStaff = _allStaff
                        .where((s) => !submittedUserIds.contains(s.uid))
                        .toList();
                    final staff = pendingStaff[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Text(
                          staff.displayName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        staff.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(staff.email),
                      trailing: const Icon(Icons.pending_actions,
                          color: Colors.orange),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildReportsList() {
    if (_reports.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No reports submitted for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Text(
                  'Submitted Reports (${_reports.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = _reports[index];
                return _buildReportCard(report);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BorangBData report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Get district and mission names
            final districtName = report.districtId != null
                ? report
                    .districtId // Will be improved in future with district name loading
                : null;
            final missionName = report.missionId != null
                ? (AppConstants.missions.firstWhere(
                    (m) => m['id'] == report.missionId,
                    orElse: () => {'name': report.missionId ?? 'Unknown'},
                  )['name'])
                : null;

            // Navigate to report preview
            Navigator.pushNamed(
              context,
              '/borang-b-preview',
              arguments: {
                'data': report,
                'month': report.month,
                'districtName': districtName,
                'missionName': missionName,
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        report.userName[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Submitted on ${DateFormat('MMM d, yyyy').format(report.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildReportStat('Baptisms', report.baptisms,
                          Icons.water_drop, Colors.blue),
                    ),
                    Expanded(
                      child: _buildReportStat(
                          'Visitations',
                          report.totalVisitations,
                          Icons.home_work,
                          Colors.green),
                    ),
                    Expanded(
                      child: _buildReportStat(
                          'Literature',
                          report.totalLiterature,
                          Icons.menu_book,
                          Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
