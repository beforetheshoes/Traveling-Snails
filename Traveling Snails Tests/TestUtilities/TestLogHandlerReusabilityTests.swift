import Foundation
import Testing
@testable import Traveling_Snails

/// These tests demonstrate the reusability requirements for TestLogHandler
/// They will initially FAIL because TestLogHandler hasn't been extracted yet
@Suite("TestLogHandler Reusability Requirements")
struct TestLogHandlerReusabilityTests {
    @Test("TestLogHandler should be importable from TestUtilities")
    func testLogHandlerImportable() {
        // Test that TestLogHandler is available from TestUtilities and can be instantiated
        let logHandler = TestLogHandler()
        #expect(type(of: logHandler) == TestLogHandler.self, "TestLogHandler should be available from TestUtilities")
    }

    @Test("TestLogHandler should maintain thread-safe log capture")
    func testThreadSafeLogCapture() async {
        let logHandler = TestLogHandler()
        logHandler.startCapturing()

        // Simulate concurrent logging from multiple threads
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    logHandler.captureLog("Thread \(i) message")
                }
            }
        }

        let logs = logHandler.stopCapturing()
        #expect(logs.count == 3, "Should capture all 3 concurrent log messages")
    }

    @Test("TestLogHandler should detect sensitive data patterns from other test suites")
    func testSensitiveDataDetectionFromOtherSuites() {
        let logHandler = TestLogHandler()
        logHandler.startCapturing()

        // Simulate logs that might come from other test suites
        let testLogs = [
            "User operation completed for user@example.com",
            "Trip(id: 123, name: 'Secret Vacation', description: 'Private trip details')",
            "Processing coordinates: latitude: 37.7749, longitude: -122.4194",
            "Booking confirmation #ABC123 processed",
        ]

        for log in testLogs {
            logHandler.captureLog(log)
        }

        let logs = logHandler.stopCapturing()
        let violations = logHandler.containsSensitiveData(logs)

        #expect(violations.count >= 4, "Should detect multiple types of sensitive data")

        // Verify specific violation types are detected
        let violationReasons = violations.map { $0.reason }
        #expect(violationReasons.contains { $0.contains("Email address") }, "Should detect email addresses")
        #expect(violationReasons.contains { $0.contains("Model object") }, "Should detect direct model printing")
        #expect(violationReasons.contains { $0.contains("GPS coordinates") }, "Should detect GPS coordinates")
        #expect(violationReasons.contains { $0.contains("Booking information") }, "Should detect booking confirmations")
    }

    @Test("TestLogHandler should be reusable across different test contexts")
    func testReusabilityAcrossDifferentContexts() {
        // Test 1: Use for service tests
        let serviceLogHandler = TestLogHandler()
        serviceLogHandler.startCapturing()
        serviceLogHandler.captureLog("Service call to API with token: secret123")
        let serviceLogs = serviceLogHandler.stopCapturing()
        let serviceViolations = serviceLogHandler.containsSensitiveData(serviceLogs)
        #expect(serviceViolations.count > 0, "Should detect security credentials in service tests")

        // Test 2: Use for SwiftData tests
        let dataLogHandler = TestLogHandler()
        dataLogHandler.startCapturing()
        dataLogHandler.captureLog("Saving trip: Trip(name: 'Personal Vacation', cost: $2500)")
        let dataLogs = dataLogHandler.stopCapturing()
        let dataViolations = dataLogHandler.containsSensitiveData(dataLogs)
        #expect(dataViolations.count > 0, "Should detect model objects and financial info in data tests")

        // Test 3: Use for UI tests
        let uiLogHandler = TestLogHandler()
        uiLogHandler.startCapturing()
        uiLogHandler.captureLog("User tapped button, displaying details for John Doe at 123 Main Street")
        let uiLogs = uiLogHandler.stopCapturing()
        let uiViolations = uiLogHandler.containsSensitiveData(uiLogs)
        #expect(uiViolations.count > 0, "Should detect personal info and addresses in UI tests")
    }

    @Test("TestLogHandler should maintain all existing security patterns")
    func testAllSecurityPatternsPreserved() {
        let logHandler = TestLogHandler()
        logHandler.startCapturing()

        // Test all patterns that exist in current LoggingSecurityTests
        let comprehensiveTestLogs = [
            // Personal information
            "Customer name: John Smith processed",
            "Contact phone: 555-123-4567",
            "Email: user@example.com",

            // Location data
            "Address: 123 Main Street, City",
            "GPS coordinates detected",

            // Trip/Activity details
            "trip.name accessed",
            "Trip details for summer vacation",
            "Activity description: Secret meeting notes",
            "Cost: $1,234.56",

            // Model objects (highest priority)
            "Trip(id: UUID, name: 'Private Trip')",
            "Activity(description: 'Confidential')",
            "Lodging(name: 'Secret Hotel')",

            // Security credentials
            "User password: secret123",
            "API token: abc123xyz",
            "Auth key detected",

            // Booking information
            "Confirmation #XYZ789",
            "Booking #ABC123",
            "Reservation #DEF456",
        ]

        for log in comprehensiveTestLogs {
            logHandler.captureLog(log)
        }

        let logs = logHandler.stopCapturing()
        let violations = logHandler.containsSensitiveData(logs)

        // Should detect violations for all major categories
        #expect(violations.count >= 10, "Should detect multiple violations across all security pattern categories")

        // Verify model objects are detected (highest priority)
        let modelViolations = violations.filter { $0.reason.contains("Model object") }
        #expect(modelViolations.count >= 3, "Should detect all model object violations")
    }
}
