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
import 'package:pastor_report/services/optimized_data_service.dart';
import 'package:pastor_report/services/todo_storage_service.dart';
import 'package:pastor_report/services/appointment_storage_service.dart';
import 'package:pastor_report/services/event_service.dart';
import 'package:pastor_report/services/activity_storage_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

class ImprovedDashboardScreen extends StatefulWidget {
  const ImprovedDashboardScreen({super.key});

  @override
  State<ImprovedDashboardScreen> createState() => _ImprovedDashboardScreenState();
}

class _ImprovedDashboardScreenState extends State<ImprovedDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController(text: '0');
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _searchQuery = '';
  bool _showQuickActions = false;
  String _quickActionTab = 'activity'; // 'activity' or 'todo'
  int _selectedTodoPriority = 1; // 0: Low, 1: Medium, 2: High
  DateTime _selectedActivityDate = DateTime.now();
  String _selectedActivityType = 'Other';

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

  Stream<List<Department>> _getDepartmentsStream(String missionName) {
    return OptimizedDataService.instance.streamDepartmentsByMissionName(missionName);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final isAuthenticated = authProvider.isAuthenticated;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          _buildModernAppBar(user),

          // Quick Stats Overview
          if (isAuthenticated) _buildQuickStats(user),

          // Quick Actions (Combined Activity + Todo)
          if (isAuthenticated) _buildQuickActionsSection(),

          // Upcoming Items Section (Todos + Appointments)
          if (isAuthenticated) _buildUpcomingSection(),

          // Departments Section
          _buildDepartmentsSection(user),

          // Recent Activities
          if (isAuthenticated) _buildRecentActivitiesSection(),

          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildModernAppBar(UserModel? user) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primaryLight,
      actions: [
        if (user != null)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryLight,
                AppColors.primaryLight.withValues(alpha: 0.8),
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (user != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildRoleBadge(user),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Pastor Report',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildSearchBar(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
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
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search departments...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: AppColors.primaryLight),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(UserModel? user) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, int>>(
          future: _getQuickStats(user),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final stats = snapshot.data!;
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
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Quick Actions Section (Combined Activity + Todo)
  Widget _buildQuickActionsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Card(
          elevation: 2,
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
                          color: AppColors.primaryLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.dashboard_customize,
                          size: 32,
                          color: AppColors.primaryLight,
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
                                color: Colors.grey.shade600,
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
                        color: Colors.grey.shade400,
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

                      // Tab Selector
                      Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              'Activity',
                              Icons.event_note,
                              'activity',
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTabButton(
                              'Todo',
                              Icons.check_circle_outline,
                              'todo',
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Show Activity Form or Todo Form based on selected tab
                      if (_quickActionTab == 'activity') ..._buildActivityForm(),
                      if (_quickActionTab == 'todo') ..._buildTodoForm(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Tab Button for Quick Actions
  Widget _buildTabButton(String label, IconData icon, String tabValue, Color color) {
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
          color: isSelected ? color : Colors.white,
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
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: Colors.green.shade700),
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
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
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
                    }[newValue] ?? '';
                    _activityController.selection = TextSelection.fromPosition(TextPosition(offset: _activityController.text.length));
                  } else {
                    _activityController.clear();
                  }
                });
              }
            },
            items: ['Visitation', 'Bible Study', 'Prayer Meeting', 'Wedding', 'Funeral', 'Counseling', 'Other'].map<DropdownMenuItem<String>>((String type) {
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
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        child: TextField(
          controller: _activityController,
          decoration: InputDecoration(
            hintText: _selectedActivityType == 'Other' ? 'Enter your activity' : 'Details about ${_selectedActivityType.toLowerCase()}',
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

      // Mileage + Location
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _mileageController,
              decoration: InputDecoration(
                labelText: 'Mileage (km)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // Notes
      TextField(
        controller: _noteController,
        decoration: InputDecoration(
          labelText: 'Notes (Optional)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 12),

      // Buttons
      Row(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/activities'),
              icon: const Icon(Icons.list),
              label: const Text('View All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade700),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
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
        decoration: InputDecoration(
          hintText: 'Enter your todo item',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),
      const SizedBox(height: 12),

      // Priority
      Row(
        children: [
          Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(width: 12),
          Expanded(child: _buildInlinePriorityChip('Low', 0, Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildInlinePriorityChip('Medium', 1, Colors.orange)),
          const SizedBox(width: 8),
          Expanded(child: _buildInlinePriorityChip('High', 2, Colors.red)),
        ],
      ),
      const SizedBox(height: 12),

      // Buttons
      Row(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/todos'),
              icon: const Icon(Icons.checklist),
              label: const Text('View All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    ];
  }


  Widget _buildUpcomingSection() {
    return SliverToBoxAdapter(
      child: Column(
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
                    color: Colors.grey[800],
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
      ),
    );
  }

  Widget _buildUpcomingCards() {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildTodosCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildAppointmentsCard()),
        ],
      ),
    );
  }

  Widget _buildTodosCard() {
    return FutureBuilder<List<Todo>>(
      future: TodoStorageService.instance.getTodos(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final incompleteTodos = snapshot.data!.where((t) => !t.isCompleted).take(3).toList();

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
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${incompleteTodos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pending Todos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: incompleteTodos.isEmpty
                      ? const Center(
                          child: Text(
                            'No pending todos',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
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
                                    todo.priority == 2 ? Icons.priority_high : Icons.circle,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      todo.content,
                                      style: const TextStyle(
                                        color: Colors.white,
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
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        AppointmentStorageService.instance.getAppointments(),
        EventService.instance.getLocalEvents(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data![0] as List<Appointment>;
        final events = snapshot.data![1] as List<Event>;

        // Combine appointments and events
        final upcomingAppointments = appointments
            .where((a) => a.dateTime.isAfter(DateTime.now()))
            .map((a) => {'type': 'appointment', 'data': a, 'dateTime': a.dateTime})
            .toList();

        final upcomingEvents = events
            .where((e) => e.startDate.isAfter(DateTime.now()))
            .map((e) => {'type': 'event', 'data': e, 'dateTime': e.startDate})
            .toList();

        final upcoming = [...upcomingAppointments, ...upcomingEvents]
          ..sort((a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));

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
                    const Icon(Icons.calendar_today, color: Colors.white, size: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${displayItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Events & Appointments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: displayItems.isEmpty
                      ? const Center(
                          child: Text(
                            'No upcoming events',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
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
                                    isEvent ? Icons.event : Icons.calendar_today,
                                    size: 12,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          DateFormat('MMM dd, hh:mm a').format(dateTime),
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

  Widget _buildDepartmentsSection(UserModel? user) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Departments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                if (user != null)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/departments'),
                    child: const Text('View All'),
                  ),
              ],
            ),
          ),
          _buildDepartmentsGrid(user),
        ],
      ),
    );
  }

  Widget _buildDepartmentsGrid(UserModel? user) {
    final missionName = user?.mission ?? 'Southern Asia-Pacific Division';

    return StreamBuilder<List<Department>>(
      stream: _getDepartmentsStream(missionName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: displayDepartments.length,
                itemBuilder: (context, index) {
                  return _buildDepartmentCard(displayDepartments[index], departments);
                },
              ),
              if (hasMore) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/departments'),
                  icon: const Icon(Icons.grid_view),
                  label: Text(
                    'View All ${departments.length} Departments',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDepartmentCard(Department department, List<Department> allDepartments) {
    // Use department's custom color if available, otherwise use default gradient
    List<Color> colors;

    if (department.color != null) {
      // Create a gradient from the department's color
      final baseColor = department.color!;
      colors = [
        baseColor,
        Color.fromARGB(
          baseColor.alpha,
          (baseColor.red * 0.7).toInt().clamp(0, 255),
          (baseColor.green * 0.7).toInt().clamp(0, 255),
          (baseColor.blue * 0.7).toInt().clamp(0, 255),
        ),
      ];
    } else {
      // Fallback: Generate a unique color based on department name
      final colorIndex = department.name.hashCode % 6;
      final cardColors = [
        [Colors.indigo[400]!, Colors.indigo[600]!],
        [Colors.teal[400]!, Colors.teal[600]!],
        [Colors.purple[400]!, Colors.purple[600]!],
        [Colors.pink[400]!, Colors.pink[600]!],
        [Colors.cyan[400]!, Colors.cyan[600]!],
        [Colors.deepOrange[400]!, Colors.deepOrange[600]!],
      ];
      colors = cardColors[colorIndex];
    }

    return GestureDetector(
      onTap: () => _handleDepartmentTap(department, allDepartments),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  department.icon,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                department.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    return SliverToBoxAdapter(
      child: Column(
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
                    color: Colors.grey[800],
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
      ),
    );
  }

  Widget _buildActivitiesList() {
    return FutureBuilder<List<Activity>>(
      future: ActivityStorageService.instance.getActivities(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final activities = snapshot.data!.take(3).toList();

        if (activities.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No activities yet',
                    style: TextStyle(color: Colors.grey[600]),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.description, color: Colors.green[600], size: 24),
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
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
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
  Future<void> _handleDepartmentTap(Department department, List<Department> allDepartments) async {
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
    final appointments = await AppointmentStorageService.instance.getAppointments();
    final events = await EventService.instance.getLocalEvents();
    final activities = await ActivityStorageService.instance.getActivities();

    final upcomingAppointments = appointments.where((a) => a.dateTime.isAfter(DateTime.now())).length;
    final upcomingEvents = events.where((e) => e.startDate.isAfter(DateTime.now())).length;

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

  // Quick Add Activity Bottom Sheet
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
                      Icon(Icons.event_note, color: AppColors.primaryLight, size: 24),
                      const SizedBox(width: 12),
                      const Text('Quick Add Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: AppColors.primaryLight),
                          const SizedBox(width: 8),
                          Text('Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}', style: const TextStyle(fontSize: 16)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
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
                                }[newValue] ?? '';
                                activityController.selection = TextSelection.fromPosition(TextPosition(offset: activityController.text.length));
                              }
                            });
                          }
                        },
                        items: activityTypes.map<DropdownMenuItem<String>>((String type) {
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
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
                    ),
                    child: TextField(
                      controller: activityController,
                      decoration: InputDecoration(
                        hintText: selectedActivityType == 'Other' ? 'Enter your activity' : 'Details about ${selectedActivityType.toLowerCase()}',
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
                    decoration: const InputDecoration(labelText: 'Mileage', hintText: 'Enter distance in km', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: locationController,
                          decoration: const InputDecoration(labelText: 'Location (Optional)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: noteController,
                          decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      if (activityController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter activity details')));
                        return;
                      }

                      try {
                        final mileage = double.tryParse(mileageController.text) ?? 0.0;
                        final formattedActivity = selectedActivityType == 'Other'
                            ? activityController.text.trim()
                            : '[$selectedActivityType] ${activityController.text.trim()}';

                        final activity = Activity(
                          id: const Uuid().v4(),
                          date: selectedDate,
                          activities: formattedActivity,
                          mileage: mileage,
                          note: noteController.text.trim(),
                          location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                          createdAt: DateTime.now(),
                        );

                        final success = await ActivityStorageService.instance.addActivity(activity);

                        if (success && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$selectedActivityType activity added successfully'),
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'View All',
                                onPressed: () => Navigator.pushNamed(context, '/activities'),
                              ),
                            ),
                          );
                          if (mounted) setState(() {});
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
                    Icon(Icons.add_task, color: AppColors.primaryLight, size: 24),
                    const SizedBox(width: 12),
                    const Text('Quick Add Todo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
                const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPriorityChip('Low', 0, selectedPriority, Colors.green, (priority) {
                        setState(() => selectedPriority = priority);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPriorityChip('Medium', 1, selectedPriority, Colors.orange, (priority) {
                        setState(() => selectedPriority = priority);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPriorityChip('High', 2, selectedPriority, Colors.red, (priority) {
                        setState(() => selectedPriority = priority);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (todoController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter todo details')));
                      return;
                    }

                    try {
                      final todo = Todo(
                        id: const Uuid().v4(),
                        content: todoController.text.trim(),
                        priority: selectedPriority,
                        isCompleted: false,
                        createdAt: DateTime.now(),
                      );

                      await TodoStorageService.instance.saveTodo(todo);

                      if (context.mounted) {
                        Navigator.pop(context);
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
                        if (mounted) setState(() {});
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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

  Widget _buildPriorityChip(String label, int priority, int selectedPriority, Color color, Function(int) onSelect) {
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
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        createdAt: DateTime.now(),
      );

      final success = await ActivityStorageService.instance.addActivity(activity);

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
      final todo = Todo(
        id: const Uuid().v4(),
        content: _todoController.text.trim(),
        priority: _selectedTodoPriority,
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      await TodoStorageService.instance.saveTodo(todo);

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
}
