import 'package:flutter/material.dart';
import 'package:pastor_report/models/event_model.dart';
import 'package:pastor_report/services/event_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Event>> _events = {};
  List<Event> _selectedDayEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await EventService.instance.getAllEvents();

    final Map<DateTime, List<Event>> eventMap = {};
    for (var event in events) {
      final date = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      if (eventMap[date] == null) {
        eventMap[date] = [];
      }
      eventMap[date]!.add(event);
    }

    // Get selected day events
    List<Event> selectedDayEvts = [];
    if (_selectedDay != null) {
      final date = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      selectedDayEvts = eventMap[date] ?? [];
      selectedDayEvts.sort((a, b) => a.startDate.compareTo(b.startDate));
    }

    setState(() {
      _events = eventMap;
      _selectedDayEvents = selectedDayEvts;
    });
  }

  void _updateSelectedDayEvents() {
    if (_selectedDay == null) return;
    final date = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final selectedDayEvts = _events[date] ?? [];
    selectedDayEvts.sort((a, b) => a.startDate.compareTo(b.startDate));

    setState(() {
      _selectedDayEvents = selectedDayEvts;
    });
  }

  List<Event> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  void _showAddEventBottomSheet({Event? editEvent}) {
    if (editEvent != null && editEvent.isGlobal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Global events cannot be edited')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddEventSheet(
        selectedDate: _selectedDay ?? DateTime.now(),
        event: editEvent,
        onSaved: _loadEvents,
      ),
    );
  }

  Future<void> _deleteEvent(Event event) async {
    if (!event.isGlobal) {
      await EventService.instance.deleteLocalEvent(event.id);
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
                _updateSelectedDayEvents();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _updateSelectedDayEvents();
                });
              },
              onFormatChanged: (format) => setState(() => _calendarFormat = format),
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.5), shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: true, titleCentered: true),
            ),
          ),
          Expanded(
            child: _selectedDayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No events on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _selectedDayEvents.length,
                    itemBuilder: (context, index) {
                      final event = _selectedDayEvents[index];
                      return _EventCard(event: event, onEdit: () => _showAddEventBottomSheet(editEvent: event), onDelete: () => _deleteEvent(event));
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventBottomSheet(),
        backgroundColor: AppColors.primaryLight,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  final DateTime selectedDate;
  final Event? event;
  final VoidCallback onSaved;

  const _AddEventSheet({required this.selectedDate, this.event, required this.onSaved});

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  late TextEditingController _organizerController;
  late DateTime _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descController = TextEditingController(text: widget.event?.description ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _organizerController = TextEditingController(text: widget.event?.organizer ?? '');
    _startDate = widget.event?.startDate ?? widget.selectedDate;
    _endDate = widget.event?.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _organizerController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter title')));
      return;
    }

    final event = Event(
      id: widget.event?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      startDate: _startDate,
      endDate: _endDate,
      location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      organizer: _organizerController.text.trim().isNotEmpty ? _organizerController.text.trim() : null,
      isGlobal: false,
      createdAt: widget.event?.createdAt ?? DateTime.now(),
    );

    await EventService.instance.saveLocalEvent(event);

    if (mounted) {
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Event ${widget.event == null ? 'added' : 'updated'}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.event == null ? 'New Event' : 'Edit Event', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title))),
                const SizedBox(height: 16),
                TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)), maxLines: 3),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                    if (date != null) setState(() => _startDate = date);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Start: ${DateFormat('MMM dd, yyyy').format(_startDate)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(context: context, initialDate: _endDate ?? _startDate.add(const Duration(days: 1)), firstDate: _startDate, lastDate: DateTime(2030));
                    if (date != null) setState(() => _endDate = date);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(_endDate == null ? 'End Date (Optional)' : 'End: ${DateFormat('MMM dd, yyyy').format(_endDate!)}'),
                ),
                if (_endDate != null) TextButton.icon(onPressed: () => setState(() => _endDate = null), icon: const Icon(Icons.clear, size: 16), label: const Text('Clear'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
                const SizedBox(height: 16),
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on))),
                const SizedBox(height: 16),
                TextField(controller: _organizerController, decoration: const InputDecoration(labelText: 'Organizer', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveEvent,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(widget.event == null ? 'Add Event' : 'Update Event'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({required this.event, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: event.isGlobal ? null : onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (event.isGlobal ? Colors.purple : AppColors.primaryLight).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(event.isGlobal ? Icons.public : Icons.event, color: event.isGlobal ? Colors.purple : AppColors.primaryLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(event.endDate == null ? DateFormat('MMM dd, yyyy').format(event.startDate) : '${DateFormat('MMM dd').format(event.startDate)} - ${DateFormat('MMM dd, yyyy').format(event.endDate!)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (event.location != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.location_on, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(event.location!, style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                    ],
                  ],
                ),
              ),
              if (event.isGlobal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Global', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                )
              else
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                  onSelected: (value) async {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Event'), content: const Text('Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete'))]));
                      if (confirm == true) onDelete();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
