//
//  AppConfiguration.swift
//  Traveling Snails
//
//

import Foundation

/// Application configuration for retry logic and error handling
enum AppConfiguration {
    
    // MARK: - Environment Detection
    
    /// Current app environment
    static var environment: Environment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .preview
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .test
        } else {
            return .development
        }
        #else
        return .production
        #endif
    }
    
    /// Available app environments
    enum Environment {
        case development
        case test
        case preview
        case production
    }
    
    // MARK: - Retry Configuration
    
    /// Configuration for retry logic
    struct RetryConfiguration {
        /// Maximum number of retry attempts
        let maxAttempts: Int
        
        /// Base delay for exponential backoff (in seconds)
        let baseDelay: TimeInterval
        
        /// Maximum delay between retries (in seconds)
        let maxDelay: TimeInterval
        
        /// Whether to use exponential backoff
        let useExponentialBackoff: Bool
        
        /// Timeout for individual operations (in seconds)
        let operationTimeout: TimeInterval
        
        /// Calculate delay for a given retry attempt
        func delay(for attempt: Int) -> TimeInterval {
            guard useExponentialBackoff else { return baseDelay }
            
            let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
            return min(exponentialDelay, maxDelay)
        }
    }
    
    // MARK: - Default Configurations
    
    /// Default retry configuration for network operations
    static var networkRetry: RetryConfiguration {
        switch environment {
        case .development, .preview:
            return RetryConfiguration(
                maxAttempts: 3,
                baseDelay: 1.0,
                maxDelay: 8.0,
                useExponentialBackoff: true,
                operationTimeout: 30.0
            )
        case .test:
            // Faster retries for tests
            return RetryConfiguration(
                maxAttempts: 2,
                baseDelay: 0.1,
                maxDelay: 0.5,
                useExponentialBackoff: true,
                operationTimeout: 5.0
            )
        case .production:
            return RetryConfiguration(
                maxAttempts: 5,
                baseDelay: 2.0,
                maxDelay: 32.0,
                useExponentialBackoff: true,
                operationTimeout: 60.0
            )
        }
    }
    
    /// Retry configuration for database operations
    static var databaseRetry: RetryConfiguration {
        switch environment {
        case .development, .preview:
            return RetryConfiguration(
                maxAttempts: 2,
                baseDelay: 0.5,
                maxDelay: 2.0,
                useExponentialBackoff: false,
                operationTimeout: 10.0
            )
        case .test:
            return RetryConfiguration(
                maxAttempts: 1,
                baseDelay: 0.1,
                maxDelay: 0.1,
                useExponentialBackoff: false,
                operationTimeout: 2.0
            )
        case .production:
            return RetryConfiguration(
                maxAttempts: 3,
                baseDelay: 1.0,
                maxDelay: 5.0,
                useExponentialBackoff: true,
                operationTimeout: 15.0
            )
        }
    }
    
    /// Retry configuration for CloudKit sync operations
    static var syncRetry: RetryConfiguration {
        switch environment {
        case .development, .preview:
            return RetryConfiguration(
                maxAttempts: 3,
                baseDelay: 2.0,
                maxDelay: 16.0,
                useExponentialBackoff: true,
                operationTimeout: 120.0
            )
        case .test:
            return RetryConfiguration(
                maxAttempts: 2,
                baseDelay: 0.2,
                maxDelay: 1.0,
                useExponentialBackoff: true,
                operationTimeout: 10.0
            )
        case .production:
            return RetryConfiguration(
                maxAttempts: 5,
                baseDelay: 5.0,
                maxDelay: 60.0,
                useExponentialBackoff: true,
                operationTimeout: 300.0
            )
        }
    }
    
    /// Retry configuration for CloudKit quota exceeded errors
    static var quotaExceededRetry: RetryConfiguration {
        switch environment {
        case .development, .preview:
            return RetryConfiguration(
                maxAttempts: 3,
                baseDelay: 30.0,  // 30 seconds
                maxDelay: 180.0,  // 3 minutes
                useExponentialBackoff: false,
                operationTimeout: 300.0
            )
        case .test:
            return RetryConfiguration(
                maxAttempts: 2,
                baseDelay: 1.0,
                maxDelay: 2.0,
                useExponentialBackoff: false,
                operationTimeout: 10.0
            )
        case .production:
            return RetryConfiguration(
                maxAttempts: 5,
                baseDelay: 60.0,  // 1 minute
                maxDelay: 600.0,  // 10 minutes
                useExponentialBackoff: false,
                operationTimeout: 600.0
            )
        }
    }
    
    // MARK: - Error Analytics Configuration
    
    /// Configuration for error analytics and history
    struct AnalyticsConfiguration {
        /// Maximum number of error events to keep in history
        let maxHistorySize: Int
        
        /// Maximum age of error events to keep (in seconds)
        let maxEventAge: TimeInterval
        
        /// Interval between cleanup operations (in seconds)
        let cleanupInterval: TimeInterval
        
        /// Time window for detecting rapid consecutive errors (in seconds)
        let rapidErrorWindow: TimeInterval
        
        /// Minimum error count to trigger pattern detection
        let minPatternCount: Int
    }
    
    /// Error analytics configuration
    static var errorAnalytics: AnalyticsConfiguration {
        switch environment {
        case .development, .preview:
            return AnalyticsConfiguration(
                maxHistorySize: 100,
                maxEventAge: 7200,      // 2 hours
                cleanupInterval: 600,    // 10 minutes
                rapidErrorWindow: 60,    // 1 minute
                minPatternCount: 3
            )
        case .test:
            return AnalyticsConfiguration(
                maxHistorySize: 20,
                maxEventAge: 300,        // 5 minutes
                cleanupInterval: 60,     // 1 minute
                rapidErrorWindow: 10,    // 10 seconds
                minPatternCount: 2
            )
        case .production:
            return AnalyticsConfiguration(
                maxHistorySize: 50,
                maxEventAge: 3600,       // 1 hour
                cleanupInterval: 300,    // 5 minutes
                rapidErrorWindow: 120,   // 2 minutes
                minPatternCount: 5
            )
        }
    }
    
    // MARK: - Error State Configuration
    
    /// Configuration for error state management
    struct ErrorStateConfiguration {
        /// Time after which an error state is considered stale (in seconds)
        let staleTimeout: TimeInterval
        
        /// Maximum retry attempts to show in UI
        let maxVisibleRetries: Int
    }
    
    /// Error state configuration
    static var errorState: ErrorStateConfiguration {
        switch environment {
        case .development, .preview:
            return ErrorStateConfiguration(
                staleTimeout: 300,      // 5 minutes
                maxVisibleRetries: 3
            )
        case .test:
            return ErrorStateConfiguration(
                staleTimeout: 60,       // 1 minute
                maxVisibleRetries: 2
            )
        case .production:
            return ErrorStateConfiguration(
                staleTimeout: 600,      // 10 minutes
                maxVisibleRetries: 5
            )
        }
    }
    
    // MARK: - CloudKit Batch Configuration
    
    /// Configuration for CloudKit batch operations
    struct BatchConfiguration {
        /// Maximum records per CloudKit batch
        let maxRecordsPerBatch: Int
        
        /// Delay between batch operations (in milliseconds)
        let batchDelay: Int
    }
    
    /// CloudKit batch configuration
    static var cloudKitBatch: BatchConfiguration {
        switch environment {
        case .development, .preview:
            return BatchConfiguration(
                maxRecordsPerBatch: 200,
                batchDelay: 300
            )
        case .test:
            return BatchConfiguration(
                maxRecordsPerBatch: 50,
                batchDelay: 50
            )
        case .production:
            return BatchConfiguration(
                maxRecordsPerBatch: 400,  // CloudKit limit
                batchDelay: 500
            )
        }
    }
    
    // MARK: - Custom Configuration Support
    
    /// Storage for custom configurations (useful for testing)
    private static var customConfigurations: [String: Any] = [:]
    
    /// Register a custom configuration
    static func setCustomConfiguration<T>(_ config: T, for key: String) {
        customConfigurations[key] = config
    }
    
    /// Get a custom configuration
    static func getCustomConfiguration<T>(for key: String, default: T) -> T {
        return customConfigurations[key] as? T ?? `default`
    }
    
    /// Clear all custom configurations
    static func clearCustomConfigurations() {
        customConfigurations.removeAll()
    }
}