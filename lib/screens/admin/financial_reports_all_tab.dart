import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/models/financial_report_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/financial_report_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/screens/financial_report_edit_screen.dart';
import 'package:pastor_report/utils/constants.dart';

class FinancialReportsAllTab extends StatefulWidget {
  const FinancialReportsAllTab({super.key});

  @override
  State<FinancialReportsAllTab> createState() => _FinancialReportsAllTabState();
}

class _FinancialReportsAllTabState extends State<FinancialReportsAllTab> {
  final FinancialReportService _reportService = FinancialReportService();
  final ChurchService _churchService = ChurchService();
  final DistrictService _districtService = DistrictService();
  final RegionService _regionService = RegionService();
  final MissionService _missionService = MissionService.instance;

  List<FinancialReport> _allReports = [];
  List<Church> _churches = [];
  List<District> _districts = [];
  List<Region> _regions = [];
  List<Mission> _missions = [];

  String? _selectedMissionId;
  String _sortColumn = 'submittedAt';
  bool _sortAscending = false;
  bool _isLoading = true;
  final Set<String> _selectedReportIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    debugPrint('📋 FinancialReportsAllTab initialized');
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔄 Loading reference data...');

      // Get current user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Load all reference data
      _churches = await _churchService.getAllChurches();
      debugPrint('   Loaded ${_churches.length} churches');

      _districts = await _districtService.getAllDistricts();
      debugPrint('   Loaded ${_districts.length} districts');

      _regions = await _regionService.getAllRegions();
      debugPrint('   Loaded ${_regions.length} regions');

      _missions = await _missionService.getAllMissions();
      debugPrint('   Loaded ${_missions.length} missions');

      // Set mission filter based on user role
      if (user != null && user.userRole != UserRole.superAdmin) {
        // Non-superAdmin users: filter by their mission only
        _selectedMissionId = user.mission;
        debugPrint('   User role: ${user.userRole.name}, filtering by mission: ${user.mission}');
      } else {
        debugPrint('   User role: superAdmin, showing all missions');
      }

