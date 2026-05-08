// lib/screens/inapp_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pastor_report/theme_manager.dart';
import 'package:pastor_report/models/department_model.dart';
import 'package:pastor_report/utils/constants.dart';

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
          body: CustomScrollView(
            slivers: [
              _buildModernAppBar(),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    // WebView Content
                    Expanded(
                      child: WebViewWidget(controller: _controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Floating Action Button for Departments
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              _showDepartmentMenu(
                  context); // Ensure this correctly calls the menu function
            },
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            child: const Icon(Icons.menu),
          ),
        );
      },
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentDepartmentName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.business,
                  color: Colors.white70,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'Department Portal',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primaryDark,
                  ],
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 20,
              child: Icon(
                Icons.web,
                size: 150,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Online Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () {
            _controller.reload();
          },
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.open_in_browser, color: Colors.white),
          onPressed: () {
            _controller.loadRequest(Uri.parse(currentUrl));
          },
          tooltip: 'Open in Browser',
        ),
      ],
    );
  }

  // Function to Show Departments Menu with all departments listed
  void _showDepartmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the bottom sheet to be scrollable
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // Initial height of the sheet
          minChildSize: 0.4, // Minimum height
          maxChildSize: 0.9, // Maximum height
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Handle bar for draggable sheet
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Header
                      Row(
                        children: [
                          const Icon(Icons.menu_book, color: AppColors.primaryLight),
                          const SizedBox(width: 12),
                          Text(
                            'Departments',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Switch to another department portal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Back to Departments List option
                      ListTile(
                        leading: const Icon(Icons.arrow_back, color: AppColors.primaryLight),
                        title: const Text('Back to Departments List'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/departments');
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Display all departments passed from the DepartmentsScreen
                      ...widget.departments.map((department) {
                        return ListTile(
                          leading: Icon(
                              Department.getIconFromString(department['icon']),
                              color: AppColors.primaryLight),
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
