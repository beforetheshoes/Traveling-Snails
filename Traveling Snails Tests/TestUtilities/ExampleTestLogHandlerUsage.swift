import Foundation
import Testing
@testable import Traveling_Snails

/// Example demonstrating how other test suites can use the shared TestLogHandler
/// This serves as both documentation and verification that the extraction worked properly
@Suite("Example TestLogHandler Usage")
struct ExampleTestLogHandlerUsage {
    @Test("Example: Using TestLogHandler in SwiftData tests")
    func exampleSwiftDataSecurityTest() {
        let logHandler = TestLogHandler()

        // Start capturing logs before any potentially sensitive operations
        logHandler.startCapturing()

        // Simulate some logging that might happen during SwiftData operations
        logHandler.captureLog("Processing trip data for vacation planning")
        logHandler.captureLog("User email: private@example.com detected in logs") // This should be flagged
        logHandler.captureLog("Operation completed successfully") // This should be safe

        // Stop capturing and analyze for security violations
        let logs = logHandler.stopCapturing()
        let violations = logHandler.containsSensitiveData(logs)

        // Verify that sensitive data was detected
        #expect(violations.count > 0, "Should detect email address violation")

        let emailViolation = violations.first { $0.reason.contains("Email address") }
        #expect(emailViolation != nil, "Should specifically detect email address pattern")
    }

    @Test("Example: Using TestLogHandler in service layer tests")
    func exampleServiceSecurityTest() {
        let logHandler = TestLogHandler()

        logHandler.startCapturing()

        // Simulate logging from service layer operations
        logHandler.captureLog("API call initiated")
        logHandler.captureLog("Authentication token: abc123secret") // Security violation
        logHandler.captureLog("Response received with status 200") // Safe

        let logs = logHandler.stopCapturing()
        let violations = logHandler.containsSensitiveData(logs)

        // Should detect the token exposure
        #expect(violations.count > 0, "Should detect security credential violation")

        let tokenViolation = violations.first { $0.reason.contains("Security credentials") }
        #expect(tokenViolation != nil, "Should detect token in logs")
    }

    @Test("Example: Using TestLogHandler for model object detection")
    func exampleModelObjectDetection() {
        let logHandler = TestLogHandler()

        logHandler.startCapturing()

        // Simulate logging that directly prints model objects (highest priority violation)
        logHandler.captureLog("Processing request")
        logHandler.captureLog("Trip(id: 123, name: 'Secret Vacation', description: 'Private details')") // Model violation
        logHandler.captureLog("Operation completed")

        let logs = logHandler.stopCapturing()
        let violations = logHandler.containsSensitiveData(logs)

        // Should detect model object printing (highest priority)
        #expect(violations.count > 0, "Should detect model object violation")

        let modelViolation = violations.first { $0.reason.contains("Model object") }
        #expect(modelViolation != nil, "Should detect direct model printing")

        // Model violations take precedence, so we should see exactly one violation
        #expect(violations.count == 1, "Model object detection should take precedence")
    }

    @Test("Example: Thread-safe usage across concurrent operations")
    func exampleConcurrentUsage() async {
        let logHandler = TestLogHandler()

        logHandler.startCapturing()

        // Simulate concurrent logging from multiple operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                logHandler.captureLog("Background sync operation started")
            }
            group.addTask {
                logHandler.captureLog("User interaction logged")
            }
            group.addTask {
                logHandler.captureLog("CloudKit operation completed")
            }
        }

        let logs = logHandler.stopCapturing()

        // Should capture all concurrent logs safely
        #expect(logs.count == 3, "Should safely capture all concurrent log messages")

        // Verify no violations in safe logs
        let violations = logHandler.containsSensitiveData(logs)
        #expect(violations.isEmpty, "Safe operational logs should not trigger violations")
    }

    @Test("Example: Integration with existing test patterns")
    @MainActor func exampleIntegrationWithSwiftDataTestBase() {
        // Demonstrate how TestLogHandler works alongside other test utilities
        _ = SwiftDataTestBase() // Demonstrates integration but don't need to use it
        let logHandler = TestLogHandler()

        logHandler.startCapturing()

        // Simulate operations that might use both SwiftData and logging
        logHandler.captureLog("Creating test trip in isolated database")
        logHandler.captureLog("SwiftData context initialized successfully") // Safe version

        let logs = logHandler.stopCapturing()
        let violations = logHandler.containsSensitiveData(logs)

        // Integration logs should generally be safe
        #expect(violations.isEmpty, "Test infrastructure logs should not contain sensitive data")
    }
}
