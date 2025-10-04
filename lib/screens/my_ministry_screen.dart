import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/staff_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/services/church_storage_service.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
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
  bool _isLoading = false;
  final TextEditingController _staffSearchController = TextEditingController();
  final TextEditingController _churchSearchController = TextEditingController();
  String _staffSearchQuery = '';
  String _churchSearchQuery = '';
  String _churchSortBy = 'name'; // name, elder, status, members
  String _staffSortBy = 'name'; // name, role, mission

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB when tab changes
    });
    _loadData();
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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    if (userId.isNotEmpty) {
      final churches =
          await ChurchStorageService.instance.getUserChurches(userId);

      setState(() {
        _churches = churches;
      });
    }

    setState(() => _isLoading = false);
  }

  void _addChurch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => _ChurchForm(
        onSave: (church) async {
          await ChurchStorageService.instance.saveChurch(church);
          _loadData();
        },
      ),
    );
  }

  void _editChurch(Church church) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => _ChurchForm(
        church: church,
        onSave: (updatedChurch) async {
          await ChurchStorageService.instance.saveChurch(updatedChurch);
          _loadData();
        },
      ),
    );
  }

  void _addStaff(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => _StaffForm(
        userMission: user.mission ?? '',
        userId: user.uid,
        onSave: (staff) async {
          await StaffService.instance.addStaff(staff);
        },
      ),
    );
  }

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

  void _deleteChurch(Church church) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Church'),
        content: Text('Are you sure you want to delete ${church.churchName}?'),
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
      await ChurchStorageService.instance.deleteChurch(church.id);
      _loadData();
    }
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ministry'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
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
            child: TabBar(
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
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            ElevatedButton.icon(
              onPressed: _addChurch,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Church'),
            ),
          ],
        ),
      );
    }

    // Apply search filter
    var filteredChurches = _churches;
    if (_churchSearchQuery.isNotEmpty) {
      filteredChurches = _churches
          .where((c) =>
              c.churchName.toLowerCase().contains(_churchSearchQuery.toLowerCase()) ||
              c.elderName.toLowerCase().contains(_churchSearchQuery.toLowerCase()) ||
              c.status.displayName.toLowerCase().contains(_churchSearchQuery.toLowerCase()) ||
              (c.address?.toLowerCase().contains(_churchSearchQuery.toLowerCase()) ?? false))
          .toList();
    }

    // Apply sorting
    filteredChurches.sort((a, b) {
      switch (_churchSortBy) {
        case 'name':
          return a.churchName.toLowerCase().compareTo(b.churchName.toLowerCase());
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
    final churches = _churches.where((c) => c.status == ChurchStatus.church).length;
    final companies = _churches.where((c) => c.status == ChurchStatus.company).length;
    final branches = _churches.where((c) => c.status == ChurchStatus.branch).length;
    final totalMembers = _churches
        .where((c) => c.memberCount != null)
        .fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0));

    return Column(
      children: [
        // Add Church Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addChurch,
              icon: const Icon(Icons.add),
              label: const Text('Add Church'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

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
                    fillColor: Colors.white,
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
                onSelected: (value) => setState(() => _churchSortBy = value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'name',
                    child: Row(
                      children: [
                        Icon(Icons.church, size: 20, color: _churchSortBy == 'name' ? AppColors.primaryLight : Colors.grey),
                        const SizedBox(width: 8),
                        Text('Church Name', style: TextStyle(fontWeight: _churchSortBy == 'name' ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'elder',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 20, color: _churchSortBy == 'elder' ? AppColors.primaryLight : Colors.grey),
                        const SizedBox(width: 8),
                        Text('Elder Name', style: TextStyle(fontWeight: _churchSortBy == 'elder' ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.category, size: 20, color: _churchSortBy == 'status' ? AppColors.primaryLight : Colors.grey),
                        const SizedBox(width: 8),
                        Text('Status', style: TextStyle(fontWeight: _churchSortBy == 'status' ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'members',
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 20, color: _churchSortBy == 'members' ? AppColors.primaryLight : Colors.grey),
                        const SizedBox(width: 8),
                        Text('Members', style: TextStyle(fontWeight: _churchSortBy == 'members' ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Statistics Cards
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
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
              if (totalMembers > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryLight.withValues(alpha: 0.15),
                        AppColors.primaryLight.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.people, color: AppColors.primaryLight, size: 20),
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
            ],
          ),
        ),

        // Results count
        if (_churchSearchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No churches found matching "$_churchSearchQuery"',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredChurches.length,
                  itemBuilder: (context, index) {
                    final church = filteredChurches[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(church.status),
                          child: Icon(
                            Icons.church,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          church.churchName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Elder: ${church.elderName}'),
                            Text(
                              church.status.displayName,
                              style: TextStyle(
                                color: _getStatusColor(church.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'view', child: Text('View Details')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editChurch(church);
                            } else if (value == 'delete') {
                              _deleteChurch(church);
                            } else if (value == 'view') {
                              _showChurchDetails(church);
                            }
                          },
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
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
                  s.name.toLowerCase().contains(_staffSearchQuery.toLowerCase()) ||
                  s.role.toLowerCase().contains(_staffSearchQuery.toLowerCase()) ||
                  s.mission.toLowerCase().contains(_staffSearchQuery.toLowerCase()) ||
                  (s.department?.toLowerCase().contains(_staffSearchQuery.toLowerCase()) ?? false))
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

        return Column(
          children: [
            // Add Staff Button (only for mission admins)
            if (isMissionAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addStaff(user!),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Staff'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

            // Search Bar with Sort
            Padding(
              padding: EdgeInsets.fromLTRB(16, isMissionAdmin ? 0 : 16, 16, 16),
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
                                  setState(() => _staffSearchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                    onSelected: (value) => setState(() => _staffSortBy = value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'name',
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 20, color: _staffSortBy == 'name' ? AppColors.primaryLight : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Name', style: TextStyle(fontWeight: _staffSortBy == 'name' ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'role',
                        child: Row(
                          children: [
                            Icon(Icons.work, size: 20, color: _staffSortBy == 'role' ? AppColors.primaryLight : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Role', style: TextStyle(fontWeight: _staffSortBy == 'role' ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'mission',
                        child: Row(
                          children: [
                            Icon(Icons.church, size: 20, color: _staffSortBy == 'mission' ? AppColors.primaryLight : Colors.grey),
                            const SizedBox(width: 8),
                            Text('Mission', style: TextStyle(fontWeight: _staffSortBy == 'mission' ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Statistics Cards
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ),

            // Results count
            if (_staffSearchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No staff found matching "$_staffSearchQuery"',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredStaff.length,
                      itemBuilder: (context, index) {
                        final staff = filteredStaff[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                staff.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              staff.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(staff.role),
                                Text(
                                  staff.mission,
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
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editStaff(staff, user!),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteStaff(staff),
                                    tooltip: 'Delete',
                                  ),
                                ] else ...[
                                  IconButton(
                                    icon: const Icon(Icons.phone, color: Colors.green),
                                    onPressed: () => _makePhoneCall(staff.phone),
                                    tooltip: 'Call',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.email, color: Colors.blue),
                                    onPressed: () => _sendEmail(staff.email),
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

  Stream<List<Staff>> _getStaffStream(UserModel? user) {
    if (user == null) return Stream.value([]);

    // SuperAdmin and Admin see all staff
    if (user.userRole == UserRole.superAdmin || user.userRole == UserRole.admin) {
      return StaffService.instance.streamAllStaff();
    }

    // Others see staff from their mission only
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
        final district = await DistrictService.instance.getDistrictById(staff.district!);
        districtName = district?.name ?? staff.district;
      } catch (e) {
        districtName = staff.district;
      }
    }

    if (staff.region != null) {
      try {
        final region = await RegionService.instance.getRegionById(staff.region!);
        regionName = region?.name ?? staff.region;
      } catch (e) {
        regionName = staff.region;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
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
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                staff.role,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _detailRow(Icons.business, 'Mission', staff.mission),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.category, 'Status', church.status.displayName),
            _detailRow(Icons.person, 'Elder', church.elderName),
            _detailRow(Icons.email, 'Email', church.elderEmail),
            _detailRow(Icons.phone, 'Phone', church.elderPhone),
            if (church.address != null)
              _detailRow(Icons.location_on, 'Address', church.address!),
            if (church.memberCount != null)
              _detailRow(Icons.people, 'Members', church.memberCount.toString()),
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
      ),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
      case ChurchStatus.church:
        return Colors.blue;
      case ChurchStatus.company:
        return Colors.orange;
      case ChurchStatus.branch:
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

// Church Form Bottom Sheet
class _ChurchForm extends StatefulWidget {
  final Church? church;
  final Function(Church) onSave;

  const _ChurchForm({this.church, required this.onSave});

  @override
  State<_ChurchForm> createState() => _ChurchFormState();
}

class _ChurchFormState extends State<_ChurchForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _churchNameController;
  late TextEditingController _elderNameController;
  late TextEditingController _elderEmailController;
  late TextEditingController _elderPhoneController;
  late TextEditingController _addressController;
  late TextEditingController _memberCountController;
  ChurchStatus _selectedStatus = ChurchStatus.church;
  String? _selectedDistrictId;
  String? _selectedRegionId;
  List<Region> _regions = [];
  List<District> _districts = [];

  @override
  void initState() {
    super.initState();
    _churchNameController =
        TextEditingController(text: widget.church?.churchName ?? '');
    _elderNameController =
        TextEditingController(text: widget.church?.elderName ?? '');
    _elderEmailController =
        TextEditingController(text: widget.church?.elderEmail ?? '');
    _elderPhoneController =
        TextEditingController(text: widget.church?.elderPhone ?? '');
    _addressController =
        TextEditingController(text: widget.church?.address ?? '');
    _memberCountController = TextEditingController(
        text: widget.church?.memberCount?.toString() ?? '');
    _selectedStatus = widget.church?.status ?? ChurchStatus.church;
    _selectedDistrictId = widget.church?.districtId;
    _selectedRegionId = widget.church?.regionId;
    _loadOrganizationalData();
  }

  Future<void> _loadOrganizationalData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final missionId = authProvider.user?.mission;

    if (missionId != null && missionId.isNotEmpty) {
      try {
        final regions = await RegionService.instance.getRegionsByMission(missionId);
        setState(() {
          _regions = regions;
        });

        if (_selectedRegionId != null) {
          final districts = await DistrictService.instance.getDistrictsByRegion(_selectedRegionId!);
          setState(() {
            _districts = districts;
          });
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _loadDistrictsForRegion(String regionId) async {
    try {
      final districts = await DistrictService.instance.getDistrictsByRegion(regionId);
      setState(() {
        _districts = districts;
        _selectedDistrictId = null; // Reset district when region changes
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _churchNameController.dispose();
    _elderNameController.dispose();
    _elderEmailController.dispose();
    _elderPhoneController.dispose();
    _addressController.dispose();
    _memberCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
                  widget.church == null ? 'Add Church' : 'Edit Church',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _churchNameController,
                  decoration: const InputDecoration(
                    labelText: 'Church Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.church),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ChurchStatus>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: ChurchStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Region Dropdown
                if (_regions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedRegionId,
                    decoration: const InputDecoration(
                      labelText: 'Region (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.map),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._regions.map((region) => DropdownMenuItem(
                            value: region.id,
                            child: Text(region.name),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRegionId = value;
                        if (value != null) {
                          _loadDistrictsForRegion(value);
                        } else {
                          _districts = [];
                          _selectedDistrictId = null;
                        }
                      });
                    },
                  ),
                if (_regions.isNotEmpty) const SizedBox(height: 16),
                // District Dropdown
                if (_selectedRegionId != null && _districts.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedDistrictId,
                    decoration: const InputDecoration(
                      labelText: 'District (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._districts.map((district) => DropdownMenuItem(
                            value: district.id,
                            child: Text(district.name),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDistrictId = value);
                    },
                  ),
                if (_selectedRegionId != null && _districts.isNotEmpty)
                  const SizedBox(height: 16),
                TextFormField(
                  controller: _elderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Elder Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _elderEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Elder Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _elderPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Elder Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _memberCountController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Members (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final church = Church(
                          id: widget.church?.id ?? const Uuid().v4(),
                          userId: authProvider.user?.uid ?? '',
                          churchName: _churchNameController.text.trim(),
                          elderName: _elderNameController.text.trim(),
                          status: _selectedStatus,
                          elderEmail: _elderEmailController.text.trim(),
                          elderPhone: _elderPhoneController.text.trim(),
                          address: _addressController.text.trim().isEmpty
                              ? null
                              : _addressController.text.trim(),
                          memberCount: _memberCountController.text.trim().isEmpty
                              ? null
                              : int.tryParse(_memberCountController.text.trim()),
                          createdAt: widget.church?.createdAt ?? DateTime.now(),
                          districtId: _selectedDistrictId,
                          regionId: _selectedRegionId,
                          missionId: authProvider.user?.mission,
                        );
                        widget.onSave(church);
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Church'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
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
      ),
    );
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
    _regionController =
        TextEditingController(text: widget.staff?.region ?? '');
    _notesController = TextEditingController(text: widget.staff?.notes ?? '');
    _selectedMission = widget.staff?.mission ?? widget.userMission;
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
                  widget.staff == null ? 'Add Staff Member' : 'Edit Staff Member',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedMission = value!),
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
                                department: _departmentController.text.trim().isEmpty
                                    ? null
                                    : _departmentController.text.trim(),
                                district: _districtController.text.trim().isEmpty
                                    ? null
                                    : _districtController.text.trim(),
                                region: _regionController.text.trim().isEmpty
                                    ? null
                                    : _regionController.text.trim(),
                                notes: _notesController.text.trim().isEmpty
                                    ? null
                                    : _notesController.text.trim(),
                                createdAt: widget.staff?.createdAt ?? DateTime.now(),
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
