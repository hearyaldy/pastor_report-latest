import 'package:flutter/material.dart';
import 'package:pastor_report/models/appointment_model.dart';
import 'package:pastor_report/models/event_model.dart';
import 'package:pastor_report/models/global_event_model.dart';
import 'package:pastor_report/services/appointment_storage_service.dart';
import 'package:pastor_report/services/event_service.dart';
import 'package:pastor_report/services/global_event_service.dart';
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

  // Factory constructor to create from GlobalEvent
  factory CalendarItem.fromGlobalEvent(GlobalEvent globalEvent) {
    return CalendarItem(
      id: globalEvent.id,
      title: globalEvent.title,
      description: globalEvent.notes,
      dateTime: globalEvent.dateTime,
      location: globalEvent.department,
      type: 'global_event',
      originalItem: globalEvent,
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
  bool _isMonthView = false; // New state to toggle month view

  Map<DateTime, List<CalendarItem>> _calendarItems = {};
  List<CalendarItem> _selectedDayItems = [];
  List<CalendarItem> _monthViewItems = []; // Items for month view

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
    print('Initializing TabController with length: 4');
    _tabController = TabController(length: 4, vsync: this);
    print('TabController initialized. Current index: ${_tabController.index}');
    _tabController.addListener(() {
      // Defensive check for valid index
      print('TabController index changed to: ${_tabController.index}, Length: ${_tabController.length}');
      if (_tabController.index < 0 || _tabController.index >= 4) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.index != 0) {
            _tabController.animateTo(0);
          }
        });
        return;
      }

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
            case 3:
              _selectedView = 'global_events';
              break;
          }
        });
        _filterItems();
        if (_isMonthView) {
          // Update month view items when tab changes
          setState(() {
            _monthViewItems = _getItemsForMonth();
          });
        }
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

  // Load appointments, events, and global events
  Future<void> _loadCalendarItems() async {
    // Load appointments
    final appointments =
        await AppointmentStorageService.instance.getAppointments();
    final events = await EventService.instance.getLocalEvents();
    print('Loading global events from service...');
    final globalEvents = await GlobalEventService.instance.getAllEvents();
    print('Retrieved ${globalEvents.length} global events from service');

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

    // Process global events
    print('Processing ${globalEvents.length} global events...');
    for (var globalEvent in globalEvents) {
      print('Processing global event: ${globalEvent.title} on ${globalEvent.dateTime}');
      final date = DateTime(
          globalEvent.dateTime.year, globalEvent.dateTime.month, globalEvent.dateTime.day);

      if (itemsMap[date] == null) {
        itemsMap[date] = [];
      }
      itemsMap[date]!.add(CalendarItem.fromGlobalEvent(globalEvent));
    }
    print('Finished processing global events');

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
      
      // Update month view items if in month view
      if (_isMonthView) {
        _monthViewItems = _getItemsForMonth();
      }
    });
  }

  List<CalendarItem> _filterItemsByView(List<CalendarItem> items) {
    if (_selectedView == 'all') return items;
    
    // Match view with item type
    String typeToMatch;
    switch (_selectedView) {
      case 'appointments':
        typeToMatch = 'appointment';
        break;
      case 'events':
        typeToMatch = 'event';
        break;
      case 'global_events':
        typeToMatch = 'global_event';
        break;
      default:
        typeToMatch = _selectedView;
    }
    
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
      
      // Update month view items if in month view
      if (_isMonthView) {
        _monthViewItems = _getItemsForMonth();
      }
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
      
      // Update month view items if in month view
      if (_isMonthView) {
        _monthViewItems = _getItemsForMonth();
      }
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

    Color eventTypeColor = type == 'appointment' 
        ? Colors.orange 
        : AppColors.primaryLight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: eventTypeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: eventTypeColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: eventTypeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: eventTypeColor.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          type == 'appointment' 
                              ? Icons.calendar_today 
                              : Icons.event,
                          color: eventTypeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add ${type.capitalize()}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: eventTypeColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter title',
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: eventTypeColor,
                      ),
                    ),
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
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(
                      Icons.calendar_today,
                      color: eventTypeColor,
                    ),
                    title: const Text('Date & Time'),
                    subtitle: Text(DateFormat('MMM dd, yyyy • h:mm a')
                        .format(_selectedDateTime)),
                    trailing: const Icon(Icons.chevron_right),
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
                ),

                // Show end date/time field for events only
                if (type == 'event') ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Icon(
                        Icons.event_available,
                        color: eventTypeColor,
                      ),
                      title: const Text('End Date & Time (optional)'),
                      subtitle: _selectedEndDateTime != null
                          ? Text(DateFormat('MMM dd, yyyy • h:mm a')
                              .format(_selectedEndDateTime!))
                          : const Text('Not specified'),
                      trailing: const Icon(Icons.chevron_right),
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
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
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
                      backgroundColor: eventTypeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
    try {
      await AppointmentStorageService.instance.createAppointment(
        title: _titleController.text.trim(),
        dateTime: _selectedDateTime,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        isCompleted: false,
      );
      _loadCalendarItems(); // Refresh calendar data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating appointment: $e')),
        );
      }
    }
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
    bool confirmed = await _showDeleteConfirmationBottomSheet(item);

    if (!confirmed) return;

    if (item.type == 'appointment') {
      await AppointmentStorageService.instance.deleteAppointment(item.id);
    } else if (item.type == 'event') {
      await EventService.instance.deleteLocalEvent(item.id);
    } else if (item.type == 'global_event') {
      // Note: Global events should typically only be managed by admins through the global events management screen
      // But if we allow deletion from here, we would use:
      // await GlobalEventService.instance.deleteEvent(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Global events can only be deleted by administrators')),
      );
      return;
    }

    _loadCalendarItems();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.type.capitalize()} deleted')),
    );
  }
  
  // Show delete confirmation bottom sheet
  Future<bool> _showDeleteConfirmationBottomSheet(CalendarItem item) async {
    Color eventTypeColor = item.type == 'appointment' 
        ? Colors.orange 
        : item.type == 'global_event' 
            ? Colors.purple 
            : AppColors.primaryLight;

    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: eventTypeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: eventTypeColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: eventTypeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: eventTypeColor.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        item.type == 'appointment'
                            ? Icons.calendar_today
                            : item.type == 'global_event'
                                ? Icons.public
                                : _getEventIcon(item.title),
                        color: eventTypeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete ${item.type.capitalize()}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: eventTypeColor,
                            ),
                          ),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to delete this item?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ).then((value) => value ?? false);
  }

  // Show details of an item
  void _showItemDetails(CalendarItem item) {
    Color eventTypeColor = item.type == 'appointment' 
        ? Colors.orange 
        : item.type == 'global_event' 
            ? Colors.purple 
            : AppColors.primaryLight;
            
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: eventTypeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: eventTypeColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: eventTypeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: eventTypeColor.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        item.type == 'appointment'
                            ? Icons.calendar_today
                            : item.type == 'global_event'
                                ? Icons.public
                                : _getEventIcon(item.title),
                        color: eventTypeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.type == 'global_event' 
                                ? 'Global Event' 
                                : item.type.capitalize(),
                            style: TextStyle(
                              fontSize: 14,
                              color: eventTypeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.type != 'global_event') ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          Navigator.pop(context);
                          if (item.type == 'appointment') {
                            Navigator.pushNamed(context, '/appointments',
                                arguments: item.originalItem);
                          } else if (item.type == 'event') {
                            Navigator.pushNamed(context, '/events',
                                arguments: item.originalItem);
                          }
                        },
                        color: eventTypeColor,
                        style: IconButton.styleFrom(
                          backgroundColor: eventTypeColor.withOpacity(0.1),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteItem(item);
                        },
                        color: Colors.red,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy • h:mm a').format(item.dateTime),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              if (item.type == 'event' &&
                  (item.originalItem as Event).endDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event_available,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Ends: ${DateFormat('MMM dd, yyyy • h:mm a').format((item.originalItem as Event).endDate!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.location != null && item.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.location!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
              if (item.type == 'appointment') ...[
                if ((item.originalItem as Appointment).contactPerson != null &&
                    (item.originalItem as Appointment)
                        .contactPerson!
                        .isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Contact',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        (item.originalItem as Appointment).contactPerson!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
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
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
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

  List<CalendarItem> _getItemsForMonth() {
    // Filter items based on the selected tab view for the current month
    List<CalendarItem> monthItems = [];
    
    // Get all items for the current month
    _calendarItems.forEach((date, items) {
      if (date.month == _focusedDay.month && date.year == _focusedDay.year) {
        // Apply the same filter as for day view to each item before adding
        List<CalendarItem> filteredItems = _filterItemsByView(items);
        monthItems.addAll(filteredItems);
      }
    });
    
    // Sort the final list
    monthItems.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return monthItems;
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
          // Toggle between day view and month view
          IconButton(
            icon: Icon(_isMonthView ? Icons.today : Icons.date_range),
            onPressed: () {
              setState(() {
                _isMonthView = !_isMonthView;
              });
            },
            tooltip: _isMonthView ? 'Switch to Day View' : 'Switch to Month View',
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
            Tab(text: 'Global Events'),
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
              if (_isMonthView) {
                // Update month view items when month changes
                setState(() {
                  _monthViewItems = _getItemsForMonth();
                });
              }
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
                _isMonthView
                    ? Text(
                        '${DateFormat('MMMM yyyy').format(_focusedDay)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : Text(
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
                  _isMonthView
                      ? '${_getItemsForMonth().length} items this month'
                      : '${_selectedDayItems.length} items',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isMonthView
                ? _buildMonthView()
                : (_selectedDayItems.isEmpty
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
                          Color eventTypeColor = item.type == 'appointment' 
                              ? Colors.orange 
                              : item.type == 'global_event' 
                                  ? Colors.purple 
                                  : AppColors.primaryLight;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: eventTypeColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            elevation: 1,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showItemDetails(item),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: eventTypeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: eventTypeColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Icon(
                                        item.type == 'appointment'
                                            ? Icons.calendar_today
                                            : item.type == 'global_event'
                                                ? Icons.public
                                                : _getEventIcon(item.title),
                                        color: eventTypeColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: eventTypeColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: eventTypeColor.withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  DateFormat('h:mm a').format(item.dateTime),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: eventTypeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (item.location != null && item.location!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.location_on,
                                                    size: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      item.location!,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )),
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
            // Show bottom sheet to choose type
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add New',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.orange,
                          ),
                        ),
                        title: const Text('Appointment'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          _showAddBottomSheet(type: 'appointment');
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryLight.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.event,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        title: const Text('Event'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          _showAddBottomSheet(type: 'event');
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          }
        },
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthView() {
    List<CalendarItem> monthItems = _getItemsForMonth();
    
    // Sort items by date and time
    monthItems.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    if (monthItems.isEmpty) {
      return Center(
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
                  ? 'No appointments or events this month'
                  : 'No ${_selectedView}s this month',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: monthItems.length,
      itemBuilder: (context, index) {
        final item = monthItems[index];
        Color eventTypeColor = item.type == 'appointment' 
            ? Colors.orange 
            : item.type == 'global_event' 
                ? Colors.purple 
                : AppColors.primaryLight;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: eventTypeColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showItemDetails(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: eventTypeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: eventTypeColor.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      item.type == 'appointment'
                          ? Icons.calendar_today
                          : item.type == 'global_event'
                              ? Icons.public
                              : _getEventIcon(item.title),
                      color: eventTypeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: eventTypeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: eventTypeColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                DateFormat('MMM dd').format(item.dateTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: eventTypeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('h:mm a').format(item.dateTime),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (item.location != null && item.location!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.location!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extension to capitalize first letter of string
extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
