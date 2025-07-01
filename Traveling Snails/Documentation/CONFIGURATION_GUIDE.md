# Configuration Guide

This guide explains the configuration system for retry logic and error handling in the Traveling Snails app.

## Overview

The `AppConfiguration` enum provides centralized, environment-specific configuration for:
- Retry logic (attempts, delays, timeouts)
- Error analytics and history management
- CloudKit batch processing
- Error state management

## Environment Detection

The configuration automatically adapts based on the current environment:

```swift
// AppConfiguration automatically detects:
- .development  // Running in Xcode
- .test        // Running unit tests
- .preview     // SwiftUI previews
- .production  // Release builds
```

## Configuration Categories

### 1. Network Retry Configuration

Controls retry behavior for network operations:

```swift
AppConfiguration.networkRetry
```

**Default Values:**
- Development: 3 attempts, 1s base delay, 30s timeout
- Test: 2 attempts, 0.1s base delay, 5s timeout  
- Production: 5 attempts, 2s base delay, 60s timeout

### 2. Database Retry Configuration

Controls retry behavior for database operations:

```swift
AppConfiguration.databaseRetry
```

**Default Values:**
- Development: 2 attempts, 0.5s delay, 10s timeout
- Test: 1 attempt, 0.1s delay, 2s timeout
- Production: 3 attempts, 1s base delay, 15s timeout

### 3. Sync Retry Configuration

Controls retry behavior for CloudKit sync operations:

```swift
AppConfiguration.syncRetry
```

**Default Values:**
- Development: 3 attempts, 2s base delay, 120s timeout
- Test: 2 attempts, 0.2s base delay, 10s timeout
- Production: 5 attempts, 5s base delay, 300s timeout

### 4. Quota Exceeded Retry Configuration

Special configuration for CloudKit quota exceeded errors:

```swift
AppConfiguration.quotaExceededRetry
```

**Default Values:**
- Development: 3 attempts, 30s delay, 300s timeout
- Test: 2 attempts, 1s delay, 10s timeout
- Production: 5 attempts, 60s delay, 600s timeout

### 5. Error Analytics Configuration

Controls error history and pattern detection:

```swift
AppConfiguration.errorAnalytics
```

**Settings:**
- `maxHistorySize`: Maximum error events to keep
- `maxEventAge`: How long to keep error events
- `cleanupInterval`: How often to clean up old events
- `rapidErrorWindow`: Time window for detecting rapid errors
- `minPatternCount`: Minimum errors to trigger pattern detection

### 6. CloudKit Batch Configuration

Controls CloudKit batch processing:

```swift
AppConfiguration.cloudKitBatch
```

**Settings:**
- `maxRecordsPerBatch`: Maximum records per CloudKit batch (400 limit)
- `batchDelay`: Delay between batch operations in milliseconds

## Usage Examples

### Basic Usage

```swift
// Get retry configuration
let config = AppConfiguration.networkRetry

// Calculate delay for retry attempt
let delay = config.delay(for: attemptNumber)

// Check max attempts
if retryCount < config.maxAttempts {
    // Retry operation
}
```

### Error Recovery

```swift
// Generate recovery plan based on error type
let config = AppConfiguration.networkRetry
let recoveryPlan = TripEditErrorRecovery.generateRecoveryPlan(
    for: error,
    retryCount: currentRetryCount
)
```

### Sync Operations

```swift
// Configure batch processing
let batchConfig = AppConfiguration.cloudKitBatch
let totalBatches = (recordCount + batchConfig.maxRecordsPerBatch - 1) / batchConfig.maxRecordsPerBatch

// Add delay between batches
try await Task.sleep(for: .milliseconds(batchConfig.batchDelay))
```

## Custom Configuration (For Testing)

You can override configurations for testing:

```swift
// Set custom configuration
AppConfiguration.setCustomConfiguration(
    AppConfiguration.RetryConfiguration(
        maxAttempts: 1,
        baseDelay: 0.1,
        maxDelay: 0.1,
        useExponentialBackoff: false,
        operationTimeout: 1.0
    ),
    for: "testRetryConfig"
)

// Use custom configuration
let config = AppConfiguration.getCustomConfiguration(
    for: "testRetryConfig",
    default: AppConfiguration.networkRetry
)

// Clear custom configurations after test
AppConfiguration.clearCustomConfigurations()
```

## Exponential Backoff

The retry configuration supports exponential backoff:

```swift
// With exponential backoff enabled:
// Attempt 1: baseDelay * 2^0 = 1s
// Attempt 2: baseDelay * 2^1 = 2s  
// Attempt 3: baseDelay * 2^2 = 4s
// (capped at maxDelay)
```

## Environment-Specific Behavior

### Development
- Moderate retry attempts with reasonable delays
- More verbose error tracking
- Faster cleanup cycles

### Test
- Minimal retry attempts with very short delays
- Reduced history size for memory efficiency
- Fast timeouts to prevent test hanging

### Production
- Maximum retry attempts for reliability
- Longer delays to avoid overwhelming services
- Extended error history for debugging

## Best Practices

1. **Always use configuration values** instead of hardcoding
2. **Consider the environment** when setting timeouts
3. **Use appropriate configurations** for different error types
4. **Monitor retry patterns** to detect systematic issues
5. **Test with different configurations** to ensure robustness

## Migration from Hardcoded Values

If you find hardcoded retry logic:

```swift
// ❌ Old way (hardcoded)
if retryCount <= 3 {
    let delay = pow(2.0, Double(retryCount))
    // retry...
}

// ✅ New way (configured)
let config = AppConfiguration.networkRetry
if retryCount < config.maxAttempts {
    let delay = config.delay(for: retryCount)
    // retry...
}
```

## Monitoring and Debugging

The configuration system integrates with the logging system:

```swift
// Logs include configuration context
Logger.shared.info("Retry attempt \(attempt)/\(config.maxAttempts)")
Logger.shared.info("Waiting \(delay)s before retry")
```

Check logs to understand retry behavior and tune configurations as needed.