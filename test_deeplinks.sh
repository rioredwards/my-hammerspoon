#!/bin/bash

# Test script for Hammerspoon deep link window management
# Make sure Hammerspoon is running and reloaded before testing

echo "🧪 Testing Hammerspoon Deep Link Window Management"
echo "=================================================="
echo ""

# Array of all deep link commands to test
commands=(
    "winMaximize"
    "winLeft"
    "winRight" 
    "winTop"
    "winBottom"
    "winTopLeft"
    "winTopRight"
    "winBottomLeft"
    "winBottomRight"
    "winMaximize"
)

# Function to test a single command
test_command() {
    local cmd=$1
    echo "Testing: hammerspoon://$cmd"
    open "hammerspoon://$cmd"
    sleep 1
}

# Test each command
for cmd in "${commands[@]}"; do
    test_command "$cmd"
done

echo ""
echo "✅ All deep link tests completed!"
echo ""
echo "Available commands:"
echo "  hammerspoon://winMaximize    - Maximize window"
echo "  hammerspoon://winLeft        - Left half"
echo "  hammerspoon://winRight       - Right half" 
echo "  hammerspoon://winTop         - Top half"
echo "  hammerspoon://winBottom      - Bottom half"
echo "  hammerspoon://winTopLeft     - Top-left quarter"
echo "  hammerspoon://winTopRight    - Top-right quarter"
echo "  hammerspoon://winBottomLeft  - Bottom-left quarter"
echo "  hammerspoon://winBottomRight - Bottom-right quarter"
echo "  hammerspoon://winMaximize    - Maximize window"
