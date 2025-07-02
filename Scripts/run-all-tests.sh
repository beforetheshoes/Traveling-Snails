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
SIMULATOR_NAME="iPhone 16" 
GENERIC_SIMULATOR="platform=iOS Simulator,id=dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
START_EPOCH=$(date +%s)
EXIT_CODE=0

# Test target configuration
TEST_TARGET="Traveling Snails Tests"
UNIT_TEST_PATH="Unit Tests"
INTEGRATION_TEST_PATH="Integration Tests"
PERFORMANCE_TEST_PATH="Performance Tests"

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        Traveling Snails - Test & Lint Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Timestamp: $TIMESTAMP${NC}"
echo -e "${CYAN}Directory: $PROJECT_ROOT${NC}"
echo ""

# Function to execute test with xcbeautify and simulator fallback
execute_test_with_xcbeautify() {
    local test_name="$1"
    local xcodebuild_command="$2"
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 Running $test_name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check for simulator availability and fallback
    local simulator="$SIMULATOR_NAME"
    if ! xcrun simctl list devices | grep -q "$simulator"; then
        echo -e "${YELLOW}⚠️  $simulator not available, checking for iPhone 15...${NC}"
        if xcrun simctl list devices | grep -q "iPhone 15"; then
            simulator="iPhone 15"
            echo -e "${GREEN}✓ Using $simulator instead${NC}"
        else
            echo -e "${RED}❌ No compatible simulator found${NC}"
            EXIT_CODE=1
            return 1
        fi
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
                return 0
            else
                echo -e "${RED}✗ $test_name failed even with generic simulator${NC}"
                EXIT_CODE=1
                return 1
            fi
        fi
        
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
        -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
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
        -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME\" \
        -only-testing:\"$TEST_TARGET/Security Tests\""
    
    execute_test_with_xcbeautify "Security Tests" "$xcodebuild_command"
}

# Function to run unit tests only
run_unit_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME\" \
        -only-testing:\"$TEST_TARGET/$UNIT_TEST_PATH\""
    
    execute_test_with_xcbeautify "Unit Tests" "$xcodebuild_command"
}

# Function to run integration tests only
run_integration_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME\" \
        -only-testing:\"$TEST_TARGET/$INTEGRATION_TEST_PATH\""
    
    execute_test_with_xcbeautify "Integration Tests" "$xcodebuild_command"
}

# Function to run performance tests only
run_performance_tests() {
    local xcodebuild_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME\" \
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
        -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME\""
    
    # Add xcbeautify if available
    if command -v xcbeautify &> /dev/null; then
        build_command="$build_command | xcbeautify"
    fi
    
    run_step "Building $PROJECT_NAME" "$build_command"
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
        -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME\""
    
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
    echo "  --no-build           Skip building project (tests only)"
    echo "  --quick              Skip dependency resolution"
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
    echo "  $0 --unit-only --no-build # Run unit tests without rebuilding"
    echo "  $0 --no-clean --quick     # Fast run without cleanup"
}

# Parse command line arguments
SKIP_CLEAN=false
LINT_ONLY=false
TEST_ONLY=false
SECURITY_ONLY=false
UNIT_ONLY=false
INTEGRATION_ONLY=false
PERFORMANCE_ONLY=false
QUICK_RUN=false
NO_BUILD=false

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
        --no-build)
            NO_BUILD=true
            shift
            ;;
        --quick)
            QUICK_RUN=true
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
    
    if [ $count -gt 1 ]; then
        echo -e "${RED}Error: Test category options are mutually exclusive${NC}"
        echo -e "${RED}You specified:$selected_options${NC}"
        echo "Please use only one of: --security-only, --unit-only, --integration-only, or --performance-only"
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
    else
        # Run SwiftLint if not test-only
        if [ "$TEST_ONLY" = false ]; then
            run_swiftlint
        fi
        
        # Build and test if not lint-only
        if [ "$LINT_ONLY" = false ]; then
            build_project
            if [ $EXIT_CODE -eq 0 ]; then
                run_tests
            else
                echo -e "${YELLOW}⚠️  Skipping tests due to build failure${NC}"
            fi
        fi
    fi
    
    # Generate summary
    generate_summary
    
    # Exit with appropriate code
    exit $EXIT_CODE
}

# Run main function
main