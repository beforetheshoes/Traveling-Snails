import Foundation
import Testing
@testable import Traveling_Snails

/// Intercepts and captures log output for testing
/// 
/// This utility provides thread-safe log capture and comprehensive sensitive data detection
/// for security testing across all test suites. It can be used to verify that logging
/// operations don't expose sensitive user data, personal information, or security credentials.
///
/// Usage:
/// ```swift
/// let logHandler = TestLogHandler()
/// logHandler.startCapturing()
/// // ... perform operations that may log
/// let logs = logHandler.stopCapturing()
/// let violations = logHandler.containsSensitiveData(logs)
/// #expect(violations.isEmpty, "No sensitive data should be logged")
/// ```
public class TestLogHandler {
    private var capturedLogs: [String] = []
    private let queue = DispatchQueue(label: "test.log.handler")
    
    public init() {}
    
    /// Clears any previously captured logs and begins fresh capture
    public func startCapturing() {
        capturedLogs.removeAll()
    }
    
    /// Thread-safely returns all captured logs since startCapturing() was called
    public func stopCapturing() -> [String] {
        queue.sync {
            return capturedLogs
        }
    }
    
    /// Thread-safely adds a log message to the captured logs array
    public func captureLog(_ message: String) {
        queue.sync {
            capturedLogs.append(message)
        }
    }
    
    /// Analyzes logs for sensitive data patterns and returns violations
    /// 
    /// This method implements comprehensive security pattern detection including:
    /// - Model object detection (highest priority - SwiftData models printed directly)
    /// - Personal information (names, phone numbers, email addresses)
    /// - Location data (street addresses, GPS coordinates)
    /// - Trip/Activity details (names, descriptions, notes, costs)
    /// - Security credentials (passwords, tokens, secrets, keys)
    /// - Booking information (confirmation numbers, reservations)
    ///
    /// - Parameter logs: Array of log messages to analyze
    /// - Returns: Array of tuples containing violating log message and reason for violation
    public func containsSensitiveData(_ logs: [String]) -> [(log: String, reason: String)] {
        var violations: [(log: String, reason: String)] = []
        
        let sensitivePatterns = [
            // Personal information patterns (more specific to avoid false positives)
            (pattern: "\\b(name|guest|user|customer|person):\\s*[A-Za-z]+ [A-Za-z]+", reason: "Possible name exposure"),
            (pattern: "\\d{3}-\\d{3}-\\d{4}", reason: "Phone number pattern"),
            (pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", reason: "Email address"),
            
            // Location data
            (pattern: "\\d+ [A-Za-z]+ (Street|St|Avenue|Ave|Road|Rd)", reason: "Street address"),
            (pattern: "latitude|longitude|coordinates", reason: "GPS coordinates"),
            
            // Trip/Activity details
            (pattern: "trip\\.name|activity\\.name|lodging\\.name", reason: "Trip/activity names"),
            (pattern: "trip:\\s*[A-Za-z]|trip\\s+name:|trip\\s+details", reason: "Trip name exposure"),
            (pattern: "\\]\\s*=\\s*[A-Za-z]", reason: "Array item name exposure"),
            (pattern: "emptyTrip\\.name", reason: "Trip name exposure"),
            (pattern: "trip\\.name", reason: "Trip name exposure"),
            (pattern: "description:|notes:", reason: "Personal descriptions/notes"),
            (pattern: "cost:|price:|amount:", reason: "Financial information"),
            
            // Other sensitive data
            (pattern: "password|token|secret|key", reason: "Security credentials"),
            (pattern: "confirmation\\s*#|booking\\s*#|reservation\\s*#", reason: "Booking information")
        ]
        
        for log in logs {
            let lowercaseLog = log.lowercased()
            var foundViolation = false
            
            // Check for model string representations FIRST (highest priority)
            if lowercaseLog.contains("trip(") || 
               lowercaseLog.contains("activity(") || 
               lowercaseLog.contains("lodging(") ||
               lowercaseLog.contains("transportation(") ||
               lowercaseLog.contains("organization(") {
                violations.append((log: log, reason: "Model object printed directly"))
                foundViolation = true
            }
            
            // Only check other patterns if no model object detected
            if !foundViolation {
                for (pattern, reason) in sensitivePatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        let range = NSRange(location: 0, length: log.utf16.count)
                        if regex.firstMatch(in: log, options: [], range: range) != nil {
                            violations.append((log: log, reason: reason))
                            break
                        }
                    }
                }
            }
        }
        
        return violations
    }
}