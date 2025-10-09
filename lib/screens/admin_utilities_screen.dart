// lib/screens/admin_utilities_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pastor_report/utils/constants.dart';
import 'package:pastor_report/providers/mission_provider.dart';
import 'package:pastor_report/providers/auth_provider.dart';
import 'package:pastor_report/services/data_import_service.dart';
import 'package:pastor_report/utils/fix_staff_region_district.dart';
import 'package:pastor_report/utils/map_staff_names_to_ids.dart';
import 'package:pastor_report/utils/diagnose_staff_data.dart';
import 'package:pastor_report/utils/import_staff_assignments.dart';
import 'package:pastor_report/utils/check_unmatched_staff.dart';
import 'package:pastor_report/utils/fix_staff_names.dart';

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
              const _SectionHeader(title: 'Staff Data Management'),
              _ActionCard(
                title: 'Analyze Staff Region/District IDs',
                description:
                    'Check all staff records for invalid region/district IDs and show which ones need fixing.',
                icon: Icons.analytics,
                color: Colors.purple,
                onTap: () async {
                  _showLoadingDialog(context, 'Analyzing staff records...');

                  try {
                    final results =
                        await StaffRegionDistrictFixer.analyzeStaffRecords();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading

                      final invalidRegions =
                          (results['invalid_regions'] as List).length;
                      final invalidDistricts =
                          (results['invalid_districts'] as List).length;

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Analysis Results'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Total Staff: ${results['total_staff']}'),
                                Text(
                                    'Staff with Region: ${results['staff_with_region']}'),
                                Text(
                                    'Staff with District: ${results['staff_with_district']}'),
                                const Divider(),
                                Text(
                                    'Valid Regions: ${results['valid_regions']}',
                                    style: const TextStyle(color: Colors.green)),
                                Text(
                                    'Valid Districts: ${results['valid_districts']}',
                                    style: const TextStyle(color: Colors.green)),
                                const Divider(),
                                Text('Invalid Regions: $invalidRegions',
                                    style: TextStyle(
                                        color: invalidRegions > 0
                                            ? Colors.red
                                            : Colors.green)),
                                Text('Invalid Districts: $invalidDistricts',
                                    style: TextStyle(
                                        color: invalidDistricts > 0
                                            ? Colors.red
                                            : Colors.green)),
                                if (invalidRegions > 0 || invalidDistricts > 0)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: Text(
                                      'Check the console/logs for detailed list of invalid records.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                              ],
                            ),
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
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error analyzing staff: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Clear Invalid Region/District IDs',
                description:
                    'Remove invalid region/district IDs from staff records. This will set them to null.',
                icon: Icons.cleaning_services,
                color: Colors.red,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Cleanup'),
                      content: const Text(
                          'This will remove invalid region and district IDs from staff records by setting them to null.\n\n'
                          'Run "Analyze Staff Region/District IDs" first to see which records will be affected.\n\n'
                          'Do you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          child: const Text('YES, CLEAR INVALID IDs'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    _showLoadingDialog(context, 'Clearing invalid IDs...');

                    try {
                      final count =
                          await StaffRegionDistrictFixer.clearInvalidIds();

                      if (context.mounted) {
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Successfully cleared $count invalid IDs'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error clearing IDs: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'List Valid Regions & Districts',
                description:
                    'Show all valid region and district IDs organized by mission. Check console for output.',
                icon: Icons.list_alt,
                color: Colors.teal,
                onTap: () async {
                  _showLoadingDialog(
                      context, 'Loading regions and districts...');

                  try {
                    await StaffRegionDistrictFixer
                        .listValidRegionsAndDistricts();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Check the console/logs for the complete list'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error listing data: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Preview Name-to-ID Mapping',
                description:
                    'Preview which staff district/region names will be mapped to IDs. No changes made.',
                icon: Icons.preview,
                color: Colors.blue,
                onTap: () async {
                  _showLoadingDialog(context, 'Analyzing staff records...');

                  try {
                    await StaffNameToIdMapper.previewMapping();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Preview complete! Check console/logs for details'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error previewing: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Map District/Region Names to IDs',
                description:
                    'Convert staff district/region names (like "INANAM") to correct UUIDs. This fixes the display issue!',
                icon: Icons.transform,
                color: Colors.green,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Mapping'),
                      content: const Text(
                          'This will update staff records by converting district/region names to correct Firestore IDs.\n\n'
                          'Run "Preview Name-to-ID Mapping" first to see what will change.\n\n'
                          'Do you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.green),
                          child: const Text('YES, MAP TO IDs'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    _showLoadingDialog(context, 'Mapping names to IDs...');

                    try {
                      final results =
                          await StaffNameToIdMapper.mapNamesToIds();

                      if (context.mounted) {
                        Navigator.pop(context); // Close loading

                        final updated = results['staff_updated'] as int;
                        final skipped = results['staff_skipped'] as int;
                        final errors = (results['errors'] as List).length;

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Mapping Complete'),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Total Staff: ${results['total_staff']}'),
                                Text('Updated: $updated',
                                    style:
                                        const TextStyle(color: Colors.green)),
                                Text('Skipped: $skipped'),
                                if (errors > 0)
                                  Text('Errors: $errors',
                                      style:
                                          const TextStyle(color: Colors.red)),
                                const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text(
                                    'Staff records now have correct region/district IDs!',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
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
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error mapping: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Fix Staff Name Mismatches',
                description:
                    'Correct staff names in Firestore to match churches_SAB.json (e.g., "Jeremiah Sam" → "Jeremiah Sam John").',
                icon: Icons.edit,
                color: Colors.teal,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Fix Staff Names'),
                      content: const Text(
                          'This will rename 4 staff members to match the names in churches_SAB.json:\n\n'
                          '• Jeremiah Sam → Jeremiah Sam John\n'
                          '• Clario Taipin Gadoit → Cleario Taipin\n'
                          '• Erick Roy Paul → Erick RoyPaul\n'
                          '• Micheal Chin Hon Kee → Micheal Chin\n\n'
                          'After fixing, re-run "Import Staff Assignments" to assign their districts.\n\n'
                          'Do you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.teal),
                          child: const Text('YES, FIX NAMES'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    _showLoadingDialog(context, 'Fixing staff names...');

                    try {
                      final results =
                          await StaffNameFixer.applyNameCorrections();

                      if (context.mounted) {
                        Navigator.pop(context); // Close loading

                        final applied = results['applied'] as int;
                        final notFound =
                            (results['not_found'] as List).length;
                        final errors = (results['errors'] as List).length;

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Name Corrections Complete'),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    'Total Corrections: ${results['total_corrections']}'),
                                const Divider(),
                                Text('Applied: $applied',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold)),
                                if (notFound > 0)
                                  Text('Not Found: $notFound',
                                      style:
                                          const TextStyle(color: Colors.orange)),
                                if (errors > 0)
                                  Text('Errors: $errors',
                                      style:
                                          const TextStyle(color: Colors.red)),
                                const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text(
                                    'Now re-run "Import Staff Assignments" to assign districts to the renamed staff.',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
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
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error fixing names: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Preview Staff Assignments Import',
                description:
                    'Preview pastor assignments from churches_SAB.json before importing.',
                icon: Icons.visibility,
                color: Colors.lightBlue,
                onTap: () async {
                  _showLoadingDialog(context, 'Loading preview...');

                  try {
                    await StaffAssignmentImporter.previewImport();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Preview complete! Check console for pastor assignments.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error previewing: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Import Staff Assignments (Sabah)',
                description:
                    'Import pastor district/region assignments from churches_SAB.json. This will update staff records.',
                icon: Icons.download,
                color: Colors.deepPurple,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Import'),
                      content: const Text(
                          'This will import pastor assignments from churches_SAB.json and update staff records with their district and region.\n\n'
                          'The import will:\n'
                          '• Match pastors by name\n'
                          '• Update region and district IDs\n'
                          '• Only affect Sabah Mission staff\n\n'
                          'Run "Preview Staff Assignments Import" first to see what will be imported.\n\n'
                          'Do you want to continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.deepPurple),
                          child: const Text('YES, IMPORT'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    _showLoadingDialog(context, 'Importing assignments...');

                    try {
                      final results =
                          await StaffAssignmentImporter.importFromChurchesJSON();

                      if (context.mounted) {
                        Navigator.pop(context); // Close loading

                        final matched = results['matched_staff'] as int;
                        final updated = results['updated_staff'] as int;
                        final unmatched =
                            (results['unmatched_staff'] as List).length;
                        final errors = (results['errors'] as List).length;

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Import Complete'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      'Total Pastors in JSON: ${results['total_pastors_in_json']}'),
                                  const Divider(),
                                  Text('Matched Staff: $matched',
                                      style:
                                          const TextStyle(color: Colors.green)),
                                  Text('Updated Staff: $updated',
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold)),
                                  if (unmatched > 0)
                                    Text('Unmatched Staff: $unmatched',
                                        style: const TextStyle(
                                            color: Colors.orange)),
                                  if (errors > 0)
                                    Text('Errors: $errors',
                                        style:
                                            const TextStyle(color: Colors.red)),
                                  if (unmatched > 0 || errors > 0)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 16),
                                      child: Text(
                                        'Check console for detailed list of unmatched staff and errors.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              ),
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
                        Navigator.pop(context); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error importing: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Check Unmatched Staff Details',
                description:
                    'Show details of the 17 unmatched staff from the last import to understand why they weren\'t matched.',
                icon: Icons.person_search,
                color: Colors.brown,
                onTap: () async {
                  _showLoadingDialog(context, 'Checking unmatched staff...');

                  final unmatchedStaff = [
                    'Alexander Maxon Horis',
                    'Lovell Juil',
                    'A Harnnie Severinus',
                    'Timothy Chin Wei Jun',
                    'Ariman Paulus',
                    'Justin Wong Chong Yung',
                    'Jeremiah Sam',
                    'Clario Taipin Gadoit',
                    'Melrindro Rojiin Lukas',
                    'Soliun Sandayan',
                    'Ronald Longgou',
                    'Francis Lajanim',
                    'Adriel Charles Jr',
                    'Junniel Mac Daniel Gara',
                    'Erick Roy Paul',
                    'Micheal Chin Hon Kee',
                    'Richard Ban Solynsem',
                  ];

                  try {
                    await UnmatchedStaffChecker.checkUnmatchedStaff(
                        unmatchedStaff);

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Staff details displayed in console. Check their roles to see if they need district assignments.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error checking staff: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 32),
              const _SectionHeader(title: 'Staff Data Diagnostics'),
              _ActionCard(
                title: 'Show Sample Staff Records',
                description:
                    'Display the first 10 staff records with all their fields to understand the data structure.',
                icon: Icons.preview,
                color: Colors.indigo,
                onTap: () async {
                  _showLoadingDialog(context, 'Loading sample records...');

                  try {
                    await StaffDataDiagnostics.showSampleStaffRecords(
                        sampleSize: 10);

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Sample records displayed in console. Check logs for details.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error showing samples: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Analyze Staff by Mission',
                description:
                    'Count staff by mission and show how many have region/district assignments.',
                icon: Icons.bar_chart,
                color: Colors.deepOrange,
                onTap: () async {
                  _showLoadingDialog(context, 'Analyzing staff by mission...');

                  try {
                    await StaffDataDiagnostics.analyzeStaffByMission();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Analysis complete! Check console for detailed breakdown by mission.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error analyzing: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              _ActionCard(
                title: 'Get Data Source Suggestions',
                description:
                    'Show suggestions for how to populate missing staff district/region data.',
                icon: Icons.lightbulb_outline,
                color: Colors.amber,
                onTap: () async {
                  await StaffDataDiagnostics.suggestDataSources();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Suggestions displayed in console.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
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