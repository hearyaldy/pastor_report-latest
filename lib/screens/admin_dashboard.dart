// lib/screens/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/services/user_management_service.dart';
import 'package:pastor_report/utils/constants.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    );
  }

  Widget _buildUsersTab() {
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
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = snapshot.data!.docs;

              // Filter users based on search query
              final filteredUsers = _searchQuery.isEmpty
                  ? allUsers
                  : allUsers.where((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final name = (userData['displayName'] ?? '').toString().toLowerCase();
                      final email = (userData['email'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || email.contains(_searchQuery);
                    }).toList();

              if (filteredUsers.isEmpty) {
                return const Center(
                  child: Text('No users found'),
                );
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  final userData = filteredUsers[index].data() as Map<String, dynamic>;
                  final userId = filteredUsers[index].id;
                  final bool isAdmin = userData['isAdmin'] ?? false;
                  final bool isEditor = userData['isEditor'] ?? false;

                  // Determine role and color
                  Color roleColor;
                  IconData roleIcon;
                  String roleText;

                  if (isAdmin) {
                    roleColor = Colors.red;
                    roleIcon = Icons.admin_panel_settings;
                    roleText = 'Admin';
                  } else if (isEditor) {
                    roleColor = Colors.orange;
                    roleIcon = Icons.edit;
                    roleText = 'Editor';
                  } else {
                    roleColor = AppColors.primaryLight;
                    roleIcon = Icons.person;
                    roleText = 'User';
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: roleColor,
                        child: Icon(roleIcon, color: Colors.white),
                      ),
                      title: Text(userData['displayName'] ?? 'No Name'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userData['email'] ?? 'No Email'),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              roleText,
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) => _handleUserAction(value, userId, userData),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'makeAdmin',
                            child: Row(
                              children: [
                                Icon(
                                  isAdmin ? Icons.remove_moderator : Icons.admin_panel_settings,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'makeEditor',
                            child: Row(
                              children: [
                                Icon(
                                  isEditor ? Icons.remove_circle : Icons.edit,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(isEditor ? 'Remove Editor' : 'Make Editor'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete User'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleUserAction(String action, String userId, Map<String, dynamic> userData) async {
    final bool isAdmin = userData['isAdmin'] ?? false;
    final bool isEditor = userData['isEditor'] ?? false;

    try {
      if (action == 'makeAdmin') {
        await UserManagementService().updateUserRole(
          uid: userId,
          isAdmin: !isAdmin,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${userData['displayName']} is ${!isAdmin ? 'now' : 'no longer'} an admin',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (action == 'makeEditor') {
        // Update editor role
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isEditor': !isEditor,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${userData['displayName']} is ${!isEditor ? 'now' : 'no longer'} an editor',
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

  Widget _buildDepartmentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('departments').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final departments = snapshot.data!.docs;

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: departments.length,
              itemBuilder: (context, index) {
                final department = departments[index].data() as Map<String, dynamic>;
                final departmentId = departments[index].id;
                
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.business),
                    title: Text(department['name'] ?? 'Unnamed Department'),
                    subtitle: Text(department['description'] ?? 'No description'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editDepartment(context, departmentId, department),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteDepartment(context, departmentId, department['name']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 16,
              right: 16,
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

  Future<void> _confirmDeleteUser(BuildContext context, String userId, String? userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${userName ?? 'this user'}?'),
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
            await FirebaseFirestore.instance.collection('departments').add(departmentData);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Department added successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!mounted) return;
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

  Future<void> _editDepartment(BuildContext context, String departmentId, Map<String, dynamic> department) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DepartmentBottomSheet(
        departmentId: departmentId,
        initialData: department,
        onSave: (departmentData) async {
          try {
            departmentData['updatedAt'] = FieldValue.serverTimestamp();
            await FirebaseFirestore.instance.collection('departments').doc(departmentId).update(departmentData);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Department updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!mounted) return;
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

  Future<void> _confirmDeleteDepartment(BuildContext context, String departmentId, String? departmentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Are you sure you want to delete ${departmentName ?? 'this department'}?'),
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
        await FirebaseFirestore.instance.collection('departments').doc(departmentId).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
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
    {'key': 'volunteer_activism', 'icon': Icons.volunteer_activism, 'name': 'Volunteer'},
    {'key': 'access_time', 'icon': Icons.access_time, 'name': 'Clock'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.initialData?['description'] ?? '');
    _linkController = TextEditingController(text: widget.initialData?['formUrl'] ?? '');

    if (widget.initialData != null) {
      _selectedIcon = widget.initialData!['icon'] ?? 'business';
      _isActive = widget.initialData!['isActive'] ?? true;

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

  void _save() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'formUrl': _linkController.text.trim(),
        'icon': _selectedIcon,
        'color': _selectedColor.value,
        'isActive': _isActive,
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
                    widget.departmentId == null ? 'Add Department' : 'Edit Department',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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
                        if (!value.startsWith('http://') && !value.startsWith('https://')) {
                          return 'Please enter a valid URL';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Icon Selection
                  const Text(
                    'Icon',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              color: isSelected ? AppColors.primaryLight : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryLight : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iconData['icon'],
                                  color: isSelected ? Colors.white : Colors.black54,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  iconData['name'],
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isSelected ? Colors.white : Colors.black54,
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
                  const Text(
                    'Card Color',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              color: isSelected ? AppColors.primaryLight : Colors.grey[300]!,
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
                    subtitle: Text(_isActive ? 'Department is active' : 'Department is inactive'),
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
                          child: Text(widget.departmentId == null ? 'Add Department' : 'Save Changes'),
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
