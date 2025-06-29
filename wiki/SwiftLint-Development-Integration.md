# SwiftLint Development Integration Guide

This guide covers setting up SwiftLint integration for daily development, including Xcode build phases, pre-commit hooks, and automated workflows.

## Table of Contents

1. [Xcode Integration](#xcode-integration)
2. [Pre-commit Hooks](#pre-commit-hooks)
3. [IDE Setup](#ide-setup)
4. [Automated Workflows](#automated-workflows)
5. [Performance Optimization](#performance-optimization)
6. [Troubleshooting](#troubleshooting)

## Xcode Integration

### Automatic Setup

Use the automated setup script for the fastest configuration:

```bash
# Run the automated Xcode integration script
./Scripts/setup-swiftlint.sh
```

This script will:
- ✅ Verify SwiftLint is available via SPM
- ✅ Generate the proper Xcode build script
- ✅ Provide step-by-step Xcode configuration instructions
- ✅ Test the SwiftLint configuration

### Manual Xcode Build Phase Setup

If you prefer manual setup, follow these steps:

#### 1. Add Run Script Build Phase

1. Open `Traveling Snails.xcodeproj` in Xcode
2. Select the **Traveling Snails** project in the navigator
3. Select the **Traveling Snails** target (not the test target)
4. Go to the **Build Phases** tab
5. Click **+** and select **New Run Script Phase**
6. Name the phase **"SwiftLint"**

#### 2. Configure the Script

Paste this optimized script into the run script phase:

```bash
# SwiftLint Build Phase for Traveling Snails
# Security-focused with performance optimizations

# Exit early if not the main app target
if [ "${TARGET_NAME}" != "Traveling Snails" ]; then
    echo "Skipping SwiftLint for ${TARGET_NAME} (test target)"
    exit 0
fi

echo "🔍 Running SwiftLint for ${TARGET_NAME}..."

# Use SwiftLint from SPM or fallback to system installation
SWIFTLINT_CMD=""
if command -v swift >/dev/null 2>&1; then
    # Try SPM first (project dependency)
    if swift package --package-path "${SRCROOT}" plugin --list | grep -q SwiftLint; then
        SWIFTLINT_CMD="swift run --package-path ${SRCROOT} swiftlint"
    elif command -v swiftlint >/dev/null 2>&1; then
        SWIFTLINT_CMD="swiftlint"
    else
        echo "❌ SwiftLint not found. Run ./Scripts/setup-swiftlint.sh"
        exit 1
    fi
else
    echo "❌ Swift not found. Ensure Xcode Command Line Tools are installed."
    exit 1
fi

# Run SwiftLint with optimized settings
cd "${SRCROOT}"
${SWIFTLINT_CMD} lint --config .swiftlint.yml --quiet

# Check for critical security violations separately
SECURITY_CHECK=$(${SWIFTLINT_CMD} lint --config .swiftlint.yml --reporter json | jq -r '.[] | select(.rule_id | test("no_print_statements|no_sensitive_logging|safe_error_messages") and .severity == "error") | "\(.file):\(.line): \(.reason)"' 2>/dev/null || echo "")

if [ ! -z "$SECURITY_CHECK" ]; then
    echo ""
    echo "🚨 CRITICAL SECURITY VIOLATIONS:"
    echo "$SECURITY_CHECK"
    echo ""
    echo "❌ Build failed due to security violations."
    echo "   Fix these issues before building:"
    echo "   • Replace print() with Logger.shared"
    echo "   • Remove sensitive data from logs"
    echo "   • Use safe error messages"
    exit 1
fi

echo "✅ SwiftLint checks passed"
```

#### 3. Configure Input/Output Files

**Input Files** (for build optimization):
```
$(SRCROOT)/.swiftlint.yml
$(SRCROOT)/Traveling Snails
```

**Output Files** (for build caching):
```
$(DERIVED_FILE_DIR)/swiftlint.log
```

#### 4. Position the Build Phase

**Important**: Move the SwiftLint build phase to run **before** the "Compile Sources" phase to catch issues early.

### Xcode Settings Optimization

#### Build Settings

Add these build settings for better SwiftLint integration:

1. Go to **Build Settings** tab
2. Search for "Other Swift Flags"
3. Add: `-Xfrontend -warn-long-function-bodies=100`
4. This helps identify functions that might need SwiftLint attention

#### Scheme Configuration

1. Edit the scheme (Product → Scheme → Edit Scheme)
2. Go to **Build** section
3. Check **"Parallelize Build"** for faster builds
4. Ensure SwiftLint runs for both Debug and Release configurations

## Pre-commit Hooks

Pre-commit hooks catch issues before they enter the repository, improving code quality and reducing CI failures.

### Automatic Setup

```bash
# Set up pre-commit hooks automatically
./Scripts/setup-pre-commit-hooks.sh
```

This script installs:
- ✅ **pre-commit hook** - Runs SwiftLint on staged files
- ✅ **commit-msg hook** - Validates commit message format
- ✅ **Security-focused checks** that block commits with violations

### Manual Pre-commit Hook Setup

If you prefer manual setup:

#### 1. Create Basic Pre-commit Hook

```bash
# Create the hook file
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "🔍 Running SwiftLint pre-commit checks..."

# Get staged Swift files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$" | grep -v "Tests" || true)

if [ -z "$STAGED_FILES" ]; then
    echo "✅ No Swift files to check"
    exit 0
fi

# Run SwiftLint on staged files only
swift run swiftlint lint --use-stdin --path /dev/stdin < <(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$" | xargs cat)

# Check exit code
if [ $? -ne 0 ]; then
    echo "❌ SwiftLint found issues. Fix them before committing."
    echo "💡 Run 'swift run swiftlint --autocorrect' to fix style issues"
    exit 1
fi

echo "✅ SwiftLint checks passed!"
EOF

# Make it executable
chmod +x .git/hooks/pre-commit
```

#### 2. Enhanced Security-Focused Hook

For production use, the automated script creates a more sophisticated hook that:
- 📋 **Stages file analysis** - Only checks files being committed
- 🚨 **Security violation blocking** - Prevents commits with security issues
- 📊 **Detailed reporting** - Shows exactly what needs to be fixed
- ⚡ **Performance optimized** - Uses temporary directories for efficient checking

### Hook Behavior

#### What Gets Checked
- ✅ Staged Swift files only (not entire codebase)
- ✅ Production code (excludes test files)
- ✅ Security rules (print statements, sensitive logging)
- ✅ Critical style violations

#### Blocking vs Warning Violations
- **BLOCKS commit**: Security violations, critical errors
- **ALLOWS commit**: Style warnings, minor issues

#### Bypass Options
```bash
# Skip hooks in emergencies (use sparingly)
git commit --no-verify -m "Emergency fix"

# Check what the hook would do without committing
.git/hooks/pre-commit
```

## IDE Setup

### Xcode Extensions

While there's no official SwiftLint Xcode extension, you can improve the experience:

#### 1. Build Phase Integration (Recommended)
- Errors appear directly in Xcode's issue navigator
- Violations show as compiler warnings/errors
- Click to jump directly to problem locations

#### 2. External Editor Integration

For users of external editors:

**VS Code:**
```json
{
    "swiftlint.enable": true,
    "swiftlint.configPath": ".swiftlint.yml",
    "swiftlint.onlyEnableWithSwiftlintConfig": true
}
```

**Vim/Neovim:**
```vim
" Add to your .vimrc
Plug 'dense-analysis/ale'
let g:ale_swift_swiftlint_executable = 'swift run swiftlint'
let g:ale_swift_swiftlint_use_global = 1
```

### Xcode Snippets

Create code snippets for common SwiftLint-compliant patterns:

#### Logger Usage Snippet
```swift
// Identifier: logger-debug
Logger.shared.debug("<#message#>", category: .<#category#>)
```

#### SwiftData Query Snippet  
```swift
// Identifier: swiftdata-query
@Query private var <#items#>: [<#ModelType#>]
```

## Automated Workflows

### Local Development Automation

#### Shell Aliases

Add these to your `.bashrc` or `.zshrc`:

```bash
# SwiftLint shortcuts for Traveling Snails
alias lint='swift run swiftlint'
alias lintf='swift run swiftlint --autocorrect'
alias lintj='swift run swiftlint lint --reporter json'
alias lints='swift run swiftlint lint | grep -E "(warning:|error:)"'
```

#### Git Aliases

```bash
# Add to ~/.gitconfig
[alias]
    lint-staged = !git diff --cached --name-only | grep '\\.swift$' | xargs swift run swiftlint lint
    fix-style = !swift run swiftlint --autocorrect && git add -u
```

### Continuous Integration

The project includes optimized CI workflows in `.github/workflows/swiftlint.yml`:

#### Key Features:
- 🚀 **Parallel execution** for faster builds
- 📊 **JSON-based parsing** for reliable violation detection
- 🔒 **Security-focused checks** with build failures
- 📋 **Detailed reporting** with GitHub PR annotations
- ⚡ **Optimized caching** using SPM package resolution

#### Local CI Simulation:
```bash
# Run the same checks as CI locally
swift run swiftlint lint --config .swiftlint.yml --parallel --reporter json > violations.json

# Analyze results like CI does
jq '[.[] | select(.rule_id | test("no_print_statements|no_sensitive_logging|safe_error_messages"))] | length' violations.json
```

## Performance Optimization

### Build Performance

#### Xcode Build Optimization
1. **Incremental linting** - Only lint changed files
2. **Parallel builds** - Enable in scheme settings
3. **Input/Output files** - Proper caching configuration
4. **Target-specific** - Only run on main app target

#### Advanced Caching
```bash
# Custom build script with file-based caching
CACHE_FILE="${DERIVED_FILE_DIR}/swiftlint.cache"
SOURCE_HASH=$(find "Traveling Snails" -name "*.swift" -exec shasum {} \; | shasum | cut -d' ' -f1)

if [ -f "$CACHE_FILE" ] && [ "$(cat $CACHE_FILE)" = "$SOURCE_HASH" ]; then
    echo "✅ SwiftLint cache hit - skipping"
    exit 0
fi

# Run SwiftLint and cache result
swift run swiftlint lint --config .swiftlint.yml
echo "$SOURCE_HASH" > "$CACHE_FILE"
```

### Git Hook Performance

#### Staged Files Only
The pre-commit hook only checks staged files, not the entire codebase:

```bash
# Efficient: Only staged Swift files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$")

# Inefficient: Entire codebase (avoid this)
# swift run swiftlint lint
```

#### Parallel Processing
```bash
# Use SwiftLint's built-in parallelization
swift run swiftlint lint --parallel
```

### Rule Performance

#### Selective Rule Execution
For development, focus on critical rules:

```bash
# Security-only check (fastest)
swift run swiftlint lint --enable-rule no_print_statements,no_sensitive_logging,safe_error_messages

# Modern Swift patterns only
swift run swiftlint lint --enable-rule use_navigation_stack,no_state_object,use_l10n_enum
```

## Troubleshooting

### Common Integration Issues

#### 1. "SwiftLint not found" in Xcode

**Problem**: Build fails with SwiftLint not found error

**Solution**:
```bash
# Verify SwiftLint is available
swift run swiftlint version

# If not available, run setup script
./Scripts/setup-swiftlint.sh

# Check Xcode build script uses correct path
# Should use: swift run swiftlint (not just swiftlint)
```

#### 2. Pre-commit Hook Not Running

**Problem**: Committing without SwiftLint checks

**Solution**:
```bash
# Check if hook exists and is executable
ls -la .git/hooks/pre-commit

# If not executable
chmod +x .git/hooks/pre-commit

# If doesn't exist
./Scripts/setup-pre-commit-hooks.sh
```

#### 3. Performance Issues

**Problem**: SwiftLint slowing down builds

**Solution**:
```bash
# Use parallel processing
swift run swiftlint lint --parallel

# Optimize Xcode build phase with proper input/output files
# Add to Input Files: $(SRCROOT)/.swiftlint.yml
# Add to Output Files: $(DERIVED_FILE_DIR)/swiftlint.log
```

#### 4. False Positives

**Problem**: SwiftLint flagging legitimate code

**Solution**:
```swift
// Disable specific rules for lines
// swiftlint:disable:next no_print_statements
print("This print is intentional")

// Disable for entire file
// swiftlint:disable no_print_statements

// Disable for code block
// swiftlint:disable no_print_statements
func debugFunction() {
    print("Debug output")
}
// swiftlint:enable no_print_statements
```

### Debug Mode

#### Verbose Output
```bash
# Get detailed SwiftLint execution info
swift run swiftlint lint --verbose

# Test specific rules
swift run swiftlint lint --enable-rule no_print_statements --verbose
```

#### Configuration Validation
```bash
# Validate .swiftlint.yml syntax
swift run swiftlint rules

# Test configuration against sample file
echo 'print("test")' | swift run swiftlint lint --use-stdin --path test.swift
```

### Getting Help

#### Project-Specific Issues
1. Check existing documentation in `wiki/`
2. Review `CLAUDE.md` for development guidelines
3. Look at successful CI runs in GitHub Actions

#### SwiftLint Issues
1. Check [SwiftLint documentation](https://github.com/realm/SwiftLint)
2. Review rule-specific documentation
3. Test with minimal examples

#### Performance Issues
1. Run `./Scripts/swiftlint-performance-benchmark.sh`
2. Check CI execution times in GitHub Actions
3. Profile specific rules with `--verbose` flag

---

## Quick Reference

### Essential Commands
```bash
./Scripts/setup-swiftlint.sh          # Xcode integration setup
./Scripts/setup-pre-commit-hooks.sh   # Git hooks setup
swift run swiftlint lint              # Manual check
swift run swiftlint --autocorrect     # Fix style issues
git commit                            # Triggers pre-commit checks
```

### Key Integration Points
- **Xcode Build Phase**: Runs before compilation
- **Pre-commit Hook**: Runs before each commit
- **CI/CD Pipeline**: Runs on every PR/push
- **Local Development**: Manual and automated checks

**For questions about development integration, refer to the main SwiftLint Usage Guide or create an issue in the repository.**