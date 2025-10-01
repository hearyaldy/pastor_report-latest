import 'package:flutter/material.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final userService = UserManagementService();

  String? _selectedMission;
  String? _selectedRole;
  String? _selectedPosition;
  String _groupBy = 'none'; // none, mission, role, position
  bool _showFilters = false;

  List<UserModel> _applyFilters(List<UserModel> users) {
    var filtered = users;

    if (_selectedMission != null && _selectedMission!.isNotEmpty) {
      filtered = filtered.where((u) => u.mission == _selectedMission).toList();
    }

    if (_selectedRole != null && _selectedRole!.isNotEmpty) {
      filtered = filtered.where((u) => u.roleString == _selectedRole).toList();
    }

    if (_selectedPosition != null && _selectedPosition!.isNotEmpty) {
      filtered = filtered.where((u) => u.role == _selectedPosition).toList();
    }

    return filtered;
  }

  Map<String, List<UserModel>> _groupUsers(List<UserModel> users) {
    if (_groupBy == 'none') {
      return {'All Users': users};
    }

    final Map<String, List<UserModel>> grouped = {};

    for (final user in users) {
      String key;

      switch (_groupBy) {
        case 'mission':
          key = user.mission ?? 'No Mission';
          break;
        case 'role':
          key = user.roleString;
          break;
        case 'position':
          key = user.role ?? 'No Position';
          break;
        default:
          key = 'All Users';
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(user);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            tooltip: _showFilters ? 'Hide Filters' : 'Show Filters',
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: StreamBuilder<List<UserModel>>(
                stream: userService.getUsersStream(),
                builder: (context, snapshot) {
                  final allUsers = snapshot.data ?? [];
                  final missions = allUsers
                      .map((u) => u.mission)
                      .where((m) => m != null && m.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
                  final roles = allUsers.map((u) => u.roleString).toSet().toList()
                    ..sort();
                  final positions = allUsers
                      .map((u) => u.role)
                      .where((r) => r != null && r.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Mission Filter
                      DropdownButtonFormField<String>(
                        value: _selectedMission,
                        decoration: const InputDecoration(
                          labelText: 'Mission',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Missions'),
                          ),
                          ...missions.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m!),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMission = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      // Role Filter (Admin Type)
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role (Admin Type)',
                          prefixIcon: Icon(Icons.admin_panel_settings),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Roles'),
                          ),
                          ...roles.map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      // Position Filter
                      DropdownButtonFormField<String>(
                        value: _selectedPosition,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                          prefixIcon: Icon(Icons.work),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Positions'),
                          ),
                          ...positions.map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p!),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPosition = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      // Group By
                      DropdownButtonFormField<String>(
                        value: _groupBy,
                        decoration: const InputDecoration(
                          labelText: 'Group By',
                          prefixIcon: Icon(Icons.group_work),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('No Grouping'),
                          ),
                          DropdownMenuItem(
                            value: 'mission',
                            child: Text('Group by Mission'),
                          ),
                          DropdownMenuItem(
                            value: 'role',
                            child: Text('Group by Role'),
                          ),
                          DropdownMenuItem(
                            value: 'position',
                            child: Text('Group by Position'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _groupBy = value ?? 'none';
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      // Clear Filters Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedMission = null;
                              _selectedRole = null;
                              _selectedPosition = null;
                              _groupBy = 'none';
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear All Filters'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // User List
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: userService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                final allUsers = snapshot.data!;
                final filteredUsers = _applyFilters(allUsers);
                final groupedUsers = _groupUsers(filteredUsers);

                if (filteredUsers.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No users match the selected filters',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: groupedUsers.length,
                  itemBuilder: (context, groupIndex) {
                    final groupKey = groupedUsers.keys.elementAt(groupIndex);
                    final groupUsers = groupedUsers[groupKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Header
                        if (_groupBy != 'none')
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            child: Row(
                              children: [
                                Icon(
                                  _groupBy == 'mission'
                                      ? Icons.business
                                      : _groupBy == 'role'
                                          ? Icons.admin_panel_settings
                                          : Icons.work,
                                  size: 20,
                                  color: AppColors.primaryLight,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$groupKey (${groupUsers.length})',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Group Users
                        ...groupUsers.map((user) => _buildUserCard(user)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isAdmin
              ? Colors.red
              : user.isMissionAdmin
                  ? Colors.orange
                  : user.isEditor
                      ? Colors.blue
                      : AppColors.primaryLight,
          child: Icon(
            user.isAdmin
                ? Icons.admin_panel_settings
                : user.isMissionAdmin
                    ? Icons.business_center
                    : user.isEditor
                        ? Icons.edit
                        : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(user.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (user.mission != null && user.mission!.isNotEmpty)
                  Chip(
                    label: Text(user.mission!),
                    avatar: const Icon(Icons.business, size: 16),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (user.role != null && user.role!.isNotEmpty)
                  Chip(
                    label: Text(user.role!),
                    avatar: const Icon(Icons.work, size: 16),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                Chip(
                  label: Text(user.roleString),
                  backgroundColor: user.isAdmin
                      ? Colors.red.shade100
                      : user.isMissionAdmin
                          ? Colors.orange.shade100
                          : user.isEditor
                              ? Colors.blue.shade100
                              : Colors.grey.shade200,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        trailing: Switch(
          value: user.isAdmin,
          onChanged: (value) async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('${value ? 'Grant' : 'Remove'} Admin Access'),
                content: Text(
                  'Are you sure you want to ${value ? 'grant' : 'remove'} admin access for ${user.displayName}?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                await userService.toggleAdminStatus(user.uid, value);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User updated')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
