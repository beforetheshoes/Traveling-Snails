# SwiftLint Usage Guide for Traveling Snails

This comprehensive guide covers everything developers need to know about using SwiftLint in the Traveling Snails project, from basic usage to advanced customization and CI integration.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Project-Specific Rules](#project-specific-rules)
3. [Security-Focused Rules](#security-focused-rules)
4. [SwiftData Patterns](#swiftdata-patterns)
5. [Modern Swift Patterns](#modern-swift-patterns)
6. [Development Workflows](#development-workflows)
7. [CI/CD Integration](#cicd-integration)
8. [Troubleshooting](#troubleshooting)
9. [Performance Optimization](#performance-optimization)
10. [Contributing & Customization](#contributing--customization)

## Quick Start

### Installation

The project uses Swift Package Manager for SwiftLint. The setup is automated through scripts:

```bash
# Run the automated setup script
./Scripts/setup-swiftlint.sh

# Or install manually
swift package resolve
swift build
```

### Basic Commands

```bash
# Lint all files
swift run swiftlint lint

# Lint with autocorrect (safe fixes only)
swift run swiftlint --autocorrect

# Lint specific files
swift run swiftlint lint path/to/file.swift

# Generate report for CI
swift run swiftlint lint --reporter json > swiftlint-report.json
```

### Xcode Integration

Add a build phase script to run SwiftLint automatically:

```bash
# Build Phase Script
if command -v swift >/dev/null 2>&1; then
    cd "${SRCROOT}"
    swift run swiftlint --autocorrect
    swift run swiftlint
else
    echo "warning: SwiftLint not installed"
fi
```

## Project-Specific Rules

### Security Rules

#### 1. No Print Statements (`no_print_statements`)

**Rule**: Enforces use of `Logger.shared` instead of `print()` statements.

```swift
// ❌ Avoid
print("Debug information: \(data)")

// ✅ Preferred
#if DEBUG
Logger.shared.debug("Debug information: \(data)", category: .debug)
#endif
```

**Exclusions**: Test files are excluded from this rule.

#### 2. No Sensitive Data Logging (`no_sensitive_logging`)

**Rule**: Prevents logging of potentially sensitive user data.

```swift
// ❌ Avoid
Logger.shared.info("User trip: \(trip.name)")
Logger.shared.debug("Password attempt: \(password)")

// ✅ Preferred
Logger.shared.info("User trip accessed")
Logger.shared.debug("Authentication attempt")
```

**Monitored Keywords** (refined patterns):
- `password`, `token`, `secret`, `apiKey`, `authKey`, `privateKey`, `accessKey`
- Rule uses simplified regex patterns to reduce false positives
- Focuses on truly sensitive authentication and security data

#### 3. Safe Error Messages (`safe_error_messages`)

**Rule**: Ensures error messages don't expose internal implementation details.

```swift
// ❌ Avoid
throw TripError.custom("Failed to save in modelContext.save() line 245")

// ✅ Preferred  
throw TripError.saveFailed("Unable to save trip data")
```

### Modern Swift Patterns

#### 1. Use NavigationStack (`use_navigation_stack`)

**Rule**: Enforces `NavigationStack` over deprecated `NavigationView`.

```swift
// ❌ Avoid
NavigationView {
    TripListView()
}

// ✅ Preferred
NavigationStack {
    TripListView()
}
```

#### 2. Use @Observable (`no_state_object`)

**Rule**: Promotes `@Observable` over `@StateObject`/`@ObservableObject` for iOS 17+.

```swift
// ❌ Avoid
@StateObject private var viewModel = TripViewModel()

// ✅ Preferred
@State private var viewModel = TripViewModel() // where TripViewModel uses @Observable
```

#### 3. Use L10n Enum (`use_l10n_enum`)

**Rule**: Encourages L10n enum system over `NSLocalizedString`.

```swift
// ❌ Avoid
Text(NSLocalizedString("trip.add.title", comment: ""))

// ✅ Preferred
Text(L10n.Trip.Add.title)
```

### SwiftData Patterns

#### 1. No Parameter Passing (`no_swiftdata_parameter_passing`)

**Rule**: Prevents the infinite recreation anti-pattern.

```swift
// ❌ Avoid - Causes infinite view recreation
struct TripView: View {
    let trips: [Trip]  // Parameter passing
    
    var body: some View { ... }
}

// ✅ Preferred - Use @Query directly
struct TripView: View {
    @Query private var trips: [Trip]  // Direct query
    
    var body: some View { ... }
}
```

#### 2. Input Validation (`require_input_validation`)

**Rule**: Ensures user input fields include validation.

```swift
// ❌ Avoid
TextField("Trip Name", text: $tripName)

// ✅ Preferred
TextField("Trip Name", text: $tripName)
    .onChange(of: tripName) { _, newValue in
        isValid = !newValue.isEmpty && newValue.count <= 100
    }
```

## Development Workflows

### Pre-Commit Hook

Set up automatic linting before commits:

```bash
# Install pre-commit hook
echo "swift run swiftlint --autocorrect && swift run swiftlint" > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Daily Development

1. **Before starting work**: Run `swift run swiftlint` to check current state
2. **During development**: Use autocorrect frequently: `swift run swiftlint --autocorrect`
3. **Before committing**: Ensure all violations are addressed
4. **PR creation**: Verify CI passes SwiftLint checks

### Handling Violations

#### Priority Order:
1. **Security violations** (errors) - Must fix immediately
2. **Modern Swift violations** (errors) - Fix before merge
3. **Code quality violations** (warnings) - Fix when convenient

#### Common Fixes:

```bash
# Auto-fix safe style issues
swift run swiftlint --autocorrect

# Generate detailed report for manual fixes
swift run swiftlint lint --reporter html > swiftlint-report.html
```

## CI/CD Integration

### GitHub Actions Workflow

The project includes a comprehensive GitHub Actions workflow (`.github/workflows/swiftlint.yml`) that:

1. **Runs security analysis** with JSON parsing for robust violation detection
2. **Generates reports** with detailed breakdowns
3. **Fails builds** on critical security violations
4. **Provides summaries** in GitHub PR comments

### Key CI Features (Recently Optimized):

- **Single SwiftLint run with JSON output** for efficiency (eliminates redundant executions)
- **JSON-based parsing with jq** for robust error handling and better performance
- **Security-focused violation detection** with specific error codes
- **Artifact upload** of detailed reports with 30-day retention
- **GitHub Actions annotations** for inline PR feedback
- **Performance monitoring** with violation count tracking
- **Optimized caching** using Swift Package Manager cache keys

### Local CI Simulation:

```bash
# Run the same checks as CI (optimized workflow)
swift run swiftlint lint --config .swiftlint.yml --parallel --reporter json > violations.json

# Check for security violations using refined patterns
jq '[.[] | select(.rule_id | test("no_print_statements|no_sensitive_logging|safe_error_messages"))] | length' violations.json

# Count violations by severity
jq '[.[] | .severity] | group_by(.) | map({severity: .[0], count: length})' violations.json

# Check for critical print statement violations
PRINT_COUNT=$(jq '[.[] | select(.rule_id == "no_print_statements" and .severity == "error")] | length' violations.json)
if [ "$PRINT_COUNT" -gt 0 ]; then
  echo "Critical: $PRINT_COUNT print statement violations found"
  exit 1
fi
```

## Troubleshooting

### Common Issues

#### 1. SwiftLint Not Found
```bash
# Verify installation
swift run swiftlint version

# Reinstall if needed
swift package clean
swift package resolve
swift build
```

#### 2. False Positives

For legitimate violations that should be ignored:

```swift
// swiftlint:disable:next no_print_statements
print("This is intentionally a print statement")

// Or disable for entire file
// swiftlint:disable no_print_statements
```

#### 3. Performance Issues

```bash
# Use parallel processing
swift run swiftlint lint --parallel

# Lint only changed files
git diff --name-only --diff-filter=AMR | grep ".swift$" | xargs swift run swiftlint lint
```

### Debugging Custom Rules

```bash
# Test specific rule
swift run swiftlint lint --enable-rule no_print_statements

# Verbose output for debugging
swift run swiftlint lint --verbose
```

## Performance Optimization

### Build Script Integration

Use the optimized build script for better performance:

```bash
./Scripts/swiftlint-build-script.sh
```

### Selective Rule Running

For large codebases, use rule subsets:

```bash
# Security rules only
swift run swiftlint lint --enable-rule no_print_statements,no_sensitive_logging,safe_error_messages

# Modern Swift rules only  
swift run swiftlint lint --enable-rule use_navigation_stack,no_state_object,use_l10n_enum
```

### Caching Strategy

The project uses SPM caching for faster CI runs:

```yaml
- name: Cache Swift Package Manager
  uses: actions/cache@v4
  with:
    path: |
      .build
      SourcePackages
    key: ${{ runner.os }}-spm-${{ hashFiles('Package.swift', 'Package.resolved') }}
```

## Contributing & Customization

### Adding New Rules

1. **Identify the pattern** you want to enforce/prevent
2. **Write the regex** with proper exclusions for comments and tests
3. **Test thoroughly** to avoid false positives
4. **Add to `.swiftlint.yml`** with appropriate severity

#### Example Rule Addition:

```yaml
custom_rules:
  my_new_rule:
    name: "My New Rule"
    regex: '(?<!//\s*)(?<!/\*[\s\S]*?)pattern_to_match'
    message: "Helpful message explaining what to do instead"
    severity: warning
    excluded: ".*Tests.*\\.swift$"
```

### Testing Rules

```bash
# Test rule against specific files
echo 'let test = "problematic pattern"' | swift run swiftlint lint --enable-rule my_new_rule --use-stdin --path test.swift
```

### Rule Severity Guidelines

- **Error**: Security issues, deprecated API usage, critical anti-patterns
- **Warning**: Code quality, style preferences, potential issues
- **Info**: Suggestions, best practices

### Regular Rule Maintenance

1. **Monthly review** of violation patterns
2. **Update regex patterns** based on false positives
3. **Adjust severity levels** based on team feedback
4. **Document new patterns** in this guide

### Recent Pattern Refinements (Latest Update)

The custom rules have been simplified for better reliability and fewer false positives:

#### Pattern Improvements:
- **Simplified regex patterns** to reduce complexity and improve maintainability
- **Removed overly complex negative lookbehinds** that caused parsing errors
- **Enhanced exclusions** for test files and preview content
- **Focused security detection** on the most critical patterns

#### Before/After Examples:

```yaml
# Old complex pattern (caused parsing issues)
regex: '(?<!//\s*)(?<!#if\s+DEBUG\s*\n\s*)(?<!/\*[\s\S]*?)\bprint\s*\('

# New simplified pattern (reliable and fast)
regex: '\bprint\s*\('
```

This approach prioritizes:
- ✅ **Reliability** over complexity
- ✅ **Performance** in CI environments  
- ✅ **Maintainability** for future updates
- ✅ **Reduced false negatives** while accepting some false positives that can be addressed with exclusions

## Advanced Configuration

### File-Specific Overrides

```yaml
# In .swiftlint.yml
included:
  - Traveling Snails
  - Traveling Snails Tests

excluded:
  - Generated
  - Pods
  - .build

# Rule-specific exclusions
custom_rules:
  no_print_statements:
    excluded: ".*Tests.*\\.swift$|.*Preview.*\\.swift$"
```

### Environment-Specific Rules

```bash
# Development environment
export SWIFTLINT_CONFIG=.swiftlint.yml

# CI environment with stricter rules
export SWIFTLINT_CONFIG=.swiftlint-ci.yml
```

### Integration with Other Tools

```bash
# Combine with other linters
swift run swiftlint lint && swiftformat . --lint
```

## Metrics and Monitoring

### Track Progress

```bash
# Generate metrics over time
swift run swiftlint lint --reporter json | jq '[.[] | .severity] | group_by(.) | map({severity: .[0], count: length})'
```

### Quality Gates

Set up quality gates based on violation counts:

```bash
# Fail if more than 10 errors
ERRORS=$(swift run swiftlint lint --reporter json | jq '[.[] | select(.severity == "error")] | length')
if [ "$ERRORS" -gt 10 ]; then
  echo "Too many errors: $ERRORS"
  exit 1
fi
```

---

## Quick Reference

### Essential Commands
```bash
swift run swiftlint lint                    # Check all files
swift run swiftlint --autocorrect          # Fix style issues
swift run swiftlint lint --reporter json   # Generate JSON report
swift run swiftlint rules                  # List all rules
```

### Key Security Rules
- `no_print_statements` - Use Logger instead of print
- `no_sensitive_logging` - Don't log sensitive data
- `safe_error_messages` - Don't expose internals

### Key Modern Swift Rules
- `use_navigation_stack` - Use NavigationStack (iOS 16+)
- `no_state_object` - Use @Observable (iOS 17+)
- `use_l10n_enum` - Use L10n enum system

### SwiftData Rules
- `no_swiftdata_parameter_passing` - Use @Query, not parameters

**For questions or issues with SwiftLint integration, refer to the project documentation or create an issue in the repository.**