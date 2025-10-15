// lib/screens/global_events_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/global_event_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/global_event_service.dart';
import 'package:pastor_report/utils/theme_colors.dart';
import 'package:pastor_report/utils/constants.dart';

class GlobalEventsManagementScreen extends StatefulWidget {
  const GlobalEventsManagementScreen({super.key});

  @override
  State<GlobalEventsManagementScreen> createState() =>
      _GlobalEventsManagementScreenState();
}

class _GlobalEventsManagementScreenState
    extends State<GlobalEventsManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('GlobalEventsManagementScreen build method called');
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    print(
        'User in build: ${user?.uid}, Role: ${user?.userRole}, Role name: ${user?.userRole?.name}');
    final canAddEvents = _canAddEvents(user);
    print('Can add events: $canAddEvents');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            _buildModernAppBar(user),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    if (canAddEvents) ...[
                      const SizedBox(height: 16),
                      _buildAddEventButton(user),
                    ],
                    if (user?.userRole == UserRole.superAdmin ||
                        user?.userRole == UserRole.admin) ...[
                      const SizedBox(height: 16),
                      _buildDepartmentFilter(),
                      const SizedBox(height: 8),
                      _buildDateRangeFilter(),
                    ],
                  ],
                ),
              ),
            ),
            _buildEventsList(user, canAddEvents),
          ],
        ),
      ),
      floatingActionButton: canAddEvents
          ? FloatingActionButton.extended(
              onPressed: () => _addEvent(context, user!),
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add Event'),
            )
          : null,
    );
  }

  Widget _buildModernAppBar(UserModel? user) {
    print('Building Modern AppBar');
    print(
        'User role in AppBar: ${user?.userRole}, Role name: ${user?.userRole?.name}');
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: context.colors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Global Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.colors.onPrimary,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.colors.primaryGradient,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Icon(
                  Icons.event,
                  size: 150,
                  color: context.colors.onPrimary.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) async {
            if ((value == 'import_pdf' || value == 'import_json') &&
                user != null) {
              String source = value == 'import_pdf' ? 'PDF' : 'JSON';

              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Import Special Events ($source)'),
                  content: Text(
                      'This will import the 2025 Special Events calendar from the $source file.\n\n'
                      'Do you want to continue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Import'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                if (value == 'import_pdf') {
                  await _importSpecialEventsFromPDF(user!);
                } else {
                  await _importSpecialEventsFromJSON(user!);
                }
              }
            }
            // Add any additional menu options here if needed
          },
          itemBuilder: (context) {
            print('Building popup menu items');
            print('User role: ${user?.userRole}');
            print('User role name: ${user?.userRole?.name}');
            print('UserRole.superAdmin: ${UserRole.superAdmin}');
            print('UserRole.superAdmin name: ${UserRole.superAdmin.name}');
            print('UserRole.admin: ${UserRole.admin}');
            print('UserRole.admin name: ${UserRole.admin.name}');

            // Show import option for Super Admin and Admin users
            final showImport = user?.userRole == UserRole.superAdmin ||
                user?.userRole == UserRole.admin;
            print('Show import option: $showImport');

            if (showImport) {
              print('Adding import menu items');
              return [
                const PopupMenuItem(
                  value: 'import_pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 20),
                      SizedBox(width: 8),
                      Text('Import Events (PDF)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import_json',
                  child: Row(
                    children: [
                      Icon(Icons.data_object, size: 20),
                      SizedBox(width: 8),
                      Text('Import Events (JSON)'),
                    ],
                  ),
                ),
              ];
            } else {
              print('Not showing import option');
              return [];
            }
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search events by title, department, or notes...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: context.colors.adaptive(
          light: const Color(0xFFF5F5F5),
          dark: const Color(0xFF2C2C2C),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildAddEventButton(UserModel? user) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.adaptive(
          light: const Color(0xFFE8F5E9),
          dark: const Color(0xFF1B5E20),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.adaptive(
            light: const Color(0xFFA5D6A7),
            dark: const Color(0xFF66BB6A),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.add_circle,
              color: context.colors.adaptive(
                light: const Color(0xFF388E3C),
                dark: const Color(0xFF81C784),
              ),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Add Global Event',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.adaptive(
                  light: const Color(0xFF388E3C),
                  dark: const Color(0xFF81C784),
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentFilter() {
    final user = context.read<AuthProvider>().user;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.adaptive(
          light: const Color(0xFFE3F2FD),
          dark: const Color(0xFF1A237E),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.adaptive(
            light: const Color(0xFF90CAF9),
            dark: const Color(0xFF5C6BC0),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.category,
                  color: context.colors.adaptive(
                    light: const Color(0xFF1976D2),
                    dark: const Color(0xFF90CAF9),
                  ),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter by Department',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.adaptive(
                      light: const Color(0xFF1976D2),
                      dark: const Color(0xFF90CAF9),
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              decoration: InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.colors.surface,
                prefixIcon: const Icon(Icons.category),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                    value: 'All', child: Text('All Departments')),
                ...DepartmentData.departments.map((dept) => DropdownMenuItem(
                      value: dept.name,
                      child: Text(dept.name),
                    )),
              ],
              onChanged: (value) =>
                  setState(() => _selectedDepartment = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.adaptive(
          light: const Color(0xFFFEF7E8),
          dark: const Color(0xFF493C1D),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.adaptive(
            light: const Color(0xFFF4A950),
            dark: const Color(0xFFD2A054),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  color: context.colors.adaptive(
                    light: const Color(0xFFD2691E),
                    dark: const Color(0xFFF4A950),
                  ),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter by Date Range',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.adaptive(
                      light: const Color(0xFFD2691E),
                      dark: const Color(0xFFF4A950),
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_dateRange != null
                  ? '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}'
                  : 'Select Date Range'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_dateRange != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _dateRange = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  Widget _buildEventsList(UserModel? user, bool canEdit) {
    final stream = _getEventsStream(user);
    return StreamBuilder<List<GlobalEvent>>(
      stream: stream,
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note,
                      size: 64, color: context.colors.emptyStateIcon),
                  const SizedBox(height: 16),
                  Text(
                    'No events found',
                    style: TextStyle(
                        fontSize: 16, color: context.colors.emptyStateText),
                  ),
                ],
              ),
            ),
          );
        }

        var eventsList = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          eventsList = eventsList
              .where((event) =>
                  event.title
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  (event.department
                          ?.toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ??
                      false) ||
                  (event.notes
                          ?.toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ??
                      false))
              .toList();
        }

        // Apply department filter
        if (_selectedDepartment != 'All') {
          eventsList = eventsList
              .where((event) => event.department == _selectedDepartment)
              .toList();
        }

        // Apply date range filter
        if (_dateRange != null) {
          eventsList = eventsList
              .where((event) =>
                  event.dateTime.isAfter(_dateRange!.start) &&
                  event.dateTime.isBefore(_dateRange!.end))
              .toList();
        }

        if (eventsList.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 64, color: context.colors.emptyStateIcon),
                  const SizedBox(height: 16),
                  Text(
                    'No events match your search',
                    style: TextStyle(
                        fontSize: 16, color: context.colors.emptyStateText),
                  ),
                ],
              ),
            ),
          );
        }

        // Sort events by date/time
        eventsList.sort((a, b) => a.dateTime.compareTo(b.dateTime));

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= eventsList.length) return null;
                final event = eventsList[index];
                return Column(
                  children: [
                    _buildModernEventCard(event, canEdit, user),
                    if (index < eventsList.length - 1)
                      const SizedBox(height: 12),
                  ],
                );
              },
              childCount: eventsList.length,
            ),
          ),
        );
      },
    );
  }

  Stream<List<GlobalEvent>> _getEventsStream(UserModel? user) {
    if (user == null) return Stream.value([]);

    switch (user.userRole) {
      case UserRole.superAdmin:
      case UserRole.admin:
        return GlobalEventService.instance.streamAllEvents();
      case UserRole.missionAdmin:

        // Allow directors and officers to see all events
        return GlobalEventService.instance.streamAllEvents();
      default:
        // Regular users can only view events
        return GlobalEventService.instance.streamAllEvents();
    }
  }

  Widget _buildModernEventCard(
      GlobalEvent event, bool canEdit, UserModel? user) {
    final eventDate = event.dateTime;
    Color eventColor = _getEventColor(event.department);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: eventColor.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: eventColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Event date indicator in top right corner
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: eventColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${eventDate.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showEventDetails(event, canEdit, user),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Calendar icon for date
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            eventColor.withOpacity(0.8),
                            eventColor,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${eventDate.month}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${eventDate.year}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Event info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 14,
                                  color: context.colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${eventDate.hour.toString().padLeft(2, '0')}:${eventDate.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.calendar_today,
                                  size: 14,
                                  color: context.colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (event.department != null)
                                _buildChip(
                                  event.department!,
                                  Icons.category,
                                  context.colors.adaptive(
                                    light: const Color(0xFFE3F2FD),
                                    dark: const Color(0xFF1565C0),
                                  ),
                                  context.colors.adaptive(
                                    light: const Color(0xFF1976D2),
                                    dark: const Color(0xFF90CAF9),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    if (canEdit)
                      SizedBox(
                        width: 96,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: context.colors.primary,
                              ),
                              iconSize: 20,
                              padding: const EdgeInsets.all(4),
                              onPressed: () =>
                                  _editEvent(context, event, user!),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: context.colors.error,
                              ),
                              iconSize: 20,
                              padding: const EdgeInsets.all(4),
                              onPressed: () => _deleteEvent(event),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
      String label, IconData icon, Color backgroundColor, Color textColor) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(String? department) {
    if (department == null) return Colors.grey;

    // Return specific colors based on department
    switch (department.toLowerCase()) {
      case 'ministerial':
        return Colors.blue;
      case 'stewardship':
        return Colors.green;
      case 'youth':
        return Colors.purple;
      case 'communication':
        return Colors.orange;
      case 'health':
        return Colors.red;
      case 'education':
        return Colors.teal;
      case 'family life':
        return Colors.pink;
      case 'women\'s ministry':
        return Colors.deepPurple;
      case 'children':
        return Colors.lime;
      case 'publishing':
        return Colors.brown;
      case 'sabbath school':
        return Colors.amber;
      case 'adventist community services':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  void _addEvent(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => _GlobalEventForm(
        user: user,
        onSave: (event) async {
          await GlobalEventService.instance.addEvent(event);
        },
      ),
    );
  }

  void _editEvent(BuildContext context, GlobalEvent event, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => _GlobalEventForm(
        event: event,
        user: user,
        onSave: (updatedEvent) async {
          await GlobalEventService.instance.updateEvent(updatedEvent);
        },
      ),
    );
  }

  void _deleteEvent(GlobalEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete ${event.title}?'),
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
      await GlobalEventService.instance.deleteEvent(event.id);
    }
  }

  void _showEventDetails(GlobalEvent event, bool canEdit, UserModel? user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: _getEventColor(event.department),
                child: Icon(
                  Icons.event,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(event.title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _detailRow(Icons.calendar_today, 'Date',
                  '${event.dateTime.day}/${event.dateTime.month}/${event.dateTime.year}'),
              _detailRow(Icons.schedule, 'Time',
                  '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}'),
              if (event.department != null)
                _detailRow(Icons.category, 'Department', event.department!),
              if (event.notes != null && event.notes!.isNotEmpty)
                _detailRow(Icons.note, 'Notes', event.notes!),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: context.colors.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canAddEvents(UserModel? user) {
    if (user == null) return false;

    // Allow Super Admin, Admin, Mission Admin, Department Directors, and Mission Officers to add events
    return user.userRole == UserRole.superAdmin ||
        user.userRole == UserRole.admin ||
        user.userRole == UserRole.missionAdmin;
  }

  /// Import special events from the PDF calendar for 2025
  Future<void> _importSpecialEventsFromPDF(UserModel user) async {
    final specialEvents2025 = [
      // January
      {
        'date': '2025-01-04',
        'time': '09:00',
        'title': 'Quarterly Day of Prayer',
        'department': 'R&RCom',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-01-08',
        'time': '09:00',
        'title': 'Ten Days of Prayer',
        'department': 'GC-MIN',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-01-11',
        'time': '09:00',
        'title': 'Health Ministries Day',
        'department': 'GC-HM/DIV',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-01-18',
        'time': '09:00',
        'title': 'Religious Liberty Day',
        'department': 'GC/NAD-PARL',
        'notes': 'World 2025 Special Events'
      },

      // February
      {
        'date': '2025-02-01',
        'time': '09:00',
        'title': 'Reach the World: Personal Outreach',
        'department': 'GC-SSPM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-02-08',
        'time': '09:00',
        'title': 'Christian Home and Marriage Week',
        'department': 'GC-FM',
        'notes': 'World 2025 Special Events'
      },

      // March
      {
        'date': '2025-03-01',
        'time': '09:00',
        'title': 'Women\'s Day of Prayer',
        'department': 'GC-WM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-03-08',
        'time': '09:00',
        'title': 'Adventist World Radio Day',
        'department': 'GC-AWR',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-03-15',
        'time': '09:00',
        'title': 'Youth Week of Prayer',
        'department': 'GC-YOU',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-03-15',
        'time': '09:00',
        'title': 'Global Youth Day/Global Children\'s Day',
        'department': 'GC-YOU/CHM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-03-22',
        'time': '09:00',
        'title': 'Christian Education Day',
        'department': 'Divisions',
        'notes': 'World 2025 Special Events'
      },

      // April
      {
        'date': '2025-04-05',
        'time': '09:00',
        'title': 'Quarterly Day of Prayer',
        'department': 'R&RCom',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-04-05',
        'time': '09:00',
        'title': 'World Ambassador Day',
        'department': 'GC-YOU',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-04-12',
        'time': '09:00',
        'title': 'Literature Evangelism Rally Week',
        'department': 'Divisions',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-04-12',
        'time': '09:00',
        'title': 'Friends of Hope Day (Visitor\'s Day)',
        'department': 'GC-SSPM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-04-12',
        'time': '09:00',
        'title': 'Hope Channel International Day',
        'department': 'GC-HCI',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-04-12',
        'time': '09:00',
        'title': 'World Impact Day—for Distribution of Missionary Book',
        'department': 'Divisions',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-04-19',
        'time': '09:00',
        'title': 'Possibility Ministries Day',
        'department': 'GC-APM',
        'notes': 'World 2025 Special Events'
      },

      // May
      {
        'date': '2025-05-03',
        'time': '09:00',
        'title': 'Drug Awareness Month',
        'department': 'GC-HM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-05-03',
        'time': '09:00',
        'title': 'Reach the World: Using Communication Channels',
        'department': 'GC-COM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-05-17',
        'time': '09:00',
        'title': 'Global Adventurer\'s Day',
        'department': 'GC-YOU',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-05-24',
        'time': '09:00',
        'title': 'World Day of Prayer for Children at Risk',
        'department': 'GC-CHM',
        'notes': 'World 2025 Special Events'
      },

      // June
      {
        'date': '2025-06-07',
        'time': '09:00',
        'title':
            'Reach the World: Bible Study: Sabbath School and Correspondence Courses',
        'department': 'GC-SSPM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-06-14',
        'time': '09:00',
        'title': 'Women\'s Ministries Emphasis Day',
        'department': 'GC-WM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-06-21',
        'time': '09:00',
        'title': 'Reach the World: Nurturing Other Members and Reclaiming',
        'department': 'GC-SSPM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-06-21',
        'time': '09:00',
        'title': 'Adventist Church World Refugee Day',
        'department': 'ADRA',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-06-28',
        'time': '09:00',
        'title': 'World Public Campus Ministries Day',
        'department': 'GC-YOU',
        'notes': 'World 2025 Special Events'
      },

      // July
      {
        'date': '2025-07-05',
        'time': '09:00',
        'title': 'Quarterly Day of Prayer',
        'department': 'R&RCom',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-07-12',
        'time': '09:00',
        'title': 'Mission Promotion Day',
        'department': 'GC-AM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-07-19',
        'time': '09:00',
        'title': 'Reach the World: Media Ministry',
        'department': 'GC-COM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-07-26',
        'time': '09:00',
        'title': 'Children\'s Sabbath',
        'department': 'GC-CHM',
        'notes': 'World 2025 Special Events'
      },

      // August
      {
        'date': '2025-08-02',
        'time': '09:00',
        'title': 'Global Mission Evangelism Day',
        'department': 'Divisions',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-08-09',
        'time': '09:00',
        'title': 'Reach the World: Church Planting',
        'department': 'GC-AM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-08-16',
        'time': '09:00',
        'title': 'Education Day',
        'department': 'GC-EDU',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-08-23',
        'time': '09:00',
        'title': 'enditnow Day',
        'department': 'GC-WM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-08-23',
        'time': '09:00',
        'title': 'Lay Evangelism Day',
        'department': 'Divisions',
        'notes': 'World 2025 Special Events'
      },

      // September
      {
        'date': '2025-09-06',
        'time': '09:00',
        'title': 'Youth Spiritual and Mission Commitment Day',
        'department': 'Divisions',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-09-07',
        'time': '09:00',
        'title': 'Family Togetherness Week of Prayer',
        'department': 'GC-FM',
        'notes': 'World 2025 Special Events'
      },
      {
        'date': '2025-09-13',
        'time': '09:00',
        'title': 'Family Togetherness Day of Prayer',
        'department': 'GC-FM',
        'notes': 'World 2025 Special Events'
      },
    ];

    try {
      int addedCount = 0;
      int errorCount = 0;

      for (final eventData in specialEvents2025) {
        try {
          final dateTimeStr = '${eventData['date']} ${eventData['time']}';
          final dateTime = DateTime.parse(dateTimeStr);

          final event = GlobalEvent(
            id: const Uuid().v4(),
            title: eventData['title'] as String,
            dateTime: dateTime,
            department: eventData['department'] as String,
            notes: eventData['notes'] as String,
            createdBy: user.uid,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          print('Attempting to add event: ${event.title} on ${event.dateTime}');
          final success = await GlobalEventService.instance.addEvent(event);
          print('Event add result for ${event.title}: $success');
          if (success) {
            addedCount++;
            print('Successfully added event: ${event.title}');
          } else {
            errorCount++;
            print('Failed to add event: ${event.title}');
          }
        } catch (e) {
          errorCount++;
          print('Error adding event ${eventData['title']}: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Added $addedCount special events. $errorCount errors.'),
            backgroundColor: addedCount > 0 ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing special events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Import special events from the JSON file (complete 2025 calendar)
  Future<void> _importSpecialEventsFromJSON(UserModel user) async {
    try {
      // Load the JSON file
      final jsonString =
          await rootBundle.loadString('assets/special_events_2025.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      final eventsData = jsonData['CalendarOfSpecialDays2025'] as List<dynamic>;

      int addedCount = 0;
      int errorCount = 0;

      // Process each month
      for (final monthData in eventsData) {
        final monthName = monthData['month'] as String;
        final events = monthData['events'] as List<dynamic>;

        print('Processing $monthName with ${events.length} events');

        // Process each event in the month
        for (final eventData in events) {
          try {
            final dateStr = eventData['date'] as String;
            final title = eventData['title'] as String;
            final department = eventData['department'] as String;

            // Parse the date - we need to convert "4" or "8-18" to actual dates in 2025
            final dates = _parseEventDates(dateStr, monthName, 2025);

            // Create events for each date
            for (final date in dates) {
              final event = GlobalEvent(
                id: const Uuid().v4(),
                title: title,
                dateTime: date,
                department: department,
                notes: 'World 2025 Special Events from JSON',
                createdBy: user.uid,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              print('Attempting to add event: $title on $date');
              final success = await GlobalEventService.instance.addEvent(event);
              print('Event add result for $title: $success');

              if (success) {
                addedCount++;
                print('Successfully added event: $title');
              } else {
                errorCount++;
                print('Failed to add event: $title');
              }
            }
          } catch (e) {
            errorCount++;
            print('Error processing event: $e');
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Added $addedCount special events from JSON. $errorCount errors.'),
            backgroundColor: addedCount > 0 ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing special events from JSON: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Parse event dates from string format like "4" or "8-18"
  List<DateTime> _parseEventDates(String dateStr, String monthName, int year) {
    final dates = <DateTime>[];

    // Convert month name to number
    final months = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12
    };

    final month = months[monthName];
    if (month == null) {
      print('Invalid month name: $monthName');
      return dates;
    }

    // Handle date ranges like "8-18" or single dates like "4"
    if (dateStr.contains('-')) {
      // Date range
      final parts = dateStr.split('-');
      if (parts.length == 2) {
        final startDay = int.tryParse(parts[0]);
        final endDay = int.tryParse(parts[1]);

        if (startDay != null && endDay != null) {
          // Create events for each day in the range
          for (int day = startDay; day <= endDay; day++) {
            try {
              dates.add(DateTime(year, month, day));
            } catch (e) {
              print('Error creating date for $year-$month-$day: $e');
            }
          }
        }
      }
    } else {
      // Single date
      final day = int.tryParse(dateStr);
      if (day != null) {
        try {
          dates.add(DateTime(year, month, day));
        } catch (e) {
          print('Error creating date for $year-$month-$day: $e');
        }
      }
    }

    return dates;
  }
}

class _GlobalEventForm extends StatefulWidget {
  final GlobalEvent? event;
  final UserModel user;
  final Function(GlobalEvent) onSave;

  const _GlobalEventForm({
    this.event,
    required this.user,
    required this.onSave,
  });

  @override
  State<_GlobalEventForm> createState() => _GlobalEventFormState();
}

class _GlobalEventFormState extends State<_GlobalEventForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDateTime;
  String? _selectedDepartment;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.event?.title ?? '';
    _notesController.text = widget.event?.notes ?? '';
    _selectedDateTime = widget.event?.dateTime ?? DateTime.now();
    _selectedDepartment = widget.event?.department ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  widget.event == null
                      ? 'Add Global Event'
                      : 'Edit Global Event',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(_selectedDateTime != null
                      ? 'Date & Time: ${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year} ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}'
                      : 'Select Date & Time'),
                  onTap: _selectDateTime,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Department (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('None'),
                    ),
                    ...DepartmentData.departments
                        .map((dept) => DropdownMenuItem(
                              value: dept.name,
                              child: Text(dept.name),
                            )),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedDepartment = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate() &&
                                _selectedDateTime != null) {
                              final event = GlobalEvent(
                                id: widget.event?.id ?? const Uuid().v4(),
                                title: _titleController.text.trim(),
                                dateTime: _selectedDateTime!,
                                department:
                                    _selectedDepartment?.isNotEmpty == true
                                        ? _selectedDepartment
                                        : null,
                                notes: _notesController.text.trim().isNotEmpty
                                    ? _notesController.text.trim()
                                    : null,
                                createdBy: widget.user.uid,
                                createdAt:
                                    widget.event?.createdAt ?? DateTime.now(),
                                updatedAt:
                                    widget.event?.updatedAt ?? DateTime.now(),
                              );
                              widget.onSave(event);
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            foregroundColor: context.colors.onPrimary,
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
        ),
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }
}
