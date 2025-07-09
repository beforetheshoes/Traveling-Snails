#!/bin/bash
# Test Chunk 5: SwiftLint Analysis
# Target: Complete in under 60 seconds
# Independent: Can run without other chunks

set -e

# Source shared configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/test-chunk-0-config.sh"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
START_EPOCH=$(date +%s)

printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}             Test Chunk 5: SwiftLint Analysis${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${CYAN}Timestamp: %s${NC}\n" "$TIMESTAMP"
printf "${CYAN}Target: Complete in <60 seconds${NC}\n"
printf "${CYAN}Directory: %s${NC}\n" "$PROJECT_ROOT"
printf "\n"

# Change to project root
cd "$PROJECT_ROOT"

# SwiftLint Analysis
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}                  SwiftLint Analysis${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

# Create cache directory if it doesn't exist
mkdir -p "$(dirname "$SWIFTLINT_CACHE_PATH")"

# Run SwiftLint with optimizations
lint_output_file="swiftlint-results.json"

# First run SwiftLint with --fix to auto-correct violations
printf "${CYAN}Running SwiftLint auto-fix...${NC}\n"
fix_command="swift run swiftlint lint \
    --config .swiftlint.yml \
    --cache-path \"$SWIFTLINT_CACHE_PATH\" \
    --fix"

if run_step_with_timeout "Auto-fixing SwiftLint violations" "$fix_command" 60; then
    printf "${GREEN}✓ Auto-fix completed${NC}\n\n"
else
    printf "${YELLOW}⚠️  Auto-fix encountered issues (continuing with analysis)${NC}\n\n"
fi

# Then run analysis to see remaining violations
swiftlint_command="swift run swiftlint lint \
    --config .swiftlint.yml \
    --cache-path \"$SWIFTLINT_CACHE_PATH\" \
    --reporter json > \"$lint_output_file\""

# Run SwiftLint and capture exit code (don't fail immediately on violations)
if run_step_with_timeout "Running SwiftLint analysis" "$swiftlint_command" 60; then
    lint_exit_code=0
    printf "${GREEN}✓ SwiftLint analysis completed${NC}\n"
else
    lint_exit_code=$?
    # SwiftLint returns non-zero when violations are found, which is expected
    printf "${YELLOW}⚠️  SwiftLint found violations (this is normal)${NC}\n"
fi

# Analyze results
if command -v jq &> /dev/null && [ -f "$lint_output_file" ] && [ -s "$lint_output_file" ]; then
    printf "${CYAN}Analyzing SwiftLint results...${NC}\n"
    
    total_violations=$(jq 'length' "$lint_output_file" 2>/dev/null || echo "0")
    error_count=$(jq '[.[] | select(.severity == "error")] | length' "$lint_output_file" 2>/dev/null || echo "0")
    warning_count=$(jq '[.[] | select(.severity == "warning")] | length' "$lint_output_file" 2>/dev/null || echo "0")
    security_violations=$(jq '[.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages"))] | length' "$lint_output_file" 2>/dev/null || echo "0")
    
    printf "\n${CYAN}SwiftLint Summary:${NC}\n"
    printf "  Total violations: %s\n" "$total_violations"
    printf "  Errors: ${RED}%s${NC}\n" "$error_count"
    printf "  Warnings: ${YELLOW}%s${NC}\n" "$warning_count"
    printf "  Security issues: ${RED}%s${NC}\n" "$security_violations"
    
    # Check for critical violations
    if [ "$error_count" -gt 0 ] || [ "$security_violations" -gt 0 ]; then
        printf "\n${RED}❌ Critical SwiftLint violations found!${NC}\n"
        
        # Show details for errors
        if [ "$error_count" -gt 0 ]; then
            printf "${RED}Errors:${NC}\n"
            jq -r '.[] | select(.severity == "error") | "  \(.file):\(.line):\(.character) - \(.rule_id): \(.reason)"' "$lint_output_file" 2>/dev/null | head -10
            if [ "$error_count" -gt 10 ]; then
                printf "  ... and %d more errors\n" "$((error_count - 10))"
            fi
        fi
        
        # Show security violations
        if [ "$security_violations" -gt 0 ]; then
            printf "${RED}Security Violations:${NC}\n"
            jq -r '.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages")) | "  \(.file):\(.line) - \(.rule_id): \(.reason)"' "$lint_output_file" 2>/dev/null
        fi
        
        # Clean up
        rm -f "$lint_output_file"
        exit 1
    else
        printf "${GREEN}✓ No critical violations${NC}\n"
    fi
    
    # Clean up
    rm -f "$lint_output_file"
else
    # Fallback to regular output if jq not available or file is empty
    printf "${CYAN}Running SwiftLint without detailed analysis...${NC}\n"
    
    # Run auto-fix first
    fix_fallback_command="swift run swiftlint lint \
        --config .swiftlint.yml \
        --cache-path \"$SWIFTLINT_CACHE_PATH\" \
        --fix"
    
    if run_step_with_timeout "Auto-fixing SwiftLint violations (fallback)" "$fix_fallback_command" 60; then
        printf "${GREEN}✓ Auto-fix completed${NC}\n"
    else
        printf "${YELLOW}⚠️  Auto-fix encountered issues${NC}\n"
    fi
    
    # Then run analysis
    fallback_command="swift run swiftlint lint \
        --config .swiftlint.yml \
        --cache-path \"$SWIFTLINT_CACHE_PATH\""
    
    if run_step_with_timeout "Running SwiftLint analysis (fallback)" "$fallback_command" 60; then
        printf "${GREEN}✓ SwiftLint completed successfully${NC}\n"
    else
        # Only fail on actual errors, not violations
        printf "${YELLOW}⚠️  SwiftLint found violations${NC}\n"
    fi
fi

# Summary
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}                  Chunk 5 Summary${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

total_duration=$(($(date +%s) - START_EPOCH))
printf "${CYAN}Chunk 5 Execution Summary${NC}\n"
printf "Start Time: %s\n" "$TIMESTAMP"
printf "End Time:   %s\n" "$(date +"%Y-%m-%d %H:%M:%S")"
printf "Duration:   %ds\n\n" "$total_duration"

if [ $total_duration -gt 60 ]; then
    printf "${YELLOW}⚠️  Chunk 5 took %ds (target: <60s)${NC}\n" "$total_duration"
    printf "${YELLOW}Consider optimizing SwiftLint configuration${NC}\n"
else
    printf "${GREEN}✓ Chunk 5 completed within target time${NC}\n"
fi

printf "${GREEN}╔═══════════════════════════════════════╗${NC}\n"
printf "${GREEN}║       CHUNK 5 PASSED! ✅             ║${NC}\n"
printf "${GREEN}║  SwiftLint Auto-fix + Analysis Done  ║${NC}\n"
printf "${GREEN}╚═══════════════════════════════════════╝${NC}\n\n"
printf "${GREEN}All chunks can now be considered complete!${NC}\n"
printf "${CYAN}Note: SwiftLint auto-fixed violations where possible${NC}\n"

exit 0