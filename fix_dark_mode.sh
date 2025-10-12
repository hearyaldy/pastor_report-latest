#!/bin/bash

# Script to fix common dark mode issues in Flutter screens
# This replaces hardcoded colors with theme-aware alternatives

echo "Fixing dark mode issues across screens..."

# Backup directory
BACKUP_DIR="./lib/screens_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Create backup
echo "Creating backup in $BACKUP_DIR..."
cp -r lib/screens/* "$BACKUP_DIR/"

# Fix common patterns across all screen files
for file in lib/screens/*.dart; do
    echo "Processing: $file"

    # Skip backup files
    if [[ "$file" == *.bak* ]]; then
        continue
    fi

    # Fix backgroundColor: Colors.grey[50] or similar
    sed -i.tmp 's/backgroundColor: Colors\.grey\[50\]/backgroundColor: Theme.of(context).scaffoldBackgroundColor/g' "$file"
    sed -i.tmp 's/backgroundColor: Colors\.grey\[100\]/backgroundColor: Theme.of(context).scaffoldBackgroundColor/g' "$file"

    # Fix color: Colors.white in containers
    sed -i.tmp 's/color: Colors\.white$/color: Theme.of(context).cardColor/g' "$file"

    # Fix Colors.grey[...] text colors
    sed -i.tmp 's/color: Colors\.grey\[600\]/color: Theme.of(context).textTheme.bodySmall?.color/g' "$file"
    sed -i.tmp 's/color: Colors\.grey\[800\]/color: Theme.of(context).colorScheme.onSurface/g' "$file"

    # Remove temp files
    rm -f "${file}.tmp"
done

echo "✅ Dark mode fixes applied!"
echo "Backup saved in: $BACKUP_DIR"
echo ""
echo "⚠️  NOTE: Some manual fixes may still be needed for:"
echo "   - Complex Container decorations"
echo "   - Gradient backgrounds"
echo "   - Icon colors"
echo ""
echo "Run 'flutter analyze' to check for any issues."
