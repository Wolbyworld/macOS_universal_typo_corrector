#!/bin/bash

set -e

# Configuration
APP_NAME="Luzia Universal Typo Correcter"
DMG_NAME="${1:-Luzia-Enterprise}"  # Allow custom name as argument
APP_PATH="./build/Build/Products/Release/${APP_NAME}.app"
VOL_NAME="Luzia"
BACKGROUND_DIR="./dmg-resources"
BACKGROUND_FILE="dmg-background.png"

# DMG window dimensions (must match background image)
WINDOW_WIDTH=660
WINDOW_HEIGHT=400

# Icon positions (centered vertically at ~180px from top)
APP_ICON_X=140
APP_ICON_Y=190
APPS_ICON_X=520
APPS_ICON_Y=190
ICON_SIZE=100

echo "======================================"
echo "  DMG Creator for Luzia"
echo "======================================"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Run the build first (e.g., ./build-enterprise.sh or xcodebuild)"
    exit 1
fi

# Check if background exists, generate if not
if [ ! -f "$BACKGROUND_DIR/$BACKGROUND_FILE" ]; then
    echo "Generating DMG background..."
    if [ -f "$BACKGROUND_DIR/generate-background.swift" ]; then
        swift "$BACKGROUND_DIR/generate-background.swift"
    else
        echo "Warning: No background generator found. DMG will use default appearance."
    fi
fi

# Remove existing DMG if present
rm -f "${DMG_NAME}.dmg"
rm -f "${DMG_NAME}-temp.dmg"

echo "Creating DMG contents..."

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf '$TMP_DIR'" EXIT

# Copy app
cp -R "$APP_PATH" "$TMP_DIR/"

# Create Applications symlink
ln -s /Applications "$TMP_DIR/Applications"

# Create hidden directory for background
mkdir -p "$TMP_DIR/.background"
if [ -f "$BACKGROUND_DIR/$BACKGROUND_FILE" ]; then
    cp "$BACKGROUND_DIR/$BACKGROUND_FILE" "$TMP_DIR/.background/"
    # Copy @2x version if exists
    if [ -f "$BACKGROUND_DIR/dmg-background@2x.png" ]; then
        cp "$BACKGROUND_DIR/dmg-background@2x.png" "$TMP_DIR/.background/"
    fi
fi

echo "Creating temporary DMG..."

# Create a temporary read-write DMG
hdiutil create -srcfolder "$TMP_DIR" \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 200m \
    "${DMG_NAME}-temp.dmg"

echo "Mounting DMG for customization..."

# Mount the DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_NAME}-temp.dmg" | grep -E '^/dev/' | head -1 | awk '{print $1}')
MOUNT_DIR="/Volumes/$VOL_NAME"

if [ -z "$DEVICE" ] || [ ! -d "$MOUNT_DIR" ]; then
    echo "Error: Failed to mount DMG"
    exit 1
fi

echo "Mounted at: $MOUNT_DIR (device: $DEVICE)"

# Wait for Finder to recognize the volume
sleep 2

echo "Customizing DMG appearance..."

# Use AppleScript to customize the DMG window
osascript << EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        delay 1

        -- Set view options
        set current view of container window to icon view
        set theViewOptions to icon view options of container window

        -- Configure icon view
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to $ICON_SIZE

        -- Set background if it exists
        try
            set background picture of theViewOptions to file ".background:$BACKGROUND_FILE"
        end try

        -- Set window size and position
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, $((200 + WINDOW_WIDTH)), $((200 + WINDOW_HEIGHT))}

        -- Position the icons
        set position of item "${APP_NAME}.app" of container window to {$APP_ICON_X, $APP_ICON_Y}
        set position of item "Applications" of container window to {$APPS_ICON_X, $APPS_ICON_Y}

        -- Update and close
        close
        open
        delay 1
        close

    end tell
end tell
EOF

# Sync to ensure changes are written
sync

echo "Finalizing DMG..."

# Unmount the DMG
hdiutil detach "$DEVICE" -quiet

# Convert to compressed, read-only DMG
hdiutil convert "${DMG_NAME}-temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_NAME}.dmg"

# Clean up temporary DMG
rm -f "${DMG_NAME}-temp.dmg"

# Get final info
DMG_SIZE=$(du -h "${DMG_NAME}.dmg" | cut -f1)

echo ""
echo "======================================"
echo "  DMG Created Successfully!"
echo "======================================"
echo ""
echo "File: ${DMG_NAME}.dmg"
echo "Size: ${DMG_SIZE}"
echo "Path: $(pwd)/${DMG_NAME}.dmg"
echo ""
echo "To distribute:"
echo "  1. Upload ${DMG_NAME}.dmg to your distribution channel"
echo "  2. Users open the DMG and drag the app to Applications"
echo "  3. First launch: Right-click > Open (to bypass Gatekeeper)"
echo ""
