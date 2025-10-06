// lib/screens/admin_utilities_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/providers/mission_provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/data_import_service.dart';

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
                title: 'Import Regions & Districts',
                description:
                    'Import 10 regions and 59 districts into the current mission. This will add organizational structure.',
                icon: Icons.upload_file,
                color: Colors.orange,
                onTap: () async {
                  final authProvider = context.read<AuthProvider>();
                  final missionId = authProvider.user?.mission;

                  if (missionId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No mission selected'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Show preview dialog
                  final stats = DataImportService.instance.getImportStats();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Import Regions & Districts'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This will import:\n'
                              '• ${stats['totalRegions']} Regions\n'
                              '• ${stats['totalDistricts']} Districts\n\n'
                              'Districts per region:',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: (stats['districtsByRegion']
                                          as Map<int, List<String>>)
                                      .entries
                                      .map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '  Region ${entry.key}: ${entry.value.length} districts',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('IMPORT'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    try {
                      // Show loading indicator
                      _showLoadingDialog(context,
                          'Importing regions and districts...\nThis may take a moment.');

                      // Import data
                      final result = await DataImportService.instance
                          .importRegionsAndDistricts(missionId);

                      // Hide loading and show success
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Import completed!\n'
                              'Regions created: ${result['regionsCreated']}/${result['totalRegions']}\n'
                              'Districts created: ${result['districtsCreated']}/${result['totalDistricts']}\n'
                              'Districts skipped (already exist): ${result['districtsSkipped']}',
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      // Hide loading and show error
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error during import: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Update Staff Districts',
                description:
                    'Update 63 staff members with their district and region assignments based on the latest data.',
                icon: Icons.people_outline,
                color: Colors.purple,
                onTap: () async {
                  final authProvider = context.read<AuthProvider>();
                  final missionId = authProvider.user?.mission;

                  if (missionId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No mission selected'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Update Staff Districts'),
                      content: const Text(
                        'This will update 63 staff members with their district and region assignments.\n\n'
                        'Staff will be matched by name and updated with the correct district and region.\n\n'
                        'Do you want to continue?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                          ),
                          child: const Text('UPDATE'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    try {
                      // Show loading indicator
                      _showLoadingDialog(context,
                          'Updating staff districts...\nThis may take a moment.');

                      // Update staff
                      final result = await DataImportService.instance
                          .updateStaffDistricts(missionId);

                      // Hide loading and show success
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Update completed!\n'
                              'Staff updated: ${result['staffUpdated']}\n'
                              'Staff not found: ${result['staffNotFound']}\n'
                              'Staff skipped (no changes): ${result['staffSkipped']}\n'
                              'Total staff in data: ${result['totalStaff']}',
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    } catch (e) {
                      // Hide loading and show error
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error during update: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              const _SectionHeader(title: 'Diagnostics'),
              _ActionCard(
                title: 'Check Missions Collection',
                description:
                    'Display all missions from Firestore to debug mission selector issues.',
                icon: Icons.bug_report,
                color: Colors.purple,
                onTap: () async {
                  final firestore = FirebaseFirestore.instance;

                  try {
                    final missionsSnapshot =
                        await firestore.collection('missions').get();

                    if (context.mounted) {
                      final missions = missionsSnapshot.docs.map((doc) {
                        final data = doc.data();
                        return 'ID: ${doc.id}\n'
                            'Name: ${data['name']}\n'
                            'Code: ${data['code']}\n'
                            'Description: ${data['description']}\n';
                      }).join('\n---\n');

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                              'Missions (${missionsSnapshot.docs.length})'),
                          content: SingleChildScrollView(
                            child: Text(missions.isEmpty
                                ? 'No missions found'
                                : missions),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CLOSE'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Fix User Mission IDs',
                description:
                    'Convert user mission names to Firestore IDs. This ensures consistency across the app.',
                icon: Icons.person_search,
                color: Colors.orange,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Fix User Missions'),
                      content: const Text(
                          'This will convert mission names in user profiles to Firestore IDs.\n\n'
                          'For example: "Sabah Mission" → "4LFC9isp22H7Og1FHBm6"\n\n'
                          'This ensures all users have consistent mission IDs.\n\n'
                          'Do you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('FIX USERS'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    try {
                      _showLoadingDialog(context, 'Fixing user missions...');

                      final firestore = FirebaseFirestore.instance;

                      // Get all missions to create a name->ID map
                      final missionsSnapshot =
                          await firestore.collection('missions').get();
                      final missionNameToId = <String, String>{};
                      for (var doc in missionsSnapshot.docs) {
                        final name = doc.data()['name'] as String?;
                        if (name != null) {
                          missionNameToId[name] = doc.id;
                        }
                      }

                      // Get all users
                      final usersSnapshot =
                          await firestore.collection('users').get();

                      int updated = 0;
                      int skipped = 0;
                      int failed = 0;

                      for (var userDoc in usersSnapshot.docs) {
                        try {
                          final userData = userDoc.data();
                          final currentMission = userData['mission'] as String?;

                          if (currentMission == null || currentMission.isEmpty) {
                            skipped++;
                            continue;
                          }

                          // Check if it's already a Firestore ID (long random string)
                          if (currentMission.length > 15 &&
                              !currentMission.contains(' ')) {
                            skipped++;
                            continue;
                          }

                          // It's a mission name, convert to ID
                          final missionId = missionNameToId[currentMission];
                          if (missionId != null) {
                            await firestore
                                .collection('users')
                                .doc(userDoc.id)
                                .update({'mission': missionId});
                            updated++;
                            print(
                                '✅ Updated user ${userDoc.id}: "$currentMission" → "$missionId"');
                          } else {
                            failed++;
                            print(
                                '❌ No mission ID found for name: $currentMission');
                          }
                        } catch (e) {
                          failed++;
                          print('❌ Error updating user ${userDoc.id}: $e');
                        }
                      }

                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Fixed $updated users. Skipped: $skipped, Failed: $failed'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              const _SectionHeader(title: 'Financial Reports'),
              _ActionCard(
                title: 'Fix Financial Reports Mission IDs',
                description:
                    'Update existing financial reports to include mission ID. This fixes the issue where Mission Page doesn\'t show all church reports.',
                icon: Icons.healing,
                color: Colors.teal,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Fix Financial Reports'),
                      content: const Text(
                          'This will update all financial reports that are missing mission ID. '
                          'The mission ID will be populated from each church\'s data.\n\n'
                          'This is safe and will not affect your existing data.\n\n'
                          'Do you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: const Text('FIX REPORTS'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    try {
                      // Show loading indicator
                      _showLoadingDialog(context,
                          'Fixing financial reports...\nThis may take a moment.');

                      final firestore = FirebaseFirestore.instance;

                      // Get all reports (we'll fix both null and incorrect values)
                      final reportsSnapshot = await firestore
                          .collection('financial_reports')
                          .get();

                      int updated = 0;
                      int failed = 0;
                      int skipped = 0;

                      for (var reportDoc in reportsSnapshot.docs) {
                        try {
                          final reportData = reportDoc.data();
                          final churchId = reportData['churchId'] as String?;
                          final currentMissionId = reportData['missionId'] as String?;

                          if (churchId == null) {
                            failed++;
                            continue;
                          }

                          // Get the church to find its correct missionId
                          final churchDoc = await firestore
                              .collection('churches')
                              .doc(churchId)
                              .get();

                          if (!churchDoc.exists) {
                            failed++;
                            continue;
                          }

                          final churchData = churchDoc.data()!;
                          final correctMissionId = churchData['missionId'] as String?;

                          if (correctMissionId == null) {
                            failed++;
                            continue;
                          }

                          // Check if needs update (null OR incorrect value)
                          if (currentMissionId != correctMissionId) {
                            // Update the report with correct missionId
                            await firestore
                                .collection('financial_reports')
                                .doc(reportDoc.id)
                                .update({
                              'missionId': correctMissionId,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            updated++;
                          } else {
                            skipped++;
                          }
                        } catch (e) {
                          failed++;
                        }
                      }

                      // Hide loading and show success
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Financial reports fixed!\n'
                              'Total processed: ${reportsSnapshot.docs.length}\n'
                              'Updated: $updated\n'
                              'Already correct: $skipped\n'
                              'Failed: $failed\n\n'
                              'Mission pages should now show all reports correctly.',
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                      }
                    } catch (e) {
                      // Hide loading and show error
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error fixing reports: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }
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