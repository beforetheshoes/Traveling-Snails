#!/bin/bash
# Intelligent Pre-commit Hook for Traveling Snails
# Automatically selects appropriate validation mode based on changed files
# Balances code quality with developer velocity

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

echo -e "${BLUE}🧠 Intelligent Pre-commit Hook${NC}"
echo -e "${CYAN}Analyzing changes to determine appropriate validation level...${NC}"

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM || true)

if [ -z "$STAGED_FILES" ]; then
    echo -e "${YELLOW}⚠️  No staged files found${NC}"
    exit 0
fi

# Analyze staged files to determine change type
analyze_change_type() {
    local files="$1"
    
    # Critical patterns that require full validation
    if echo "$files" | grep -qE "(Models|SwiftData|CoreData).*\.swift$"; then
        echo "data-model"
        return
    fi
    
    if echo "$files" | grep -qE "(Security|Auth|Crypto|Login).*\.swift$"; then
        echo "security"
        return
    fi
    
    if echo "$files" | grep -qE "(ErrorStateManagement|Logger|Accessibility).*\.swift$"; then
        echo "critical-infrastructure"
        return
    fi
    
    # Major feature patterns
    if echo "$files" | grep -qE "^Traveling Snails/Views/.*\.swift$" && [ $(echo "$files" | wc -l) -gt 5 ]; then
        echo "major-feature"
        return
    fi
    
    # UI-focused changes
    if echo "$files" | grep -qE "^Traveling Snails/Views/.*\.swift$"; then
        echo "ui-changes"
        return
    fi
    
    # Test-only changes
    if echo "$files" | grep -qE "Tests/.*\.swift$" && ! echo "$files" | grep -qE "^Traveling Snails/.*\.swift$"; then
        echo "test-only"
        return
    fi
    
    # Configuration changes
    if echo "$files" | grep -qE "\.(yml|yaml|json|plist|xcconfig)$"; then
        echo "configuration"
        return
    fi
    
    # Documentation changes
    if echo "$files" | grep -qE "\.(md|txt|rtf)$"; then
        echo "documentation"
        return
    fi
    
    # Default to standard changes
    echo "standard"
}

# Display file analysis
display_file_analysis() {
    local files="$1"
    local change_type="$2"
    
    echo -e "${CYAN}📁 Files being committed:${NC}"
    echo "$files" | sed 's/^/  /' | head -10
    
    if [ $(echo "$files" | wc -l) -gt 10 ]; then
        echo -e "${YELLOW}  ... and $(($(echo "$files" | wc -l) - 10)) more files${NC}"
    fi
    
    echo -e "${CYAN}📊 Change type detected: ${YELLOW}$change_type${NC}"
}

# Determine validation mode based on change type
determine_validation_mode() {
    local change_type="$1"
    
    case "$change_type" in
        "data-model"|"security"|"critical-infrastructure")
            echo "full"
            ;;
        "major-feature")
            # Use fast for major features too - full only for critical changes
            echo "fast"
            ;;
        "ui-changes")
            # UI changes use fast validation - most UI issues caught by SwiftLint + build
            echo "fast"
            ;;
        "configuration")
            # Config changes use full since they can break everything
            echo "full"
            ;;
        "test-only"|"documentation")
            echo "fast"
            ;;
        "standard")
            echo "fast"
            ;;
        *)
            echo "fast"
            ;;
    esac
}

# Explain validation choice
explain_validation_choice() {
    local change_type="$1"
    local mode="$2"
    
    echo -e "${CYAN}🎯 Validation mode: ${YELLOW}$mode${NC}"
    
    case "$change_type" in
        "data-model")
            echo -e "${CYAN}   Reason: Data model changes require comprehensive testing${NC}"
            ;;
        "security")
            echo -e "${CYAN}   Reason: Security changes require full validation${NC}"
            ;;
        "critical-infrastructure")
            echo -e "${CYAN}   Reason: Critical infrastructure changes need thorough testing${NC}"
            ;;
        "major-feature")
            echo -e "${CYAN}   Reason: Major features use fast validation for quick feedback${NC}"
            ;;
        "ui-changes")
            echo -e "${CYAN}   Reason: UI changes use fast validation (SwiftLint + build catches most issues)${NC}"
            ;;
        "test-only")
            echo -e "${CYAN}   Reason: Test-only changes use fast validation${NC}"
            ;;
        "documentation")
            echo -e "${CYAN}   Reason: Documentation changes use fast validation${NC}"
            ;;
        "standard")
            echo -e "${CYAN}   Reason: Standard changes use fast validation${NC}"
            ;;
        *)
            echo -e "${CYAN}   Reason: Default to fast validation${NC}"
            ;;
    esac
}

# Main execution
main() {
    local override_mode="$1"
    
    # Allow manual override
    if [ -n "$override_mode" ]; then
        echo -e "${YELLOW}🔧 Manual override: Using $override_mode mode${NC}"
        validation_mode="$override_mode"
    else
        # Analyze changes
        change_type=$(analyze_change_type "$STAGED_FILES")
        validation_mode=$(determine_validation_mode "$change_type")
        
        # Display analysis
        display_file_analysis "$STAGED_FILES" "$change_type"
        explain_validation_choice "$change_type" "$validation_mode"
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    # Execute appropriate validation
    case "$validation_mode" in
        "fast")
            echo -e "${GREEN}⚡ Running fast validation...${NC}"
            exec "$SCRIPT_DIR/pre-commit-fast.sh"
            ;;
        "full")
            echo -e "${GREEN}🔄 Running full validation...${NC}"
            exec "$SCRIPT_DIR/pre-commit-full.sh"
            ;;
        "async")
            echo -e "${GREEN}🚀 Running async validation...${NC}"
            exec "$SCRIPT_DIR/pre-commit-async.sh"
            ;;
        *)
            echo -e "${RED}❌ Unknown validation mode: $validation_mode${NC}"
            exit 1
            ;;
    esac
}

# Handle command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi