// lib/screens/mission_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/models/mission_model.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/providers/mission_provider.dart';
import 'package:pastor_report/widgets/loading_overlay.dart';

class MissionManagementScreen extends StatefulWidget {
  const MissionManagementScreen({super.key});

  @override
  State<MissionManagementScreen> createState() =>
      _MissionManagementScreenState();
}

class _MissionManagementScreenState extends State<MissionManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load missions when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final missionProvider =
          Provider.of<MissionProvider>(context, listen: false);
      missionProvider.loadMissions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Missions'),
            Tab(text: 'Departments'),
          ],
        ),
      ),
      body: Consumer<MissionProvider>(
        builder: (context, missionProvider, child) {
          return LoadingOverlay(
            isLoading: missionProvider.isLoading,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Missions Tab
                _MissionsTab(
                  missions: missionProvider.missions,
                  selectedMission: missionProvider.selectedMission,
                  onMissionSelected: (mission) {
                    missionProvider.selectMission(id: mission.id);
                  },
                  onAddMission: _showAddMissionDialog,
                  onEditMission: _showEditMissionDialog,
                  onDeleteMission: (mission) {
                    _showDeleteMissionConfirmation(mission);
                  },
                ),
                // Departments Tab
                _DepartmentsTab(
                  departments: missionProvider.departments,
                  selectedMission: missionProvider.selectedMission,
                  onAddDepartment: _showAddDepartmentDialog,
                  onEditDepartment: _showEditDepartmentDialog,
                  onDeleteDepartment: (department) {
                    _showDeleteDepartmentConfirmation(department);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddMissionDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Mission'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Mission Name',
                  hintText: 'Enter mission name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Mission Code',
                  hintText: 'Enter 3-letter code',
                ),
                maxLength: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter mission description',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  codeController.text.isNotEmpty) {
                final mission = Mission(
                  id: '', // Will be assigned by Firestore
                  name: nameController.text,
                  code: codeController.text.toUpperCase(),
                  description: descriptionController.text,
                );

                Provider.of<MissionProvider>(context, listen: false)
                    .addMission(mission);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill in all required fields')),
                );
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _showEditMissionDialog(Mission mission) {
    final nameController = TextEditingController(text: mission.name);
    final codeController = TextEditingController(text: mission.code);
    final descriptionController =
        TextEditingController(text: mission.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Mission'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Mission Name',
                  hintText: 'Enter mission name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Mission Code',
                  hintText: 'Enter 3-letter code',
                ),
                maxLength: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter mission description',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  codeController.text.isNotEmpty) {
                final updatedMission = Mission(
                  id: mission.id,
                  name: nameController.text,
                  code: codeController.text.toUpperCase(),
                  description: descriptionController.text,
                  departments: mission.departments,
                  createdAt: mission.createdAt,
                );

                Provider.of<MissionProvider>(context, listen: false)
                    .updateMission(updatedMission);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill in all required fields')),
                );
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _showDeleteMissionConfirmation(Mission mission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mission'),
        content: Text(
            'Are you sure you want to delete ${mission.name}?\n\nThis will also delete all departments in this mission. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<MissionProvider>(context, listen: false)
                  .deleteMission(mission.id);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddDepartmentDialog() {
    final nameController = TextEditingController();
    final formUrlController = TextEditingController();
    IconData selectedIcon = Icons.folder;
    final missionProvider =
        Provider.of<MissionProvider>(context, listen: false);
    final selectedMission = missionProvider.selectedMission;

    if (selectedMission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mission first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New Department'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Adding department to: ${selectedMission.name}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Department Name',
                      hintText: 'Enter department name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<IconData>(
                    value: selectedIcon,
                    decoration: const InputDecoration(
                      labelText: 'Icon',
                    ),
                    items: [
                      Icons.person,
                      Icons.account_balance,
                      Icons.group,
                      Icons.message,
                      Icons.local_hospital,
                      Icons.school,
                      Icons.family_restroom,
                      Icons.woman,
                      Icons.child_care,
                      Icons.book,
                      Icons.person_pin,
                      Icons.access_time,
                      Icons.volunteer_activism,
                      Icons.folder,
                    ].map((IconData icon) {
                      return DropdownMenuItem<IconData>(
                        value: icon,
                        child: Row(
                          children: [
                            Icon(icon),
                            const SizedBox(width: 8),
                            Text(Department.getIconString(icon)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (IconData? value) {
                      if (value != null) {
                        setState(() {
                          selectedIcon = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: formUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Form URL',
                      hintText: 'Enter Google Form URL',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      formUrlController.text.isNotEmpty) {
                    final department = Department(
                      id: '', // Will be assigned by Firestore
                      name: nameController.text,
                      icon: selectedIcon,
                      formUrl: formUrlController.text,
                      mission: selectedMission.name,
                    );

                    missionProvider.addDepartment(department);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please fill in all required fields')),
                    );
                  }
                },
                child: const Text('ADD'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDepartmentDialog(Department department) {
    final nameController = TextEditingController(text: department.name);
    final formUrlController = TextEditingController(text: department.formUrl);
    IconData selectedIcon = department.icon;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Department'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mission: ${department.mission ?? "None"}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Department Name',
                      hintText: 'Enter department name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<IconData>(
                    value: selectedIcon,
                    decoration: const InputDecoration(
                      labelText: 'Icon',
                    ),
                    items: [
                      Icons.person,
                      Icons.account_balance,
                      Icons.group,
                      Icons.message,
                      Icons.local_hospital,
                      Icons.school,
                      Icons.family_restroom,
                      Icons.woman,
                      Icons.child_care,
                      Icons.book,
                      Icons.person_pin,
                      Icons.access_time,
                      Icons.volunteer_activism,
                      Icons.folder,
                    ].map((IconData icon) {
                      return DropdownMenuItem<IconData>(
                        value: icon,
                        child: Row(
                          children: [
                            Icon(icon),
                            const SizedBox(width: 8),
                            Text(Department.getIconString(icon)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (IconData? value) {
                      if (value != null) {
                        setState(() {
                          selectedIcon = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: formUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Form URL',
                      hintText: 'Enter Google Form URL',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      formUrlController.text.isNotEmpty) {
                    final updatedDepartment = Department(
                      id: department.id,
                      name: nameController.text,
                      icon: selectedIcon,
                      formUrl: formUrlController.text,
                      mission: department.mission,
                      isActive: department.isActive,
                    );

                    Provider.of<MissionProvider>(context, listen: false)
                        .updateDepartment(updatedDepartment);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please fill in all required fields')),
                    );
                  }
                },
                child: const Text('UPDATE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDepartmentConfirmation(Department department) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text(
            'Are you sure you want to delete ${department.name}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<MissionProvider>(context, listen: false)
                  .deleteDepartment(
                department.id,
                missionName: department.mission,
              );
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MissionsTab extends StatelessWidget {
  final List<Mission> missions;
  final Mission? selectedMission;
  final Function(Mission) onMissionSelected;
  final VoidCallback onAddMission;
  final Function(Mission) onEditMission;
  final Function(Mission) onDeleteMission;

  const _MissionsTab({
    required this.missions,
    required this.selectedMission,
    required this.onMissionSelected,
    required this.onAddMission,
    required this.onEditMission,
    required this.onDeleteMission,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        missions.isEmpty
            ? const Center(
                child: Text('No missions found. Add a mission to get started.'),
              )
            : ListView.builder(
                itemCount: missions.length,
                padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                itemBuilder: (context, index) {
                  final mission = missions[index];
                  final isSelected = selectedMission?.id == mission.id;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : null,
                    child: ListTile(
                      title: Text(mission.name),
                      subtitle: Text('Code: ${mission.code}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => onEditMission(mission),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => onDeleteMission(mission),
                          ),
                        ],
                      ),
                      onTap: () => onMissionSelected(mission),
                    ),
                  );
                },
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: onAddMission,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _DepartmentsTab extends StatelessWidget {
  final List<Department> departments;
  final Mission? selectedMission;
  final VoidCallback onAddDepartment;
  final Function(Department) onEditDepartment;
  final Function(Department) onDeleteDepartment;

  const _DepartmentsTab({
    required this.departments,
    required this.selectedMission,
    required this.onAddDepartment,
    required this.onEditDepartment,
    required this.onDeleteDepartment,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        selectedMission == null
            ? const Center(
                child: Text('Select a mission first to see its departments.'),
              )
            : departments.isEmpty
                ? Center(
                    child: Text(
                        'No departments found for ${selectedMission!.name}. Add a department to get started.'),
                  )
                : ListView.builder(
                    itemCount: departments.length,
                    padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                    itemBuilder: (context, index) {
                      final department = departments[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Icon(department.icon),
                          title: Text(department.name),
                          subtitle: Text(
                            department.formUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => onEditDepartment(department),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => onDeleteDepartment(department),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: selectedMission != null ? onAddDepartment : null,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
