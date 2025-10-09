import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/staff_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/data_import_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/import_sabah_staff.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedMission = 'All';
  String _sortBy = 'Position'; // New sorting state

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isMissionAdmin = user?.userRole == UserRole.missionAdmin ||
        user?.userRole == UserRole.admin ||
        user?.userRole == UserRole.superAdmin ||
        user?.userRole == UserRole.districtPastor;

    // Only mission admins, district pastors and above can access this screen
    if (!isMissionAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Staff Directory'),
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need Mission Admin credentials to access this page',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    if (user?.userRole == UserRole.superAdmin ||
                        user?.userRole == UserRole.admin) ...[
                      const SizedBox(height: 16),
                      _buildMissionFilter(),
                      const SizedBox(height: 16),
                      _buildSortFilter(),
                    ],
                  ],
                ),
              ),
            ),
            _buildStaffList(user, isMissionAdmin),
          ],
        ),
      ),
      floatingActionButton: isMissionAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _addStaff(context, user!),
              backgroundColor: AppColors.primaryLight,
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'),
            )
          : null,
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryLight,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Staff Directory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryLight,
                AppColors.primaryDark,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Icon(
                  Icons.people_alt_rounded,
                  size: 150,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            final user = context.read<AuthProvider>().user!;
            if (value == 'import') {
              _importCSV(context, user);
            } else if (value == 'export') {
              _exportCSV(context, user);
            } else if (value == 'template') {
              _downloadTemplate(context);
            } else if (value == 'import_sabah') {
              _importSabahStaff(context, user);
            } else if (value == 'import_sabah_mission') {
              _importSabahMissionData(context, user);
            } else if (value == 'import_nsm_mission') {
              _importNSMMissionData(context, user);
            } else if (value == 'cleanup_duplicates') {
              _cleanupDuplicateStaff(context, user);
            } else if (value == 'migrate_missions') {
              // Inline migration logic to update existing staff records from mission names to UUIDs
              () async {
                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  // Get all staff records
                  final staffService = StaffService.instance;
                  final allStaff = await staffService.getAllStaff();

                  int migratedCount = 0;
                  for (final staff in allStaff) {
                    // Check if mission field contains a name instead of UUID
                    final missionMap = AppConstants.missions.firstWhere(
                      (m) => m['name'] == staff.mission,
                      orElse: () => {'id': '', 'name': ''},
                    );

                    if (missionMap['id']!.isNotEmpty &&
                        missionMap['id'] != staff.mission) {
                      // Update the staff record with the UUID
                      final updatedStaff =
                          staff.copyWith(mission: missionMap['id']);
                      await staffService.updateStaff(updatedStaff);
                      migratedCount++;
                    }
                  }

                  // Close loading dialog
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Migration completed! $migratedCount records updated.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  // Close loading dialog if open
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Migration failed: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'import',
              child: Row(
                children: [
                  Icon(Icons.upload_file, size: 20),
                  SizedBox(width: 8),
                  Text('Import CSV'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text('Export CSV'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'template',
              child: Row(
                children: [
                  Icon(Icons.file_download, size: 20),
                  SizedBox(width: 8),
                  Text('Download Template'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import_sabah',
              child: Row(
                children: [
                  Icon(Icons.cloud_upload, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Import Sabah Staff'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import_sabah_mission',
              child: Row(
                children: [
                  Icon(Icons.business, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Import Sabah Mission Data'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'import_nsm_mission',
              child: Row(
                children: [
                  Icon(Icons.business, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Import North Sabah Mission Data'),
                ],
              ),
            ),
            if (context.read<AuthProvider>().user?.userRole ==
                UserRole.superAdmin)
              const PopupMenuItem(
                value: 'cleanup_duplicates',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services,
                        size: 20, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Clean Up Duplicate Staff'),
                  ],
                ),
              ),
            if (context.read<AuthProvider>().user?.userRole ==
                UserRole.superAdmin)
              const PopupMenuItem(
                value: 'migrate_missions',
                child: Row(
                  children: [
                    Icon(Icons.sync, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Migrate Mission UUIDs'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search staff by name, role, or email...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
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
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildMissionFilter() {
    final user = context.read<AuthProvider>().user;
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
                Icon(Icons.admin_panel_settings,
                    color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  user?.userRole == UserRole.superAdmin
                      ? 'Super Admin: Select Mission'
                      : 'Admin: Filter by Mission',
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
                prefixIcon: const Icon(Icons.business),
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
              onChanged: (value) => setState(() => _selectedMission = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sort, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sort Staff By',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
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
                DropdownMenuItem(
                    value: 'Position', child: Text('Position Hierarchy')),
                DropdownMenuItem(value: 'Name', child: Text('Name (A-Z)')),
                DropdownMenuItem(value: 'Role', child: Text('Role (A-Z)')),
                DropdownMenuItem(
                    value: 'Department', child: Text('Department')),
              ],
              onChanged: (value) => setState(() => _sortBy = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList(UserModel? user, bool isMissionAdmin) {
    return StreamBuilder<List<Staff>>(
      stream: _getStaffStream(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

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

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No staff found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        var staffList = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          staffList = staffList
              .where((s) =>
                  s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  s.role.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  s.email.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
        }

        // Apply mission filter
        if (_selectedMission != 'All') {
          staffList =
              staffList.where((s) => s.mission == _selectedMission).toList();
        }

        // Apply sorting
        staffList = _sortStaffList(staffList);

        if (staffList.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No staff match your search',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Display staff based on sorting method
        if (_sortBy == 'Position') {
          // For position hierarchy, display in a flat sorted list
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= staffList.length) return null;
                  final staff = staffList[index];
                  return Column(
                    children: [
                      _buildModernStaffCard(staff, isMissionAdmin, user),
                      if (index < staffList.length - 1)
                        const SizedBox(height: 12),
                    ],
                  );
                },
                childCount: staffList.length,
              ),
            ),
          );
        } else {
          // For other sorting methods, group by role
          Map<String, List<Staff>> staffByRole = {};
          for (var staff in staffList) {
            final role = staff.role;
            if (!staffByRole.containsKey(role)) {
              staffByRole[role] = [];
            }
            staffByRole[role]!.add(staff);
          }

          // Create a list of widgets for each role group
          List<Widget> roleGroups = [];
          final sortedRoles = staffByRole.keys.toList()..sort();

          for (var role in sortedRoles) {
            roleGroups.add(_buildRoleSectionHeader(role));
            roleGroups.addAll(staffByRole[role]!
                .map((staff) =>
                    _buildModernStaffCard(staff, isMissionAdmin, user))
                .toList());
            roleGroups.add(const SizedBox(height: 24));
          }

          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => roleGroups[index],
                childCount: roleGroups.length,
              ),
            ),
          );
        }
      },
    );
  }

  List<Staff> _sortStaffList(List<Staff> staffList) {
    switch (_sortBy) {
      case 'Position':
        return _sortByPositionHierarchy(staffList);
      case 'Name':
        return staffList..sort((a, b) => a.name.compareTo(b.name));
      case 'Role':
        return staffList..sort((a, b) => a.role.compareTo(b.role));
      case 'Department':
        return staffList
          ..sort((a, b) {
            final deptA = a.department ?? '';
            final deptB = b.department ?? '';
            return deptA.compareTo(deptB);
          });
      default:
        return staffList;
    }
  }

  List<Staff> _sortByPositionHierarchy(List<Staff> staffList) {
    // Define position hierarchy (higher index = higher priority)
    const positionHierarchy = {
      'President': 4,
      'Executive Secretary': 3,
      'Treasurer': 2,
      // All other positions get priority 1
    };

    return staffList
      ..sort((a, b) {
        // Get priority for each staff member's role
        int getPriority(Staff staff) {
          // Check if the role contains any of the high-priority positions
          for (var entry in positionHierarchy.entries) {
            if (staff.role.toLowerCase().contains(entry.key.toLowerCase())) {
              return entry.value;
            }
          }
          return 1; // Default priority for other positions
        }

        int priorityA = getPriority(a);
        int priorityB = getPriority(b);

        // Sort by priority first (higher priority first)
        if (priorityA != priorityB) {
          return priorityB.compareTo(priorityA); // Higher priority first
        }

        // If same priority, sort by name
        return a.name.compareTo(b.name);
      });
  }

  Widget _buildRoleSectionHeader(String role) {
    Color roleColor = _getRoleColor(role);
    IconData roleIcon = _getRoleIcon(role);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Icon(roleIcon, color: roleColor, size: 24),
          const SizedBox(width: 12),
          Text(
            role,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_getRoleCount(role)} staff',
                style: TextStyle(
                  fontSize: 12,
                  color: roleColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getRoleCount(String role) {
    // This would need to be calculated based on current filtered staff
    // For now, return a placeholder
    return 0;
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'district pastor':
        return Colors.blue;
      case 'mission officer':
        return Colors.green;
      case 'assistant pastor':
        return Colors.orange;
      case 'youth pastor':
        return Colors.purple;
      case 'children pastor':
        return Colors.pink;
      case 'worship pastor':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'district pastor':
        return Icons.business;
      case 'mission officer':
        return Icons.group_work;
      case 'assistant pastor':
        return Icons.person;
      case 'youth pastor':
        return Icons.sports_soccer;
      case 'children pastor':
        return Icons.child_care;
      case 'worship pastor':
        return Icons.music_note;
      default:
        return Icons.work;
    }
  }

  Widget _buildModernStaffCard(Staff staff, bool canEdit, UserModel? user) {
    final roleColor = _getRoleColor(staff.role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: roleColor.withValues(alpha: 0.3), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Role indicator in top right corner
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: roleColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getRoleIcon(staff.role),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showStaffDetails(staff, canEdit, user),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48, // Reduced from 56 to save space
                      height: 48, // Reduced from 56 to save space
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            roleColor.withValues(alpha: 0.8),
                            roleColor,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getRoleIcon(staff.role),
                        color: Colors.white,
                        size: 24, // Reduced from 28
                      ),
                    ),
                    const SizedBox(width: 12), // Reduced from 16
                    // Staff info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            staff.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildChip(
                                staff.role,
                                _getRoleIcon(staff.role),
                                roleColor.withValues(alpha: 0.1),
                                roleColor,
                              ),
                              if (staff.mission.isNotEmpty)
                                _buildChip(
                                  AppConstants.missions.firstWhere(
                                        (m) => m['id'] == staff.mission,
                                        orElse: () => {'name': staff.mission},
                                      )['name'] ??
                                      staff.mission,
                                  Icons.business,
                                  Colors.blue.shade100,
                                  Colors.blue.shade700,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    if (canEdit)
                      SizedBox(
                        width:
                            96, // Increased from 80 to 96 to prevent overflow
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: AppColors.primaryLight,
                              ),
                              iconSize: 20, // Smaller icons
                              padding: const EdgeInsets.all(4), // Less padding
                              onPressed: () =>
                                  _editStaff(context, staff, user!),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red.shade400,
                              ),
                              iconSize: 20, // Smaller icons
                              padding: const EdgeInsets.all(4), // Less padding
                              onPressed: () => _deleteStaff(staff),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
      String label, IconData icon, Color backgroundColor, Color textColor) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200), // Limit chip width
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<Staff>> _getStaffStream(UserModel? user) {
    if (user == null) return Stream.value([]);

    switch (user.userRole) {
      case UserRole.superAdmin:
      case UserRole.admin:
        return StaffService.instance.streamAllStaff();
      case UserRole.missionAdmin:
        return StaffService.instance.streamStaffByMission(user.mission ?? '');
      case UserRole.districtPastor:
        return StaffService.instance.streamStaffByDistrict(user.district ?? '');
      default:
        return StaffService.instance.streamStaffByMission(user.mission ?? '');
    }
  }

  Widget _buildEmptyState(bool canAdd) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No staff members yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          if (canAdd) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () =>
                  _addStaff(context, context.read<AuthProvider>().user!),
              icon: const Icon(Icons.add),
              label: const Text('Add First Staff Member'),
            ),
          ],
        ],
      ),
    );
  }

  void _addStaff(BuildContext context, UserModel user) {
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

  void _editStaff(BuildContext context, Staff staff, UserModel user) {
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

  void _showStaffDetails(Staff staff, bool canEdit, UserModel? user) {
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
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(staff.name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text(staff.role,
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              _detailRow(
                  Icons.business,
                  'Mission',
                  AppConstants.missions.firstWhere(
                        (m) => m['id'] == staff.mission,
                        orElse: () =>
                            {'id': staff.mission, 'name': staff.mission},
                      )['name'] ??
                      staff.mission),
              if (staff.department != null)
                _detailRow(Icons.category, 'Department', staff.department!),
              if (staff.district != null)
                FutureBuilder<String>(
                  future: DistrictService().getDistrictNameById(staff.district),
                  builder: (context, snapshot) {
                    final districtName = snapshot.data ?? staff.district!;
                    return _detailRow(
                        Icons.location_on, 'District', districtName);
                  },
                ),
              if (staff.region != null)
                FutureBuilder<String>(
                  future: RegionService().getRegionNameById(staff.region),
                  builder: (context, snapshot) {
                    final regionName = snapshot.data ?? staff.region!;
                    return _detailRow(Icons.map, 'Region', regionName);
                  },
                ),
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
                Text(label,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importCSV(BuildContext context, UserModel user) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final csvData = await file.readAsString();

      if (!mounted) return;

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Importing staff...'),
                ],
              ),
            ),
          ),
        ),
      );

      final importResult =
          await StaffService.instance.importStaffFromCSV(csvData, user.uid);

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      // Show result dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
              importResult['success'] ? 'Import Complete' : 'Import Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(importResult['message']),
              if (importResult['errors'] != null &&
                  (importResult['errors'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Errors:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...(importResult['errors'] as List)
                    .take(5)
                    .map((e) => Text('• $e')),
                if ((importResult['errors'] as List).length > 5)
                  Text(
                      '... and ${(importResult['errors'] as List).length - 5} more'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error importing CSV: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportCSV(BuildContext context, UserModel user) async {
    try {
      final staff =
          await StaffService.instance.getStaffByMission(user.mission ?? '');

      if (staff.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No staff to export')),
        );
        return;
      }

      final csvData = await StaffService.instance.exportStaffToCSV(staff);

      // Save to temp file
      final directory = await getTemporaryDirectory();
      final fileName =
          'staff_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Staff Directory Export',
        text: 'Exported ${staff.length} staff members',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error exporting CSV: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      const template =
          'name,role,email,phone,mission,department,district,region,notes\n'
          'John Doe,District Pastor,john@example.com,+60123456789,Sabah Mission,Evangelism,Kota Kinabalu,West Coast,Sample entry';

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/staff_import_template.csv');
      await file.writeAsString(template);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Staff Import Template',
        text: 'Use this template to import staff members',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _importSabahStaff(BuildContext context, UserModel user) async {
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Sabah Mission Staff'),
        content: const Text(
          'This will import 59 staff members from Sabah Mission to the database.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (shouldImport != true || !mounted) return;

    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Importing staff...'),
          ],
        ),
      ),
    );

    try {
      await importSabahStaff(user.uid);

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully imported Sabah Mission staff'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing staff: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importSabahMissionData(
      BuildContext context, UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Sabah Mission Data'),
        content: const Text(
          'This will import complete Sabah Mission data including regions, districts, and churches from the JSON file.\n\n'
          'WARNING: This will DELETE all existing regions, districts, and churches for Sabah Mission and replace them with data from churches_SAB.json.\n\n'
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Import Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Importing Sabah Mission data...'),
          ],
        ),
      ),
    );

    try {
      final result =
          await DataImportService.instance.importSabahMissionData(user.uid);

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Text(
            'Successfully imported Sabah Mission data:\n\n'
            '• Regions created: ${result['regionsCreated']}\n'
            '• Districts created: ${result['districtsCreated']}\n'
            '• Churches created: ${result['churchesCreated']}\n'
            '• Churches deleted: ${result['churchesDeleted']}\n\n'
            'Total imported: ${result['totalImported']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing mission data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cleanupDuplicateStaff(
      BuildContext context, UserModel user) async {
    // First, ask for confirmation and mission selection
    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Up Duplicate Staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will identify and remove duplicate staff entries by comparing names. Staff with North Sabah Mission ID will be prioritized and kept, while duplicates with different mission IDs will be removed.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select mission to clean up:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setState) {
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: 'all',
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All Missions'),
                    ),
                    DropdownMenuItem(
                      value: 'M89PoDdB5sNCoDl8qTNS',
                      child: Text('North Sabah Mission'),
                    ),
                  ],
                  onChanged: (value) {},
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // We'll use the current value from the StatefulBuilder context
              String missionId = 'all';

              Navigator.pop(context, {
                'confirmed': true,
                'missionId': missionId == 'all' ? null : missionId
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );

    // If canceled or null
    if (result == null || result['confirmed'] != true) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cleaning up duplicate staff entries...'),
          ],
        ),
      ),
    );

    try {
      // Run the cleanup process
      final stats = await StaffService.instance.cleanupDuplicateStaff(
        missionId: result['missionId'],
      );

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      // Show results dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cleanup Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Staff entries checked: ${stats['totalStaffChecked']}'),
              const SizedBox(height: 8),
              Text('Duplicate groups found: ${stats['duplicateGroupsFound']}'),
              const SizedBox(height: 8),
              Text('Duplicate entries found: ${stats['duplicatesFound']}'),
              const SizedBox(height: 8),
              Text('Duplicate entries deleted: ${stats['duplicatesDeleted']}'),
              const SizedBox(height: 16),
              const Text(
                'Note: Staff with North Sabah Mission ID were prioritized and kept when duplicates were found.',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cleaning up duplicates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importNSMMissionData(
      BuildContext context, UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import North Sabah Mission Data'),
        content: const Text(
            'This will import complete North Sabah Mission data including regions, districts, and staff from the JSON file.\n\n'
            'This will REPLACE all existing data for North Sabah Mission.\n\n'
            'Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Import Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Importing North Sabah Mission data...'),
          ],
        ),
      ),
    );

    try {
      final result =
          await DataImportService.instance.importNSMMissionData(user.uid);

      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Successful'),
          content: Text('Successfully imported North Sabah Mission data:\n\n'
              '• Regions created: ${result['regionsCreated']}\n'
              '• Districts created: ${result['districtsCreated']}\n'
              '• Staff created: ${result['staffCreated']}\n'
              '• Staff deleted: ${result['staffDeleted']}\n'
              '• Churches deleted: ${result['churchesDeleted']}\n'
              '• Duplicates skipped: ${result['duplicatesSkipped']}\n\n'
              'Total imported: ${result['totalImported']}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing NSM mission data: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

// Staff Form Widget
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
    _selectedMission = matchingMission['id']!;
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
                          value: m['id'], child: Text(m['name']!)))
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

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Staff Management'),
    ),
    body: const Center(
      child: Text('Staff Management Screen'),
    ),
  );
}
