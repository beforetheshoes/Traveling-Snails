# Secure Logging Guidelines for Traveling Snails

## Overview

This document provides comprehensive security guidelines for logging in the Traveling Snails app to prevent exposure of sensitive user data while maintaining effective debugging capabilities.

## 🚨 Critical Security Rules

### **NEVER Log These Items:**
- **User personal information**: Names, email addresses, phone numbers
- **Trip details**: Trip names, destination names, personal notes, descriptions
- **Activity information**: Activity names, lodging names, restaurant names
- **Location data**: Street addresses, GPS coordinates, specific locations
- **Financial information**: Credit card numbers, costs, prices, booking confirmations
- **Security credentials**: Passwords, tokens, API keys, secrets
- **Model objects directly**: Never use `print(trip)` or `print(activity)`

### **Safe to Log:**
- **Object IDs**: UUIDs and identifiers (use `.public` privacy level)
- **Counts and statistics**: Number of trips, activities, lodging items
- **Status information**: Success/failure states, sync status
- **Performance metrics**: Timing, counts, technical statistics
- **System information**: OS version, app version, technical diagnostics

## 🛡️ Implementation Patterns

### 1. Use Logger Framework (NOT print statements)

✅ **CORRECT:**
```swift
import os

#if DEBUG
Logger().debug("Trip operation completed for ID: \(trip.id, privacy: .public)")
Logger().debug("Activity count: \(activities.count, privacy: .public)")
Logger().debug("Sync status: \(syncStatus, privacy: .public)")
#endif
```

❌ **WRONG:**
```swift
print("Processing trip: \(trip.name)")  // Exposes trip name!
print("Activity details: \(activity)")  // Exposes entire model!
print("User created: \(user.email)")    // Exposes email!
```

### 2. Always Use DEBUG Guards

All debugging logs must be wrapped in `#if DEBUG` preprocessor directives:

```swift
#if DEBUG
Logger().debug("Debug information here")
#endif
```

This ensures logs are completely removed from production builds.

### 3. Use Privacy Levels Correctly

- **`.public`**: Safe identifiers, counts, technical data
- **`.private`**: NEVER use for user data - only for truly sensitive technical info

```swift
// ✅ Safe patterns
Logger().debug("Operation completed for ID: \(id, privacy: .public)")
Logger().debug("Found \(count, privacy: .public) items")
Logger().debug("Status: \(status, privacy: .public)")

// ❌ NEVER do this
Logger().debug("Trip name: \(trip.name, privacy: .private)")  // Still wrong!
```

### 4. Safe Model Logging Patterns

**For Trip Objects:**
```swift
// ✅ CORRECT
#if DEBUG
Logger().debug("Trip created with ID: \(trip.id, privacy: .public)")
Logger().debug("Trip has \(trip.activities.count, privacy: .public) activities")
#endif

// ❌ WRONG
print("Trip: \(trip)")
print("Trip name: \(trip.name)")
```

**For Activity Objects:**
```swift
// ✅ CORRECT
#if DEBUG
Logger().debug("Activity saved with ID: \(activity.id, privacy: .public)")
Logger().debug("Activity cost range: \(costCategory, privacy: .public)")  // e.g., "low", "medium", "high"
#endif

// ❌ WRONG
print("Activity: \(activity.name)")
print("Activity details: \(activity)")
```

## 📋 Code Review Checklist

Before committing code, verify:

- [ ] No `print()` statements in production code
- [ ] All debug logs wrapped in `#if DEBUG`
- [ ] Using `Logger` framework instead of `print()`
- [ ] No model objects logged directly
- [ ] No sensitive user data in logs
- [ ] Privacy levels specified for all logged data
- [ ] IDs used instead of names/descriptions

## 🧪 Testing Security Compliance

The codebase includes comprehensive security tests in:
- `LoggingSecurityTests.swift` - General security patterns
- `CodebaseSecurityAuditTests.swift` - Specific codebase violations
- `TestLogHandler.swift` - Security detection utilities

Run security tests regularly:
```bash
xcodebuild test -scheme "Traveling Snails" -only-testing:"Traveling Snails Tests/LoggingSecurityTests"
xcodebuild test -scheme "Traveling Snails" -only-testing:"Traveling Snails Tests/CodebaseSecurityAuditTests"
```

## 🔍 Examples by Use Case

### Debug Empty Collections
```swift
// ✅ CORRECT
#if DEBUG
Logger().debug("Trip has \(trip.lodging.count, privacy: .public) lodging items")
for (index, lodging) in trip.lodging.enumerated() {
    Logger().debug("Lodging[\(index, privacy: .public)] ID: \(lodging.id, privacy: .public)")
}
#endif

// ❌ WRONG
print("DEBUG: lodging[\(index)] = \(lodging.name)")
```

### Error Handling
```swift
// ✅ CORRECT
#if DEBUG
Logger().debug("Save operation failed for trip ID: \(tripId, privacy: .public)")
Logger().error("Database error occurred: \(error.localizedDescription)")
#endif

// ❌ WRONG
print("Failed to save trip: \(trip)")
print("Error with user data: \(userData)")
```

### Performance Monitoring
```swift
// ✅ CORRECT
Logger().info("Import completed - Trips: \(tripsCount), Activities: \(activitiesCount)")
Logger().debug("Sync duration: \(duration, privacy: .public)ms")

// ❌ WRONG
print("Imported trips: \(tripNames.joined(separator: ", "))")
```

## ⚠️ Common Pitfalls

### 1. String Interpolation in Models
```swift
// ❌ DANGEROUS - Never override description to include sensitive data
extension Trip: CustomStringConvertible {
    var description: String {
        return "Trip: \(name) at \(location)"  // This would expose data in logs!
    }
}
```

### 2. Debugging Arrays
```swift
// ❌ WRONG
print("All trips: \(trips)")  // Prints entire trip objects!

// ✅ CORRECT
#if DEBUG
Logger().debug("Found \(trips.count, privacy: .public) trips with IDs: \(trips.map(\.id), privacy: .public)")
#endif
```

### 3. Test Code Violations
Even test code must follow security guidelines:
```swift
// ❌ WRONG in tests
print("Test trip name: \(testTrip.name)")

// ✅ CORRECT in tests
#if DEBUG
Logger().debug("Test trip created with ID: \(testTrip.id, privacy: .public)")
#endif
```

## 🚀 Migration Guide

When updating existing code:

1. **Find all print statements**: Search for `print(` in codebase
2. **Identify sensitive data**: Check if logs contain user/trip/activity names
3. **Replace with Logger**: Use appropriate Logger calls with privacy levels
4. **Add DEBUG guards**: Wrap all debug logs in `#if DEBUG`
5. **Test security**: Run security test suites to verify compliance

## 📚 Related Documentation

- **Logger.swift**: Core logging infrastructure
- **TestLogHandler.swift**: Security testing utilities
- **LoggingSecurityTests.swift**: Comprehensive security test patterns
- **CLAUDE.md**: Development guidelines including security requirements

## 🆘 When in Doubt

**ASK THESE QUESTIONS:**
1. Could this log expose user personal information?
2. Would I be comfortable if this appeared in a crash report?
3. Does this help debugging without revealing sensitive data?
4. Am I using IDs instead of names/descriptions?

**If unsure, err on the side of caution and use only:**
- Object IDs (UUIDs)
- Counts and statistics
- Technical status information
- Non-sensitive metadata

Remember: **User privacy and data security are non-negotiable.** When debugging, use IDs and counts instead of personal information.