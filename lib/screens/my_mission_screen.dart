import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/utils/constants.dart';

enum ViewLevel { mission, district, church }

class MyMissionScreen extends StatefulWidget {
  const MyMissionScreen({super.key});

  @override
  State<MyMissionScreen> createState() => _MyMissionScreenState();
}

class _MyMissionScreenState extends State<MyMissionScreen> {
  final FinancialReportService _financialService =
      FinancialReportService.instance;
  final DistrictService _districtService = DistrictService.instance;
  final ChurchService _churchService = ChurchService.instance;
  final StaffService _staffService = StaffService.instance;

  bool _isLoading = true;
  Map<String, double> _financialData = {};
  int _totalDistricts = 0;
  int _totalChurches = 0;
  int _totalStaff = 0;
  int _totalMembers = 0;
  int _churchesWithReports = 0;
  DateTime _selectedMonth = DateTime.now();

  // View level controls
  ViewLevel _viewLevel = ViewLevel.mission;
  List<District> _allDistricts = [];
  List<Church> _allChurches = [];
  String? _selectedDistrictId;
  String? _selectedChurchId;

  @override
  void initState() {
    super.initState();
    _loadMissionData();
  }

  Future<void> _loadMissionData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null && user.mission != null) {
        debugPrint(
            '📊 Loading data for mission: ${user.mission}, View: $_viewLevel');

        // Load all districts and churches for filtering
        _allDistricts =
            await _districtService.getDistrictsByMission(user.mission!);
        _allChurches = [];
        for (var district in _allDistricts) {
          final churches =
              await _churchService.getChurchesByDistrict(district.id);
          _allChurches.addAll(churches);
        }

        // Load data based on view level
        switch (_viewLevel) {
          case ViewLevel.mission:
            await _loadMissionLevelData(user.mission!);
            break;
          case ViewLevel.district:
            await _loadDistrictLevelData();
            break;
          case ViewLevel.church:
            await _loadChurchLevelData();
            break;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading mission data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMissionLevelData(String missionId) async {
    debugPrint('📊 Loading mission level data');

    _totalDistricts = _allDistricts.length;
    _totalChurches = _allChurches.length;
    _totalMembers =
        _allChurches.fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0));

    // Load staff count
    final staff = await _staffService.getStaffByMission(missionId);
    _totalStaff = staff.length;

    // Count reported churches
    int reportedChurches = 0;
    for (var district in _allDistricts) {
      try {
        final count = await _financialService.countChurchesWithReports(
          district.id,
          _selectedMonth,
        );
        reportedChurches += count;
      } catch (e) {
        debugPrint('⚠️ Could not count reports: $e');
      }
    }
    _churchesWithReports = reportedChurches;

    // Load financial data
    try {
      _financialData = await _financialService.getMissionAggregateByMonth(
        missionId,
        _selectedMonth,
      );
    } catch (e) {
      debugPrint('⚠️ Could not load financial data: $e');
      _financialData = {
        'tithe': 0.0,
        'offerings': 0.0,
        'specialOfferings': 0.0,
        'total': 0.0
      };
    }
  }

  Future<void> _loadDistrictLevelData() async {
    if (_selectedDistrictId == null && _allDistricts.isNotEmpty) {
      _selectedDistrictId = _allDistricts.first.id;
    }

    if (_selectedDistrictId == null) return;

    debugPrint('📊 Loading district level data for: $_selectedDistrictId');

    final churches =
        _allChurches.where((c) => c.districtId == _selectedDistrictId).toList();

    _totalDistricts = 1;
    _totalChurches = churches.length;
    _totalMembers =
        churches.fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0));
    _totalStaff = 0; // Districts don't track individual staff

    // Count reported churches
    try {
      _churchesWithReports = await _financialService.countChurchesWithReports(
        _selectedDistrictId!,
        _selectedMonth,
      );
    } catch (e) {
      _churchesWithReports = 0;
    }

    // Load financial data
    try {
      _financialData = await _financialService.getDistrictAggregateByMonth(
        _selectedDistrictId!,
        _selectedMonth,
      );
    } catch (e) {
      _financialData = {
        'tithe': 0.0,
        'offerings': 0.0,
        'specialOfferings': 0.0,
        'total': 0.0
      };
    }
  }

  Future<void> _loadChurchLevelData() async {
    if (_selectedChurchId == null && _allChurches.isNotEmpty) {
      _selectedChurchId = _allChurches.first.id;
    }

    if (_selectedChurchId == null) return;

    debugPrint('📊 Loading church level data for: $_selectedChurchId');

    final church = _allChurches.firstWhere((c) => c.id == _selectedChurchId);

    _totalDistricts = 0;
    _totalChurches = 1;
    _totalMembers = church.memberCount ?? 0;
    _totalStaff = 0;

    // Check if this church has reported
    final report = await _financialService.getReportByChurchAndMonth(
      _selectedChurchId!,
      _selectedMonth,
    );
    _churchesWithReports = report != null ? 1 : 0;

    // Load financial data
    if (report != null) {
      _financialData = {
        'tithe': report.tithe,
        'offerings': report.offerings,
        'specialOfferings': report.specialOfferings,
        'total': report.totalFinancial,
      };
    } else {
      _financialData = {
        'tithe': 0.0,
        'offerings': 0.0,
        'specialOfferings': 0.0,
        'total': 0.0
      };
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadMissionData();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!authProvider.isAuthenticated) {
      return Scaffold(
        body: _buildLoginPrompt(),
      );
    }

    if (user?.mission == null) {
      return Scaffold(
        body: _buildNoMissionAssigned(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadMissionData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildModernAppBar(user!),
            _buildViewSelector(user),
            _buildMonthSelectorSliver(),
            if (_viewLevel == ViewLevel.district ||
                _viewLevel == ViewLevel.church)
              _buildFilterSelector(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildFinancialSummary(),
                  _buildOrganizationalStats(),
                  _buildReportingStatus(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 80,
              color: AppColors.primaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'Login Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please login to view your mission data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppConstants.routeWelcome);
              },
              icon: const Icon(Icons.login),
              label: const Text('Login Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMissionAssigned() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 80,
              color: AppColors.primaryLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Mission Assigned',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You are not currently assigned to a mission.\nPlease contact your administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primaryLight,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadMissionData,
          tooltip: 'Refresh',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryLight,
                AppColors.primaryLight.withValues(alpha: 0.8),
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.business,
                          size: 36,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mission Overview',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.mission ?? 'Unknown Mission',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          DateFormat('MMMM yyyy').format(_selectedMonth),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildViewSelector(UserModel user) {
    // Determine available views based on user role
    final bool isMissionAdmin =
        user.canManageMissions() || user.canManageDepartments();

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'View Level',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ViewLevel>(
              segments: [
                if (isMissionAdmin)
                  const ButtonSegment<ViewLevel>(
                    value: ViewLevel.mission,
                    label: Text('Mission'),
                    icon: Icon(Icons.business, size: 18),
                  ),
                const ButtonSegment<ViewLevel>(
                  value: ViewLevel.district,
                  label: Text('District'),
                  icon: Icon(Icons.location_city, size: 18),
                ),
                const ButtonSegment<ViewLevel>(
                  value: ViewLevel.church,
                  label: Text('Church'),
                  icon: Icon(Icons.church, size: 18),
                ),
              ],
              selected: {_viewLevel},
              onSelectionChanged: (Set<ViewLevel> selected) {
                setState(() {
                  _viewLevel = selected.first;
                  // Reset selections when changing view
                  if (_viewLevel == ViewLevel.mission) {
                    _selectedDistrictId = null;
                    _selectedChurchId = null;
                  } else if (_viewLevel == ViewLevel.district) {
                    _selectedChurchId = null;
                  }
                });
                _loadMissionData();
              },
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primaryLight;
                  }
                  return Colors.grey[100]!;
                }),
                foregroundColor:
                    WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.grey[700]!;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelector() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_viewLevel == ViewLevel.district) ...[
              Text(
                'Select District',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDistrictId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        prefixIcon: Icon(Icons.location_city,
                            color: AppColors.primaryLight),
                      ),
                      items: _allDistricts.map((district) {
                        return DropdownMenuItem(
                          value: district.id,
                          child: Text(
                            '${district.name} (${district.code})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDistrictId = value;
                        });
                        _loadMissionData();
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (_viewLevel == ViewLevel.church) ...[
              Text(
                'Select Church',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedChurchId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        prefixIcon:
                            Icon(Icons.church, color: AppColors.primaryLight),
                      ),
                      items: _allChurches.map((church) {
                        final district = _allDistricts.firstWhere(
                          (d) => d.id == church.districtId,
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
                        return DropdownMenuItem(
                          value: church.id,
                          child: Text(
                            '${church.churchName} (${district.name})',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChurchId = value;
                        });
                        _loadMissionData();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelectorSliver() {
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

  Widget _buildFinancialSummary() {
    final totalTithe = _financialData['tithe'] ?? 0.0;
    final totalOfferings = _financialData['offerings'] ?? 0.0;
    final totalSpecial = _financialData['specialOfferings'] ?? 0.0;
    final grandTotal = _financialData['total'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              const Text(
                'Financial Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFinancialCard(
                  'Tithe',
                  totalTithe,
                  Icons.volunteer_activism,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialCard(
                  'Offerings',
                  totalOfferings,
                  Icons.card_giftcard,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFinancialCard(
                  'Special',
                  totalSpecial,
                  Icons.stars,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFinancialCard(
                  'Total',
                  grandTotal,
                  Icons.account_balance,
                  Colors.purple,
                ),
              ),
            ],
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
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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

  Widget _buildOrganizationalStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              const Text(
                'Organization Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Districts',
                  _totalDistricts.toString(),
                  Icons.location_city,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Churches',
                  _totalChurches.toString(),
                  Icons.church,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Staff',
                  _totalStaff.toString(),
                  Icons.people,
                  Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Members',
                  NumberFormat('#,###').format(_totalMembers),
                  Icons.groups,
                  Colors.pink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
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

  Widget _buildReportingStatus() {
    final reportingPercentage = _totalChurches > 0
        ? (_churchesWithReports / _totalChurches * 100).toInt()
        : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              const Text(
                'Reporting Status',
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
              border: Border.all(color: Colors.grey[300]!),
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
                    const Text(
                      'Churches Reported',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$_churchesWithReports / $_totalChurches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _totalChurches > 0
                        ? _churchesWithReports / _totalChurches
                        : 0,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      reportingPercentage >= 80
                          ? Colors.green
                          : reportingPercentage >= 50
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$reportingPercentage% Complete',
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
    );
  }
}
