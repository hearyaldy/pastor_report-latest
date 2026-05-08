import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/services/restoration_service.dart';
import 'package:pastor_report/services/region_migration_service.dart';
import 'package:pastor_report/services/user_staff_region_migration_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/utils/web_wrapper.dart';

class ChurchManagementScreen extends StatefulWidget {
  const ChurchManagementScreen({super.key});

  @override
  State<ChurchManagementScreen> createState() => _ChurchManagementScreenState();
}

class _ChurchManagementScreenState extends State<ChurchManagementScreen> {
  final ChurchService _churchService = ChurchService();
  final DistrictService _districtService = DistrictService();
  final RegionService _regionService = RegionService();
  final MissionService _missionService = MissionService.instance;
  final RestorationService _restorationService = RestorationService();
  final RegionMigrationService _migrationService = RegionMigrationService();
  final UserStaffRegionMigrationService _userStaffMigrationService = UserStaffRegionMigrationService();

  List<Church> _churches = [];
  List<District> _districts = [];
  List<Region> _regions = [];
  List<Mission> _missions = [];

  String? _selectedMissionId;
  String? _selectedRegionId;
  String? _selectedDistrictId;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Load missions first
      _missions = await _missionService.getAllMissions();

      // For superadmin, let them select mission. For others, use their assigned mission
      if (user?.userRole == UserRole.superAdmin) {
        // Load all data if no mission selected yet
        if (_selectedMissionId == null && _missions.isNotEmpty) {
          _selectedMissionId = _missions.first.id;
        }
      } else if (user?.userRole == UserRole.districtPastor &&
          user?.mission != null) {
        // For district pastors, set their mission (district is optional)
        _selectedMissionId = user!.mission;
        _selectedDistrictId = user.district; // May be null
      } else if (user?.mission != null) {
        _selectedMissionId = user!.mission;
      }

      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading initial data: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    if (_selectedMissionId == null) return;

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Load regions for selected mission
      _regions = await _regionService.getRegionsByMission(_selectedMissionId!);

      // Debug: Log loaded regions with full details
      print('ChurchManagement: Loaded ${_regions.length} regions for mission $_selectedMissionId');
      final selectedMission = _missions.firstWhere((m) => m.id == _selectedMissionId,
        orElse: () => Mission(id: _selectedMissionId!, name: 'Unknown'));
      print('ChurchManagement: Selected mission name: ${selectedMission.name}');
      for (var region in _regions) {
        print('  - Region: ${region.name} | ID: ${region.id} | missionId: ${region.missionId}');
      }

      // Check for duplicates or regions from other missions
      final regionsByName = <String, List<Region>>{};
      for (var region in _regions) {
        regionsByName.putIfAbsent(region.name, () => []).add(region);
      }
      regionsByName.forEach((name, regions) {
        if (regions.length > 1) {
          print('WARNING: Duplicate regions found for "$name":');
          for (var r in regions) {
            print('  * ID: ${r.id} | missionId: ${r.missionId}');
          }
        }
      });

      if (user?.userRole == UserRole.districtPastor) {
        if (user?.district != null) {
          // District pastor should only see churches in their district.
          _districts =
              await _districtService.getDistrictsByMission(user!.mission!);
          _churches =
              await _churchService.getChurchesByDistrict(user.district!);
        } else {
          // If district is not assigned, show no churches.
          _districts = [];
          _churches = [];
        }
      } else if (_selectedRegionId != null) {
        _districts =
            await _districtService.getDistrictsByRegion(_selectedRegionId!);

        if (_selectedDistrictId != null) {
          _churches =
              await _churchService.getChurchesByDistrict(_selectedDistrictId!);
        } else if (_districts.isNotEmpty) {
          // Use bulk loading for all districts in the region
          final districtIds = _districts.map((d) => d.id).toList();
          _churches = await _churchService.getChurchesByDistricts(districtIds);
        }
      } else {
        // Load all districts and churches for the mission (for admins)
        _districts =
            await _districtService.getDistrictsByMission(_selectedMissionId!);
            
        if (_districts.isNotEmpty) {
          // Use bulk loading for all districts in the mission
          final districtIds = _districts.map((d) => d.id).toList();
          _churches = await _churchService.getChurchesByDistricts(districtIds);
        } else {
          _churches = [];
        }
      }

      _churches.sort((a, b) => a.churchName.compareTo(b.churchName));
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

