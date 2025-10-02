import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/services/department_service.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/providers/auth_provider.dart';

class DepartmentManagementScreen extends StatelessWidget {
  const DepartmentManagementScreen({super.key});

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
                  leading: Icon(dept.icon, color: AppColors.primaryLight, size: 32),
                  title: Text(dept.name),
                  subtitle: Text(dept.formUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                  onPressed: () => Navigator.pop(context, false),
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
                              await deptService.deleteDepartment(dept.id, missionName: userMission);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Department deleted')),
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

  static void _showDepartmentDialog(BuildContext context, Department? department, String? userMission) {
    final nameController = TextEditingController(text: department?.name ?? '');
    final urlController = TextEditingController(text: department?.formUrl ?? '');
    IconData selectedIcon = department?.icon ?? Icons.dashboard;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(department == null ? 'Add Department' : 'Edit Department'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Form URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Icon:'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  if (nameController.text.isEmpty || urlController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  try {
                    final deptService = DepartmentService();
                    final newDept = Department(
                      id: department?.id ?? '',
                      name: nameController.text,
                      icon: selectedIcon,
                      formUrl: urlController.text,
                      mission: userMission,
                      color: department?.color, // Preserve existing color
                      isActive: department?.isActive ?? true, // Preserve active status
                    );

                    if (department == null) {
                      await deptService.addDepartment(newDept);
                    } else {
                      await deptService.updateDepartment(newDept);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Department ${department == null ? 'added' : 'updated'}')),
                    );
                  } catch (e) {
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
