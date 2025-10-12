import 'dart:io';

void main() {
  final filesToFix = [
    'lib/screens/admin_dashboard_improved.dart',
    'lib/screens/mission_management_screen.dart',
    'lib/screens/ministerial_secretary_dashboard.dart',
    'lib/screens/district_management_screen.dart',
    'lib/screens/dashboard_screen_improved.dart',
    'lib/screens/activities_list_screen.dart',
    'lib/screens/profile_screen.dart',
    'lib/screens/financial_reports_list_screen.dart',
    'lib/screens/financial_report_edit_screen.dart',
    'lib/screens/events_screen.dart',
    'lib/screens/admin/financial_reports_screen.dart',
    'lib/screens/admin/resource_management_screen.dart',
    'lib/screens/admin/church_management_screen.dart',
    'lib/screens/treasurer/treasurer_dashboard.dart',
    'lib/screens/treasurer/financial_report_form.dart',
    'lib/screens/treasurer/fam_form.dart',
  ];

  int totalReplacements = 0;
  int filesModified = 0;

  // Backup directory
  final backupDir = Directory('lib/screens_backup_darkmode_${DateTime.now().millisecondsSinceEpoch}');
  backupDir.createSync(recursive: true);
  print('✓ Created backup directory: ${backupDir.path}');

  for (var filePath in filesToFix) {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('⚠ Skipping ${filePath} - file not found');
      continue;
    }

    // Backup original
    final backupPath = '${backupDir.path}/${filePath.split('/').last}';
    file.copySync(backupPath);

    String content = file.readAsStringSync();
    final originalContent = content;
    int fileReplacements = 0;

    // Common dark mode replacements
    final patterns = [
      // Scaffold backgrounds
      [RegExp(r'backgroundColor:\s*Colors\.grey\[50\]'), 'backgroundColor: Theme.of(context).scaffoldBackgroundColor'],
      [RegExp(r'backgroundColor:\s*Colors\.grey\[100\]'), 'backgroundColor: Theme.of(context).scaffoldBackgroundColor'],
      [RegExp(r'backgroundColor:\s*Colors\.white\s*,'), 'backgroundColor: Theme.of(context).scaffoldBackgroundColor,'],

      // Card/Container colors
      [RegExp(r'color:\s*Colors\.white\s*,'), 'color: Theme.of(context).cardColor,'],
      [RegExp(r'color:\s*Colors\.grey\[50\]\s*,'), 'color: Theme.of(context).cardColor,'],

      // Text colors
      [RegExp(r'color:\s*Colors\.grey\[800\]'), 'color: Theme.of(context).colorScheme.onSurface'],
      [RegExp(r'color:\s*Colors\.grey\[700\]'), 'color: Theme.of(context).textTheme.bodyMedium?.color'],
      [RegExp(r'color:\s*Colors\.grey\[600\]'), 'color: Theme.of(context).textTheme.bodySmall?.color'],
      [RegExp(r'color:\s*Colors\.grey\[500\]'), 'color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)'],
      [RegExp(r'color:\s*Colors\.grey\[400\]'), 'color: Theme.of(context).dividerColor'],
      [RegExp(r'color:\s*Colors\.black87'), 'color: Theme.of(context).colorScheme.onSurface'],
      [RegExp(r'color:\s*Colors\.black54'), 'color: Theme.of(context).textTheme.bodySmall?.color'],

      // Borders & Dividers
      [RegExp(r'color:\s*Colors\.grey\[300\]'), 'color: Theme.of(context).dividerColor'],
      [RegExp(r'color:\s*Colors\.grey\[200\]'), 'color: Theme.of(context).dividerColor'],
      [RegExp(r'Border\.all\(color:\s*Colors\.grey\[300\]!\)'), 'Border.all(color: Theme.of(context).dividerColor)'],
      [RegExp(r'Border\.all\(color:\s*Colors\.grey\[200\]!\)'), 'Border.all(color: Theme.of(context).dividerColor)'],
      [RegExp(r'BorderSide\(color:\s*Colors\.grey\[300\]!'), 'BorderSide(color: Theme.of(context).dividerColor'],
      [RegExp(r'BorderSide\(color:\s*Colors\.grey\[200\]!'), 'BorderSide(color: Theme.of(context).dividerColor'],

      // Shadows
      [RegExp(r'BoxShadow\(\s*color:\s*Colors\.black\.withOpacity'), 'BoxShadow(\n            color: Theme.of(context).shadowColor.withOpacity'],
      [RegExp(r'BoxShadow\(\s*color:\s*Colors\.grey\.withOpacity'), 'BoxShadow(\n            color: Theme.of(context).shadowColor.withOpacity'],

      // Specific hardcoded light colors
      [RegExp(r'Colors\.blue\.shade50'), 'Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)'],
      [RegExp(r'Colors\.blue\.shade100'), 'Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)'],
      [RegExp(r'Colors\.grey\.shade50'), 'Theme.of(context).colorScheme.surfaceContainerHighest'],
      [RegExp(r'Colors\.grey\.shade100'), 'Theme.of(context).colorScheme.surfaceContainerHighest'],
    ];

    for (var pattern in patterns) {
      final regex = pattern[0] as RegExp;
      final replacement = pattern[1] as String;
      final matches = regex.allMatches(content).length;
      if (matches > 0) {
        content = content.replaceAll(regex, replacement);
        fileReplacements += matches;
      }
    }

    if (fileReplacements > 0) {
      file.writeAsStringSync(content);
      filesModified++;
      totalReplacements += fileReplacements;
      print('✓ Fixed ${filePath.split('/').last}: $fileReplacements replacements');
    } else {
      print('- No changes needed for ${filePath.split('/').last}');
    }
  }

  print('\n========================================');
  print('✅ DARK MODE FIX COMPLETE');
  print('========================================');
  print('Files modified: $filesModified');
  print('Total replacements: $totalReplacements');
  print('Backup location: ${backupDir.path}');
  print('========================================');
}
