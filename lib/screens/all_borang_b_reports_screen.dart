import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/utils/constants.dart';

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
  Map<String, String> _districtNames = {}; // Cache district names
  bool _isLoading = true;
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
      final reports = await _firestoreService.getAllReports();
      
      // Load district names for reports
      final districtIds = reports
          .where((r) => r.districtId != null && r.districtId!.isNotEmpty)
          .map((r) => r.districtId!)
          .toSet();
      
      for (final districtId in districtIds) {
        if (!_districtNames.containsKey(districtId)) {
          final district = await DistrictService.instance.getDistrictById(districtId);
          if (district != null) {
            _districtNames[districtId] = district.name;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _reports = reports;
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
        final monthStr = DateFormat('MMMM yyyy').format(report.month).toLowerCase();
        
        return nameLower.contains(searchLower) ||
            districtName.contains(searchLower) ||
            monthStr.contains(searchLower);
      }).toList();
    }

    // Apply mission filter
    if (_selectedMission != 'All') {
      filtered = filtered.where((r) => r.missionId == _selectedMission).toList();
    }

    // Apply district filter
    if (_selectedDistrict != 'All') {
      filtered = filtered.where((r) => r.districtId == _selectedDistrict).toList();
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
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildSortFilter(),
                    const SizedBox(height: 16),
                    _buildMissionFilter(),
                    const SizedBox(height: 16),
                    _buildDistrictFilter(),
                    const SizedBox(height: 8),
                    _buildSummaryBar(),
                  ],
                ),
              ),
            ),
            _buildReportsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primaryLight,
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
              padding: const EdgeInsets.fromLTRB(56, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Borang B Reports',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View all submitted monthly reports',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
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
        fillColor: Colors.grey.shade100,
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
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sort, color: Colors.deepPurple.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sort Reports By',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: InputDecoration(
                labelText: 'Sort By',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.sort_by_alpha),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Month (Newest)', child: Text('Month (Newest First)')),
                DropdownMenuItem(value: 'Month (Oldest)', child: Text('Month (Oldest First)')),
                DropdownMenuItem(value: 'Name (A-Z)', child: Text('Name (A-Z)')),
                DropdownMenuItem(value: 'Name (Z-A)', child: Text('Name (Z-A)')),
                DropdownMenuItem(value: 'District', child: Text('District')),
              ],
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _applyFiltersAndSort();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Filter by Mission',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedMission,
              decoration: InputDecoration(
                labelText: 'Mission',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.location_city),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'All', child: Text('All Missions')),
                ...AppConstants.missions.map((m) => DropdownMenuItem(
                      value: m['id'],
                      child: Text(m['name']!),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMission = value!;
                  _selectedDistrict = 'All'; // Reset district when mission changes
                  _applyFiltersAndSort();
                });
              },
            ),
          ],
        ),
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
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place, color: Colors.teal.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Filter by District',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDistrict,
              decoration: InputDecoration(
                labelText: 'District',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.location_on),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 'All', child: Text('All Districts')),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Total Reports:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_filteredReports.length}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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

    if (_filteredReports.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No reports found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
    final monthStr = DateFormat('MMMM yyyy').format(report.month);
    final statusColor = report.status == ReportStatus.submitted
        ? Colors.green
        : Colors.orange;
    final statusText = report.status == ReportStatus.submitted
        ? 'Submitted'
        : 'Draft';
    final districtName = report.districtId != null
        ? (_districtNames[report.districtId] ?? 'Unknown District')
        : 'No District';
    final missionName = report.missionId != null
        ? (AppConstants.missions.firstWhere(
              (m) => m['id'] == report.missionId,
              orElse: () => {'name': 'Unknown'},
            )['name'] ?? 'Unknown')
        : 'No Mission';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewReport(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.shade400,
                      Colors.deepPurple.shade600,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_ind,
                  color: Colors.white,
                  size: 24,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      monthStr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildChip(
                          statusText,
                          report.status == ReportStatus.submitted
                              ? Icons.check_circle
                              : Icons.edit,
                          statusColor.withValues(alpha: 0.1),
                          statusColor,
                        ),
                        _buildChip(
                          districtName,
                          Icons.place,
                          Colors.teal.shade100,
                          Colors.teal.shade700,
                        ),
                        _buildChip(
                          missionName,
                          Icons.business,
                          Colors.blue.shade100,
                          Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
