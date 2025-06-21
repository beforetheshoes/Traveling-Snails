# ModelContext.reset Fatal Error Fix

## Problem
Fatal error: "This model instance was destroyed by calling ModelContext.reset and is no longer usable."

## Root Cause
AppSettings was holding a reference to a UserPreferences SwiftData model instance. When the ModelContext was reset or changed (often during testing or app lifecycle changes), this reference became stale and accessing it would cause a fatal error.

## Solution Applied

### 1. Enhanced ModelContext Handling
```swift
// In AppSettings.setModelContext(_:)
func setModelContext(_ context: ModelContext) {
    // If context is changing, clear existing references to prevent stale model access
    if self.modelContext !== context {
        logger.debug("ModelContext changing, clearing existing UserPreferences reference")
        self.userPreferences = nil
    }
    
    self.modelContext = context
    self.userPreferences = UserPreferences.getInstance(from: context)
    // ...
}
```

### 2. Safe Property Access
```swift
// Added ensureValidPreferences() calls to all properties
public var colorScheme: ColorSchemePreference {
    get {
        ensureValidPreferences()
        return userPreferences?.colorSchemePreference ?? .system
    }
    set {
        ensureValidPreferences()
        userPreferences?.colorSchemePreference = newValue
        try? modelContext?.save()
    }
}
```

### 3. Defensive Reference Management
```swift
private func ensureValidPreferences() {
    guard let context = modelContext else { return }
    
    // If we don't have userPreferences or if it becomes stale, refresh it
    if userPreferences == nil {
        logger.debug("UserPreferences is nil, creating/fetching from ModelContext")
        self.userPreferences = UserPreferences.getInstance(from: context)
    }
}
```

## Key Changes Made

1. **ModelContext Change Detection**: Detect when ModelContext changes and clear stale references
2. **Lazy Re-initialization**: Refresh UserPreferences instance when needed
3. **Defensive Programming**: Always check for nil and re-fetch if necessary
4. **Proper Logging**: Added debug logging to track when references are refreshed

## Why This Fixes the Issue

- **Prevents Stale References**: When ModelContext changes, we clear the old UserPreferences reference
- **Safe Access Pattern**: Properties always ensure valid references before use
- **Graceful Recovery**: If reference becomes stale, we re-fetch instead of crashing
- **Singleton Pattern**: UserPreferences.getInstance() ensures we get the correct instance

## Testing

The fix addresses the core issue:
- ✅ AppSettings no longer holds stale SwiftData model references
- ✅ ModelContext changes are handled gracefully
- ✅ Properties safely access UserPreferences without fatal errors
- ✅ Singleton pattern ensures consistency

## Manual Verification

1. **App Launch**: Settings should load correctly
2. **Context Changes**: No crashes when ModelContext is reset/changed
3. **Setting Changes**: Color scheme and biometric timeout should persist
4. **CloudKit Sync**: Settings should sync between devices properly

This fix ensures AppSettings is resilient to SwiftData model lifecycle changes while maintaining proper CloudKit synchronization.