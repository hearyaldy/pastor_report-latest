import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/services/optimized_data_service.dart';
import 'package:pastor_report/screens/inapp_webview_screen.dart';
import 'package:pastor_report/utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // No longer need to load departments manually - using Firestore streams
  }

  // Stream departments with caching - uses OptimizedDataService
  Stream<List<Department>> _getDepartmentsStream(String missionName) {
    return OptimizedDataService.instance.streamDepartmentsByMissionName(missionName);
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
            Icon(Icons.lock_outline, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            const Text('Login Required'),
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
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryLight,
            actions: [
              // Settings button for all users
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                tooltip: 'Settings',
              ),
              // Login button for non-authenticated users
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (!authProvider.isAuthenticated) {
                    return TextButton.icon(
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text('Login',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Avatar for authenticated users
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.isAuthenticated) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          (authProvider.user!.displayName.isNotEmpty
                                  ? authProvider.user!.displayName[0]
                                  : 'U')
                              .toUpperCase(),
                          style: TextStyle(color: AppColors.primaryLight),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Header Image
                  Image.asset(
                    'assets/images/header_image.png',
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Welcome Text and Search
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            if (authProvider.isAuthenticated) {
                              final user = authProvider.user!;
                              // Build location info string
                              List<String> locationParts = [];
                              if (user.mission != null &&
                                  user.mission!.isNotEmpty) {
                                locationParts.add(user.mission!);
                              }
                              if (user.district != null &&
                                  user.district!.isNotEmpty) {
                                locationParts.add(user.district!);
                              }
                              if (user.region != null &&
                                  user.region!.isNotEmpty) {
                                locationParts.add(user.region!);
                              }
                              final locationInfo = locationParts.join(' • ');

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    user.displayName.isNotEmpty
                                        ? user.displayName
                                        : 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (user.role != null &&
                                      user.role!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.badge_outlined,
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          user.role!,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (locationInfo.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.white70,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            locationInfo,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            } else {
                              return const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome to',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Digital Ministry',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search departments...',
                              prefixIcon: Icon(Icons.search),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Mission Indicator - Under header image
          SliverToBoxAdapter(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final userMission = authProvider.user?.mission;
                if (userMission == null || userMission.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Mission',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userMission,
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Department Grid - Using Firestore StreamBuilder
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                // Get user's mission for filtering
                final userMission = authProvider.user?.mission;

                // If no mission assigned, show message
                if (userMission == null || userMission.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.dashboard, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No mission assigned to your account',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please contact an administrator to assign you to a mission${authProvider.isAdmin ? "\n\nUser email: ${authProvider.user?.email}" : ""}',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Stream departments from Firestore for user's mission
                return StreamBuilder<List<Department>>(
                  stream: _getDepartmentsStream(userMission),
                  builder: (context, snapshot) {
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

                    if (!snapshot.hasData) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final departmentList = snapshot.data!;
                    if (departmentList.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.dashboard, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No departments found for "$userMission" mission',
                                style: const TextStyle(fontSize: 18, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please contact your mission administrator to set up departments',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Apply search filter to departments
                    final filteredDepartments = _searchQuery.isEmpty
                        ? departmentList
                        : departmentList
                            .where((dept) => dept.name
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                            .toList();

                    // Prepare to show departments with optional warning banner

                    if (filteredDepartments.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No results found for "$_searchQuery"',
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Use SliverList for the banner and SliverGrid for departments
                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mission-specific departments are enforced at service level

                          // Department grid in a non-scrollable grid view
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.1,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filteredDepartments.length,
                            itemBuilder: (context, index) {
                              final department = filteredDepartments[index];
                              return _DepartmentCard(
                                department: department,
                                onTap: () => _handleDepartmentTap(department, departmentList),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _DepartmentCard extends StatelessWidget {
  final Department department;
  final VoidCallback onTap;

  const _DepartmentCard({
    required this.department,
    required this.onTap,
  });

  String _getLastUpdatedText() {
    if (department.lastUpdated == null) return 'Never updated';

    final now = DateTime.now();
    final difference = now.difference(department.lastUpdated!);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Recently updated';
    }
  }

  Color _getStatusColor() {
    // Red for inactive or no link
    // Priority: isActive status first
    if (!department.isActive) {
      return Colors.red.shade700; // Inactive - Red
    }

    // If active, show green
    return Colors.green.shade600; // Active - Green
  }

  String _getStatusText() {
    // Simple active/inactive status
    if (!department.isActive) {
      return 'INACTIVE';
    }

    return 'ACTIVE';
  }

  IconData _getStatusIcon() {
    if (!department.isActive) {
      return Icons.cancel; // X icon for inactive
    }

    return Icons.check_circle; // Check icon for active
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = department.color ?? AppColors.cardBackground;
    final statusColor = _getStatusColor();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardColor,
                cardColor.withOpacity(0.7),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Icon and Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      department.icon,
                      color: AppColors.primaryLight,
                      size: 24,
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(),
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Department Name
              Flexible(
                child: Text(
                  department.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              // Last Updated Info
              Row(
                children: [
                  Icon(
                    Icons.update,
                    size: 10,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getLastUpdatedText(),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
