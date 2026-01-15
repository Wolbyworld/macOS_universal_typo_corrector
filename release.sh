#!/bin/bash
set -e

# Luzia Universal Typo Correcter - Release Script
# Creates a signed release for OTA updates via Sparkle + GitHub Releases
#
# Usage: ./release.sh <version> "<release notes>"
# Example: ./release.sh 1.1.0 "Bug fixes and performance improvements"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

PROJECT_NAME="Luzia Universal Typo Correcter"
APP_NAME="Luzia Universal Typo Correcter.app"
SPARKLE_BIN="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin"
RELEASES_DIR="$PROJECT_DIR/releases"
APPCAST_FILE="$PROJECT_DIR/appcast.xml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: ./release.sh <version> [\"release notes\"]"
    echo "Example: ./release.sh 1.1.0 \"Bug fixes and improvements\""
    exit 1
fi

VERSION="$1"
RELEASE_NOTES="${2:-Release $VERSION}"

# Validate version format (semver)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo -e "${RED}Error: Invalid version format. Use semver (e.g., 1.0.0 or 1.1)${NC}"
    exit 1
fi

echo ""
echo "========================================"
echo "  Luzia Release Builder v1.0"
echo "========================================"
echo ""
echo "Version: $VERSION"
echo "Notes:   $RELEASE_NOTES"
echo ""

# Step 1: Update version in Info.plist
echo -e "${YELLOW}Step 1: Updating version in Info.plist...${NC}"
INFO_PLIST="$PROJECT_DIR/$PROJECT_NAME/Info.plist"

# Update CFBundleShortVersionString
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"

# Calculate build number (integer from version, e.g., 1.2.3 -> 123)
BUILD_NUMBER=$(echo "$VERSION" | tr -d '.')
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$INFO_PLIST"

echo -e "${GREEN}   Version: $VERSION (Build $BUILD_NUMBER)${NC}"

# Step 2: Build the app
echo ""
echo -e "${YELLOW}Step 2: Building release...${NC}"

xcodebuild -project "$PROJECT_NAME.xcodeproj" \
           -scheme "$PROJECT_NAME" \
           -configuration Release \
           -derivedDataPath build \
           build \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           2>&1 | grep -E "(Build|error:|warning:|\*\*)" || true

BUILT_APP="$PROJECT_DIR/build/Build/Products/Release/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo -e "${RED}Error: Build failed. App not found at $BUILT_APP${NC}"
    exit 1
fi

echo -e "${GREEN}   Build complete!${NC}"

# Step 2b: Inject Sparkle configuration
echo ""
echo -e "${YELLOW}Step 2b: Injecting Sparkle configuration...${NC}"

APP_PLIST="$BUILT_APP/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Add :SUFeedURL string 'https://raw.githubusercontent.com/Wolbyworld/macOS_universal_typo_corrector/main/appcast.xml'" "$APP_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :SUFeedURL 'https://raw.githubusercontent.com/Wolbyworld/macOS_universal_typo_corrector/main/appcast.xml'" "$APP_PLIST"

/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string '6GZWiKhcsOojOzy0S4PWEtOqVzmkD675xYRvAOq/7Kw='" "$APP_PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey '6GZWiKhcsOojOzy0S4PWEtOqVzmkD675xYRvAOq/7Kw='" "$APP_PLIST"

echo -e "${GREEN}   Sparkle keys injected!${NC}"

# Step 2c: Fix code signature (re-sign properly after plist changes)
echo ""
echo -e "${YELLOW}Step 2c: Re-signing app after plist modifications...${NC}"

# Sign frameworks first (inside-out signing)
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --sign - "$BUILT_APP/Contents/Frameworks/Sparkle.framework"
# Sign main app last
codesign --force --sign - "$BUILT_APP"

echo -e "${GREEN}   App re-signed!${NC}"

# Step 3: Create releases directory and zip archive
echo ""
echo -e "${YELLOW}Step 3: Creating release archive...${NC}"

