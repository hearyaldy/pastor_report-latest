import 'dart:io';

void main() {
  final files = Directory('lib/screens')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('.bak'))
      .toList();

  int totalFixes = 0;
  int filesFixed = 0;

  for (var file in files) {
    String content = file.readAsStringSync();
    String originalContent = content;
    int fileFixes = 0;

    // Fix const decorations with Theme.of(context)
    // Pattern: const BoxDecoration( ... color: Theme.of(context)...
    final constDecorationPattern = RegExp(
      r'const\s+(BoxDecoration|InputDecoration|TextStyle|EdgeInsets\.all|EdgeInsets\.symmetric|BoxConstraints)\s*\([^)]*Theme\.of\(context\)[^)]*\)',
      multiLine: true,
      dotAll: true,
    );

    content = content.replaceAllMapped(constDecorationPattern, (match) {
      fileFixes++;
      // Remove 'const' keyword
      return match.group(0)!.replaceFirst(RegExp(r'const\s+'), '');
    });

    // More specific pattern for BoxDecoration with Theme.of(context).cardColor
    content = content.replaceAllMapped(
      RegExp(r'const\s+BoxDecoration\(\s*color:\s*Theme\.of\(context\)'),
      (match) {
        fileFixes++;
        return 'BoxDecoration(\n          color: Theme.of(context)';
      },
    );

    // Fix const Text with Theme colors
    content = content.replaceAllMapped(
      RegExp(r'const\s+Text\([^)]+color:\s*Theme\.of\(context\)[^)]*\)', multiLine: true, dotAll: true),
      (match) {
        fileFixes++;
        return match.group(0)!.replaceFirst('const ', '');
      },
    );

    // Fix const Icon with Theme colors
    content = content.replaceAllMapped(
      RegExp(r'const\s+Icon\([^)]+color:\s*Theme\.of\(context\)[^)]*\)', multiLine: true, dotAll: true),
      (match) {
        fileFixes++;
        return match.group(0)!.replaceFirst('const ', '');
      },
    );

    if (fileFixes > 0) {
      file.writeAsStringSync(content);
      filesFixed++;
      totalFixes += fileFixes;
      print('✓ Fixed ${file.path.split('/').last}: $fileFixes const errors');
    }
  }

  print('\n========================================');
  print('✅ CONST ERROR FIX COMPLETE');
  print('========================================');
  print('Files fixed: $filesFixed');
  print('Total fixes: $totalFixes');
  print('========================================');
}
