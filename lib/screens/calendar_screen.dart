import 'package:flutter/material.dart';
import 'package:pastor_report/models/appointment_model.dart';
import 'package:pastor_report/models/event_model.dart';
import 'package:pastor_report/services/appointment_storage_service.dart';
import 'package:pastor_report/services/event_service.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// Create a common calendar item class to handle both appointments and events
class CalendarItem {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String? location;
  final String type; // 'appointment' or 'event'
  final dynamic originalItem; // Store the original Appointment or Event

  CalendarItem({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.location,
    required this.type,
    required this.originalItem,
  });

  // Factory constructor to create from Appointment
  factory CalendarItem.fromAppointment(Appointment appointment) {
    return CalendarItem(
      id: appointment.id,
      title: appointment.title,
      description: appointment.description,
      dateTime: appointment.dateTime,
      location: appointment.location,
      type: 'appointment',
      originalItem: appointment,
    );
  }

  // Factory constructor to create from Event
  factory CalendarItem.fromEvent(Event event) {
    return CalendarItem(
      id: event.id,
      title: event.title,
      description: event.description,
      dateTime: event.startDate,
      location: event.location,
      type: 'event',
      originalItem: event,
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedView = 'all'; // 'all', 'appointments', 'events'

  Map<DateTime, List<CalendarItem>> _calendarItems = {};
  List<CalendarItem> _selectedDayItems = [];

  late TabController _tabController;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  DateTime? _selectedEndDateTime; // For events only

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedView = 'all';
              break;
            case 1:
              _selectedView = 'appointments';
              break;
            case 2:
              _selectedView = 'events';
              break;
          }
        });
        _filterItems();
      }
    });
    _loadCalendarItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Load both appointments and events
  Future<void> _loadCalendarItems() async {
    // Load appointments
    final appointments =
        await AppointmentStorageService.instance.getAppointments();
    final events = await EventService.instance.getLocalEvents();

    final Map<DateTime, List<CalendarItem>> itemsMap = {};

    // Process appointments
    for (var appointment in appointments) {
      final date = DateTime(appointment.dateTime.year,
          appointment.dateTime.month, appointment.dateTime.day);

      if (itemsMap[date] == null) {
        itemsMap[date] = [];
      }
      itemsMap[date]!.add(CalendarItem.fromAppointment(appointment));
    }

    // Process events
    for (var event in events) {
      final date = DateTime(
          event.startDate.year, event.startDate.month, event.startDate.day);

      if (itemsMap[date] == null) {
        itemsMap[date] = [];
      }
      itemsMap[date]!.add(CalendarItem.fromEvent(event));
    }

    // Update selected day items
    List<CalendarItem> selectedDayItems = [];
    if (_selectedDay != null) {
      final date =
          DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      selectedDayItems = itemsMap[date] ?? [];
      selectedDayItems.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    setState(() {
      _calendarItems = itemsMap;
      _selectedDayItems = _filterItemsByView(selectedDayItems);
    });
  }

  List<CalendarItem> _filterItemsByView(List<CalendarItem> items) {
    if (_selectedView == 'all') return items;
    // Match singular type with plural view (appointments -> appointment, events -> event)
    final typeToMatch = _selectedView == 'appointments' ? 'appointment' : 'event';
    return items.where((item) => item.type == typeToMatch).toList();
  }

  void _filterItems() {
    if (_selectedDay == null) return;
    final date = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    final allItems = _calendarItems[date] ?? [];

    setState(() {
      _selectedDayItems = _filterItemsByView(allItems);
    });
  }

  // Handle selection of a day on the calendar
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    final date = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final allItems = _calendarItems[date] ?? [];

    setState(() {
      _selectedDayItems = _filterItemsByView(allItems);
    });
  }

  // Check if a day has calendar items
  List<CalendarItem> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _calendarItems[date] ?? [];
  }

  // Show bottom sheet to add new appointment or event
  void _showAddBottomSheet({String type = 'appointment'}) {
    // Reset form fields
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _selectedDateTime = _selectedDay ?? DateTime.now();
    _selectedEndDateTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add ${type.capitalize()}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter title',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Enter description',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'Enter location',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date & Time'),
                  subtitle: Text(DateFormat('MMM dd, yyyy • h:mm a')
                      .format(_selectedDateTime)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateTime,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                      );
                      if (time != null) {
                        setState(() {
                          _selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),

                // Show end date/time field for events only
                if (type == 'event')
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Date & Time (optional)'),
                    subtitle: _selectedEndDateTime != null
                        ? Text(DateFormat('MMM dd, yyyy • h:mm a')
                            .format(_selectedEndDateTime!))
                        : const Text('Not specified'),
                    trailing: const Icon(Icons.event_available),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedEndDateTime ??
                            _selectedDateTime.add(const Duration(hours: 1)),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                              _selectedEndDateTime ??
                                  _selectedDateTime
                                      .add(const Duration(hours: 1))),
                        );
                        if (time != null) {
                          setState(() {
                            _selectedEndDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () {
                    // Validate
                    if (_titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a title')),
                      );
                      return;
                    }

                    if (type == 'appointment') {
                      _addAppointment();
                    } else {
                      _addEvent();
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add a new appointment
  Future<void> _addAppointment() async {
    final newAppointment = Appointment(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      dateTime: _selectedDateTime,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    await AppointmentStorageService.instance.saveAppointment(newAppointment);
    _loadCalendarItems(); // Refresh calendar data
  }

  // Add a new event
  Future<void> _addEvent() async {
    final newEvent = Event(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      startDate: _selectedDateTime,
      endDate: _selectedEndDateTime,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      isGlobal: false,
      createdAt: DateTime.now(),
    );

    await EventService.instance.saveLocalEvent(newEvent);
    _loadCalendarItems(); // Refresh calendar data
  }

  // Delete an item
  Future<void> _deleteItem(CalendarItem item) async {
    bool confirmed = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete ${item.type.capitalize()}'),
            content: Text('Are you sure you want to delete "${item.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    if (item.type == 'appointment') {
      await AppointmentStorageService.instance.deleteAppointment(item.id);
    } else {
      await EventService.instance.deleteLocalEvent(item.id);
    }

    _loadCalendarItems();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.type.capitalize()} deleted')),
    );
  }

  // Show details of an item
  void _showItemDetails(CalendarItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.type == 'appointment'
                          ? Colors.orange.shade100
                          : Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.type == 'appointment'
                          ? Icons.calendar_today
                          : _getEventIcon(item.title),
                      size: 20,
                      color: item.type == 'appointment'
                          ? Colors.orange.shade700
                          : Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.type.capitalize(),
                    style: TextStyle(
                      fontSize: 14,
                      color: item.type == 'appointment'
                          ? Colors.orange.shade700
                          : Colors.indigo.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      if (item.type == 'appointment') {
                        Navigator.pushNamed(context, '/appointments',
                            arguments: item.originalItem);
                      } else {
                        Navigator.pushNamed(context, '/events',
                            arguments: item.originalItem);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteItem(item);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • h:mm a').format(item.dateTime),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              if (item.type == 'event' &&
                  (item.originalItem as Event).endDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event_available,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Ends: ${DateFormat('MMM dd, yyyy • h:mm a').format((item.originalItem as Event).endDate!)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
              if (item.location != null && item.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.location!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ],
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              if (item.type == 'appointment') ...[
                if ((item.originalItem as Appointment).contactPerson != null &&
                    (item.originalItem as Appointment)
                        .contactPerson!
                        .isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        (item.originalItem as Appointment).contactPerson!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  if ((item.originalItem as Appointment).contactPhone != null &&
                      (item.originalItem as Appointment)
                          .contactPhone!
                          .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          (item.originalItem as Appointment).contactPhone!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendarItems,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Appointments'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  _selectedDay == null
                      ? 'No Date Selected'
                      : DateFormat.yMMMMd().format(_selectedDay!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedDayItems.length} items',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedDayItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedView == 'appointment'
                              ? Icons.calendar_today
                              : _selectedView == 'event'
                                  ? Icons.event
                                  : Icons.calendar_month,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedView == 'all'
                              ? 'No appointments or events for this day'
                              : 'No ${_selectedView}s for this day',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _selectedDayItems.length,
                    itemBuilder: (context, index) {
                      final item = _selectedDayItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showItemDetails(item),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: item.type == 'appointment'
                                        ? Colors.orange.shade100
                                        : Colors.indigo.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    item.type == 'appointment'
                                        ? Icons.calendar_today
                                        : _getEventIcon(item.title),
                                    color: item.type == 'appointment'
                                        ? Colors.orange.shade700
                                        : Colors.indigo.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            DateFormat('h:mm a')
                                                .format(item.dateTime),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.location != null &&
                                          item.location!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 14,
                                                  color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item.location!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedView == 'appointments') {
            _showAddBottomSheet(type: 'appointment');
          } else if (_selectedView == 'events') {
            _showAddBottomSheet(type: 'event');
          } else {
            // Show dialog to choose type
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('What would you like to add?'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Appointment'),
                      onTap: () {
                        Navigator.pop(context);
                        _showAddBottomSheet(type: 'appointment');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text('Event'),
                      onTap: () {
                        Navigator.pop(context);
                        _showAddBottomSheet(type: 'event');
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        },
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Extension to capitalize first letter of string
extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
