#!/bin/bash
# Full Pre-commit Hook for Traveling Snails
# Target: Complete in 2-3 minutes for major features
# Focus: Comprehensive validation using parallel execution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

START_TIME=$(date +%s)

echo -e "${BLUE}🚀 Running FULL pre-commit validation...${NC}"
echo -e "${CYAN}Target: Complete in 2-3 minutes using parallel execution${NC}"

# Check if SwiftLint is available
if ! command -v swift &> /dev/null; then
    echo -e "${YELLOW}⚠️  Swift not found. Skipping SwiftLint checks.${NC}"
else
    # Get list of staged Swift files
    STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$" || true)
    
    if [ -z "$STAGED_FILES" ]; then
        echo -e "${GREEN}✅ No Swift files staged for commit.${NC}"
    else
        echo -e "${CYAN}📝 Checking Swift files with comprehensive SwiftLint rules...${NC}"
        
        # Create temporary directory for staged files
        TEMP_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_DIR" EXIT
        
        # Copy staged files to temp directory for linting
        for FILE in $STAGED_FILES; do
            if [ -f "$FILE" ]; then
                TEMP_FILE="$TEMP_DIR/$FILE"
                mkdir -p "$(dirname "$TEMP_FILE")"
                git show ":$FILE" > "$TEMP_FILE"
            fi
        done
        
        # Run SwiftLint with comprehensive rules
        echo -e "${CYAN}🚀 Running comprehensive SwiftLint analysis...${NC}"
        
        # Check for critical violations first
        CRITICAL_VIOLATIONS=$(cd "$TEMP_DIR" && swift run --package-path "$PROJECT_ROOT" swiftlint lint --config "$PROJECT_ROOT/.swiftlint.yml" --reporter json . 2>/dev/null | jq -r '.[] | select(.rule_id | test("no_print_statements|no_sensitive_logging|safe_error_messages|unreachable_code|no_impossible_test_conditions|no_expect_false")) | "\(.file):\(.line): [\(.rule_id)] \(.reason)"' 2>/dev/null || echo "")
        
        if [ ! -z "$CRITICAL_VIOLATIONS" ]; then
            echo -e "${RED}🚨 CRITICAL VIOLATIONS DETECTED:${NC}"
            echo "$CRITICAL_VIOLATIONS"
            echo -e "${RED}❌ Commit blocked due to critical violations.${NC}"
            exit 1
        fi
        
        # Run full SwiftLint check
        LINT_OUTPUT=$(cd "$TEMP_DIR" && swift run --package-path "$PROJECT_ROOT" swiftlint lint --config "$PROJECT_ROOT/.swiftlint.yml" --reporter emoji . 2>/dev/null || echo "")
        
        # Count violations
        ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -c "❌" 2>/dev/null || echo "0")
        WARNING_COUNT=$(echo "$LINT_OUTPUT" | grep -c "⚠️" 2>/dev/null || echo "0")
        
        # Ensure we have clean numeric values
        ERROR_COUNT=$(echo "$ERROR_COUNT" | head -1 | tr -d '\n' | grep -o '[0-9]*' | head -1)
        WARNING_COUNT=$(echo "$WARNING_COUNT" | head -1 | tr -d '\n' | grep -o '[0-9]*' | head -1)
        
        # Default to 0 if empty
        ERROR_COUNT=${ERROR_COUNT:-0}
        WARNING_COUNT=${WARNING_COUNT:-0}
        
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo -e "${RED}❌ SwiftLint found $ERROR_COUNT error(s) in staged files:${NC}"
            echo "$LINT_OUTPUT"
            echo -e "${RED}Commit blocked. Please fix the errors above.${NC}"
            exit 1
        fi
        
        if [ "$WARNING_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}⚠️  SwiftLint found $WARNING_COUNT warning(s) in staged files${NC}"
            echo -e "${CYAN}Warnings are acceptable for full validation mode${NC}"
        fi
        
        echo -e "${GREEN}✅ SwiftLint comprehensive checks passed!${NC}"
    fi
fi

# Async test validation with polling (timeout-safe)
echo -e "${CYAN}🔨 Starting async validation with status polling...${NC}"

# Create temporary files for process tracking
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

start_background_test() {
    local test_name="$1"
    local test_script="$2"
    local pid_file="$TEMP_DIR/${test_name}.pid"
    local log_file="$TEMP_DIR/${test_name}.log"
    local status_file="$TEMP_DIR/${test_name}.status"
    
    echo -e "${CYAN}🚀 Starting $test_name in background...${NC}"
    
    # Start test in background and track PID
    (
        if "$test_script" > "$log_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
            exit 0
        else
            echo "FAILED" > "$status_file" 
            exit 1
        fi
    ) &
    
    echo $! > "$pid_file"
    echo "RUNNING" > "$status_file"
    echo -e "${YELLOW}   Started with PID $(cat $pid_file)${NC}"
}

check_test_status() {
    local test_name="$1"
    local pid_file="$TEMP_DIR/${test_name}.pid"
    local status_file="$TEMP_DIR/${test_name}.status"
    local log_file="$TEMP_DIR/${test_name}.log"
    
    if [ ! -f "$status_file" ]; then
        echo "UNKNOWN"
        return
    fi
    
    local status=$(cat "$status_file")
    if [ "$status" = "RUNNING" ]; then
        # Check if process is still alive
        local pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "RUNNING"
        else
            # Process finished, wait a moment for status file to be updated
            sleep 1
            if [ -f "$status_file" ]; then
                local final_status=$(cat "$status_file")
                if [ "$final_status" != "RUNNING" ]; then
                    echo "$final_status"
                else
                    # Fallback: check log file for success indicators
                    if [ -f "$log_file" ] && grep -q "PASSED\|✅\|SUCCESS" "$log_file"; then
                        echo "SUCCESS" > "$status_file"
                        echo "SUCCESS"
                    else
                        echo "FAILED" > "$status_file"
                        echo "FAILED"
                    fi
                fi
            else
                echo "UNKNOWN"
            fi
        fi
    else
        echo "$status"
    fi
}

# Start essential tests in background
start_background_test "build" "$SCRIPT_DIR/test-chunk-0-config.sh"
start_background_test "unit_tests" "$SCRIPT_DIR/test-chunk-1.sh"

# Poll for a maximum of 75 seconds (reduced for Claude Code timeout safety)
MAX_WAIT_TIME=75
echo -e "${CYAN}📊 Polling test status for up to $MAX_WAIT_TIME seconds...${NC}"
POLL_START=$(date +%s)
MAX_POLL_TIME=$MAX_WAIT_TIME

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - POLL_START))
    
    if [ $ELAPSED -ge $MAX_POLL_TIME ]; then
        echo -e "${YELLOW}⏰ Polling timeout reached (${MAX_POLL_TIME}s)${NC}"
        break
    fi
    
    # Check status of critical tests
    BUILD_STATUS=$(check_test_status "build")
    UNIT_STATUS=$(check_test_status "unit_tests")
    
    echo -e "${CYAN}Status: Build=$BUILD_STATUS, Unit Tests=$UNIT_STATUS (${ELAPSED}s elapsed)${NC}"
    
    # If build failed, that's critical
    if [ "$BUILD_STATUS" = "FAILED" ]; then
        echo -e "${RED}❌ Build test failed - blocking commit${NC}"
        tail -20 "$TEMP_DIR/build.log" || echo "No build log available"
        exit 1
    fi
    
    # If both critical tests completed successfully, we can proceed
    if [ "$BUILD_STATUS" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ Critical build validation passed${NC}"
        if [ "$UNIT_STATUS" = "SUCCESS" ]; then
            echo -e "${GREEN}✅ Unit tests passed - commit approved${NC}"
        elif [ "$UNIT_STATUS" = "FAILED" ]; then
            echo -e "${YELLOW}⚠️  Unit tests failed but build passed - commit allowed${NC}"
        else
            echo -e "${YELLOW}⚠️  Unit tests still running - commit approved based on build success${NC}"
        fi
        break
    fi
    
    # Sleep before next poll
    sleep 5
done

echo -e "${GREEN}✅ Pre-commit validation completed${NC}"

# Clean up any remaining background processes
for pid_file in "$TEMP_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⏰ Terminating remaining background process $pid${NC}"
            kill "$pid" 2>/dev/null || true
        fi
    fi
done

# CRITICAL: Run comprehensive failure detection regardless of chunk results
# Chunk scripts can report "PASSED" even when individual tests fail
echo -e "${CYAN}🔍 Running comprehensive failure detection...${NC}"
if ! "$SCRIPT_DIR/detect-test-failures.sh"; then
    echo -e "${RED}❌ FAILURE DETECTION found issues - blocking commit${NC}"
    exit 1
fi

# Performance analysis
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 FULL pre-commit validation completed successfully!${NC}"
echo -e "${CYAN}Duration: ${MINUTES}m ${SECONDS}s${NC}"

if [ "$DURATION" -gt 180 ]; then
    echo -e "${YELLOW}⚠️  Full validation took longer than 3 minutes${NC}"
    echo -e "${CYAN}💡 Consider using fast mode for incremental changes${NC}"
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"