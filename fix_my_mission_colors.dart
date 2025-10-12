import 'dart:io';

void main() {
  final file = File('lib/screens/my_mission_screen.dart');
  String content = file.readAsStringSync();

  int replacements = 0;

  // Replace all remaining hardcoded colors
  final patterns = [
    // Grey text colors
    [RegExp(r'color: Colors\.grey\[700\]'), 'color: Theme.of(context).textTheme.bodyMedium?.color'],
    [RegExp(r'color: Colors\.grey\[600\]'), 'color: Theme.of(context).textTheme.bodySmall?.color'],
    [RegExp(r'color: Colors\.grey\[500\]'), 'color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)'],
    [RegExp(r'color: Colors\.grey\[400\]'), 'color: Theme.of(context).dividerColor'],

    // Grey backgrounds
    [RegExp(r'backgroundColor: Colors\.grey\[200\]'), 'backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest'],
    [RegExp(r'backgroundColor: Colors\.grey\.shade600'), 'backgroundColor: Theme.of(context).colorScheme.surface'],

    // Borders
    [RegExp(r'border: Border\.all\(color: Colors\.grey\[300\]!\)'), 'border: Border.all(color: Theme.of(context).dividerColor)'],
    [RegExp(r'Border\.all\(color: Colors\.grey\[300\]!\)'), 'Border.all(color: Theme.of(context).dividerColor)'],
    [RegExp(r'color: Colors\.grey\[300\]'), 'color: Theme.of(context).dividerColor'],
    [RegExp(r'BorderSide\(color: Colors\.grey\[200\]!'), 'BorderSide(color: Theme.of(context).dividerColor'],

    // Note: Keep white text on colored backgrounds (app bar, buttons, etc.)
    // But fix white container backgrounds
    [RegExp(r'color: Colors\.white,\s*borderRadius'), 'color: Theme.of(context).cardColor,\n        borderRadius'],
  ];

  for (var pattern in patterns) {
    final regex = pattern[0] as RegExp;
    final replacement = pattern[1] as String;
    final matches = regex.allMatches(content).length;
    if (matches > 0) {
      content = content.replaceAll(regex, replacement);
      replacements += matches;
      print('✓ Replaced ${matches}x: ${regex.pattern}');
    }
  }

  file.writeAsStringSync(content);
  print('\n✅ Total replacements: $replacements');
  print('✅ Fixed lib/screens/my_mission_screen.dart');
}
