import 'dart:io';

/// Fix const errors caused by Theme.of(context) in const expressions
void main() async {
  print('🔧 Fixing const expression errors...');

  final screensDir = Directory('lib/screens');
  final files = screensDir
      .listSync(recursive: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  int filesFixed = 0;
  int totalFixes = 0;

  for (final file in files) {
    var content = await file.readAsString();
    final originalContent = content;

    // Fix patterns where const is used with Theme.of(context)
    // Pattern 1: const Icon(..., color: Theme.of(context)...)
    content = content.replaceAll(
      RegExp(r'const Icon\(([^)]+),\s*color:\s*Theme\.of\(context\)'),
      'Icon(\$1, color: Theme.of(context)',
    );

    // Pattern 2: const Text(..., style: TextStyle(color: Theme.of(context)...))
    content = content.replaceAll(
      RegExp(r'const Text\(([^,]+),\s*style:\s*TextStyle\(color:\s*Theme\.of\(context\)'),
      'Text(\$1, style: TextStyle(color: Theme.of(context)',
    );

    // Pattern 3: const TextStyle(color: Theme.of(context)...)
    content = content.replaceAll(
      RegExp(r'const TextStyle\(([^)]*color:\s*Theme\.of\(context\)[^)]*)'),
      'TextStyle(\$1',
    );

    if (content != originalContent) {
      await file.writeAsString(content);
      filesFixed++;
      final fixes = '\n'.allMatches(originalContent).length - '\n'.allMatches(content).length;
      totalFixes += fixes.abs();
      print('✅ Fixed: ${file.uri.pathSegments.last}');
    }
  }

  print('\n✨ Done!');
  print('Files fixed: $filesFixed');
  print('Const keywords removed: ~$totalFixes');
}
