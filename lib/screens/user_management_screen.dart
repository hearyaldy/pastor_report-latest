import 'package:flutter/material.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final userService = UserManagementService();
  String _searchQuery = '';
  String? _selectedMissionFilter;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      _currentUser = await userService.getCurrentUser();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  List<UserModel> _applyFilters(List<UserModel> users) {
    var filtered = users;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        return user.displayName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            user.email.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply mission filter (compare both ID and name since users might have either)
    if (_selectedMissionFilter != null && _selectedMissionFilter!.isNotEmpty) {
      filtered = filtered.where((user) {
        if (user.mission == null) return false;
        // Check if mission matches directly OR if the mission name matches
        return user.mission == _selectedMissionFilter ||
            MissionService().getMissionNameById(user.mission) ==
                MissionService().getMissionNameById(_selectedMissionFilter);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 16),
                    _buildFilterRow(),
                  ],
                ),
              ),
            ),
            _buildUserList(),
          ],
        ),
      ),
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
          'User Management',
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
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search users by name or email...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
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
        });
      },
    );
  }

  Widget _buildFilterRow() {
    return StreamBuilder<List<UserModel>>(
      stream: userService.getUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final allUsers = snapshot.data!;
        // Get unique mission IDs and normalize them
        final missionIds = allUsers
            .map((u) => u.mission)
            .where((m) => m != null && m.isNotEmpty)
            .toSet()
            .toList();

        // Sort missions by name
        final missions = missionIds
          ..sort((a, b) {
            final nameA = MissionService().getMissionNameById(a);
            final nameB = MissionService().getMissionNameById(b);
            return nameA.compareTo(nameB);
          });

        return DropdownButtonFormField<String>(
          value: _selectedMissionFilter,
          decoration: InputDecoration(
            labelText: 'Filter by Mission',
            prefixIcon: const Icon(Icons.business, size: 20),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Missions')),
            ...missions.map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    MissionService().getMissionNameById(m),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedMissionFilter = value;
            });
          },
        );
      },
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<UserModel>>(
      stream: userService.getUsersStream(),
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
          return const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No users found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final allUsers = snapshot.data!;
        final filteredUsers = _applyFilters(allUsers);

        if (filteredUsers.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No users match your search',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Group users by role
        Map<UserRole, List<UserModel>> usersByRole = {};
        for (var user in filteredUsers) {
          if (!usersByRole.containsKey(user.userRole)) {
            usersByRole[user.userRole] = [];
          }
          usersByRole[user.userRole]!.add(user);
        }

        // Sort roles by level in descending order (highest level first)
        final sortedRoles = usersByRole.keys.toList()
          ..sort((a, b) => b.level.compareTo(a.level));

        // Create a list of widgets for each role group
        List<Widget> roleGroups = [];
        for (var role in sortedRoles) {
          roleGroups.add(_buildRoleSectionHeader(role));
          roleGroups.addAll(
              usersByRole[role]!.map((user) => _buildUserCard(user)).toList());
          roleGroups
              .add(const SizedBox(height: 24)); // Add space between role groups
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
      },
    );
  }

  Widget _buildRoleSectionHeader(UserRole role) {
    Color roleColor = _getRoleColor(role);
    IconData roleIcon = _getRoleIcon(role);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Icon(roleIcon, color: roleColor, size: 24),
          const SizedBox(width: 12),
          Text(
            '${role.displayName}s', // Pluralize the role name
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
                color: roleColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRoleDescription(role),
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

  Widget _buildUserCard(UserModel user) {
    // Get role color for the card
    final roleColor = _getRoleColor(user.userRole);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: roleColor.withOpacity(0.3), width: 1.5),
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
                    _getRoleIcon(user.userRole),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showUserDetails(user),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            roleColor.withOpacity(0.8),
                            roleColor,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getRoleIcon(user.userRole),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildChip(
                                user.role ?? 'User',
                                _getRoleIcon(user.userRole),
                                _getRoleColor(user.userRole).withOpacity(0.1),
                                _getRoleColor(user.userRole),
                              ),
                              if (user.mission != null)
                                _buildChip(
                                  MissionService()
                                      .getMissionNameById(user.mission),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Role management button
                        IconButton(
                          icon: Icon(
                            Icons.manage_accounts,
                            color: _currentUser?.userRole
                                        .canManageRole(user.userRole) ==
                                    true
                                ? AppColors.primaryLight
                                : Colors.grey,
                          ),
                          onPressed: _currentUser?.userRole
                                      .canManageRole(user.userRole) ==
                                  true
                              ? () => _showChangeRoleDialog(user)
                              : null,
                          tooltip: 'Manage Role',
                        ),
                        // Delete button
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: _currentUser?.userRole
                                        .canManageRole(user.userRole) ==
                                    true
                                ? Colors.red.shade400
                                : Colors.grey,
                          ),
                          onPressed: _currentUser?.userRole
                                      .canManageRole(user.userRole) ==
                                  true
                              ? () => _confirmDeleteUser(user)
                              : null,
                          tooltip: 'Delete User',
                        ),
                      ],
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

  // Helper method to get role icon
  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.security;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.missionAdmin:
        return Icons.business;
      case UserRole.ministerialSecretary:
        return Icons.book;
      case UserRole.officer:
        return Icons.badge;
      case UserRole.director:
        return Icons.supervisor_account;
      case UserRole.editor:
        return Icons.edit_note;
      case UserRole.churchTreasurer:
        return Icons.account_balance_wallet;
      case UserRole.districtPastor:
        return Icons.location_city;
      case UserRole.user:
        return Icons.person;
    }
  }

  // Helper method to get role color
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.deepPurple;
      case UserRole.admin:
        return Colors.red.shade700;
      case UserRole.missionAdmin:
        return Colors.blue.shade700;
      case UserRole.ministerialSecretary:
        return Colors.teal.shade700;
      case UserRole.officer:
        return Colors.cyan.shade700;
      case UserRole.director:
        return Colors.deepPurple.shade700;
      case UserRole.editor:
        return Colors.green.shade700;
      case UserRole.churchTreasurer:
        return Colors.amber.shade800;
      case UserRole.districtPastor:
        return Colors.indigo.shade700;
      case UserRole.user:
        return AppColors.primaryDark;
    }
  }

  Widget _buildChip(
      String label, IconData icon, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: user.isAdmin
                      ? [Colors.red, Colors.red.shade700]
                      : [AppColors.primaryLight, AppColors.primaryDark],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      size: 40,
                      color: user.isAdmin ? Colors.red : AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.isAdmin ? 'Admin' : 'Pastor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildDetailRow(Icons.email, 'Email', user.email),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.badge, 'User ID', user.uid),
                  if (user.mission != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.business, 'Mission',
                        MissionService().getMissionNameById(user.mission)),
                  ],
                  if (user.district != null) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<String>(
                      future:
                          DistrictService().getDistrictNameById(user.district),
                      builder: (context, snapshot) {
                        final districtName = snapshot.data ?? user.district!;
                        return _buildDetailRow(
                            Icons.map, 'District', districtName);
                      },
                    ),
                  ],
                  if (user.region != null) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<String>(
                      future: RegionService().getRegionNameById(user.region),
                      builder: (context, snapshot) {
                        final regionName = snapshot.data ?? user.region!;
                        return _buildDetailRow(
                            Icons.place, 'Region', regionName);
                      },
                    ),
                  ],
                  if (user.role != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.work, 'Position', user.role!),
                  ],
                  const SizedBox(height: 24),
                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _currentUser?.userRole.canManageRole(user.userRole) ==
                                  true
                              ? () {
                                  Navigator.pop(context);
                                  _showChangeRoleDialog(user);
                                }
                              : null,
                      icon: const Icon(Icons.manage_accounts),
                      label: const Text('Manage User Role'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            user.isAdmin ? Colors.red : AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Show a dialog to change user role
  Future<void> _showChangeRoleDialog(UserModel user) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to determine your permissions')),
      );
      return;
    }

    // Only show roles that the current user can assign
    List<UserRole> availableRoles = [];

    for (var role in UserRole.values) {
      if (_currentUser!.userRole.canManageRole(role)) {
        availableRoles.add(role);
      }
    }

    if (availableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You don\'t have permission to change roles')),
      );
      return;
    }

    UserRole selectedRole = user.userRole;

    final newRole = await showModalBottomSheet<UserRole>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Row(
              children: [
                Icon(
                  Icons.manage_accounts,
                  color: AppColors.primaryLight,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Change Role',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            Text(
              'Select a new role for ${user.displayName}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // Role selection list
            ...availableRoles.map((role) => _buildRoleSelectionTile(
                  role: role,
                  isSelected: selectedRole == role,
                  onTap: () {
                    selectedRole = role;
                    Navigator.pop(context, role);
                  },
                )),

            const SizedBox(height: 20),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Add padding for bottom safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );

    if (newRole != null && newRole != user.userRole) {
      try {
        await userService.updateUserRole(uid: user.uid, newRole: newRole);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                    'Role updated for ${user.displayName} to ${newRole.displayName}'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Confirm and delete user
  Future<void> _confirmDeleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            const Text('Delete User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this user?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    user.email,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Text(
                    user.role ?? 'User',
                    style: TextStyle(
                      color: _getRoleColor(user.userRole),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone. The user will be removed from the system.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await userService.deleteUser(user.uid);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          '${user.displayName} has been deleted from user database'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '⚠️ Note: Firebase Auth account remains. Delete manually from Firebase Console > Authentication',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Refresh the user list
        setState(() {});
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error deleting user: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // Helper method to build role selection tile for the bottom sheet
  Widget _buildRoleSelectionTile({
    required UserRole role,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);
    final roleDescription = _getRoleDescription(role);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? roleColor.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? roleColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(roleIcon, color: roleColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    roleDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: roleColor, size: 24),
          ],
        ),
      ),
    );
  }

  // Helper method for role description
  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Full system access';
      case UserRole.admin:
        return 'Manage users and missions';
      case UserRole.missionAdmin:
        return 'Manage own mission';
      case UserRole.ministerialSecretary:
        return 'View and manage Borang B reports';
      case UserRole.officer:
        return 'Mission-level officer access';
      case UserRole.director:
        return 'Mission-level director access';
      case UserRole.editor:
        return 'Edit department URLs';
      case UserRole.churchTreasurer:
        return 'Manage financial reports';
      case UserRole.districtPastor:
        return 'Manage churches and reports in own district';
      case UserRole.user:
        return 'Basic access';
    }
  }
}
