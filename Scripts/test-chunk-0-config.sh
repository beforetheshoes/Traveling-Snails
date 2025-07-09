#!/bin/bash
# Shared configuration for all test chunks
# This file should be sourced by all test scripts
# Can also be run directly to setup environment and build project

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Project Configuration
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Use Xcode's default DerivedData path to match Xcode exactly
export DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData/Traveling_Snails-ackkzpghnwayaydvsnwvqosotsnv"
export PROJECT_NAME="Traveling Snails"
export SCHEME_NAME="Traveling Snails"

# Multiple destination support - Use proper simulator names with fallback
export IOS_SIMULATOR_NAME="iPhone 15 Pro"
export IPAD_SIMULATOR_NAME="iPad Pro (12.9-inch) (6th generation)"

# Fallback simulator names if primary ones aren't available
export IOS_SIMULATOR_FALLBACK="iPhone 14 Pro"
export IPAD_SIMULATOR_FALLBACK="iPad Air (5th generation)"

# Last resort: use any available simulator (for local development)
export ANY_IOS_SIMULATOR="Any iOS Simulator Device"

# Use generic simulator names instead of hardcoded IDs to prevent CoreSimulator issues
# This prevents simulator deletion/corruption that can happen with stale IDs
export IOS_SIMULATOR_ID=""  # Let iOS pick the right simulator
export IPAD_SIMULATOR_ID=""  # Let iOS pick the right simulator

# Default destination (can be overridden)
export DESTINATION_TYPE="${TEST_DESTINATION:-ios}"
case "$DESTINATION_TYPE" in
    "ios")
        export SIMULATOR_NAME="$IOS_SIMULATOR_NAME"
        export SIMULATOR_ID=""  # Always use generic name to prevent CoreSimulator issues
        export DESTINATION="platform=iOS Simulator,name=$IOS_SIMULATOR_NAME,arch=arm64"
        ;;
    "ipad")
        export SIMULATOR_NAME="$IPAD_SIMULATOR_NAME"
        export SIMULATOR_ID=""  # Always use generic name to prevent CoreSimulator issues
        export DESTINATION="platform=iOS Simulator,name=$IPAD_SIMULATOR_NAME,arch=arm64"
        ;;
    "mac")
        export SIMULATOR_NAME="My Mac (Designed for iPad)"
        export SIMULATOR_ID="mac"
        export DESTINATION="platform=macOS,arch=arm64"
        ;;
    *)
        # Default to iOS
        export SIMULATOR_NAME="$IOS_SIMULATOR_NAME"
        export SIMULATOR_ID=""  # Always use generic name to prevent CoreSimulator issues
        export DESTINATION="platform=iOS Simulator,name=$IOS_SIMULATOR_NAME,arch=arm64"
        ;;
esac

# Build settings to improve performance and avoid credential issues
# These need to be passed individually with -setting flags
build_settings_array=(
    "CODE_SIGNING_ALLOWED=NO"
    "CODE_SIGNING_REQUIRED=NO"
    "CODE_SIGN_IDENTITY="
    "CODE_SIGN_ENTITLEMENTS="
    "EXPANDED_CODE_SIGN_IDENTITY="
    "PROVISIONING_PROFILE_SPECIFIER="
    "PROVISIONING_PROFILE="
    "DEVELOPMENT_TEAM="
    "COMPILER_INDEX_STORE_ENABLE=NO"
    "SWIFT_COMPILATION_MODE=wholemodule"
)

# Function to format build settings for xcodebuild
format_build_settings() {
    local settings=""
    for setting in "${build_settings_array[@]}"; do
        settings="$settings -setting $setting"
    done
    echo "$settings"
}

export BUILD_SETTINGS=$(format_build_settings)

# SwiftLint cache path
export SWIFTLINT_CACHE_PATH="$PROJECT_ROOT/.swiftlint.cache"

