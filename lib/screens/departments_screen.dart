// lib/screens/departments_screen.dart
import 'package:flutter/material.dart';
import 'package:pastor_report/screens/inapp_webview_screen.dart';

class DepartmentsScreen extends StatefulWidget {
  final bool isAdmin;

  const DepartmentsScreen({super.key, required this.isAdmin});

  @override
  // ignore: library_private_types_in_public_api
  _DepartmentsScreenState createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  final List<Map<String, dynamic>> departments = [
    {
      'name': 'Ministerial',
      'icon': Icons.person,
      'link': 'https://forms.gle/MinisterialLink',
    },
    {
      'name': 'Stewardship',
      'icon': Icons.account_balance,
      'link': 'https://forms.gle/Fwud8srq8aXikzY48',
    },
    {
      'name': 'Youth',
      'icon': Icons.group,
      'link': 'https://tinyurl.com/laporan-jpba',
    },
    {
      'name': 'Communication',
      'icon': Icons.message,
      'link': 'https://forms.gle/QRKusCXvhShcbi766',
    },
    {
      'name': 'Health Ministry',
      'icon': Icons.local_hospital,
      'link': 'https://forms.gle/aR4mRU8HopXGQ6cq5',
    },
    {
      'name': 'Education',
      'icon': Icons.school,
      'link': 'https://forms.gle/EducationLink',
    },
    {
      'name': 'Family Life',
      'icon': Icons.family_restroom,
      'link': 'https://forms.gle/iak14RPeULZ18BCD6',
    },
    {
      'name': 'Women\'s Ministry',
      'icon': Icons.woman,
      'link': 'https://forms.gle/1tzirnartRswrDbb6',
    },
    {
      'name': 'Children',
      'icon': Icons.child_care,
      'link': 'https://docs.google.com/forms/d/e/1FAIpQLScEof1Gbwv1WccmcEnQyZlY10CTpE040IvybbQavAN-1OKctQ/viewform',
    },
    {
      'name': 'Publishing',
      'icon': Icons.book,
      'link': 'https://forms.gle/PublishingLink',
    },
    {
      'name': 'Personal Ministry',
      'icon': Icons.person_pin,
      'link': 'https://forms.gle/PersonalMinistryLink',
    },
    {
      'name': 'Sabbath School',
      'icon': Icons.access_time,
      'link': 'https://forms.gle/muGXDfhyvLvvh5So8',
    },
    {
      'name': 'Adventist Community Services',
      'icon': Icons.volunteer_activism,
      'link': 'https://forms.gle/AdventistCommunityServicesLink',
    },
  ];

  // Utility function to get the current formatted date
  String _getCurrentDate() {
    final now = DateTime.now();
    return '${_getDayOfWeek(now.weekday)} | ${now.day}-${now.month}-${now.year}';
  }

  // Utility function to get the day of the week
  String _getDayOfWeek(int weekday) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with image, app name, and date
          Stack(
            children: [
              Container(
                height: 150, // Set height to 150px
                width: double.infinity, // Stretch to full width of the screen
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/header_image.png'), // Ensure this image exists
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Positioned(
                left: 16,
                bottom: 20,
                child: Text(
                  'Pastor Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 5,
                child: Text(
                  _getCurrentDate(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // List of departments
          Expanded(
            child: ListView.builder(
              itemCount: departments.length,
              itemBuilder: (context, index) {
                final department = departments[index];
                return Card(
                  color: const Color(0xFFF9DBBA), // Background color from your palette
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Icon(department['icon'], color: const Color(0xFF1A4870)), // Icon color
                    title: Text(
                      department['name'],
                      style: const TextStyle(
                        fontSize: 16.0,
                        color: Color(0xFF1F316F),
                      ),
                    ),
                    onTap: () {
                      // Navigate to the in-app WebView with the department link and name
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InAppWebViewScreen(
                            initialUrl: department['link'],
                            initialDepartmentName: department['name'],
                            departments: departments, // Pass the full list of departments
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Bottom navigation bar with settings button triggering a bottom sheet
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/');
          } else if (index == 1) {
            // Display settings or bottom sheet for settings if needed
          }
        },
      ),
    );
  }
}
