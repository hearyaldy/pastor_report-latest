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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Mission',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Mission Name',
                  hintText: 'Enter mission name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Mission Code',
                  hintText: 'Enter 3-letter code',
                  border: OutlineInputBorder(),
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter mission description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
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
                              content:
                                  Text('Please fill in all required fields')),
                        );
                      }
                    },
                    child: const Text('ADD'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMissionDialog(Mission mission) {
    final nameController = TextEditingController(text: mission.name);
    final codeController = TextEditingController(text: mission.code);
    final descriptionController =
        TextEditingController(text: mission.description ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Mission',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Mission Name',
                  hintText: 'Enter mission name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Mission Code',
                  hintText: 'Enter 3-letter code',
                  border: OutlineInputBorder(),
                ),
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                autofocus: false,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter mission description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
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
                              content:
                                  Text('Please fill in all required fields')),
                        );
                      }
                    },
                    child: const Text('UPDATE'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
    IconData selectedIcon = Department.availableIcons.first['icon'];
    final missionProvider =
        Provider.of<MissionProvider>(context, listen: false);
    final selectedMission = missionProvider.selectedMission;

    if (selectedMission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mission first')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Department',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Adding to: ${selectedMission.name}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Department Name',
                      hintText: 'Enter department name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<IconData>(
                    value: selectedIcon,
                    decoration: const InputDecoration(
                      labelText: 'Icon',
                      border: OutlineInputBorder(),
                    ),
                    items: Department.availableIcons.map((iconData) {
                      return DropdownMenuItem<IconData>(
                        value: iconData['icon'],
                        child: Row(
                          children: [
                            Icon(iconData['icon']),
                            const SizedBox(width: 8),
                            Text(iconData['name']),
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
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Form URL',
                      hintText: 'Enter Google Form URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
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
                                  content: Text(
                                      'Please fill in all required fields')),
                            );
                          }
                        },
                        child: const Text('ADD'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDepartmentDialog(Department department) {
    final nameController = TextEditingController(text: department.name);
    final formUrlController = TextEditingController(text: department.formUrl);
    IconData selectedIcon = department.icon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Department',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mission: ${department.mission ?? "None"}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Department Name',
                      hintText: 'Enter department name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<IconData>(
                    value: selectedIcon,
                    decoration: const InputDecoration(
                      labelText: 'Icon',
                      border: OutlineInputBorder(),
                    ),
                    items: Department.availableIcons.map((iconData) {
                      return DropdownMenuItem<IconData>(
                        value: iconData['icon'],
                        child: Row(
                          children: [
                            Icon(iconData['icon']),
                            const SizedBox(width: 8),
                            Text(iconData['name']),
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
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Form URL',
                      hintText: 'Enter Google Form URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
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
                              color: department.color, // Preserve the color
                            );

                            Provider.of<MissionProvider>(context, listen: false)
                                .updateDepartment(updatedDepartment);
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please fill in all required fields')),
                            );
                          }
                        },
                        child: const Text('UPDATE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
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
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
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
