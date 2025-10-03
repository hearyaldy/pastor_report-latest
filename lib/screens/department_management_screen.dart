import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/services/department_service.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/providers/auth_provider.dart';

class DepartmentManagementScreen extends StatelessWidget {
  const DepartmentManagementScreen({super.key});

  // Available colors for department selection
  static final List<Color> _availableColors = [
    // Light pastel colors (original)
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

    // More vibrant options
    const Color(0xFFC8E6C9), // Medium Green
    const Color(0xFFBBDEFB), // Medium Blue
    const Color(0xFFFFE0B2), // Medium Orange
    const Color(0xFFE1BEE7), // Medium Purple
    const Color(0xFFF8BBD0), // Medium Pink

    // Neutral options
    Colors.white, // White
    const Color(0xFFF5F5F5), // Light Grey
    const Color(0xFFECEFF1), // Blue Grey Light
  ];

  @override
  Widget build(BuildContext context) {
    final deptService = DepartmentService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userMission = authProvider.user?.mission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Management'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showDepartmentDialog(context, null, userMission);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Department>>(
        stream: deptService.getDepartmentsStream(mission: userMission),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No departments found'),
                  Text('Tap + to add a department'),
                ],
              ),
            );
          }

          final departments = snapshot.data!;

          return ListView.builder(
            itemCount: departments.length,
            itemBuilder: (context, index) {
              final dept = departments[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading:
                      Icon(dept.icon, color: AppColors.primaryLight, size: 32),
                  title: Text(dept.name),
                  subtitle: Text(dept.formUrl,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _showDepartmentDialog(context, dept, userMission);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Department'),
                              content: Text('Delete ${dept.name}?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              await deptService.deleteDepartment(dept.id,
                                  missionName: userMission);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Department deleted')),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static void _showDepartmentDialog(
      BuildContext context, Department? department, String? userMission) {
    final nameController = TextEditingController(text: department?.name ?? '');
    final urlController =
        TextEditingController(text: department?.formUrl ?? '');
    IconData selectedIcon = department?.icon ?? Icons.dashboard;

    // Initialize color with department color or default
    Color selectedColor = department?.color ?? AppColors.cardBackground;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title:
                Text(department == null ? 'Add Department' : 'Edit Department'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Form URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Color selection
                  const Text('Select Color:'),
                  const SizedBox(height: 8),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _availableColors.length,
                      itemBuilder: (context, index) {
                        final color = _availableColors[index];
                        final isSelected = selectedColor.value == color.value;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Icon:'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: Department.availableIcons.length,
                      itemBuilder: (context, index) {
                        final iconData = Department.availableIcons[index];
                        final isSelected = selectedIcon == iconData['icon'];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedIcon = iconData['icon'];
                            });
                          },
                          child: Card(
                            color: isSelected ? AppColors.primaryLight : null,
                            child: Icon(
                              iconData['icon'],
                              size: 32,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty ||
                      urlController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  try {
                    final deptService = DepartmentService();

                    // Debug: Log the mission value
                    print('Adding department with mission: $userMission');

                    final newDept = Department(
                      id: department?.id ?? '',
                      name: nameController.text,
                      icon: selectedIcon,
                      formUrl: urlController.text,
                      mission: userMission,
                      color: selectedColor, // Use the selected color
                      isActive: department?.isActive ??
                          true, // Preserve active status
                    );

                    if (department == null) {
                      // Add department - it will lookup the mission by name
                      await deptService.addDepartment(newDept);
                      print('Department added successfully');
                    } else {
                      await deptService.updateDepartment(newDept);
                      print('Department updated successfully');
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Department ${department == null ? 'added' : 'updated'}')),
                    );
                  } catch (e) {
                    print('Error adding/updating department: $e');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: Text(department == null ? 'Add' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }
}
