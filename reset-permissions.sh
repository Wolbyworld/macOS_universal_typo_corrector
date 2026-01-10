#!/bin/bash

echo "🔓 Opening Accessibility Settings..."
echo ""
echo "Steps:"
echo "  1. Find 'Luzia Universal Typo Correcter' in the list"
echo "  2. Click the (-) button or toggle it off then on"
echo "  3. Close System Settings"
echo "  4. Try Shift+Cmd+G in any app"
echo ""

# Open Accessibility preferences
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
