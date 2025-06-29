# SwiftLint Guidelines for Traveling Snails

This document describes the SwiftLint configuration, security rules, and best practices for the Traveling Snails project.

## Overview

SwiftLint is integrated into our project with a focus on **security** and **modern Swift/SwiftUI patterns**. Our configuration enforces:

- Security-first coding practices
- Modern iOS 18+ patterns
- Consistent code style
- Prevention of common Swift pitfalls

## Security-Focused Rules

### 🚨 Critical Security Rules (Errors)

#### `no_print_statements`
- **Rule**: Prohibits all `print()` statements
- **Severity**: Error (builds will fail)
- **Reason**: Prevents accidental logging of sensitive data
- **Solution**: Use `Logger.shared.info()`, `.debug()`, `.warning()`, or `.error()` instead

```swift
// ❌ WRONG - Will cause build failure
print("User data: \(userData)")

// ✅ CORRECT - Secure logging
Logger.shared.debug("Processing user request")
```

#### `use_navigation_stack`
- **Rule**: Prohibits deprecated `NavigationView`
- **Severity**: Error
- **Reason**: Enforces modern iOS 16+ navigation patterns
- **Solution**: Use `NavigationStack` instead

```swift
// ❌ WRONG - Will cause build failure
NavigationView {
    ContentView()
}

// ✅ CORRECT - Modern pattern
NavigationStack {
    ContentView()
}
```

#### `no_state_object`
- **Rule**: Prohibits `@StateObject` and `@ObservableObject`
- **Severity**: Error
- **Reason**: Enforces modern iOS 17+ observation patterns
- **Solution**: Use `@Observable` classes with `@State` instead

```swift
// ❌ WRONG - Will cause build failure
@StateObject private var viewModel = ViewModel()

// ✅ CORRECT - Modern pattern
@State private var viewModel = ViewModel()
```

### ⚠️ Security Warnings

#### `no_sensitive_logging`
- **Rule**: Detects potential sensitive data in logging
- **Severity**: Warning
- **Triggers**: Patterns like `trip.name`, `user.`, `password`, `token`, `secret`
- **Action**: Manual review required

#### `safe_error_messages`
- **Rule**: Ensures error messages don't expose internal details
- **Severity**: Warning
- **Triggers**: Keywords like `internal`, `private`, `debug`, `stack` in error messages

#### `no_swiftdata_parameter_passing`
- **Rule**: Detects SwiftData model arrays passed as parameters
- **Severity**: Warning
- **Reason**: Prevents infinite view recreation bugs
- **Solution**: Use `@Query` directly in consuming views

```swift
// ❌ WRONG - Can cause infinite recreation
struct ActivityListView: View {
    let activities: [Activity]  // Parameter passing
}

// ✅ CORRECT - Direct querying
struct ActivityListView: View {
    @Query private var activities: [Activity]
}
```

## Modern Swift Patterns Enforced

### SwiftUI Patterns
- **`NavigationStack`** over `NavigationView`
- **`@Observable`** over `@StateObject`/@ObservableObject`
- **Proper SwiftData usage** with `@Query` and `@Environment(\.modelContext)`

### Localization Patterns
- **L10n enum system** over `NSLocalizedString`
- **Hardcoded string detection** for UI elements

### Code Style Patterns
- **Sorted imports**
- **Implicit returns** in closures and computed properties
- **Trailing commas** in multi-line collections
- **Proper file headers**
- **Consistent naming conventions**

## Configuration Details

### File Inclusion/Exclusion

```yaml
included:
  - Traveling Snails      # Main app code
  - Traveling Snails Tests # Test code

excluded:
  - .build               # Build artifacts
  - .swiftpm            # Package manager
  - Packages            # Dependencies
  - "*/Generated"       # Generated code
  - DerivedData         # Xcode artifacts
```

### Rule Severity Levels

- **Error**: Fails builds, must be fixed
- **Warning**: Shows in build output, recommended to fix
- **Disabled**: Rules that don't apply to our project

### Warning Threshold
- **Limit**: 10 warnings maximum
- **Reason**: Encourages fixing issues promptly
- **Override**: Increase temporarily for large refactoring

## Local Development Workflow

### Setup
```bash
# Initial setup (run once)
./Scripts/setup-swiftlint.sh

# Or manually
swift package resolve
```

### Daily Usage
```bash
# Check for violations
swift run swiftlint lint

# Auto-fix style issues (safe changes only)
swift run swiftlint --autocorrect

# Check specific file
swift run swiftlint lint "Traveling Snails/Views/SomeView.swift"

