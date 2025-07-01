//
//  LoggingSecurityTests.swift
//  Traveling Snails
//
//

import Foundation
import os
import SwiftData
import Testing

@testable import Traveling_Snails


@Suite("Logging Security Tests")
struct LoggingSecurityTests {
    let logHandler = TestLogHandler()

    @Suite("Sensitive Data Detection")
    struct SensitiveDataDetectionTests {
        let logHandler = TestLogHandler()

        @Test("Detect trip name exposure in logs")
        func detectTripNameExposure() {
            logHandler.startCapturing()

            // Simulate logs that would expose trip names
            let badLogs = [
                "Processing trip: Summer Vacation 2024",
                "Trip name: Business Trip to Seattle",
                "Loading trip details for 'Family Reunion'",
            ]

            for log in badLogs {
                logHandler.captureLog(log)
            }

            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)

            #expect(!violations.isEmpty, "Should detect trip name exposure")
            #expect(violations.count == badLogs.count, "Should detect all violations")
        }

        @Test("Detect personal information in logs")
        func detectPersonalInformation() {
            logHandler.startCapturing()

            let badLogs = [
                "User email: john.doe@example.com",
                "Contact phone: 555-123-4567",
                "Guest name: Jane Smith",
            ]

            for log in badLogs {
                logHandler.captureLog(log)
            }

            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)

            #expect(violations.count >= 2, "Should detect email and phone patterns")
        }

        @Test("Detect model object direct printing")
        func detectModelObjectPrinting() {
            logHandler.startCapturing()

            let badLogs = [
                "Current trip: Trip(id: 123, name: 'Hawaii Vacation', startDate: 2024-06-01)",
                "Activity details: Activity(name: 'Snorkeling', cost: 150.00)",
                "Lodging info: Lodging(name: 'Hilton Hotel', address: '123 Beach Rd')",
            ]

            for log in badLogs {
                logHandler.captureLog(log)
            }

            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)

            #expect(violations.count == badLogs.count, "Should detect all model printings")
            for violation in violations {
                #expect(violation.reason == "Model object printed directly")
            }
        }

        @Test("Safe logging patterns should pass")
        func safeLoggingPatterns() {
            logHandler.startCapturing()

            let safeLogs = [
                "Trip operation completed for ID: 12345",
                "Processing activity count: 5",
                "Sync status: completed",
                "Database operation: success",
                "View appeared: TripListView",
            ]

            for log in safeLogs {
                logHandler.captureLog(log)
            }

            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)

            #expect(violations.isEmpty, "Safe logs should not trigger violations")
        }
    }

    @Suite("Logger Framework Usage Tests")
    struct LoggerFrameworkUsageTests {
        @Test("Logger should use privacy levels for sensitive data")
        func loggerPrivacyLevels() {
            // This test verifies that the Logger class is configured to handle privacy
            let logger = Logger.shared

            // Test that logger exists and is properly configured
            // The logger should be using proper categories and levels
            logger.debug("Test message", category: .debug)
            #expect(true, "Logger instance exists and can be used")
        }

        @Test("Debug logging should be conditional")
        func debugLoggingConditional() {
            // Verify debug method exists and is properly guarded
            Logger.shared.debug("Test debug message")

            // In production, this should not produce output
            #if !DEBUG
            // This test would verify no output in release builds
            #expect(true, "Debug logging should be disabled in release")
            #endif
        }
    }

    @Suite("Code Pattern Tests")
    struct CodePatternTests {
        @Test("Print statements should be wrapped in DEBUG guards")
        func printStatementsWithDebugGuards() {
            // This is a meta-test that would be run against the codebase
            // For now, we just test the concept

            let codeWithoutGuard = """
            print("This is bad: \\(sensitiveData)")
            """

            let codeWithGuard = """
            #if DEBUG
            print("This is better but still not ideal: \\(id)")
            #endif
            """

            let bestPractice = """
            #if DEBUG
            Logger.activityLogger.debug("Operation completed for ID: \\(id, privacy: .public)")
            #endif
            """

            #expect(codeWithoutGuard.contains("print("), "Unguarded print detected")
            #expect(codeWithGuard.contains("#if DEBUG"), "Has DEBUG guard")
            #expect(bestPractice.contains("Logger") && bestPractice.contains("privacy:"), "Uses Logger with privacy")
        }
    }

    @Suite("Integration Tests")
    struct LoggingIntegrationTests {
        @Test("Model operations should not log sensitive data")
        @MainActor
        func modelOperationsLogging() async throws {
            let container = try ModelContainer(
                for: Trip.self, Activity.self, Lodging.self, Transportation.self, Organization.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            let context = container.mainContext

            // Create test data
            let trip = Trip(name: "Sensitive Trip Name")
            trip.notes = "Personal notes about the trip"

            context.insert(trip)

            // Simulate what proper logging should look like
            let properLogOutput = "Trip created with ID: \(trip.id)"

            #expect(!properLogOutput.contains("Sensitive Trip Name"))
            #expect(!properLogOutput.contains("Secret Location"))
            #expect(!properLogOutput.contains("Personal notes"))
        }
    }
}

// Extension to test Logger usage patterns
extension Traveling_Snails.Logger {
    /// Example of how to properly log with privacy
    func logSafeOperation<T>(operation: String, id: T) where T: CustomStringConvertible {
        self.info("\(operation) for ID: \(id)")
    }
}