  String _getRegionName(String? regionId) {
    if (regionId == null) return 'N/A';
    final region = _regions.firstWhere(
      (r) => r.id == regionId,
      orElse: () => Region(
        id: '',
        name: 'Unknown',
        code: '',
        missionId: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    return region.name;
  }

  // Natural sort comparator for sorting strings with numbers
  int _naturalCompare(String a, String b) {
    // Extract numbers from strings for comparison
    final aMatch = RegExp(r'\d+').firstMatch(a);
    final bMatch = RegExp(r'\d+').firstMatch(b);

    if (aMatch != null && bMatch != null) {
      final aNum = int.parse(aMatch.group(0)!);
      final bNum = int.parse(bMatch.group(0)!);
      if (aNum != bNum) {
        return aNum.compareTo(bNum);
      }
    }

    // Fall back to string comparison
    return a.compareTo(b);
  }

  // Check if a region belongs to the selected mission
  // Handles both mission IDs and mission names (for backward compatibility)
  bool _regionBelongsToMission(Region region, String? missionId) {
    if (missionId == null) return true;

    // Direct ID match
    if (region.missionId == missionId) return true;

    // Check if region's missionId matches the mission's name (backward compatibility)
    final selectedMission = _missions.firstWhere(
      (m) => m.id == missionId,
      orElse: () => Mission(id: missionId, name: ''),
    );

    if (selectedMission.name.isNotEmpty) {
      // Exact match (case-insensitive)
      if (region.missionId.toLowerCase() == selectedMission.name.toLowerCase()) {
        return true;
      }
    }

    return false;
  }

  List<Church> get _filteredChurches {
    if (_searchQuery.isEmpty) return _churches;
    return _churches.where((church) {
      return church.churchName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          church.elderName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: WebWrapper(child: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            _buildSearchAndFilter(),
            _buildStatsCards(),
            _buildChurchList(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(null),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Church'),
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
                AppColors.primaryLight.withOpacity(0.9),
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.church,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Church Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).cardColor,
                              ),
                            ),
                            Text(
                              'Manage church registrations',
                              style: TextStyle(
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
        // Cleanup button - only for super admin
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            if (authProvider.user?.userRole != UserRole.superAdmin) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Clean Duplicates',
              onPressed: _showCleanupDialog,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Mission Selector (for SuperAdmin)
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.user;
                if (user?.userRole != UserRole.superAdmin) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Super Admin: Select Mission',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMissionId,
                          decoration: InputDecoration(
                            labelText: 'Mission',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            prefixIcon: const Icon(Icons.business),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: _missions.map((mission) {
                            return DropdownMenuItem(
                              value: mission.id,
                              child: Text(mission.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMissionId = value;
                                _selectedRegionId = null;
                                _selectedDistrictId = null;
                              });
                              _loadData();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search churches...',
                  prefixIcon: Icon(Icons.search, color: AppColors.primaryLight),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filters - Hide for District Pastors
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.user;
                if (user?.userRole == UserRole.districtPastor) {
                  return const SizedBox.shrink();
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Region',
                        _selectedRegionId,
                        [
                          const DropdownMenuItem(
                              value: null, child: Text('All Regions')),
                          // Filter regions by selected mission and sort naturally
                          ...(_regions
                                  .where((r) =>
                                      _regionBelongsToMission(r, _selectedMissionId))
                                  .toList()
                                    ..sort((a, b) =>
                                        _naturalCompare(a.name, b.name)))
                              .map((r) => DropdownMenuItem(
                                    value: r.id,
                                    child: Text(r.name,
                                        overflow: TextOverflow.ellipsis),
                                  )),
                        ],
                        (value) {
                          setState(() {
                            _selectedRegionId = value;
                            _selectedDistrictId = null;
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
                          // Sort districts naturally as well
                          ...(_districts.toList()
                                ..sort(
                                    (a, b) => _naturalCompare(a.name, b.name)))
                              .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name,
                                        overflow: TextOverflow.ellipsis),
                                  )),
                        ],
                        (value) {
                          setState(() => _selectedDistrictId = value);
                          _loadData();
                        },
                        Icons.location_city,
                      ),
                    ),
                  ],
                );
              },
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
        color: Theme.of(context).cardColor,
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
        initialValue: value,
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

  Widget _buildStatsCards() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Churches',
                _filteredChurches.length.toString(),
                Icons.church,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Members',
                _filteredChurches
                    .fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0))
                    .toString(),
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active',
                _filteredChurches
                    .where((c) => c.status == ChurchStatus.organizedChurch)
                    .length
                    .toString(),
                Icons.check_circle,
                Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChurchList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredChurches.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.church_outlined,
                  size: 64, color: Theme.of(context).dividerColor),
              const SizedBox(height: 16),
              Text(
                'No churches found',
                style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try a different search'
                    : 'Add your first church',
                style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.7)),
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
            final church = _filteredChurches[index];
            return _buildChurchCard(church);
          },
          childCount: _filteredChurches.length,
        ),
      ),
    );
  }

  Widget _buildChurchCard(Church church) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showChurchDetails(church),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.church,
                    color: AppColors.primaryLight,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        church.churchName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_city,
                              size: 14,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            _getDistrictName(church.districtId),
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.people,
                              size: 14,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${church.memberCount ?? 0}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ],
                      ),
                      if (church.address != null &&
                          church.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                church.address!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.7)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddEditDialog(church);
                    } else if (value == 'delete') {
                      _deleteChurch(church);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Colors.blue),
                          SizedBox(width: 12),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete'),
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
    );
  }

  void _showChurchDetails(Church church) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
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
                      color: AppColors.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.church,
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
                          church.churchName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Elder: ${church.elderName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
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
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDetailRow(
                      'Region', _getRegionName(church.regionId), Icons.map),
                  _buildDetailRow('District',
                      _getDistrictName(church.districtId), Icons.location_city),
                  _buildDetailRow('Elder Name', church.elderName, Icons.person),
                  _buildDetailRow(
                      'Members', '${church.memberCount ?? 0}', Icons.people),
                  _buildDetailRow(
                      'Status',
                      church.status.toString().split('.').last.toUpperCase(),
                      Icons.info),
                  _buildDetailRow(
                      'Address',
                      church.address != null && church.address!.isNotEmpty
                          ? church.address!
                          : 'N/A',
                      Icons.location_on),
                  _buildDetailRow(
                      'Elder Phone', church.elderPhone, Icons.phone),
                  _buildDetailRow(
                      'Elder Email', church.elderEmail, Icons.email),
                  _buildDetailRow(
                      'Created',
                      DateFormat('MMM dd, yyyy').format(church.createdAt),
                      Icons.calendar_today),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddEditDialog(church);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: BorderSide(color: AppColors.primaryLight),
                        foregroundColor: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteChurch(church);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryLight),
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
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(Church? church) {
    final isEditing = church != null;
    final churchNameController =
        TextEditingController(text: church?.churchName ?? '');
    final elderNameController =
        TextEditingController(text: church?.elderName ?? '');
    final elderEmailController =
        TextEditingController(text: church?.elderEmail ?? '');
    final elderPhoneController =
        TextEditingController(text: church?.elderPhone ?? '');
    final addressController =
        TextEditingController(text: church?.address ?? '');
    final memberCountController =
        TextEditingController(text: church?.memberCount?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    String? selectedDistrictId = church?.districtId;
    String? selectedRegionId = church?.regionId;
    String? selectedMissionId = church?.missionId ?? _selectedMissionId;
    ChurchStatus selectedStatus =
        church?.status ?? ChurchStatus.organizedChurch;

    // Prepare local selectable options based on current selections
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    final bool isSuperAdmin = currentUser?.userRole == UserRole.superAdmin;

    List<Region> modalRegions = _regions
        .where((r) => _regionBelongsToMission(r, selectedMissionId))
        .toList();
    if (selectedRegionId == null && modalRegions.isNotEmpty) {
      selectedRegionId = modalRegions.first.id;
    }
    List<District> modalDistricts = _districts
        .where(
            (d) => selectedRegionId == null || d.regionId == selectedRegionId)
        .toList();
    if (selectedDistrictId == null && modalDistricts.isNotEmpty) {
      selectedDistrictId = modalDistricts.first.id;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEditing ? Icons.edit : Icons.add,
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
                            isEditing ? 'Edit Church' : 'Add New Church',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Update ${church.churchName} information'
                                : 'Create a new church record',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
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
              const Divider(),
              // Form content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: churchNameController,
                            decoration: const InputDecoration(
                              labelText: 'Church Name',
                              hintText: 'e.g., Grace Baptist Church',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter church name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: elderNameController,
                            decoration: const InputDecoration(
                              labelText: 'Elder Name',
                              hintText: 'e.g., Pastor John Smith',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter elder name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: elderEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Elder Email (Optional)',
                              hintText: 'e.g., pastor@church.com',
                              border: OutlineInputBorder(),
                              helperText: 'Email or phone required',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              final phone = elderPhoneController.text.trim();

                              // If both are empty, show error
                              if (email.isEmpty && phone.isEmpty) {
                                return 'Please provide email or phone';
                              }

                              // If email is provided, validate it
                              if (email.isNotEmpty && !email.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: elderPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Elder Phone (Optional)',
                              hintText: 'e.g., +60123456789',
                              border: OutlineInputBorder(),
                              helperText: 'Email or phone required',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              final email = elderEmailController.text.trim();

                              // If both are empty, show error
                              if (phone.isEmpty && email.isEmpty) {
                                return 'Please provide email or phone';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address (Optional)',
                              hintText: 'Church address',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: memberCountController,
                            decoration: const InputDecoration(
                              labelText: 'Member Count (Optional)',
                              hintText: 'e.g., 150',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final count = int.tryParse(value);
                                if (count == null || count < 0) {
                                  return 'Please enter a valid number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ChurchStatus>(
                            initialValue: selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Church Status',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.label),
                            ),
                            isExpanded: true,
                            items: ChurchStatus.values
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getStatusIcon(status),
                                            size: 20,
                                            color: _getStatusColor(status),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(status.displayName),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => selectedStatus = value);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          // Organization selectors: Mission (if super admin), Region, District
                          Row(
                            children: [
                              Icon(Icons.account_tree,
                                  color: AppColors.primaryLight),
                              const SizedBox(width: 8),
                              const Text(
                                'Organization',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isSuperAdmin) ...[
                            DropdownButtonFormField<String>(
                              initialValue: selectedMissionId,
                              decoration: const InputDecoration(
                                labelText: 'Mission',
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: _missions
                                  .map((m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text(m.name),
                                      ))
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                setModalState(() {
                                  selectedMissionId = value;
                                  selectedRegionId = null;
                                  selectedDistrictId = null;
                                  modalRegions = [];
                                  modalDistricts = [];
                                });
                                try {
                                  final fetchedRegions = await _regionService
                                      .getRegionsByMission(value);
                                  setModalState(() {
                                    modalRegions = fetchedRegions;
                                    if (modalRegions.isNotEmpty) {
                                      selectedRegionId = modalRegions.first.id;
                                    }
                                  });
                                  if (selectedRegionId != null) {
                                    final fetchedDistricts =
                                        await _districtService
                                            .getDistrictsByRegion(
                                                selectedRegionId!);
                                    setModalState(() {
                                      modalDistricts = fetchedDistricts;
                                      if (modalDistricts.isNotEmpty) {
                                        selectedDistrictId =
                                            modalDistricts.first.id;
                                      }
                                    });
                                  }
                                } catch (e) {
                                  // ignore error in UI, can show a snackbar if needed
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            // Show fixed Mission for non-super admins
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Mission',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _missions
                                    .firstWhere(
                                      (m) => m.id == selectedMissionId,
                                      orElse: () => Mission(
                                          id: selectedMissionId ?? '',
                                          name: 'Current Mission'),
                                    )
                                    .name,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          DropdownButtonFormField<String>(
                            initialValue: selectedRegionId,
                            decoration: const InputDecoration(
                              labelText: 'Region',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: (modalRegions.toList()
                                  ..sort((a, b) => _naturalCompare(a.name, b.name)))
                                .map((r) => DropdownMenuItem(
                                      value: r.id,
                                      child: Text(r.name),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              setModalState(() {
                                selectedRegionId = value;
                                selectedDistrictId = null;
                                modalDistricts = [];
                              });
                              if (value != null) {
                                try {
                                  final fetchedDistricts =
                                      await _districtService
                                          .getDistrictsByRegion(value);
                                  setModalState(() {
                                    modalDistricts = fetchedDistricts;
                                    if (modalDistricts.isNotEmpty) {
                                      selectedDistrictId =
                                          modalDistricts.first.id;
                                    }
                                  });
                                } catch (e) {
                                  // ignore
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDistrictId,
                            decoration: const InputDecoration(
                              labelText: 'District',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: (modalDistricts.toList()
                                  ..sort((a, b) => _naturalCompare(a.name, b.name)))
                                .map((d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(d.name),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setModalState(() => selectedDistrictId = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              final memberCount =
                                  memberCountController.text.trim().isNotEmpty
                                      ? int.tryParse(
                                          memberCountController.text.trim())
                                      : null;

                              // Require organization hierarchy selections
                              if (selectedMissionId == null ||
                                  selectedRegionId == null ||
                                  selectedDistrictId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please select Mission, Region, and District'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              if (isEditing) {
                                // Update existing church
                                final updatedChurch = church.copyWith(
                                  churchName: churchNameController.text.trim(),
                                  elderName: elderNameController.text.trim(),
                                  elderEmail: elderEmailController.text.trim(),
                                  elderPhone: elderPhoneController.text.trim(),
                                  address: addressController.text.trim().isEmpty
                                      ? null
                                      : addressController.text.trim(),
                                  memberCount: memberCount,
                                  status: selectedStatus,
                                  updatedAt: DateTime.now(),
                                  missionId: selectedMissionId,
                                  regionId: selectedRegionId,
                                  districtId: selectedDistrictId,
                                );

                                await _churchService
                                    .updateChurch(updatedChurch);

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Church updated successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                // Create new church
                                final authProvider = Provider.of<AuthProvider>(
                                    context,
                                    listen: false);
                                final currentUser = authProvider.user;
                                final newChurch = Church(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  userId: currentUser?.uid ?? 'system',
                                  churchName: churchNameController.text.trim(),
                                  elderName: elderNameController.text.trim(),
                                  elderEmail: elderEmailController.text.trim(),
                                  elderPhone: elderPhoneController.text.trim(),
                                  address: addressController.text.trim().isEmpty
                                      ? null
                                      : addressController.text.trim(),
                                  memberCount: memberCount,
                                  status: selectedStatus,
                                  createdAt: DateTime.now(),
                                  districtId: selectedDistrictId,
                                  regionId: selectedRegionId,
                                  missionId: selectedMissionId,
                                );

                                await _churchService.createChurch(newChurch);

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Church created successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            Text(isEditing ? 'Update Church' : 'Create Church'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(ChurchStatus status) {
    switch (status) {
      case ChurchStatus.organizedChurch:
        return Icons.church;
      case ChurchStatus.company:
        return Icons.group;
      case ChurchStatus.group:
        return Icons.groups;
    }
  }

  Color _getStatusColor(ChurchStatus status) {
    switch (status) {
      case ChurchStatus.organizedChurch:
        return AppColors.primaryLight;
      case ChurchStatus.company:
        return Colors.blue;
      case ChurchStatus.group:
        return Colors.green;
    }
  }

  void _showCleanupDialog() {
    if (_selectedMissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a mission first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedMission = _missions.firstWhere(
      (m) => m.id == _selectedMissionId,
      orElse: () => Mission(id: _selectedMissionId!, name: 'Unknown'),
    );

    // Check if this is North Sabah Mission or Sabah Mission
    final isNorthSabahMission = selectedMission.name == 'North Sabah Mission';
    final isSabahMission = selectedMission.name == 'Sabah Mission';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.blue),
            SizedBox(width: 12),
            Text('Region Management'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current mission: ${selectedMission.name}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 16),
              // CRITICAL: Migrate semantic IDs to UUIDs
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.transform,
                            size: 16, color: Colors.purple),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Convert IDs to UUIDs (CRITICAL)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Run this FIRST if regions have semantic IDs\n• Converts "nsm_region_1" → UUID format\n• Updates all districts and churches\n• Required for app to work correctly',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Fix User/Staff Region References
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt,
                            size: 16, color: Colors.teal),
                        const SizedBox(width: 8),
                        Text(
                          'Fix User/Staff Regions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Run this AFTER UUID migration\n• Updates user and staff region references\n• Fixes UUID display issues\n• Matches by name, pattern, or number',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            if (isNorthSabahMission) ...[
              // Special option for North Sabah Mission
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high,
                            size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Fix NSM Regions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Keep NSM Region 1-4\n• Reassign Region 5-12 to Sabah Mission\n• Preserves all IDs, districts, and churches',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isSabahMission) ...[
              // Restore from JSON
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restore,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Restore from JSON',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Restore all 10 regions from churches_SAB.json\n• Create/update districts and churches\n• Preserves existing church data',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cleaning_services,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Clean Duplicates',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Keeps the most recent region\n• Removes older duplicates\n• Cannot be undone',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // Closes SingleChildScrollView
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // CRITICAL: Convert semantic IDs to UUIDs
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _performMigrationToUUIDs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.transform, size: 18),
            label: const Text('Convert to UUIDs'),
          ),
          // Fix User/Staff Regions
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _performUserStaffRegionMigration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.people_alt, size: 18),
            label: const Text('Fix User/Staff'),
          ),
          if (isNorthSabahMission)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _performNSMFix();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Fix NSM'),
            ),
          if (isSabahMission)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _performSabahRestoration();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Restore from JSON'),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performCleanup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clean Duplicates'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSabahRestoration() async {
    if (_selectedMissionId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Restoring Sabah Mission from JSON...'),
                SizedBox(height: 8),
                Text(
                  'This may take a few minutes',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'system';

      final result = await _restorationService.restoreSabahMissionFromJson(
        sabahMissionId: _selectedMissionId!,
        userId: userId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final regionsCreated = result['regionsCreated'] as int;
        final regionsUpdated = result['regionsUpdated'] as int;
        final districtsCreated = result['districtsCreated'] as int;
        final churchesCreated = result['churchesCreated'] as int;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Restoration Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully restored Sabah Mission from JSON!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📍 Regions: $regionsCreated created, $regionsUpdated updated',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🏛️ Districts: $districtsCreated created',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⛪ Churches: $churchesCreated created/updated',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'All regions (1-10), districts, and churches have been restored from churches_SAB.json',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadData(); // Refresh data
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during restoration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performNSMFix() async {
    if (_selectedMissionId == null) return;

    // Sabah Mission ID
    const sabahMissionId = '4LFC9isp22H7Og1FHBm6';

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Fixing NSM regions...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _regionService.fixNorthSabahMissionRegions(
        northSabahMissionId: _selectedMissionId!,
        sabahMissionId: sabahMissionId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final kept = result['kept'] as int;
        final reassigned = result['reassigned'] as int;
        final details = result['details'] as Map<String, dynamic>;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Migration Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully fixed NSM regions!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✓ Kept in NSM: $kept regions',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '→ Reassigned to Sabah Mission: $reassigned regions (IDs preserved)',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Regions kept in NSM:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (details['kept'] as List).join(', '),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if ((details['reassigned'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Regions reassigned to Sabah Mission:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (details['reassigned'] as List).join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadData(); // Refresh data
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during fix: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performCleanup() async {
    if (_selectedMissionId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cleaning up duplicates...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _regionService.cleanupDuplicateRegions(_selectedMissionId!);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final removed = result['duplicatesRemoved'] as int;
        final total = result['totalRegions'] as int;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  removed > 0 ? Icons.check_circle : Icons.info,
                  color: removed > 0 ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 12),
                const Text('Cleanup Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  removed > 0
                      ? 'Successfully removed $removed duplicate region(s)'
                      : 'No duplicates found',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total regions now: $total',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadData(); // Refresh data
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during cleanup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteChurch(Church church) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Church'),
          ],
        ),
        content: Text('Are you sure you want to delete ${church.churchName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _churchService.deleteChurch(church.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Church deleted successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performMigrationToUUIDs() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Converting regions to UUID format...'),
                SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _migrationService.migrateRegionsToUUIDs();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final migrated = result['migrated'] as int;
        final skipped = result['skipped'] as int;
        final migrations = result['migrations'] as Map<String, String>;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.purple),
                SizedBox(width: 12),
                Text('Migration Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  migrated > 0
                      ? 'Successfully migrated $migrated region(s) to UUID format!'
                      : 'All regions already using UUID format',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✓ Migrated: $migrated regions',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '→ Already UUID: $skipped regions',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '✓ Updated all districts and churches',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (migrations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ID Conversions:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: migrations.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${entry.key} → ${entry.value.substring(0, 8)}...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadData(); // Refresh data
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during migration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performUserStaffRegionMigration() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Fixing user and staff region references...'),
                SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await _userStaffMigrationService.migrateUserAndStaffRegionReferences();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result['success'] == true) {
        final usersUpdated = result['usersUpdated'] as int;
        final staffUpdated = result['staffUpdated'] as int;
        final usersSkipped = result['usersSkipped'] as int;
        final staffSkipped = result['staffSkipped'] as int;

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.teal),
                SizedBox(width: 12),
                Text('Migration Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usersUpdated + staffUpdated > 0
                      ? 'Successfully fixed user and staff region references!'
                      : 'All users and staff already have correct region references',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✓ Users Updated: $usersUpdated',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '✓ Staff Updated: $staffUpdated',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '→ Total Fixed: ${usersUpdated + staffUpdated}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (usersSkipped + staffSkipped > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ℹ Skipped: ${usersSkipped + staffSkipped} (already correct or no region)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Region names should now display correctly for all users and staff.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadData(); // Refresh data
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during migration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
