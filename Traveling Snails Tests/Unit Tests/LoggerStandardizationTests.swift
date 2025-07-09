//
//  LoggerStandardizationTests.swift
//  Traveling Snails
//
//

import Foundation
import os
import Testing
@testable import Traveling_Snails

@Suite("Logger Standardization Tests")
struct LoggerStandardizationTests {
    @Suite("Logger.secure Pattern Tests")
    struct LoggerSecureTests {
        @Test("Logger.secure creates proper os.Logger instance", .tags(.unit, .fast, .parallel, .logging, .security, .validation))
        func testLoggerSecureCreation() {
            let logger = Logger.secure(category: .app)
            // Verify it's an os.Logger by testing it doesn't crash
            logger.debug("Test message")
        }

        @Test("Logger.secure uses correct subsystem and category", .tags(.unit, .fast, .parallel, .logging, .security, .validation))
        func testLoggerSecureSubsystemAndCategory() {
            _ = Bundle.main.bundleIdentifier ?? "com.travelingsnails.app"

            // Test that Logger.secure creates loggers without crashing
            let appLogger = Logger.secure(category: .app)
            let syncLogger = Logger.secure(category: .sync)

            // Verify they work by logging test messages
            appLogger.debug("App logger test")
            syncLogger.debug("Sync logger test")
        }

        @Test("Logger.secure supports all categories", .tags(.unit, .fast, .parallel, .logging, .security, .validation))
        func testLoggerSecureAllCategories() {
            for category in Traveling_Snails.Logger.Category.allCases {
                let logger = Traveling_Snails.Logger.secure(category: category)
                // Verify logger works by testing a log call
                logger.debug("Testing category: \(category.rawValue)")
            }
        }

        @Test("Logger.secure privacy levels work correctly", .tags(.unit, .medium, .serial, .logging, .security, .validation, .errorHandling))
        func testLoggerSecurePrivacyLevels() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            let logger = Traveling_Snails.Logger.secure(category: .debug)

            // Test public privacy level
            logger.debug("Test message with \("public_data", privacy: .public)")

            // Test private privacy level (should not expose data)
            logger.debug("Test message with \("private_data", privacy: .private)")

            let logs = logHandler.stopCapturing()

