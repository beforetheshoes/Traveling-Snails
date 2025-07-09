#!/bin/bash
# Test Chunk 2: Integration + SwiftData Tests
# Target: Complete in under 90 seconds
# Requires: Chunk 1 (Build) must have passed

set -e

# Source shared configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/test-chunk-0-config.sh"

# Process arguments for debug mode
DEBUG_MODE="false"
for arg in "$@"; do
    case "$arg" in
        "debug"|"--debug")
            DEBUG_MODE="true"
            ;;
    esac
done

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
START_EPOCH=$(date +%s)

printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}        Test Chunk 2: Integration + SwiftData Tests${NC}\n"
if [ "$DEBUG_MODE" = "true" ]; then
    printf "${BLUE}                  (Debug Mode)${NC}\n"
fi
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${CYAN}Timestamp: %s${NC}\n" "$TIMESTAMP"
printf "${CYAN}Target: Complete in <90 seconds${NC}\n"
printf "${CYAN}Directory: %s${NC}\n" "$PROJECT_ROOT"
if [ "$DEBUG_MODE" = "true" ]; then
    printf "${CYAN}Debug Mode: Enabled (showing all output)${NC}\n"
fi
printf "\n"

# Change to project root
cd "$PROJECT_ROOT"

# Verify build exists (Chunk 1 dependency)
printf "${CYAN}Verifying build state from Chunk 1...${NC}\n"
if [ ! -d "$DERIVED_DATA_PATH" ]; then
    printf "${RED}❌ Build artifacts not found - Run Chunk 1 first${NC}\n"
    exit 1
fi
printf "${GREEN}✓ Build state verified${NC}\n\n"

# Check simulator availability
if ! check_simulator; then
    printf "${RED}❌ Cannot proceed without valid simulator${NC}\n"
    exit 1
fi

# Ensure simulator is running
boot_simulator

# Run all tests for this chunk in parallel
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}         Running Integration + SwiftData Tests${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

# Combined test command to match Xcode exactly
combined_test_command="xcodebuild test \
    -project \"$PROJECT_NAME.xcodeproj\" \
    -scheme \"$SCHEME_NAME\" \
    -destination \"$DESTINATION\" \
    -derivedDataPath \"$DERIVED_DATA_PATH\" \
    -only-testing:\"Traveling Snails Tests/Integration Tests\" \
    -only-testing:\"Traveling Snails Tests/SwiftData Tests\" \
    -only-testing:\"Traveling Snails Tests/Settings Tests\""

if ! run_step_with_timeout "Running Integration, SwiftData, and Settings Tests" "$combined_test_command" "$TEST_TIMEOUT" "$DEBUG_MODE"; then
    printf "${RED}❌ TESTS FAILED${NC}\n"
    exit 1
fi

# Summary
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}                  Chunk 2 Summary${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

total_duration=$(($(date +%s) - START_EPOCH))
printf "${CYAN}Chunk 2 Execution Summary${NC}\n"
printf "Start Time: %s\n" "$TIMESTAMP"
printf "End Time:   %s\n" "$(date +"%Y-%m-%d %H:%M:%S")"
printf "Duration:   %ds\n\n" "$total_duration"

if [ $total_duration -gt 90 ]; then
    printf "${YELLOW}⚠️  Chunk 2 took %ds (target: <90s)${NC}\n" "$total_duration"
    printf "${YELLOW}Consider optimizing test selection or parallel execution${NC}\n"
else
    printf "${GREEN}✓ Chunk 2 completed within target time${NC}\n"
fi

printf "${GREEN}╔═══════════════════════════════════════╗${NC}\n"
printf "${GREEN}║       CHUNK 2 PASSED! ✅             ║${NC}\n"
printf "${GREEN}║  Integration + SwiftData Complete    ║${NC}\n"
printf "${GREEN}╚═══════════════════════════════════════╝${NC}\n\n"
printf "${GREEN}Ready to proceed to Chunk 3 (UI + Accessibility Tests)${NC}\n"

exit 0