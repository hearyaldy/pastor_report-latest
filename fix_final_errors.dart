import 'dart:io';

void main() {
  int totalFixes = 0;

  // Fix typo: surfaceContainerHighest0 -> surfaceContainerHighest
  final districtFile = File('lib/screens/district_management_screen.dart');
  if (districtFile.existsSync()) {
    String content = districtFile.readAsStringSync();
    content = content.replaceAll(
        '.surfaceContainerHighest0', '.surfaceContainerHighest');
    districtFile.writeAsStringSync(content);
    print('✓ Fixed district_management_screen.dart typos');
  }

  // Fix remaining const errors
  final filesToFix = [
    'lib/screens/admin/church_management_screen.dart',
    'lib/screens/admin/financial_reports_screen.dart',
    'lib/screens/admin/resource_management_screen.dart',
    'lib/screens/dashboard_screen_improved.dart',
    'lib/screens/district_management_screen.dart',
    'lib/screens/financial_report_edit_screen.dart',
    'lib/screens/profile_screen.dart',
  ];

  for (var filePath in filesToFix) {
    final file = File(filePath);
    if (!file.existsSync()) continue;

    String content = file.readAsStringSync();
    int fileFixes = 0;

    // Remove const from Expanded widgets with Theme.of(context)
    if (content.contains('const Expanded(') &&
        content.contains('Theme.of(context)')) {
      final lines = content.split('\n');
      final newLines = <String>[];

      for (int i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.contains('const Expanded(')) {
          // Check next 20 lines for Theme.of(context)
          bool hasThemeContext = false;
          for (int j = i; j < i + 20 && j < lines.length; j++) {
            if (lines[j].contains('Theme.of(context)')) {
              hasThemeContext = true;
              break;
            }
            if (lines[j].contains(')') && !lines[j].contains('(')) {
              break; // End of Expanded widget
            }
          }
          if (hasThemeContext) {
            line = line.replaceFirst('const Expanded(', 'Expanded(');
            fileFixes++;
          }
        }
        newLines.add(line);
      }
      content = newLines.join('\n');
    }

    // Remove const from Column/Row with Theme.of(context) children
    content = content.replaceAllMapped(
      RegExp(
          r'const (Column|Row)\([^)]*children:\s*\[[^\]]*Theme\.of\(context\)',
          multiLine: true,
          dotAll: true),
      (match) {
        fileFixes++;
        return match.group(0)!.replaceFirst('const ', '');
      },
    );

    if (fileFixes > 0) {
      file.writeAsStringSync(content);
      print('✓ Fixed ${filePath.split('/').last}: $fileFixes fixes');
      totalFixes += fileFixes;
    }
  }

  print('\n✅ Total fixes: $totalFixes');
}

void _fixFile(String path, List<List<RegExp>> patterns) {
  final file = File(path);
  if (!file.existsSync()) {
    print('⚠ File not found: $path');
    return;
  }

  String content = file.readAsStringSync();
  int fixes = 0;

  for (var pattern in patterns) {
    final regex = pattern[0];
    final replacement = pattern[1] as String;
    final matches = regex.allMatches(content).length;
    if (matches > 0) {
      content = content.replaceAll(regex, replacement);
      fixes += matches;
    }
  }

  if (fixes > 0) {
    file.writeAsStringSync(content);
    print('✓ Fixed ${path.split('/').last}: $fixes typos');
  }
}
