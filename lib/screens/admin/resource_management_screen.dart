import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/models/resource_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/resource_service.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourceManagementScreen extends StatefulWidget {
  const ResourceManagementScreen({super.key});

  @override
  State<ResourceManagementScreen> createState() =>
      _ResourceManagementScreenState();
}

class _ResourceManagementScreenState extends State<ResourceManagementScreen> {
  final ResourceService _resourceService = ResourceService();

  List<Resource> _resources = [];
  List<Resource> _filteredResources = [];
  bool _isLoading = true;
  String _searchQuery = '';
  ResourceCategory? _selectedCategory;
  String _sortBy = 'uploadedAt'; // uploadedAt, name, category
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) return;

      // Load resources based on user role
      if (user.userRole == UserRole.superAdmin) {
        _resources = await _resourceService.getAllResources();
      } else if (user.mission != null) {
        _resources = await _resourceService.getResourcesByMission(user.mission!);
      }

      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading resources: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    _filteredResources = _resources.where((resource) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          resource.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          resource.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          resource.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));

      // Category filter
      final matchesCategory = _selectedCategory == null || resource.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    // Sort
    _filteredResources.sort((a, b) {
      int compare = 0;
      switch (_sortBy) {
        case 'name':
          compare = a.name.compareTo(b.name);
          break;
        case 'category':
          compare = a.category.displayName.compareTo(b.category.displayName);
          break;
        case 'uploadedAt':
        default:
          compare = a.uploadedAt.compareTo(b.uploadedAt);
          break;
      }
      return _sortAscending ? compare : -compare;
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          _buildModernAppBar(),
          _buildFiltersAndSearch(),
          _buildStatistics(),
          _buildResourcesList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddResourceDialog(),
        backgroundColor: AppColors.primaryLight,
        icon: const Icon(Icons.add),
        label: const Text('Add Resource'),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryLight,
                AppColors.primaryLight.withValues(alpha: 0.9),
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.folder_open,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resource Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Upload & manage ministry resources',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildFiltersAndSearch() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search resources...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
            ),
            const SizedBox(height: 12),
            // Filters Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ResourceCategory?>(
                        value: _selectedCategory,
                        hint: const Text('All Categories'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Categories'),
                          ),
                          ...ResourceCategory.values.map((category) =>
                              DropdownMenuItem(
                                value: category,
                                child: Text(category.displayName),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                          _applyFilters();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      items: const [
                        DropdownMenuItem(value: 'uploadedAt', child: Text('Date')),
                        DropdownMenuItem(value: 'name', child: Text('Name')),
                        DropdownMenuItem(value: 'category', child: Text('Category')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortBy = value);
                          _applyFilters();
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                  onPressed: () {
                    setState(() => _sortAscending = !_sortAscending);
                    _applyFilters();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final totalCount = _resources.length;
    final filteredCount = _filteredResources.length;

    // Count by category
    final docCount = _filteredResources.where((r) => r.category == ResourceCategory.document).length;
    final imageCount = _filteredResources.where((r) => r.category == ResourceCategory.image).length;
    final videoCount = _filteredResources.where((r) => r.category == ResourceCategory.video).length;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                filteredCount.toString(),
                Icons.folder,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Docs',
                docCount.toString(),
                Icons.description,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Images',
                imageCount.toString(),
                Icons.image,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Videos',
                videoCount.toString(),
                Icons.video_library,
                Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcesList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredResources.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No resources found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final resource = _filteredResources[index];
            return _buildResourceCard(resource);
          },
          childCount: _filteredResources.length,
        ),
      ),
    );
  }

  Widget _buildResourceCard(Resource resource) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openResource(resource),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildFileIcon(resource.category),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resource.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download, size: 20),
                            SizedBox(width: 12),
                            Text('Download'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'download':
                          _openResource(resource);
                          break;
                        case 'edit':
                          _showEditResourceDialog(resource);
                          break;
                        case 'delete':
                          _confirmDeleteResource(resource);
                          break;
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  _buildInfoChip(Icons.file_present, resource.fileExtension),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.data_usage, resource.fileSizeFormatted),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.person, resource.uploaderName),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.access_time, DateFormat('dd MMM yyyy').format(resource.uploadedAt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileIcon(ResourceCategory category) {
    IconData icon;
    Color color;

    switch (category) {
      case ResourceCategory.document:
        icon = Icons.description;
        color = Colors.blue;
        break;
      case ResourceCategory.presentation:
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      case ResourceCategory.spreadsheet:
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case ResourceCategory.image:
        icon = Icons.image;
        color = Colors.purple;
        break;
      case ResourceCategory.video:
        icon = Icons.video_library;
        color = Colors.red;
        break;
      case ResourceCategory.audio:
        icon = Icons.audiotrack;
        color = Colors.teal;
        break;
      case ResourceCategory.other:
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _openResource(Resource resource) async {
    final url = Uri.parse(resource.fileUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resource')),
        );
      }
    }
  }

  void _showAddResourceDialog() {
    // TODO: Implement file picker and upload dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File upload feature will be implemented with Firebase Storage'),
      ),
    );
  }

  void _showEditResourceDialog(Resource resource) {
    // TODO: Implement edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit ${resource.name}')),
    );
  }

  void _confirmDeleteResource(Resource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resource'),
        content: Text('Are you sure you want to delete "${resource.name}"?'),
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
      try {
        await _resourceService.deleteResource(resource.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resource deleted successfully')),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting resource: $e')),
          );
        }
      }
    }
  }
}
