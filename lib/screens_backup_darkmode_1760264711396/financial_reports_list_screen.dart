import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/screens/treasurer/financial_report_form.dart';
import 'package:pastor_report/utils/app_colors.dart' as AppColorUtils;

class FinancialReportsListScreen extends StatefulWidget {
  final String? churchId;
  final String? churchName;

  const FinancialReportsListScreen({
    super.key,
    this.churchId,
    this.churchName,
  });

  @override
  State<FinancialReportsListScreen> createState() =>
      _FinancialReportsListScreenState();
}

class _FinancialReportsListScreenState
    extends State<FinancialReportsListScreen> {
  final FinancialReportService _financialService =
      FinancialReportService.instance;
  final ChurchService _churchService = ChurchService.instance;
  final DistrictService _districtService = DistrictService.instance;

  List<FinancialReport> _reports = [];
  List<Church> _churches = [];
  List<District> _districts = [];
  bool _isLoading = true;
  String? _selectedChurchId;
  final DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedChurchId = widget.churchId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) return;

      // Load churches user can manage
      _churches = await _getManageableChurches(user);

      // Load districts for reference
      if (user.isSuperAdmin || user.canManageMissions()) {
        final missionId = user.mission;
        if (missionId != null) {
          _districts = await _districtService.getDistrictsByMission(missionId);
        }
      } else if (user.churchId != null) {
        final userChurch = await _churchService.getChurchById(user.churchId!);
        if (userChurch?.districtId != null) {
          final district =
              await _districtService.getDistrictById(userChurch!.districtId!);
          if (district != null) {
            _districts = [district];
          }
        }
      }

      // Set default church if none selected
      if (_selectedChurchId == null && _churches.isNotEmpty) {
        _selectedChurchId = _churches.first.id;
      }

      // Load reports
      await _loadReports();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Church>> _getManageableChurches(UserModel user) async {
    if (user.isSuperAdmin || user.canManageMissions()) {
      // Load all churches in mission
      final missionId = user.mission;
      if (missionId != null) {
        final districts =
            await _districtService.getDistrictsByMission(missionId);
        List<Church> allChurches = [];
        for (var district in districts) {
          final churches =
              await _churchService.getChurchesByDistrict(district.id);
          allChurches.addAll(churches);
        }
        return allChurches;
      }
    } else if (user.roleTitle != null &&
        (user.roleTitle!.contains('Pastor') ||
            user.roleTitle!.contains('pastor'))) {
      // Pastors can manage churches in their district
      if (user.churchId != null && user.churchId!.isNotEmpty) {
        final userChurch = await _churchService.getChurchById(user.churchId!);
        if (userChurch != null && userChurch.districtId != null) {
          return await _churchService
              .getChurchesByDistrict(userChurch.districtId!);
        }
      }
    }
    return [];
  }

  Future<void> _loadReports() async {
    if (_selectedChurchId == null) {
      setState(() => _reports = []);
      return;
    }

    try {
      final selectedChurch =
          _churches.firstWhere((c) => c.id == _selectedChurchId);
      final reports = await _financialService.getReportsByChurch(
        _selectedChurchId!,
        districtId: selectedChurch.districtId,
      );
      setState(() => _reports = reports);
    } catch (e) {
      debugPrint('Error loading reports: $e');
      setState(() => _reports = []);
    }
  }

  String _getDistrictName(String? districtId) {
    if (districtId == null) return 'Unknown District';
    final district = _districts.firstWhere(
      (d) => d.id == districtId,
      orElse: () => District(
        id: '',
        name: 'Unknown District',
        code: '',
        regionId: '',
        missionId: '',
        createdAt: DateTime.now(),
        createdBy: '',
      ),
    );
    return district.name;
  }

  String _getChurchName(String churchId) {
    final church = _churches.firstWhere(
      (c) => c.id == churchId,
      orElse: () => Church(
        id: '',
        userId: '',
        churchName: 'Unknown Church',
        elderName: '',
        status: ChurchStatus.organizedChurch,
        elderEmail: '',
        elderPhone: '',
        districtId: '',
        regionId: '',
        missionId: '',
        createdAt: DateTime.now(),
      ),
    );
    return church.churchName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Financial Reports'),
        backgroundColor: AppColorUtils.AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Church selector
                if (_churches.length > 1)
                  SliverToBoxAdapter(
                    child: _buildChurchSelector(),
                  ),

                // Reports list
                _reports.isEmpty
                    ? SliverFillRemaining(
                        child: _buildEmptyState(),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildReportCard(_reports[index]),
                          childCount: _reports.length,
                        ),
                      ),
              ],
            ),
      floatingActionButton: _selectedChurchId != null
          ? FloatingActionButton(
              heroTag: "financial_reports_list_fab",
              onPressed: _addNewReport,
              backgroundColor: AppColorUtils.AppColors.primaryLight,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildChurchSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedChurchId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Select Church',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.church),
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        items: _churches.map((church) {
          return DropdownMenuItem(
            value: church.id,
            child: Text(
              '${church.churchName} - ${_getDistrictName(church.districtId)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedChurchId = value;
          });
          _loadReports();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Financial Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedChurchId != null
                  ? 'No reports found for ${_getChurchName(_selectedChurchId!)}'
                  : 'Select a church to view reports',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedChurchId != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _addNewReport,
                icon: const Icon(Icons.add),
                label: const Text('Add First Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorUtils.AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(FinancialReport report) {
    final church = _churches.firstWhere(
      (c) => c.id == report.churchId,
      orElse: () => Church(
        id: '',
        userId: '',
        churchName: 'Unknown Church',
        elderName: '',
        status: ChurchStatus.organizedChurch,
        elderEmail: '',
        elderPhone: '',
        districtId: '',
        regionId: '',
        missionId: '',
        createdAt: DateTime.now(),
      ),
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _editReport(report, church),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with church name and status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      church.churchName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip(report.status),
                ],
              ),

              const SizedBox(height: 6),

              // Financial summary
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFinancialItem('Tithe', report.tithe),
                    ),
                    Expanded(
                      child: _buildFinancialItem('Offerings', report.offerings),
                    ),
                    Expanded(
                      child: _buildFinancialItem(
                          'Special', report.specialOfferings),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Total and date
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColorUtils.AppColors.primaryLight
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Total: \$${report.totalFinancial.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColorUtils.AppColors.primaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(report.submittedAt),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
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

  Widget _buildFinancialItem(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'approved':
        backgroundColor = Colors.green;
        textColor = Colors.white;
        break;
      case 'submitted':
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        break;
      case 'draft':
      default:
        backgroundColor = Colors.grey;
        textColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _addNewReport() {
    if (_selectedChurchId == null) return;

    final church = _churches.firstWhere((c) => c.id == _selectedChurchId);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialReportForm(
          report: FinancialReport(
            id: '',
            churchId: church.id,
            districtId: church.districtId,
            regionId: church.regionId,
            missionId: church.missionId,
            month: DateTime(_selectedMonth.year, _selectedMonth.month),
            year: _selectedMonth.year,
            tithe: 0,
            offerings: 0,
            specialOfferings: 0,
            submittedBy: authProvider.user?.uid ?? '',
            submittedAt: DateTime.now(),
            status: 'draft',
            createdAt: DateTime.now(),
          ),
          church: church,
          isNewReport: true,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadReports();
        _showSnackBar('Financial report created successfully');
      }
    });
  }

  void _editReport(FinancialReport report, Church church) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialReportForm(
          report: report,
          church: church,
          isNewReport: false,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadReports();
        _showSnackBar('Financial report updated successfully');
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : AppColorUtils.AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
