#!/bin/bash

echo "🔍 Checking development setup for Luzia..."
echo ""

# Check for Xcode
echo "1. Checking Xcode installation..."
if xcode-select -p &>/dev/null; then
    XCODE_PATH=$(xcode-select -p)
    if [[ "$XCODE_PATH" == *"CommandLineTools"* ]]; then
        echo "   ⚠️  Only Command Line Tools installed"
        echo "   ❌ Full Xcode required for xcodebuild"
        echo ""
        echo "   To fix:"
        echo "   1. Install Xcode from App Store"
        echo "   2. Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
        echo "   3. Run: sudo xcodebuild -license accept"
        XCODE_OK=false
    else
        echo "   ✅ Xcode installed at: $XCODE_PATH"
        XCODE_OK=true

        # Check xcodebuild
        if command -v xcodebuild &>/dev/null; then
            XCODE_VERSION=$(xcodebuild -version | head -n1)
            echo "   ✅ $XCODE_VERSION"
        fi
    fi
else
    echo "   ❌ Xcode not found"
    echo "   Install from: https://apps.apple.com/app/xcode/id497799835"
    XCODE_OK=false
fi

echo ""
echo "2. Checking app installation..."
if [ -d "/Applications/Luzia Universal Typo Correcter.app" ]; then
    echo "   ✅ App installed in /Applications"

    # Check code signature
    SIGNATURE=$(codesign -dv "/Applications/Luzia Universal Typo Correcter.app" 2>&1 | grep "Signature=" | cut -d= -f2)
    echo "   📝 Signature: $SIGNATURE"
else
    echo "   ℹ️  App not yet installed (will be created on first deploy)"
fi

echo ""
echo "3. Checking Accessibility permissions..."
# Try to check if accessibility is granted (this is approximate)
if ps aux | grep -i "Luzia" | grep -v grep &>/dev/null; then
    echo "   ✅ App is currently running"
else
    echo "   ℹ️  App not currently running"
fi
echo "   💡 Accessibility permission must be granted manually:"
echo "      System Settings > Privacy & Security > Accessibility"

echo ""
echo "4. Checking log directories..."
LOG_DIR="$HOME/Library/Application Support/Luzia/Evals"
if [ -d "$LOG_DIR" ]; then
    echo "   ✅ Log directory exists: $LOG_DIR"

    if [ -f "$LOG_DIR/evals_log.tsv" ]; then
        LOG_COUNT=$(wc -l < "$LOG_DIR/evals_log.tsv")
        echo "   📊 Eval log entries: $LOG_COUNT"
    fi

    if [ -f "$LOG_DIR/evals_errors.tsv" ]; then
        ERROR_COUNT=$(wc -l < "$LOG_DIR/evals_errors.tsv")
        echo "   📊 Error log entries: $ERROR_COUNT"
    fi
else
    echo "   ℹ️  Log directory not yet created (will be created on first run)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$XCODE_OK" = true ]; then
    echo "✅ Ready to deploy!"
    echo ""
    echo "Run: ./quick-deploy.sh"
else
    echo "⚠️  Setup incomplete - install full Xcode first"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
