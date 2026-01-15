#!/bin/bash

set -e

# Configuration
APP_NAME="Luzia Universal Typo Correcter"
DMG_NAME="Luzia-Enterprise"
APP_PATH="./build/Build/Products/Release/${APP_NAME}.app"
VOL_NAME="Luzia"

echo "📦 Creating distribution DMG..."

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App not found at $APP_PATH"
    echo "   Run ./build-enterprise.sh first"
    exit 1
fi

# Create temporary directory for DMG contents
TMP_DIR=$(mktemp -d)
echo "   Using temp dir: $TMP_DIR"

# Copy app to temp directory
cp -R "$APP_PATH" "$TMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TMP_DIR/Applications"

# Create the DMG
echo "   Creating DMG..."
hdiutil create -volname "$VOL_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "$DMG_NAME.dmg"

# Clean up
rm -rf "$TMP_DIR"

echo ""
echo "✅ DMG created: $DMG_NAME.dmg"
echo ""
echo "📍 Location: $(pwd)/$DMG_NAME.dmg"
echo "📊 Size: $(du -h "$DMG_NAME.dmg" | cut -f1)"
echo ""
echo "🚀 To distribute:"
echo "   1. Upload $DMG_NAME.dmg to shared drive or Slack"
echo "   2. Employees open DMG and drag app to Applications folder"
echo "   3. Right-click app → Open (first launch only)"
echo ""
