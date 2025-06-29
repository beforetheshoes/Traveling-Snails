# SwiftLint Development Integration Guide

This guide covers integrating SwiftLint into your daily development workflow, including Xcode integration, pre-commit hooks, and automated tooling.

## Table of Contents

1. [Xcode Integration](#xcode-integration)
2. [Pre-Commit Hooks](#pre-commit-hooks)
3. [IDE Configuration](#ide-configuration)
4. [Command Line Tools](#command-line-tools)
5. [Automation Scripts](#automation-scripts)
6. [Performance Optimization](#performance-optimization)
7. [Troubleshooting](#troubleshooting)

## Xcode Integration

### Build Phase Integration

Add SwiftLint as a build phase to automatically check code during compilation:

#### 1. Add Build Phase Script

1. Open your Xcode project
2. Select your target
3. Go to "Build Phases" tab
4. Click "+" and select "New Run Script Phase"
5. Name it "SwiftLint"
6. Add this script:

```bash
# SwiftLint Build Phase Script for Traveling Snails

# Only run SwiftLint on main scheme builds, not for testing
if [ "${CONFIGURATION}" = "Debug" ] || [ "${CONFIGURATION}" = "Release" ]; then
    # Check if SwiftLint is available via Swift Package Manager
    if command -v swift >/dev/null 2>&1; then
        cd "${SRCROOT}"
        
        # Run autocorrect first (safe fixes only)
        echo "🔧 Running SwiftLint autocorrect..."
        swift run swiftlint --autocorrect --config .swiftlint.yml
        
        # Then run linting with build integration
        echo "🔍 Running SwiftLint analysis..."
        swift run swiftlint lint --config .swiftlint.yml --strict
        
        # Check for security violations and fail build if found
        VIOLATIONS=$(swift run swiftlint lint --config .swiftlint.yml --reporter json 2>/dev/null || echo "[]")
        SECURITY_VIOLATIONS=$(echo "$VIOLATIONS" | jq '[.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages"))] | length' 2>/dev/null || echo "0")
        
        if [ "$SECURITY_VIOLATIONS" -gt 0 ]; then
            echo "error: $SECURITY_VIOLATIONS security violations detected. Build failed."
            exit 1
        fi
        
        echo "✅ SwiftLint analysis completed"
    else
        echo "warning: SwiftLint not found. Install via Swift Package Manager."
    fi
fi
```

#### 2. Position the Build Phase

- Drag the "SwiftLint" phase to run **after** "Compile Sources"
- This ensures SwiftLint runs on the latest code but doesn't interfere with compilation

### Xcode Scheme Configuration

#### Development Scheme Setup

Create a dedicated development scheme with SwiftLint integration:

1. **Product → Scheme → Manage Schemes**
2. **Duplicate** your main scheme and name it "Development"
3. **Edit Scheme → Build → Pre-actions**
4. Add pre-action script:

```bash
# Pre-build SwiftLint check
cd "${SRCROOT}"
swift run swiftlint --autocorrect
```

#### Release Scheme Setup

For release builds, use stricter validation:

1. **Edit Scheme → Build → Post-actions**
2. Add post-action script:

```bash
# Post-build release validation
cd "${SRCROOT}"
VIOLATIONS=$(swift run swiftlint lint --reporter json | jq 'length' 2>/dev/null || echo "999")
if [ "$VIOLATIONS" -gt 10 ]; then
    echo "error: Too many SwiftLint violations ($VIOLATIONS) for release build"
    exit 1
fi
```

### Xcode Warnings Integration

Configure SwiftLint to show violations as Xcode warnings/errors:

```bash
# Use in build phase for better Xcode integration
swift run swiftlint lint --reporter xcode
```

This will show violations directly in Xcode's issue navigator with clickable file links.

## Pre-Commit Hooks

### Automatic Git Hook Setup

#### 1. Install Pre-Commit Hook

Run this command in your project root:

```bash
# Create and install pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
# SwiftLint Pre-Commit Hook for Traveling Snails

echo "🔍 Running SwiftLint pre-commit check..."

# Check if SwiftLint is available
if ! command -v swift >/dev/null 2>&1; then
    echo "❌ Swift not found. Cannot run SwiftLint."
    exit 1
fi

# Get list of Swift files being committed
SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep "\.swift$" || true)

if [ -z "$SWIFT_FILES" ]; then
    echo "📝 No Swift files in commit. Skipping SwiftLint."
    exit 0
fi

echo "📁 Checking $(echo "$SWIFT_FILES" | wc -l) Swift files..."

# Run autocorrect first
echo "🔧 Running SwiftLint autocorrect..."
swift run swiftlint --autocorrect --config .swiftlint.yml

# Add any auto-corrected changes to commit
git add $SWIFT_FILES

# Run linting on staged files
echo "🔍 Running SwiftLint analysis..."
VIOLATIONS_OUTPUT=$(swift run swiftlint lint --config .swiftlint.yml --reporter json $SWIFT_FILES 2>/dev/null || echo "[]")

# Check for critical security violations
SECURITY_VIOLATIONS=$(echo "$VIOLATIONS_OUTPUT" | jq '[.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages") and .severity == "error")] | length' 2>/dev/null || echo "0")

if [ "$SECURITY_VIOLATIONS" -gt 0 ]; then
    echo "🚨 CRITICAL: $SECURITY_VIOLATIONS security violations detected!"
    echo "❌ Commit blocked. Please fix security issues before committing."
    echo "$VIOLATIONS_OUTPUT" | jq -r '.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages") and .severity == "error") | "\(.file):\(.line): error: \(.reason)"' 2>/dev/null || true
    exit 1
fi

# Check for high violation count
TOTAL_VIOLATIONS=$(echo "$VIOLATIONS_OUTPUT" | jq 'length' 2>/dev/null || echo "0")
if [ "$TOTAL_VIOLATIONS" -gt 20 ]; then
    echo "⚠️  Warning: High number of violations ($TOTAL_VIOLATIONS). Consider fixing before commit."
    echo "Continue anyway? (y/N)"
    read -r RESPONSE
    if [ "$RESPONSE" != "y" ] && [ "$RESPONSE" != "Y" ]; then
        echo "❌ Commit cancelled."
        exit 1
    fi
fi

echo "✅ SwiftLint check passed. Proceeding with commit."
exit 0
EOF

# Make hook executable
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed successfully!"
```

#### 2. Team Hook Distribution

To ensure all team members use the same hooks, add a setup script:

```bash
# Scripts/setup-git-hooks.sh
#!/bin/bash

echo "🔧 Setting up Git hooks for Traveling Snails..."

# Copy pre-commit hook
cp Scripts/git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Copy pre-push hook (optional)
if [ -f "Scripts/git-hooks/pre-push" ]; then
    cp Scripts/git-hooks/pre-push .git/hooks/pre-push
    chmod +x .git/hooks/pre-push
fi

echo "✅ Git hooks installed successfully!"
echo "🔍 SwiftLint will now run automatically before commits."
```

### Custom Hook Configurations

#### Selective File Checking

Only check files that have changed:

```bash
# In pre-commit hook - check only modified files
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$" || true)

if [ ! -z "$STAGED_SWIFT_FILES" ]; then
    echo "$STAGED_SWIFT_FILES" | xargs swift run swiftlint lint --config .swiftlint.yml
fi
```

#### Skip Hook for Emergency Commits

Allow bypassing the hook when needed:

```bash
# Emergency commit without SwiftLint check
git commit --no-verify -m "Emergency fix: bypassing SwiftLint"
```

## IDE Configuration

### VS Code Integration

#### 1. Install SwiftLint Extension

1. Install "SwiftLint" extension by Shin Yamamoto
2. Configure in VS Code settings:

```json
{
    "swiftlint.enable": true,
    "swiftlint.configPath": ".swiftlint.yml",
    "swiftlint.autocorrectOnSave": true,
    "swiftlint.onlyEnableWithSwiftlintFile": true
}
```

#### 2. Task Integration

Add to `.vscode/tasks.json`:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "SwiftLint",
            "type": "shell",
            "command": "swift",
            "args": ["run", "swiftlint", "lint"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            },
            "problemMatcher": {
                "owner": "swiftlint",
                "fileLocation": "absolute",
                "pattern": {
                    "regexp": "^(.*):(\\d+):(\\d+):\\s+(warning|error):\\s+(.*)$",
                    "file": 1,
                    "line": 2,
                    "column": 3,
                    "severity": 4,
                    "message": 5
                }
            }
        },
        {
            "label": "SwiftLint Autocorrect",
            "type": "shell",
            "command": "swift",
            "args": ["run", "swiftlint", "--autocorrect"],
            "group": "build"
        }
    ]
}
```

### AppCode Integration

For JetBrains AppCode users:

1. **File → Settings → Tools → External Tools**
2. **Add New Tool**:
   - **Name**: SwiftLint
   - **Program**: `swift`
   - **Arguments**: `run swiftlint lint $FilePath$`
   - **Working Directory**: `$ProjectFileDir$`

## Command Line Tools

### Development Scripts

#### Quick Lint Script

Create `Scripts/quick-lint.sh`:

```bash
#!/bin/bash
# Quick SwiftLint check for development

echo "🔍 Quick SwiftLint check..."

# Check only modified files
MODIFIED_FILES=$(git status --porcelain | grep "\.swift$" | cut -c4- || true)

if [ -z "$MODIFIED_FILES" ]; then
    echo "📝 No modified Swift files found."
    exit 0
fi

echo "📁 Checking $(echo "$MODIFIED_FILES" | wc -l) modified files..."

# Run on modified files only
echo "$MODIFIED_FILES" | xargs swift run swiftlint lint --config .swiftlint.yml

echo "✅ Quick lint completed."
```

#### Fix All Script

Create `Scripts/fix-all-violations.sh`:

```bash
#!/bin/bash
# Fix all possible SwiftLint violations

echo "🔧 Fixing all SwiftLint violations..."

# Run autocorrect multiple times (some fixes enable other fixes)
for i in {1..3}; do
    echo "🔄 Autocorrect pass $i..."
    swift run swiftlint --autocorrect --config .swiftlint.yml
done

# Show remaining violations
echo "📊 Remaining violations:"
swift run swiftlint lint --config .swiftlint.yml --reporter summary

echo "✅ Auto-fix completed. Manual fixes may be required for remaining violations."
```

### Alias Setup

Add to your shell profile (`.bashrc`, `.zshrc`):

```bash
# SwiftLint aliases for Traveling Snails
alias swiftlint-check='swift run swiftlint lint'
alias swiftlint-fix='swift run swiftlint --autocorrect'
alias swiftlint-security='swift run swiftlint lint --enable-rule no_print_statements,no_sensitive_logging,safe_error_messages'
alias swiftlint-report='swift run swiftlint lint --reporter html > swiftlint-report.html && open swiftlint-report.html'
```

## Automation Scripts

### CI Integration Helper

Create `Scripts/ci-swiftlint.sh`:

```bash
#!/bin/bash
# CI-optimized SwiftLint execution

set -e

echo "🔍 Running CI SwiftLint checks..."

# Generate JSON report
swift run swiftlint lint --config .swiftlint.yml --reporter json > swiftlint-results.json

# Check for critical violations
CRITICAL_VIOLATIONS=$(jq '[.[] | select(.severity == "error")] | length' swiftlint-results.json 2>/dev/null || echo "0")
SECURITY_VIOLATIONS=$(jq '[.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages"))] | length' swiftlint-results.json 2>/dev/null || echo "0")

echo "📊 Analysis Results:"
echo "   Critical Violations: $CRITICAL_VIOLATIONS"
echo "   Security Violations: $SECURITY_VIOLATIONS"

# Fail if critical issues found
if [ "$CRITICAL_VIOLATIONS" -gt 0 ]; then
    echo "❌ Critical violations detected. Build failed."
    jq -r '.[] | select(.severity == "error") | "\(.file):\(.line): error: \(.reason)"' swiftlint-results.json 2>/dev/null || true
    exit 1
fi

if [ "$SECURITY_VIOLATIONS" -gt 0 ]; then
    echo "🚨 Security violations detected. Build failed."
    jq -r '.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages")) | "\(.file):\(.line): \(.severity): \(.reason)"' swiftlint-results.json 2>/dev/null || true
    exit 1
fi

echo "✅ SwiftLint CI check passed."
```

### Weekly Cleanup Script

Create `Scripts/weekly-swiftlint-cleanup.sh`:

```bash
#!/bin/bash
# Weekly SwiftLint maintenance

echo "🧹 Weekly SwiftLint cleanup..."

# Generate comprehensive report
swift run swiftlint lint --config .swiftlint.yml --reporter html > "reports/swiftlint-$(date +%Y-%m-%d).html"

# Show statistics
echo "📊 Current Statistics:"
VIOLATIONS=$(swift run swiftlint lint --config .swiftlint.yml --reporter json | jq 'length' 2>/dev/null || echo "0")
ERRORS=$(swift run swiftlint lint --config .swiftlint.yml --reporter json | jq '[.[] | select(.severity == "error")] | length' 2>/dev/null || echo "0")
WARNINGS=$(swift run swiftlint lint --config .swiftlint.yml --reporter json | jq '[.[] | select(.severity == "warning")] | length' 2>/dev/null || echo "0")

echo "   Total Violations: $VIOLATIONS"
echo "   Errors: $ERRORS"
echo "   Warnings: $WARNINGS"

# Suggest focus areas
if [ "$ERRORS" -gt 0 ]; then
    echo "🎯 Focus: Fix $ERRORS error-level violations first"
elif [ "$WARNINGS" -gt 50 ]; then
    echo "🎯 Focus: Reduce warning count (currently $WARNINGS)"
else
    echo "✅ Code quality is good! Consider enhancing rules."
fi
```

## Performance Optimization

### Caching Strategy

#### SPM Build Cache

Leverage SPM caching for faster subsequent runs:

```bash
# Use existing .build cache when possible
if [ -d ".build" ]; then
    echo "📦 Using existing SPM cache..."
    swift run swiftlint lint
else
    echo "🔄 Building SwiftLint (first run)..."
    swift build && swift run swiftlint lint
fi
```

#### File-Level Caching

Only process changed files:

```bash
# Check modification times
CACHE_FILE=".swiftlint-cache"
if [ -f "$CACHE_FILE" ]; then
    # Only lint files newer than cache
    find . -name "*.swift" -newer "$CACHE_FILE" | xargs swift run swiftlint lint
else
    # Full lint and create cache
    swift run swiftlint lint
    touch "$CACHE_FILE"
fi
```

### Parallel Processing

For large codebases:

```bash
# Use parallel processing (if available)
swift run swiftlint lint --parallel --config .swiftlint.yml
```

### Rule Subsets

Run different rule sets at different times:

```bash
# Quick security check
swift run swiftlint lint --enable-rule no_print_statements,no_sensitive_logging

# Full check (less frequently)
swift run swiftlint lint --config .swiftlint.yml
```

## Troubleshooting

### Common Issues

#### 1. "SwiftLint not found"

```bash
# Verify SwiftLint is built
swift build
ls .build/debug/swiftlint

# Rebuild if necessary
swift package clean
swift build
```

#### 2. "Configuration file not found"

```bash
# Verify config file exists
ls -la .swiftlint.yml

# Check working directory in scripts
pwd
cd "${SRCROOT}" || cd "$(dirname "$0")/.."
```

#### 3. "Permission denied"

```bash
# Fix script permissions
chmod +x Scripts/*.sh
chmod +x .git/hooks/*
```

#### 4. "jq command not found"

```bash
# Install jq for JSON processing
brew install jq  # macOS
# or use alternative JSON parsing
```

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Verbose SwiftLint output
swift run swiftlint lint --verbose

# Debug rule matching
swift run swiftlint lint --enable-rule specific_rule --verbose
```

### Performance Debugging

```bash
# Time SwiftLint execution
time swift run swiftlint lint

# Profile specific rules
swift run swiftlint lint --enable-rule no_print_statements --reporter summary
```

---

## Quick Setup Checklist

- [ ] **Xcode Build Phase**: Added SwiftLint script to build phases
- [ ] **Pre-Commit Hook**: Installed and tested git hook
- [ ] **IDE Integration**: Configured VS Code/AppCode extensions
- [ ] **Command Aliases**: Added helpful shell aliases
- [ ] **Team Scripts**: Set up shared automation scripts
- [ ] **Performance**: Enabled caching and parallel processing
- [ ] **Documentation**: Team trained on integration workflow

**Next Steps**: Customize the integration based on your team's specific workflow and preferences. Consider setting up team-specific rules and automation based on your development patterns.