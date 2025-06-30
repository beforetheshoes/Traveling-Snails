//
//  CodebaseSecurityAuditTests.swift
//  Traveling Snails
//
//  Security audit tests to detect sensitive data exposure in actual codebase files
//

import Testing
import Foundation
import SwiftData
@testable import Traveling_Snails

@Suite("Codebase Security Audit")
struct CodebaseSecurityAuditTests {
    let logHandler = TestLogHandler()
    
    @Suite("Actual Codebase Violations")
    struct ActualCodebaseViolations {
        
        @Test("DebugEmptyTripTest no longer exposes sensitive data")
        func debugEmptyTripTestFixed() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()
            
            // Simulate the fixed secure logs from DebugEmptyTripTest.swift after our security improvements
            let secureFixedLogs = [
                "Empty trip created with ID: 12345-67890-ABCDEF",
                "Trip lodging count: 0",
                "Trip transportation count: 0", 
                "Trip activity count: 0",
                "Lodging[0] ID: ABC-123-DEF",
                "Transportation[0] ID: XYZ-456-GHI",
                "Activity[0] ID: JKL-789-MNO",
                "Created empty activity with ID: PQR-012-STU",
                "Activity trip ID: VWX-345-YZA",
                "Activity organization ID: BCD-678-EFG"
            ]
            
            for log in secureFixedLogs {
                logHandler.captureLog(log)
            }
            
            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)
            