# Generate detailed report
swift run swiftlint lint --reporter json > swiftlint-report.json
```

### Xcode Integration

1. **Automatic**: Add Run Script Phase via `./Scripts/setup-swiftlint.sh`
2. **Manual**: Copy content from `Scripts/swiftlint-build-script.sh`
3. **Build Integration**: Runs before compilation, fails build on errors

## CI/CD Integration

### GitHub Actions
- **Workflow**: `.github/workflows/swiftlint.yml`
- **Triggers**: All pushes and pull requests
- **Features**:
  - Security violation detection
  - Automatic style corrections
  - Report generation
  - Artifact upload

### Security Checks
The CI pipeline specifically checks for:
- Print statement violations (fails build)
- Sensitive data logging patterns
- High violation counts
- Critical security issues

## Common Violations and Fixes

### 1. Print Statements
```swift
// ❌ Violation
print("Debug info: \(data)")

// ✅ Fix
Logger.shared.debug("Debug info processed")
```

### 2. Deprecated Navigation
```swift
// ❌ Violation
NavigationView {
    List { /* content */ }
}

// ✅ Fix
NavigationStack {
    List { /* content */ }
}
```

### 3. Old Observation Patterns
```swift
// ❌ Violation
class ViewModel: ObservableObject {
    @Published var data: String = ""
}

// ✅ Fix
@Observable
class ViewModel {
    var data: String = ""
}
```

### 4. SwiftData Parameter Passing
```swift
// ❌ Violation
struct TripDetailView: View {
    let activities: [Activity]
}

// ✅ Fix
struct TripDetailView: View {
    let trip: Trip
    @Query private var activities: [Activity]
    
    init(trip: Trip) {
        self.trip = trip
        self._activities = Query(
            filter: #Predicate<Activity> { $0.trip?.id == trip.id }
        )
    }
}
```

### 5. Hardcoded Strings
```swift
// ❌ Violation
Text("Hello World")

// ✅ Fix
Text(L10n.helloWorld)
```

## Disabling Rules (Use Sparingly)

### Temporary Disabling
```swift
// swiftlint:disable:next rule_name
problematic_code()

// swiftlint:disable rule_name
// Multiple lines of code
// swiftlint:enable rule_name
```

### File-Level Disabling
```swift
// swiftlint:disable file_header
// For files that need custom headers
```

### When to Disable
- **Generated code**: Always disable for auto-generated files
- **Third-party code**: Disable for external dependencies
- **Temporary situations**: During large refactoring (re-enable ASAP)
- **False positives**: When rule incorrectly flags valid code

## Customizing Rules

### Adding New Rules
1. Edit `.swiftlint.yml`
2. Add to `custom_rules` section
3. Test with sample violations
4. Update this documentation

### Modifying Existing Rules
1. Change severity or configuration in `.swiftlint.yml`
2. Test impact on codebase
3. Update team via documentation
4. Consider migration period for breaking changes

## Performance Considerations

### Large Codebases
- SwiftLint analyzes 156+ Swift files
- Build time impact: ~5-10 seconds
- CI/CD impact: ~30-60 seconds
- Memory usage: Minimal

### Optimization Tips
- Use `.swiftlint.yml` exclusions for build directories
- Consider separate configs for different targets
- Run incrementally during development

## Troubleshooting

### Common Issues

#### "SwiftLint not found"
```bash
# Check installation
which swiftlint
swift run swiftlint version

# Reinstall if needed
brew install swiftlint
# OR
swift package resolve
```

#### "Configuration warnings"
- Usually about disabled rules with configurations
- Safe to ignore or fix by removing unused configs

#### "Build failures in Xcode"
- Check Build Phases for SwiftLint script
- Verify script path and permissions
- Check `.swiftlint.yml` syntax

#### "Too many violations"
- Use `swift run swiftlint --autocorrect` for style fixes
- Address errors first, then warnings
- Consider temporary rule disabling during migration

### Getting Help
- Check SwiftLint documentation: https://github.com/realm/SwiftLint
- Review project-specific rules in `.swiftlint.yml`
- Ask team members for project-specific guidance
- Use `swift run swiftlint rules` to see all available rules

## Best Practices

### For Developers
1. **Run SwiftLint early and often** during development
2. **Use autocorrect** for style issues before committing
3. **Address errors immediately** - don't let them accumulate
4. **Understand why rules exist** rather than blindly following them
5. **Suggest improvements** when rules don't fit project needs

### For Code Reviews
1. **Check for SwiftLint violations** before approving PRs
2. **Ensure CI checks pass** before merging
3. **Discuss rule violations** rather than just fixing them
4. **Look for patterns** that might need new rules

### For Project Maintenance
1. **Review rules quarterly** to ensure they remain relevant
2. **Update SwiftLint version** regularly for new features
3. **Monitor violation trends** to identify training needs
4. **Keep documentation current** as rules evolve

---

## Related Documentation

- [CLAUDE.md](CLAUDE.md) - Development principles and patterns
- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall project architecture
- [SwiftData-Patterns.md](SwiftData-Patterns.md) - Data layer best practices
- [Development-Workflow.md](Development-Workflow.md) - General development workflow

---

*This document is maintained as part of the Traveling Snails project documentation. Last updated: 2025-06-29*