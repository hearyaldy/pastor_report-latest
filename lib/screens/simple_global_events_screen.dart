// lib/screens/simple_global_events_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/models/global_event_model.dart';
import 'package:pastor_report/models/user_model.dart';
import 'package:pastor_report/services/global_event_service.dart';
import 'package:pastor_report/utils/constants.dart';

class SimpleGlobalEventsScreen extends StatefulWidget {
  const SimpleGlobalEventsScreen({super.key});

  @override
  State<SimpleGlobalEventsScreen> createState() =>
      _SimpleGlobalEventsScreenState();
}

class _SimpleGlobalEventsScreenState extends State<SimpleGlobalEventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final canAddEvents = _canAddEvents(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Events'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSearchBar(),
                    if (canAddEvents) const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildEventsList(user, canAddEvents),
          ],
        ),
      ),
      floatingActionButton: canAddEvents
          ? FloatingActionButton(
              onPressed: () => _addEvent(context, user!),
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Search events...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildEventsList(UserModel? user, bool canEdit) {
    return StreamBuilder<List<GlobalEvent>>(
      stream: GlobalEventService.instance.streamAllEvents(),
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
                  const Icon(Icons.event_note, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No events found'),
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
                    _buildEventCard(event, canEdit, user),
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

  Widget _buildEventCard(GlobalEvent event, bool canEdit, UserModel? user) {
    final eventDate = event.dateTime;
    Color eventColor = _getEventColor(event.department);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showEventDetails(event),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: eventColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${eventDate.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${eventDate.day}/${eventDate.month}/${eventDate.year} at ${eventDate.hour.toString().padLeft(2, '0')}:${eventDate.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        if (event.department != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            event.department!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editEvent(context, event, user!);
                        } else if (value == 'delete') {
                          _deleteEvent(event);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                ],
              ),
              if (event.notes != null && event.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  event.notes!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
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
      builder: (context) => _EventForm(
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
      builder: (context) => _EventForm(
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
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GlobalEventService.instance.deleteEvent(event.id);
    }
  }

  void _showEventDetails(GlobalEvent event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _detailItem(Icons.calendar_today, 'Date',
                '${event.dateTime.day}/${event.dateTime.month}/${event.dateTime.year}'),
            _detailItem(Icons.schedule, 'Time',
                '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}'),
            if (event.department != null)
              _detailItem(Icons.category, 'Department', event.department!),
            if (event.notes != null && event.notes!.isNotEmpty)
              _detailItem(Icons.note, 'Notes', event.notes!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canAddEvents(UserModel? user) {
    if (user == null) return false;

    // Allow Super Admin, Admin, Mission Admin, Directors, and Officers to add events
    return user.userRole == UserRole.superAdmin ||
        user.userRole == UserRole.admin ||
        user.userRole == UserRole.missionAdmin ||
        user.userRole == UserRole.director ||
        user.userRole == UserRole.officer;
  }
}

class _EventForm extends StatefulWidget {
  final GlobalEvent? event;
  final UserModel user;
  final Function(GlobalEvent) onSave;

  const _EventForm({
    this.event,
    required this.user,
    required this.onSave,
  });

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
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
                Text(
                  widget.event == null
                      ? 'Add Global Event'
                      : 'Edit Global Event',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an event title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    _selectedDateTime != null
                        ? 'Date & Time: ${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year} ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}'
                        : 'Select Date & Time',
                  ),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: _selectDateTime,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment?.isEmpty == true
                      ? null
                      : _selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Department (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
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
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveEvent,
                        child: const Text('Save'),
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

  void _saveEvent() {
    if (_formKey.currentState!.validate() && _selectedDateTime != null) {
      final event = GlobalEvent(
        id: widget.event?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        dateTime: _selectedDateTime!,
        department: _selectedDepartment?.isNotEmpty == true
            ? _selectedDepartment
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdBy: widget.user.uid,
        createdAt: widget.event?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.onSave(event);
      Navigator.pop(context);
    }
  }
}
