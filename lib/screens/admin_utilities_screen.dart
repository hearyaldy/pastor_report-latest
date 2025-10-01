// lib/screens/admin_utilities_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/providers/mission_provider.dart';

class AdminUtilitiesScreen extends StatelessWidget {
  const AdminUtilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Utilities'),
      ),
      body: Consumer<MissionProvider>(
        builder: (context, missionProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const _SectionHeader(title: 'Data Structure Management'),
              SwitchListTile(
                title: const Text('Use Mission-Based Structure'),
                subtitle: const Text(
                    'Switch between legacy structure and new mission-based structure'),
                value: missionProvider.isUsingMissionStructure,
                onChanged: (value) {
                  missionProvider.toggleUsingMissionStructure(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Switched to ${value ? "mission-based" : "legacy"} structure'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _ActionCard(
                title: 'Migrate to Mission Structure',
                description:
                    'Migrate existing departments to the new mission-based structure. This preserves existing data.',
                icon: Icons.upgrade,
                color: Colors.green,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Migration'),
                      content: const Text(
                          'This will migrate your existing department data to the new mission-based structure. '
                          'Existing data will be preserved.\n\n'
                          'Do you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('YES, MIGRATE DATA'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      // Show loading indicator
                      _showLoadingDialog(
                          context, 'Migrating data to mission structure...');

                      // Migrate data
                      await missionProvider.migrateToMissionStructure();

                      // Hide loading and show success
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Data has been successfully migrated to the new mission structure!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      // Hide loading and show error
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error during migration: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              const _SectionHeader(title: 'Mission & Department Management'),
              _ActionCard(
                title: 'Mission Management',
                description:
                    'View, add, edit, or delete missions and their departments.',
                icon: Icons.business,
                color: Colors.blue,
                onTap: () {
                  Navigator.pushNamed(
                      context, AppConstants.routeMissionManagement);
                },
              ),
              _ActionCard(
                title: 'Reseed All Data',
                description:
                    'This will delete all existing missions and departments and recreate them with default data.',
                icon: Icons.refresh,
                color: Colors.blue,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Reseed'),
                      content: const Text(
                          'WARNING: This will delete all existing missions and departments and recreate them with default data. '
                          'This action cannot be undone.\n\n'
                          'Are you sure you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('YES, RESEED ALL',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      // Show loading indicator with more detailed message
                      _showLoadingDialog(context, 'Reseeding data...\nThis may take a moment. Please wait.', name: 'reseed_loading');

                      // Set a timeout to update the loading message after a few seconds
                      // to reassure the user that the process is still running
                      Future.delayed(const Duration(seconds: 5), () {
                        if (context.mounted) {
                          // Check if the dialog is still showing before updating
                          _updateLoadingDialog(context, 
                              'Still working...\nDeleting existing data and creating new missions and departments.',
                              'reseed_loading');
                        }
                      });
                      
                      // Add another update after a longer delay
                      Future.delayed(const Duration(seconds: 15), () {
                        if (context.mounted) {
                          _updateLoadingDialog(context, 
                              'Almost there...\nSetting up new missions and departments structure.',
                              'reseed_loading');
                        }
                      });

                      // Reseed all data with a timeout
                      await missionProvider.reseedAllData()
                          .timeout(const Duration(seconds: 60), onTimeout: () {
                        throw TimeoutException('Operation timed out. The database might be too large or there might be connection issues.');
                      });

                      // Hide loading and show success
                      if (context.mounted) {
                        _dismissLoadingDialog(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'All data has been successfully reseeded!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      // Hide loading and show error
                      if (context.mounted) {
                        _dismissLoadingDialog(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error during reseed: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 10),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
  
  // Show a loading dialog with a message
  void _showLoadingDialog(BuildContext context, String message, {String name = 'loading_dialog'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      routeSettings: RouteSettings(name: name),
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button from closing
        child: AlertDialog(
          content: SizedBox(
            height: 120, // Make it taller for multi-line messages
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Update an existing loading dialog with a new message
  void _updateLoadingDialog(BuildContext context, String newMessage, String dialogName) {
    // First dismiss any existing dialog
    _dismissLoadingDialog(context);
    
    // Then show a new one with the updated message
    _showLoadingDialog(context, newMessage, name: dialogName);
  }
  
  // Dismiss the loading dialog safely
  void _dismissLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).popUntil((route) {
      return route.settings.name != 'loading_dialog' && 
             route.settings.name != 'reseed_loading';
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}