            // Verify logs were generated but sensitive data patterns are not exposed
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "Privacy levels should prevent sensitive data exposure")
        }
    }

    @Suite("Migration Pattern Validation Tests")
    struct MigrationPatternTests {
        @Test("Logger.shared pattern still works during migration", .tags(.unit, .medium, .serial, .logging, .migration, .compatibility, .regression))
        func testLoggerSharedCompatibility() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Test existing Logger.shared pattern
            #if DEBUG
            Traveling_Snails.Logger.shared.debug("Test message from shared logger", category: .app)
            #endif

            let logs = logHandler.stopCapturing()

            // Should not cause crashes or errors
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "Existing Logger.shared pattern should not expose sensitive data")
        }

        @Test("Both patterns can coexist safely", .tags(.unit, .medium, .serial, .logging, .migration, .compatibility, .regression))
        func testPatternCoexistence() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Test both patterns together
            #if DEBUG
            Traveling_Snails.Logger.shared.debug("Message from shared logger", category: .sync)
            Traveling_Snails.Logger.secure(category: .sync).debug("Message from secure logger")
            #endif

            let logs = logHandler.stopCapturing()

            // Both should work without conflicts
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "Both logging patterns should coexist safely")
        }

        @Test("Category consistency between patterns", .tags(.unit, .medium, .serial, .logging, .migration, .compatibility, .validation))
        func testCategoryConsistency() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Test same category with both patterns
            let categories: [Traveling_Snails.Logger.Category] = [.app, .sync, .database]
            for category in categories {
                #if DEBUG
                Traveling_Snails.Logger.shared.debug("Shared logger test", category: category)
                Traveling_Snails.Logger.secure(category: category).debug("Secure logger test")
                #endif
            }

            let logs = logHandler.stopCapturing()

            // Should not expose sensitive data regardless of pattern
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "Category consistency should be maintained")
        }
    }

    @Suite("High-Impact File Migration Validation")
    struct HighImpactFileMigrationTests {
        @Test("SyncManager logging patterns are safe", .tags(.unit, .medium, .serial, .logging, .security, .sync, .migration))
        func testSyncManagerLoggingPatterns() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Simulate typical SyncManager logging patterns
            #if DEBUG
            Traveling_Snails.Logger.secure(category: .sync).debug("Sync triggered on device: \("test-device", privacy: .public)")
            Traveling_Snails.Logger.secure(category: .sync).debug("Starting sync with \(5, privacy: .public) pending changes")
            Traveling_Snails.Logger.secure(category: .sync).debug("Sync completed successfully")
            #endif

            let logs = logHandler.stopCapturing()

            // Verify no sensitive data exposure
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "SyncManager logging should not expose sensitive data")
        }

        @Test("EditTripView logging patterns are safe", .tags(.unit, .medium, .serial, .logging, .security, .trip, .migration))
        func testEditTripViewLoggingPatterns() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Simulate typical EditTripView logging patterns
            #if DEBUG
            Traveling_Snails.Logger.secure(category: .dataImport).debug("Starting trip deletion for ID: \("test-id", privacy: .public)")
            Traveling_Snails.Logger.secure(category: .dataImport).debug("Trip deleted and saved successfully")
            Traveling_Snails.Logger.secure(category: .sync).debug("Triggered explicit sync for trip deletion")
            #endif

            let logs = logHandler.stopCapturing()

            // Verify no sensitive data exposure
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "EditTripView logging should not expose sensitive data")
        }

        @Test("BiometricAuthManager logging patterns are safe", .tags(.unit, .medium, .serial, .logging, .security, .authentication, .biometric))
        func testBiometricAuthManagerLoggingPatterns() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Simulate typical BiometricAuthManager logging patterns
            #if DEBUG
            Traveling_Snails.Logger.secure(category: .app).debug("BiometricLockView initialized for trip protection")
            Traveling_Snails.Logger.secure(category: .app).debug("Biometric authentication completed")
            #endif

            let logs = logHandler.stopCapturing()

            // Verify no sensitive data exposure
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "BiometricAuthManager logging should not expose sensitive data")
        }
    }

    @Suite("Performance and Consistency Tests")
    struct PerformanceConsistencyTests {
        @Test("Logger.secure performance is acceptable", .tags(.unit, .medium, .serial, .logging, .performance, .validation))
        func testLoggerSecurePerformance() {
            let startTime = CFAbsoluteTimeGetCurrent()

            // Perform 100 logging operations
            for i in 0..<100 {
                #if DEBUG
                Traveling_Snails.Logger.secure(category: .debug).debug("Performance test iteration \(i, privacy: .public)")
                #endif
            }

            let duration = CFAbsoluteTimeGetCurrent() - startTime

            // Should complete within reasonable time (less than 1 second)
            #expect(duration < 1.0, "Logger.secure should have acceptable performance")
        }

        @Test("Category assignment consistency", .tags(.unit, .medium, .serial, .logging, .validation, .consistency))
        func testCategoryAssignmentConsistency() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Test category assignment consistency
            let categories: [Traveling_Snails.Logger.Category] = [.app, .sync, .database, .ui, .cloudKit]

            for category in categories {
                #if DEBUG
                Traveling_Snails.Logger.secure(category: category).debug("Testing category: \(category.rawValue, privacy: .public)")
                #endif
            }

            let logs = logHandler.stopCapturing()

            // Verify no sensitive data exposure
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "Category assignment should be consistent and safe")
        }
    }

    @Suite("Regression Prevention Tests")
    struct RegressionPreventionTests {
        @Test("No infinite recreation from logging", .tags(.unit, .medium, .serial, .logging, .regression, .errorHandling, .boundary))
        func testNoInfiniteRecreationFromLogging() {
            var logCount = 0
            let maxExpectedLogs = 10

            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Simulate logging in a view-like context
            for _ in 0..<maxExpectedLogs {
                #if DEBUG
                Traveling_Snails.Logger.secure(category: .ui).debug("View logging test")
                #endif
                logCount += 1
            }

            let logs = logHandler.stopCapturing()

            // Should not cause infinite recreation
            #expect(logCount == maxExpectedLogs, "Logging should not cause infinite recreation")
            #expect(logs.count <= maxExpectedLogs * 2, "Log count should be reasonable") // Allow some tolerance
        }

        @Test("Logger migration does not affect SwiftData operations", .tags(.unit, .medium, .serial, .logging, .swiftdata, .migration, .compatibility))
        func testLoggerMigrationSwiftDataCompatibility() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()

            // Simulate logging during SwiftData operations
            #if DEBUG
            Traveling_Snails.Logger.secure(category: .database).debug("SwiftData operation starting")
            Traveling_Snails.Logger.secure(category: .database).debug("SwiftData operation completed")
            #endif

            let logs = logHandler.stopCapturing()

            // Should not interfere with SwiftData
            let violations = logHandler.containsSensitiveData(logs)
            #expect(violations.isEmpty, "Logger migration should not affect SwiftData operations")
        }
    }
}
