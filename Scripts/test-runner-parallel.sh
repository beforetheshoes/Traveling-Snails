#!/bin/bash
# Parallel Test Runner for Traveling Snails
# Runs test chunks in parallel to reduce overall execution time

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
SCRIPT_DIR="$(dirname "$0")"
cd "$PROJECT_ROOT"

# Logging setup
LOG_DIR="$PROJECT_ROOT/test-logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Global arrays for tracking
declare -a parallel_pids=()
declare -a parallel_chunks=()
declare -a parallel_results=()

# Function to run chunk with logging
run_chunk_parallel() {
    local chunk_script="$1"
    local chunk_name="$2"
    local log_file="$LOG_DIR/${chunk_name}_${TIMESTAMP}.log"
    
    echo -e "${CYAN}🚀 Starting $chunk_name in parallel...${NC}"
    
    # Run chunk and capture exit code
    {
        echo "=== $chunk_name execution started at $(date) ==="
        if "$chunk_script" > "$log_file" 2>&1; then
            echo "SUCCESS" > "$log_file.status"
            echo "=== $chunk_name completed successfully at $(date) ==="
        else
            echo "FAILED" > "$log_file.status"
            echo "=== $chunk_name FAILED at $(date) ==="
        fi
    } &
    
    local pid=$!
    parallel_pids+=($pid)
    parallel_chunks+=("$chunk_name")
}

# Function to wait for all parallel processes
wait_for_parallel_completion() {
    local all_success=true
    
    echo -e "${BLUE}⏳ Waiting for parallel test execution...${NC}"
    
    for i in "${!parallel_pids[@]}"; do
        local pid=${parallel_pids[$i]}
        local chunk_name=${parallel_chunks[$i]}
        
        if wait $pid; then
            echo -e "${GREEN}✅ $chunk_name completed successfully${NC}"
            parallel_results+=("SUCCESS")
        else
            echo -e "${RED}❌ $chunk_name failed${NC}"
            parallel_results+=("FAILED")
            all_success=false
        fi
    done
    
    return $all_success
}

# Function to display results summary
display_results_summary() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}            Parallel Test Execution Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    for i in "${!parallel_chunks[@]}"; do
        local chunk_name=${parallel_chunks[$i]}
        local result=${parallel_results[$i]}
        
        if [[ "$result" == "SUCCESS" ]]; then
            echo -e "${GREEN}✅ $chunk_name: PASSED${NC}"
        else
            echo -e "${RED}❌ $chunk_name: FAILED${NC}"
            # Show last 10 lines of log for failed chunks
            local log_file="$LOG_DIR/${chunk_name}_${TIMESTAMP}.log"
            if [[ -f "$log_file" ]]; then
                echo -e "${YELLOW}   Last 10 lines of $chunk_name log:${NC}"
                tail -10 "$log_file" | sed 's/^/   /'
            fi
        fi
    done
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Function to run parallel test suite
run_parallel_test_suite() {
    local mode="${1:-full}"
    
    echo -e "${BLUE}🚀 Starting parallel test suite (mode: $mode)${NC}"
    
    # Always run build configuration first
    echo -e "${CYAN}📦 Running build configuration...${NC}"
    if ! "$SCRIPT_DIR/test-chunk-0-config.sh"; then
        echo -e "${RED}❌ Build configuration failed - aborting${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Build configuration completed${NC}"
    
    # Reset arrays
    parallel_pids=()
    parallel_chunks=()
    parallel_results=()
    
    case "$mode" in
        "fast")
            echo -e "${CYAN}⚡ Running fast validation (critical tests only)${NC}"
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-1.sh" "unit-tests"
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-5.sh" "swiftlint"
            ;;
        "full")
            echo -e "${CYAN}🔄 Running full validation (all test chunks)${NC}"
            # Run independent chunks in parallel
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-1.sh" "unit-tests"
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-2.sh" "integration-tests"
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-4.sh" "performance-tests"
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-5.sh" "swiftlint"
            ;;
        "ui-only")
            echo -e "${CYAN}🎨 Running UI-focused validation${NC}"
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-1.sh" "unit-tests"
            run_chunk_parallel "$SCRIPT_DIR/test-chunk-3.sh" "ui-tests"
            ;;
        *)
            echo -e "${RED}❌ Unknown mode: $mode${NC}"
            echo -e "${YELLOW}Available modes: fast, full, ui-only${NC}"
            exit 1
            ;;
    esac
    
    # Wait for all parallel processes to complete
    if wait_for_parallel_completion; then
        echo -e "${GREEN}✅ All parallel tests completed successfully${NC}"
        
        # Run UI tests sequentially if full mode (they may need more resources)
        if [[ "$mode" == "full" ]]; then
            echo -e "${CYAN}🎨 Running UI tests sequentially...${NC}"
            if "$SCRIPT_DIR/test-chunk-3.sh"; then
                echo -e "${GREEN}✅ UI tests completed successfully${NC}"
            else
                echo -e "${RED}❌ UI tests failed${NC}"
                display_results_summary
                exit 1
            fi
        fi
        
        display_results_summary
        return 0
    else
        echo -e "${RED}❌ Some parallel tests failed${NC}"
        display_results_summary
        return 1
    fi
}

# Function to clean up old logs
cleanup_old_logs() {
    # Keep only last 10 log files per chunk type
    find "$LOG_DIR" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
}

# Main execution
main() {
    local mode="${1:-full}"
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}        Traveling Snails - Parallel Test Runner${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Mode: $mode${NC}"
    echo -e "${CYAN}Timestamp: $(date)${NC}"
    echo -e "${CYAN}Project Root: $PROJECT_ROOT${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    # Cleanup old logs
    cleanup_old_logs
    
    # Run the parallel test suite
    if run_parallel_test_suite "$mode"; then
        echo -e "${GREEN}🎉 Parallel test suite completed successfully!${NC}"
        exit 0
    else
        echo -e "${RED}💥 Parallel test suite failed!${NC}"
        exit 1
    fi
}

# Handle command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi