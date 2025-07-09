#!/bin/bash
# Test Chunk 4: Performance + Security Tests
# Target: Complete in under 90 seconds
# Requires: Chunk 1 (Build) must have passed

set -e

# Source shared configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/test-chunk-0-config.sh"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
START_EPOCH=$(date +%s)

printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}        Test Chunk 4: Performance + Security Tests${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${CYAN}Timestamp: %s${NC}\n" "$TIMESTAMP"
printf "${CYAN}Target: Complete in <90 seconds${NC}\n"
printf "${CYAN}Directory: %s${NC}\n" "$PROJECT_ROOT"
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
printf "${BLUE}         Running Performance + Security Tests${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

# Combined test command for all tests in this chunk
# Performance tests may need exclusive access, so we use fewer parallel destinations
combined_test_command="xcodebuild test \
    -project \"$PROJECT_NAME.xcodeproj\" \
    -scheme \"$SCHEME_NAME\" \
    -destination \"$DESTINATION\" \
    -derivedDataPath \"$DERIVED_DATA_PATH\" \
    -only-testing:\"Traveling Snails Tests/Performance Tests\" \
    -only-testing:\"Traveling Snails Tests/Security Tests\" \
    -only-testing:\"Traveling Snails Tests/Stress Tests\" \
    -disable-concurrent-destination-testing \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    CODE_SIGN_ENTITLEMENTS= \
    EXPANDED_CODE_SIGN_IDENTITY= \
    PROVISIONING_PROFILE_SPECIFIER= \
    PROVISIONING_PROFILE= \
    DEVELOPMENT_TEAM= \
    COMPILER_INDEX_STORE_ENABLE=NO"

if ! run_step_with_timeout "Running Performance, Security, and Stress Tests" "$combined_test_command" 180; then
    printf "${RED}❌ TESTS FAILED${NC}\n"
    exit 1
fi

# Summary
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}                  Chunk 4 Summary${NC}\n"
printf "${BLUE}═══════════════════════════════════════════════════════════${NC}\n\n"

total_duration=$(($(date +%s) - START_EPOCH))
printf "${CYAN}Chunk 4 Execution Summary${NC}\n"
printf "Start Time: %s\n" "$TIMESTAMP"
printf "End Time:   %s\n" "$(date +"%Y-%m-%d %H:%M:%S")"
printf "Duration:   %ds\n\n" "$total_duration"

if [ $total_duration -gt 90 ]; then
    printf "${YELLOW}⚠️  Chunk 4 took %ds (target: <90s)${NC}\n" "$total_duration"
    printf "${YELLOW}Performance tests may need optimization${NC}\n"
else
    printf "${GREEN}✓ Chunk 4 completed within target time${NC}\n"
fi

printf "${GREEN}╔═══════════════════════════════════════╗${NC}\n"
printf "${GREEN}║       CHUNK 4 PASSED! ✅             ║${NC}\n"
printf "${GREEN}║   Performance + Security Complete    ║${NC}\n"
printf "${GREEN}╚═══════════════════════════════════════╝${NC}\n\n"
printf "${GREEN}Ready to proceed to Chunk 5 (SwiftLint Analysis)${NC}\n"

# Cleanup simulator if this is the last testing chunk
cleanup_simulator

exit 0