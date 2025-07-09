#!/bin/bash
# Test Chunk 1: Unit Tests Only  
# Target: Complete in under 90 seconds
# Requires: Chunk 0 (Setup + Build) must have completed

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
printf "${BLUE}               Test Chunk 1: Unit Tests${NC}\n"
if [ "$DEBUG_MODE" = "true" ]; then
    printf "${BLUE}                  (Debug Mode)${NC}\n"
fi
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${CYAN}Timestamp: %s${NC}\n" "$TIMESTAMP"
printf "${CYAN}Target: Complete in <90 seconds${NC}\n"
printf "${CYAN}Directory: %s${NC}\n" "$PROJECT_ROOT"
printf "${CYAN}Simulator: %s (ID: %s)${NC}\n" "$SIMULATOR_NAME" "$SIMULATOR_ID"
if [ "$DEBUG_MODE" = "true" ]; then
    printf "${CYAN}Debug Mode: Enabled (showing all output)${NC}\n"
fi
printf "\n"

# Change to project root
cd "$PROJECT_ROOT"

# Verify build exists (Chunk 0 dependency)
printf "${CYAN}Verifying build state from Chunk 0...${NC}\n"
if [ ! -d "$DERIVED_DATA_PATH" ]; then
    printf "${RED}❌ Build artifacts not found - Run Chunk 0 first${NC}\n"
    printf "${YELLOW}Run: ./Scripts/test-chunk-0-config.sh${NC}\n"
    exit 1
fi
printf "${GREEN}✓ Build state verified${NC}\n\n"

# Check simulator availability (should already be running from Chunk 0)
if ! check_simulator; then
    printf "${RED}❌ Cannot proceed without valid simulator${NC}\n"
    exit 1
fi

# Ensure simulator is running (may need to re-boot if chunks run separately)
boot_simulator

# Run Unit Tests
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}                    Unit Tests${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

# Build test command to match Xcode exactly
unit_test_command="xcodebuild test \
    -project \"$PROJECT_NAME.xcodeproj\" \
    -scheme \"$SCHEME_NAME\" \
    -destination \"$DESTINATION\" \
    -derivedDataPath \"$DERIVED_DATA_PATH\" \
    -only-testing:\"Traveling Snails Tests/MinimalTest\" \
    -only-testing:\"Traveling Snails Tests/SimpleTestInfrastructureTest\" \
    -only-testing:\"Traveling Snails Tests/NotificationNamesTests\""

# Run with timeout (110 seconds to let tests complete and show failures)
if ! run_step_with_timeout "Running Unit Tests" "$unit_test_command" 110 "$DEBUG_MODE"; then
    printf "${RED}❌ UNIT TESTS FAILED${NC}\n"
    exit 1
fi

# Summary
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}                  Chunk 1 Summary${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

total_duration=$(($(date +%s) - START_EPOCH))
printf "${CYAN}Chunk 1 Execution Summary${NC}\n"
printf "Start Time: %s\n" "$TIMESTAMP"
printf "End Time:   %s\n" "$(date +"%Y-%m-%d %H:%M:%S")"
printf "Duration:   %ds\n\n" "$total_duration"

if [ $total_duration -gt 90 ]; then
    printf "${YELLOW}⚠️  Chunk 1 took %ds (target: <90s)${NC}\n" "$total_duration"
    printf "${YELLOW}Consider optimizing build or test selection${NC}\n"
else
    printf "${GREEN}✓ Chunk 1 completed within target time${NC}\n"
fi

printf "${GREEN}╔═══════════════════════════════════════╗${NC}\n"
printf "${GREEN}║       CHUNK 1 PASSED! ✅             ║${NC}\n"
printf "${GREEN}║      Unit Tests Complete             ║${NC}\n"
printf "${GREEN}╚═══════════════════════════════════════╝${NC}\n\n"
printf "${GREEN}Ready to proceed to Chunk 2 (Integration + SwiftData Tests)${NC}\n"

# Keep simulator running for next chunks
exit 0