# Timeout for individual test commands (5 minutes)
export TEST_TIMEOUT=300

# Debug mode support
export DEBUG_MODE="${DEBUG_MODE:-false}"

# macOS-compatible timeout function
timeout_macos() {
    local duration=$1
    shift
    
    # Run command in background
    "$@" &
    local pid=$!
    
    # Start watchdog in background
    ( sleep "$duration" && kill -TERM $pid 2>/dev/null && sleep 2 && kill -KILL $pid 2>/dev/null ) &
    local watchdog_pid=$!
    
    # Wait for command to complete
    local exit_code=0
    if wait $pid 2>/dev/null; then
        exit_code=$?
        kill $watchdog_pid 2>/dev/null
        wait $watchdog_pid 2>/dev/null
    else
        # Check if process was killed by watchdog
        if ! kill -0 $pid 2>/dev/null; then
            exit_code=124  # timeout exit code
        else
            exit_code=1  # generic failure
        fi
    fi
    
    return $exit_code
}

# Function to check xcresult bundle for test failures
check_xcresult_failures() {
    local output_file="$1"
    local has_failures=false
    
    # Extract xcresult path from output
    local xcresult_path=$(grep -o "/.*\.xcresult" "$output_file" | head -1)
    
    if [ -n "$xcresult_path" ] && [ -d "$xcresult_path" ]; then
        printf "${CYAN}Checking xcresult bundle for test failures...${NC}\n"
        
        # Use modern xcresulttool to extract test results (Xcode 16+)
        local test_summary=$(xcrun xcresulttool get test-results summary --path "$xcresult_path" --format json 2>/dev/null)
        local test_details=$(xcrun xcresulttool get test-results tests --path "$xcresult_path" --format json 2>/dev/null)
        
        if [ -n "$test_summary" ] || [ -n "$test_details" ]; then
            # Check test summary for failure indicators
            if [ -n "$test_summary" ]; then
                local failed_count=$(echo "$test_summary" | grep -o '"failedTests"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)
                if [ -n "$failed_count" ] && [ "$failed_count" -gt 0 ]; then
                    has_failures=true
                    printf "${RED}Found $failed_count failed tests in xcresult bundle${NC}\n"
                fi
            fi
            
            # Check detailed test results for failures
            if [ -n "$test_details" ]; then
                local failed_tests=$(echo "$test_details" | grep -o '"result"[[:space:]]*:[[:space:]]*"failed"' | wc -l | tr -d ' ')
                if [ "$failed_tests" -gt 0 ]; then
                    has_failures=true
                    printf "${RED}Found $failed_tests failed test cases in xcresult bundle${NC}\n"
                    
                    # Extract and show failure details
                    printf "${RED}Test failure details:${NC}\n"
                    echo "$test_details" | grep -A 10 -B 5 '"result"[[:space:]]*:[[:space:]]*"failed"' | head -30
                    printf "\n"
                fi
                
                # Also check for specific Swift Testing failure patterns
                if echo "$test_details" | grep -q '"expectationFailures"\|"issueRecords"\|"failureMessage"'; then
                    has_failures=true
                    printf "${RED}Found Swift Testing failures in xcresult bundle${NC}\n"
                    # Show failure messages
                    echo "$test_details" | grep -A 5 -B 2 '"expectationFailures"\|"issueRecords"\|"failureMessage"' | head -20
                    printf "\n"
                fi
            fi
        else
            # Fallback: check if any test files mention failures
            printf "${YELLOW}Could not parse xcresult with test-results, checking for failure indicators...${NC}\n"
            if [ -d "$xcresult_path" ]; then
                # Look for failure indicators in the bundle structure
                if find "$xcresult_path" -name "*.json" -exec grep -l "failed\|failure\|expectation.*failed" {} \; 2>/dev/null | grep -q .; then
                    has_failures=true
                    printf "${RED}Found failure indicators in xcresult bundle files${NC}\n"
                fi
            fi
        fi
    fi
    
    if [ "$has_failures" = true ]; then
        return 1
    else
        return 0
    fi
}

# Function to run a command with timeout and capture result
run_step_with_timeout() {
    local description="$1"
    local command="$2"
    local timeout="${3:-$TEST_TIMEOUT}"
    local debug_mode="${4:-false}"
    local start_time=$(date +%s)
    
    printf "${YELLOW}▶ %s${NC}\n" "$description"
    printf "${CYAN}  Command: %s${NC}\n" "$(echo "$command" | head -1)..."
    printf "${CYAN}  Timeout: %ds${NC}\n" "$timeout"
    
    # Create a temporary file for output
    local output_file=$(mktemp)
    
    # Run command with timeout, showing progress
    if [ "$debug_mode" = "true" ]; then
        # Debug mode: stream output in real-time
        printf "${CYAN}  Debug mode: streaming output...${NC}\n"
        if (timeout_macos "$timeout" bash -c "$command" 2>&1 | tee "$output_file"); then
            local exit_code=0
        else
            local exit_code=$?
        fi
    else
        # Normal mode: capture output 
        if (timeout_macos "$timeout" bash -c "$command" > "$output_file" 2>&1); then
            local exit_code=0
        else
            local exit_code=$?
        fi
    fi
    
    if [ $exit_code -eq 0 ]; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Check for test failures in both standard output and xcresult bundle
        local has_failures=false
        
        # First check xcresult bundle (more reliable for Swift Testing)
        if ! check_xcresult_failures "$output_file"; then
            has_failures=true
        fi
        
        # Also check standard output for immediate failures
        if [ -s "$output_file" ]; then
            # Swift Testing specific patterns - Enhanced for your specific errors
            if grep -q "#expect\|#require\|Issue recorded\|recorded.*issue" "$output_file"; then
                has_failures=true
            fi
            # Swift Testing expectation patterns from your examples (most important)
            if grep -q "Expectation failed.*→.*==" "$output_file" || grep -q "Expectation failed:" "$output_file"; then
                has_failures=true
            fi
            # Swift Testing failure indicators
            if grep -q "Test.*failed\|Failed.*test\|❌\|✗\|Issues.*[1-9]" "$output_file"; then
                has_failures=true
            fi
            # Compilation errors - match Xcode patterns (exclude harmless AppIntents warnings)
            if grep -q "error:" "$output_file" || (grep -q "warning:" "$output_file" && ! grep -q "appintentsmetadataprocessor.*warning:\|No AppIntents.framework dependency found" "$output_file"); then
                has_failures=true
            fi
            # Compiler warnings that indicate code issues
            if grep -q "No calls to throwing functions occur within 'try' expression" "$output_file"; then
                has_failures=true
            fi
            # Swift Testing timeout patterns
            if grep -q "testNetworkTimeoutHandling.*failed\|timeout.*exceeded\|Should complete.*within.*time" "$output_file"; then
                has_failures=true
            fi
            # Swift Testing accessibility patterns
            if grep -q "Navigation element.*should contain\|Should provide.*reading flow\|voice command.*should" "$output_file"; then
                has_failures=true
            fi
            # Traditional XCTest failures
            if grep -q "Test Suite.*failed\|Testing failed\|TEST FAILED\|TESTING FAILED" "$output_file"; then
                has_failures=true
            fi
            # Any assertion or expectation failures
            if grep -q "Assertion failed\|failed.*assertion\|failed.*expectation" "$output_file"; then
                has_failures=true
            fi
            # Check exit status patterns that indicate failures
            if grep -q "Test run failed\|Build failed\|xcodebuild.*failed" "$output_file"; then
                has_failures=true
            fi
        fi
        
        if [ "$has_failures" = true ]; then
            printf "${RED}✗ %s completed in %ds but had test failures${NC}\n" "$description" "$duration"
            printf "${RED}Test failures detected:${NC}\n"
            
            # Show compilation errors first (most critical) - exclude harmless warnings
            if grep -q "error:\|warning:" "$output_file" | grep -v "appintentsmetadataprocessor.*warning:\|No AppIntents.framework dependency found"; then
                printf "${RED}Compilation errors/warnings:${NC}\n"
                grep -A 3 -B 1 "error:\|warning:" "$output_file" | grep -v "appintentsmetadataprocessor.*warning:\|No AppIntents.framework dependency found" | head -20
                printf "\n"
            fi
            
            # Show Swift Testing expectation failures (your specific pattern)
            if grep -q "Expectation failed.*→.*==" "$output_file"; then
                printf "${RED}Swift Testing expectation failures:${NC}\n"
                grep -A 2 -B 2 "Expectation failed.*→.*==" "$output_file" | head -30
                printf "\n"
            fi
            
            # Show Swift Testing timeout failures
            if grep -q "testNetworkTimeoutHandling.*failed\|timeout.*exceeded\|Should complete.*within.*time" "$output_file"; then
                printf "${RED}Swift Testing timeout failures:${NC}\n"
                grep -A 3 -B 2 "testNetworkTimeoutHandling.*failed\|timeout.*exceeded\|Should complete.*within.*time" "$output_file" | head -15
                printf "\n"
            fi
            
            # Show Swift Testing accessibility failures
            if grep -q "Navigation element.*should contain\|Should provide.*reading flow\|voice command.*should" "$output_file"; then
                printf "${RED}Swift Testing accessibility failures:${NC}\n"
                grep -A 2 -B 2 "Navigation element.*should contain\|Should provide.*reading flow\|voice command.*should" "$output_file" | head -20
                printf "\n"
            fi
            
            # Show Swift Testing failures
            if grep -q "#expect\|#require" "$output_file"; then
                printf "${RED}Swift Testing #expect/#require failures:${NC}\n"
                grep -A 2 -B 1 "#expect\|#require" "$output_file" | head -15
                printf "\n"
            fi
            
            # Show issue records
            if grep -q "Issue recorded\|recorded.*issue" "$output_file"; then
                printf "${RED}Swift Testing issue records:${NC}\n"
                grep -A 2 -B 2 "Issue recorded\|recorded.*issue" "$output_file" | head -15
                printf "\n"
            fi
            
            # Show traditional test failures
            if grep -q "Testing failed\|TEST FAILED\|Test Suite.*failed" "$output_file"; then
                printf "${RED}Traditional test failures:${NC}\n"
                grep -A 5 -B 2 "Testing failed\|TEST FAILED\|Test Suite.*failed" "$output_file" | head -15
                printf "\n"
            fi
            
            # Show any failure indicators
            if grep -q "❌\|✗" "$output_file"; then
                printf "${RED}Other failure indicators:${NC}\n"
                grep -A 1 -B 1 "❌\|✗" "$output_file" | head -10
                printf "\n"
            fi
            
            rm -f "$output_file"
            printf "\n"
            return 1
        else
            printf "${GREEN}✓ %s completed in %ds${NC}\n\n" "$description" "$duration"
            
            # Show brief success output if available
            if grep -q "Test Suite.*passed" "$output_file"; then
                grep "Test Suite.*passed" "$output_file" | tail -3
                printf "\n"
            fi
            
            rm -f "$output_file"
            return 0
        fi
    else
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ $exit_code -eq 124 ]; then
            printf "${RED}✗ %s timed out after %ds${NC}\n" "$description" "$duration"
        else
            printf "${RED}✗ %s failed after %ds (exit code: %d)${NC}\n" "$description" "$duration" "$exit_code"
        fi
        
        # Show last 30 lines of output for debugging
        printf "${RED}Last output:${NC}\n"
        tail -30 "$output_file"
        rm -f "$output_file"
        printf "\n"
        return 1
    fi
}

