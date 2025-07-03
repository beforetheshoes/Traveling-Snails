#!/bin/bash

# Enhanced Build script for Traveling Snails
# Handles multiple iOS versions and simulator configurations

cd "$(dirname "$0")"

# Function to find available iPhone 16 simulator
find_simulator() {
    # Use the iPhone 16 with iOS 26.0 that we know exists
    echo >&2 "✓ Using iPhone 16 (iOS 26.0)"
    echo "platform=iOS Simulator,id=3A41C909-AAB6-443D-AF1C-2BCBC40047D8"
    return 0
}

# Function to check if xcbeautify is available
check_xcbeautify() {
    if ! command -v xcbeautify &> /dev/null; then
        echo "⚠️  xcbeautify not found. Install with: brew install xcbeautify"
        echo "   Falling back to raw xcodebuild output..."
        return 1
    fi
    return 0
}

# Main script execution
echo "🏗️  Traveling Snails Build Script"
echo "================================="

# Find simulator
DESTINATION=$(find_simulator)
SIMULATOR_FOUND=$?

# Check xcbeautify availability
check_xcbeautify
USE_XCBEAUTIFY=$?

echo "🚀 Starting build process..."
echo "   Destination: $DESTINATION"
echo

# Build the xcodebuild command
CMD="xcodebuild build -scheme \"Traveling Snails\" -destination \"$DESTINATION\""

# Add xcbeautify if available
if [ $USE_XCBEAUTIFY -eq 0 ]; then
    CMD="$CMD | xcbeautify --quieter"
fi

# Execute the command
echo "Executing: $CMD"
echo "----------------------------------------"
eval $CMD
EXIT_CODE=$?

echo "----------------------------------------"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Build completed successfully"
else
    echo "❌ Build failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE