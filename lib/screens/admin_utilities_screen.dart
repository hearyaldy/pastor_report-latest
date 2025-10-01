// lib/screens/admin_utilities_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pastor_report/providers/mission_provider.dart';
import 'package:pastor_report/utils/constants.dart';

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
                      _showLoading(
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
                title: 'Open Mission Management',
                description:
                    'Manage missions and their departments in the dedicated management screen.',
                icon: Icons.business,
                color: Colors.green,
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
                      // Show loading indicator
                      _showLoading(context, 'Reseeding data...');

                      // Reseed all data
                      await missionProvider.reseedAllData();

                      // Hide loading and show success
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'All data has been successfully reseeded!'),
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
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
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

  void _showLoading(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
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
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
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
