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

# Build verification with warning analysis
echo -e "${CYAN}🔨 Comprehensive build verification...${NC}"

# Find available simulator
find_available_simulator() {
    local primary_sim="iPhone 15 Pro"
    local fallback_sim="iPhone 14 Pro"
    
    if xcrun simctl list devices | grep -q "$primary_sim"; then
        echo "$primary_sim"
        return 0
    fi
    
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
    
    echo "Any iOS Simulator Device"
    return 0
}

ACTUAL_SIMULATOR=$(find_available_simulator)

# Build project and capture warnings
BUILD_LOG=$(mktemp)
XCODEBUILD_CMD="xcodebuild build \
    -project \"Traveling Snails.xcodeproj\" \
    -scheme \"Traveling Snails\" \
    -destination \"platform=iOS Simulator,name=$ACTUAL_SIMULATOR\""

if ! eval "$XCODEBUILD_CMD" > "$BUILD_LOG" 2>&1; then
    echo -e "${RED}❌ Build failed during full pre-commit check${NC}"
    echo -e "${YELLOW}Build log (last 20 lines):${NC}"
    tail -20 "$BUILD_LOG"
    rm -f "$BUILD_LOG"
    exit 1
fi

# Check for critical warnings
CRITICAL_WARNINGS=$(grep -E "warning:.*unreachable code|warning:.*will never be executed" "$BUILD_LOG" || true)
if [ -n "$CRITICAL_WARNINGS" ]; then
    echo -e "${RED}❌ Critical code warnings detected:${NC}"
    echo "$CRITICAL_WARNINGS"
    rm -f "$BUILD_LOG"
    exit 1
fi

# Check for unused variable warnings
UNUSED_VAR_WARNINGS=$(grep -E "warning:.*initialization of.*was never used|warning:.*immutable value.*was never used" "$BUILD_LOG" || true)
if [ -n "$UNUSED_VAR_WARNINGS" ]; then
    echo -e "${RED}❌ Unused variable warnings detected:${NC}"
    echo "$UNUSED_VAR_WARNINGS"
    rm -f "$BUILD_LOG"
    exit 1
fi

rm -f "$BUILD_LOG"
echo -e "${GREEN}✅ Build verification passed!${NC}"

# Run comprehensive test suite using parallel execution
echo -e "${CYAN}🧪 Running comprehensive test suite with parallel execution...${NC}"

if ! "$SCRIPT_DIR/test-runner-parallel.sh" full; then
    echo -e "${RED}❌ Comprehensive test suite failed${NC}"
    echo -e "${YELLOW}   Check test logs in ./test-logs/ for detailed diagnosis${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Comprehensive test suite passed!${NC}"

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