      // Load all reports
      await _loadAllReports();
    } catch (e) {
      debugPrint('❌ Error in _loadData: $e');
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

  Future<void> _loadAllReports() async {
    try {
      debugPrint('📊 Loading all financial reports...');

      // Load ALL reports directly from Firestore (including mock data)
      _allReports = await _reportService.getAllReports(
        missionId: _selectedMissionId,
      );

      debugPrint('   Total reports loaded from Firestore: ${_allReports.length}');

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final beforeSearch = _allReports.length;
        _allReports = _allReports.where((r) {
          final churchName = _getChurchName(r.churchId).toLowerCase();
          final districtName = _getDistrictName(r.districtId).toLowerCase();
          final regionName = _getRegionName(r.regionId).toLowerCase();
          final status = r.status.toLowerCase();
          final query = _searchQuery.toLowerCase();

          return churchName.contains(query) ||
              districtName.contains(query) ||
              regionName.contains(query) ||
              status.contains(query);
        }).toList();
        debugPrint('   After search filter: ${_allReports.length} (filtered ${beforeSearch - _allReports.length})');
      }

      _sortReports();

      debugPrint('✅ Finished loading reports: ${_allReports.length} total');

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ Error loading all reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  void _sortReports() {
    _allReports.sort((a, b) {
      int compare = 0;
      switch (_sortColumn) {
        case 'church':
          compare = _getChurchName(a.churchId)
              .compareTo(_getChurchName(b.churchId));
          break;
        case 'district':
          compare = _getDistrictName(a.districtId)
              .compareTo(_getDistrictName(b.districtId));
          break;
        case 'region':
          compare =
              _getRegionName(a.regionId).compareTo(_getRegionName(b.regionId));
          break;
        case 'month':
          compare = a.month.compareTo(b.month);
          break;
        case 'submittedAt':
          compare = a.submittedAt.compareTo(b.submittedAt);
          break;
        case 'status':
          compare = a.status.compareTo(b.status);
          break;
      }
      return _sortAscending ? compare : -compare;
    });
  }

  String _getChurchName(String? churchId) {
    if (churchId == null) return 'Unknown';
    try {
      final church = _churches.firstWhere((c) => c.id == churchId);
      return church.churchName;
    } catch (e) {
      return 'Unknown Church';
    }
  }

  String _getDistrictName(String? districtId) {
    if (districtId == null) return 'N/A';
    try {
      final district = _districts.firstWhere((d) => d.id == districtId);
      return district.name;
    } catch (e) {
      return 'N/A';
    }
  }

  String _getRegionName(String? regionId) {
    if (regionId == null) return 'N/A';
    try {
      final region = _regions.firstWhere((r) => r.id == regionId);
      return region.name;
    } catch (e) {
      return 'N/A';
    }
  }

  String _getMissionName(String? missionId) {
    if (missionId == null) return 'N/A';
    try {
      final mission = _missions.firstWhere((m) => m.id == missionId);
      return mission.name;
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'submitted':
        return Colors.blue;
      case 'draft':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'submitted':
        return Icons.pending;
      case 'draft':
        return Icons.edit;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group reports by month
    final Map<String, List<FinancialReport>> groupedReports = {};
    for (var report in _allReports) {
      final monthKey = DateFormat('MMMM yyyy').format(report.month);
      if (!groupedReports.containsKey(monthKey)) {
        groupedReports[monthKey] = [];
      }
      groupedReports[monthKey]!.add(report);
    }

    // Sort month keys in descending order (most recent first)
    final sortedMonthKeys = groupedReports.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    return Column(
      children: [
        // Filters and Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by church, district, region...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _loadAllReports();
                },
              ),
              // Mission Filter (only for superadmin)
              Builder(
                builder: (context) {
                  final authProvider = Provider.of<AuthProvider>(context);
                  final user = authProvider.user;
                  final isSuperAdmin = user?.userRole == UserRole.superAdmin;

                  if (!isSuperAdmin) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.filter_list, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Mission:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedMissionId,
                                  hint: Text(
                                    'All Missions',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  isExpanded: true,
                                  isDense: true,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade900),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All Missions'),
                                    ),
                                    ..._missions.map((mission) => DropdownMenuItem(
                                          value: mission.id,
                                          child: Text(mission.name),
                                        )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMissionId = value;
                                      _selectedReportIds.clear();
                                    });
                                    _loadAllReports();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // Stats Row - matches search field width and 20% smaller
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatChip(
                        'Total',
                        _allReports.length.toString(),
                        Icons.description,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _buildCompactStatChip(
                        'Approved',
                        _allReports
                            .where((r) => r.status == 'approved')
                            .length
                            .toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _buildCompactStatChip(
                        'Pending',
                        _allReports
                            .where((r) => r.status == 'submitted')
                            .length
                            .toString(),
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedReportIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _bulkDelete(),
                    icon: const Icon(Icons.delete, size: 18),
                    label: Text('Delete ${_selectedReportIds.length} Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Reports List - Grouped by Month
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox,
                              size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No reports found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        itemCount: sortedMonthKeys.length,
                        itemBuilder: (context, index) {
                          final monthKey = sortedMonthKeys[index];
                          final monthReports = groupedReports[monthKey]!;

                          return _buildMonthSection(monthKey, monthReports);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCompactStatChip(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6.4), // 20% smaller (8 * 0.8)
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.4), // 20% smaller (8 * 0.8)
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color), // 20% smaller (20 * 0.8)
          const SizedBox(height: 3.2), // 20% smaller (4 * 0.8)
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.4, // 20% smaller (18 * 0.8)
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 8, // 20% smaller (10 * 0.8)
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSection(String monthKey, List<FinancialReport> reports) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: Row(
        children: [
          Icon(Icons.calendar_month, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Text(
            monthKey,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${reports.length} reports',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: reports.map((report) => _buildReportCard(report)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(FinancialReport report) {
    final isSelected = _selectedReportIds.contains(report.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedReportIds.remove(report.id);
            } else {
              _selectedReportIds.add(report.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedReportIds.add(report.id);
                        } else {
                          _selectedReportIds.remove(report.id);
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getChurchName(report.churchId),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getDistrictName(report.districtId)} • ${_getRegionName(report.regionId)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(report.status).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(report.status),
                          size: 14,
                          color: _getStatusColor(report.status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          report.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(report.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      Icons.calendar_today,
                      'Month',
                      DateFormat('MMM yyyy').format(report.month),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      Icons.access_time,
                      'Submitted',
                      DateFormat('dd MMM').format(report.submittedAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // History section (if more than 1 entry)
              if (report.history.length > 1) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timeline, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Edit History (${report.history.length} entries)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...report.history.reversed.take(3).map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 4, right: 6),
                                decoration: BoxDecoration(
                                  color: entry.action == 'created'
                                      ? Colors.green
                                      : entry.action == 'approved'
                                      ? Colors.blue
                                      : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.action == 'created' ? '✨ Created' : entry.action == 'approved' ? '✓ Approved' : '✏️ Updated'} by ${entry.editorName}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      DateFormat('dd MMM yyyy, HH:mm').format(entry.editedAt),
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (entry.changes != null && entry.changes!.isNotEmpty) ...[
                                      Text(
                                        'Changed: ${entry.changes!.keys.join(", ")}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      if (report.history.length > 3) ...[
                        Text(
                          '+ ${report.history.length - 3} more edits',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showHistoryDialog(report),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('History', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _editReport(report),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deleteReport(report),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryLight),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
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
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildReportRow(FinancialReport report) {
    final isSelected = _selectedReportIds.contains(report.id);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        setState(() {
          if (selected == true) {
            _selectedReportIds.add(report.id);
          } else {
            _selectedReportIds.remove(report.id);
          }
        });
      },
      cells: [
        DataCell(
          Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedReportIds.add(report.id);
                } else {
                  _selectedReportIds.remove(report.id);
                }
              });
            },
          ),
        ),
        DataCell(
          Text(
            _getChurchName(report.churchId),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(Text(_getDistrictName(report.districtId))),
        DataCell(Text(_getRegionName(report.regionId))),
        DataCell(Text(DateFormat('MMM yyyy').format(report.month))),
        DataCell(Text(DateFormat('dd MMM yyyy').format(report.submittedAt))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(report.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStatusColor(report.status).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(report.status),
                  size: 14,
                  color: _getStatusColor(report.status),
                ),
                const SizedBox(width: 4),
                Text(
                  report.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(report.status),
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View History
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                tooltip: 'View History',
                onPressed: () => _showHistoryDialog(report),
              ),
              // Edit
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                color: Colors.blue,
                tooltip: 'Edit',
                onPressed: () => _editReport(report),
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                color: Colors.red,
                tooltip: 'Delete',
                onPressed: () => _deleteReport(report),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int? _getSortColumnIndex() {
    switch (_sortColumn) {
      case 'church':
        return 1;
      case 'district':
        return 2;
      case 'region':
        return 3;
      case 'month':
        return 4;
      case 'submittedAt':
        return 5;
      case 'status':
        return 6;
      default:
        return null;
    }
  }

  void _sort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
    _sortReports();
    setState(() {});
  }

  bool _isMonthFullySelected(List<FinancialReport> reports) {
    if (reports.isEmpty) return false;
    return reports.every((r) => _selectedReportIds.contains(r.id));
  }

  void _toggleMonthSelection(List<FinancialReport> reports, bool select) {
    setState(() {
      if (select) {
        _selectedReportIds.addAll(reports.map((r) => r.id));
      } else {
        _selectedReportIds.removeAll(reports.map((r) => r.id));
      }
    });
  }

  void _showHistoryDialog(FinancialReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.history, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            const Text('Edit History'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: report.history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No edit history available'),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: report.history.length,
                  itemBuilder: (context, index) {
                    final history = report.history[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.1),
                        child: Icon(
                          _getHistoryIcon(history.action),
                          color: AppColors.primaryLight,
                          size: 20,
                        ),
                      ),
                      title: Text(history.editorName),
                      subtitle: Text(
                        '${history.action} • ${DateFormat('dd MMM yyyy, HH:mm').format(history.editedAt)}',
                      ),
                      trailing: history.changes != null
                          ? IconButton(
                              icon: const Icon(Icons.info_outline, size: 20),
                              onPressed: () {
                                // Show changes detail
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Changes'),
                                    content: Text(history.changes.toString()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('CLOSE'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  IconData _getHistoryIcon(String action) {
    switch (action.toLowerCase()) {
      case 'created':
        return Icons.add_circle;
      case 'updated':
        return Icons.edit;
      case 'approved':
        return Icons.check_circle;
      default:
        return Icons.history;
    }
  }

  void _editReport(FinancialReport report) async {
    // Get the church for this report
    final church = _churches.firstWhere(
      (c) => c.id == report.churchId,
      orElse: () => Church(
        id: '',
        userId: '',
        churchName: 'Unknown',
        elderName: '',
        status: ChurchStatus.organizedChurch,
        elderEmail: '',
        elderPhone: '',
        createdAt: DateTime.now(),
      ),
    );

    // Navigate to edit screen
    await Navigator.push(
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

  void _deleteReport(FinancialReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Report'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the report for ${_getChurchName(report.churchId)} (${DateFormat('MMM yyyy').format(report.month)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _reportService.deleteReport(report.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadAllReports();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _bulkDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Bulk Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedReportIds.length} selected reports? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                for (var id in _selectedReportIds) {
                  await _reportService.deleteReport(id);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${_selectedReportIds.length} reports deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                _selectedReportIds.clear();
                _loadAllReports();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );
  }
}
