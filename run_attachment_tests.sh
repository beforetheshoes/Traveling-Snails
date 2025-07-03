#!/bin/bash

# Focused Test Script for Issue #28: File Attachment Export/Import
# Tests the specific attachment functionality and UI refresh fixes

cd "$(dirname "$0")"

# Import common functions from main test script
source_functions() {
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
}

# Source the functions
source_functions

# Function to run a specific test suite
run_test_suite() {
    local test_suite="$1"
    local description="$2"
    local destination="$3"
    local use_xcbeautify="$4"
    
    echo
    echo "🧪 Testing: $description"
    echo "   Suite: $test_suite"
    echo "   Destination: $destination"
    echo
    
    # Build the xcodebuild command
    local cmd="xcodebuild test -scheme \"Traveling Snails\" -destination \"$destination\" -only-testing:\"$test_suite\""
    
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
        echo "✅ $description - PASSED"
    else
        echo "❌ $description - FAILED (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Main script execution
echo "📎 Issue #28: File Attachment Test Runner"
echo "========================================="
echo "Testing attachment export/import and UI refresh functionality"
echo

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

# Track overall success
OVERALL_SUCCESS=0
TESTS_RUN=0
TESTS_PASSED=0

# Test suites specifically for Issue #28
echo "🎯 Running Issue #28 specific tests..."

# Test 1: Original attachment functionality
echo
echo "═══════════════════════════════════════════════════════════════"
run_test_suite "Traveling Snails Tests/EmbeddedFileAttachmentTests" "Original Attachment Functionality" "$DESTINATION" "$USE_XCBEAUTIFY"
if [ $? -eq 0 ]; then
    ((TESTS_PASSED++))
fi
((TESTS_RUN++))

# Test 2: Export/Import bug reproduction tests
echo
echo "═══════════════════════════════════════════════════════════════"
run_test_suite "Traveling Snails Tests/FileAttachmentExportImportBugTests" "Export/Import Bug Tests" "$DESTINATION" "$USE_XCBEAUTIFY"
if [ $? -eq 0 ]; then
    ((TESTS_PASSED++))
fi
((TESTS_RUN++))

# Test 3: Minimal reproduction tests
echo
echo "═══════════════════════════════════════════════════════════════"
run_test_suite "Traveling Snails Tests/MinimalAttachmentBugReproTest" "Minimal Bug Reproduction" "$DESTINATION" "$USE_XCBEAUTIFY"
if [ $? -eq 0 ]; then
    ((TESTS_PASSED++))
fi
((TESTS_RUN++))

# Test 4: UI Refresh bug tests
echo
echo "═══════════════════════════════════════════════════════════════"
run_test_suite "Traveling Snails Tests/AttachmentUIRefreshBugTest" "UI Refresh Fix Tests" "$DESTINATION" "$USE_XCBEAUTIFY"
if [ $? -eq 0 ]; then
    ((TESTS_PASSED++))
fi
((TESTS_RUN++))

# Test 5: Comprehensive import/export integration tests
echo
echo "═══════════════════════════════════════════════════════════════"
run_test_suite "Traveling Snails Tests/ComprehensiveImportExportTests/FileAttachmentImportExportTests" "Comprehensive Import/Export Tests" "$DESTINATION" "$USE_XCBEAUTIFY"
if [ $? -eq 0 ]; then
    ((TESTS_PASSED++))
fi
((TESTS_RUN++))

# Final results
echo
echo "========================================="
echo "📊 Issue #28 Test Results Summary"
echo "========================================="
echo "Tests Run: $TESTS_RUN"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $((TESTS_RUN - TESTS_PASSED))"

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo "🎉 ALL TESTS PASSED - Issue #28 fix is working correctly!"
    echo
    echo "✅ File attachment export functionality verified"
    echo "✅ File attachment import functionality verified"  
    echo "✅ UI refresh mechanism working correctly"
    echo "✅ Complete export/import cycle validated"
    exit 0
else
    echo "❌ SOME TESTS FAILED - Issue #28 fix needs more work"
    echo
    echo "Please review the failed tests above and address any issues."
    echo "The attachment export/import or UI refresh functionality may not be working correctly."
    exit 1
fi