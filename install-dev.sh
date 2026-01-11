#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

APP_NAME="Luzia Universal Typo Correcter.app"
DEV_BUILD="build/Build/Products/Release/$APP_NAME"
INSTALL_PATH="/Applications/$APP_NAME"
BACKUP_DIR="$HOME/Desktop/Luzia Backups"

echo "🚀 Installing Dev Build to /Applications"
echo ""

# Check if dev build exists
if [ ! -d "$DEV_BUILD" ]; then
    echo "❌ Error: Dev build not found at:"
    echo "   $DEV_BUILD"
    echo ""
    echo "💡 Run ./quick-deploy.sh first to build the app"
    exit 1
fi

# Create backup directory if needed
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    echo "📁 Created backup directory: $BACKUP_DIR"
fi

# Backup existing version if it exists
if [ -d "$INSTALL_PATH" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_PATH="$BACKUP_DIR/$APP_NAME.$TIMESTAMP"

    echo "💾 Backing up current version..."
    cp -R "$INSTALL_PATH" "$BACKUP_PATH"
    echo "   ✓ Backed up to: $BACKUP_PATH"
    echo ""
fi

# Kill running instance
echo "🛑 Stopping running app..."
killall "Luzia Universal Typo Correcter" 2>/dev/null && echo "   ✓ Stopped" || echo "   (Not running)"
sleep 1

# Remove old version
if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
    echo "   ✓ Removed old version"
fi

# Copy new version
echo ""
echo "📦 Installing new version..."
cp -R "$DEV_BUILD" "/Applications/"
echo "   ✓ Installed to /Applications/"

# Launch
echo ""
echo "🚀 Launching app..."
open "$INSTALL_PATH"
sleep 2

echo ""
echo "✅ Done! App is running in menu bar."
echo ""
echo "📊 Version Info:"
echo "   Built: $(date -r "$DEV_BUILD" '+%Y-%m-%d %H:%M:%S')"
echo "   Size: $(du -sh "$DEV_BUILD" | cut -f1)"
echo ""

# Count backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR" | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo "💾 Backups: $BACKUP_COUNT versions saved in:"
    echo "   $BACKUP_DIR"
    echo ""
fi

echo "💡 Tips:"
echo "   • Test with: Select text + ⇧⌘G"
echo "   • View logs: tail -f ~/Library/Application\\ Support/Luzia/Evals/*.tsv"
echo "   • Preferences: Right-click menu bar icon"
echo ""
echo "⚠️  If permissions are needed:"
echo "   System Settings > Privacy & Security > Accessibility"
echo "   Remove and re-add Luzia to reset permissions"
echo ""
