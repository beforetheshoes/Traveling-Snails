#!/bin/bash
# Comprehensive Test and Lint Runner for Traveling Snails
# This script runs all tests and linting checks for the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="Traveling Snails"
SCHEME_NAME="Traveling Snails"
# Use generic simulator for better CI compatibility
SIMULATOR_NAME="iPhone 15 Pro" 
GENERIC_SIMULATOR="platform=iOS Simulator,name=iPhone 15 Pro"

# Fallback simulator names if primary ones aren't available
SIMULATOR_FALLBACK="iPhone 14 Pro"
IPAD_SIMULATOR_FALLBACK="iPad Pro (12.9-inch) (6th generation)"

# Function to find available simulator
find_available_simulator() {
    local primary_sim="$1"
    local fallback_sim="${2:-iPhone 14 Pro}"
    
    # Check if primary simulator exists
    if xcrun simctl list devices | grep -q "$primary_sim"; then
        echo "$primary_sim"
        return 0
    fi
    
    # Try fallback simulators
    local fallback_list="$fallback_sim iPhone 14 iPhone 13 Pro iPhone 12 Pro"
    for sim_name in $fallback_list; do
        if xcrun simctl list devices | grep -q "$sim_name"; then
            echo "$sim_name"
            return 0
        fi
    done
    
    # Get first available iOS simulator
    local first_sim=$(xcrun simctl list devices | grep -A 20 "iOS" | grep "(" | head -1 | sed 's/^[[:space:]]*//' | sed 's/ (.*//')
    if [ -n "$first_sim" ]; then
        echo "$first_sim"
        return 0
    fi
    
    # Last resort
    echo "Any iOS Simulator Device"
    return 0
}

# Set actual simulator name based on availability
ACTUAL_SIMULATOR=$(find_available_simulator "$SIMULATOR_NAME" "$SIMULATOR_FALLBACK")
GENERIC_SIMULATOR="platform=iOS Simulator,name=$ACTUAL_SIMULATOR"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
START_EPOCH=$(date +%s)
EXIT_CODE=0

# Global array for background process IDs
declare -a pids=()

# Test target configuration
TEST_TARGET="Traveling Snails Tests"
UNIT_TEST_PATH="Unit Tests"
INTEGRATION_TEST_PATH="Integration Tests"
PERFORMANCE_TEST_PATH="Performance Tests"

# Change to project root
cd "$PROJECT_ROOT"

