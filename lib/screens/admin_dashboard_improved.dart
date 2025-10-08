import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/services/department_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/screens/admin/church_management_screen.dart';
import 'package:pastor_report/screens/admin/financial_reports_screen.dart';
import 'package:pastor_report/screens/mission_management_screen.dart';
import 'package:pastor_report/screens/region_management_screen.dart';
import 'package:pastor_report/screens/district_management_screen.dart';
import 'package:pastor_report/screens/department_management_screen.dart';
import 'package:pastor_report/screens/user_management_screen.dart';
import 'package:pastor_report/screens/staff_management_screen.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/models/mission_model.dart';

class ImprovedAdminDashboard extends StatefulWidget {
  const ImprovedAdminDashboard({super.key});

  @override
  State<ImprovedAdminDashboard> createState() => _ImprovedAdminDashboardState();
}

class _ImprovedAdminDashboardState extends State<ImprovedAdminDashboard> {
  final UserManagementService _userService = UserManagementService();
  final DepartmentService _departmentService = DepartmentService();
  final ChurchService _churchService = ChurchService();
  final DistrictService _districtService = DistrictService.instance;
  final RegionService _regionService = RegionService.instance;

  int _totalUsers = 0;
  int _totalDepartments = 0;
  int _totalChurches = 0;
  int _totalDistricts = 0;
  int _totalRegions = 0;
  bool _isLoading = true;

  // Static flag to prevent duplicate church data loading across screens
  static bool _churchDataLoaded = false;
  static DateTime? _lastChurchDataLoad;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadUserStats(),
        _loadDepartmentStats(),
        _loadChurchStats(),
        _loadDistrictStats(),
        _loadRegionStats(),
      ]);
    } catch (e) {
      debugPrint('Error loading admin dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final users = await _userService.getUsers();
      _totalUsers = users.length;
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _loadDepartmentStats() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userMission = authProvider.user?.mission;

      final departments =
          await _departmentService.getDepartments(mission: userMission);
      _totalDepartments = departments.length;
      debugPrint(
          '📊 Loaded ${departments.length} departments for mission: $userMission');
    } catch (e) {
      debugPrint('Error loading department stats: $e');
    }
  }

  Future<void> _loadChurchStats() async {
    // Check if church data was loaded recently (within last 30 seconds) to prevent duplicate loading
    if (_churchDataLoaded && _lastChurchDataLoad != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastChurchDataLoad!);
      if (timeSinceLastLoad.inSeconds < 30) {
        debugPrint(
            '📊 Skipping church stats load - data loaded recently (${timeSinceLastLoad.inSeconds}s ago)');
        return;
      }
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final userMission = user?.mission;

      if (userMission != null && userMission.isNotEmpty) {
        // For district pastors, count all churches in their mission
        if (user?.userRole == UserRole.districtPastor) {
          final churches =
              await _churchService.getChurchesByMission(userMission);
          _totalChurches = churches.length;
          debugPrint(
              '📊 Loaded ${churches.length} churches for district pastor in mission: $userMission');
        } else {
          // Get churches for the specific mission by getting all districts first
          final districts =
              await _districtService.getDistrictsByMission(userMission);
          int totalChurches = 0;
          for (var district in districts) {
            final churches =
                await _churchService.getChurchesByDistrict(district.id);
            totalChurches += churches.length;
          }
          _totalChurches = totalChurches;
          debugPrint(
              '📊 Loaded $totalChurches churches for mission: $userMission');
        }

        // Mark data as loaded
        _churchDataLoaded = true;
        _lastChurchDataLoad = DateTime.now();
      } else {
        // Super admin - get all churches
        final churches = await _churchService.getAllChurches();
        _totalChurches = churches.length;
        debugPrint('📊 Loaded ${churches.length} churches (all missions)');

        // Mark data as loaded
        _churchDataLoaded = true;
        _lastChurchDataLoad = DateTime.now();
      }
    } catch (e) {
      debugPrint('Error loading church stats: $e');
    }
  }

  Future<void> _loadDistrictStats() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final userMission = user?.mission;

      if (userMission != null && userMission.isNotEmpty) {
        // For district pastors, count all districts in their mission
        if (user?.userRole == UserRole.districtPastor) {
          final districts =
              await _districtService.getDistrictsByMission(userMission);
          _totalDistricts = districts.length;
          debugPrint(
              '📊 District pastor sees ${districts.length} districts in mission: $userMission');
        } else {
          // Get districts for the specific mission
          final districts =
              await _districtService.getDistrictsByMission(userMission);
          _totalDistricts = districts.length;
          debugPrint(
              '📊 Loaded ${districts.length} districts for mission: $userMission');
        }
      } else {
        // Super admin - get all districts
        final districts = await _districtService.getAllDistricts();
        _totalDistricts = districts.length;
        debugPrint('📊 Loaded ${districts.length} districts (all missions)');
      }
    } catch (e) {
      debugPrint('Error loading district stats: $e');
    }
  }

  Future<void> _loadRegionStats() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      final userMission = user?.mission;

      if (userMission != null && userMission.isNotEmpty) {
        // For district pastors, count all regions in their mission
        if (user?.userRole == UserRole.districtPastor) {
          final regions = await _regionService.getRegionsByMission(userMission);
          _totalRegions = regions.length;
          debugPrint(
              '📊 District pastor sees ${regions.length} regions in mission: $userMission');
        } else {
          // Get regions for the specific mission
          final regions = await _regionService.getRegionsByMission(userMission);
          _totalRegions = regions.length;
          debugPrint(
              '📊 Loaded ${regions.length} regions for mission: $userMission');
        }
      } else {
        // Super admin - get all regions
        final regions = await _regionService.getAllRegions();
        _totalRegions = regions.length;
        debugPrint('📊 Loaded ${regions.length} regions (all missions)');
      }
    } catch (e) {
      debugPrint('Error loading region stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(user),
            _buildQuickStats(),
            _buildManagementGrid(),
            _buildRecentActivitySection(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: _buildQuickActionFAB(),
    );
  }

  Widget _buildModernAppBar(UserModel? user) {
    return SliverAppBar(
      expandedHeight: 200,
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
                          Icons.admin_panel_settings,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Dashboard',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Welcome back, ${user?.displayName ?? 'Admin'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
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
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadDashboardData,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.pushNamed(context, AppConstants.routeSettings);
          },
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'System Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    'Total Users',
                    _totalUsers.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Departments',
                    _totalDepartments.toString(),
                    Icons.dashboard,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Regions',
                    _totalRegions.toString(),
                    Icons.map,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    'Districts',
                    _totalDistricts.toString(),
                    Icons.location_city,
                    Colors.indigo,
                  ),
                  _buildStatCard(
                    'Churches',
                    _totalChurches.toString(),
                    Icons.church,
                    Colors.orange,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Get the visible management tools based on user role
  List<Widget> _getManagementTools(UserModel? user) {
    if (user == null) return [];

    final List<Widget> tools = [];

    // User Management - Only Admin and SuperAdmin
    if (user.canManageUsers()) {
      tools.add(_buildManagementCard(
        'User Management',
        'Manage accounts',
        Icons.people,
        Colors.blue,
        () => _navigateToUserManagement(),
      ));
    }

    // Missions - Only Admin and SuperAdmin
    if (user.canManageMissions()) {
      tools.add(_buildManagementCard(
        'Missions',
        'Configure missions',
        Icons.public,
        Colors.green,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MissionManagementScreen(),
          ),
        ),
      ));
    }

    // Churches - Admin, SuperAdmin, MissionAdmin, DistrictPastor
    if (user.canManageMissions() ||
        user.userRole == UserRole.missionAdmin ||
        user.userRole == UserRole.districtPastor) {
      tools.add(_buildManagementCard(
        'Churches',
        'Church data',
        Icons.church,
        Colors.orange,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChurchManagementScreen(),
          ),
        ),
      ));
    }

    // Regions - Admin, SuperAdmin, MissionAdmin
    if (user.canManageMissions() || user.userRole == UserRole.missionAdmin) {
      tools.add(_buildManagementCard(
        'Regions',
        'Regional structure',
        Icons.map,
        Colors.purple,
        () => _navigateToRegionManagement(user),
      ));
    } // Staff Management - Admin, SuperAdmin, MissionAdmin, DistrictPastor
    if (user.canManageMissions() ||
        user.userRole == UserRole.missionAdmin ||
        user.userRole == UserRole.districtPastor) {
      tools.add(_buildManagementCard(
        'Staff Management',
        'Manage staff by mission',
        Icons.people_outline,
        Colors.amber,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StaffManagementScreen(),
          ),
        ),
      ));
    }

    // Districts - Admin, SuperAdmin, MissionAdmin, DistrictPastor
    if (user.canManageMissions() ||
        user.userRole == UserRole.missionAdmin ||
        user.userRole == UserRole.districtPastor) {
      tools.add(_buildManagementCard(
        'Districts',
        'District management',
        Icons.location_city,
        Colors.indigo,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DistrictManagementScreen(),
          ),
        ),
      ));
    }

    // Departments - Admin, SuperAdmin, MissionAdmin, Editor
    if (user.canEditDepartmentUrls()) {
      tools.add(_buildManagementCard(
        'Departments',
        'Department setup',
        Icons.dashboard,
        Colors.teal,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DepartmentManagementScreen(),
          ),
        ),
      ));
    }

    // Financial Reports - Admin, SuperAdmin, ChurchTreasurer
    if (user.canManageMissions() || user.userRole == UserRole.churchTreasurer) {
      tools.add(_buildManagementCard(
        'Financial Reports',
        'View analytics',
        Icons.assessment,
        Colors.red,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FinancialReportsScreen(),
          ),
        ),
      ));
    }

    return tools;
  }

  Widget _buildManagementGrid() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final managementTools = _getManagementTools(user);

    if (managementTools.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Management Tools',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: managementTools,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admin_activity')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildActivitySkeleton();
                }
                if (snapshot.hasError) {
                  return Text('Error loading activity: ${snapshot.error}');
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
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
                    child: Row(
                      children: [
                        Icon(Icons.inbox, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text(
                          'No recent activity',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
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
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final title = data['title'] as String? ?? 'Activity';
                      final subtitle = data['subtitle'] as String? ?? '';
                      final type = data['type'] as String? ?? 'info';
                      final ts = data['createdAt'];
                      DateTime? createdAt;
                      if (ts is Timestamp) createdAt = ts.toDate();
                      if (ts is String) createdAt = DateTime.tryParse(ts);

                      final iconColor = _activityColor(type);
                      final iconData = _activityIcon(type);
                      final timeText =
                          createdAt != null ? _timeAgo(createdAt) : '';

                      return _buildActivityItem(
                        title,
                        subtitle,
                        iconData,
                        iconColor,
                        timeText,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }

  Color _activityColor(String type) {
    switch (type.toLowerCase()) {
      case 'user':
      case 'success':
        return Colors.green;
      case 'department':
      case 'info':
        return Colors.blue;
      case 'church':
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _activityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'user':
        return Icons.person_add;
      case 'department':
        return Icons.add_circle;
      case 'church':
        return Icons.church;
      case 'warning':
        return Icons.warning_amber;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildActivitySkeleton() {
    return Container(
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
        children: List.generate(3, (i) => i)
            .map((_) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.black12, radius: 14),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonLine(widthFactor: 0.5),
                            SizedBox(height: 6),
                            _SkeletonLine(widthFactor: 0.8),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      _SkeletonLine(width: 40),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // Simple skeleton line widget lives below as a separate class

  Widget _buildActivityItem(
      String title, String subtitle, IconData icon, Color color, String time) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionFAB() {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      onPressed: () => _showQuickActionsBottomSheet(),
      icon: const Icon(Icons.add_circle_outline),
      label: const Text('Quick Actions'),
      elevation: 4,
    );
  }

  void _showQuickActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildQuickActionButton('Add User', Icons.person_add,
                    Colors.blue, () => _navigateToUserManagement()),
                _buildQuickActionButton(
                    'Add Church',
                    Icons.church,
                    Colors.orange,
                    () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ChurchManagementScreen(),
                          ),
                        )),
                _buildQuickActionButton(
                    'Missions',
                    Icons.public,
                    Colors.purple,
                    () => Navigator.pushNamed(
                          context,
                          AppConstants.routeMissionManagement,
                        )),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToUserManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserManagementScreen(),
      ),
    );
  }

  void _navigateToRegionManagement(UserModel user) {
    // For mission admin, use their assigned mission
    if (user.userRole == UserRole.missionAdmin && user.mission != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegionManagementScreen(
            missionId: user.mission!,
            missionName: user.mission!, // TODO: Could get actual mission name
          ),
        ),
      );
      return;
    }

    // For super admin and admin, show mission selection
    _showMissionSelectionDialog();
  }

  void _showMissionSelectionDialog() async {
    try {
      final missions = await MissionService.instance.getAllMissions();

      if (!mounted) return;

      if (missions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No missions found. Please create a mission first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final selectedMission = await showModalBottomSheet<Mission>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Mission',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a mission to manage its regions',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Mission list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: missions.length,
                  itemBuilder: (context, index) {
                    final mission = missions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Icon(Icons.public, color: Colors.green[700]),
                      ),
                      title: Text(mission.name),
                      subtitle: Text('ID: ${mission.id}'),
                      onTap: () => Navigator.pop(context, mission),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );

      if (selectedMission != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegionManagementScreen(
              missionId: selectedMission.id,
              missionName: selectedMission.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading missions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SkeletonLine extends StatelessWidget {
  final double? width;
  final double widthFactor;
  const _SkeletonLine({this.width, this.widthFactor = 1});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: width != null ? null : widthFactor,
      child: Container(
        width: width,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
