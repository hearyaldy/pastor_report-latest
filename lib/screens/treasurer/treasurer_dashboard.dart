import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/screens/treasurer/financial_report_form.dart';
import 'package:pastor_report/screens/treasurer/export_report_screen.dart';
import 'package:pastor_report/utils/app_colors.dart';

class TreasurerDashboard extends StatefulWidget {
  const TreasurerDashboard({super.key});

  @override
  State<TreasurerDashboard> createState() => _TreasurerDashboardState();
}

class _TreasurerDashboardState extends State<TreasurerDashboard>
    with TickerProviderStateMixin {
  final FinancialReportService _reportService = FinancialReportService();
  final ChurchService _churchService = ChurchService();

  Church? _userChurch;
  List<FinancialReport> _reports = [];
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = true;

  // Floating Action Menu variables
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null || user.userRole != UserRole.churchTreasurer) {
        throw Exception('Only Church Treasurers can access this dashboard');
      }

      // Check if user has assigned church
      if (user.churchId == null || user.churchId!.isEmpty) {
        setState(() {
          _isLoading = false;
          _userChurch = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No church assigned to your account. Please contact your administrator.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get the assigned church
      final church = await _churchService.getChurchById(user.churchId!);

      if (church == null) {
        setState(() {
          _isLoading = false;
          _userChurch = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Church not found. Please contact your administrator.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _userChurch = church;

      // Load financial reports for this church
      final reports = await _reportService.getReportsByChurch(
        _userChurch!.id,
        districtId: _userChurch!.districtId,
      );

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadData();
  }

  // Get report for the selected month
  FinancialReport? get currentMonthReport {
    if (_reports.isEmpty) return null;

    try {
      return _reports.firstWhere(
        (report) =>
            report.month.year == _selectedMonth.year &&
            report.month.month == _selectedMonth.month,
      );
    } catch (e) {
      return null;
    }
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
        _animationController.reverse();
      });
    }
  }

  Future<void> _createOrEditReport() async {
    _closeMenu(); // Close menu first
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null || _userChurch == null) return;

    // Check if report exists for current month
    final existingReport = currentMonthReport;

    // Create a default report if none exists
    final report = existingReport ??
        FinancialReport(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          churchId: _userChurch!.id,
          districtId: _userChurch!.districtId,
          regionId: _userChurch!.regionId,
          missionId: _userChurch!.missionId,
          month: _selectedMonth,
          year: _selectedMonth.year,
          tithe: 0,
          offerings: 0,
          specialOfferings: 0,
          submittedBy: user.uid,
          submittedAt: DateTime.now(),
          createdAt: DateTime.now(),
          status: 'draft',
        );

    // Navigate to form screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialReportForm(
          report: report,
          church: _userChurch!,
          isNewReport: existingReport == null,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _exportReport() {
    _closeMenu(); // Close menu first
    if (_userChurch == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExportReportScreen(
          church: _userChurch!,
          selectedMonth: _selectedMonth,
        ),
      ),
    );
  }

  void _quickViewSummary() {
    _closeMenu(); // Close menu first
    // Show a quick summary dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.summarize, color: AppColors.primaryLight),
            const SizedBox(width: 12),
            const Text('Quick Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (currentMonthReport != null) ...[
              Text('Status: ${currentMonthReport!.status.toUpperCase()}'),
              Text(
                  'Total: RM ${currentMonthReport!.totalFinancial.toStringAsFixed(2)}'),
              Text('Tithe: RM ${currentMonthReport!.tithe.toStringAsFixed(2)}'),
              Text(
                  'Offerings: RM ${currentMonthReport!.offerings.toStringAsFixed(2)}'),
              Text(
                  'Special: RM ${currentMonthReport!.specialOfferings.toStringAsFixed(2)}'),
            ] else ...[
              const Text('Status: No report submitted'),
              const Text('Total: RM 0.00'),
            ],
            const SizedBox(height: 16),
            Text('Total Reports: ${_reports.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                _buildMonthSelector(),
                _buildFinancialSummary(),
                _buildReportsList(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          // Invisible barrier to close menu when tapped outside
          if (_isMenuOpen)
            GestureDetector(
              onTap: _closeMenu,
              child: Container(
                color: Colors.transparent,
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionMenu(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryLight,
                AppColors.primaryLight.withValues(alpha: 0.9),
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Church Treasurer',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_isLoading)
                              const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white70),
                                ),
                              )
                            else
                              Text(
                                _userChurch?.churchName ?? 'No church assigned',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download),
          tooltip: 'Export Reports',
          onPressed: _exportReport,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currentMonthReport == null
                          ? 'No report submitted'
                          : 'Report submitted',
                      style: TextStyle(
                        fontSize: 13,
                        color: currentMonthReport == null
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    final report = currentMonthReport;

    // Values to display
    final double tithe = report?.tithe ?? 0;
    final double offerings = report?.offerings ?? 0;
    final double special = report?.specialOfferings ?? 0;
    final double total = tithe + offerings + special;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Grand Total Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        report == null ? 'No Report Data' : 'Total Collection',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'RM ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  if (report != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM yyyy').format(report.month),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                  if (report != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(report.status),
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              report.status.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Breakdown Cards
            Row(
              children: [
                Expanded(
                  child: _buildBreakdownCard(
                    'Tithe',
                    tithe,
                    Icons.account_balance,
                    Colors.blue,
                    total > 0 ? (tithe / total * 100) : 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBreakdownCard(
                    'Offerings',
                    offerings,
                    Icons.volunteer_activism,
                    Colors.green,
                    total > 0 ? (offerings / total * 100) : 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBreakdownCard(
                    'Special',
                    special,
                    Icons.card_giftcard,
                    Colors.orange,
                    total > 0 ? (special / total * 100) : 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBreakdownCard(String title, double amount, IconData icon,
      Color color, double percentage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon with circular background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          // Amount
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          // Percentage text
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reports.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assessment_outlined,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No reports found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first financial report by tapping the + button',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final report = _reports[index];
            return _buildReportCard(report);
          },
          childCount: _reports.length,
        ),
      ),
    );
  }

  Widget _buildReportCard(FinancialReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main card content
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              onTap: () => _editReport(report),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon based on status
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(report.status)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _getStatusIcon(report.status),
                          color: _getStatusColor(report.status),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(report.month),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Updated: ${DateFormat('MMM d, yyyy').format(report.updatedAt ?? report.createdAt)}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: _buildMiniStat(
                                    'Tithe', report.tithe, Colors.blue),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: _buildMiniStat(
                                    'Offer', report.offerings, Colors.green),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: _buildMiniStat('Special',
                                    report.specialOfferings, Colors.orange),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'RM ${report.totalFinancial.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(report.status)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            report.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(report.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                      ),
                      onTap: () => _editReport(report),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.primaryLight),
                            const SizedBox(width: 6),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(16),
                      ),
                      onTap: () => _deleteReport(report),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.red.shade400),
                            const SizedBox(width: 6),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          'RM ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Icons.edit_note;
      case 'submitted':
        return Icons.upload_file;
      case 'approved':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  void _editReport(FinancialReport report) {
    if (_userChurch == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialReportForm(
          report: report,
          church: _userChurch!,
          isNewReport: false,
        ),
      ),
    ).then((_) => _loadData()); // Reload data after editing
  }

  Future<void> _deleteReport(FinancialReport report) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Delete Report'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the report for ${DateFormat('MMMM yyyy').format(report.month)}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _reportService.deleteReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                    'Report for ${DateFormat('MMM yyyy').format(report.month)} deleted'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadData(); // Reload the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFloatingActionMenu() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Menu items (shown when menu is open)
        if (_isMenuOpen) ...[
          // Quick Summary button
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FloatingActionButton(
                heroTag: 'summary',
                onPressed: _quickViewSummary,
                backgroundColor: Colors.blue,
                mini: true,
                tooltip: 'Quick Summary',
                child: const Icon(Icons.summarize),
              ),
            ),
          ),
          // Export Report button
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FloatingActionButton(
                heroTag: 'export',
                onPressed: _exportReport,
                backgroundColor: Colors.green,
                mini: true,
                tooltip: 'Export Reports',
                child: const Icon(Icons.file_download),
              ),
            ),
          ),
          // Create/Edit Report button
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FloatingActionButton(
                heroTag: 'report',
                onPressed: _createOrEditReport,
                backgroundColor: Colors.orange,
                mini: true,
                tooltip: 'Create/Edit Report',
                child: const Icon(Icons.edit),
              ),
            ),
          ),
        ],
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleMenu,
          backgroundColor: AppColors.primaryLight,
          tooltip: _isMenuOpen ? 'Close Menu' : 'Open Menu',
          child: AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * 2 * 3.14159,
                child: Icon(_isMenuOpen ? Icons.close : Icons.add),
              );
            },
          ),
        ),
      ],
    );
  }
}
