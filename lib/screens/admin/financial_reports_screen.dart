import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pastor_report/screens/financial_report_edit_screen.dart';
import 'package:pastor_report/utils/app_colors.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final FinancialReportService _reportService = FinancialReportService();
  final ChurchService _churchService = ChurchService();
  final DistrictService _districtService = DistrictService();
  final RegionService _regionService = RegionService();

  List<FinancialReport> _reports = [];
  List<Church> _churches = [];
  List<District> _districts = [];
  List<Region> _regions = [];

  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _selectedRegionId;
  String? _selectedDistrictId;
  String? _selectedChurchId;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _regions = await _regionService.getAllRegions();
      _districts = await _districtService.getAllDistricts();
      _churches = await _churchService.getAllChurches();

      // Load reports based on filters
      if (_selectedChurchId != null) {
        final report = await _reportService.getReportByChurchAndMonth(
            _selectedChurchId!, _selectedMonth);
        _reports = report != null ? [report] : [];
      } else if (_selectedDistrictId != null) {
        _reports =
            await _reportService.getReportsByDistrict(_selectedDistrictId!);
        _reports = _reports.where((r) {
          return r.month.year == _selectedMonth.year &&
              r.month.month == _selectedMonth.month;
        }).toList();
      } else {
        // Get all churches and their reports for the selected month
        _reports = [];
        for (var church in _churches) {
          final report = await _reportService.getReportByChurchAndMonth(
              church.id, _selectedMonth);
          if (report != null) {
            _reports.add(report);
          }
        }
      }

      _reports.sort((a, b) => b.totalFinancial.compareTo(a.totalFinancial));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getChurchName(String? churchId) {
    if (churchId == null) return 'Unknown';
    final church = _churches.firstWhere(
      (c) => c.id == churchId,
      orElse: () => Church(
        id: '',
        userId: '',
        churchName: 'Unknown',
        elderName: '',
        status: ChurchStatus.church,
        elderEmail: '',
        elderPhone: '',
        createdAt: DateTime.now(),
      ),
    );
    return church.churchName;
  }

  String _getDistrictName(String? districtId) {
    if (districtId == null) return 'N/A';
    final district = _districts.firstWhere(
      (d) => d.id == districtId,
      orElse: () => District(
        id: '',
        name: 'Unknown',
        code: '',
        regionId: '',
        missionId: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    return district.name;
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadData();
  }

  // Check if user has permission to access financial reports
  bool _hasAccess(UserModel? user) {
    if (user == null) return false;

    return user.canManageMissions() ||
        user.userRole == UserRole.churchTreasurer;
  }

  // Check if user can edit or delete reports
  bool _canEditReport(UserModel? user, FinancialReport report) {
    if (user == null) return false;

    // Admins and super admins can edit any report
    if (user.userRole == UserRole.admin ||
        user.userRole == UserRole.superAdmin) {
      return true;
    }

    // For now, allow churchTreasurer to edit reports if they can access financial reports
    // In a real implementation, you would check if the churchId matches
    if (user.userRole == UserRole.churchTreasurer &&
        user.canAccessFinancialReports) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Check access permission
    if (!_hasAccess(user)) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 72, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to view financial reports',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final totalTithe = _reports.fold<double>(0, (sum, r) => sum + r.tithe);
    final totalOfferings =
        _reports.fold<double>(0, (sum, r) => sum + r.offerings);
    final totalSpecial =
        _reports.fold<double>(0, (sum, r) => sum + r.specialOfferings);
    final grandTotal = totalTithe + totalOfferings + totalSpecial;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            _buildMonthSelector(),
            _buildFilters(),
            _buildFinancialSummary(
                totalTithe, totalOfferings, totalSpecial, grandTotal),
            _buildReportsList(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
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
                        child: const Icon(Icons.assessment,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Financial Reports',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Tithe & offerings analytics',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Export button
                      IconButton(
                        icon: const Icon(
                          Icons.file_download,
                          color: Colors.white,
                        ),
                        onPressed:
                            _isExporting ? null : _showExportConfirmation,
                        tooltip: 'Export Reports',
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
                      '${_reports.length} reports',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
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

  Widget _buildFilters() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Region',
                    _selectedRegionId,
                    [
                      const DropdownMenuItem(
                          value: null, child: Text('All Regions')),
                      ..._regions.map((r) => DropdownMenuItem(
                            value: r.id,
                            child:
                                Text(r.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    (value) {
                      setState(() {
                        _selectedRegionId = value;
                        _selectedDistrictId = null;
                        _selectedChurchId = null;
                      });
                      _loadData();
                    },
                    Icons.map,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDropdown(
                    'District',
                    _selectedDistrictId,
                    [
                      const DropdownMenuItem(
                          value: null, child: Text('All Districts')),
                      ..._districts
                          .where((d) =>
                              _selectedRegionId == null ||
                              d.regionId == _selectedRegionId)
                          .map((d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(d.name,
                                    overflow: TextOverflow.ellipsis),
                              )),
                    ],
                    (value) {
                      setState(() {
                        _selectedDistrictId = value;
                        _selectedChurchId = null;
                      });
                      _loadData();
                    },
                    Icons.location_city,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFilterDropdown(
              'Church',
              _selectedChurchId,
              [
                const DropdownMenuItem(
                    value: null, child: Text('All Churches')),
                ..._churches
                    .where((c) =>
                        (_selectedDistrictId == null ||
                            c.districtId == _selectedDistrictId) &&
                        (_selectedRegionId == null ||
                            c.regionId == _selectedRegionId))
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.churchName,
                              overflow: TextOverflow.ellipsis),
                        )),
              ],
              (value) {
                setState(() => _selectedChurchId = value);
                _loadData();
              },
              Icons.church,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String?>> items,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: AppColors.primaryLight),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildFinancialSummary(
      double tithe, double offerings, double special, double total) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Grand Total Card
            Container(
              padding: const EdgeInsets.all(20),
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
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Collection',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            'RM ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
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
              Text(
                'No financial reports for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                style: TextStyle(color: Colors.grey[500]),
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
            return _buildReportCard(report, index + 1);
          },
          childCount: _reports.length,
        ),
      ),
    );
  }

  Widget _buildReportCard(FinancialReport report, int rank) {
    final churchName = _getChurchName(report.churchId);
    final districtName = _getDistrictName(report.districtId);

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showReportDetails(report),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? (rank == 1
                            ? Colors.amber
                            : rank == 2
                                ? Colors.grey[400]
                                : Colors.brown[300])
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        churchName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_city,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            districtName,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                              child: _buildMiniStat(
                                  'Tithe', report.tithe, Colors.blue)),
                          const SizedBox(width: 4),
                          Flexible(
                              child: _buildMiniStat(
                                  'Offerings', report.offerings, Colors.green)),
                          const SizedBox(width: 4),
                          Flexible(
                              child: _buildMiniStat('Special',
                                  report.specialOfferings, Colors.orange)),
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
                        borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey[600],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          'RM ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'submitted':
        return Colors.blue;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Export report to Excel
  Future<void> _exportToExcel(FinancialReport report) async {
    try {
      final churchName = _getChurchName(report.churchId);

      // In a real implementation, you would create Excel file here
      // using the Excel package with proper type handling

      // For now, show a sample implementation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Excel export feature will be implemented with proper Excel package')),
        );

        // To simulate sharing
        await Share.share(
          'Financial Report for $churchName - ${DateFormat('MMMM yyyy').format(report.month)}\n'
          'Tithe: RM ${report.tithe.toStringAsFixed(2)}\n'
          'Offerings: RM ${report.offerings.toStringAsFixed(2)}\n'
          'Special: RM ${report.specialOfferings.toStringAsFixed(2)}\n'
          'Total: RM ${report.totalFinancial.toStringAsFixed(2)}',
          subject: 'Financial Report - $churchName (Excel)',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting Excel: $e')),
        );
      }
    }
  }

  // Export report to PDF
  Future<void> _exportToPDF(FinancialReport report) async {
    try {
      final churchName = _getChurchName(report.churchId);

      // In a real implementation, you would create PDF file here
      // using the pdf package with proper implementation

      // For now, show a sample implementation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'PDF export feature will be implemented with proper PDF package')),
        );

        // To simulate sharing
        await Share.share(
          'Financial Report for $churchName - ${DateFormat('MMMM yyyy').format(report.month)}\n'
          'Tithe: RM ${report.tithe.toStringAsFixed(2)}\n'
          'Offerings: RM ${report.offerings.toStringAsFixed(2)}\n'
          'Special: RM ${report.specialOfferings.toStringAsFixed(2)}\n'
          'Total: RM ${report.totalFinancial.toStringAsFixed(2)}',
          subject: 'Financial Report - $churchName (PDF)',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting PDF: $e')),
        );
      }
    }
  }

  // Delete report
  Future<void> _deleteReport(FinancialReport report) async {
    try {
      // Call the service method to delete the report
      await FinancialReportService().deleteReport(report.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted successfully')),
        );
        _loadData(); // Reload data from server
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting report: $e')),
        );
      }
    }
  }

  void _showReportDetails(FinancialReport report) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final canEdit = _canEditReport(user, report);
    final church = _churches.firstWhere(
      (c) => c.id == report.churchId,
      orElse: () => Church(
        id: '',
        userId: '',
        churchName: 'Unknown',
        elderName: '',
        status: ChurchStatus.church,
        elderEmail: '',
        elderPhone: '',
        createdAt: DateTime.now(),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: Navigator.of(context),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85, // Increase height
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assessment,
                      color: AppColors.primaryLight,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getChurchName(report.churchId),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(report.month),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Action buttons row
            if (canEdit) // Only show if user can edit
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Edit button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context); // Close bottom sheet
                          // Small delay to ensure smooth transition
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FinancialReportEditScreen(
                                  report: report,
                                  church: church,
                                  onUpdate: _loadData,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Delete button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(report);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // Share button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Share button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final churchName = _getChurchName(report.churchId);
                        final month =
                            DateFormat('MMMM yyyy').format(report.month);
                        final total = report.totalFinancial.toStringAsFixed(2);

                        Share.share(
                          'Financial Report for $churchName - $month\n'
                          '------------------------------------\n'
                          'Tithe: RM ${report.tithe.toStringAsFixed(2)}\n'
                          'Offerings: RM ${report.offerings.toStringAsFixed(2)}\n'
                          'Special: RM ${report.specialOfferings.toStringAsFixed(2)}\n'
                          'Total: RM $total',
                          subject: 'Financial Report - $churchName ($month)',
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDetailRow(
                      'Church', _getChurchName(report.churchId), Icons.church),
                  _buildDetailRow('District',
                      _getDistrictName(report.districtId), Icons.location_city),
                  _buildDetailRow(
                      'Month',
                      DateFormat('MMMM yyyy').format(report.month),
                      Icons.calendar_today),
                  _buildDetailRow(
                      'Status', report.status.toUpperCase(), Icons.info),
                  const Divider(height: 32),
                  _buildDetailRow(
                      'Tithe',
                      'RM ${report.tithe.toStringAsFixed(2)}',
                      Icons.account_balance),
                  _buildDetailRow(
                      'Offerings',
                      'RM ${report.offerings.toStringAsFixed(2)}',
                      Icons.volunteer_activism),
                  _buildDetailRow(
                      'Special Offerings',
                      'RM ${report.specialOfferings.toStringAsFixed(2)}',
                      Icons.card_giftcard),
                  const Divider(height: 32),
                  _buildDetailRow(
                      'Total',
                      'RM ${report.totalFinancial.toStringAsFixed(2)}',
                      Icons.calculate,
                      isTotal: true),
                  if (report.notes != null && report.notes!.isNotEmpty) ...[
                    const Divider(height: 32),
                    _buildDetailRow('Notes', report.notes!, Icons.note_alt),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show confirmation dialog before deleting a report
  void _showDeleteConfirmation(FinancialReport report) {
    final churchName = _getChurchName(report.churchId);
    final month = DateFormat('MMMM yyyy').format(report.month);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete the financial report for $churchName - $month?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReport(report);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isTotal
                  ? AppColors.primaryLight.withValues(alpha: 0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isTotal ? AppColors.primaryLight : AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isTotal ? 18 : 15,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                    color: isTotal ? AppColors.primaryLight : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAllToExcel() async {
    try {
      // Show loading indicator
      setState(() => _isExporting = true);

      String scope = 'All';
      String fileName;

      // Filter name based on selection
      if (_selectedChurchId != null) {
        final church = _churches.firstWhere((c) => c.id == _selectedChurchId);
        scope = church.churchName;
      } else if (_selectedDistrictId != null) {
        final district =
            _districts.firstWhere((d) => d.id == _selectedDistrictId);
        scope = district.name;
      } else if (_selectedRegionId != null) {
        final region = _regions.firstWhere((r) => r.id == _selectedRegionId);
        scope = region.name;
      }

      // Format file name based on selection and month
      final monthStr = DateFormat('MMM_yyyy').format(_selectedMonth);
      fileName = '${scope}_Financial_Reports_$monthStr.xlsx';

      // Generate Excel file
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Financial Reports'];

      // Add headers
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = TextCellValue('Church');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
          .value = TextCellValue('Month');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
          .value = TextCellValue('Tithe');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
          .value = TextCellValue('Offerings');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0))
          .value = TextCellValue('Special Offerings');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0))
          .value = TextCellValue('Total');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0))
          .value = TextCellValue('Status');
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0))
          .value = TextCellValue('Notes');

      // Add data rows
      for (var i = 0; i < _reports.length; i++) {
        final report = _reports[i];
        final church = _churches.firstWhere((c) => c.id == report.churchId);

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
            .value = TextCellValue(church.churchName);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
            .value = TextCellValue(DateFormat('MMM yyyy').format(report.month));
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
            .value = DoubleCellValue(report.tithe);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
            .value = DoubleCellValue(report.offerings);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1))
            .value = DoubleCellValue(report.specialOfferings);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1))
            .value = DoubleCellValue(report.totalFinancial);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1))
            .value = TextCellValue(report.status);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i + 1))
            .value = TextCellValue(report.notes ?? '');
      }

      // Auto-fit columns
      final List<double> columnWidths = [
        20.0,
        15.0,
        12.0,
        12.0,
        12.0,
        12.0,
        12.0,
        30.0
      ];
      for (var i = 0; i < columnWidths.length; i++) {
        sheet.setColumnWidth(i, columnWidths[i]);
      }

      // Get directory for saving file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Save the Excel file
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);

        // Show bottom sheet with sharing options
        if (mounted) {
          _showExportCompleteOptions(filePath, fileName);
        }
      } else {
        throw Exception('Failed to generate Excel file');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to Excel: $e'),
            behavior: SnackBarBehavior.floating,
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

  Future<void> _exportAllToPDF() async {
    try {
      // Show loading indicator
      setState(() => _isExporting = true);

      String scope = 'All';
      String fileName;

      // Filter name based on selection
      if (_selectedChurchId != null) {
        final church = _churches.firstWhere((c) => c.id == _selectedChurchId);
        scope = church.churchName;
      } else if (_selectedDistrictId != null) {
        final district =
            _districts.firstWhere((d) => d.id == _selectedDistrictId);
        scope = district.name;
      } else if (_selectedRegionId != null) {
        final region = _regions.firstWhere((r) => r.id == _selectedRegionId);
        scope = region.name;
      }

      // Format file name based on selection and month
      final monthStr = DateFormat('MMM_yyyy').format(_selectedMonth);
      fileName = '${scope}_Financial_Reports_$monthStr.pdf';

      // Create PDF document
      final pdf = pw.Document();

      // Add page with financial report data
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Financial Reports',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Scope: $scope',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  'Period: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 12),
              ),
            );
          },
          build: (pw.Context context) {
            // Table header
            final headers = [
              'Church',
              'Month',
              'Tithe',
              'Offerings',
              'Special\nOfferings',
              'Total',
              'Status'
            ];

            // Table data
            final data = _reports.map((report) {
              final church =
                  _churches.firstWhere((c) => c.id == report.churchId);
              return [
                church.churchName,
                DateFormat('MMM yyyy').format(report.month),
                'RM ${report.tithe.toStringAsFixed(2)}',
                'RM ${report.offerings.toStringAsFixed(2)}',
                'RM ${report.specialOfferings.toStringAsFixed(2)}',
                'RM ${report.totalFinancial.toStringAsFixed(2)}',
                report.status,
              ];
            }).toList();

            // Create table with header and data rows
            return [
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.center,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Notes:',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
              pw.SizedBox(height: 10),
              // Add notes section for each report
              ...List<pw.Widget>.generate(_reports.length, (index) {
                final report = _reports[index];
                final church =
                    _churches.firstWhere((c) => c.id == report.churchId);

                if (report.notes != null && report.notes!.isNotEmpty) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(5)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${church.churchName} (${DateFormat('MMM yyyy').format(report.month)}):',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(report.notes ?? ''),
                      ],
                    ),
                  );
                } else {
                  return pw.SizedBox(); // Empty container if no notes
                }
              }),
            ];
          },
        ),
      );

      // Get directory for saving file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Save the PDF file
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Show bottom sheet with sharing options
      if (mounted) {
        _showExportCompleteOptions(filePath, fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting to PDF: $e'),
            behavior: SnackBarBehavior.floating,
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

  Future<void> _showExportConfirmation() async {
    String scope = 'all churches';

    if (_selectedChurchId != null) {
      final church = _churches.firstWhere((c) => c.id == _selectedChurchId);
      scope = church.churchName;
    } else if (_selectedDistrictId != null) {
      final district =
          _districts.firstWhere((d) => d.id == _selectedDistrictId);
      scope = '${district.name} district';
    } else if (_selectedRegionId != null) {
      final region = _regions.firstWhere((r) => r.id == _selectedRegionId);
      scope = '${region.name} region';
    }

    final month = DateFormat('MMMM yyyy').format(_selectedMonth);

    final exportType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.file_download,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export Reports',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose export format',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Export details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scope: $scope'),
                  const SizedBox(height: 5),
                  Text('Period: $month'),
                  const SizedBox(height: 5),
                  Text('Total reports: ${_reports.length}'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Export options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_chart),
                    label: const Text('EXCEL'),
                    onPressed: () => Navigator.pop(context, 'excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('PDF'),
                    onPressed: () => Navigator.pop(context, 'pdf'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
            ),
          ],
        ),
      ),
    );

    if (exportType == 'excel') {
      _exportAllToExcel();
    } else if (exportType == 'pdf') {
      _exportAllToPDF();
    }
  }

  void _showExportCompleteOptions(String filePath, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with success icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export Complete',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'File saved as $fileName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // File location info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File Location:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    filePath,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share option
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('SHARE FILE'),
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(filePath)],
                      subject: 'Financial Report',
                      text: 'Sharing financial report: $fileName');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
