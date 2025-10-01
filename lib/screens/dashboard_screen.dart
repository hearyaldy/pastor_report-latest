import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/providers/mission_provider.dart';
import 'package:pastor_report/models/department_model.dart';
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

    // Use a post-frame callback to safely access the context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Check if widget is still in the tree

      try {
        // Safe provider access
        final missionProvider =
            Provider.of<MissionProvider>(context, listen: false);
        missionProvider.initialize();

        // Load departments for the user's mission
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userMission = authProvider.user?.mission;
        if (userMission != null && userMission.isNotEmpty) {
          missionProvider.loadDepartments(missionName: userMission);
        }
      } catch (e) {
        debugPrint('Error initializing providers: $e');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Use try-catch to safely handle dependencies
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final missionProvider =
          Provider.of<MissionProvider>(context, listen: false);
      final userMission = authProvider.user?.mission;

      // Reload departments if user's mission changes
      if (userMission != null && userMission.isNotEmpty) {
        missionProvider.loadDepartments(missionName: userMission);
      }
    } catch (e) {
      // Providers might not be ready yet
      debugPrint('Providers not ready in didChangeDependencies: $e');
    }
  }

  // Handle department tap - check auth first
  Future<void> _handleDepartmentTap(Department department) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // If not authenticated, show login dialog
    if (!authProvider.isAuthenticated) {
      final shouldLogin = await _showLoginPrompt();
      if (shouldLogin == true && mounted) {
        // Navigate to sign in screen
        final result = await Navigator.pushNamed(context, '/login');

        // If login successful, navigate to department
        if (result == true && mounted) {
          _navigateToDepartment(department);
        }
      }
    } else {
      // Already authenticated, navigate directly
      _navigateToDepartment(department);
    }
  }

  // Show loading indicator for reseeding departments
  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reseeding departments...'),
              ],
            ),
          ),
        ),
      ),
    );
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

  void _navigateToDepartment(Department department) {
    final missionProvider =
        Provider.of<MissionProvider>(context, listen: false);

    // Get all departments from the mission provider
    final departments = missionProvider.departments;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InAppWebViewScreen(
          initialUrl: department.formUrl,
          initialDepartmentName: department.name,
          departments: departments
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

          // Department Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: Consumer2<AuthProvider, MissionProvider>(
              builder: (context, authProvider, missionProvider, child) {
                // Get user's mission for filtering
                final userMission = authProvider.user?.mission;

                // We don't call loadDepartments here anymore, it's moved to initState

                // Check if mission provider is still loading
                if (missionProvider.isLoading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // Convert to builder format
                return Builder(
                  builder: (context) {
                    // No need to check isLoading again as we already did above

                    if (missionProvider.errorMessage != null) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${missionProvider.errorMessage}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => setState(() {
                                  if (userMission != null) {
                                    missionProvider.loadDepartments(
                                        missionName: userMission);
                                  }
                                }),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final departmentList = missionProvider.departments;
                    if (departmentList.isEmpty) {
                      String message = 'No departments available';
                      String subtitle = 'Please contact the administrator';

                      // If user has a mission, make the message more specific
                      if (userMission != null && userMission.isNotEmpty) {
                        message =
                            'No departments found for "$userMission" mission';
                        subtitle =
                            'Please contact your mission administrator to set up departments for your mission';

                        // Add debug button for admins
                        if (authProvider.isAdmin) {
                          subtitle += '\n\nAdmin: Tap to reseed departments';
                        }
                      } else {
                        message = 'No mission assigned to your account';
                        subtitle =
                            'Please contact an administrator to assign you to a mission';

                        // Show user details for debugging
                        if (authProvider.isAdmin) {
                          subtitle +=
                              '\n\nUser email: ${authProvider.user?.email}';
                        }
                      }

                      final children = <Widget>[
                        const Icon(Icons.dashboard,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          style:
                              const TextStyle(fontSize: 18, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ];

                      // Add admin reseed button if user is admin
                      if (authProvider.isAdmin) {
                        children.addAll([
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reseed All Departments'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              try {
                                // Show loading
                                _showLoading(context);

                                // Get mission provider
                                final missionProvider =
                                    Provider.of<MissionProvider>(context,
                                        listen: false);

                                // Reseed all data using mission provider
                                await missionProvider.reseedAllData();

                                // Show success
                                if (context.mounted) {
                                  Navigator.pop(
                                      context); // Remove loading dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Missions and departments have been successfully reseeded!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  setState(() {}); // Refresh the screen
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(
                                      context); // Remove loading dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ]);
                      }

                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: children,
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
                                onTap: () => _handleDepartmentTap(department),
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
    if (!department.isActive || department.formUrl.isEmpty) {
      return Colors.red;
    }

    if (department.lastUpdated == null) return Colors.orange;

    final daysSinceUpdate =
        DateTime.now().difference(department.lastUpdated!).inDays;

    if (daysSinceUpdate > 30) {
      return Colors.red; // Not updated for a month
    } else if (daysSinceUpdate > 7) {
      return Colors.orange; // Not updated for a week
    } else {
      return Colors.green; // Recently updated
    }
  }

  String _getStatusText() {
    if (!department.isActive) return 'Inactive';

    if (department.formUrl.isEmpty) return 'No Link';

    if (department.lastUpdated == null) return 'Not Updated';

    final daysSinceUpdate =
        DateTime.now().difference(department.lastUpdated!).inDays;

    if (daysSinceUpdate > 30) {
      return 'Outdated';
    } else if (daysSinceUpdate > 7) {
      return 'Check Link';
    } else {
      return 'Active';
    }
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
                          Icons.circle,
                          size: 8,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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
