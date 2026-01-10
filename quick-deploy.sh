#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

PROJECT_NAME="Luzia Universal Typo Correcter"
APP_NAME="Luzia Universal Typo Correcter.app"

echo "🔨 Building $PROJECT_NAME..."
echo "   Configuration: Release"
echo ""

# Build the app (adhoc signing - permissions need reset on first run after build)
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$PROJECT_NAME" \
           -configuration Release \
           -derivedDataPath build \
           build \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO

echo ""
echo "✅ Build complete!"
echo ""

# Path to built app
BUILT_APP="build/Build/Products/Release/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Error: Built app not found at $BUILT_APP"
    exit 1
fi

echo "📦 Installing to /Applications..."

# Kill if running
killall "$PROJECT_NAME" 2>/dev/null && echo "   Stopped running instance" || true
sleep 1

# Remove old version and copy new one (force recursive remove)
if [ -d "/Applications/$APP_NAME" ]; then
    rm -rf "/Applications/$APP_NAME"
    echo "   Removed old version"
fi

cp -R "$BUILT_APP" "/Applications/"
echo "   Copied to /Applications/"

echo ""
echo "🚀 Launching app..."
open "/Applications/$APP_NAME"

echo ""
echo "✅ Done! App is running in menu bar."
echo ""
echo "⚠️  IMPORTANT - Accessibility Permissions:"
echo "   After rebuilding, you need to reset permissions:"
echo "   1. Open: System Settings > Privacy & Security > Accessibility"
echo "   2. Remove 'Luzia Universal Typo Correcter' from the list"
echo "   3. Try the shortcut (Shift+Cmd+G) to trigger permission prompt"
echo "   4. Re-grant permission"
echo ""
echo "💡 Tips:"
echo "   - Check menu bar for Luzia icon"
echo "   - View logs: tail -f ~/Library/Application\ Support/Luzia/Evals/*.tsv"
echo ""