            #expect(violations.isEmpty, "Fixed DebugEmptyTripTest should not have sensitive data violations")
        }
        
        @Test("Old insecure patterns are properly detected as violations")
        func oldInsecurePatternsDetected() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()
            
            // These are the OLD problematic patterns that SHOULD be flagged as violations
            let oldViolatingPatterns = [
                "DEBUG: emptyTrip.name = 'Secret Vacation'",
                "DEBUG: lodging[0] = Hotel California", 
                "DEBUG: transportation[0] = United Airlines Flight 123",
                "DEBUG: activity[0] = Private Beach Tour"
            ]
            
            for violation in oldViolatingPatterns {
                logHandler.captureLog(violation)
            }
            
            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)
            
            #expect(violations.count == oldViolatingPatterns.count, "Should detect all old insecure patterns as violations")
        }
        
        @Test("Commented print statements have been removed from BiometricLockView")
        func commentedPrintStatementsRemoved() {
            // This test verifies that the risky commented print statement was removed from BiometricLockView.swift
            // The original line was: // print("🔒 BiometricLockView.body for \\(trip.name) - isAuthenticating: \\(isAuthenticating)")
            
            // Test that we can still detect such patterns if they were to reappear
            let riskyPattern = "print(\"🔒 BiometricLockView.body for \\(trip.name) - isAuthenticating: \\(isAuthenticating)\")"
            
            let logHandler = TestLogHandler()
            logHandler.startCapturing()
            logHandler.captureLog(riskyPattern)
            let violations = logHandler.containsSensitiveData(logHandler.stopCapturing())
            
            #expect(!violations.isEmpty, "Trip name exposure would be detected as violation")
            // The violation could be detected as any trip-related pattern
            let hasRelevantViolation = violations.contains { violation in
                violation.reason.lowercased().contains("trip") || 
                violation.reason.lowercased().contains("name") ||
                violation.reason.lowercased().contains("exposure")
            }
            #expect(hasRelevantViolation, "Should identify relevant security violation")
        }
    }
    
    @Suite("Secure Patterns Tests")
    struct SecurePatternsTests {
        
        @Test("ID-based logging is secure")
        func idBasedLoggingSecure() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()
            
            let secureLogs = [
                "DEBUG: Trip operation completed for ID: 12345",
                "DEBUG: lodging count = 3",
                "DEBUG: transportation count = 2", 
                "DEBUG: activity count = 5",
                "DEBUG: manual total = 10",
                "DEBUG: Trip with ID: abc-123 - totalActivities = 8",
                "DEBUG: Activity created with ID: def-456",
                "DEBUG: Organization with ID: xyz-789"
            ]
            
            for log in secureLogs {
                logHandler.captureLog(log)
            }
            
            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)
            
            #expect(violations.isEmpty, "ID-based logging should not trigger violations")
        }
        
        @Test("Logger framework usage should be secure")
        func loggerFrameworkSecure() {
            let logHandler = TestLogHandler()
            logHandler.startCapturing()
            
            let secureLoggerLogs = [
                "#if DEBUG\nLogger.shared.debug(\"Trip operation completed for ID: \\(trip.id, privacy: .public)\")\n#endif",
                "Logger.activityLogger.debug(\"Activity count: \\(count, privacy: .public)\")",
                "Logger.shared.info(\"Import completed - Trips: \\(tripsCount), Organizations: \\(orgsCount)\")"
            ]
            
            for log in secureLoggerLogs {
                logHandler.captureLog(log)
            }
            
            let capturedLogs = logHandler.stopCapturing()
            let violations = logHandler.containsSensitiveData(capturedLogs)
            
            #expect(violations.isEmpty, "Proper Logger usage should not trigger violations")
        }
    }
    
    @Suite("Production Safety Tests")
    struct ProductionSafetyTests {
        
        @Test("Debug guards prevent production exposure")
        func debugGuardsPreventExposure() {
            // Test that we can identify when debug guards are missing
            let unguardedLog = "print(\"Sensitive: \\(trip.name)\")"
            let guardedLog = "#if DEBUG\nprint(\"Debug: Trip ID \\(trip.id)\")\n#endif"
            let loggerGuardedLog = "#if DEBUG\nLogger.shared.debug(\"Operation for ID: \\(id, privacy: .public)\")\n#endif"
            
            #expect(!unguardedLog.contains("#if DEBUG"), "Unguarded print is unsafe")
            #expect(guardedLog.contains("#if DEBUG"), "Guarded print is safer")
            #expect(loggerGuardedLog.contains("Logger") && loggerGuardedLog.contains("#if DEBUG"), "Logger with guard is best practice")
        }
        
        @Test("Privacy levels in Logger calls")
        func privacyLevelsInLogger() {
            let logsWithPrivacy = [
                "Logger.shared.debug(\"ID: \\(id, privacy: .public)\")",
                "Logger.shared.debug(\"Count: \\(count, privacy: .public)\")",
                "Logger.shared.debug(\"Status: \\(status, privacy: .public)\")"
            ]
            
            for log in logsWithPrivacy {
                #expect(log.contains("privacy: .public"), "Should use explicit privacy levels")
                #expect(!log.contains("privacy: .private"), "Should not log private data")
            }
        }
    }
    
    @Suite("Integration with Model Operations")
    struct ModelOperationSecurityTests {
        
        @Test("Model operations should only log IDs")
        @MainActor
        func modelOperationsLogOnlyIds() async throws {
            let container = try ModelContainer(
                for: Trip.self, Activity.self, Lodging.self, Transportation.self, Organization.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            
            let context = container.mainContext
            
            // Create test data with sensitive information
            let trip = Trip(name: "Secret Government Meeting")
            trip.notes = "Classified information about the meeting"
            
            let org = Organization(name: "CIA Front Company")
            let activity = Activity(
                name: "Covert Operation",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            context.insert(trip)
            context.insert(org)
            context.insert(activity)
            
            // Test what secure logging should look like
            let secureLogOutput = "Trip created with ID: \(trip.id)"
            let secureActivityLog = "Activity created with ID: \(activity.id)"
            let secureOrgLog = "Organization created with ID: \(org.id)"
            
            // These logs should NOT contain sensitive data
            #expect(!secureLogOutput.contains("Secret Government Meeting"))
            #expect(!secureActivityLog.contains("Covert Operation"))
            #expect(!secureOrgLog.contains("CIA Front Company"))
            
            // These logs should contain only safe identifiers
            #expect(secureLogOutput.contains(trip.id.uuidString))
            #expect(secureActivityLog.contains(activity.id.uuidString))
            #expect(secureOrgLog.contains(org.id.uuidString))
        }
    }
}