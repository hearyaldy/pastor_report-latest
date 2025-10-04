import 'package:flutter/material.dart';
import 'package:pastor_report/models/district_model.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/services/district_service.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';

class DistrictManagementScreen extends StatefulWidget {
  final String missionId;
  final String missionName;

  const DistrictManagementScreen({
    super.key,
    required this.missionId,
    required this.missionName,
  });

  @override
  State<DistrictManagementScreen> createState() =>
      _DistrictManagementScreenState();
}

class _DistrictManagementScreenState extends State<DistrictManagementScreen> {
  final DistrictService _districtService = DistrictService.instance;
  final RegionService _regionService = RegionService.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRegionFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Districts - ${widget.missionName}'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDistrictDialog(),
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add),
        label: const Text('Add District'),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search districts...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    if (value != _searchQuery) {
                      setState(() => _searchQuery = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Region Filter
                StreamBuilder<List<Region>>(
                  stream: _regionService.streamRegionsByMission(widget.missionId),
                  builder: (context, snapshot) {
                    final regions = snapshot.data ?? [];
                    if (regions.isEmpty) return const SizedBox.shrink();

                    return DropdownButtonFormField<String>(
                      value: _selectedRegionFilter,
                      decoration: InputDecoration(
                        labelText: 'Filter by Region',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Regions'),
                        ),
                        ...regions.map((region) => DropdownMenuItem(
                              value: region.id,
                              child: Text(region.name),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedRegionFilter = value);
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Districts List
          Expanded(
            child: StreamBuilder<List<District>>(
              stream: _districtService.streamDistrictsByMission(widget.missionId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var districts = snapshot.data ?? [];

                // Apply region filter
                if (_selectedRegionFilter != null) {
                  districts = districts
                      .where((d) => d.regionId == _selectedRegionFilter)
                      .toList();
                }

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  districts = districts.where((district) {
                    return district.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        district.code
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (districts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_city_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ||
                                  _selectedRegionFilter != null
                              ? 'No districts found'
                              : 'No districts yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchQuery.isEmpty &&
                            _selectedRegionFilter == null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create a new district',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: districts.length,
                  itemBuilder: (context, index) {
                    final district = districts[index];
                    return _buildDistrictCard(district);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictCard(District district) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.location_city,
            color: AppColors.primaryLight,
          ),
        ),
        title: Text(
          district.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Code: ${district.code}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            // Show region name
            FutureBuilder<Region?>(
              future: _regionService.getRegionById(district.regionId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Text(
                    'Region: ${snapshot.data!.name}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (district.pastorId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Pastor Assigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDistrictDialog(district),
              tooltip: 'Edit District',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteDistrict(district),
              tooltip: 'Delete District',
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDistrictDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedRegionId;

    // Get regions for selection
    final regions = await _regionService.getRegionsByMission(widget.missionId);

    if (regions.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a region first before adding districts'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New District'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRegionId,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      border: OutlineInputBorder(),
                    ),
                    items: regions
                        .map((region) => DropdownMenuItem(
                              value: region.id,
                              child: Text(region.name),
                            ))
                        .toList(),
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a region';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setDialogState(() => selectedRegionId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'District Name',
                      hintText: 'e.g., Kota Kinabalu District',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'District Code',
                      hintText: 'e.g., KKD',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district code';
                      }
                      return null;
                    },
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
                if (formKey.currentState!.validate()) {
                  final code = codeController.text.trim().toUpperCase();
                  final selectedRegion =
                      regions.firstWhere((r) => r.id == selectedRegionId);

                  // Check if code already exists in this region
                  final exists = await _districtService.isDistrictCodeExists(
                      code, selectedRegionId!);
                  if (exists && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('District code "$code" already exists in this region'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final district = District(
                    id: const Uuid().v4(),
                    name: nameController.text.trim(),
                    code: code,
                    regionId: selectedRegionId!,
                    missionId: widget.missionId,
                    createdAt: DateTime.now(),
                    createdBy: 'admin', // TODO: Get from current user
                  );

                  try {
                    await _districtService.createDistrict(district);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('District created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDistrictDialog(District district) async {
    final nameController = TextEditingController(text: district.name);
    final codeController = TextEditingController(text: district.code);
    final formKey = GlobalKey<FormState>();
    String? selectedRegionId = district.regionId;

    // Get regions for selection
    final regions = await _regionService.getRegionsByMission(widget.missionId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit District'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRegionId,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      border: OutlineInputBorder(),
                    ),
                    items: regions
                        .map((region) => DropdownMenuItem(
                              value: region.id,
                              child: Text(region.name),
                            ))
                        .toList(),
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a region';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setDialogState(() => selectedRegionId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'District Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'District Code',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter district code';
                      }
                      return null;
                    },
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
                if (formKey.currentState!.validate()) {
                  final code = codeController.text.trim().toUpperCase();

                  // Check if code already exists (excluding current district)
                  final exists = await _districtService.isDistrictCodeExists(
                    code,
                    selectedRegionId!,
                    excludeDistrictId: district.id,
                  );
                  if (exists && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('District code "$code" already exists in this region'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final updatedDistrict = district.copyWith(
                    name: nameController.text.trim(),
                    code: code,
                    regionId: selectedRegionId,
                  );

                  try {
                    await _districtService.updateDistrict(updatedDistrict);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('District updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDistrict(District district) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete District'),
        content: Text(
          'Are you sure you want to delete "${district.name}"?\n\n'
          'This action cannot be undone. Churches in this district must be removed first.',
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
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('District deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
