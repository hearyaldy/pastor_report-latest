import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/theme_helper.dart';
import 'package:pastor_report/utils/theme_colors.dart';

class AllBorangBReportsScreen extends StatefulWidget {
  const AllBorangBReportsScreen({super.key});

  @override
  State<AllBorangBReportsScreen> createState() =>
      _AllBorangBReportsScreenState();
}

class _AllBorangBReportsScreenState extends State<AllBorangBReportsScreen> {
  final BorangBFirestoreService _firestoreService =
      BorangBFirestoreService.instance;
  final TextEditingController _searchController = TextEditingController();

  List<BorangBData> _reports = [];
  List<BorangBData> _filteredReports = [];
  final Map<String, String> _districtNames = {}; // Cache district names
  final Set<String> _expandedCards = {}; // Track which cards are expanded
  bool _isLoading = true;
  bool _isSortExpanded = false; // Add this for collapsible sort section
  bool _isMissionExpanded = false; // Add this for collapsible mission section
  bool _isDistrictExpanded = false; // Add this for collapsible district section
  String _searchQuery = '';
  String _sortBy = 'Month (Newest)';
  String _selectedMission = 'All';
  String _selectedDistrict = 'All';

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllReports() async {
    setState(() => _isLoading = true);
    try {
      // Get current user's mission
      final authProvider = context.read<AuthProvider>();
      final userMission = authProvider.user?.mission;

      final reports = await _firestoreService.getAllReports();

      // Filter to only show SUBMITTED reports (drafts should not be visible)
      final submittedReports = reports
          .where((r) => r.status == ReportStatus.submitted)
          .toList();

      // Filter reports by user's mission if they are ministerial secretary
      List<BorangBData> filteredByMission = submittedReports;
      if (userMission != null && userMission.isNotEmpty) {
        filteredByMission =
            submittedReports.where((r) => r.missionId == userMission).toList();
        // Set the selected mission to user's mission and disable changing it
        _selectedMission = userMission;
      }

      // Load district names for submitted reports to build complete cache
      final districtIds = submittedReports
          .where((r) => r.districtId != null && r.districtId!.isNotEmpty)
          .map((r) => r.districtId!)
          .toSet();

      debugPrint('Loading ${districtIds.length} unique districts...');
      for (final districtId in districtIds) {
        if (!_districtNames.containsKey(districtId)) {
          try {
            final district = await DistrictService.instance.getDistrictById(districtId);
            if (district != null) {
              _districtNames[districtId] = district.name;
              debugPrint('✅ Loaded district: ${district.name} (ID: $districtId)');
            } else {
              // Try to get the district name using the resolve function which tries multiple approaches
              // This is a temporary fix - we'll try to resolve it when displaying
              _districtNames[districtId] = districtId; // Placeholder
            }
          } catch (e) {
            debugPrint('❌ Error loading district $districtId: $e');
            _districtNames[districtId] = districtId; // Fallback to ID on error
          }
        }
      }
      debugPrint('District names cache: $_districtNames');

      if (mounted) {
        setState(() {
          _reports = filteredByMission;
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading all Borang B reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFiltersAndSort() {
    var filtered = List<BorangBData>.from(_reports);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((report) {
        final searchLower = _searchQuery.toLowerCase();
        final nameLower = report.userName.toLowerCase();
        final districtName = report.districtId != null
            ? (_districtNames[report.districtId] ?? '').toLowerCase()
            : '';
        final monthStr =
            DateFormat('MMMM yyyy').format(report.month).toLowerCase();

        return nameLower.contains(searchLower) ||
            districtName.contains(searchLower) ||
            monthStr.contains(searchLower);
      }).toList();
    }

    // Apply mission filter
    if (_selectedMission != 'All') {
      filtered =
          filtered.where((r) => r.missionId == _selectedMission).toList();
    }

    // Apply district filter
    if (_selectedDistrict != 'All') {
      filtered =
          filtered.where((r) => r.districtId == _selectedDistrict).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'Month (Newest)':
        filtered.sort((a, b) => b.month.compareTo(a.month));
        break;
      case 'Month (Oldest)':
        filtered.sort((a, b) => a.month.compareTo(b.month));
        break;
      case 'Name (A-Z)':
        filtered.sort((a, b) => a.userName.compareTo(b.userName));
        break;
      case 'Name (Z-A)':
        filtered.sort((a, b) => b.userName.compareTo(a.userName));
        break;
      case 'District':
        filtered.sort((a, b) {
          final districtA = _districtNames[a.districtId] ?? '';
          final districtB = _districtNames[b.districtId] ?? '';
          return districtA.compareTo(districtB);
        });
        break;
    }

    setState(() => _filteredReports = filtered);
  }

  void _viewReport(BorangBData report) {
    // Get the actual names instead of IDs
    final districtName = report.districtId != null
        ? (_districtNames[report.districtId] ?? report.districtId)
        : null;
    
    // Use MissionService to resolve mission name properly
    final missionName = report.missionId != null
        ? MissionService.instance.getMissionNameById(report.missionId)
        : null;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAllReports,
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfographics(),
                    const SizedBox(height: 16),
                    _buildActiveFiltersChips(),
                  ],
                ),
              ),
            ),
            _buildReportsList(),
          ],
        ),
      ),
      floatingActionButton: _buildFilterFAB(),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Borang B Reports',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted reports only • Drafts are private',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
    );
  }

  Widget _buildInfographics() {
    // Calculate statistics
    final totalBaptisms = _filteredReports.fold<int>(0, (sum, r) => sum + r.baptisms);
    final totalMembers = _filteredReports.isNotEmpty
        ? _filteredReports.map((r) => r.membersEnd).reduce((a, b) => a > b ? a : b)
        : 0;
    final totalFinancial = _filteredReports.fold<double>(0, (sum, r) => sum + r.totalFinancial);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Reports',
                '${_filteredReports.length}',
                Icons.description,
                context.colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Baptisms',
                '$totalBaptisms',
                Icons.water_drop,
                Colors.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Members',
                '$totalMembers',
                Icons.people,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Financial',
                'RM ${totalFinancial.toStringAsFixed(0)}',
                Icons.attach_money,
                Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.withAlpha(color, 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    final activeFilters = <Widget>[];

    if (_searchQuery.isNotEmpty) {
      activeFilters.add(_buildFilterChip('Search: $_searchQuery', () {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
          _applyFiltersAndSort();
        });
      }));
    }

    if (_sortBy != 'Month (Newest)') {
      activeFilters.add(_buildFilterChip('Sort: $_sortBy', () {
        setState(() {
          _sortBy = 'Month (Newest)';
          _applyFiltersAndSort();
        });
      }));
    }

    if (_selectedMission != 'All') {
      final missionName = AppConstants.missions.firstWhere(
        (m) => m['id'] == _selectedMission,
        orElse: () => {'name': _selectedMission},
      )['name'];
      activeFilters.add(_buildFilterChip('Mission: $missionName', () {
        setState(() {
          _selectedMission = 'All';
          _applyFiltersAndSort();
        });
      }));
    }

    if (_selectedDistrict != 'All') {
      final districtName = _districtNames[_selectedDistrict] ?? _selectedDistrict;
      activeFilters.add(_buildFilterChip('District: $districtName', () {
        setState(() {
          _selectedDistrict = 'All';
          _applyFiltersAndSort();
        });
      }));
    }

    if (activeFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_list, size: 16, color: context.colors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Active Filters',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _sortBy = 'Month (Newest)';
                  _selectedMission = 'All';
                  _selectedDistrict = 'All';
                  _applyFiltersAndSort();
                });
              },
              child: Text(
                'Clear All',
                style: TextStyle(fontSize: 12, color: context.colors.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: activeFilters,
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDelete) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: Icon(Icons.close, size: 16, color: context.colors.textSecondary),
      onDeleted: onDelete,
      backgroundColor: context.colors.withAlpha(context.colors.primary, 0.1),
      side: BorderSide(color: context.colors.withAlpha(context.colors.primary, 0.3)),
    );
  }

  Widget _buildFilterFAB() {
    final hasActiveFilters = _searchQuery.isNotEmpty ||
        _sortBy != 'Month (Newest)' ||
        _selectedMission != 'All' ||
        _selectedDistrict != 'All';

    return FloatingActionButton.extended(
      onPressed: _showFiltersBottomSheet,
      backgroundColor: context.colors.primary,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.filter_list, color: context.colors.onPrimary),
          if (hasActiveFilters)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.primary, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      label: Text('Filters', style: TextStyle(color: context.colors.onPrimary)),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Row(
                children: [
                  Icon(Icons.filter_list, color: context.colors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Filter Reports',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Filters content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildSortFilter(),
                    const SizedBox(height: 16),
                    _buildMissionFilter(),
                    const SizedBox(height: 16),
                    _buildDistrictFilter(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              // Apply button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Apply Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by name, district, or month...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _applyFiltersAndSort();
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
          _applyFiltersAndSort();
        });
      },
    );
  }

  Widget _buildSortFilter() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.withAlpha(context.colors.primary, 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isSortExpanded = !_isSortExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.sort, color: context.colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sort Reports By',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _sortBy,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isSortExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.colors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isSortExpanded) ...[
            Divider(height: 1, color: context.colors.outline),
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                value: _sortBy,
                decoration: InputDecoration(
                  labelText: 'Sort By',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: context.colors.background,
                  prefixIcon: const Icon(Icons.sort_by_alpha),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'Month (Newest)',
                      child: Text('Month (Newest First)')),
                  DropdownMenuItem(
                      value: 'Month (Oldest)',
                      child: Text('Month (Oldest First)')),
                  DropdownMenuItem(
                      value: 'Name (A-Z)', child: Text('Name (A-Z)')),
                  DropdownMenuItem(
                      value: 'Name (Z-A)', child: Text('Name (Z-A)')),
                  DropdownMenuItem(value: 'District', child: Text('District')),
                ],
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                    _applyFiltersAndSort();
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMissionFilter() {
    final authProvider = context.read<AuthProvider>();
    final userMission = authProvider.user?.mission;
    final isMissionLevelStaff =
        (authProvider.user?.isMinisterialSecretary ?? false) ||
            (authProvider.user?.isOfficer ?? false) ||
            (authProvider.user?.isDirector ?? false);

    // If user is mission-level staff (ministerial secretary, officer, or director), show read-only mission info
    if (isMissionLevelStaff && userMission != null) {
      final missionName = AppConstants.missions.firstWhere(
        (m) => m['id'] == userMission,
        orElse: () => {'name': 'Unknown Mission'},
      )['name'];

      return Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colors.withAlpha(context.colors.primary, 0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.business, color: context.colors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Mission',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      missionName ?? 'Unknown Mission',
                      style: TextStyle(
                        fontSize: 16,
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock, color: context.colors.textSecondary, size: 20),
            ],
          ),
        ),
      );
    }

    // For super admin/admin, show dropdown filter with collapse
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.withAlpha(context.colors.primary, 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isMissionExpanded = !_isMissionExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.business, color: context.colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filter by Mission',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _selectedMission == 'All'
                        ? 'All Missions'
                        : AppConstants.missions.firstWhere(
                            (m) => m['id'] == _selectedMission,
                            orElse: () => {'name': _selectedMission},
                          )['name']!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isMissionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.colors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isMissionExpanded) ...[
            Divider(height: 1, color: context.colors.outline),
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                value: _selectedMission,
                decoration: InputDecoration(
                  labelText: 'Mission',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: context.colors.background,
                  prefixIcon: const Icon(Icons.location_city),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                      value: 'All', child: Text('All Missions')),
                  ...AppConstants.missions.map((m) => DropdownMenuItem(
                        value: m['id'],
                        child: Text(m['name']!),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMission = value!;
                    _selectedDistrict =
                        'All'; // Reset district when mission changes
                    _applyFiltersAndSort();
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDistrictFilter() {
    // Get unique districts from filtered reports
    final availableDistricts = <String, String>{};
    for (final report in _reports) {
      if (report.districtId != null &&
          report.districtId!.isNotEmpty &&
          (_selectedMission == 'All' || report.missionId == _selectedMission)) {
        availableDistricts[report.districtId!] =
            _districtNames[report.districtId] ?? report.districtId!;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.withAlpha(context.colors.primary, 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isDistrictExpanded = !_isDistrictExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.place, color: context.colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filter by District',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _selectedDistrict == 'All'
                        ? 'All Districts'
                        : availableDistricts[_selectedDistrict] ??
                            _selectedDistrict,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isDistrictExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.colors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isDistrictExpanded) ...[
            Divider(height: 1, color: context.colors.outline),
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                value: _selectedDistrict,
                decoration: InputDecoration(
                  labelText: 'District',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: context.colors.background,
                  prefixIcon: const Icon(Icons.location_on),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                      value: 'All', child: Text('All Districts')),
                  ...availableDistricts.entries.map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDistrict = value!;
                    _applyFiltersAndSort();
                  });
                },
              ),
            ),
          ],
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

    if (_filteredReports.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 80, color: context.colors.emptyStateIcon),
              const SizedBox(height: 16),
              Text(
                'No reports found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
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
          (context, index) => _buildReportCard(_filteredReports[index]),
          childCount: _filteredReports.length,
        ),
      ),
    );
  }

  Widget _buildReportCard(BorangBData report) {
    final isExpanded = _expandedCards.contains(report.id);
    final monthStr = DateFormat('MMMM yyyy').format(report.month);
    final statusColor = report.status == ReportStatus.submitted
        ? Theme.of(context).colorScheme.primary
        : Colors.orange;
    final statusText =
        report.status == ReportStatus.submitted ? 'Submitted' : 'Draft';
    final districtName = report.districtId != null
        ? (_districtNames[report.districtId] ?? 'Unknown District')
        : 'No District';
    final missionName = report.missionId != null
        ? (AppConstants.missions.firstWhere(
              (m) => m['id'] == report.missionId,
              orElse: () => {'name': 'Unknown'},
            )['name'] ??
            'Unknown')
        : 'No Mission';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Compact header (always visible)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(report.id);
                } else {
                  _expandedCards.add(report.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Compact avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_ind,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Report info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_month,
                                size: 12, color: context.colors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              monthStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildCompactChip(
                              statusText,
                              report.status == ReportStatus.submitted
                                  ? Icons.check_circle
                                  : Icons.edit,
                              statusColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse icon
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: context.colors.primary,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          // Expanded details
          if (isExpanded) ...[
            Divider(height: 1, color: context.colors.outline),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location info
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          Icons.business,
                          'Mission',
                          missionName,
                          context.colors.adaptive(
                            light: const Color(0xFF1976D2),
                            dark: const Color(0xFF90CAF9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildInfoRow(
                          Icons.place,
                          'District',
                          districtName,
                          context.colors.adaptive(
                            light: const Color(0xFF388E3C),
                            dark: const Color(0xFF81C784),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Submit date/time
                  if (report.submittedAt != null) ...[
                    _buildInfoRow(
                      Icons.access_time,
                      'Submitted',
                      DateFormat('MMM dd, yyyy • h:mm a')
                          .format(report.submittedAt!),
                      context.colors.primary,
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Quick stats
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.withAlpha(context.colors.primary, 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Stats',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
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
                                Icons.people,
                                'Members',
                                report.membersEnd.toString(),
                                Colors.blue,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                Icons.home,
                                'Visits',
                                report.totalVisitations.toString(),
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // View full report button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _viewReport(report),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Full Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: context.colors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

}
