#!/bin/bash
# Async Pre-commit Hook for Traveling Snails
# Target: Fast pre-commit (30-60s) + background full validation
# Focus: Allow commit to proceed while comprehensive testing runs in background

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

echo -e "${BLUE}🚀 Running ASYNC pre-commit validation...${NC}"
echo -e "${CYAN}Phase 1: Fast validation (30-60s)${NC}"
echo -e "${CYAN}Phase 2: Background comprehensive validation${NC}"

# Phase 1: Run fast validation to allow commit
echo -e "${YELLOW}⚡ Phase 1: Running fast validation...${NC}"

if ! "$SCRIPT_DIR/pre-commit-fast.sh"; then
    echo -e "${RED}❌ Fast validation failed - commit blocked${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Phase 1 completed - commit will be allowed${NC}"

# Phase 2: Start background comprehensive validation
echo -e "${CYAN}🔄 Phase 2: Starting background comprehensive validation...${NC}"

# Create async validation log
ASYNC_LOG_DIR="$PROJECT_ROOT/async-validation-logs"
mkdir -p "$ASYNC_LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ASYNC_LOG_FILE="$ASYNC_LOG_DIR/async_validation_${TIMESTAMP}.log"

# Get current commit info for context
CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Background validation function
run_background_validation() {
    local log_file="$1"
    local commit_hash="$2"
    local branch_name="$3"
    
    {
        echo "=== Async Validation Started ==="
        echo "Timestamp: $(date)"
        echo "Commit: $commit_hash"
        echo "Branch: $branch_name"
        echo "Project: Traveling Snails"
        echo "=== Starting Comprehensive Validation ==="
        
        # Run comprehensive validation
        if "$SCRIPT_DIR/pre-commit-full.sh"; then
            echo "=== ASYNC VALIDATION PASSED ==="
            echo "All comprehensive tests passed for commit $commit_hash"
            echo "Validation completed at: $(date)"
            
            # Create success marker
            touch "$ASYNC_LOG_DIR/success_${commit_hash:0:8}.marker"
            
            # Optional: Send notification (if available)
            if command -v osascript &> /dev/null; then
                osascript -e "display notification \"Async validation PASSED for commit ${commit_hash:0:8}\" with title \"Traveling Snails CI\""
            fi
            
        else
            echo "=== ASYNC VALIDATION FAILED ==="
            echo "Comprehensive tests failed for commit $commit_hash"
            echo "Validation failed at: $(date)"
            echo ""
            echo "RECOMMENDED ACTIONS:"
            echo "1. Run: git show $commit_hash"
            echo "2. Run: ./Scripts/pre-commit-full.sh"
            echo "3. Fix any issues and create follow-up commit"
            echo "4. Or revert with: git revert $commit_hash"
            
            # Create failure marker
            touch "$ASYNC_LOG_DIR/failure_${commit_hash:0:8}.marker"
            
            # Optional: Send notification (if available)
            if command -v osascript &> /dev/null; then
                osascript -e "display notification \"Async validation FAILED for commit ${commit_hash:0:8}\" with title \"Traveling Snails CI\""
            fi
        fi
        
        echo "=== Async Validation Completed ==="
    } > "$log_file" 2>&1
}

# Start background validation
echo -e "${CYAN}📝 Background validation log: $ASYNC_LOG_FILE${NC}"
echo -e "${CYAN}📍 Monitor progress: tail -f $ASYNC_LOG_FILE${NC}"

# Run background validation in a detached process
nohup bash -c "$(declare -f run_background_validation); run_background_validation '$ASYNC_LOG_FILE' '$CURRENT_COMMIT' '$CURRENT_BRANCH'" > /dev/null 2>&1 &
BACKGROUND_PID=$!

# Save background process info
echo "$BACKGROUND_PID" > "$ASYNC_LOG_DIR/background_pid_${TIMESTAMP}.txt"

echo -e "${GREEN}✅ Background validation started (PID: $BACKGROUND_PID)${NC}"

# Performance analysis for Phase 1
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 ASYNC pre-commit validation completed!${NC}"
echo -e "${CYAN}Phase 1 Duration: ${DURATION}s${NC}"
echo -e "${YELLOW}📋 Background validation status:${NC}"
echo -e "${CYAN}  • Log file: $ASYNC_LOG_FILE${NC}"
echo -e "${CYAN}  • Process ID: $BACKGROUND_PID${NC}"
echo -e "${CYAN}  • Monitor: tail -f $ASYNC_LOG_FILE${NC}"
echo -e "${YELLOW}💡 Check async validation results in 2-3 minutes${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Function to check async validation status
cat << 'EOF' > "$ASYNC_LOG_DIR/check_async_status.sh"
#!/bin/bash
# Check async validation status

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
ASYNC_LOG_DIR="$PROJECT_ROOT/async-validation-logs"

echo "=== Async Validation Status ==="
echo "Recent validation runs:"

# Find recent success/failure markers
find "$ASYNC_LOG_DIR" -name "*.marker" -mtime -1 | sort | while read marker; do
    if [[ "$marker" == *"success"* ]]; then
        echo "✅ $(basename "$marker")"
    else
        echo "❌ $(basename "$marker")"
    fi
done

# Show active background processes
echo ""
echo "Active background processes:"
ps aux | grep "pre-commit-async" | grep -v grep || echo "No active processes"

echo ""
echo "Recent log files:"
ls -la "$ASYNC_LOG_DIR"/*.log 2>/dev/null | tail -5 || echo "No log files found"
EOF

chmod +x "$ASYNC_LOG_DIR/check_async_status.sh"

echo -e "${CYAN}💡 Check validation status: $ASYNC_LOG_DIR/check_async_status.sh${NC}"