#!/bin/bash
set -e

APP_NAME="Luzia Universal Typo Correcter.app"
INSTALL_PATH="/Applications/$APP_NAME"
BACKUP_DIR="$HOME/Desktop/Luzia Backups"

echo "🔄 Restore Luzia from Backup"
echo ""

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ No backups found"
    echo "   Looking for: $BACKUP_DIR"
    exit 1
fi

# List available backups
BACKUPS=($(ls -1t "$BACKUP_DIR" | grep ".app"))
BACKUP_COUNT=${#BACKUPS[@]}

if [ "$BACKUP_COUNT" -eq 0 ]; then
    echo "❌ No backup versions found in:"
    echo "   $BACKUP_DIR"
    exit 1
fi

echo "📦 Available backups:"
echo ""

for i in "${!BACKUPS[@]}"; do
    BACKUP="${BACKUPS[$i]}"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP"
    TIMESTAMP=$(echo "$BACKUP" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    DATE_FORMATTED=$(echo "$TIMESTAMP" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')

    echo "   [$((i+1))] $DATE_FORMATTED"
done

echo ""
echo -n "Which backup to restore? (1-$BACKUP_COUNT, or 0 to cancel): "
read CHOICE

if [ "$CHOICE" -eq 0 ] 2>/dev/null; then
    echo "❌ Cancelled"
    exit 0
fi

if [ "$CHOICE" -lt 1 ] 2>/dev/null || [ "$CHOICE" -gt "$BACKUP_COUNT" ] 2>/dev/null; then
    echo "❌ Invalid choice"
    exit 1
fi

SELECTED_BACKUP="${BACKUPS[$((CHOICE-1))]}"
BACKUP_PATH="$BACKUP_DIR/$SELECTED_BACKUP"

echo ""
echo "📦 Restoring: $SELECTED_BACKUP"
echo ""

# Kill running instance
echo "🛑 Stopping running app..."
killall "Luzia Universal Typo Correcter" 2>/dev/null && echo "   ✓ Stopped" || echo "   (Not running)"
sleep 1

# Remove current version
if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
    echo "   ✓ Removed current version"
fi

# Copy backup to /Applications
echo ""
echo "📦 Restoring backup..."
cp -R "$BACKUP_PATH" "$INSTALL_PATH"
echo "   ✓ Restored to /Applications/"

# Launch
echo ""
echo "🚀 Launching app..."
open "$INSTALL_PATH"

echo ""
echo "✅ Done! Backup restored successfully."
echo ""
echo "💡 If this version has issues, run this script again to try another backup."
echo ""
