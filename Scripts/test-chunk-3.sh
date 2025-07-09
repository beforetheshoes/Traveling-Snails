#!/bin/bash
# Test Chunk 3: UI + Accessibility Tests (Debug Enhanced)
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

# Create debug output directory
DEBUG_DIR="$PROJECT_ROOT/debug-chunk3"
mkdir -p "$DEBUG_DIR"

printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}          Test Chunk 3: UI + Accessibility Tests${NC}\n"
if [ "$DEBUG_MODE" = "true" ]; then
    printf "${BLUE}                  (Debug Mode)${NC}\n"
fi
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${CYAN}Timestamp: %s${NC}\n" "$TIMESTAMP"
printf "${CYAN}Target: Complete in <90 seconds${NC}\n"
printf "${CYAN}Directory: %s${NC}\n" "$PROJECT_ROOT"
printf "${CYAN}Debug Output: %s${NC}\n" "$DEBUG_DIR"
if [ "$DEBUG_MODE" = "true" ]; then
    printf "${CYAN}Debug Mode: Enabled (streaming output + detailed analysis)${NC}\n"
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

# Capture current build settings for comparison
printf "${CYAN}Capturing build settings for debugging...${NC}\n"
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -showBuildSettings \
    -derivedDataPath "$DERIVED_DATA_PATH" > "$DEBUG_DIR/build-settings.txt" 2>&1
printf "${GREEN}✓ Build settings saved to debug folder${NC}\n\n"

# Run all tests for this chunk with debugging output
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}            Running UI + Accessibility Tests${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

# Test command that matches Xcode's execution exactly
XCRESULT_PATH="$PROJECT_ROOT/chunk3-test-results.xcresult"
rm -rf "$XCRESULT_PATH"

ui_test_command="xcodebuild test \
    -project \"$PROJECT_NAME.xcodeproj\" \
    -scheme \"$SCHEME_NAME\" \
    -destination \"$DESTINATION\" \
    -derivedDataPath \"$DERIVED_DATA_PATH\" \
    -resultBundlePath \"$XCRESULT_PATH\" \
    -only-testing:\"Traveling Snails Tests/UI Tests\" \
    -only-testing:\"Traveling Snails Tests/Accessibility Tests\""

# Run with timeout (90 seconds target)
if ! run_step_with_timeout "Running UI + Accessibility Tests" "$ui_test_command" 90 "$DEBUG_MODE"; then
    printf "${RED}❌ UI TESTS FAILED${NC}\n"
    exit 1
fi

# Summary
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}                  Chunk 3 Summary${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

total_duration=$(($(date +%s) - START_EPOCH))
printf "${CYAN}Chunk 3 Execution Summary${NC}\n"
printf "Start Time: %s\n" "$TIMESTAMP"
printf "End Time:   %s\n" "$(date +"%Y-%m-%d %H:%M:%S")"
printf "Duration:   %ds\n\n" "$total_duration"

if [ $total_duration -gt 90 ]; then
    printf "${YELLOW}⚠️  Chunk 3 took %ds (target: <90s)${NC}\n" "$total_duration"
    printf "${YELLOW}Consider optimizing test selection${NC}\n"
else
    printf "${GREEN}✓ Chunk 3 completed within target time${NC}\n"
fi

printf "${GREEN}╔═══════════════════════════════════════╗${NC}\n"
printf "${GREEN}║       CHUNK 3 PASSED! ✅             ║${NC}\n"
printf "${GREEN}║   UI + Accessibility Tests Complete  ║${NC}\n"
printf "${GREEN}╚═══════════════════════════════════════╝${NC}\n\n"
printf "${GREEN}Ready to proceed to Chunk 4 (Performance + Security Tests)${NC}\n"

exit 0