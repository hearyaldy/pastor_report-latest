import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pastor_report/models/appointment_model.dart';

class AppointmentStorageService {
  static const String _appointmentsKey = 'appointments';
  static final AppointmentStorageService instance = AppointmentStorageService._();

  AppointmentStorageService._();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<Appointment>> getAppointments() async {
    if (_prefs == null) await initialize();

    final appointmentsJson = _prefs!.getString(_appointmentsKey);
    if (appointmentsJson == null) return [];

    final List<dynamic> decoded = json.decode(appointmentsJson);
    return decoded.map((json) => Appointment.fromJson(json)).toList();
  }

  Future<void> saveAppointment(Appointment appointment) async {
    final appointments = await getAppointments();

    // Check if appointment already exists
    final index = appointments.indexWhere((a) => a.id == appointment.id);
    if (index != -1) {
      appointments[index] = appointment;
    } else {
      appointments.add(appointment);
    }

    await _saveAppointments(appointments);
  }

  Future<void> deleteAppointment(String id) async {
    final appointments = await getAppointments();
    appointments.removeWhere((appointment) => appointment.id == id);
    await _saveAppointments(appointments);
  }

  Future<void> toggleAppointmentComplete(String id) async {
    final appointments = await getAppointments();
    final index = appointments.indexWhere((appointment) => appointment.id == id);

    if (index != -1) {
      final appointment = appointments[index];
      appointments[index] = appointment.copyWith(
        isCompleted: !appointment.isCompleted,
      );
      await _saveAppointments(appointments);
    }
  }

  Future<void> _saveAppointments(List<Appointment> appointments) async {
    if (_prefs == null) await initialize();

    final encoded = json.encode(appointments.map((a) => a.toJson()).toList());
    await _prefs!.setString(_appointmentsKey, encoded);
  }

  // Get upcoming appointments
  Future<List<Appointment>> getUpcomingAppointments() async {
    final appointments = await getAppointments();
    final now = DateTime.now();
    return appointments
        .where((apt) => apt.dateTime.isAfter(now) && !apt.isCompleted)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime)); // Nearest first
  }

  // Get today's appointments
  Future<List<Appointment>> getTodayAppointments() async {
    final appointments = await getAppointments();
    final now = DateTime.now();
    return appointments
        .where((apt) =>
            apt.dateTime.year == now.year &&
            apt.dateTime.month == now.month &&
            apt.dateTime.day == now.day)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // Get past appointments
  Future<List<Appointment>> getPastAppointments() async {
    final appointments = await getAppointments();
    final now = DateTime.now();
    return appointments.where((apt) => apt.dateTime.isBefore(now)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // Recent first
  }
}
