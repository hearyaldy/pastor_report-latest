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
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/import_sabah_staff.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  String _searchQuery = '';
  String _selectedMission = 'All';

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isMissionAdmin = user?.userRole == UserRole.missionAdmin ||
        user?.userRole == UserRole.admin ||
        user?.userRole == UserRole.superAdmin;

    // Only mission admins and above can access this screen
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
      appBar: AppBar(
        title: const Text('Staff Directory'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          if (isMissionAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'import') {
                  _importCSV(context, user!);
                } else if (value == 'export') {
                  _exportCSV(context, user!);
                } else if (value == 'template') {
                  _downloadTemplate(context);
                } else if (value == 'import_sabah') {
                  _importSabahStaff(context, user!);
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
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search staff...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                if (user?.userRole == UserRole.superAdmin ||
                    user?.userRole == UserRole.admin) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedMission,
                    decoration: InputDecoration(
                      labelText: 'Filter by Mission',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.filter_list),
                    ),
                    items: ['All', ...AppConstants.missions]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedMission = value!),
                  ),
                ],
              ],
            ),
          ),

          // Staff List
          Expanded(
            child: StreamBuilder<List<Staff>>(
              stream: _getStaffStream(user),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isMissionAdmin);
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
                  staffList = staffList
                      .where((s) => s.mission == _selectedMission)
                      .toList();
                }

                if (staffList.isEmpty) {
                  return const Center(child: Text('No staff found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    return _buildStaffCard(staff, isMissionAdmin, user);
                  },
                );
              },
            ),
          ),
        ],
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

  Stream<List<Staff>> _getStaffStream(UserModel? user) {
    if (user == null) return Stream.value([]);

    switch (user.userRole) {
      case UserRole.superAdmin:
      case UserRole.admin:
        return StaffService.instance.streamAllStaff();
      case UserRole.missionAdmin:
        return StaffService.instance.streamStaffByMission(user.mission ?? '');
      default:
        return StaffService.instance.streamStaffByMission(user.mission ?? '');
    }
  }

  Widget _buildStaffCard(Staff staff, bool canEdit, UserModel? user) {
    final canEditThis = canEdit &&
        (user?.userRole == UserRole.superAdmin ||
            user?.userRole == UserRole.admin ||
            staff.mission == user?.mission);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: staff.photoUrl != null
            ? CircleAvatar(backgroundImage: NetworkImage(staff.photoUrl!))
            : CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  staff.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        title: Text(staff.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(staff.role),
            Text(staff.mission,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => _makePhoneCall(staff.phone),
              tooltip: 'Call',
            ),
            if (canEditThis)
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'email', child: Text('Send Email')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _editStaff(context, staff, user!);
                  } else if (value == 'delete') {
                    _deleteStaff(staff);
                  } else if (value == 'email') {
                    _sendEmail(staff.email);
                  }
                },
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showStaffDetails(staff),
      ),
    );
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
              onPressed: () => _addStaff(context, context.read<AuthProvider>().user!),
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

  void _showStaffDetails(Staff staff) {
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
                    fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(staff.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(staff.role, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            _detailRow(Icons.business, 'Mission', staff.mission),
            if (staff.department != null)
              _detailRow(Icons.category, 'Department', staff.department!),
            if (staff.district != null)
              _detailRow(Icons.location_on, 'District', staff.district!),
            if (staff.region != null)
              _detailRow(Icons.map, 'Region', staff.region!),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
          title: Text(importResult['success'] ? 'Import Complete' : 'Import Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(importResult['message']),
              if (importResult['errors'] != null &&
                  (importResult['errors'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(importResult['errors'] as List).take(5).map((e) => Text('• $e')),
                if ((importResult['errors'] as List).length > 5)
                  Text('... and ${(importResult['errors'] as List).length - 5} more'),
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
        SnackBar(content: Text('Error importing CSV: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportCSV(BuildContext context, UserModel user) async {
    try {
      final staff = await StaffService.instance.getStaffByMission(user.mission ?? '');

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
      final fileName = 'staff_export_${DateTime.now().millisecondsSinceEpoch}.csv';
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
        SnackBar(content: Text('Error exporting CSV: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      const template = 'name,role,email,phone,mission,department,district,region,notes\n'
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
    _regionController =
        TextEditingController(text: widget.staff?.region ?? '');
    _notesController = TextEditingController(text: widget.staff?.notes ?? '');
    _selectedMission = widget.staff?.mission ?? widget.userMission;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _districtController.dispose();
    _regionController.dispose();
    _notesController.dispose();
    super.dispose();
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
                  widget.staff == null ? 'Add Staff Member' : 'Edit Staff Member',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedMission = value!),
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
                                department: _departmentController.text.trim().isEmpty
                                    ? null
                                    : _departmentController.text.trim(),
                                district: _districtController.text.trim().isEmpty
                                    ? null
                                    : _districtController.text.trim(),
                                region: _regionController.text.trim().isEmpty
                                    ? null
                                    : _regionController.text.trim(),
                                notes: _notesController.text.trim().isEmpty
                                    ? null
                                    : _notesController.text.trim(),
                                createdAt: widget.staff?.createdAt ?? DateTime.now(),
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
