#!/bin/bash

# Pre-commit Hook Setup Script for Traveling Snails
# This script sets up Git pre-commit hooks to run SwiftLint automatically

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="${PROJECT_DIR}/.git/hooks"
PRE_COMMIT_HOOK="${HOOKS_DIR}/pre-commit"

echo "🪝 Setting up pre-commit hooks for Traveling Snails..."

# Check if we're in a git repository
if [ ! -d "${PROJECT_DIR}/.git" ]; then
    echo "❌ Not in a Git repository. Please run this script from the project root."
    exit 1
fi

# Check if SwiftLint is available
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not available. Please ensure Xcode is installed."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "${HOOKS_DIR}"

# Create the pre-commit hook script
cat > "${PRE_COMMIT_HOOK}" << 'EOF'
#!/bin/bash

# Pre-commit hook for Traveling Snails
# Runs SwiftLint on staged Swift files to prevent security and quality issues

echo "🔍 Running pre-commit SwiftLint checks..."

# Get the project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

# Check if SwiftLint is available
if ! command -v swift &> /dev/null; then
    echo "⚠️  Swift not found. Skipping SwiftLint checks."
    exit 0
fi

# Get list of staged Swift files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$" | grep -v "Tests" || true)

if [ -z "$STAGED_FILES" ]; then
    echo "✅ No Swift files staged for commit."
    exit 0
fi

echo "📝 Checking ${STAGED_FILES//[$'\n']/ } Swift files..."

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

# Run SwiftLint on staged files with optimized settings
echo "🚀 Running SwiftLint with security-focused rules..."

# Check for critical security violations first
SECURITY_VIOLATIONS=$(cd "$TEMP_DIR" && swift run --package-path "$PROJECT_ROOT" swiftlint lint --config "$PROJECT_ROOT/.swiftlint.yml" --reporter json . 2>/dev/null | jq -r '.[] | select(.rule_id | test("no_print_statements|no_sensitive_logging|safe_error_messages")) | "\(.file):\(.line): \(.reason)"' 2>/dev/null || echo "")

if [ ! -z "$SECURITY_VIOLATIONS" ]; then
    echo ""
    echo "🚨 SECURITY VIOLATIONS DETECTED:"
    echo "$SECURITY_VIOLATIONS"
    echo ""
    echo "❌ Commit blocked due to security violations."
    echo "   Please fix these issues before committing:"
    echo "   - Replace print() statements with Logger.shared"
    echo "   - Remove sensitive data from logging"
    echo "   - Use safe error messages"
    echo ""
    exit 1
fi

# Run full SwiftLint check
LINT_OUTPUT=$(cd "$TEMP_DIR" && swift run --package-path "$PROJECT_ROOT" swiftlint lint --config "$PROJECT_ROOT/.swiftlint.yml" --reporter emoji . 2>/dev/null || echo "")

# Count violations
ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -c "❌" || echo "0")
WARNING_COUNT=$(echo "$LINT_OUTPUT" | grep -c "⚠️" || echo "0")

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo ""
    echo "❌ SwiftLint found $ERROR_COUNT error(s) in staged files:"
    echo "$LINT_OUTPUT"
    echo ""
    echo "Commit blocked. Please fix the errors above."
    echo "💡 Tip: Run 'swift run swiftlint --autocorrect' to fix style issues automatically."
    exit 1
fi

if [ "$WARNING_COUNT" -gt 0 ]; then
    echo ""
    echo "⚠️  SwiftLint found $WARNING_COUNT warning(s) in staged files:"
    echo "$LINT_OUTPUT"
    echo ""
    echo "Consider fixing these warnings for better code quality."
    echo "💡 Tip: Run 'swift run swiftlint --autocorrect' to fix style issues automatically."
    echo ""
fi

echo "✅ SwiftLint checks passed! Proceeding with commit."
EOF

# Make the hook executable
chmod +x "${PRE_COMMIT_HOOK}"

# Create a commit-msg hook for additional safety
cat > "${HOOKS_DIR}/commit-msg" << 'EOF'
#!/bin/bash

# Commit message hook for Traveling Snails
# Ensures commit messages follow basic conventions

COMMIT_MSG_FILE="$1"
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Skip if this is a merge commit
if [[ $COMMIT_MSG == Merge* ]]; then
    exit 0
fi

# Skip if this is a revert commit
if [[ $COMMIT_MSG == Revert* ]]; then
    exit 0
fi

# Check minimum length
if [ ${#COMMIT_MSG} -lt 10 ]; then
    echo "❌ Commit message too short. Please provide a descriptive commit message (at least 10 characters)."
    exit 1
fi

# Check for security-related commits
if echo "$COMMIT_MSG" | grep -qi "fix.*security\|security.*fix\|vulnerability\|exploit"; then
    echo "🔒 Security-related commit detected. Ensure all sensitive information is removed."
fi

echo "✅ Commit message format is acceptable."
EOF

chmod +x "${HOOKS_DIR}/commit-msg"

# Test the setup
echo ""
echo "🧪 Testing pre-commit hook setup..."

if [ -x "${PRE_COMMIT_HOOK}" ]; then
    echo "✅ Pre-commit hook is executable"
else
    echo "❌ Pre-commit hook is not executable"
    exit 1
fi

if [ -x "${HOOKS_DIR}/commit-msg" ]; then
    echo "✅ Commit-msg hook is executable"
else
    echo "❌ Commit-msg hook is not executable"
    exit 1
fi

echo ""
echo "🎉 Pre-commit hooks setup complete!"
echo ""
echo "📋 What was installed:"
echo "  • .git/hooks/pre-commit - Runs SwiftLint on staged files"
echo "  • .git/hooks/commit-msg - Validates commit message format"
echo ""
echo "🔧 How it works:"
echo "  • Before each commit, SwiftLint checks staged Swift files"
echo "  • Security violations (print statements, sensitive logging) block commits"
echo "  • Style violations show warnings but allow commits"
echo "  • Commit messages are validated for minimum length"
echo ""
echo "💡 Tips:"
echo "  • Run 'swift run swiftlint --autocorrect' before committing to fix style issues"
echo "  • Use 'git commit --no-verify' to bypass hooks in emergencies"
echo "  • Hooks only run on staged files, not the entire codebase"
echo ""
echo "🔍 Next steps:"
echo "  1. Stage some Swift files: git add ."
echo "  2. Try committing: git commit -m 'Test commit'"
echo "  3. Verify hooks run and provide feedback"