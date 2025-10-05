import 'package:flutter/material.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/services/church_service.dart';

class DistrictManagementScreen extends StatefulWidget {
  const DistrictManagementScreen({super.key});

  @override
  State<DistrictManagementScreen> createState() => _DistrictManagementScreenState();
}

class _DistrictManagementScreenState extends State<DistrictManagementScreen> {
  final DistrictService _districtService = DistrictService();
  final RegionService _regionService = RegionService();
  final ChurchService _churchService = ChurchService();

  List<District> _districts = [];
  List<Region> _regions = [];
  Map<String, int> _churchCounts = {};

  String? _selectedRegionId;
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

      // Load districts based on selection
      if (_selectedRegionId != null) {
        _districts = await _districtService.getDistrictsByRegion(_selectedRegionId!);
      } else {
        _districts = await _districtService.getAllDistricts();
      }

      _districts.sort((a, b) => a.name.compareTo(b.name));

      // Load church counts for each district
      _churchCounts.clear();
      for (var district in _districts) {
        final churches = await _churchService.getChurchesByDistrict(district.id);
        _churchCounts[district.id] = churches.length;
      }
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

  void _showEditDialog(District? district) {
    final isEdit = district != null;
    final nameController = TextEditingController(text: district?.name ?? '');
    final codeController = TextEditingController(text: district?.code ?? '');

    String? selectedRegionId = district?.regionId ?? _selectedRegionId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit District' : 'Add District'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRegionId,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  border: OutlineInputBorder(),
                ),
                items: _regions.map((region) {
                  return DropdownMenuItem(
                    value: region.id,
                    child: Text('${region.name} (${region.code})'),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedRegionId = value;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'District Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'District Code',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., KK1, PPR',
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
                  codeController.text.isEmpty ||
                  selectedRegionId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final region = _regions.firstWhere((r) => r.id == selectedRegionId);

              final districtData = District(
                id: district?.id ?? 'dist_${DateTime.now().millisecondsSinceEpoch}',
                name: nameController.text,
                code: codeController.text.toUpperCase(),
                regionId: selectedRegionId!,
                missionId: region.missionId,
                createdBy: district?.createdBy ?? 'admin',
                createdAt: district?.createdAt ?? DateTime.now(),
              );

              try {
                if (isEdit) {
                  await _districtService.updateDistrict(districtData);
                } else {
                  await _districtService.createDistrict(districtData);
                }

                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'District updated successfully' : 'District created successfully'),
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

  void _deleteDistrict(District district) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete District'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete ${district.name}?'),
            const SizedBox(height: 8),
            if (_churchCounts[district.id] != null && _churchCounts[district.id]! > 0)
              Text(
                'Warning: This district has ${_churchCounts[district.id]} churches. They will be affected.',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _districtService.deleteDistrict(district.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('District deleted successfully')),
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
        title: const Text('District Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
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
                });
                _loadData();
              },
            ),
          ),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCard(
                  'Total Districts',
                  _districts.length.toString(),
                  Icons.location_city,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Total Churches',
                  _churchCounts.values.fold<int>(0, (sum, count) => sum + count).toString(),
                  Icons.church,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Regions',
                  _selectedRegionId != null ? '1' : _regions.length.toString(),
                  Icons.map,
                  Colors.orange,
                ),
              ],
            ),
          ),

          const Divider(),

          // District list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _districts.isEmpty
                    ? const Center(child: Text('No districts found'))
                    : ListView.builder(
                        itemCount: _districts.length,
                        itemBuilder: (context, index) {
                          final district = _districts[index];
                          final churchCount = _churchCounts[district.id] ?? 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  district.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                district.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Code: ${district.code}'),
                                  Text('Region: ${_getRegionName(district.regionId)}'),
                                  Text('Churches: $churchCount'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(district),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteDistrict(district),
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
        label: const Text('Add District'),
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
