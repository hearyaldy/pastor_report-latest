import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/models/todo_model.dart';
import 'package:pastor_report/models/appointment_model.dart';
import 'package:pastor_report/models/event_model.dart';
import 'package:pastor_report/models/activity_model.dart';
import 'package:pastor_report/models/borang_b_model.dart';
import 'package:pastor_report/models/church_model.dart';
import 'package:pastor_report/services/optimized_data_service.dart';
import 'package:pastor_report/services/todo_storage_service.dart';
import 'package:pastor_report/services/appointment_storage_service.dart';
import 'package:pastor_report/services/event_service.dart';
import 'package:pastor_report/services/activity_storage_service.dart';
import 'package:pastor_report/services/borang_b_firestore_service.dart';
import 'package:pastor_report/services/church_service.dart';
import 'package:pastor_report/services/staff_service.dart';
import 'package:pastor_report/services/mission_service.dart';
import 'package:pastor_report/services/profile_picture_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/utils/theme_colors.dart';
import 'package:pastor_report/utils/web_wrapper.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

class ImprovedDashboardScreen extends StatefulWidget {
  const ImprovedDashboardScreen({super.key});

  @override
  State<ImprovedDashboardScreen> createState() =>
      _ImprovedDashboardScreenState();
}

class _ImprovedDashboardScreenState extends State<ImprovedDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _mileageController =
      TextEditingController(text: '0');
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _searchQuery = '';
  bool _showQuickActions = false;
  String _quickActionTab = 'activity'; // 'activity' or 'todo'
  int _selectedTodoPriority = 1; // 0: Low, 1: Medium, 2: High
  DateTime _selectedActivityDate = DateTime.now();
  String _selectedActivityType = 'Other';
  String? _profilePicturePath;

  // Cache for department data to prevent multiple API calls
  static final Map<String, List<Department>> _departmentCache = {};
  static final Map<String, DateTime> _departmentCacheTime = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Cache for other frequently accessed data
  static final Map<String, Object> _generalCache = {};
  static final Map<String, DateTime> _generalCacheTime = {};

  // Cached futures to prevent recreation on rebuilds
  Future<List<Todo>>? _cachedTodosFuture;
  Future<List<dynamic>>? _cachedAppointmentsFuture;
  DateTime? _lastTodosLoad;
  DateTime? _lastAppointmentsLoad;
  static const Duration _futureCacheDuration = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  // Load profile picture from local storage
  Future<void> _loadProfilePicture() async {
    final path = await ProfilePictureService.instance.getProfilePicturePath();
    if (mounted) {
      setState(() {
        _profilePicturePath = path;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _todoController.dispose();
    _activityController.dispose();
    _mileageController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static const double _maxDashboardWidth = 1100.0;

  Widget _constrainContent(Widget child) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 900) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxDashboardWidth),
        child: child,
      ),
    );
  }

  Stream<List<Department>> _getDepartmentsStream(String missionIdOrName) {
    // Accept either mission ID or mission name
    // Only log when actually needed for debugging
    // print('Dashboard: Fetching departments for mission: $missionIdOrName');

    // Special case handling for known problematic IDs
    if (missionIdOrName == '4LFC9isp22H7Og1FHBm6') {
      // Only log when actually needed for debugging
      // print(
      //     'Dashboard: Using special handling for known ID: $missionIdOrName -> Sabah Mission');
      // For this specific ID, we know it should be "Sabah Mission"
    }

    return OptimizedDataService.instance
        .streamDepartmentsByMissionId(missionIdOrName);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isAuthenticated = authProvider.isAuthenticated;

    // Show welcome screen for non-authenticated users
    if (!isAuthenticated) {
      return _buildWelcomeScreen();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: WebWrapper(
        maxWidth: _maxDashboardWidth,
        child: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          _buildModernAppBar(user),

          // Search Bar Section
          SliverToBoxAdapter(
            child: _constrainContent(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSearchBar(),
              ),
            ),
          ),

          // Onboarding incomplete banner
          if (user != null && !user.onboardingCompleted)
            SliverToBoxAdapter(
              child: _constrainContent(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Card(
                    color: Colors.orange.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.orange.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Your profile setup is incomplete.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(
                                context, AppConstants.routeOnboarding),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.orange.shade800),
                            child: const Text('Complete Setup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Quick Stats Overview
          _buildQuickStats(user),

          // Quick Actions (Combined Activity + Todo)
          _buildQuickActionsSection(user),

          // Upcoming Items Section (Todos + Appointments)
          _buildUpcomingSection(),

          // Departments Section
          _buildDepartmentsSection(user),

          // Recent Activities
          _buildRecentActivitiesSection(),

          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    ),
    );
  }

  Widget _buildModernAppBar(UserModel? user) {
    return SliverAppBar(
      expandedHeight: 160, // Increased from 150 to accommodate content
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: context.colors.primary,
      actions: [
        if (user != null) ...[
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider.signOut();

                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppConstants.routeWelcome,
                    (route) => false,
                  );
                }
              }
            },
            tooltip: 'Logout',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.colors.primaryGradient,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (user != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).cardColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 6),
                              _buildRoleBadge(user),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          backgroundImage: _profilePicturePath != null
                              ? FileImage(File(_profilePicturePath!))
                              : null,
                          child: _profilePicturePath == null
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.primary,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'PastorPro',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).cardColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Church Management System',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: false,
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search departments...',
          hintStyle: TextStyle(color: Theme.of(context).dividerColor),
          prefixIcon: Icon(Icons.search, color: context.colors.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getRoleColor(user),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getRoleIcon(user), size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            user.roleString.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).cardColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(UserModel? user) {
    return SliverToBoxAdapter(
      child: _constrainContent(Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, int>>(
          future: _getQuickStats(user),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final stats = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1024) {
                  // Desktop: 3 or 4 columns depending on screen width
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth > 1200 ? 4 : 3,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return _buildStatCard(
                            'Pending Todos',
                            stats['todos'] ?? 0,
                            Icons.check_circle_outline,
                            Colors.blue,
                          );
                        case 1:
                          return _buildStatCard(
                            'Events',
                            stats['appointments'] ?? 0,
                            Icons.event,
                            Colors.orange,
                          );
                        case 2:
                          return _buildStatCard(
                            'Activities',
                            stats['activities'] ?? 0,
                            Icons.assignment,
                            Colors.green,
                          );
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  );
                } else {
                  // Mobile & tablet: 3 columns in a row
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Pending Todos',
                          stats['todos'] ?? 0,
                          Icons.check_circle_outline,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Events',
                          stats['appointments'] ?? 0,
                          Icons.event,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Activities',
                          stats['activities'] ?? 0,
                          Icons.assignment,
                          Colors.green,
                        ),
                      ),
                    ],
                  );
                }
              },
            );
          },
        ),
      )),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  // Quick Actions Section (Combined Activity + Todo)
  Widget _buildQuickActionsSection(UserModel? user) {
    return SliverToBoxAdapter(
      child: _constrainContent(Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: context.colors.withAlpha(context.colors.primary, 0.3),
                  width: 2,
                ),
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
                        _showQuickActions = !_showQuickActions;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.colors
                                  .withAlpha(context.colors.primary, 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.dashboard_customize,
                              size: 32,
                              color: context.colors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quick Actions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _showQuickActions
                                      ? 'Tap to collapse'
                                      : 'Tap to add activities or todos',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _showQuickActions
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 24,
                            color: context.colors.emptyStateIcon,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showQuickActions)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 12),

                          // Tab Selector - Responsive
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 800) {
                                // On desktop, use horizontal layout with more padding
                                return Row(
                                  children: [
                                    Expanded(
                                      child: _buildTabButton(
                                        'Activity',
                                        Icons.event_note,
                                        'activity',
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTabButton(
                                        'Todo',
                                        Icons.check_circle_outline,
                                        'todo',
                                        Colors.blue,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // On mobile, use vertical layout to save space
                                return Column(
                                  children: [
                                    _buildTabButton(
                                      'Activity',
                                      Icons.event_note,
                                      'activity',
                                      Colors.green,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTabButton(
                                      'Todo',
                                      Icons.check_circle_outline,
                                      'todo',
                                      Colors.blue,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Show Activity Form or Todo Form based on selected tab
                          if (_quickActionTab == 'activity')
                            ..._buildActivityForm(),
                          if (_quickActionTab == 'todo') ..._buildTodoForm(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Borang B Card - Visible to regular users for creating their own reports
          // Super admins and ministerial secretaries can access all reports via the list screen
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 120,
                child: _buildBorangBCard(),
              ),
            ),
            // Ministerial Secretary: View All Reports Card
            if (user.canAccessBorangBReports)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: 120,
                  child: _buildAllBorangBReportsCard(),
                ),
              ),
          ],
          // My Ministry Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 120,
              child: _buildMyMinistryCard(),
            ),
          ),
        ],
      )),
    );
  }

  // Tab Button for Quick Actions
  Widget _buildTabButton(
      String label, IconData icon, String tabValue, Color color) {
    final isSelected = _quickActionTab == tabValue;
    return InkWell(
      onTap: () {
        setState(() {
          _quickActionTab = tabValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Build Activity Form - DUPLICATE REMOVED, KEPT ONLY BELOW

  // Build Todo Form - DUPLICATE REMOVED, KEPT ONLY BELOW

  List<Widget> _buildActivityForm() {
    return [
      // Section Header
      Text(
        'Activity Information',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade800,
        ),
      ),
      const SizedBox(height: 12),

      // Date Picker
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedActivityDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (picked != null) {
            setState(() => _selectedActivityDate = picked);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 18, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Date: ${DateFormat('MMM dd, yyyy').format(_selectedActivityDate)}',
                style: const TextStyle(fontSize: 14),
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Activity Type + Details combined
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: context.colors.outline),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8), topRight: Radius.circular(8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedActivityType,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedActivityType = newValue;
                  if (newValue != 'Other') {
                    _activityController.text = {
                          'Visitation': 'Visitation to ',
                          'Bible Study': 'Bible Study on ',
                          'Prayer Meeting': 'Prayer Meeting with ',
                          'Wedding': 'Wedding of ',
                          'Funeral': 'Funeral service for ',
                          'Counseling': 'Counseling session with ',
                        }[newValue] ??
                        '';
                    _activityController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _activityController.text.length));
                  } else {
                    _activityController.clear();
                  }
                });
              }
            },
            items: [
              'Visitation',
              'Bible Study',
              'Prayer Meeting',
              'Wedding',
              'Funeral',
              'Counseling',
              'Other'
            ].map<DropdownMenuItem<String>>((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Row(
                  children: [
                    _getActivityTypeIcon(type),
                    const SizedBox(width: 8),
                    Text(type, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.outline),
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        child: TextField(
          controller: _activityController,
          autofocus: false,
          decoration: InputDecoration(
            hintText: _selectedActivityType == 'Other'
                ? 'Enter your activity'
                : 'Details about ${_selectedActivityType.toLowerCase()}',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(12),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
      const SizedBox(height: 16),

      // Additional Details Header
      Text(
        'Additional Details',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade800,
        ),
      ),
      const SizedBox(height: 12),

      // Mileage + Location - Responsive
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // On desktop, use side-by-side layout
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _mileageController,
                    autofocus: false,
                    decoration: InputDecoration(
                      labelText: 'Mileage (km)',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _locationController,
                    autofocus: false,
                    decoration: InputDecoration(
                      labelText: 'Location (Optional)',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // On mobile, stack vertically to save horizontal space
            return Column(
              children: [
                TextField(
                  controller: _mileageController,
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText: 'Mileage (km)',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText: 'Location (Optional)',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            );
          }
        },
      ),
      const SizedBox(height: 12),

      // Notes
      TextField(
        controller: _noteController,
        autofocus: false,
        decoration: InputDecoration(
          labelText: 'Notes (Optional)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 12),

      // Buttons - Responsive
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // On desktop, place buttons side by side
            return Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveActivityInline,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Activity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/activities'),
                    icon: const Icon(Icons.list),
                    label: const Text('View All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // On mobile, stack vertically to save space
            return Column(
              children: [
                SizedBox(
                  width: double.infinity, // Full width button
                  child: ElevatedButton.icon(
                    onPressed: _saveActivityInline,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Activity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, // Full width button
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/activities'),
                    icon: const Icon(Icons.list),
                    label: const Text('View All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    ];
  }

  // Build Todo Form
  List<Widget> _buildTodoForm() {
    return [
      // Section Header
      Text(
        'Todo Details',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
      const SizedBox(height: 12),

      // Todo input
      TextField(
        controller: _todoController,
        autofocus: false,
        decoration: InputDecoration(
          hintText: 'Enter your todo item',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),
      const SizedBox(height: 12),

      // Priority
      Row(
        children: [
          Text('Priority:',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(child: _buildInlinePriorityChip('Low', 0, Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildInlinePriorityChip('Medium', 1, Colors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _buildInlinePriorityChip('High', 2, Colors.red)),
        ],
      ),
      const SizedBox(height: 12),

      // Buttons - Responsive
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            // On desktop, place buttons side by side
            return Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveTodoInline,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Todo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/todos'),
                    icon: const Icon(Icons.checklist),
                    label: const Text('View All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // On mobile, stack vertically to save space
            return Column(
              children: [
                SizedBox(
                  width: double.infinity, // Full width button
                  child: ElevatedButton.icon(
                    onPressed: _saveTodoInline,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Todo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, // Full width button
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/todos'),
                    icon: const Icon(Icons.checklist),
                    label: const Text('View All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    ];
  }

  Widget _buildUpcomingSection() {
    return SliverToBoxAdapter(
      child: _constrainContent(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/calendar'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          _buildUpcomingCards(),
        ],
      )),
    );
  }

  Widget _buildUpcomingCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 1024) {
            // Desktop: Grid layout
            return SizedBox(
              height: 250, // Slightly taller for desktop
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.8, // Adjust as needed
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 2,
                itemBuilder: (context, index) {
                  return index == 0 ? _buildTodosCard() : _buildAppointmentsCard();
                },
              ),
            );
          } else {
            // Mobile: Row layout
            return SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(child: _buildTodosCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAppointmentsCard()),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildTodosCard() {
    // Use cached future to prevent recreation on rebuild
    final now = DateTime.now();
    if (_cachedTodosFuture == null || 
        _lastTodosLoad == null || 
        now.difference(_lastTodosLoad!) > _futureCacheDuration) {
      _cachedTodosFuture = TodoStorageService.instance.getTodos();
      _lastTodosLoad = now;
    }

    return FutureBuilder<List<Todo>>(
      future: _cachedTodosFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[400]!,
                  Colors.blue[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading todos...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final incompleteTodos =
            snapshot.data!.where((t) => !t.isCompleted).take(3).toList();

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/todos'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[400]!,
                  Colors.blue[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Theme.of(context).cardColor, size: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${incompleteTodos.length}',
                        style: TextStyle(
                          color: Theme.of(context).cardColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pending Todos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: incompleteTodos.isEmpty
                      ? const Center(
                          child: Text(
                            'No pending todos',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          itemCount: incompleteTodos.length,
                          itemBuilder: (context, index) {
                            final todo = incompleteTodos[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    todo.priority == 2
                                        ? Icons.priority_high
                                        : Icons.circle,
                                    size: 12,
                                    color: Theme.of(context).cardColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      todo.content,
                                      style: TextStyle(
                                        color: Theme.of(context).cardColor,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppointmentsCard() {
    // Use cached future to prevent recreation on rebuild
    final now = DateTime.now();
    if (_cachedAppointmentsFuture == null || 
        _lastAppointmentsLoad == null || 
        now.difference(_lastAppointmentsLoad!) > _futureCacheDuration) {
      _cachedAppointmentsFuture = Future.wait([
        AppointmentStorageService.instance.getAppointments(),
        EventService.instance.getLocalEvents(),
      ]);
      _lastAppointmentsLoad = now;
    }

    return FutureBuilder<List<dynamic>>(
      future: _cachedAppointmentsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange[400]!,
                  Colors.orange[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading events...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final appointments = snapshot.data![0] as List<Appointment>;
        final events = snapshot.data![1] as List<Event>;

        // Combine appointments and events
        final upcomingAppointments = appointments
            .where((a) => a.dateTime.isAfter(DateTime.now()))
            .map((a) =>
                {'type': 'appointment', 'data': a, 'dateTime': a.dateTime})
            .toList();

        final upcomingEvents = events
            .where((e) => e.startDate.isAfter(DateTime.now()))
            .map((e) => {'type': 'event', 'data': e, 'dateTime': e.startDate})
            .toList();

        final upcoming = [...upcomingAppointments, ...upcomingEvents]
          ..sort((a, b) =>
              (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

        final displayItems = upcoming.take(3).toList();

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/calendar'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange[400]!,
                  Colors.orange[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.calendar_today,
                        color: Theme.of(context).cardColor, size: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${displayItems.length}',
                        style: TextStyle(
                          color: Theme.of(context).cardColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Events & Appointments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).cardColor,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: displayItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No upcoming events',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            final item = displayItems[index];
                            final isEvent = item['type'] == 'event';
                            final title = isEvent
                                ? (item['data'] as Event).title
                                : (item['data'] as Appointment).title;
                            final dateTime = item['dateTime'] as DateTime;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    isEvent
                                        ? Icons.event
                                        : Icons.calendar_today,
                                    size: 12,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: Theme.of(context).cardColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          DateFormat('MMM dd, hh:mm a')
                                              .format(dateTime),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBorangBCard() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    return FutureBuilder<BorangBData?>(
      future: BorangBFirestoreService.instance.getReportByUserAndMonth(
        userId,
        DateTime.now().year,
        DateTime.now().month,
      ),
      builder: (context, snapshot) {
        final hasReport = snapshot.hasData && snapshot.data != null;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/borang-b-list'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal[400]!,
                  Colors.teal[600]!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.assignment,
                      color: Theme.of(context).cardColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Borang B - Monthly Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).cardColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasReport
                            ? 'Tap to view/edit report'
                            : 'Tap to create this month\'s report',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasReport ? Icons.check_circle : Icons.add_circle_outline,
                  color: Theme.of(context).cardColor,
                  size: 28,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllBorangBReportsCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/all-borang-b-reports'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange[400]!,
              Colors.orange[600]!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.library_books,
                  color: Theme.of(context).cardColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'All Borang B Reports',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).cardColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'View all submitted reports',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).cardColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyMinistryCard() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userMission = authProvider.user?.mission;
    final userDistrict = authProvider.user?.district;

    return StreamBuilder<List<dynamic>>(
      stream: userMission != null && userMission.isNotEmpty
          ? StaffService.instance.streamStaffByMission(userMission)
          : Stream.value([]),
      builder: (context, staffSnapshot) {
        final staffCount = staffSnapshot.data?.length ?? 0;

        return FutureBuilder<List<Church>>(
          future: userDistrict != null && userDistrict.isNotEmpty
              ? ChurchService.instance.getChurchesByDistrict(userDistrict)
              : Future.value([]),
          builder: (context, churchSnapshot) {
            final churchCount = churchSnapshot.data?.length ?? 0;

            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/my-ministry'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple[400]!,
                      Colors.deepPurple[600]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.church,
                          color: Theme.of(context).cardColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'My Ministry',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).cardColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$churchCount ${churchCount == 1 ? 'Church' : 'Churches'} • $staffCount ${staffCount == 1 ? 'Staff' : 'Staff'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Theme.of(context).cardColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDepartmentsSection(UserModel? user) {
    final missionName = user?.mission != null
        ? MissionService().getMissionNameById(user!.mission)
        : 'All Missions';

    return SliverToBoxAdapter(
      child: _constrainContent(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern header with gradient background
          Container(
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.colors.primary,
                  context.colors.withAlpha(context.colors.primary, 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: context.colors.withAlpha(context.colors.primary, 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.dashboard,
                    color: Theme.of(context).cardColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Departments',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).cardColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.business,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              missionName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // View All button
                if (user != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/departments'),
                      icon: Icon(Icons.arrow_forward,
                          color: Theme.of(context).cardColor, size: 18),
                      label: const Text(
                        'View All',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildDepartmentsGrid(user),
        ],
      )),
    );
  }

  Widget _buildDepartmentsGrid(UserModel? user) {
    String? missionId = user?.mission;
    // Get the mission ID from user, or use a default if not available
    String missionIdOrDefault = missionId ?? 'sabah-mission'; // Default ID

    // Get the human-readable mission name for display
    String missionName =
        MissionService().getMissionNameById(missionIdOrDefault);

    // Only log when actually loading, not on every rebuild
    // print(
    //     'Loading departments for mission: $missionName (ID: $missionIdOrDefault)');

    return StreamBuilder<List<Department>>(
      stream: _getDepartmentsStream(missionIdOrDefault),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && 
            (!snapshot.hasData || snapshot.data!.isEmpty)) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No departments available')),
          );
        }

        var departments = snapshot.data!;
        if (_searchQuery.isNotEmpty) {
          departments = departments
              .where((dept) => dept.name.toLowerCase().contains(_searchQuery))
              .toList();
        }

        final displayDepartments = departments.take(4).toList();
        final hasMore = departments.length > 4;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount;
                  double aspectRatio = 1.1;
                  
                  if (constraints.maxWidth > 1200) {
                    crossAxisCount = 4; // 4 columns on very large screens
                  } else if (constraints.maxWidth > 1024) {
                    crossAxisCount = 4; // 4 columns on desktop
                  } else if (constraints.maxWidth > 768) {
                    crossAxisCount = 3; // 3 columns on tablets
                  } else {
                    crossAxisCount = 2; // 2 columns on mobile
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: displayDepartments.length,
                    itemBuilder: (context, index) {
                      return _buildDepartmentCard(
                          displayDepartments[index], departments);
                    },
                  );
                },
              ),
              if (hasMore) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/departments'),
                  icon: const Icon(Icons.grid_view),
                  label: Text(
                    'View All ${departments.length} Departments',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDepartmentCard(
      Department department, List<Department> allDepartments) {
    // Brighten the card color
    final cardColor = _brightenColor(department.color ??
        Theme.of(context).colorScheme.surfaceContainerHighest);

    return GestureDetector(
      onTap: () => _handleDepartmentTap(department, allDepartments),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).cardColor,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleDepartmentTap(department, allDepartments),
            child: Stack(
              children: [
                // Inactive badge at top-right corner
                if (!department.isActive)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_circle,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Inactive',
                            style: TextStyle(
                              color: Theme.of(context).cardColor,
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
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          department.icon,
                          size: 24,
                          color: _getIconColor(department.color),
                        ),
                      ),
                      const Spacer(),
                      // Name
                      Text(
                        department.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.colors.onColor(cardColor),
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
        ),
      ),
    );
  }

  /// Keep bright colors vibrant - no brightening needed for CMYK colors
  Color _brightenColor(Color color) {
    return color; // Return original bright color without modification
  }

  Color _getIconColor(Color? bgColor) {
    if (bgColor == null) return context.colors.primary;
    final luminance = bgColor.computeLuminance();
    return context.colors.onColor(bgColor);
  }

  Widget _buildRecentActivitiesSection() {
    return SliverToBoxAdapter(
      child: _constrainContent(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/activities'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          _buildActivitiesList(),
        ],
      )),
    );
  }

  Widget _buildActivitiesList() {
    return FutureBuilder<List<Activity>>(
      future: ActivityStorageService.instance.getActivities(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading activities...',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final activities = snapshot.data!.take(3).toList();

        if (activities.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64, color: Theme.of(context).dividerColor),
                  const SizedBox(height: 16),
                  Text(
                    'No activities yet',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: activities.map((activity) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.description,
                          color: Colors.green[600], size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.activities,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(activity.date),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Theme.of(context).dividerColor),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Helper methods
  Future<void> _handleDepartmentTap(
      Department department, List<Department> allDepartments) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      final shouldLogin = await _showLoginPrompt();
      if (shouldLogin == true && mounted) {
        final result = await Navigator.pushNamed(context, '/login');
        if (result == true && mounted) {
          _navigateToDepartment(department, allDepartments);
        }
      }
    } else {
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
            Icon(Icons.lock_outline, color: context.colors.primary),
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
              backgroundColor: context.colors.primary,
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
    Navigator.pushNamed(
      context,
      AppConstants.routeInAppWebView,
      arguments: {
        'url': department.formUrl,
        'departmentName': department.name,
      },
    );
  }

  Future<Map<String, int>> _getQuickStats(UserModel? user) async {
    if (user == null) return {};

    final todos = await TodoStorageService.instance.getTodos();
    final appointments =
        await AppointmentStorageService.instance.getAppointments();
    final events = await EventService.instance.getLocalEvents();
    final activities = await ActivityStorageService.instance.getActivities();

    final upcomingAppointments =
        appointments.where((a) => a.dateTime.isAfter(DateTime.now())).length;
    final upcomingEvents =
        events.where((e) => e.startDate.isAfter(DateTime.now())).length;

    return {
      'todos': todos.where((t) => !t.isCompleted).length,
      'appointments': upcomingAppointments + upcomingEvents,
      'activities': activities.length,
    };
  }

  Color _getRoleColor(UserModel user) {
    switch (user.userRole) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.admin:
        return Colors.red;
      case UserRole.missionAdmin:
        return Colors.blue;
      case UserRole.ministerialSecretary:
        return Colors.teal;
      case UserRole.officer:
        return Colors.cyan;
      case UserRole.director:
        return Colors.deepPurple;
      case UserRole.editor:
        return Colors.orange;
      case UserRole.churchTreasurer:
        return Colors.amber.shade800;
      case UserRole.districtPastor:
        return Colors.indigo;
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
      case UserRole.ministerialSecretary:
        return Icons.book;
      case UserRole.officer:
        return Icons.badge;
      case UserRole.director:
        return Icons.supervisor_account;
      case UserRole.editor:
        return Icons.edit;
      case UserRole.churchTreasurer:
        return Icons.account_balance_wallet;
      case UserRole.districtPastor:
        return Icons.location_city;
      case UserRole.user:
        return Icons.person;
    }
  }

  // Quick Add Activity Bottom Sheet
  // Unused method - kept for reference
  // ignore: unused_element
  void _showQuickAddActivityBottomSheet() {
    final activityController = TextEditingController();
    final mileageController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    final locationController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedActivityType = 'Other';

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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_note,
                          color: context.colors.primary, size: 24),
                      const SizedBox(width: 12),
                      const Text('Quick Add Activity',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
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
                        border: Border.all(color: context.colors.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18, color: context.colors.primary),
                          const SizedBox(width: 8),
                          Text(
                              'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                              style: const TextStyle(fontSize: 16)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border.all(color: context.colors.outline),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedActivityType,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedActivityType = newValue;
                              if (newValue != 'Other') {
                                activityController.text = {
                                      'Visitation': 'Visitation to ',
                                      'Bible Study': 'Bible Study on ',
                                      'Prayer Meeting': 'Prayer Meeting with ',
                                      'Wedding': 'Wedding of ',
                                      'Funeral': 'Funeral service for ',
                                      'Counseling': 'Counseling session with ',
                                    }[newValue] ??
                                    '';
                                activityController.selection =
                                    TextSelection.fromPosition(TextPosition(
                                        offset:
                                            activityController.text.length));
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
                                Text(type),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: context.colors.outline),
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4)),
                    ),
                    child: TextField(
                      controller: activityController,
                      decoration: InputDecoration(
                        hintText: selectedActivityType == 'Other'
                            ? 'Enter your activity'
                            : 'Details about ${selectedActivityType.toLowerCase()}',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mileageController,
                    decoration: const InputDecoration(
                        labelText: 'Mileage',
                        hintText: 'Enter distance in km',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                              labelText: 'Location (Optional)',
                              border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                              labelText: 'Notes (Optional)',
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      if (activityController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please enter activity details')));
                        return;
                      }

                      try {
                        final mileage =
                            double.tryParse(mileageController.text) ?? 0.0;
                        final formattedActivity = selectedActivityType ==
                                'Other'
                            ? activityController.text.trim()
                            : '[$selectedActivityType] ${activityController.text.trim()}';

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
                          if (mounted) setState(() {});
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')));
                      }
                    },
                    child: const Text('SAVE ACTIVITY'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Quick Add Todo Bottom Sheet
  // Unused method - kept for reference
  // ignore: unused_element
  void _showQuickAddTodoBottomSheet() {
    final todoController = TextEditingController();
    int selectedPriority = 1; // 0: Low, 1: Medium, 2: High

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
                Row(
                  children: [
                    Icon(Icons.add_task,
                        color: context.colors.primary, size: 24),
                    const SizedBox(width: 12),
                    const Text('Quick Add Todo',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: todoController,
                  decoration: const InputDecoration(
                    labelText: 'Todo',
                    hintText: 'Enter your todo item',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Priority:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPriorityChip(
                          'Low', 0, selectedPriority, Colors.green, (priority) {
                        setState(() => selectedPriority = priority);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPriorityChip(
                          'Medium', 1, selectedPriority, Colors.orange,
                          (priority) {
                        setState(() => selectedPriority = priority);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPriorityChip(
                          'High', 2, selectedPriority, Colors.red, (priority) {
                        setState(() => selectedPriority = priority);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (todoController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please enter todo details')));
                      return;
                    }

                    try {
                      await TodoStorageService.instance.createTodo(
                        content: todoController.text.trim(),
                        priority: selectedPriority,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Todo added successfully'),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'View All',
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/todos'),
                            ),
                          ),
                        );
                        if (mounted) setState(() {});
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')));
                    }
                  },
                  child: const Text('ADD TODO'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriorityChip(String label, int priority, int selectedPriority,
      Color color, Function(int) onSelect) {
    final isSelected = priority == selectedPriority;
    return InkWell(
      onTap: () => onSelect(priority),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Inline priority chip for todo section
  Widget _buildInlinePriorityChip(String label, int priority, Color color) {
    final isSelected = priority == _selectedTodoPriority;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTodoPriority = priority;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Save activity inline
  Future<void> _saveActivityInline() async {
    if (_activityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter activity details')),
      );
      return;
    }

    try {
      final mileage = double.tryParse(_mileageController.text) ?? 0.0;
      final formattedActivity = _selectedActivityType == 'Other'
          ? _activityController.text.trim()
          : '[$_selectedActivityType] ${_activityController.text.trim()}';

      final activity = Activity(
        id: const Uuid().v4(),
        date: _selectedActivityDate,
        activities: formattedActivity,
        mileage: mileage,
        note: _noteController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        createdAt: DateTime.now(),
      );

      final success =
          await ActivityStorageService.instance.addActivity(activity);

      if (success && mounted) {
        // Clear the inputs
        _activityController.clear();
        _mileageController.text = '0';
        _locationController.clear();
        _noteController.clear();
        // Reset to today and Other
        setState(() {
          _selectedActivityDate = DateTime.now();
          _selectedActivityType = 'Other';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_selectedActivityType activity added successfully'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View All',
              onPressed: () => Navigator.pushNamed(context, '/activities'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // Save todo inline
  Future<void> _saveTodoInline() async {
    if (_todoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter todo details')),
      );
      return;
    }

    try {
      await TodoStorageService.instance.createTodo(
        content: _todoController.text.trim(),
        priority: _selectedTodoPriority,
      );

      if (mounted) {
        // Clear the input
        _todoController.clear();
        // Reset priority to Medium
        setState(() {
          _selectedTodoPriority = 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Todo added successfully'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View All',
              onPressed: () => Navigator.pushNamed(context, '/todos'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

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
        iconData = Icons.add_circle_outline;
        iconColor = Colors.orange;
        break;
    }

    return Icon(iconData, color: iconColor, size: 20);
  }

  // Welcome screen for non-authenticated users
  Widget _buildWelcomeScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primaryLight,
              AppColors.accent,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.church,
                      size: 60,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App Name
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: Theme.of(context).cardColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Tagline
                  const Text(
                    'Digital Ministry Platform',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Features
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureItem(
                            Icons.assignment, 'Track Activities & Reports'),
                        const SizedBox(height: 16),
                        _buildFeatureItem(Icons.calendar_today,
                            'Manage Events & Appointments'),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                            Icons.description, 'Submit Monthly Borang B'),
                        const SizedBox(height: 16),
                        _buildFeatureItem(
                            Icons.people, 'Department Management'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppConstants.routeLogin);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        foregroundColor: context.colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                            context, AppConstants.routeRegister);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Theme.of(context).cardColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Browse Departments
                  TextButton(
                    onPressed: () {
                      // Stay on current screen to browse departments
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Login to access all features'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text(
                      'Browse as Guest',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).cardColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).cardColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