# Signal handlers for cleanup
cleanup() {
    echo -e "${YELLOW}\n⚠️  Cleaning up background processes...${NC}"
    # Kill background processes if they exist
    if [ ${#pids[@]} -gt 0 ]; then
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done
    fi
    # Clean up temporary files
    rm -f .unit_test_exit_code .integration_test_exit_code .performance_test_exit_code .security_test_exit_code
    rm -f .test_cache_*.tmp
    exit 130
}

# Set up signal handlers
trap cleanup INT TERM

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        Traveling Snails - Test & Lint Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Timestamp: $TIMESTAMP${NC}"
echo -e "${CYAN}Directory: $PROJECT_ROOT${NC}"
echo ""

# Function to check if tests need to run based on cache
should_run_tests() {
    local test_name="$1"
    local cache_file=".test_cache_${test_name// /_}"
    
    if [ "$USE_CACHE" = false ]; then
        return 0  # Always run if cache disabled
    fi
    
    if [ ! -f "$cache_file" ]; then
        return 0  # Run if no cache file
    fi
    
    local cache_time=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
    local newest_source=$(find . -name "*.swift" -not -path "./.build/*" -not -path "./build/*" -newer "$cache_file" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$newest_source" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Source files changed since last $test_name run${NC}"
        return 0  # Run if source files changed
    fi
    
    echo -e "${GREEN}✓ $test_name skipped (cached result valid)${NC}"
    return 1  # Skip if cache valid
}

# Function to mark test as cached
mark_test_cached() {
    local test_name="$1"
    local cache_file=".test_cache_${test_name// /_}"
    local exit_code="$2"
    
    if [ "$USE_CACHE" = true ]; then
        # Use atomic write for cache file to prevent race conditions
        local temp_file="${cache_file}.tmp"
        echo "$exit_code" > "$temp_file" && mv "$temp_file" "$cache_file"
        touch "$cache_file"
    fi
}

# Function to execute test with xcbeautify and simulator fallback
execute_test_with_xcbeautify() {
    local test_name="$1"
    local xcodebuild_command="$2"
    
    # Check cache first
    if ! should_run_tests "$test_name"; then
        return 0
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 Running $test_name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Add coverage flags if requested
    if [ "$COVERAGE" = true ]; then
        xcodebuild_command="$xcodebuild_command -enableCodeCoverage YES -derivedDataPath ./build"
    fi
    
    # Check for simulator availability and fallback
    local simulator="$SIMULATOR_NAME"
    if ! xcrun simctl list devices | grep -q "$simulator"; then
        echo -e "${YELLOW}⚠️  $simulator not available, using fallback...${NC}"
        simulator="$ACTUAL_SIMULATOR"
        echo -e "${GREEN}✓ Using $simulator instead${NC}"
    fi
    
    # Update command with correct simulator
    local updated_command=$(echo "$xcodebuild_command" | sed "s/name=$SIMULATOR_NAME/name=$simulator/g")
    
    # Store the base command for error handling
    local base_command="$updated_command"
    
    # Add xcbeautify if available, but preserve exit codes
    if command -v xcbeautify &> /dev/null; then
        # Use set -o pipefail to preserve xcodebuild exit code through pipe
        updated_command="set -o pipefail && $updated_command | xcbeautify"
    else
        # Without xcbeautify, still preserve exit code
        updated_command="set -o pipefail && $updated_command 2>&1 | tee /dev/stderr | grep -E \"Test Suite|Test Case|passed|failed|error\" || true"
    fi
    
    # Execute and capture exit code
    if eval "$updated_command"; then
        echo -e "${GREEN}✓ All $test_name passed!${NC}"
        mark_test_cached "$test_name" 0
    else
        local exit_status=$?
        echo -e "${RED}✗ $test_name execution failed with exit code: $exit_status${NC}"
        echo -e "${CYAN}Command: $base_command${NC}"
        
        # Check if it's a simulator issue
        if [[ $exit_status -eq 70 ]] || grep -q "Unable to find a destination" <<< "$base_command"; then
            echo -e "${YELLOW}⚠️  Simulator issue detected. Retrying with generic destination...${NC}"
            
            # Retry with generic simulator
            local generic_command=$(echo "$base_command" | sed "s/-destination \"[^\"]*\"/-destination \"$GENERIC_SIMULATOR\"/g")
            echo -e "${CYAN}Retry command: $generic_command${NC}"
            
            if command -v xcbeautify &> /dev/null; then
                generic_command="set -o pipefail && $generic_command | xcbeautify"
            fi
            
            if eval "$generic_command"; then
                echo -e "${GREEN}✓ All $test_name passed with generic simulator!${NC}"
                mark_test_cached "$test_name" 0
                return 0
            else
                echo -e "${RED}✗ $test_name failed even with generic simulator${NC}"
                mark_test_cached "$test_name" 1
                EXIT_CODE=1
                return 1
            fi
        fi
        
        mark_test_cached "$test_name" 1
        EXIT_CODE=1
        return 1
    fi
    
    echo ""
}

# Function to run a command and capture result
run_step() {
    local description="$1"
    local command="$2"
    local start_time=$(date +%s)
    
    echo -e "${YELLOW}▶ $description${NC}"
    
    if eval "$command"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ $description completed in ${duration}s${NC}"
        echo ""
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}✗ $description failed after ${duration}s${NC}"
        echo ""
        EXIT_CODE=1
        return 1
    fi
}

# Function to check dependencies
check_dependencies() {
    echo -e "${CYAN}Checking dependencies...${NC}"
    
    local missing_deps=()
    
    # Check for xcodebuild
    if ! command -v xcodebuild &> /dev/null; then
        missing_deps+=("xcodebuild (Xcode)")
    fi
    
    # Check for swift
    if ! command -v swift &> /dev/null; then
        missing_deps+=("swift")
    fi
    
    # Check for xcbeautify (optional but recommended)
    if ! command -v xcbeautify &> /dev/null; then
        echo -e "${YELLOW}⚠️  xcbeautify not found. Install with: brew install xcbeautify${NC}"
        echo -e "${YELLOW}   Output will be less readable without it.${NC}"
    fi
    
    # Check for jq (used in SwiftLint analysis)
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️  jq not found. Install with: brew install jq${NC}"
        echo -e "${YELLOW}   Some SwiftLint analysis features will be limited.${NC}"
    fi
    
    # Check for available iOS simulators
    if command -v xcodebuild &> /dev/null; then
        echo -e "${CYAN}Checking available iOS simulators...${NC}"
        local available_sims=$(xcodebuild -showdestinations -scheme "$SCHEME_NAME" 2>/dev/null | grep "platform:iOS Simulator" | head -5 || true)
        if [[ -z "$available_sims" ]]; then
            echo -e "${YELLOW}⚠️  No iOS simulators found. Tests may fail.${NC}"
            echo -e "${YELLOW}   Try: sudo xcode-select -s /Applications/Xcode.app${NC}"
        else
            echo -e "${GREEN}✓ iOS simulators available${NC}"
            if ! echo "$available_sims" | grep -q "$SIMULATOR_NAME"; then
                echo -e "${YELLOW}⚠️  '$SIMULATOR_NAME' simulator not found. Will use generic destination.${NC}"
            fi
        fi
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${RED}   - $dep${NC}"
        done
        exit 1
    fi
    
    echo -e "${GREEN}✓ All required dependencies found${NC}"
    echo ""
}

# Function to clean derived data
clean_derived_data() {
    echo -e "${CYAN}Cleaning build artifacts...${NC}"
    
    # Clean Xcode derived data
    if xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" clean &> /dev/null; then
        echo -e "${GREEN}✓ Xcode build cleaned${NC}"
    fi
    
    # Clean Swift package artifacts
    if [ -d ".build" ]; then
        rm -rf .build
        echo -e "${GREEN}✓ Swift package build cleaned${NC}"
    fi
    
    echo ""
}

# Function to resolve dependencies
resolve_dependencies() {
    run_step "Resolving Swift package dependencies" \
        "swift package resolve"
}

# Function to validate test targets exist
validate_test_targets() {
    echo -e "${CYAN}Validating test targets...${NC}"
    
    local validation_failed=false
    
    # Check if the main test target exists
    if ! xcodebuild -project "$PROJECT_NAME.xcodeproj" -list 2>/dev/null | grep -q "$TEST_TARGET"; then
        echo -e "${RED}❌ Test target '$TEST_TARGET' not found in project${NC}"
        validation_failed=true
    else
        echo -e "${GREEN}✓ Found test target: $TEST_TARGET${NC}"
    fi
    
    # Function to validate individual test categories can be run
    validate_test_category() {
        local category_name="$1"
        local test_path="$2"
        
        # Check if test directory exists
        if [ ! -d "$PROJECT_ROOT/$TEST_TARGET/$test_path" ]; then
            echo -e "${RED}❌ $category_name directory not found: $test_path${NC}"
            return 1
        fi
        
        # Check if directory contains Swift test files
        if ! ls "$PROJECT_ROOT/$TEST_TARGET/$test_path"/*.swift >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Warning: No Swift test files found in $category_name directory${NC}"
            return 1
        fi
        
        echo -e "${GREEN}✓ Found $category_name with test files${NC}"
        return 0
    }
    
    # Validate each test category
    validate_test_category "Unit Tests" "$UNIT_TEST_PATH"
    validate_test_category "Integration Tests" "$INTEGRATION_TEST_PATH" 
    validate_test_category "Performance Tests" "$PERFORMANCE_TEST_PATH"
    
    # Additional validation: Try a dry-run test command to verify xcodebuild can find the targets
    echo -e "${CYAN}Performing dry-run validation...${NC}"
    if xcodebuild test \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "platform=iOS Simulator,name=$ACTUAL_SIMULATOR" \
        -only-testing:"$TEST_TARGET/$UNIT_TEST_PATH" \
        -dry-run >/dev/null 2>&1; then
        echo -e "${GREEN}✓ xcodebuild can locate test targets${NC}"
    else
        echo -e "${YELLOW}⚠️  xcodebuild dry-run failed - test targets may not be properly configured${NC}"
        echo -e "${CYAN}Tip: Run 'xcodebuild test -project \"$PROJECT_NAME.xcodeproj\" -scheme \"$SCHEME_NAME\" -showBuildSettings' to debug${NC}"
    fi
    
    if [ "$validation_failed" = true ]; then
        echo -e "${RED}Test target validation failed. Please check your project configuration.${NC}"
        exit 1
    fi
    
    echo ""
}

# Function to run security tests only
run_security_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\" \
        -only-testing:\"$TEST_TARGET/Security Tests\""
    
    execute_test_with_xcbeautify "Security Tests" "$xcodebuild_command"
}

# Function to run regression prevention tests specifically
run_regression_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\" \
        -only-testing:\"$TEST_TARGET/Security Tests/TestRegressionPreventionTests\""
    
    execute_test_with_xcbeautify "Regression Prevention Tests" "$xcodebuild_command"
}

# Function to run unit tests only
run_unit_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\" \
        -only-testing:\"$TEST_TARGET/$UNIT_TEST_PATH\""
    
    execute_test_with_xcbeautify "Unit Tests" "$xcodebuild_command"
}

# Function to run integration tests only
run_integration_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\" \
        -only-testing:\"$TEST_TARGET/$INTEGRATION_TEST_PATH\""
    
    execute_test_with_xcbeautify "Integration Tests" "$xcodebuild_command"
}

# Function to run performance tests only
run_performance_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\" \
        -only-testing:\"$TEST_TARGET/$PERFORMANCE_TEST_PATH\""
    
    execute_test_with_xcbeautify "Performance Tests" "$xcodebuild_command"
}

# Function to run SwiftLint
run_swiftlint() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    SwiftLint Analysis${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Run SwiftLint with JSON output for analysis
    local lint_output_file="swiftlint-results.json"
    
    if swift run swiftlint lint --config .swiftlint.yml --reporter json > "$lint_output_file" 2>/dev/null; then
        echo -e "${GREEN}✓ SwiftLint analysis completed${NC}"
    else
        echo -e "${YELLOW}⚠️  SwiftLint found issues${NC}"
    fi
    
    # Analyze results
    if command -v jq &> /dev/null && [ -f "$lint_output_file" ]; then
        local total_violations=$(jq 'length' "$lint_output_file" 2>/dev/null || echo "0")
        local error_count=$(jq '[.[] | select(.severity == "error")] | length' "$lint_output_file" 2>/dev/null || echo "0")
        local warning_count=$(jq '[.[] | select(.severity == "warning")] | length' "$lint_output_file" 2>/dev/null || echo "0")
        local security_violations=$(jq '[.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages"))] | length' "$lint_output_file" 2>/dev/null || echo "0")
        
        echo ""
        echo -e "${CYAN}SwiftLint Summary:${NC}"
        echo -e "  Total violations: $total_violations"
        echo -e "  Errors: ${RED}$error_count${NC}"
        echo -e "  Warnings: ${YELLOW}$warning_count${NC}"
        echo -e "  Security issues: ${RED}$security_violations${NC}"
        
        # Check for critical violations
        if [ "$error_count" -gt 0 ] || [ "$security_violations" -gt 0 ]; then
            echo ""
            echo -e "${RED}❌ Critical SwiftLint violations found!${NC}"
            
            # Show details for errors
            if [ "$error_count" -gt 0 ]; then
                echo -e "${RED}Errors:${NC}"
                jq -r '.[] | select(.severity == "error") | "  \(.file):\(.line):\(.character) - \(.rule_id): \(.reason)"' "$lint_output_file" 2>/dev/null | head -10
                if [ "$error_count" -gt 10 ]; then
                    echo "  ... and $((error_count - 10)) more errors"
                fi
            fi
            
            # Show security violations
            if [ "$security_violations" -gt 0 ]; then
                echo -e "${RED}Security Violations:${NC}"
                jq -r '.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages")) | "  \(.file):\(.line) - \(.rule_id): \(.reason)"' "$lint_output_file" 2>/dev/null
            fi
            
            EXIT_CODE=1
        else
            echo -e "${GREEN}✓ No critical violations${NC}"
        fi
        
        # Clean up
        rm -f "$lint_output_file"
    else
        # Fallback to regular output if jq not available
        swift run swiftlint lint --config .swiftlint.yml || EXIT_CODE=1
    fi
    
    echo ""
}

# Function to build the project
build_project() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    Building Project${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local build_command="xcodebuild build \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\""
    
    # Add xcbeautify if available
    if command -v xcbeautify &> /dev/null; then
        build_command="$build_command | xcbeautify"
    fi
    
    run_step "Building $PROJECT_NAME" "$build_command"
}

# Function to run tests in parallel
run_tests_parallel() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}              Running Tests in Parallel${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Start background processes for each test category
    pids=()
    
    # Unit tests
    (
        run_unit_tests
        echo $? > .unit_test_exit_code
    ) &
    pids+=($!)
    
    # Integration tests  
    (
        run_integration_tests
        echo $? > .integration_test_exit_code
    ) &
    pids+=($!)
    
    # Performance tests
    (
        run_performance_tests
        echo $? > .performance_test_exit_code
    ) &
    pids+=($!)
    
    # Security tests
    (
        run_security_tests
        echo $? > .security_test_exit_code
    ) &
    pids+=($!)
    
    # Wait for all processes to complete
    echo -e "${CYAN}Waiting for parallel test execution to complete...${NC}"
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    # Check exit codes
    local unit_exit=$(cat .unit_test_exit_code 2>/dev/null || echo 1)
    local integration_exit=$(cat .integration_test_exit_code 2>/dev/null || echo 1)
    local performance_exit=$(cat .performance_test_exit_code 2>/dev/null || echo 1)
    local security_exit=$(cat .security_test_exit_code 2>/dev/null || echo 1)
    
    # Verify exit code files exist and are readable
    if [ ! -f ".unit_test_exit_code" ]; then
        echo -e "${RED}⚠️  Unit test exit code file missing${NC}"
        unit_exit=1
    fi
    if [ ! -f ".integration_test_exit_code" ]; then
        echo -e "${RED}⚠️  Integration test exit code file missing${NC}"
        integration_exit=1
    fi
    if [ ! -f ".performance_test_exit_code" ]; then
        echo -e "${RED}⚠️  Performance test exit code file missing${NC}"
        performance_exit=1
    fi
    if [ ! -f ".security_test_exit_code" ]; then
        echo -e "${RED}⚠️  Security test exit code file missing${NC}"
        security_exit=1
    fi
    
    # Clean up exit code files
    rm -f .unit_test_exit_code .integration_test_exit_code .performance_test_exit_code .security_test_exit_code
    
    # Report results
    echo -e "${CYAN}Parallel Test Results:${NC}"
    [ $unit_exit -eq 0 ] && echo -e "${GREEN}✓ Unit Tests${NC}" || echo -e "${RED}✗ Unit Tests${NC}"
    [ $integration_exit -eq 0 ] && echo -e "${GREEN}✓ Integration Tests${NC}" || echo -e "${RED}✗ Integration Tests${NC}"
    [ $performance_exit -eq 0 ] && echo -e "${GREEN}✓ Performance Tests${NC}" || echo -e "${RED}✗ Performance Tests${NC}"
    [ $security_exit -eq 0 ] && echo -e "${GREEN}✓ Security Tests${NC}" || echo -e "${RED}✗ Security Tests${NC}"
    
    # Set global exit code if any tests failed
    if [ $unit_exit -ne 0 ] || [ $integration_exit -ne 0 ] || [ $performance_exit -ne 0 ] || [ $security_exit -ne 0 ]; then
        EXIT_CODE=1
    fi
    
    echo ""
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    Running Tests${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local test_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\""
    
    # Add xcbeautify if available
    if command -v xcbeautify &> /dev/null; then
        test_command="$test_command | xcbeautify"
    else
        # Without xcbeautify, at least filter for test results
        test_command="$test_command 2>&1 | grep -E \"Test Suite|Test Case|passed|failed|error\""
    fi
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        EXIT_CODE=1
    fi
    
    echo ""
}

# Function to generate coverage report
generate_coverage_report() {
    if [ "$COVERAGE" = true ]; then
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}                  Coverage Report${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        local coverage_dir="./build/Build/ProfileData"
        if [ -d "$coverage_dir" ]; then
            echo -e "${CYAN}Generating coverage report...${NC}"
            
            # Find coverage files
            local coverage_files=$(find "$coverage_dir" -name "*.profdata" 2>/dev/null)
            if [ -n "$coverage_files" ]; then
                echo -e "${GREEN}✓ Coverage data found${NC}"
                echo -e "${CYAN}Coverage files:${NC}"
                echo "$coverage_files"
                
                # Generate coverage report
                echo -e "${CYAN}Run this command to view detailed coverage:${NC}"
                # Find the app path dynamically
                local app_path=$(find ./build/Build/Products -name "*.app" -type d | head -1)
                if [ -n "$app_path" ]; then
                    local app_binary="$app_path/$(basename "$app_path" .app)"
                    echo "xcrun llvm-cov report \\"
                    echo "  \"$app_binary\" \\"
                    echo "  -instr-profile=$coverage_files \\"
                    echo "  -ignore-filename-regex=Tests"
                else
                    echo -e "${RED}⚠️  Could not find app binary for coverage report${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  No coverage data found${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Coverage directory not found${NC}"
        fi
        
        echo ""
    fi
}

# Function to generate summary report
generate_summary() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    Summary Report${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local end_timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local total_duration=$(($(date +%s) - START_EPOCH))
    
    echo -e "${CYAN}Test Suite Execution Summary${NC}"
    echo -e "Start Time: $TIMESTAMP"
    echo -e "End Time:   $end_timestamp"
    echo -e "Duration:   ${total_duration}s"
    echo ""
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║         ALL CHECKS PASSED! ✅         ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}The codebase is ready for commit/deployment.${NC}"
    else
        echo -e "${RED}╔═══════════════════════════════════════╗${NC}"
        echo -e "${RED}║      SOME CHECKS FAILED! ❌          ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${RED}Please fix the issues above before proceeding.${NC}"
        echo ""
        echo -e "${YELLOW}Tips:${NC}"
        echo -e "  • Run ${CYAN}swift run swiftlint --autocorrect${NC} to fix style issues"
        echo -e "  • Check test output above for failing tests"
        echo -e "  • Ensure all security violations are addressed"
    fi
    
    echo ""
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --no-clean           Skip cleaning derived data"
    echo "  --lint-only          Run only SwiftLint checks"
    echo "  --test-only          Run only tests (no linting)"
    echo "  --security-only      Run only security tests"
    echo "  --unit-only          Run only unit tests"
    echo "  --integration-only   Run only integration tests"
    echo "  --performance-only   Run only performance tests"
    echo "  --regression-only    Run only regression prevention tests"
    echo "  --no-build           Skip building project (tests only)"
    echo "  --quick              Skip dependency resolution"
    echo "  --parallel           Run test categories in parallel"
    echo "  --cache              Use test result caching"
    echo "  --coverage           Generate test coverage report"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Test Category Options:"
    echo "  The --unit-only, --integration-only, --performance-only, and --security-only"
    echo "  options are mutually exclusive. Only one can be used at a time."
    echo ""
    echo "Examples:"
    echo "  $0                        # Run all checks"
    echo "  $0 --lint-only            # Run only SwiftLint"
    echo "  $0 --test-only            # Run only tests"
    echo "  $0 --security-only        # Run only security tests"
    echo "  $0 --unit-only            # Run only unit tests"
    echo "  $0 --integration-only     # Run only integration tests"
    echo "  $0 --performance-only     # Run only performance tests"
    echo "  $0 --regression-only      # Run only regression prevention tests"
    echo "  $0 --unit-only --no-build # Run unit tests without rebuilding"
    echo "  $0 --no-clean --quick     # Fast run without cleanup"
    echo "  $0 --parallel --coverage  # Parallel execution with coverage"
}

# Parse command line arguments
SKIP_CLEAN=false
LINT_ONLY=false
TEST_ONLY=false
SECURITY_ONLY=false
UNIT_ONLY=false
INTEGRATION_ONLY=false
PERFORMANCE_ONLY=false
REGRESSION_ONLY=false
QUICK_RUN=false
NO_BUILD=false
PARALLEL=false
USE_CACHE=false
COVERAGE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-clean)
            SKIP_CLEAN=true
            shift
            ;;
        --lint-only)
            LINT_ONLY=true
            shift
            ;;
        --test-only)
            TEST_ONLY=true
            shift
            ;;
        --security-only)
            SECURITY_ONLY=true
            shift
            ;;
        --unit-only)
            UNIT_ONLY=true
            shift
            ;;
        --integration-only)
            INTEGRATION_ONLY=true
            shift
            ;;
        --performance-only)
            PERFORMANCE_ONLY=true
            shift
            ;;
        --regression-only)
            REGRESSION_ONLY=true
            shift
            ;;
        --no-build)
            NO_BUILD=true
            shift
            ;;
        --quick)
            QUICK_RUN=true
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --cache)
            USE_CACHE=true
            shift
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check for mutually exclusive test category options
check_mutual_exclusivity() {
    local count=0
    local selected_options=""
    
    if [ "$SECURITY_ONLY" = true ]; then
        count=$((count + 1))
        selected_options="$selected_options --security-only"
    fi
    
    if [ "$UNIT_ONLY" = true ]; then
        count=$((count + 1))
        selected_options="$selected_options --unit-only"
    fi
    
    if [ "$INTEGRATION_ONLY" = true ]; then
        count=$((count + 1))
        selected_options="$selected_options --integration-only"
    fi
    
    if [ "$PERFORMANCE_ONLY" = true ]; then
        count=$((count + 1))
        selected_options="$selected_options --performance-only"
    fi
    
    if [ "$REGRESSION_ONLY" = true ]; then
        count=$((count + 1))
        selected_options="$selected_options --regression-only"
    fi
    
    if [ $count -gt 1 ]; then
        echo -e "${RED}Error: Test category options are mutually exclusive${NC}"
        echo -e "${RED}You specified:$selected_options${NC}"
        echo "Please use only one of: --security-only, --unit-only, --integration-only, --performance-only, or --regression-only"
        exit 1
    fi
}

# Main execution
main() {
    # Check for mutually exclusive options
    check_mutual_exclusivity
    
    # Check dependencies first
    check_dependencies
    
    # Validate test targets exist (unless running lint-only)
    if [ "$LINT_ONLY" = false ]; then
        validate_test_targets
    fi
    
    # Clean if not skipped
    if [ "$SKIP_CLEAN" = false ] && [ "$QUICK_RUN" = false ]; then
        clean_derived_data
    fi
    
    # Resolve dependencies if not quick run
    if [ "$QUICK_RUN" = false ]; then
        resolve_dependencies
    fi
    
    # Handle specific test category modes
    if [ "$SECURITY_ONLY" = true ]; then
        if [ "$NO_BUILD" = false ]; then
            build_project
        fi
        if [ $EXIT_CODE -eq 0 ]; then
            run_security_tests
        else
            echo -e "${YELLOW}⚠️  Skipping security tests due to build failure${NC}"
        fi
    elif [ "$UNIT_ONLY" = true ]; then
        if [ "$NO_BUILD" = false ]; then
            build_project
        fi
        if [ $EXIT_CODE -eq 0 ]; then
            run_unit_tests
        else
            echo -e "${YELLOW}⚠️  Skipping unit tests due to build failure${NC}"
        fi
    elif [ "$INTEGRATION_ONLY" = true ]; then
        if [ "$NO_BUILD" = false ]; then
            build_project
        fi
        if [ $EXIT_CODE -eq 0 ]; then
            run_integration_tests
        else
            echo -e "${YELLOW}⚠️  Skipping integration tests due to build failure${NC}"
        fi
    elif [ "$PERFORMANCE_ONLY" = true ]; then
        if [ "$NO_BUILD" = false ]; then
            build_project
        fi
        if [ $EXIT_CODE -eq 0 ]; then
            run_performance_tests
        else
            echo -e "${YELLOW}⚠️  Skipping performance tests due to build failure${NC}"
        fi
    elif [ "$REGRESSION_ONLY" = true ]; then
        if [ "$NO_BUILD" = false ]; then
            build_project
        fi
        if [ $EXIT_CODE -eq 0 ]; then
            run_regression_tests
        else
            echo -e "${YELLOW}⚠️  Skipping regression tests due to build failure${NC}"
        fi
    else
        # Run SwiftLint if not test-only
        if [ "$TEST_ONLY" = false ]; then
            run_swiftlint
        fi
        
        # Build and test if not lint-only
        if [ "$LINT_ONLY" = false ]; then
            build_project
            if [ $EXIT_CODE -eq 0 ]; then
                # Run regression tests first to catch immediate issues
                echo -e "${CYAN}Running regression prevention tests first...${NC}"
                run_regression_tests
                
                # Then run full test suite if regression tests pass
                if [ $EXIT_CODE -eq 0 ]; then
                    if [ "$PARALLEL" = true ]; then
                        run_tests_parallel
                    else
                        run_tests
                    fi
                else
                    echo -e "${YELLOW}⚠️  Skipping full test suite due to regression test failures${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  Skipping tests due to build failure${NC}"
            fi
        fi
    fi
    
    # Generate coverage report if requested
    generate_coverage_report
    
    # Generate summary
    generate_summary
    
    # Exit with appropriate code
    exit $EXIT_CODE
}

# Run main function
main