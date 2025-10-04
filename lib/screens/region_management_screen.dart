import 'package:flutter/material.dart';
import 'package:pastor_report/models/region_model.dart';
import 'package:pastor_report/services/region_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';

class RegionManagementScreen extends StatefulWidget {
  final String missionId;
  final String missionName;

  const RegionManagementScreen({
    super.key,
    required this.missionId,
    required this.missionName,
  });

  @override
  State<RegionManagementScreen> createState() =>
      _RegionManagementScreenState();
}

class _RegionManagementScreenState extends State<RegionManagementScreen> {
  final RegionService _regionService = RegionService.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Regions - ${widget.missionName}'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRegionDialog(),
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add),
        label: const Text('Add Region'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search regions...',
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
          ),

          // Regions List
          Expanded(
            child: StreamBuilder<List<Region>>(
              stream: _regionService.streamRegionsByMission(widget.missionId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var regions = snapshot.data ?? [];

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  regions = regions.where((region) {
                    return region.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        region.code
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                if (regions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No regions yet'
                              : 'No regions found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create a new region',
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
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return _buildRegionCard(region);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionCard(Region region) {
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
            Icons.map,
            color: AppColors.primaryLight,
          ),
        ),
        title: Text(
          region.name,
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
              'Code: ${region.code}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditRegionDialog(region),
              tooltip: 'Edit Region',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteRegion(region),
              tooltip: 'Delete Region',
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRegionDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Region'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Region Name',
                  hintText: 'e.g., North Region',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter region name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Region Code',
                  hintText: 'e.g., NR',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter region code';
                  }
                  return null;
                },
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
              if (formKey.currentState!.validate()) {
                final code = codeController.text.trim().toUpperCase();

                // Check if code already exists
                final exists = await _regionService.isRegionCodeExists(
                    code, widget.missionId);
                if (exists && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Region code "$code" already exists'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final region = Region(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  code: code,
                  missionId: widget.missionId,
                  createdAt: DateTime.now(),
                  createdBy: 'admin', // TODO: Get from current user
                );

                try {
                  await _regionService.createRegion(region);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Region created successfully'),
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
    );
  }

  void _showEditRegionDialog(Region region) {
    final nameController = TextEditingController(text: region.name);
    final codeController = TextEditingController(text: region.code);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Region'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Region Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter region name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Region Code',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter region code';
                  }
                  return null;
                },
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
              if (formKey.currentState!.validate()) {
                final code = codeController.text.trim().toUpperCase();

                // Check if code already exists (excluding current region)
                final exists = await _regionService.isRegionCodeExists(
                  code,
                  widget.missionId,
                  excludeRegionId: region.id,
                );
                if (exists && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Region code "$code" already exists'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final updatedRegion = region.copyWith(
                  name: nameController.text.trim(),
                  code: code,
                );

                try {
                  await _regionService.updateRegion(updatedRegion);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Region updated successfully'),
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
    );
  }

  void _confirmDeleteRegion(Region region) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Region'),
        content: Text(
          'Are you sure you want to delete "${region.name}"?\n\n'
          'This action cannot be undone. Districts in this region must be removed first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _regionService.deleteRegion(region.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Region deleted successfully'),
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
