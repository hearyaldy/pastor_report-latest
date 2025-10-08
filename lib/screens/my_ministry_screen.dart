import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/staff_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/church_storage_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/utils/constants.dart';

class MyMinistryScreen extends StatefulWidget {
  const MyMinistryScreen({super.key});

  @override
  State<MyMinistryScreen> createState() => _MyMinistryScreenState();
}

class _MyMinistryScreenState extends State<MyMinistryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Church> _churches = [];
  List<Mission> _missions = [];
  bool _isLoading = false;
  bool _isStatsExpanded = false;
  bool _isStaffStatsExpanded = false;
  final TextEditingController _staffSearchController = TextEditingController();
  final TextEditingController _churchSearchController = TextEditingController();
  String _staffSearchQuery = '';
  String _churchSearchQuery = '';
  String _churchSortBy = 'name'; // name, elder, status, members
  String _staffSortBy = 'name'; // name, role, mission

  // Maps to store region and district names
  final Map<String, String> _regionNames = {};
  final Map<String, String> _districtNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB when tab changes
    });
    _loadRegionAndDistrictNames();
    _loadMissions();
    _loadData();
  }

  Future<void> _loadRegionAndDistrictNames() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Only load the regions and districts that the user actually needs
      final Map<String, String> regionNames = {};
      final Map<String, String> districtNames = {};

      // Load user's region if they have one
      if (user?.region != null && user!.region!.isNotEmpty) {
        try {
          final region =
              await RegionService.instance.getRegionById(user.region!);
          if (region != null) {
            regionNames[region.id] = region.name;
          }
        } catch (e) {
          print('Error loading user region: $e');
        }
      }

      // Load user's district if they have one
      if (user?.district != null && user!.district!.isNotEmpty) {
        try {
          final district =
              await DistrictService.instance.getDistrictById(user.district!);
          if (district != null) {
            districtNames[district.id] = district.name;
          }
        } catch (e) {
          print('Error loading user district: $e');
        }
      }

      // For super admin, load a few more for reference, but still not all
      if (user?.userRole == UserRole.superAdmin && user?.mission != null) {
        try {
          final regions =
              await RegionService.instance.getRegionsByMission(user!.mission!);
          for (var region in regions) {
            regionNames[region.id] = region.name;
          }

          final districts = await DistrictService.instance
              .getDistrictsByMission(user.mission!);
          for (var district in districts) {
            districtNames[district.id] = district.name;
          }
        } catch (e) {
          print('Error loading mission regions/districts for super admin: $e');
        }
      }

      if (mounted) {
        setState(() {
          _regionNames.addAll(regionNames);
          _districtNames.addAll(districtNames);
        });
      }
    } catch (e) {
      print('Error loading region and district names: $e');
    }
  }

  Future<void> _loadMissions() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      // Only load all missions for super admin, otherwise just load user's mission
      if (user?.userRole == UserRole.superAdmin) {
        final missions = await MissionService.instance.getAllMissions();
        if (mounted) {
          setState(() {
            _missions = missions;
          });
        }
      } else if (user?.mission != null && user!.mission!.isNotEmpty) {
        // For regular users, only load their specific mission
        try {
          final userMission =
              await MissionService.instance.getMissionByID(user.mission!);
          if (userMission != null && mounted) {
            setState(() {
              _missions = [userMission]; // Store as list for compatibility
            });
          }
        } catch (e) {
          print('Error loading user mission: $e');
          // Continue without mission data
        }
      }
    } catch (e) {
      print('Error loading missions: $e');
    }
  }

  String _getRegionName(String? regionId) {
    if (regionId == null || regionId.isEmpty) {
      return 'Not assigned';
    }
    return _regionNames[regionId] ?? regionId;
  }

  String _getDistrictName(String? districtId) {
    if (districtId == null || districtId.isEmpty) {
      return 'Not assigned';
    }
    return _districtNames[districtId] ?? districtId;
  }

  String _getMissionName(String? missionId) {
    if (missionId == null || missionId.isEmpty) {
      return 'Not assigned';
    }
    // Try to find mission name from loaded missions
    final mission = _missions.firstWhere(
      (m) => m.id == missionId,
      orElse: () => Mission(
        id: missionId,
        name: missionId,
      ),
    );
    return mission.name;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _staffSearchController.dispose();
    _churchSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userModel = authProvider.user;
      final userId = userModel?.uid ?? '';

      List<Church> churches = [];

      if (userModel != null) {
        print('MyMinistryScreen: Loading data for user: ${userModel.uid}');
        print('MyMinistryScreen: User district: ${userModel.district}');
        print('MyMinistryScreen: User region: ${userModel.region}');
        print('MyMinistryScreen: User mission: ${userModel.mission}');
        print('MyMinistryScreen: User role: ${userModel.userRole}');

        // Priority: District > Region > Mission > User-created
        // This ensures users see churches under their assigned district

        // If user has a district assigned, show churches under that district
        if (userModel.district != null && userModel.district!.isNotEmpty) {
          try {
            print(
                'MyMinistryScreen: Loading churches by district: ${userModel.district}');
            churches = await ChurchService.instance
                .getChurchesByDistrict(userModel.district!);
            print(
                'MyMinistryScreen: Found ${churches.length} churches by district');

            // Debug: If no churches found, this is expected if no churches exist in this district
            if (churches.isEmpty) {
              print(
                  'MyMinistryScreen: No churches found for district ${userModel.district}, this is expected if no churches exist in this district');

              // Fallback: Also show churches created by this user
              print(
                  'MyMinistryScreen: Falling back to user-created churches for userId: $userId');
              try {
                final userChurches =
                    await ChurchService.instance.getUserChurches(userId);
                print(
                    'MyMinistryScreen: Found ${userChurches.length} user-created churches');
                churches.addAll(userChurches);
              } catch (e) {
                print('Error loading user churches as fallback: $e');
              }
            }
          } catch (e) {
            print('Error loading churches by district: $e');
            churches = [];
          }
        }
        // If user has a region assigned but no district, show churches under that region
        else if (userModel.region != null && userModel.region!.isNotEmpty) {
          try {
            print(
                'MyMinistryScreen: Loading churches by region: ${userModel.region}');
            churches = await ChurchService.instance
                .getChurchesByRegion(userModel.region!);
            print(
                'MyMinistryScreen: Found ${churches.length} churches by region');
          } catch (e) {
            print('Error loading churches by region: $e');
            churches = [];
          }
        }
        // Super admin can view churches by their assigned mission or all churches
        else if (userModel.userRole == UserRole.superAdmin) {
          try {
            print('MyMinistryScreen: Loading churches for super admin');
            // Use the user's assigned mission if available
            if (userModel.mission != null && userModel.mission!.isNotEmpty) {
              churches = await ChurchService.instance
                  .getChurchesByMission(userModel.mission!);
            } else {
              // Default to first mission or get all churches
              if (_missions.isNotEmpty) {
                churches = await ChurchService.instance
                    .getChurchesByMission(_missions[0].id);
              } else {
                // Get all churches if no missions are available
                churches = await ChurchService.instance.getAllChurches();
              }
            }
            print(
                'MyMinistryScreen: Found ${churches.length} churches for super admin');
          } catch (e) {
            print('Error loading churches by mission: $e');
            churches = [];
          }
        }
        // Regular pastor - get only churches they created
        else if (userId.isNotEmpty) {
          try {
            print(
                'MyMinistryScreen: Loading user churches for userId: $userId');
            // Try Firebase first
            churches = await ChurchService.instance.getUserChurches(userId);
            print('MyMinistryScreen: Found ${churches.length} user churches');
          } catch (e) {
            print('Error loading churches from Firebase: $e');
            // Fall back to local storage
            churches =
                await ChurchStorageService.instance.getUserChurches(userId);
          }
        }

        print('MyMinistryScreen: Final church count: ${churches.length}');

        if (mounted) {
          setState(() {
            _churches = churches;
          });
        }
      }
    } catch (e) {
      print('Error in _loadData: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Note: Add/Edit Church and Add Staff actions were removed to keep this page read-only.

  void _editStaff(Staff staff, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => _StaffForm(
        staff: staff,
        userMission: user.mission ?? '',
        userId: user.uid,
        onSave: (updatedStaff) async {
          await StaffService.instance.updateStaff(updatedStaff);
        },
      ),
    );
  }

  void _deleteStaff(Staff staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete ${staff.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StaffService.instance.deleteStaff(staff.id);
    }
  }

  // Note: Delete Church action removed; churches are managed via Admin Dashboard.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Ministry'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        // Use a simpler bottom with just the tab bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryLight,
                  AppColors.primaryLight.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                // Clean tab bar for navigation
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  indicator: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.church, size: 24),
                      text: 'My Churches',
                    ),
                    Tab(
                      icon: Icon(Icons.people, size: 24),
                      text: 'Staff Directory',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChurchesTab(),
                _buildTeamTab(),
              ],
            ),
    );
  }

  Widget _buildChurchesTab() {
    if (_churches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.church, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No churches added yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            // Removed add action; data is managed via Admin Dashboard
          ],
        ),
      );
    }

    // Apply search filter
    var filteredChurches = _churches;
    if (_churchSearchQuery.isNotEmpty) {
      filteredChurches = _churches
          .where((c) =>
              c.churchName
                  .toLowerCase()
                  .contains(_churchSearchQuery.toLowerCase()) ||
              c.elderName
                  .toLowerCase()
                  .contains(_churchSearchQuery.toLowerCase()) ||
              c.status.displayName
                  .toLowerCase()
                  .contains(_churchSearchQuery.toLowerCase()) ||
              (c.address
                      ?.toLowerCase()
                      .contains(_churchSearchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    // Apply sorting
    filteredChurches.sort((a, b) {
      switch (_churchSortBy) {
        case 'name':
          return a.churchName
              .toLowerCase()
              .compareTo(b.churchName.toLowerCase());
        case 'elder':
          return a.elderName.toLowerCase().compareTo(b.elderName.toLowerCase());
        case 'status':
          return a.status.displayName.compareTo(b.status.displayName);
        case 'members':
          return (b.memberCount ?? 0).compareTo(a.memberCount ?? 0);
        default:
          return 0;
      }
    });

    // Calculate statistics
    final totalChurches = _churches.length;
    final churches =
        _churches.where((c) => c.status == ChurchStatus.organizedChurch).length;
    final companies =
        _churches.where((c) => c.status == ChurchStatus.company).length;
    final branches =
        _churches.where((c) => c.status == ChurchStatus.group).length;
    final totalMembers = _churches
        .where((c) => c.memberCount != null)
        .fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0));

    // Get current pastor's region and district info
    final authProvider = Provider.of<AuthProvider>(context);
    final pastorUser = authProvider.user;
    final String pastorRegionName =
        pastorUser?.region != null && pastorUser!.region!.isNotEmpty
            ? _getRegionName(pastorUser.region)
            : 'Not assigned';
    final String pastorDistrictName =
        pastorUser?.district != null && pastorUser!.district!.isNotEmpty
            ? _getDistrictName(pastorUser.district)
            : 'Not assigned';

    // Use constraints to center the content with max width
    return LayoutBuilder(
      builder: (context, constraints) {
        // Center the content with a maximum width
        final contentWidth =
            constraints.maxWidth > 800 ? 800.0 : constraints.maxWidth;
        return Container(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                // Search Bar with Sort
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _churchSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search churches...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _churchSearchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _churchSearchController.clear();
                                      setState(() => _churchSearchQuery = '');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                          onChanged: (value) {
                            if (value != _churchSearchQuery) {
                              setState(() => _churchSearchQuery = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sort),
                        ),
                        tooltip: 'Sort by',
                        onSelected: (value) =>
                            setState(() => _churchSortBy = value),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'name',
                            child: Row(
                              children: [
                                Icon(Icons.church,
                                    size: 20,
                                    color: _churchSortBy == 'name'
                                        ? AppColors.primaryLight
                                        : Colors.grey),
                                const SizedBox(width: 8),
                                Text('Church Name',
                                    style: TextStyle(
                                        fontWeight: _churchSortBy == 'name'
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'elder',
                            child: Row(
                              children: [
                                Icon(Icons.person,
                                    size: 20,
                                    color: _churchSortBy == 'elder'
                                        ? AppColors.primaryLight
                                        : Colors.grey),
                                const SizedBox(width: 8),
                                Text('Elder Name',
                                    style: TextStyle(
                                        fontWeight: _churchSortBy == 'elder'
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'members',
                            child: Row(
                              children: [
                                Icon(Icons.people,
                                    size: 20,
                                    color: _churchSortBy == 'members'
                                        ? AppColors.primaryLight
                                        : Colors.grey),
                                const SizedBox(width: 8),
                                Text('Members',
                                    style: TextStyle(
                                        fontWeight: _churchSortBy == 'members'
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Collapsible Statistics Section
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isStatsExpanded = !_isStatsExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryLight.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.analytics,
                              color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Church Statistics',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _isStatsExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppColors.primaryLight,
                        ),
                      ],
                    ),
                  ),
                ),

                // Expandable Statistics Content
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isStatsExpanded ? null : 0,
                  curve: Curves.easeInOut,
                  child: _isStatsExpanded
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            children: [
                              // Statistics Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildCompactStatCard(
                                      icon: Icons.church,
                                      label: 'Total',
                                      value: '$totalChurches',
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildCompactStatCard(
                                      icon: Icons.check_circle,
                                      label: 'Church',
                                      value: '$churches',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildCompactStatCard(
                                      icon: Icons.groups,
                                      label: 'Company',
                                      value: '$companies',
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildCompactStatCard(
                                      icon: Icons.location_on,
                                      label: 'Branch',
                                      value: '$branches',
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),

                              // Pastor's Region & District Info
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.withValues(alpha: 0.15),
                                      Colors.blue.withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue
                                                .withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person,
                                              color: Colors.blue, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Your Ministry Assignment',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.map,
                                            size: 18, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Region: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            pastorRegionName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_city,
                                            size: 18, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'District: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            pastorDistrictName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Total Members Section (conditional)
                              if (totalMembers > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryLight
                                            .withValues(alpha: 0.15),
                                        AppColors.primaryLight
                                            .withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primaryLight
                                          .withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.people,
                                            color: AppColors.primaryLight,
                                            size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Total Members: ',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        '$totalMembers',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),

                // Results count
                if (_churchSearchQuery.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Found ${filteredChurches.length} of $totalChurches churches',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // Church List
                Expanded(
                  child: filteredChurches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No churches found matching "$_churchSearchQuery"',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filteredChurches.length,
                          itemBuilder: (context, index) {
                            final church = filteredChurches[index];
                            return InkWell(
                              onTap: () => _showChurchDetails(church),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primaryLight
                                        .withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryLight
                                          .withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                _getStatusColor(church.status),
                                            child: const Icon(
                                              Icons.church,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  church.churchName,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  church.status.displayName,
                                                  style: TextStyle(
                                                    color: _getStatusColor(
                                                        church.status),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right,
                                              color: Colors.grey),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Elder info
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const Icon(Icons.person,
                                                    size: 16,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Elder: ${church.elderName}',
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Member count
                                          if (church.memberCount != null)
                                            Row(
                                              children: [
                                                const Icon(Icons.people,
                                                    size: 16,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${church.memberCount} members',
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Location information - compact version
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 16, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${_getRegionName(church.regionId)}, ${_getDistrictName(church.districtId)}',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(Icons.touch_app,
                                              size: 14, color: Colors.grey),
                                          const Text(' Tap for details',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamTab() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isMissionAdmin = user?.userRole == UserRole.missionAdmin ||
        user?.userRole == UserRole.admin ||
        user?.userRole == UserRole.superAdmin;

    return StreamBuilder<List<Staff>>(
      stream: _getStaffStream(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_alt, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No staff members found',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Staff from your mission will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        var staffList = snapshot.data!;

        // Apply search filter
        var filteredStaff = staffList;
        if (_staffSearchQuery.isNotEmpty) {
          filteredStaff = staffList
              .where((s) =>
                  s.name
                      .toLowerCase()
                      .contains(_staffSearchQuery.toLowerCase()) ||
                  s.role
                      .toLowerCase()
                      .contains(_staffSearchQuery.toLowerCase()) ||
                  s.mission
                      .toLowerCase()
                      .contains(_staffSearchQuery.toLowerCase()) ||
                  (s.department
                          ?.toLowerCase()
                          .contains(_staffSearchQuery.toLowerCase()) ??
                      false))
              .toList();
        }

        // Apply sorting
        filteredStaff.sort((a, b) {
          switch (_staffSortBy) {
            case 'name':
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            case 'role':
              return a.role.toLowerCase().compareTo(b.role.toLowerCase());
            case 'mission':
              return a.mission.toLowerCase().compareTo(b.mission.toLowerCase());
            default:
              return 0;
          }
        });

        // Calculate statistics
        final totalStaff = staffList.length;
        final missions = staffList.map((s) => s.mission).toSet();
        final roles = staffList.map((s) => s.role).toSet();

        // Use constraints to center the content with max width
        return LayoutBuilder(
          builder: (context, constraints) {
            // Center the content with a maximum width
            final contentWidth =
                constraints.maxWidth > 800 ? 800.0 : constraints.maxWidth;
            return Container(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    // Search Bar with Sort
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _staffSearchController,
                              decoration: InputDecoration(
                                hintText: 'Search staff...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _staffSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _staffSearchController.clear();
                                          setState(
                                              () => _staffSearchQuery = '');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              onChanged: (value) {
                                if (value != _staffSearchQuery) {
                                  setState(() => _staffSearchQuery = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.sort),
                            ),
                            tooltip: 'Sort by',
                            onSelected: (value) =>
                                setState(() => _staffSortBy = value),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'name',
                                child: Row(
                                  children: [
                                    Icon(Icons.person,
                                        size: 20,
                                        color: _staffSortBy == 'name'
                                            ? AppColors.primaryLight
                                            : Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('Name',
                                        style: TextStyle(
                                            fontWeight: _staffSortBy == 'name'
                                                ? FontWeight.bold
                                                : FontWeight.normal)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'role',
                                child: Row(
                                  children: [
                                    Icon(Icons.work,
                                        size: 20,
                                        color: _staffSortBy == 'role'
                                            ? AppColors.primaryLight
                                            : Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('Role',
                                        style: TextStyle(
                                            fontWeight: _staffSortBy == 'role'
                                                ? FontWeight.bold
                                                : FontWeight.normal)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'mission',
                                child: Row(
                                  children: [
                                    Icon(Icons.church,
                                        size: 20,
                                        color: _staffSortBy == 'mission'
                                            ? AppColors.primaryLight
                                            : Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('Mission',
                                        style: TextStyle(
                                            fontWeight:
                                                _staffSortBy == 'mission'
                                                    ? FontWeight.bold
                                                    : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Collapsible Statistics Section
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isStaffStatsExpanded = !_isStaffStatsExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.people,
                                  color: AppColors.primaryLight),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Staff Statistics',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _isStaffStatsExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.primaryLight,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Statistics Content
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _isStaffStatsExpanded ? null : 0,
                      curve: Curves.easeInOut,
                      child: _isStaffStatsExpanded
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildCompactStatCard(
                                      icon: Icons.people,
                                      label: 'Staff',
                                      value: '$totalStaff',
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildCompactStatCard(
                                      icon: Icons.church,
                                      label: 'Missions',
                                      value: '${missions.length}',
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _buildCompactStatCard(
                                      icon: Icons.work,
                                      label: 'Roles',
                                      value: '${roles.length}',
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),

                    // Results count
                    if (_staffSearchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'Found ${filteredStaff.length} of $totalStaff staff members',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Staff List
                    Expanded(
                      child: filteredStaff.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 60, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No staff found matching "$_staffSearchQuery"',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: filteredStaff.length,
                              itemBuilder: (context, index) {
                                final staff = filteredStaff[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.primaryLight
                                          .withValues(alpha: 0.25),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryLight
                                            .withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primaryLight,
                                      child: Text(
                                        staff.name
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      staff.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(staff.role),
                                        Text(
                                          _getMissionName(staff.mission),
                                          style: TextStyle(
                                            color: AppColors.primaryLight,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isMissionAdmin) ...[
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _editStaff(staff, user!),
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteStaff(staff),
                                            tooltip: 'Delete',
                                          ),
                                        ] else ...[
                                          IconButton(
                                            icon: const Icon(Icons.phone,
                                                color: Colors.green),
                                            onPressed: () =>
                                                _makePhoneCall(staff.phone),
                                            tooltip: 'Call',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.email,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _sendEmail(staff.email),
                                            tooltip: 'Email',
                                          ),
                                        ],
                                      ],
                                    ),
                                    onTap: () => _showStaffDetails(staff),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // We're not using the mission selector anymore, but we still load missions for data purposes

  Stream<List<Staff>> _getStaffStream(UserModel? user) {
    if (user == null) return Stream.value([]);

    // SuperAdmin and Admin see all staff
    if (user.userRole == UserRole.superAdmin ||
        user.userRole == UserRole.admin) {
      return StaffService.instance.streamAllStaff();
    }

    // District Pastor sees all staff from their mission
    if (user.userRole == UserRole.districtPastor &&
        user.mission != null &&
        user.mission!.isNotEmpty) {
      return StaffService.instance.streamStaffByMission(user.mission!);
    }

    // Regular users see staff from their district only (more restrictive than mission)
    if (user.district != null && user.district!.isNotEmpty) {
      return StaffService.instance.streamStaffByDistrict(user.district!);
    }

    // Fallback: see staff from their mission if no district assigned
    if (user.mission != null && user.mission!.isNotEmpty) {
      return StaffService.instance.streamStaffByMission(user.mission!);
    }

    return Stream.value([]);
  }

  void _showStaffDetails(Staff staff) async {
    // Fetch district and region names if IDs are present
    String? districtName;
    String? regionName;

    if (staff.district != null) {
      try {
        final district =
            await DistrictService.instance.getDistrictById(staff.district!);
        districtName = district?.name ?? staff.district;
      } catch (e) {
        districtName = staff.district;
      }
    }

    if (staff.region != null) {
      try {
        final region =
            await RegionService.instance.getRegionById(staff.region!);
        regionName = region?.name ?? staff.region;
      } catch (e) {
        regionName = staff.region;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  staff.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                staff.name,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                staff.role,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _detailRow(
                  Icons.business, 'Mission', _getMissionName(staff.mission)),
              if (staff.department != null)
                _detailRow(Icons.category, 'Department', staff.department!),
              if (districtName != null)
                _detailRow(Icons.location_on, 'District', districtName),
              if (regionName != null)
                _detailRow(Icons.map, 'Region', regionName),
              _detailRow(Icons.email, 'Email', staff.email),
              _detailRow(Icons.phone, 'Phone', staff.phone),
              if (staff.notes != null && staff.notes!.isNotEmpty)
                _detailRow(Icons.note, 'Notes', staff.notes!),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(staff.phone),
                      icon: const Icon(Icons.phone),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendEmail(staff.email),
                      icon: const Icon(Icons.email),
                      label: const Text('Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                      ),
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

  void _showChurchDetails(Church church) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the sheet to be larger
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          // Use a SingleChildScrollView to make the content scrollable
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  church.churchName,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _detailRow(Icons.category, 'Status', church.status.displayName),
                _detailRow(Icons.person, 'Elder', church.elderName),
                _detailRow(Icons.email, 'Email', church.elderEmail),
                _detailRow(Icons.phone, 'Phone', church.elderPhone),
                if (church.address != null)
                  _detailRow(Icons.location_on, 'Address', church.address!),
                if (church.memberCount != null)
                  _detailRow(
                      Icons.people, 'Members', church.memberCount.toString()),
                if (church.regionId != null && church.regionId!.isNotEmpty)
                  _detailRow(
                      Icons.map, 'Region', _getRegionName(church.regionId)),
                if (church.districtId != null && church.districtId!.isNotEmpty)
                  _detailRow(Icons.location_city, 'District',
                      _getDistrictName(church.districtId)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _makePhoneCall(church.elderPhone),
                        icon: const Icon(Icons.phone),
                        label: const Text('Call Elder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendEmail(church.elderEmail),
                        icon: const Icon(Icons.email),
                        label: const Text('Email Elder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ChurchStatus status) {
    switch (status) {
      case ChurchStatus.organizedChurch:
        return Colors.blue;
      case ChurchStatus.company:
        return Colors.orange;
      case ChurchStatus.group:
        return Colors.green;
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// Staff Form Bottom Sheet
class _StaffForm extends StatefulWidget {
  final Staff? staff;
  final String userMission;
  final String userId;
  final Function(Staff) onSave;

  const _StaffForm({
    this.staff,
    required this.userMission,
    required this.userId,
    required this.onSave,
  });

  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _districtController;
  late TextEditingController _regionController;
  late TextEditingController _notesController;
  late String _selectedMission;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff?.name ?? '');
    _roleController = TextEditingController(text: widget.staff?.role ?? '');
    _emailController = TextEditingController(text: widget.staff?.email ?? '');
    _phoneController = TextEditingController(text: widget.staff?.phone ?? '');
    _departmentController =
        TextEditingController(text: widget.staff?.department ?? '');
    _districtController =
        TextEditingController(text: widget.staff?.district ?? '');
    _regionController = TextEditingController(text: widget.staff?.region ?? '');
    _notesController = TextEditingController(text: widget.staff?.notes ?? '');

    // Initialize mission selection, handling both ID and name formats
    String initialMission = widget.staff?.mission ?? widget.userMission;
    // Check if the initialMission is actually a mission ID
    final matchingMission = AppConstants.missions.firstWhere(
      (m) => m['id'] == initialMission || m['name'] == initialMission,
      orElse: () => AppConstants.missions.isNotEmpty
          ? AppConstants.missions.first
          : {'id': '', 'name': 'Unknown Mission'},
    );
    _selectedMission = matchingMission['name']!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _districtController.dispose();
    _regionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  widget.staff == null
                      ? 'Add Staff Member'
                      : 'Edit Staff Member',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roleController,
                  decoration: const InputDecoration(
                    labelText: 'Role/Position',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedMission,
                  decoration: const InputDecoration(
                    labelText: 'Mission',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.church),
                  ),
                  items: AppConstants.missions
                      .map((m) => DropdownMenuItem(
                          value: m['name'], child: Text(m['name']!)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedMission = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _districtController,
                  decoration: const InputDecoration(
                    labelText: 'District (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _regionController,
                  decoration: const InputDecoration(
                    labelText: 'Region (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              final staff = Staff(
                                id: widget.staff?.id ?? const Uuid().v4(),
                                name: _nameController.text.trim(),
                                role: _roleController.text.trim(),
                                email: _emailController.text.trim(),
                                phone: _phoneController.text.trim(),
                                mission: _selectedMission,
                                department:
                                    _departmentController.text.trim().isEmpty
                                        ? null
                                        : _departmentController.text.trim(),
                                district:
                                    _districtController.text.trim().isEmpty
                                        ? null
                                        : _districtController.text.trim(),
                                region: _regionController.text.trim().isEmpty
                                    ? null
                                    : _regionController.text.trim(),
                                notes: _notesController.text.trim().isEmpty
                                    ? null
                                    : _notesController.text.trim(),
                                createdAt:
                                    widget.staff?.createdAt ?? DateTime.now(),
                                createdBy: widget.userId,
                              );
                              widget.onSave(staff);
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
}
