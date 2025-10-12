import 'package:flutter/material.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';

class DistrictManagementScreen extends StatefulWidget {
  const DistrictManagementScreen({super.key});

  @override
  State<DistrictManagementScreen> createState() =>
      _DistrictManagementScreenState();
}

class _DistrictManagementScreenState extends State<DistrictManagementScreen> {
  final DistrictService _districtService = DistrictService.instance;
  final RegionService _regionService = RegionService.instance;
  final MissionService _missionService = MissionService();
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedMissionId;
  String? _currentMissionId;
  String? _selectedRegionFilter;
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await _userService.getCurrentUser();
      _currentMissionId = _currentUser?.mission;

      final isDistrictPastor =
          _currentUser?.userRole == UserRole.districtPastor;
      final districtRef = _currentUser?.district;

      if (isDistrictPastor && districtRef != null && districtRef.isNotEmpty) {
        District? district;

        // Try direct lookup by ID first
        try {
          district = await _districtService.getDistrictById(districtRef);
        } catch (_) {
          // Ignore and try by name
        }

        // If not found by ID, try by name (legacy data)
        if (district == null) {
          try {
            district = await _districtService.getDistrictByName(districtRef);
            if (district != null) {
              await _userService.updateUserProfile(
                uid: _currentUser!.uid,
                district: district.id,
              );
            }
          } catch (e) {
            debugPrint(
                'DistrictManagement: Failed to resolve district by name "$districtRef": $e');
          }
        }

        // Ensure mission is synced when district is found
        if (district != null && district.missionId.isNotEmpty) {
          final needsMissionUpdate = _currentMissionId == null ||
              _currentMissionId!.isEmpty ||
              _currentMissionId != district.missionId;

          if (needsMissionUpdate) {
            try {
              await _userService.updateUserProfile(
                uid: _currentUser!.uid,
                mission: district.missionId,
              );
            } catch (e) {
              debugPrint(
                  'DistrictManagement: Failed to synchronize mission for user: $e');
            }
          }

          _currentMissionId = district.missionId;
        }

        // Reload user to capture potential updates
        _currentUser = await _userService.getCurrentUser();
        _currentMissionId = _currentUser?.mission ?? _currentMissionId;
      }

