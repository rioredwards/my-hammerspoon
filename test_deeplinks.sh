#!/bin/bash

# Test script for Hammerspoon deep links.
# Deep links are auto-registered from config/hotkeys.hammerspoon.jsonc:
# each hotkey action name becomes hammerspoon://<lowercase-action-name>.
# Make sure Hammerspoon is running and reloaded before testing.

echo "🧪 Testing Hammerspoon Deep Links"
echo "=================================="
echo ""

# Action names must match the third field of each entry in
# config/hotkeys.hammerspoon.jsonc.
commands=(
    "maximizeWindow"
    "leftHalfWindow"
    "rightHalfWindow"
    "topHalfWindow"
    "bottomHalfWindow"
    "almostMaximizeWindow"
    "restoreWindow"
    "maximizeWindow"
)

# Function to test a single command
test_command() {
    local cmd=$1
    local url_cmd
    url_cmd=$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]')
    echo "Testing: hammerspoon://$url_cmd"
    open "hammerspoon://$url_cmd"
    sleep 1
}

# Test each command
for cmd in "${commands[@]}"; do
    test_command "$cmd"
done

echo ""
echo "✅ All deep link tests completed!"
echo ""
echo "Available deep links (one per hotkey action):"
echo "  hammerspoon://maximizewindow         - Maximize window"
echo "  hammerspoon://almostmaximizewindow   - Almost maximize"
echo "  hammerspoon://lefthalfwindow         - Left half"
echo "  hammerspoon://righthalfwindow        - Right half"
echo "  hammerspoon://tophalfwindow          - Top half"
echo "  hammerspoon://bottomhalfwindow       - Bottom half"
echo "  hammerspoon://restorewindow          - Restore window"
echo "  hammerspoon://nextdesktop            - Next desktop"
echo "  hammerspoon://previousdesktop        - Previous desktop"
echo "  hammerspoon://screenshotcapturetext  - OCR screenshot"
echo "  hammerspoon://screenshotcapturearea  - Area screenshot"
echo "  hammerspoon://formatclipboard        - Format clipboard"
echo ""
echo "Note: any action listed in config/hotkeys.hammerspoon.jsonc is"
echo "available as hammerspoon://<lowercase-action-name> automatically."
