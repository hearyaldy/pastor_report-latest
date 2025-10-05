import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/services/department_service.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  State<DepartmentManagementScreen> createState() => _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState extends State<DepartmentManagementScreen> {
  String _searchQuery = '';
  bool _showInactive = false;

  // Available colors for department selection
  static final List<Color> _availableColors = [
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
    const Color(0xFFC8E6C9), // Medium Green
    const Color(0xFFBBDEFB), // Medium Blue
    const Color(0xFFFFE0B2), // Medium Orange
    const Color(0xFFE1BEE7), // Medium Purple
    const Color(0xFFF8BBD0), // Medium Pink
    Colors.white, // White
    const Color(0xFFF5F5F5), // Light Grey
    const Color(0xFFECEFF1), // Blue Grey Light
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userMission = authProvider.user?.mission;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(userMission),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildToggleBar(),
                  ],
                ),
              ),
            ),
            _buildDepartmentGrid(userMission),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDepartmentDialog(context, null, userMission),
        icon: const Icon(Icons.add),
        label: const Text('Add Department'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildModernAppBar(String? userMission) {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryLight,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Department Management',
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
                  Icons.dashboard_customize,
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
        hintText: 'Search departments...',
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

  Widget _buildToggleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Show Inactive', style: TextStyle(fontSize: 14)),
          const Spacer(),
          Switch(
            value: _showInactive,
            onChanged: (value) {
              setState(() {
                _showInactive = value;
              });
            },
            activeColor: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentGrid(String? userMission) {
    final deptService = DepartmentService();

    return StreamBuilder<List<Department>>(
      stream: deptService.getDepartmentsStream(mission: userMission),
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
                  Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No departments found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add a department',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        var departments = snapshot.data!;

        // Apply filters
        if (!_showInactive) {
          departments = departments.where((d) => d.isActive).toList();
        }

        if (_searchQuery.isNotEmpty) {
          departments = departments.where((d) {
            return d.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (departments.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No departments match your search',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dept = departments[index];
                return _buildDepartmentCard(dept, userMission);
              },
              childCount: departments.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentCard(Department dept, String? userMission) {
    return Container(
      decoration: BoxDecoration(
        color: dept.color ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDepartmentDetails(dept, userMission),
          child: Stack(
            children: [
              // Inactive overlay
              if (!dept.isActive)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Chip(
                        label: Text('Inactive'),
                        backgroundColor: Colors.red,
                        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        dept.icon,
                        size: 28,
                        color: _getIconColor(dept.color),
                      ),
                    ),
                    const Spacer(),
                    // Name
                    Text(
                      dept.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // URL preview
                    Text(
                      dept.formUrl,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showDepartmentDialog(context, dept, userMission),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.9),
                              foregroundColor: AppColors.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(Icons.link, size: 20),
                            onPressed: () => _openUrl(dept.formUrl),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.9),
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getIconColor(Color? bgColor) {
    if (bgColor == null) return AppColors.primaryLight;
    // Calculate brightness
    final luminance = bgColor.computeLuminance();
    return luminance > 0.7 ? AppColors.primaryDark : AppColors.primaryLight;
  }

  void _showDepartmentDetails(Department dept, String? userMission) {
    final deptService = DepartmentService();

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
                color: dept.color ?? Colors.grey.shade100,
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
                      dept.icon,
                      size: 40,
                      color: _getIconColor(dept.color),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dept.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: dept.isActive ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dept.isActive ? 'Active' : 'Inactive',
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
                  _buildDetailRow(Icons.link, 'Form URL', dept.formUrl),
                  if (dept.mission != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.business, 'Mission', dept.mission!),
                  ],
                  if (dept.lastUpdated != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.update,
                      'Last Updated',
                      _formatDate(dept.lastUpdated!),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Actions
                  ElevatedButton.icon(
                    onPressed: () => _openUrl(dept.formUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Form'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDepartmentDialog(context, dept, userMission);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Department'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                dept.isActive ? Icons.visibility_off : Icons.visibility,
                                color: dept.isActive ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Text(dept.isActive ? 'Deactivate' : 'Activate'),
                            ],
                          ),
                          content: Text(
                            '${dept.isActive ? 'Deactivate' : 'Activate'} ${dept.name}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: dept.isActive ? Colors.orange : Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          final updatedDept = Department(
                            id: dept.id,
                            name: dept.name,
                            icon: dept.icon,
                            formUrl: dept.formUrl,
                            color: dept.color,
                            mission: dept.mission,
                            isActive: !dept.isActive,
                          );
                          await deptService.updateDepartment(updatedDept);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text('Department ${dept.isActive ? 'deactivated' : 'activated'}'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(dept.isActive ? Icons.visibility_off : Icons.visibility),
                    label: Text(dept.isActive ? 'Deactivate' : 'Activate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dept.isActive ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete Department'),
                            ],
                          ),
                          content: Text('Permanently delete ${dept.name}?'),
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

                      if (confirm == true) {
                        try {
                          await deptService.deleteDepartment(dept.id, missionName: userMission);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text('Department deleted'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Text('Could not open URL'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showDepartmentDialog(BuildContext context, Department? department, String? userMission) {
    final nameController = TextEditingController(text: department?.name ?? '');
    final urlController = TextEditingController(text: department?.formUrl ?? '');
    IconData selectedIcon = department?.icon ?? Icons.dashboard;
    Color selectedColor = department?.color ?? AppColors.cardBackground;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  department == null ? Icons.add : Icons.edit,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: 12),
                Text(department == null ? 'Add Department' : 'Edit Department'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Department Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Form URL',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Color:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Icon(
                        selectedIcon,
                        color: _getIconColor(selectedColor),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _availableColors.length,
                      itemBuilder: (context, index) {
                        final color = _availableColors[index];
                        final isSelected = selectedColor.toARGB32() == color.toARGB32();

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
                                color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.black54, size: 16)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Icon:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryLight : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              iconData['icon'],
                              size: 28,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
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
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Please fill all fields'),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
                      color: selectedColor,
                      isActive: department?.isActive ?? true,
                    );

                    if (department == null) {
                      await deptService.addDepartment(newDept);
                    } else {
                      await deptService.updateDepartment(newDept);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 12),
                            Text('Department ${department == null ? 'added' : 'updated'}'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                ),
                child: Text(department == null ? 'Add' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }
}
