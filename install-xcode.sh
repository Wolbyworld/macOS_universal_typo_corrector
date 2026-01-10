#!/bin/bash
set -e

echo "📦 Installing Xcode from command line..."
echo ""

# Check if mas is installed
if ! command -v mas &>/dev/null; then
    echo "1️⃣  Installing 'mas' (Mac App Store CLI)..."
    brew install mas
    echo "   ✅ mas installed"
    echo ""
fi

# Check if already signed in to App Store by trying to search
echo "2️⃣  Checking App Store sign-in status..."
if ! mas search Xcode &>/dev/null; then
    echo "   ⚠️  You need to be signed in to the App Store"
    echo "   Please sign in manually:"
    echo "   - Open App Store app"
    echo "   - Sign in with your Apple ID"
    echo "   - Then run this script again"
    echo ""
    open -a "App Store"
    exit 1
fi

echo "   ✅ Signed in to App Store"
echo ""

# Check if Xcode is already installed
if [ -d "/Applications/Xcode.app" ]; then
    echo "⚠️  Xcode.app already exists in /Applications"
    echo ""
    read -p "   Reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Skipping installation, configuring existing Xcode..."

        # Configure it
        sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
        sudo xcodebuild -license accept 2>/dev/null || {
            echo "   ℹ️  Please accept the license agreement:"
            sudo xcodebuild -license
        }

        echo ""
        echo "✅ Xcode configured!"
        xcodebuild -version
        exit 0
    fi
fi

# Install Xcode from App Store
# Xcode App Store ID: 497799835
echo "3️⃣  Installing Xcode from App Store..."
echo "   ⚠️  This is a LARGE download (~10-15 GB) and will take time"
echo "   You can monitor progress in Activity Monitor or App Store app"
echo ""

mas install 497799835

echo ""
echo "4️⃣  Configuring Xcode..."

# Switch to Xcode
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Accept license
echo "   Accepting license agreement..."
sudo xcodebuild -license accept 2>/dev/null || {
    echo "   ℹ️  Please accept the license agreement:"
    sudo xcodebuild -license
}

# Install additional components (may prompt)
echo "   Installing additional components..."
sudo xcodebuild -runFirstLaunch 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Xcode installed and configured!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
xcodebuild -version
echo ""
echo "🚀 You can now run: ./quick-deploy.sh"
echo ""
