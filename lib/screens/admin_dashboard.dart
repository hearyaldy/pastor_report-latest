// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/services/role_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/utils/constants.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedMissionFilter = 'All Missions';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.yellow,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellow,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.dashboard), text: 'Departments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildDepartmentsTab(),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final currentUser = context.watch<AuthProvider>().user;
          if (currentUser == null) return const SizedBox.shrink();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mission Management (only for Admin and SuperAdmin)
              if (currentUser.canManageMissions())
                FloatingActionButton.small(
                  heroTag: 'mission_management',
                  backgroundColor: Colors.blue,
                  tooltip: 'Mission Management',
                  onPressed: () {
                    Navigator.pushNamed(
                        context, AppConstants.routeMissionManagement);
                  },
                  child: const Icon(Icons.business),
                ),
              if (currentUser.canManageMissions()) const SizedBox(height: 10),
              // Add Department (for MissionAdmin and above)
              if (currentUser.canManageDepartments())
                FloatingActionButton(
                  heroTag: 'add_department',
                  backgroundColor: AppColors.primaryLight,
                  tooltip: 'Add Department',
                  onPressed: () {
                    _addDepartment(context);
                  },
                  child: const Icon(Icons.add),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsersTab() {
    final currentUser = context.watch<AuthProvider>().user;

    if (currentUser == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        // Users List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: RoleService.instance.getUsersStream(currentUser),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!.docs;

              // Filter users based on search and permissions
              final filteredUsers = users.where((doc) {
                final userData = doc.data() as Map<String, dynamic>;
                final name =
                    userData['displayName']?.toString().toLowerCase() ?? '';
                final email = userData['email']?.toString().toLowerCase() ?? '';
                final matchesSearch =
                    name.contains(_searchQuery) || email.contains(_searchQuery);

                if (!matchesSearch) return false;

                // Check if current user can manage this user
                final targetUser = UserModel.fromMap(userData, doc.id);
                return RoleService.instance.canManageUser(
                  currentUser: currentUser,
                  targetUser: targetUser,
                );
              }).toList();

              if (filteredUsers.isEmpty) {
                return const Center(
                  child: Text('No users found matching your search'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final doc = filteredUsers[index];
                  final userId = doc.id;
                  final userData = doc.data() as Map<String, dynamic>;
                  final targetUser = UserModel.fromMap(userData, userId);

                  // Determine user role and assign colors
                  Color roleColor;
                  IconData roleIcon;
                  String roleText = targetUser.roleString;

                  switch (targetUser.userRole) {
                    case UserRole.superAdmin:
                      roleColor = Colors.purple;
                      roleIcon = Icons.verified_user;
                      break;
                    case UserRole.admin:
                      roleColor = Colors.red;
                      roleIcon = Icons.admin_panel_settings;
                      break;
                    case UserRole.missionAdmin:
                      roleColor = Colors.blue;
                      roleIcon = Icons.business;
                      break;
                    case UserRole.editor:
                      roleColor = Colors.orange;
                      roleIcon = Icons.edit;
                      break;
                    case UserRole.user:
                      roleColor = AppColors.primaryLight;
                      roleIcon = Icons.person;
                      break;
                  }

                  return _UserCard(
                    userId: userId,
                    userData: userData,
                    targetUser: targetUser,
                    currentUser: currentUser,
                    roleColor: roleColor,
                    roleIcon: roleIcon,
                    roleText: roleText,
                    onActionSelected: (value) => _handleUserAction(
                        value, userId, userData, targetUser, currentUser),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleUserAction(
      String action,
      String userId,
      Map<String, dynamic> userData,
      UserModel targetUser,
      UserModel currentUser) async {
    try {
      if (action == 'changeRole') {
        _showRoleSelectionDialog(userId, userData, targetUser, currentUser);
      } else if (action == 'changeMission') {
        _showMissionSelectionDialog(userId, userData, currentUser);
      } else if (action == 'togglePremium') {
        await RoleService.instance.updatePremiumStatus(
          targetUserId: userId,
          isPremium: !targetUser.isPremium,
          currentUser: currentUser,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${userData['displayName']} is ${!targetUser.isPremium ? 'now' : 'no longer'} a premium user',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (action == 'delete') {
        _confirmDeleteUser(context, userId, userData['displayName']);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRoleSelectionDialog(
      String userId,
      Map<String, dynamic> userData,
      UserModel targetUser,
      UserModel currentUser) async {
    final availableRoles = RoleService.instance.getAssignableRoles(currentUser);

    if (availableRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to assign roles'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedRole = await showDialog<UserRole>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${userData['displayName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableRoles.map((role) {
            return RadioListTile<UserRole>(
              title: Text(role.displayName),
              subtitle: Text(_getRoleDescription(role)),
              value: role,
              groupValue: targetUser.userRole,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedRole != null && selectedRole != targetUser.userRole) {
      try {
        await RoleService.instance.updateUserRole(
          targetUserId: userId,
          newRole: selectedRole,
          currentUser: currentUser,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${userData['displayName']} is now ${selectedRole.displayName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Full system access';
      case UserRole.admin:
        return 'Manage users and missions';
      case UserRole.missionAdmin:
        return 'Manage own mission';
      case UserRole.editor:
        return 'Edit department URLs';
      case UserRole.user:
        return 'Basic access';
    }
  }

  Future<void> _showMissionSelectionDialog(String userId,
      Map<String, dynamic> userData, UserModel currentUser) async {
    // Get all missions
    final missionsSnapshot = await FirebaseFirestore.instance
        .collection('missions')
        .orderBy('name')
        .get();

    final missions = missionsSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
        .toList();

    final selectedMission = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Mission for ${userData['displayName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('None'),
              onTap: () => Navigator.pop(context, ''),
            ),
            ...missions.map((mission) {
              return ListTile(
                title: Text(mission),
                onTap: () => Navigator.pop(context, mission),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedMission != null) {
      try {
        await RoleService.instance.updateUserMission(
          targetUserId: userId,
          mission: selectedMission.isEmpty ? null : selectedMission,
          currentUser: currentUser,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedMission.isEmpty
                  ? '${userData['displayName']} removed from mission'
                  : '${userData['displayName']} assigned to $selectedMission',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update mission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDepartmentsTab() {
    // Read missions directly from Firestore with real-time updates
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('missions')
          .orderBy('name')
          .snapshots(),
      builder: (context, missionsSnapshot) {
        if (missionsSnapshot.hasError) {
          return Center(child: Text('Error: ${missionsSnapshot.error}'));
        }

        if (!missionsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final missionDocs = missionsSnapshot.data!.docs;

        // If no missions, show empty state
        if (missionDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No missions or departments found'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _addDepartment(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Department'),
                ),
              ],
            ),
          );
        }

        // Build list of mission names for filter
        final missionNames = ['All Missions'];
        missionNames.addAll(missionDocs
            .map(
                (doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
            .toList());

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mission filter dropdown
                    Container(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      width: double.infinity,
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter by Mission',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              DropdownButtonFormField<String>(
                                value: _selectedMissionFilter,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                items: missionNames.map((String mission) {
                                  return DropdownMenuItem<String>(
                                    value: mission,
                                    child: Text(mission),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedMissionFilter = newValue;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Display departments based on filter
                    if (_selectedMissionFilter == 'All Missions')
                      // Show all missions with their departments
                      for (var missionDoc in missionDocs)
                        _buildMissionSection(missionDoc)
                    else
                      // Show only selected mission's departments
                      for (var missionDoc in missionDocs)
                        if ((missionDoc.data()
                                as Map<String, dynamic>)['name'] ==
                            _selectedMissionFilter)
                          _buildMissionSection(missionDoc),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => _addDepartment(context),
                backgroundColor: AppColors.primaryLight,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  // Build a mission section with its departments
  Widget _buildMissionSection(QueryDocumentSnapshot missionDoc) {
    final missionData = missionDoc.data() as Map<String, dynamic>;
    final missionName = missionData['name'] as String;
    final missionId = missionDoc.id;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('missions')
          .doc(missionId)
          .collection('departments')
          .orderBy('name')
          .snapshots(),
      builder: (context, deptSnapshot) {
        if (deptSnapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error loading departments for $missionName'),
          );
        }

        if (!deptSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final departments = deptSnapshot.data!.docs;

        // Don't show mission if it has no departments
        if (departments.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                missionName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            ...departments.map((deptDoc) {
              final deptData = deptDoc.data() as Map<String, dynamic>;
              return _buildDepartmentCardFromData(
                  context, deptDoc.id, deptData, missionId);
            }),
          ],
        );
      },
    );
  }

  Widget _buildDepartmentCardFromData(BuildContext context, String departmentId,
      Map<String, dynamic> deptData, String missionId) {
    final departmentName = deptData['name'] as String? ?? 'Unknown';
    final formUrl = deptData['formUrl'] as String? ?? '';
    final iconString = deptData['icon'] as String? ?? 'business';
    final icon = Department.getIconFromString(iconString);

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: AppColors.primaryLight,
        ),
        title: Text(departmentName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (formUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Form URL: $formUrl',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editDepartmentInMission(
                context,
                missionId,
                Department(
                  id: departmentId,
                  name: departmentName,
                  icon: icon,
                  formUrl: formUrl,
                  isActive: deptData['isActive'] as bool? ?? true,
                  mission: deptData['mission'] as String? ?? '',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteDepartmentFromMission(
                context,
                missionId,
                departmentId,
                departmentName,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(
      BuildContext context, String userId, String? userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content:
            Text('Are you sure you want to delete ${userName ?? 'this user'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await UserManagementService().deleteUser(userId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addDepartment(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DepartmentBottomSheet(
        onSave: (departmentData) async {
          try {
            // Get the mission name from department data
            final missionName = departmentData['mission'] as String?;

            if (missionName == null || missionName.isEmpty) {
              throw 'Mission is required';
            }

            // Find the mission ID by name
            final missionSnapshot = await FirebaseFirestore.instance
                .collection('missions')
                .where('name', isEqualTo: missionName)
                .limit(1)
                .get();

            if (missionSnapshot.docs.isEmpty) {
              throw 'Mission "$missionName" not found';
            }

            final missionId = missionSnapshot.docs.first.id;

            // Add department to the mission's subcollection
            await FirebaseFirestore.instance
                .collection('missions')
                .doc(missionId)
                .collection('departments')
                .add({
              ...departmentData,
              'createdAt': FieldValue.serverTimestamp(),
            });

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Department added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to add department: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  // Methods for mission-based department operations
  Future<void> _editDepartmentInMission(
      BuildContext context, String missionId, Department department) async {
    // Get mission name directly from Firestore
    final missionDoc = await FirebaseFirestore.instance
        .collection('missions')
        .doc(missionId)
        .get();

    if (!missionDoc.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mission not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final missionName =
        (missionDoc.data() as Map<String, dynamic>)['name'] as String;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DepartmentBottomSheet(
        departmentId: department.id,
        initialData: {
          'name': department.name,
          'icon': Department.getIconString(department.icon),
          'formUrl': department.formUrl,
          'isActive': department.isActive,
          'mission': missionName,
        },
        onSave: (departmentData) async {
          try {
            // Update department directly in Firestore
            await FirebaseFirestore.instance
                .collection('missions')
                .doc(missionId)
                .collection('departments')
                .doc(department.id)
                .update({
              'name': departmentData['name'],
              'icon': departmentData['icon'],
              'formUrl': departmentData['formUrl'] ?? '',
              'isActive': departmentData['isActive'] ?? true,
              'mission': missionName,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Department updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update department: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteDepartmentFromMission(BuildContext context,
      String missionId, String departmentId, String departmentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Are you sure you want to delete $departmentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete department directly from Firestore
        await FirebaseFirestore.instance
            .collection('missions')
            .doc(missionId)
            .collection('departments')
            .doc(departmentId)
            .delete();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete department: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Department Bottom Sheet Widget
class _DepartmentBottomSheet extends StatefulWidget {
  final String? departmentId;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSave;

  const _DepartmentBottomSheet({
    this.departmentId,
    this.initialData,
    required this.onSave,
  });

  @override
  State<_DepartmentBottomSheet> createState() => _DepartmentBottomSheetState();
}

class _DepartmentBottomSheetState extends State<_DepartmentBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _linkController;

  String _selectedIcon = 'business';
  Color _selectedColor = const Color(0xFFE8F5E9);
  bool _isActive = true;
  String _selectedMission = 'Sabah Mission';

  final List<String> _missions = [
    'Sabah Mission',
    'Sarawak Mission',
    'Peninsular Mission',
    'Singapore Mission'
  ];

  final List<Color> _availableColors = [
    const Color(0xFFE8F5E9), // Light Green
    const Color(0xFFE3F2FD), // Light Blue
    const Color(0xFFFFF3E0), // Light Orange
    const Color(0xFFF3E5F5), // Light Purple
    const Color(0xFFFCE4EC), // Light Pink
    const Color(0xFFE0F2F1), // Light Teal
    const Color(0xFFFFF9C4), // Light Yellow
    const Color(0xFFFFEBEE), // Light Red
    const Color(0xFFEDE7F6), // Light Deep Purple
    const Color(0xFFE1F5FE), // Light Cyan
  ];

  final List<Map<String, dynamic>> _availableIcons = [
    {'key': 'business', 'icon': Icons.business, 'name': 'Business'},
    {'key': 'person', 'icon': Icons.person, 'name': 'Person'},
    {'key': 'group', 'icon': Icons.group, 'name': 'Group'},
    {'key': 'school', 'icon': Icons.school, 'name': 'School'},
    {'key': 'local_hospital', 'icon': Icons.local_hospital, 'name': 'Hospital'},
    {'key': 'message', 'icon': Icons.message, 'name': 'Message'},
    {'key': 'family_restroom', 'icon': Icons.family_restroom, 'name': 'Family'},
    {'key': 'child_care', 'icon': Icons.child_care, 'name': 'Child Care'},
    {'key': 'woman', 'icon': Icons.woman, 'name': 'Woman'},
    {'key': 'book', 'icon': Icons.book, 'name': 'Book'},
    {
      'key': 'volunteer_activism',
      'icon': Icons.volunteer_activism,
      'name': 'Volunteer'
    },
    {'key': 'access_time', 'icon': Icons.access_time, 'name': 'Clock'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialData?['name'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialData?['description'] ?? '');
    _linkController =
        TextEditingController(text: widget.initialData?['formUrl'] ?? '');

    if (widget.initialData != null) {
      _selectedIcon = widget.initialData!['icon'] ?? 'business';
      _isActive = widget.initialData!['isActive'] ?? true;
      _selectedMission = widget.initialData!['mission'] ?? 'Sabah Mission';

      if (widget.initialData!['color'] != null) {
        _selectedColor = Color(widget.initialData!['color']);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // Helper method to get mission abbreviation
  String _getMissionAbbreviation(String mission) {
    switch (mission) {
      case 'Sabah Mission':
        return 'SM';
      case 'Sarawak Mission':
        return 'SWM';
      case 'Peninsular Mission':
        return 'PM';
      case 'Singapore Mission':
        return 'SGM';
      default:
        return mission.substring(0, 2).toUpperCase();
    }
  }

  // Helper method to create example form URLs for different missions
  String _createExampleFormUrl(String originalUrl, String originalMission,
      String newMission, String deptName) {
    if (!originalUrl.contains('forms.gle') &&
        !originalUrl.contains('docs.google.com/forms')) {
      // If it's not a Google Forms URL, just add a mission indicator
      return '$originalUrl-${_getMissionAbbreviation(newMission)}';
    }

    // For Google Forms URLs, try to create a more realistic example
    final origAbbrev = _getMissionAbbreviation(originalMission);
    final newAbbrev = _getMissionAbbreviation(newMission);

    // Check if URL already has mission identifier
    if (originalUrl.contains(origAbbrev)) {
      return originalUrl.replaceAll(origAbbrev, newAbbrev);
    } else {
      // Try to insert mission identifier before any query parameters
      final urlParts = originalUrl.split('?');
      if (urlParts.length > 1) {
        return '${urlParts[0]}-$newAbbrev?${urlParts[1]}';
      } else {
        // Simplest case: just append the mission abbreviation
        return '$originalUrl-$newAbbrev';
      }
    }
  }

  Future<void> _copyToOtherMissions() async {
    // Show confirmation dialog with improved formatting
    String previewText =
        'This will create copies of this department for other missions.';
    final originalFormUrl = _linkController.text.trim();

    // Generate example URLs for preview with better formatting
    final List<Widget> previewWidgets = [];

    previewWidgets.add(Text(previewText));

    if (originalFormUrl.isNotEmpty) {
      previewWidgets.add(const SizedBox(height: 16));
      previewWidgets.add(Text(
        'Example form links will be created:',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));

      for (final mission in _missions) {
        if (mission != _selectedMission) {
          final exampleUrl = _createExampleFormUrl(originalFormUrl,
              _selectedMission, mission, _nameController.text.trim());

          previewWidgets.add(const SizedBox(height: 8));
          previewWidgets.add(
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exampleUrl,
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Department'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: previewWidgets,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final departmentsRef =
          FirebaseFirestore.instance.collection('departments');
      final batch = FirebaseFirestore.instance.batch();
      final currentData = Map<String, dynamic>.from(widget.initialData!);

      // Get original form URL to use as a template
      final originalFormUrl = _linkController.text.trim();
      final String deptName = _nameController.text.trim();
      final bool hasOriginalUrl = originalFormUrl.isNotEmpty;

      // Copy to each mission except the current one
      for (final mission in _missions) {
        if (mission != _selectedMission) {
          final newDepartment = Map<String, dynamic>.from(currentData);
          newDepartment['mission'] = mission;

          // Create an example form URL based on the original if one exists
          if (hasOriginalUrl) {
            final exampleUrl = _createExampleFormUrl(
                originalFormUrl, _selectedMission, mission, deptName);
            newDepartment['formUrl'] = exampleUrl;
          } else {
            newDepartment['formUrl'] = ''; // No original URL to base on
          }

          newDepartment['createdAt'] = FieldValue.serverTimestamp();

          final newDocRef = departmentsRef.doc(); // Generate new document ID
          batch.set(newDocRef, newDepartment);
        }
      }

      // Commit the batch
      await batch.commit();

      if (!mounted) return;

      // Show a more prominent success alert
      final hasFormUrls = originalFormUrl.isNotEmpty;
      final message = hasFormUrls
          ? 'Department copied to other missions with example form links'
          : 'Department copied to other missions successfully';

      // First show a dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (hasFormUrls)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Remember to check and edit the auto-generated form links if needed.',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.grey[700]),
                  ),
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

      // Also show a snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: hasFormUrls
              ? SnackBarAction(
                  label: 'Edit Links',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pop(context); // Close the bottom sheet
                    // This will refresh the departments list and user can edit as needed
                  },
                )
              : null,
        ),
      );
      Navigator.pop(context); // Close the bottom sheet
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy department: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'formUrl': _linkController.text.trim(),
        'icon': _selectedIcon,
        'color': _selectedColor.toARGB32(),
        'isActive': _isActive,
        'mission': _selectedMission, // Using selected mission
      };

      if (widget.departmentId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      widget.onSave(data);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    widget.departmentId == null
                        ? 'Add Department'
                        : 'Edit Department',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),

                  // Mode indicator for edit mode
                  if (widget.departmentId != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Edit mode - "Copy to Other Missions" button available',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Department Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Department Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a department name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Link
                  TextFormField(
                    controller: _linkController,
                    decoration: const InputDecoration(
                      labelText: 'Form Link (URL)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                      hintText: 'https://forms.gle/...',
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (!value.startsWith('http://') &&
                            !value.startsWith('https://')) {
                          return 'Please enter a valid URL';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Mission Selection
                  DropdownButtonFormField<String>(
                    value: _selectedMission,
                    decoration: const InputDecoration(
                      labelText: 'Mission *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    items: _missions.map((String mission) {
                      return DropdownMenuItem<String>(
                        value: mission,
                        child: Text(mission),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedMission = newValue;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a mission';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Copy to Other Missions Button - Improved visibility
                  if (widget.departmentId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _copyToOtherMissions,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy to Other Missions',
                              style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Icon Selection
                  Text(
                    'Icon',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableIcons.length,
                      itemBuilder: (context, index) {
                        final iconData = _availableIcons[index];
                        final isSelected = _selectedIcon == iconData['key'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIcon = iconData['key'];
                            });
                          },
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iconData['icon'],
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black54,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  iconData['name'],
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Color Selection
                  Text(
                    'Card Color',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _availableColors.map((color) {
                      final isSelected = _selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : Colors.grey[300]!,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.black54)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Status Switch
                  SwitchListTile(
                    title: const Text('Active Status'),
                    subtitle: Text(_isActive
                        ? 'Department is active'
                        : 'Department is inactive'),
                    value: _isActive,
                    activeColor: AppColors.primaryLight,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(widget.departmentId == null
                              ? 'Add Department'
                              : 'Save Changes'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Expandable User Card Widget
class _UserCard extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;
  final UserModel targetUser;
  final UserModel currentUser;
  final Color roleColor;
  final IconData roleIcon;
  final String roleText;
  final Function(String) onActionSelected;

  const _UserCard({
    required this.userId,
    required this.userData,
    required this.targetUser,
    required this.currentUser,
    required this.roleColor,
    required this.roleIcon,
    required this.roleText,
    required this.onActionSelected,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: widget.roleColor,
              child: Icon(widget.roleIcon, color: Colors.white),
            ),
            title: Row(
              children: [
                Expanded(
                    child: Text(widget.userData['displayName'] ?? 'No Name')),
                if (widget.targetUser.isPremium)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: Colors.white),
                        SizedBox(width: 2),
                        Text('Premium',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userData['email'] ?? 'No Email'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.roleColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.roleText,
                        style: TextStyle(
                          color: widget.roleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.targetUser.mission != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business,
                                size: 10, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              widget.targetUser.mission!,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.primaryLight,
              ),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          // Expanding Actions Menu
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Change Role Button
                  if (RoleService.instance
                      .getAssignableRoles(widget.currentUser)
                      .isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings, size: 20),
                        label: const Text('Change Role'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue,
                          elevation: 0,
                        ),
                        onPressed: () {
                          widget.onActionSelected('changeRole');
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                      ),
                    ),
                  if (RoleService.instance
                      .getAssignableRoles(widget.currentUser)
                      .isNotEmpty)
                    const SizedBox(height: 8),
                  // Assign Mission Button (only for Admin and SuperAdmin)
                  if (widget.currentUser.canManageMissions())
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.business, size: 20),
                        label: const Text('Assign Mission'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          foregroundColor: Colors.green,
                          elevation: 0,
                        ),
                        onPressed: () {
                          widget.onActionSelected('changeMission');
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                      ),
                    ),
                  if (widget.currentUser.canManageMissions())
                    const SizedBox(height: 8),
                  // Toggle Premium Button (only for Admin and SuperAdmin)
                  if (widget.currentUser.canManageUsers())
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          widget.targetUser.isPremium
                              ? Icons.star_border
                              : Icons.star,
                          size: 20,
                        ),
                        label: Text(
                          widget.targetUser.isPremium
                              ? 'Remove Premium'
                              : 'Make Premium',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade50,
                          foregroundColor: Colors.amber.shade700,
                          elevation: 0,
                        ),
                        onPressed: () {
                          widget.onActionSelected('togglePremium');
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                      ),
                    ),
                  if (widget.currentUser.canManageUsers())
                    const SizedBox(height: 8),
                  // Delete User Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete, size: 20),
                      label: const Text('Delete User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                      ),
                      onPressed: () {
                        widget.onActionSelected('delete');
                        setState(() {
                          _isExpanded = false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
