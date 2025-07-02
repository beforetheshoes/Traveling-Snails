#!/bin/bash

# Enhanced Test script for Traveling Snails
# Usage: ./run_tests.sh [optional-test-target]
# 
# This script handles multiple iOS versions and simulator configurations
# and provides better error handling for test execution

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

# Function to run tests with proper error handling
run_tests() {
    local test_target="$1"
    local destination="$2"
    local use_xcbeautify="$3"
    
    echo "🚀 Starting test execution..."
    echo "   Destination: $destination"
    if [ ! -z "$test_target" ]; then
        echo "   Target: $test_target"
    fi
    echo
    
    # Build the xcodebuild command
    local cmd="xcodebuild test -scheme \"Traveling Snails\" -destination \"$destination\""
    
    if [ ! -z "$test_target" ]; then
        cmd="$cmd -only-testing:\"$test_target\""
    fi
    
    # Add xcbeautify if available
    if [ "$use_xcbeautify" = "true" ]; then
        cmd="$cmd | xcbeautify --quieter"
    fi
    
    # Execute the command
    echo "Executing: $cmd"
    echo "----------------------------------------"
    eval $cmd
    local exit_code=$?
    
    echo "----------------------------------------"
    if [ $exit_code -eq 0 ]; then
        echo "✅ Tests completed successfully"
    else
        echo "❌ Tests failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

# Main script execution
echo "📱 Traveling Snails Test Runner"
echo "================================"

# Find simulator
DESTINATION=$(find_simulator)
SIMULATOR_FOUND=$?

# Check xcbeautify availability
check_xcbeautify
USE_XCBEAUTIFY=$?
if [ $USE_XCBEAUTIFY -eq 0 ]; then
    USE_XCBEAUTIFY="true"
else
    USE_XCBEAUTIFY="false"
fi

# Determine test target
if [ $# -eq 0 ]; then
    echo "🧪 Running all tests..."
    TEST_TARGET=""
else
    echo "🎯 Running specific test target: $1"
    TEST_TARGET="$1"
fi

# Run tests
run_tests "$TEST_TARGET" "$DESTINATION" "$USE_XCBEAUTIFY"
exit $?