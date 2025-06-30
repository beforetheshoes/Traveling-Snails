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
SIMULATOR_NAME="iPhone 16"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
EXIT_CODE=0

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        Traveling Snails - Test & Lint Suite${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Timestamp: $TIMESTAMP${NC}"
echo -e "${CYAN}Directory: $PROJECT_ROOT${NC}"
echo ""

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

# Function to run security tests only
run_security_tests() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 Running Security Tests${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local security_test_command="xcodebuild test \
        -project \"$PROJECT_NAME.xcodeproj\" \
        -scheme \"$SCHEME_NAME\" \
        -destination \"platform=iOS Simulator,name=$SIMULATOR_NAME\" \
        -only-testing:\"Traveling Snails Tests/LoggingSecurityTests\" \
        -only-testing:\"Traveling Snails Tests/CodebaseSecurityAuditTests\""
    
    # Add xcbeautify if available
    if command -v xcbeautify &> /dev/null; then
        security_test_command="$security_test_command | xcbeautify"
    else
        # Without xcbeautify, at least filter for test results
        security_test_command="$security_test_command 2>&1 | grep -E \"Test Suite|Test Case|passed|failed|error\""
    fi
    
    if eval "$security_test_command"; then
        echo -e "${GREEN}✓ All security tests passed!${NC}"
    else
        echo -e "${RED}✗ Some security tests failed${NC}"
        EXIT_CODE=1
    fi
    
    echo ""
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
    local total_duration=$(($(date +%s) - $(date -j -f "%Y-%m-%d %H:%M:%S" "$TIMESTAMP" +%s 2>/dev/null || date -d "$TIMESTAMP" +%s)))
    
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
    echo "  --no-clean       Skip cleaning derived data"
    echo "  --lint-only      Run only SwiftLint checks"
    echo "  --test-only      Run only tests (no linting)"
    echo "  --security-only  Run only security tests"
    echo "  --quick          Skip dependency resolution"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all checks"
    echo "  $0 --lint-only        # Run only SwiftLint"
    echo "  $0 --test-only        # Run only tests"
    echo "  $0 --security-only    # Run only security tests"
    echo "  $0 --no-clean --quick # Fast run without cleanup"
}

# Parse command line arguments
SKIP_CLEAN=false
LINT_ONLY=false
TEST_ONLY=false
SECURITY_ONLY=false
QUICK_RUN=false

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

# Main execution
main() {
    # Check dependencies first
    check_dependencies
    
    # Clean if not skipped
    if [ "$SKIP_CLEAN" = false ] && [ "$QUICK_RUN" = false ]; then
        clean_derived_data
    fi
    
    # Resolve dependencies if not quick run
    if [ "$QUICK_RUN" = false ]; then
        resolve_dependencies
    fi
    
    # Handle security-only mode
    if [ "$SECURITY_ONLY" = true ]; then
        build_project
        if [ $EXIT_CODE -eq 0 ]; then
            run_security_tests
        else
            echo -e "${YELLOW}⚠️  Skipping security tests due to build failure${NC}"
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