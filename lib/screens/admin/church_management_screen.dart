import 'package:flutter/material.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';

class ChurchManagementScreen extends StatefulWidget {
  const ChurchManagementScreen({super.key});

  @override
  State<ChurchManagementScreen> createState() => _ChurchManagementScreenState();
}

class _ChurchManagementScreenState extends State<ChurchManagementScreen> {
  final ChurchService _churchService = ChurchService();
  final DistrictService _districtService = DistrictService();
  final RegionService _regionService = RegionService();

  List<Church> _churches = [];
  List<District> _districts = [];
  List<Region> _regions = [];

  String? _selectedRegionId;
  String? _selectedDistrictId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load regions
      _regions = await _regionService.getAllRegions();

      // Load districts and churches based on selection
      if (_selectedRegionId != null) {
        _districts = await _districtService.getDistrictsByRegion(_selectedRegionId!);

        if (_selectedDistrictId != null) {
          _churches = await _churchService.getChurchesByDistrict(_selectedDistrictId!);
        } else if (_districts.isNotEmpty) {
          // Load all churches in the region
          _churches = [];
          for (var district in _districts) {
            final districtChurches = await _churchService.getChurchesByDistrict(district.id);
            _churches.addAll(districtChurches);
          }
        }
      } else {
        // Load all districts and churches
        _districts = await _districtService.getAllDistricts();
        _churches = await _churchService.getAllChurches();
      }

      _churches.sort((a, b) => a.churchName.compareTo(b.churchName));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getDistrictName(String? districtId) {
    if (districtId == null) return 'N/A';
    final district = _districts.firstWhere(
      (d) => d.id == districtId,
      orElse: () => District(
        id: '',
        name: 'Unknown',
        code: '',
        regionId: '',
        missionId: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    return district.name;
  }

  String _getRegionName(String? regionId) {
    if (regionId == null) return 'N/A';
    final region = _regions.firstWhere(
      (r) => r.id == regionId,
      orElse: () => Region(
        id: '',
        name: 'Unknown',
        code: '',
        missionId: '',
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    return region.name;
  }

  void _showEditDialog(Church? church) {
    final isEdit = church != null;
    final nameController = TextEditingController(text: church?.churchName ?? '');
    final elderNameController = TextEditingController(text: church?.elderName ?? '');
    final elderEmailController = TextEditingController(text: church?.elderEmail ?? '');
    final elderPhoneController = TextEditingController(text: church?.elderPhone ?? '');
    final addressController = TextEditingController(text: church?.address ?? '');
    final memberCountController = TextEditingController(
      text: church?.memberCount?.toString() ?? '',
    );

    String? selectedDistrictId = church?.districtId ?? _selectedDistrictId;
    ChurchStatus selectedStatus = church?.status ?? ChurchStatus.church;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Church' : 'Add Church'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDistrictId,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    border: OutlineInputBorder(),
                  ),
                  items: _districts.map((district) {
                    return DropdownMenuItem(
                      value: district.id,
                      child: Text('${district.name} (${district.code})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedDistrictId = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Church Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ChurchStatus>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ChurchStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) selectedStatus = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: elderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Elder Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: elderEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Elder Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: elderPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Elder Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: memberCountController,
                  decoration: const InputDecoration(
                    labelText: 'Member Count',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
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
                  elderNameController.text.isEmpty ||
                  elderEmailController.text.isEmpty ||
                  elderPhoneController.text.isEmpty ||
                  selectedDistrictId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields')),
                );
                return;
              }

              final district = _districts.firstWhere((d) => d.id == selectedDistrictId);

              final churchData = Church(
                id: church?.id ?? 'ch_${DateTime.now().millisecondsSinceEpoch}',
                userId: church?.userId ?? 'system',
                churchName: nameController.text,
                elderName: elderNameController.text,
                elderEmail: elderEmailController.text,
                elderPhone: elderPhoneController.text,
                status: selectedStatus,
                address: addressController.text.isEmpty ? null : addressController.text,
                memberCount: int.tryParse(memberCountController.text),
                districtId: selectedDistrictId,
                regionId: district.regionId,
                missionId: district.missionId,
                createdAt: church?.createdAt ?? DateTime.now(),
                updatedAt: DateTime.now(),
              );

              try {
                if (isEdit) {
                  await _churchService.updateChurch(churchData);
                } else {
                  await _churchService.createChurch(churchData);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Church updated successfully' : 'Church created successfully'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _deleteChurch(Church church) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Church'),
        content: Text('Are you sure you want to delete ${church.churchName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _churchService.deleteChurch(church.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Church deleted successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Church Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRegionId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Region',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Regions'),
                      ),
                      ..._regions.map((region) {
                        return DropdownMenuItem(
                          value: region.id,
                          child: Text('${region.name} (${region.code})'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRegionId = value;
                        _selectedDistrictId = null;
                      });
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDistrictId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by District',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Districts'),
                      ),
                      ..._districts.map((district) {
                        return DropdownMenuItem(
                          value: district.id,
                          child: Text('${district.name} (${district.code})'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDistrictId = value;
                      });
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCard(
                  'Total Churches',
                  _churches.length.toString(),
                  Icons.church,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Total Members',
                  _churches.fold<int>(0, (sum, c) => sum + (c.memberCount ?? 0)).toString(),
                  Icons.people,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Active',
                  _churches.where((c) => c.status == ChurchStatus.church).length.toString(),
                  Icons.check_circle,
                  Colors.teal,
                ),
              ],
            ),
          ),

          const Divider(),

          // Church list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _churches.isEmpty
                    ? const Center(child: Text('No churches found'))
                    : ListView.builder(
                        itemCount: _churches.length,
                        itemBuilder: (context, index) {
                          final church = _churches[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  church.churchName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                church.churchName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('District: ${_getDistrictName(church.districtId)}'),
                                  Text('Region: ${_getRegionName(church.regionId)}'),
                                  Text('Elder: ${church.elderName}'),
                                  Text('Members: ${church.memberCount ?? 'N/A'}'),
                                  Text('Status: ${church.status.displayName}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(church),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteChurch(church),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('Add Church'),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