mkdir -p "$RELEASES_DIR"
ZIP_NAME="Luzia-$VERSION.zip"
ZIP_PATH="$RELEASES_DIR/$ZIP_NAME"

# Remove existing zip if present
rm -f "$ZIP_PATH"

# Create zip archive (Sparkle expects .app inside zip)
# Use zip instead of ditto to exclude resource forks that cause signature issues
cd "$PROJECT_DIR/build/Build/Products/Release"
zip -r --symlinks "$ZIP_PATH" "$APP_NAME" -x "*.DS_Store" -x "*._*" -x "*.__*"
cd "$PROJECT_DIR"

ZIP_SIZE=$(stat -f%z "$ZIP_PATH")
echo -e "${GREEN}   Created: $ZIP_NAME ($ZIP_SIZE bytes)${NC}"

# Step 4: Sign the archive with EdDSA
echo ""
echo -e "${YELLOW}Step 4: Signing archive with EdDSA...${NC}"

SIGNATURE=$("$SPARKLE_BIN/sign_update" "$ZIP_PATH" 2>&1 | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)

if [ -z "$SIGNATURE" ]; then
    echo -e "${RED}Error: Failed to sign archive${NC}"
    echo "Make sure you have run: $SPARKLE_BIN/generate_keys"
    exit 1
fi

echo -e "${GREEN}   Signature: ${SIGNATURE:0:20}...${NC}"

# Step 5: Update appcast.xml
echo ""
echo -e "${YELLOW}Step 5: Updating appcast.xml...${NC}"

DOWNLOAD_URL="https://github.com/Wolbyworld/macOS_universal_typo_corrector/releases/download/v$VERSION/$ZIP_NAME"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

# Create new appcast entry
NEW_ITEM="        <item>
            <title>Version $VERSION</title>
            <description><![CDATA[$RELEASE_NOTES]]></description>
            <pubDate>$PUB_DATE</pubDate>
            <enclosure
                url=\"$DOWNLOAD_URL\"
                sparkle:version=\"$BUILD_NUMBER\"
                sparkle:shortVersionString=\"$VERSION\"
                sparkle:edSignature=\"$SIGNATURE\"
                length=\"$ZIP_SIZE\"
                type=\"application/octet-stream\"
            />
            <sparkle:minimumSystemVersion>11.0</sparkle:minimumSystemVersion>
        </item>"

# Check if appcast.xml exists and has items
if [ -f "$APPCAST_FILE" ] && grep -q "</channel>" "$APPCAST_FILE"; then
    # Insert new item before closing channel tag, after last item
    # Use awk to insert before </channel>
    awk -v new_item="$NEW_ITEM" '
        /<\/channel>/ { print new_item }
        { print }
    ' "$APPCAST_FILE" > "$APPCAST_FILE.tmp"
    mv "$APPCAST_FILE.tmp" "$APPCAST_FILE"
else
    # Create new appcast.xml
    cat > "$APPCAST_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Luzia Universal Typo Correcter</title>
        <link>https://github.com/Wolbyworld/macOS_universal_typo_corrector</link>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
$NEW_ITEM
    </channel>
</rss>
EOF
fi

echo -e "${GREEN}   Updated appcast.xml${NC}"

# Done!
echo ""
echo "========================================"
echo -e "${GREEN}  Release $VERSION Ready!${NC}"
echo "========================================"
echo ""
echo "Files created:"
echo "  - $ZIP_PATH"
echo "  - $APPCAST_FILE (updated)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Commit and push appcast.xml:"
echo "   git add appcast.xml"
echo "   git commit -m \"Release v$VERSION\""
echo "   git push"
echo ""
echo "2. Create GitHub Release at:"
echo "   https://github.com/Wolbyworld/macOS_universal_typo_corrector/releases/new"
echo ""
echo "   - Tag: v$VERSION"
echo "   - Title: Version $VERSION"
echo "   - Upload: $ZIP_PATH"
echo ""
echo "3. Users will receive update notification automatically!"
echo ""
