# Logging Security Guidelines

This document outlines the security guidelines for logging in the Traveling Snails app to protect user privacy and sensitive data.

## 🚨 Critical Security Rules

### NEVER LOG These Types of Data:
- **Trip Names**: Never log actual trip names (e.g., "Summer Vacation 2024", "Business Trip to Seattle")
- **Personal Information**: User names, addresses, phone numbers, email addresses
- **Financial Data**: Costs, prices, amounts, payment information
- **File Content**: File names, file paths, file contents, or attachment details
- **Location Data**: Specific addresses, coordinates, or destination details
- **Notes/Descriptions**: User-entered notes, descriptions, or personal details
- **Authentication Data**: Biometric states, authentication tokens, or security credentials

### ALWAYS USE Instead:
- **Generic Identifiers**: Trip IDs, Activity IDs, User IDs
- **Counts and Status**: Number of items, operation success/failure
- **System Information**: Component names, operation types, flow states

## ✅ Safe Logging Patterns

### Use Logger Framework (NOT print statements)
```swift
// ✅ CORRECT - Use Logger with appropriate category
Logger.shared.debug("Trip operation completed for ID: \(trip.id)", category: .dataImport)
Logger.shared.info("Activity count updated: \(activities.count)", category: .ui)
Logger.shared.error("Sync operation failed: \(error.localizedDescription)", category: .sync)

// ❌ WRONG - Never use print statements
print("Processing trip: \(trip.name)")
```

### Debug-Only Logging
```swift
// ✅ CORRECT - Wrap debug logging in conditional compilation
#if DEBUG
Logger.shared.debug("Navigation state updated for trip ID: \(trip.id)", category: .navigation)
#endif

// ❌ WRONG - Debug info exposed in production
Logger.shared.debug("Navigation state updated for trip: \(trip.name)", category: .navigation)
```

### Error Logging
```swift
// ✅ CORRECT - Log error without sensitive context
Logger.shared.error("Failed to save trip: \(error.localizedDescription)", category: .database)

// ❌ WRONG - Error message includes sensitive data
Logger.shared.error("Failed to save trip '\(trip.name)': \(error)", category: .database)
```

## 📝 Approved Logging Categories

Use these predefined Logger categories:
- `.app` - General application events
- `.database` - Database operations
- `.sync` - CloudKit/sync operations
- `.ui` - User interface events
- `.navigation` - Navigation state changes
- `.fileAttachment` - File operations (sanitized)
- `.export` - Data export operations
- `.dataImport` - Data import operations
- `.cloudKit` - CloudKit specific operations

## 🔍 Security Testing

### Required Tests
All logging code must pass the security tests in `LoggingSecurityTests.swift`:
- `detectTripNameExposure` - Ensures no trip names are logged
- `detectPersonalInformation` - Catches personal data logging
- `detectModelObjectPrinting` - Prevents model dumping
- `safeLoggingPatterns` - Validates safe logging practices

### Running Security Tests
```bash
xcodebuild test -scheme "Traveling Snails" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"Traveling Snails Tests/LoggingSecurityTests"
```

## 📋 Code Review Checklist

Before committing code, verify:
- [ ] No `print()` statements in production code
- [ ] All logging uses the Logger framework
- [ ] No sensitive data (names, costs, addresses) in log messages
- [ ] Debug logging is wrapped in `#if DEBUG` guards
- [ ] Error messages are sanitized to remove sensitive context
- [ ] Model objects are not printed directly
- [ ] Security tests pass

## 🚫 Common Violations and Fixes

### Trip Name Logging
```swift
// ❌ VIOLATION
print("Processing trip: \(trip.name)")
Logger.shared.debug("Trip updated: \(trip.name)", category: .database)

// ✅ FIXED
#if DEBUG
Logger.shared.debug("Trip updated for ID: \(trip.id)", category: .database)
#endif
```

### Cost/Financial Data
```swift
// ❌ VIOLATION
print("Activity cost updated to: \(cost)")
Logger.shared.debug("Cost changed from \(oldCost) to \(newCost)", category: .ui)

// ✅ FIXED
#if DEBUG
Logger.shared.debug("Activity cost field updated", category: .ui)
#endif
```

### File Information
```swift
// ❌ VIOLATION
print("Processing file: \(fileName)")
Logger.shared.debug("File path: \(filePath)", category: .fileAttachment)

// ✅ FIXED
#if DEBUG
Logger.shared.debug("File attachment processed - Type: \(fileExtension)", category: .fileAttachment)
#endif
```

### Model Object Dumping
```swift
// ❌ VIOLATION
print("Trip details: \(trip)")
Logger.shared.debug("Activity data: \(activity)", category: .database)

// ✅ FIXED
#if DEBUG
Logger.shared.debug("Trip operation completed for ID: \(trip.id)", category: .database)
#endif
```

## 🛡️ Security Incident Response

If sensitive data logging is discovered:
1. **Immediate**: Remove the logging statement
2. **Test**: Run security tests to verify fix
3. **Audit**: Search for similar patterns in codebase
4. **Review**: Update this document if new patterns emerge

## 📚 References

- Logger implementation: `Traveling Snails/Helpers/Logger.swift`
- Security tests: `Traveling Snails Tests/Security Tests/LoggingSecurityTests.swift`
- Issue tracking: GitHub Issue #39

## 🔄 Document Updates

This document should be updated whenever:
- New logging patterns are identified
- Security violations are discovered
- Additional test cases are needed
- New categories are added to the Logger

---
**Remember**: When in doubt, don't log it. User privacy is paramount.