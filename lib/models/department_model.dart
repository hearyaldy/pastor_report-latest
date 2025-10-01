// lib/models/department_model.dart
import 'package:flutter/material.dart';

class Department {
  final String id;
  final String name;
  final IconData icon;
  final String formUrl;

  Department({
    required this.id,
    required this.name,
    required this.icon,
    required this.formUrl,
  });

  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: getIconFromString(map['icon'] ?? 'person'),
      formUrl: map['formUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': getIconString(icon),
      'formUrl': formUrl,
    };
  }

  static IconData getIconFromString(String iconName) {
    final iconMap = {
      'person': Icons.person,
      'account_balance': Icons.account_balance,
      'group': Icons.group,
      'message': Icons.message,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
      'family_restroom': Icons.family_restroom,
      'woman': Icons.woman,
      'child_care': Icons.child_care,
      'book': Icons.book,
      'person_pin': Icons.person_pin,
      'access_time': Icons.access_time,
      'volunteer_activism': Icons.volunteer_activism,
    };
    return iconMap[iconName] ?? Icons.dashboard;
  }

  static String getIconString(IconData icon) {
    if (icon == Icons.person) return 'person';
    if (icon == Icons.account_balance) return 'account_balance';
    if (icon == Icons.group) return 'group';
    if (icon == Icons.message) return 'message';
    if (icon == Icons.local_hospital) return 'local_hospital';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.family_restroom) return 'family_restroom';
    if (icon == Icons.woman) return 'woman';
    if (icon == Icons.child_care) return 'child_care';
    if (icon == Icons.book) return 'book';
    if (icon == Icons.person_pin) return 'person_pin';
    if (icon == Icons.access_time) return 'access_time';
    if (icon == Icons.volunteer_activism) return 'volunteer_activism';
    return 'dashboard';
  }

  // Get list of available icons for selection
  static List<Map<String, dynamic>> get availableIcons => [
    {'name': 'Person', 'icon': Icons.person, 'key': 'person'},
    {'name': 'Account Balance', 'icon': Icons.account_balance, 'key': 'account_balance'},
    {'name': 'Group', 'icon': Icons.group, 'key': 'group'},
    {'name': 'Message', 'icon': Icons.message, 'key': 'message'},
    {'name': 'Hospital', 'icon': Icons.local_hospital, 'key': 'local_hospital'},
    {'name': 'School', 'icon': Icons.school, 'key': 'school'},
    {'name': 'Family', 'icon': Icons.family_restroom, 'key': 'family_restroom'},
    {'name': 'Woman', 'icon': Icons.woman, 'key': 'woman'},
    {'name': 'Child Care', 'icon': Icons.child_care, 'key': 'child_care'},
    {'name': 'Book', 'icon': Icons.book, 'key': 'book'},
    {'name': 'Person Pin', 'icon': Icons.person_pin, 'key': 'person_pin'},
    {'name': 'Clock', 'icon': Icons.access_time, 'key': 'access_time'},
    {'name': 'Volunteer', 'icon': Icons.volunteer_activism, 'key': 'volunteer_activism'},
  ];
}