# Check simulator availability with intelligent fallback
check_simulator() {
    if [ "$DESTINATION_TYPE" = "mac" ]; then
        printf "${GREEN}✓ Using Mac Catalyst: %s${NC}\n" "$SIMULATOR_NAME"
        return 0
    fi
    
    # Function to find the first available simulator from a list
    find_available_simulator() {
        local sim_list="$1"
        local found_sim=""
        
        for sim_name in $sim_list; do
            if xcrun simctl list devices | grep -q "$sim_name"; then
                found_sim="$sim_name"
                break
            fi
        done
        
        echo "$found_sim"
    }
    
    # Check if the primary simulator exists
    if xcrun simctl list devices | grep -q "$SIMULATOR_NAME"; then
        printf "${GREEN}✓ Found primary simulator: %s${NC}\n" "$SIMULATOR_NAME"
        return 0
    fi
    
    # Try fallback simulators based on destination type
    if [ "$DESTINATION_TYPE" = "ios" ]; then
        fallback_sims="$IOS_SIMULATOR_FALLBACK iPhone 14 iPhone 13 Pro iPhone 12 Pro"
        available_sim=$(find_available_simulator "$fallback_sims")
        
        if [ -n "$available_sim" ]; then
            printf "${YELLOW}⚠️  Primary simulator '$SIMULATOR_NAME' not found${NC}\n"
            printf "${GREEN}✓ Using fallback simulator: %s${NC}\n" "$available_sim"
            export SIMULATOR_NAME="$available_sim"
            export DESTINATION="platform=iOS Simulator,name=$available_sim,arch=arm64"
            return 0
        fi
    elif [ "$DESTINATION_TYPE" = "ipad" ]; then
        fallback_sims="$IPAD_SIMULATOR_FALLBACK iPad Pro (11-inch) iPad Air"
        available_sim=$(find_available_simulator "$fallback_sims")
        
        if [ -n "$available_sim" ]; then
            printf "${YELLOW}⚠️  Primary simulator '$SIMULATOR_NAME' not found${NC}\n"
            printf "${GREEN}✓ Using fallback simulator: %s${NC}\n" "$available_sim"
            export SIMULATOR_NAME="$available_sim"
            export DESTINATION="platform=iOS Simulator,name=$available_sim,arch=arm64"
            return 0
        fi
    fi
    
    # Final fallback: use any available iOS simulator
    printf "${YELLOW}⚠️  No preferred simulators found, checking for any iOS simulator${NC}\n"
    printf "${YELLOW}Available simulators:${NC}\n"
    xcrun simctl list devices | grep -A 10 "iOS" | head -10
    
    # Get first available iOS simulator
    first_sim=$(xcrun simctl list devices | grep -A 20 "iOS" | grep "(" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')
    
    if [ -n "$first_sim" ]; then
        printf "${GREEN}✓ Using available simulator: %s${NC}\n" "$first_sim"
        export SIMULATOR_NAME="$first_sim"
        export DESTINATION="platform=iOS Simulator,name=$first_sim,arch=arm64"
        return 0
    fi
    
    # Last resort: let xcodebuild choose
    printf "${YELLOW}⚠️  Using generic destination - let xcodebuild choose simulator${NC}\n"
    export DESTINATION="platform=iOS Simulator,name=$ANY_IOS_SIMULATOR,arch=arm64"
    return 0
}

# Pre-boot simulator function
boot_simulator() {
    if [ "$DESTINATION_TYPE" = "mac" ]; then
        printf "${GREEN}✓ Mac Catalyst ready (no simulator needed)${NC}\n\n"
        return 0
    fi
    
    printf "${CYAN}Pre-booting simulator (if needed)...${NC}\n"
    
    # Check if any iOS simulator is already booted
    if xcrun simctl list devices | grep "iOS" -A 20 | grep -q "Booted"; then
        printf "${GREEN}✓ iOS simulator already booted${NC}\n\n"
        return 0
    fi
    
    # Let xcodebuild handle simulator booting automatically
    # This prevents CoreSimulator conflicts that can delete simulators
    printf "${GREEN}✓ Will let xcodebuild boot simulator automatically${NC}\n\n"
}

# Cleanup function - VERY gentle to prevent simulator deletion
cleanup_simulator() {
    if [ "$DESTINATION_TYPE" = "mac" ]; then
        printf "${CYAN}Mac Catalyst cleanup complete${NC}\n"
        return 0
    fi
    
    # Do NOT force shutdown simulators - this can cause CoreSimulator issues
    # Let iOS manage simulator lifecycle naturally
    printf "${CYAN}Cleanup complete (letting iOS manage simulators)${NC}\n"
}

# Build project function with option for strict mode
build_project() {
    local strict_mode="${1:-false}"
    local debug_mode="${2:-false}"
    
    printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
    if [ "$strict_mode" = "true" ]; then
        printf "${BLUE}              Building Project (Strict Mode)${NC}\n"
    else
        printf "${BLUE}                    Building Project${NC}\n"
    fi
    if [ "$debug_mode" = "true" ]; then
        printf "${BLUE}                    (Debug Mode)${NC}\n"
    fi
    printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

    # Clean derived data for fresh build
    printf "${CYAN}Cleaning derived data...${NC}\n"
    rm -rf "$DERIVED_DATA_PATH"
    printf "${GREEN}✓ Derived data cleaned${NC}\n\n"

    # Build command - different settings for Mac Catalyst vs iOS
    if [ "$DESTINATION_TYPE" = "mac" ]; then
        printf "${CYAN}Using Mac Catalyst build settings${NC}\n"
        # Mac Catalyst with entitlements stripped for testing
        build_command="xcodebuild build \
            -project \"$PROJECT_NAME.xcodeproj\" \
            -scheme \"$SCHEME_NAME\" \
            -destination \"$DESTINATION\" \
            -derivedDataPath \"$DERIVED_DATA_PATH\" \
            -quiet \
            CODE_SIGN_IDENTITY=- \
            CODE_SIGNING_ALLOWED=YES \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_ENTITLEMENTS= \
            DEVELOPMENT_TEAM= \
            PROVISIONING_PROFILE= \
            PROVISIONING_PROFILE_SPECIFIER= \
            COMPILER_INDEX_STORE_ENABLE=NO"
    elif [ "$strict_mode" = "true" ]; then
        printf "${CYAN}Using strict build settings (matches Xcode exactly)${NC}\n"
        build_command="xcodebuild build \
            -project \"$PROJECT_NAME.xcodeproj\" \
            -scheme \"$SCHEME_NAME\" \
            -destination \"$DESTINATION\" \
            -derivedDataPath \"$DERIVED_DATA_PATH\""
    else
        printf "${CYAN}Using fast build settings (optimized for testing)${NC}\n"
        build_command="xcodebuild build \
            -project \"$PROJECT_NAME.xcodeproj\" \
            -scheme \"$SCHEME_NAME\" \
            -destination \"$DESTINATION\" \
            -derivedDataPath \"$DERIVED_DATA_PATH\" \
            -quiet \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY= \
            CODE_SIGN_ENTITLEMENTS= \
            EXPANDED_CODE_SIGN_IDENTITY= \
            PROVISIONING_PROFILE_SPECIFIER= \
            PROVISIONING_PROFILE= \
            DEVELOPMENT_TEAM= \
            COMPILER_INDEX_STORE_ENABLE=NO \
            SWIFT_COMPILATION_MODE=wholemodule"
    fi

    if ! run_step_with_timeout "Building $PROJECT_NAME" "$build_command" 180 "$debug_mode"; then
        printf "${RED}❌ BUILD FAILED - Cannot proceed with tests${NC}\n"
        if [ "$strict_mode" = "false" ]; then
            printf "${YELLOW}💡 Try running without fast mode for production-ready testing${NC}\n"
        fi
        # Don't cleanup simulator on build failure - not related to simulator issues
        return 1
    fi
    
    printf "${GREEN}✓ Build completed successfully${NC}\n\n"
    return 0
}

# Export functions
export -f timeout_macos
export -f run_step_with_timeout
export -f check_xcresult_failures
export -f check_simulator
export -f boot_simulator
export -f cleanup_simulator
export -f format_build_settings
export -f build_project

# Main execution when run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    START_EPOCH=$(date +%s)

    printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
    printf "${BLUE}           Test Chunk 0: Setup + Build${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
    printf "${CYAN}Timestamp: %s${NC}\n" "$TIMESTAMP"
    printf "${CYAN}Target: Setup environment and build project${NC}\n"
    printf "${CYAN}Directory: %s${NC}\n" "$PROJECT_ROOT"
    printf "${CYAN}Destination: %s (%s)${NC}\n" "$SIMULATOR_NAME" "$DESTINATION_TYPE"
    printf "\n"

    # Change to project root
    cd "$PROJECT_ROOT"

    # Quick dependency check
    printf "${CYAN}Quick dependency check...${NC}\n"
    if ! command -v xcodebuild &> /dev/null; then
        printf "${RED}❌ xcodebuild not found${NC}\n"
        exit 1
    fi
    printf "${GREEN}✓ Dependencies available${NC}\n\n"

    # Check simulator availability
    if ! check_simulator; then
        printf "${RED}❌ Cannot proceed without valid simulator${NC}\n"
        exit 1
    fi

    # Pre-boot simulator for all chunks
    boot_simulator

    # Always use strict mode for production readiness
    # Use fast mode only when explicitly requested for development iteration
    strict_mode="true"
    debug_mode="false"
    
    for arg in "$@"; do
        case "$arg" in
            "fast")
                strict_mode="false"
                printf "${YELLOW}⚡ Running in FAST MODE - for development iteration only${NC}\n"
                printf "${RED}⚠️  This is NOT production-ready testing!${NC}\n\n"
                ;;
            "debug"|"--debug")
                debug_mode="true"
                printf "${CYAN}🔍 Running in DEBUG MODE - showing all output${NC}\n\n"
                ;;
        esac
    done
    
    if [ "$debug_mode" = "false" ] && [ "$strict_mode" = "true" ]; then
        printf "${GREEN}🔍 Running in STRICT MODE - production-ready testing${NC}\n\n"
    fi

    # Build the project
    if ! build_project "$strict_mode" "$debug_mode"; then
        printf "${RED}❌ SETUP FAILED${NC}\n"
        # Don't cleanup simulator on setup failure - not related to simulator issues
        exit 1
    fi

    # Summary
    printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
    printf "${BLUE}                  Chunk 0 Summary${NC}\n"
    printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

    total_duration=$(($(date +%s) - START_EPOCH))
    printf "${CYAN}Chunk 0 Execution Summary${NC}\n"
    printf "Start Time: %s\n" "$TIMESTAMP"
    printf "End Time:   %s\n" "$(date +"%Y-%m-%d %H:%M:%S")"
    printf "Duration:   %ds\n\n" "$total_duration"

    printf "${GREEN}╔═══════════════════════════════════════╗${NC}\n"
    printf "${GREEN}║       CHUNK 0 PASSED! ✅             ║${NC}\n"
    printf "${GREEN}║     Setup + Build Complete           ║${NC}\n"
    printf "${GREEN}╚═══════════════════════════════════════╝${NC}\n\n"
    printf "${GREEN}Ready to proceed to test chunks 1-5${NC}\n"
    printf "${CYAN}Environment prepared, simulator running, project built${NC}\n\n"

    exit 0
fi