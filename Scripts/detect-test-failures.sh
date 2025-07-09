#!/bin/bash

# Advanced Test Failure Detection Script
# Detects Swift Testing failures, SwiftLint issues, and accessibility test failures
# Based on research from xcresult-issues, SwiftLint validation, and accessibility testing patterns

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Results tracking
TOTAL_FAILURES=0
SWIFTLINT_FAILURES=0
ACCESSIBILITY_FAILURES=0
MISSING_FILES=0

echo "🔍 Advanced Test Failure Detection"
echo "=================================="

# Function to check if a file exists
check_file_exists() {
    local file_path="$1"
    local description="$2"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}❌ MISSING FILE: $description${NC}"
        echo "   Expected: $file_path"
        ((MISSING_FILES++))
        ((TOTAL_FAILURES++))
        return 1
    else
        echo -e "${GREEN}✅ Found: $description${NC}"
        return 0
    fi
}

# Function to parse xcresult files for Swift Testing failures
parse_xcresult_failures() {
    local xcresult_file="$1"
    
    if [ ! -d "$xcresult_file" ]; then
        return 0
    fi
    
    echo "🔍 Parsing: $xcresult_file"
    
    # Parse test failures using xcresulttool
    if command -v xcrun >/dev/null 2>&1; then
        local failures
        failures=$(xcrun xcresulttool get --legacy --format json --path "$xcresult_file" 2>/dev/null | \
                  jq -r '.issues.testFailureSummaries._values[]? | "\(.documentLocationInCreatingWorkspace.url._value):\(.documentLocationInCreatingWorkspace.concreteLocation.line._value) \(.testCaseName._value): \(.message._value)"' 2>/dev/null || echo "")
        
        if [ -n "$failures" ]; then
            echo -e "${RED}❌ TEST FAILURES FOUND:${NC}"
            echo "$failures"
            local failure_count
            failure_count=$(echo "$failures" | wc -l)
            ((TOTAL_FAILURES += failure_count))
            return 1
        else
            echo -e "${GREEN}✅ No test failures in $xcresult_file${NC}"
            return 0
        fi
    else
        echo -e "${YELLOW}⚠️ xcrun not available - cannot parse xcresult files${NC}"
        return 0
    fi
}

# Check SwiftLint Configuration
echo ""
echo "🔧 Checking SwiftLint Configuration"
echo "--------------------------------"

check_file_exists ".swiftlint.yml" "SwiftLint configuration"
check_file_exists "Scripts/setup-swiftlint.sh" "SwiftLint setup script"

# Validate SwiftLint configuration if available
if command -v swiftlint >/dev/null 2>&1; then
    echo "🔍 Validating SwiftLint configuration..."
    if swiftlint --config .swiftlint.yml --quiet 2>/dev/null; then
        echo -e "${GREEN}✅ SwiftLint configuration valid${NC}"
    else
        echo -e "${RED}❌ SwiftLint configuration has issues${NC}"
        ((SWIFTLINT_FAILURES++))
        ((TOTAL_FAILURES++))
    fi
else
    echo -e "${YELLOW}⚠️ SwiftLint not installed${NC}"
fi

# Check for SwiftLint JSON output files
echo ""
echo "🔍 Checking SwiftLint JSON outputs"
echo "--------------------------------"

for swiftlint_json in test-swiftlint.json swiftlint-output.json .swiftlint-results.json; do
    if [ -f "$swiftlint_json" ]; then
        echo "🔍 Parsing: $swiftlint_json"
        if command -v jq >/dev/null 2>&1; then
            local lint_errors
            lint_errors=$(jq -r '.[] | select(.severity == "error") | "\(.file):\(.line) \(.rule) - \(.reason)"' "$swiftlint_json" 2>/dev/null || echo "")
            
            if [ -n "$lint_errors" ]; then
                echo -e "${RED}❌ SWIFTLINT ERRORS FOUND:${NC}"
                echo "$lint_errors"
                local error_count
                error_count=$(echo "$lint_errors" | wc -l)
                ((SWIFTLINT_FAILURES += error_count))
                ((TOTAL_FAILURES += error_count))
            else
                echo -e "${GREEN}✅ No SwiftLint errors in $swiftlint_json${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ jq not available - cannot parse SwiftLint JSON${NC}"
        fi
    fi
done

# Check Accessibility Test Patterns
echo ""
echo "♿ Checking Accessibility Test Patterns"
echo "------------------------------------"

# Look for accessibility test failures in xcresult files
accessibility_test_found=false
for xcresult_dir in $(find . -name "*.xcresult" -type d 2>/dev/null); do
    if [ -d "$xcresult_dir" ]; then
        accessibility_test_found=true
        echo "🔍 Checking accessibility in: $xcresult_dir"
        
        # Check for accessibility-specific failures
        if command -v xcrun >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
            accessibility_failures=$(xcrun xcresulttool get --legacy --format json --path "$xcresult_dir" 2>/dev/null | \
                                   jq -r '.issues.testFailureSummaries._values[]? | select(.testCaseName._value | contains("Accessibility") or contains("VoiceOver") or contains("accessibility")) | "\(.documentLocationInCreatingWorkspace.url._value):\(.documentLocationInCreatingWorkspace.concreteLocation.line._value) \(.testCaseName._value): \(.message._value)"' 2>/dev/null || echo "")
            
            if [ -n "$accessibility_failures" ]; then
                echo -e "${RED}❌ ACCESSIBILITY TEST FAILURES:${NC}"
                echo "$accessibility_failures"
                local acc_failure_count
                acc_failure_count=$(echo "$accessibility_failures" | wc -l)
                ((ACCESSIBILITY_FAILURES += acc_failure_count))
                ((TOTAL_FAILURES += acc_failure_count))
            fi
        fi
    fi
done

if [ "$accessibility_test_found" = false ]; then
    echo -e "${YELLOW}⚠️ No xcresult files found for accessibility analysis${NC}"
fi

# Detect Swift Testing Failures
echo ""
echo "🧪 Detecting Swift Testing Failures"
echo "--------------------------------"

# Find and parse all xcresult files
xcresult_found=false
for xcresult_dir in $(find . -name "*.xcresult" -type d 2>/dev/null); do
    if [ -d "$xcresult_dir" ]; then
        xcresult_found=true
        parse_xcresult_failures "$xcresult_dir"
    fi
done

if [ "$xcresult_found" = false ]; then
    echo -e "${YELLOW}⚠️ No xcresult files found${NC}"
    echo "   Run tests first to generate xcresult files for analysis"
fi

# Summary
echo ""
echo "📊 Detection Summary"
echo "==================="
echo "Total Failures Detected: $TOTAL_FAILURES"
echo "SwiftLint Issues: $SWIFTLINT_FAILURES"
echo "Accessibility Failures: $ACCESSIBILITY_FAILURES"
echo "Missing Files: $MISSING_FILES"

if [ $TOTAL_FAILURES -eq 0 ]; then
    echo -e "${GREEN}🎉 No failures detected!${NC}"
    exit 0
else
    echo -e "${RED}❌ $TOTAL_FAILURES total failures require attention${NC}"
    exit 1
fi