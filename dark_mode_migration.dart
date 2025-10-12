import 'dart:io';

/// Automated Dark Mode Migration Tool
///
/// This script automatically fixes common dark mode issues across Flutter screens
/// by replacing hardcoded colors with theme-aware alternatives.

void main() async {
  print('🌓 Pastor Report - Dark Mode Migration Tool');
  print('=' * 60);

  final screensDir = Directory('lib/screens');
  if (!await screensDir.exists()) {
    print('❌ Error: lib/screens directory not found!');
    exit(1);
  }

  // Create backup
  final backupDir = Directory('lib/screens_backup_${DateTime.now().millisecondsSinceEpoch}');
  await backupDir.create();
  print('📦 Creating backup in: ${backupDir.path}');

  final files = screensDir
      .listSync(recursive: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('.bak'))
      .toList();

  print('📄 Found ${files.length} screen files to process\n');

  int filesModified = 0;
  int totalReplacements = 0;

  for (final file in files) {
    // Backup original
    await file.copy('${backupDir.path}/${file.uri.pathSegments.last}');

    final content = await file.readAsString();
    var newContent = content;
    int fileReplacements = 0;

    // Apply all transformations
    final replacements = _getReplacements();
    for (final replacement in replacements) {
      final matches = replacement.pattern.allMatches(newContent).length;
      if (matches > 0) {
        newContent = newContent.replaceAll(replacement.pattern, replacement.replacement);
        fileReplacements += matches;
        print('  ├─ ${replacement.description}: $matches');
      }
    }

    if (fileReplacements > 0) {
      await file.writeAsString(newContent);
      filesModified++;
      totalReplacements += fileReplacements;
      print('✅ ${file.uri.pathSegments.last}: $fileReplacements replacements\n');
    }
  }

  print('=' * 60);
  print('✨ Migration Complete!');
  print('📊 Summary:');
  print('   - Files processed: ${files.length}');
  print('   - Files modified: $filesModified');
  print('   - Total replacements: $totalReplacements');
  print('   - Backup location: ${backupDir.path}');
  print('\n⚠️  Next steps:');
  print('   1. Run: flutter analyze');
  print('   2. Test app in both light and dark modes');
  print('   3. Check DARK_MODE_FIX_GUIDE.md for manual fixes');
}

class Replacement {
  final RegExp pattern;
  final String replacement;
  final String description;

  Replacement(this.pattern, this.replacement, this.description);
}

List<Replacement> _getReplacements() {
  return [
    // Scaffold backgrounds
    Replacement(
      RegExp(r'backgroundColor:\s*Colors\.grey\[50\]'),
      'backgroundColor: Theme.of(context).scaffoldBackgroundColor',
      'Scaffold background (grey[50])',
    ),
    Replacement(
      RegExp(r'backgroundColor:\s*Colors\.grey\[100\]'),
      'backgroundColor: Theme.of(context).scaffoldBackgroundColor',
      'Scaffold background (grey[100])',
    ),
    Replacement(
      RegExp(r'backgroundColor:\s*Colors\.white(?![a-zA-Z0-9])'),
      'backgroundColor: Theme.of(context).scaffoldBackgroundColor',
      'Scaffold background (white)',
    ),

    // Container/Card colors
    Replacement(
      RegExp(r'color:\s*Colors\.white(?![a-zA-Z0-9])'),
      'color: Theme.of(context).cardColor',
      'Container color (white)',
    ),

    // Text colors - primary
    Replacement(
      RegExp(r'color:\s*Colors\.grey\[800\]'),
      'color: Theme.of(context).colorScheme.onSurface',
      'Text color (grey[800])',
    ),
    Replacement(
      RegExp(r'color:\s*Colors\.black(?![a-zA-Z0-9])'),
      'color: Theme.of(context).colorScheme.onSurface',
      'Text color (black)',
    ),

    // Text colors - secondary
    Replacement(
      RegExp(r'color:\s*Colors\.grey\[600\]'),
      'color: Theme.of(context).textTheme.bodySmall?.color',
      'Secondary text (grey[600])',
    ),

    // Borders and dividers
    Replacement(
      RegExp(r'Border\.all\(color:\s*Colors\.grey\[200\]!\)'),
      'Border.all(color: Theme.of(context).dividerColor)',
      'Border (grey[200])',
    ),
    Replacement(
      RegExp(r'Border\.all\(color:\s*Colors\.grey\[300\]'),
      'Border.all(color: Theme.of(context).dividerColor',
      'Border (grey[300])',
    ),

    // Border sides
    Replacement(
      RegExp(r'BorderSide\(color:\s*Colors\.grey\[200\]'),
      'BorderSide(color: Theme.of(context).dividerColor',
      'BorderSide (grey[200])',
    ),
    Replacement(
      RegExp(r'BorderSide\(color:\s*Colors\.grey\[300\]'),
      'BorderSide(color: Theme.of(context).dividerColor',
      'BorderSide (grey[300])',
    ),

    // Hint text colors
    Replacement(
      RegExp(r'hintStyle:\s*TextStyle\(color:\s*Colors\.grey\[400\]\)'),
      'hintStyle: TextStyle(color: Theme.of(context).hintColor)',
      'Hint text color',
    ),
  ];
}
