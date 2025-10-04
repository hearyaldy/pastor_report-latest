import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/models/todo_model.dart';
import 'package:pastor_report/models/appointment_model.dart';
import 'package:pastor_report/models/event_model.dart';
import 'package:pastor_report/models/activity_model.dart';
import 'package:pastor_report/services/optimized_data_service.dart';
import 'package:pastor_report/services/todo_storage_service.dart';
import 'package:pastor_report/services/appointment_storage_service.dart';
import 'package:pastor_report/services/event_service.dart';
import 'package:pastor_report/services/activity_storage_service.dart';
import 'package:pastor_report/screens/inapp_webview_screen.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickTodoController = TextEditingController();
  String _searchQuery = '';
  bool _showQuickAddActivity = false;
  bool _showStorageWarning = false;
  String _calendarView = 'appointments'; // 'appointments' or 'events'

  @override
  void initState() {
    super.initState();
    // No longer need to load departments manually - using Firestore streams
  }

  // Stream departments with caching - uses OptimizedDataService
  Stream<List<Department>> _getDepartmentsStream(String missionName) {
    return OptimizedDataService.instance
        .streamDepartmentsByMissionName(missionName);
  }

  // Handle department tap - check auth first
  Future<void> _handleDepartmentTap(
      Department department, List<Department> allDepartments) async {
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

  void _navigateToDepartment(
      Department department, List<Department> allDepartments) {
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddActivityBottomSheet,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        tooltip: 'Quick Add Activity',
        child: const Icon(Icons.add),
      ),
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
                          Colors.black.withValues(alpha: 0.7),
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Role Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(user),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(_getRoleIcon(user),
                                                size: 12, color: Colors.white),
                                            const SizedBox(width: 4),
                                            Text(
                                              user.roleString.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Premium Badge
                                      if (user.isPremium) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star,
                                                  size: 12,
                                                  color: Colors.white),
                                              SizedBox(width: 4),
                                              Text(
                                                'PREMIUM',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
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
                                color: Colors.black.withValues(alpha: 0.1),
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

          // My Activities Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        'My Activities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Info icon button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showStorageWarning = !_showStorageWarning;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Collapsible info box
                  AnimatedCrossFade(
                    firstChild: const SizedBox(height: 0),
                    secondChild: Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All data is saved locally and will be lost if app is deleted. Back up to cloud for safekeeping.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: _showStorageWarning
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                        bottom: Radius.circular(16),
                      ),
                      onTap: () {
                        setState(() {
                          _showQuickAddActivity = !_showQuickAddActivity;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.event_note,
                                size: 32,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Daily Activity Log',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showQuickAddActivity
                                        ? 'Tap to collapse'
                                        : 'Tap to add or view activities',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _showQuickAddActivity
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 24,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showQuickAddActivity)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          children: [
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade700.withValues(alpha: 0.1),
                                          Colors.blue.shade100,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        // Use our new bottom sheet
                                        _showQuickAddActivityBottomSheet();
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Quick Add'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryLight.withValues(alpha: 0.1),
                                          Colors.blue.shade50,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                            context, '/activities');
                                      },
                                      icon: const Icon(Icons.list),
                                      label: const Text('View All'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryLight,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        side: BorderSide(
                                          color: AppColors.primaryLight,
                                          width: 1.5,
                                        ),
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
                  ],
                ),
              ),
            ),
          ),

          // My Todos Section
          _buildTodosSection(),

          // Calendar Section (combined Appointments and Events)
          _buildAppointmentsSection(),

          // Recent Activities Section
          _buildRecentActivitiesSection(),

          // Department Reports Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Department Reports',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
              ),
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
                          const Icon(Icons.dashboard,
                              size: 64, color: Colors.grey),
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
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
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
                              const Icon(Icons.dashboard,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No departments found for "$userMission" mission',
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.grey),
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

                    // Show only first 4 departments on dashboard
                    final displayDepartments =
                        filteredDepartments.take(4).toList();
                    final hasMore = filteredDepartments.length > 4;

                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Department grid - show max 4
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
                            itemCount: displayDepartments.length,
                            itemBuilder: (context, index) {
                              final department = displayDepartments[index];
                              return _DepartmentCard(
                                department: department,
                                onTap: () => _handleDepartmentTap(
                                    department, departmentList),
                              );
                            },
                          ),
                          // View All Departments link
                          if (hasMore) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/departments');
                                },
                                icon: const Icon(Icons.grid_view),
                                label: Text(
                                  'View All Departments (${filteredDepartments.length})',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
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

  // Build Todos Section
  Widget _buildTodosSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.blue.shade100.withValues(alpha: 0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.checklist,
                          color: Colors.blue.shade700, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'My Todos',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () => Navigator.pushNamed(context, '/todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick Entry Text Field
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: TextField(
                          controller: _quickTodoController,
                          decoration: InputDecoration(
                            hintText: 'Add a quick todo...',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: _addQuickTodo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.add_task, color: Colors.blue.shade700),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        // Add the todo and clear the field
                        _addQuickTodo(_quickTodoController.text);
                        _quickTodoController.clear();
                        FocusScope.of(context).unfocus();
                      },
                      tooltip: 'Add Todo',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Todo>>(
                  future: TodoStorageService.instance.getTodos(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No todos yet. Tap + to add one!',
                          style: TextStyle(color: Colors.grey));
                    }
                    final incompleteTodos = snapshot.data!
                        .where((t) => !t.isCompleted)
                        .take(3)
                        .toList();
                    if (incompleteTodos.isEmpty) {
                      return const Text('All done! 🎉',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500));
                    }
                    return Column(
                      children: incompleteTodos.map((todo) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.circle_outlined,
                                  size: 16, color: Colors.blue.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(todo.content,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (todo.priority == 2) // High priority
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('!',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/todos'),
                  child: const Text('View All Todos →'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build Calendar Section (combined Appointments and Events)
  Widget _buildAppointmentsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.indigo.shade50,
                  Colors.indigo.shade100.withValues(alpha: 0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.event,
                          color: Colors.indigo.shade700, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Calendar',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Add button with popup menu for events/appointments
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.add_circle, color: Colors.indigo),
                      tooltip: 'Add to Calendar',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        Navigator.pushNamed(context, '/calendar');
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'appointment',
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today),
                              SizedBox(width: 8),
                              Text('Add Appointment'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'event',
                          child: Row(
                            children: [
                              Icon(Icons.event),
                              SizedBox(width: 8),
                              Text('Add Event'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Segmented control for toggling between appointments and events
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      // Appointments tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _calendarView = 'appointments';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _calendarView == 'appointments'
                                  ? Colors.indigo.shade100
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: _calendarView == 'appointments'
                                      ? Colors.indigo.shade700
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Appointments',
                                  style: TextStyle(
                                    fontWeight: _calendarView == 'appointments'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _calendarView == 'appointments'
                                        ? Colors.indigo.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Events tab
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _calendarView = 'events';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _calendarView == 'events'
                                  ? Colors.indigo.shade100
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 16,
                                  color: _calendarView == 'events'
                                      ? Colors.indigo.shade700
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Events',
                                  style: TextStyle(
                                    fontWeight: _calendarView == 'events'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _calendarView == 'events'
                                        ? Colors.indigo.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Content based on selected view
                if (_calendarView == 'appointments')
                  FutureBuilder<List<Appointment>>(
                    future:
                        AppointmentStorageService.instance.getAppointments(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No appointments scheduled',
                            style: TextStyle(color: Colors.grey));
                      }
                      final upcoming = snapshot.data!
                          .where((a) => a.dateTime.isAfter(DateTime.now()))
                          .take(2)
                          .toList();
                      if (upcoming.isEmpty) {
                        return const Text('No upcoming appointments',
                            style: TextStyle(color: Colors.grey));
                      }
                      return Column(
                        children: upcoming.map((appt) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 16, color: Colors.orange.shade400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(appt.title,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          DateFormat('MMM dd, h:mm a')
                                              .format(appt.dateTime),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/calendar');
                  },
                  child: const Text('View Full Calendar →'),
                ),

                // Events view
                if (_calendarView == 'events')
                  FutureBuilder<List<Event>>(
                    future: EventService.instance.getAllEvents(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No upcoming events',
                            style: TextStyle(color: Colors.grey));
                      }
                      final upcoming = snapshot.data!
                          .where((e) => e.startDate.isAfter(DateTime.now()))
                          .take(2)
                          .toList();
                      if (upcoming.isEmpty) {
                        return const Text('No upcoming events',
                            style: TextStyle(color: Colors.grey));
                      }
                      return Column(
                        children: upcoming.map((event) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getEventIcon(event.title),
                                    color: Colors.indigo.shade700,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy • h:mm a')
                                            .format(event.startDate),
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (event.location != null &&
                                          event.location!.isNotEmpty)
                                        Text(
                                          event.location!,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get appropriate icon for event based on title keywords
  IconData _getEventIcon(String title) {
    final lowercaseTitle = title.toLowerCase();

    if (lowercaseTitle.contains('meeting') ||
        lowercaseTitle.contains('fellowship')) {
      return Icons.group;
    } else if (lowercaseTitle.contains('service') ||
        lowercaseTitle.contains('worship') ||
        lowercaseTitle.contains('prayer')) {
      return Icons.church;
    } else if (lowercaseTitle.contains('conference') ||
        lowercaseTitle.contains('seminar')) {
      return Icons.business_center;
    } else if (lowercaseTitle.contains('class') ||
        lowercaseTitle.contains('training') ||
        lowercaseTitle.contains('workshop')) {
      return Icons.school;
    } else if (lowercaseTitle.contains('celebration') ||
        lowercaseTitle.contains('party')) {
      return Icons.celebration;
    } else if (lowercaseTitle.contains('outreach') ||
        lowercaseTitle.contains('mission')) {
      return Icons.public;
    } else {
      return Icons.event;
    }
  }

  // Build Events Section - This method is kept for reference
  @pragma('vm:prefer-inline')
  Widget _buildEventsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade50,
                  Colors.purple.shade100.withValues(alpha: 0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade200),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.event,
                          color: Colors.purple.shade700, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Upcoming Events',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.purple),
                      onPressed: () => Navigator.pushNamed(context, '/events'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Event>>(
                  future: EventService.instance.getAllEvents(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No upcoming events',
                          style: TextStyle(color: Colors.grey));
                    }
                    final upcoming = snapshot.data!
                        .where((e) => e.startDate.isAfter(DateTime.now()))
                        .take(2)
                        .toList();
                    if (upcoming.isEmpty) {
                      return const Text('No upcoming events',
                          style: TextStyle(color: Colors.grey));
                    }
                    return Column(
                      children: upcoming.map((event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(event.isGlobal ? Icons.public : Icons.event,
                                  size: 16,
                                  color: event.isGlobal
                                      ? Colors.purple.shade700
                                      : Colors.purple.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(event.title,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        DateFormat('MMM dd, yyyy')
                                            .format(event.startDate),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              if (event.isGlobal)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Global',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.purple,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/events'),
                  child: const Text('View All Events →'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build Recent Activities Section
  Widget _buildRecentActivitiesSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade50,
                  Colors.green.shade100.withValues(alpha: 0.3)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.history,
                          color: Colors.green.shade700, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'My Recent Activities',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showStorageWarning = !_showStorageWarning;
                              });
                            },
                            child: Icon(Icons.info_outline,
                                size: 18, color: Colors.amber.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_showStorageWarning) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Data saved locally. Back up to cloud for safekeeping.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FutureBuilder<List<Activity>>(
                  future: ActivityStorageService.instance.getActivities(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No activities logged yet',
                          style: TextStyle(color: Colors.grey));
                    }
                    final recent = snapshot.data!.take(5).toList();
                    return Column(
                      children: recent.map((activity) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 12, color: Colors.green.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(activity.activities,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        DateFormat('MMM dd, yyyy')
                                            .format(activity.date),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/activities'),
                  child: const Text('View All Activities →'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(UserModel user) {
    switch (user.userRole) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.admin:
        return Colors.red;
      case UserRole.missionAdmin:
        return Colors.blue;
      case UserRole.editor:
        return Colors.orange;
      case UserRole.user:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(UserModel user) {
    switch (user.userRole) {
      case UserRole.superAdmin:
        return Icons.verified_user;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.missionAdmin:
        return Icons.business;
      case UserRole.editor:
        return Icons.edit;
      case UserRole.user:
        return Icons.person;
    }
  }

  // Helper method to get appropriate icon for each activity type
  Widget _getActivityTypeIcon(String activityType) {
    IconData iconData;
    Color iconColor;

    switch (activityType) {
      case 'Visitation':
        iconData = Icons.home;
        iconColor = Colors.green;
        break;
      case 'Bible Study':
        iconData = Icons.book;
        iconColor = Colors.blue;
        break;
      case 'Prayer Meeting':
        iconData = Icons.people;
        iconColor = Colors.indigo;
        break;
      case 'Wedding':
        iconData = Icons.favorite;
        iconColor = Colors.pink;
        break;
      case 'Funeral':
        iconData = Icons.assistant;
        iconColor = Colors.grey;
        break;
      case 'Counseling':
        iconData = Icons.psychology;
        iconColor = Colors.purple;
        break;
      case 'Other':
      default:
        iconData = Icons.event_note;
        iconColor = Colors.orange;
        break;
    }

    return Icon(iconData, size: 20, color: iconColor);
  }

  // Handle quick todo entry from dashboard
  Future<void> _addQuickTodo(String content) async {
    if (content.trim().isEmpty) return;

    // Create a new Todo with medium priority by default
    final newTodo = Todo(
      id: const Uuid().v4(),
      content: content.trim(),
      createdAt: DateTime.now(),
      priority: 1, // Medium priority
    );

    await TodoStorageService.instance.saveTodo(newTodo);

    // Clear the input field if called from onSubmitted
    if (_quickTodoController.text == content) {
      _quickTodoController.clear();
    }

    // Show confirmation and refresh the UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Todo added: ${newTodo.content}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View All',
            onPressed: () => Navigator.pushNamed(context, '/todos'),
          ),
        ),
      );

      // Need to refresh the todos list
      setState(() {
        // This will cause the FutureBuilder to rebuild with new data
      });
    }
  } // Show bottom sheet for quick activity entry

  void _showQuickAddActivityBottomSheet() {
    final activityController = TextEditingController();
    final mileageController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    final locationController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedActivityType = 'Other'; // Default activity type

    // Define activity types
    final activityTypes = [
      'Visitation',
      'Bible Study',
      'Prayer Meeting',
      'Wedding',
      'Funeral',
      'Counseling',
      'Other'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.event_note,
                        color: AppColors.primaryLight, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Quick Add Activity',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 18, color: AppColors.primaryLight),
                        const SizedBox(width: 8),
                        Text(
                          'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Activity field with integrated dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label for the entire field
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Activity',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // Activity Type Dropdown (without border)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedActivityType,
                          hint: const Text('Select Activity Type'),
                          icon: Icon(Icons.arrow_drop_down,
                              color: AppColors.primaryLight),
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedActivityType = newValue;

                                // Always prefill the activity field with the selected type as a hint
                                if (newValue == 'Other') {
                                  // For "Other", just keep empty
                                  activityController.text = '';
                                } else {
                                  // For specific activity types, set an appropriate prompt
                                  String prompt = '';
                                  switch (newValue) {
                                    case 'Visitation':
                                      prompt = 'Visitation to ';
                                      break;
                                    case 'Bible Study':
                                      prompt = 'Bible Study on ';
                                      break;
                                    case 'Prayer Meeting':
                                      prompt = 'Prayer Meeting with ';
                                      break;
                                    case 'Wedding':
                                      prompt = 'Wedding of ';
                                      break;
                                    case 'Funeral':
                                      prompt = 'Funeral service for ';
                                      break;
                                    case 'Counseling':
                                      prompt = 'Counseling session with ';
                                      break;
                                    default:
                                      prompt = '';
                                  }
                                  activityController.text = prompt;
                                  activityController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: activityController.text.length),
                                  );
                                }
                              });
                            }
                          },
                          items: activityTypes
                              .map<DropdownMenuItem<String>>((String type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Row(
                                children: [
                                  _getActivityTypeIcon(type),
                                  const SizedBox(width: 12),
                                  Text(
                                    type,
                                    style: TextStyle(
                                      color: type == selectedActivityType
                                          ? AppColors.primaryLight
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Activity Details Field
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: TextField(
                        controller: activityController,
                        decoration: InputDecoration(
                          hintText: selectedActivityType == 'Other'
                              ? 'Enter your activity'
                              : 'Details about ${selectedActivityType.toLowerCase()}',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12), // Mileage Field
                TextField(
                  controller: mileageController,
                  decoration: const InputDecoration(
                    labelText: 'Mileage',
                    hintText: 'Enter distance in km',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick access row for location and notes
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Save Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    // Validation
                    if (activityController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter activity details')),
                      );
                      return;
                    }

                    try {
                      final mileage =
                          double.tryParse(mileageController.text) ?? 0.0;

                      // Format activity text to include the activity type
                      final String formattedActivity;

                      // Check if the activity already starts with the activity type
                      if (selectedActivityType == 'Other') {
                        formattedActivity = activityController.text.trim();
                      } else if (activityController.text
                              .startsWith('$selectedActivityType to ') ||
                          activityController.text
                              .startsWith('$selectedActivityType on ') ||
                          activityController.text
                              .startsWith('$selectedActivityType with ') ||
                          activityController.text
                              .startsWith('$selectedActivityType of ') ||
                          activityController.text
                              .startsWith('$selectedActivityType for ') ||
                          activityController.text
                              .startsWith('$selectedActivityType session ')) {
                        // If the text already includes the activity type in a natural way, keep it as is
                        formattedActivity = activityController.text.trim();
                      } else {
                        // Otherwise add the activity type in brackets as a prefix
                        formattedActivity =
                            '[$selectedActivityType] ${activityController.text.trim()}';
                      }

                      // Create activity object
                      final activity = Activity(
                        id: const Uuid().v4(),
                        date: selectedDate,
                        activities: formattedActivity,
                        mileage: mileage,
                        note: noteController.text.trim(),
                        location: locationController.text.trim().isEmpty
                            ? null
                            : locationController.text.trim(),
                        createdAt: DateTime.now(),
                      );

                      // Save the activity
                      final success = await ActivityStorageService.instance
                          .addActivity(activity);

                      if (success && context.mounted) {
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '$selectedActivityType activity added successfully'),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'View All',
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/activities'),
                            ),
                          ),
                        );

                        // Refresh UI if needed
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  },
                  child: const Text('SAVE ACTIVITY'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quickTodoController.dispose();
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
                cardColor.withValues(alpha: 0.7),
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
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
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
