import Testing

// MARK: - Comprehensive Test Tag Taxonomy for Traveling Snails
// This file defines a systematic tagging strategy that enables:
// 1. Flexible test execution based on available time
// 2. Parallel execution optimization
// 3. Granular test selection for debugging
// 4. CI/CD pipeline optimization

extension Tag {
    // MARK: - Primary Category Tags
    // These define the main test categories based on what is being tested

    @Tag static var unit: Self           // Unit tests - isolated component testing
    @Tag static var integration: Self    // Integration tests - multi-component interaction
    @Tag static var ui: Self            // UI tests - SwiftUI component and navigation testing
    @Tag static var accessibility: Self  // Accessibility tests - WCAG compliance and a11y
    @Tag static var performance: Self    // Performance tests - benchmarking and optimization
    @Tag static var security: Self      // Security tests - vulnerability detection
    @Tag static var swiftdata: Self     // SwiftData tests - database layer testing
    @Tag static var settings: Self      // Settings tests - app preferences and config
    @Tag static var stress: Self        // Stress tests - system behavior under load
    @Tag static var utility: Self       // Utility tests - test infrastructure and framework

    // MARK: - Execution Characteristic Tags
    // These define execution requirements and timing constraints

    @Tag static var fast: Self          // <30 seconds - Quick feedback tests
    @Tag static var medium: Self        // 30-90 seconds - Standard test duration
    @Tag static var slow: Self          // 90+ seconds - Comprehensive/complex tests
    @Tag static var critical: Self      // Must pass for other tests to be meaningful
    @Tag static var parallel: Self      // Safe for parallel execution
    @Tag static var serial: Self        // Must run sequentially (resource conflicts)

    // MARK: - Platform/Technology Tags
    // These define specific platform features or technologies being tested

    @Tag static var swiftui: Self       // SwiftUI-specific testing
    @Tag static var cloudkit: Self      // CloudKit integration testing
    @Tag static var concurrent: Self    // Swift concurrency testing
    @Tag static var mainActor: Self     // MainActor isolation testing
    @Tag static var async: Self         // Async/await pattern testing
    @Tag static var network: Self       // Network operations testing
    @Tag static var filesystem: Self    // File system operations testing
    @Tag static var biometric: Self     // Biometric authentication testing
    @Tag static var permissions: Self   // System permissions testing

    // MARK: - Component-Specific Tags
    // These target specific app components for focused testing

    @Tag static var trip: Self          // Trip-related functionality
    @Tag static var activity: Self      // Activity-related functionality
    @Tag static var navigation: Self    // Navigation and routing
    @Tag static var deepLinking: Self   // Deep linking functionality
    @Tag static var calendar: Self      // Calendar view and date handling
    @Tag static var fileAttachment: Self // File attachment functionality
    @Tag static var organization: Self  // Organization management
    @Tag static var sync: Self          // Data synchronization
    @Tag static var authentication: Self // User authentication
    @Tag static var localization: Self  // Internationalization and localization
    @Tag static var dataImport: Self    // Data import functionality
    @Tag static var dataExport: Self    // Data export functionality
    @Tag static var search: Self        // Search functionality testing
    @Tag static var transportation: Self // Transportation activity testing
    @Tag static var lodging: Self       // Lodging activity testing
    @Tag static var address: Self       // Address and location testing
    @Tag static var timezone: Self      // Timezone handling testing
    @Tag static var currency: Self      // Currency and financial testing
    @Tag static var state: Self         // State management testing

    // MARK: - Functional Area Tags
    // These group tests by functional areas for targeted testing

    @Tag static var dataModel: Self     // Core data model testing
    @Tag static var viewModel: Self     // View model and business logic
    @Tag static var userInterface: Self // User interface components
    @Tag static var errorHandling: Self // Error scenarios and recovery
    @Tag static var validation: Self    // Input validation and constraints
    @Tag static var caching: Self       // Caching mechanisms and strategies
    @Tag static var migration: Self     // Data migration and versioning
    @Tag static var logging: Self       // Logging and diagnostics
    @Tag static var consistency: Self   // Data consistency and integrity
    @Tag static var comprehensive: Self // Comprehensive testing coverage

    // MARK: - Quality Assurance Tags
    // These support different quality assurance activities

    @Tag static var regression: Self    // Regression prevention testing
    @Tag static var compatibility: Self // Backward/forward compatibility
    @Tag static var memory: Self        // Memory usage and leak detection
    @Tag static var deadlock: Self      // Deadlock and race condition detection
    @Tag static var boundary: Self      // Edge case and boundary testing
    @Tag static var negative: Self      // Negative case testing
    @Tag static var smoke: Self         // Smoke tests for basic functionality
    @Tag static var sanity: Self        // Sanity checks for critical paths

    // MARK: - Build and CI Tags
    // These support continuous integration and build processes

    @Tag static var build: Self         // Build-time validation
    @Tag static var preCommit: Self     // Pre-commit validation tests
    @Tag static var nightly: Self       // Nightly build comprehensive tests
    @Tag static var release: Self       // Release candidate validation
    @Tag static var hotfix: Self        // Critical hotfix validation
}

// MARK: - Tag Combination Helpers
// These provide convenient ways to combine tags for common scenarios

extension Tag {
    // MARK: - Quick Test Combinations
    static var quickFeedback: [Tag] { [.fast, .critical, .unit] }
    static var basicValidation: [Tag] { [.fast, .medium, .smoke] }
    static var comprehensiveCheck: [Tag] { [.medium, .slow, .integration] }

    // MARK: - Platform-Specific Combinations
    static var uiValidation: [Tag] { [.ui, .swiftui, .accessibility] }
    static var dataValidation: [Tag] { [.swiftdata, .migration, .validation] }
    static var networkValidation: [Tag] { [.network, .integration, .errorHandling] }

    // MARK: - Quality Gate Combinations
    static var preCommitGate: [Tag] { [.preCommit, .fast, .critical] }
    static var integrationGate: [Tag] { [.integration, .medium, .regression] }
    static var releaseGate: [Tag] { [.release, .comprehensive, .compatibility] }
}

// MARK: - Tag Documentation
/*
 
 TAGGING STRATEGY GUIDELINES:
 
 1. MULTIPLE TAGS PER TEST:
    Tests should have multiple tags to enable flexible selection:
    @Test("User login validation", .tags(.unit, .fast, .authentication, .validation))
    
 2. EXECUTION TIMING:
    - .fast: Unit tests, simple validation, mock operations
    - .medium: Integration tests, database operations, moderate UI tests
    - .slow: Complex UI tests, performance tests, stress tests
    
 3. PARALLEL EXECUTION:
    - .parallel: Most tests (default assumption)
    - .serial: Tests that modify shared resources, stress tests
    
 4. CRITICALITY:
    - .critical: Basic functionality that other tests depend on
    - .smoke: Essential user workflows
    - .sanity: Basic system health checks
    
 5. CHUNK ORGANIZATION:
    Tags enable dynamic chunk composition:
    - Quick feedback: .fast + .critical
    - Component focus: .ui + .navigation
    - Quality gates: .preCommit + .regression
    
 6. CI/CD OPTIMIZATION:
    - Different tag combinations for different build types
    - Parallel execution based on .parallel/.serial tags
    - Time-boxed test runs using .fast/.medium/.slow
    
 */