      if (!(_currentUser?.isSuperAdmin ?? false)) {
        _selectedMissionId = _currentMissionId;
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isSuperAdmin => _currentUser?.isSuperAdmin ?? false;

  String? get _effectiveMissionId {
    return _isSuperAdmin ? _selectedMissionId : _currentMissionId;
  }

  Stream<List<District>> _getDistrictStream() {
    if (_currentUser?.userRole == UserRole.districtPastor &&
        _currentUser?.district != null) {
      // District pastors only see their own district via direct stream
      return _districtService.streamDistrictById(_currentUser!.district!);
    } else {
      // Others see all districts in their mission
      return _districtService.streamDistrictsByMission(_effectiveMissionId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            if (_isSuperAdmin) _buildMissionSelector(),
            _buildSearchSection(),
            if (_effectiveMissionId != null) ...[
              _buildRegionFilter(),
              _buildStatsCards(),
              _buildDistrictsList(),
            ] else
              _buildSelectMissionPrompt(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _effectiveMissionId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDistrictDialog(),
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add District'),
            )
          : null,
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
                        child: const Icon(
                          Icons.location_city,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'District Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Manage districts and their configurations',
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
    );
  }

  Widget _buildMissionSelector() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Mission Selector (Super Admin)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Mission>>(
              stream: _missionService.getMissionsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final missions = snapshot.data!;
                return DropdownButtonFormField<String>(
                  value: _selectedMissionId,
                  decoration: InputDecoration(
                    labelText: 'Select Mission to Manage',
                    prefixIcon:
                        Icon(Icons.business, color: AppColors.primaryLight),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.primaryLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppColors.primaryLight.withValues(alpha: 0.5)),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Select a mission...'),
                    ),
                    ...missions.map((mission) => DropdownMenuItem(
                          value: mission.id,
                          child: Text(mission.name),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMissionId = value;
                      _selectedRegionFilter =
                          null; // Reset region filter when mission changes
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search districts...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
            ),
          ),
          onChanged: (value) {
            if (value != _searchQuery) {
              setState(() => _searchQuery = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildRegionFilter() {
    // Hide region filter for district pastors
    if (_currentUser?.userRole == UserRole.districtPastor) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: StreamBuilder<List<Region>>(
          stream: _regionService.streamRegionsByMission(_effectiveMissionId!),
          builder: (context, snapshot) {
            final regions = snapshot.data ?? [];
            if (regions.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: _selectedRegionFilter,
                decoration: InputDecoration(
                  labelText: 'Filter by Region',
                  prefixIcon: const Icon(Icons.map),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.primaryLight, width: 2),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Regions'),
                  ),
                  ...regions.map((region) => DropdownMenuItem(
                        value: region.id,
                        child: Text(region.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedRegionFilter = value);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: StreamBuilder<List<District>>(
          stream: _getDistrictStream(),
          builder: (context, snapshot) {
            final districts = snapshot.data ?? [];
            final totalDistricts = districts.length;
            final filteredDistricts = _selectedRegionFilter != null
                ? districts
                    .where((d) => d.regionId == _selectedRegionFilter)
                    .length
                : totalDistricts;

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Districts',
                    value: totalDistricts.toString(),
                    icon: Icons.location_city,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: _selectedRegionFilter != null
                        ? 'In Region'
                        : 'All Districts',
                    value: filteredDistricts.toString(),
                    icon: Icons.filter_list,
                    color: Colors.blue,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectMissionPrompt() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Mission',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a mission to manage its districts',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    return StreamBuilder<List<District>>(
      stream: _getDistrictStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        var districts = snapshot.data ?? [];

        // Apply region filter
        if (_selectedRegionFilter != null) {
          districts = districts
              .where((d) => d.regionId == _selectedRegionFilter)
              .toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          districts = districts.where((district) {
            return district.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                district.code
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (districts.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_city_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No districts yet'
                        : 'No districts found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Tap + to create a new district',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final district = districts[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildDistrictCard(district),
              );
            },
            childCount: districts.length,
          ),
        );
      },
    );
  }

  Widget _buildDistrictCard(District district) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          onTap: () => _showDistrictDetails(district),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_city,
                    color: AppColors.primaryLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        district.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${district.code}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      FutureBuilder<Region?>(
                        future: _regionService.getRegionById(district.regionId),
                        builder: (context, regionSnapshot) {
                          if (regionSnapshot.hasData &&
                              regionSnapshot.data != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Region: ${regionSnapshot.data!.name}',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditDistrictDialog(district);
                        break;
                      case 'delete':
                        _confirmDeleteDistrict(district);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDistrictDetails(District district) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(district.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Code', district.code),
            FutureBuilder<Region?>(
              future: _regionService.getRegionById(district.regionId),
              builder: (context, regionSnapshot) {
                final regionName =
                    regionSnapshot.data?.name ?? 'Unknown Region';
                return _buildDetailRow('Region', regionName);
              },
            ),
            _buildDetailRow('Created By', district.createdBy),
            _buildDetailRow(
                'Created', district.createdAt.toString().split('.')[0]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditDistrictDialog(district);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showAddDistrictDialog() {
    if (_effectiveMissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a mission first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedRegionId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New District'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'District Name',
                      hintText: 'e.g., North District',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'District Code',
                      hintText: 'e.g., ND',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Region>>(
                    stream: _regionService
                        .streamRegionsByMission(_effectiveMissionId!),
                    builder: (context, snapshot) {
                      final regions = snapshot.data ?? [];
                      if (regions.isEmpty) {
                        return const Text(
                          'No regions available. Please create a region first.',
                          style: TextStyle(color: Colors.red),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: selectedRegionId,
                        decoration: const InputDecoration(
                          labelText: 'Select Region',
                          border: OutlineInputBorder(),
                        ),
                        items: regions
                            .map((region) => DropdownMenuItem(
                                  value: region.id,
                                  child: Text(region.name),
                                ))
                            .toList(),
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a region';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            selectedRegionId = value;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final code = codeController.text.trim().toUpperCase();

                  // Check if code already exists
                  final exists = await _districtService.isDistrictCodeExists(
                      code, _effectiveMissionId!);
                  if (exists && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('District code "$code" already exists'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final district = District(
                    id: const Uuid().v4(),
                    name: nameController.text.trim(),
                    code: code,
                    regionId: selectedRegionId!,
                    missionId: _effectiveMissionId!,
                    createdAt: DateTime.now(),
                    createdBy: _currentUser?.email ?? 'admin',
                  );

                  try {
                    await _districtService.createDistrict(district);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('District created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDistrictDialog(District district) {
    final nameController = TextEditingController(text: district.name);
    final codeController = TextEditingController(text: district.code);
    final formKey = GlobalKey<FormState>();
    String? selectedRegionId = district.regionId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit District'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'District Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'District Code',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<Region>>(
                    stream: _regionService
                        .streamRegionsByMission(_effectiveMissionId!),
                    builder: (context, snapshot) {
                      final regions = snapshot.data ?? [];

                      return DropdownButtonFormField<String>(
                        value: selectedRegionId,
                        decoration: const InputDecoration(
                          labelText: 'Select Region',
                          border: OutlineInputBorder(),
                        ),
                        items: regions
                            .map((region) => DropdownMenuItem(
                                  value: region.id,
                                  child: Text(region.name),
                                ))
                            .toList(),
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a region';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            selectedRegionId = value;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final code = codeController.text.trim().toUpperCase();

                  // Check if code already exists (excluding current district)
                  if (code != district.code) {
                    final exists = await _districtService.isDistrictCodeExists(
                        code, _effectiveMissionId!);
                    if (exists && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('District code "$code" already exists'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  final updatedDistrict = district.copyWith(
                    name: nameController.text.trim(),
                    code: code,
                    regionId: selectedRegionId!,
                  );

                  try {
                    await _districtService.updateDistrict(updatedDistrict);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('District updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
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
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDistrict(District district) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete District'),
        content: Text(
          'Are you sure you want to delete "${district.name}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _districtService.deleteDistrict(district.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('District deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
