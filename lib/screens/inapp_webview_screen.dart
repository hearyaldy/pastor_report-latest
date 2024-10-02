// lib/screens/inapp_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pastor_report/theme_manager.dart';

class InAppWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String initialDepartmentName;
  final List<Map<String, dynamic>> departments; // Accept the department list

  const InAppWebViewScreen({
    super.key,
    required this.initialUrl,
    required this.initialDepartmentName,
    required this.departments, // Ensure this is passed from DepartmentsScreen
  });

  @override
  InAppWebViewScreenState createState() => InAppWebViewScreenState();
}

class InAppWebViewScreenState extends State<InAppWebViewScreen> {
  late final WebViewController _controller;
  String currentDepartmentName;
  String currentUrl;

  InAppWebViewScreenState()
      : currentDepartmentName = '',
        currentUrl = '';

  @override
  void initState() {
    super.initState();
    currentDepartmentName = widget.initialDepartmentName;
    currentUrl = widget.initialUrl;

    // Initialize the WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(currentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.isDarkTheme,
      builder: (context, isDarkTheme, child) {
        return Scaffold(
          backgroundColor: isDarkTheme ? Colors.black : Colors.white,
          body: Column(
            children: [
              // Header with department name
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/header_image.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        currentDepartmentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // WebView Content
              Expanded(
                child: WebViewWidget(controller: _controller),
              ),
            ],
          ),
          // Bottom Navigation Bar with additional link to go back to Departments list
          bottomNavigationBar: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'Departments', // New item for navigating back to the departments list
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
            onTap: (index) {
              if (index == 0) {
                Navigator.pushNamed(context, '/'); // Navigate to Home
              } else if (index == 1) {
                Navigator.pushNamed(context, '/departments'); // Navigate back to Departments list
              } else if (index == 2) {
                _showSettingsMenu(context); // Show settings menu
              }
            },
          ),
          // Floating Action Button for Departments
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              _showDepartmentMenu(context); // Ensure this correctly calls the menu function
            },
            backgroundColor: const Color.fromARGB(255, 26, 72, 112),
            child: const Icon(Icons.menu),
          ),
        );
      },
    );
  }

  // Function to Show Settings Menu with Theme Toggle
  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Dark Theme'),
                value: ThemeManager.isDarkTheme.value,
                onChanged: (value) {
                  ThemeManager.isDarkTheme.value = value;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to Show Departments Menu with all departments listed
  void _showDepartmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the bottom sheet to be scrollable
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // Initial height of the sheet
          minChildSize: 0.4, // Minimum height
          maxChildSize: 0.9, // Maximum height
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.arrow_back),
                      title: const Text('Back to Departments List'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/departments');
                      },
                    ),
                    const Divider(),
                    // Display all departments passed from the DepartmentsScreen
                    ...widget.departments.map((department) {
                      return ListTile(
                        leading: Icon(department['icon']),
                        title: Text(department['name']),
                        onTap: () {
                          setState(() {
                            currentDepartmentName = department['name'];
                            currentUrl = department['link'];
                            _controller.loadRequest(Uri.parse(currentUrl));
                          });
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
