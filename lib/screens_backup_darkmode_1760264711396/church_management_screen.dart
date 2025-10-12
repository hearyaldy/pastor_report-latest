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
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:intl/intl.dart';

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
          _churches = [];
          for (var district in _districts) {
            final districtChurches =
                await _churchService.getChurchesByDistrict(district.id);
            _churches.addAll(districtChurches);
          }
        }
      } else {
        // Load all districts and churches for the mission (for admins)
        _districts =
            await _districtService.getDistrictsByMission(_selectedMissionId!);
        _churches = [];
        for (var district in _districts) {
          final districtChurches =
              await _churchService.getChurchesByDistrict(district.id);
          _churches.addAll(districtChurches);
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
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
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
      ),
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
                        child: const Icon(Icons.church,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Church Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Super Admin: Select Mission',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedMissionId,
                          decoration: InputDecoration(
                            labelText: 'Mission',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
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
                          ..._regions.map((r) => DropdownMenuItem(
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
                          ..._districts.map((d) => DropdownMenuItem(
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
              color: Colors.grey[600],
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
              Icon(Icons.church_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No churches found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try a different search'
                    : 'Add your first church',
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
          onTap: () => _showChurchDetails(church),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
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
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _getDistrictName(church.districtId),
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.people, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${church.memberCount ?? 0}',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      if (church.address != null &&
                          church.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                church.address!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
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
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
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
                    color: Colors.grey[600],
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
    ChurchStatus selectedStatus = church?.status ?? ChurchStatus.organizedChurch;

    // Prepare local selectable options based on current selections
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    final bool isSuperAdmin = currentUser?.userRole == UserRole.superAdmin;

    List<Region> modalRegions = _regions
        .where((r) =>
            selectedMissionId == null || r.missionId == selectedMissionId)
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
          decoration: const BoxDecoration(
            color: Colors.white,
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
                  color: Colors.grey[300],
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
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
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
                            value: selectedStatus,
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
                              value: selectedMissionId,
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
                            value: selectedRegionId,
                            decoration: const InputDecoration(
                              labelText: 'Region',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: modalRegions
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
                            value: selectedDistrictId,
                            decoration: const InputDecoration(
                              labelText: 'District',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items: modalDistricts
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
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
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
}
