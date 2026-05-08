import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/services/department_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/screens/inapp_webview_screen.dart';
import 'package:pastor_report/utils/theme_helper.dart';
import 'package:pastor_report/utils/web_wrapper.dart';

class DepartmentsListScreen extends StatefulWidget {
  const DepartmentsListScreen({super.key});

  @override
  State<DepartmentsListScreen> createState() => _DepartmentsListScreenState();
}

class _DepartmentsListScreenState extends State<DepartmentsListScreen> {
  String _searchQuery = '';
  bool _showInactive = false;

  /// Keep bright colors vibrant - no brightening needed for CMYK colors
  Color _brightenColor(Color color) {
    return color; // Return original bright color without modification
  }

  Color _getIconColor(Color? bgColor, BuildContext context) {
    if (bgColor == null) return context.primaryColor;
    final luminance = bgColor.computeLuminance();
    return luminance > 0.7 ? context.inverseSurface : context.primaryColor;
  }
  
  // Determine text color based on background to ensure readability
  Color _getTextColorForBackground(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    // If background is bright, use dark text; if background is dark, use light text
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  // Handle department tap - check auth first
  Future<void> _handleDepartmentTap(Department department, List<Department> allDepartments) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // If not authenticated, show login dialog
    if (!authProvider.isAuthenticated) {
      final shouldLogin = await _showLoginPrompt();
      if (shouldLogin == true && mounted) {
        // Navigate to sign in screen
        final result = await Navigator.pushNamed(context, '/login');

        // If login successful, navigate to department
        if (result == true && mounted) {
          _navigateToDepartment(department, allDepartments);
        }
      }
    } else {
      // Already authenticated, navigate directly
      _navigateToDepartment(department, allDepartments);
    }
  }

  Future<bool?> _showLoginPrompt() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text('Login Required'),
          ],
        ),
        content: const Text(
          'You need to sign in to access department forms.\n\nWould you like to login now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _navigateToDepartment(Department department, List<Department> allDepartments) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InAppWebViewScreen(
          initialUrl: department.formUrl,
          initialDepartmentName: department.name,
          departments: allDepartments
              .map((dept) => {
                    'name': dept.name,
                    'icon': Department.getIconString(dept.icon),
                    'link': dept.formUrl,
                  })
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userMission = authProvider.user?.mission;

    return Scaffold(
      body: WebWrapper(child: RefreshIndicator(
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
      )),
    );
  }

  Widget _buildModernAppBar(String? userMission) {
    final missionName = userMission != null
        ? MissionService().getMissionNameById(userMission)
        : 'All Missions';

    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Departments',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    missionName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 20,
              child: Icon(
                Icons.dashboard,
                size: 150,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              top: 60,
              right: 16,
              child: StreamBuilder<List<Department>>(
                stream: DepartmentService().getDepartmentsStream(mission: userMission),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$count Dept${count != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search departments...',
        prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      },
    );
  }

  Widget _buildToggleBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              'Active Only',
              !_showInactive,
              () => setState(() => _showInactive = false),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              'Show All',
              _showInactive,
              () => setState(() => _showInactive = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentGrid(String? userMission) {
    return StreamBuilder<List<Department>>(
      stream: DepartmentService().getDepartmentsStream(mission: userMission),
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
                  Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final allDepartments = snapshot.data ?? [];

        // Filter departments
        var filteredDepartments = allDepartments.where((dept) {
          final matchesSearch = _searchQuery.isEmpty ||
              dept.name.toLowerCase().contains(_searchQuery);
          final matchesActiveFilter = _showInactive || dept.isActive;
          return matchesSearch && matchesActiveFilter;
        }).toList();

        if (filteredDepartments.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isNotEmpty ? Icons.search_off : Icons.dashboard,
                    size: 64,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No results found for "$_searchQuery"'
                        : 'No departments found',
                    style: TextStyle(fontSize: 18, color: Theme.of(context).textTheme.bodySmall?.color),
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
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dept = filteredDepartments[index];
                return _buildDepartmentCard(dept, allDepartments);
              },
              childCount: filteredDepartments.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentCard(Department dept, List<Department> allDepartments) {
    final cardColor = _brightenColor(dept.color ?? Theme.of(context).cardColor);

    return GestureDetector(
      onTap: () => _handleDepartmentTap(dept, allDepartments),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Inactive badge
            if (!dept.isActive)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_circle, size: 12, color: Theme.of(context).colorScheme.onError),
                      const SizedBox(width: 4),
                      Text(
                        'Inactive',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      dept.icon,
                      size: 24,
                      color: _getIconColor(dept.color, context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Name
                  Text(
                    dept.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getTextColorForBackground(cardColor),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
