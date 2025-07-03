//
//  SwiftLintIntegrationTests.swift
//  Traveling Snails Tests
//
//  Integration tests for SwiftLint security and code quality enforcement
//

import Foundation
import Testing

// Process is only available on macOS, so disable Process tests on iOS
#if os(macOS)
import Darwin
#endif

@Suite("SwiftLint Integration Tests")
struct SwiftLintIntegrationTests {
    @Test("SwiftLint configuration file exists")
    func swiftLintConfigurationExists() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")

        let configExists = FileManager.default.fileExists(atPath: swiftLintConfigPath.path)
        #expect(configExists, "SwiftLint configuration file should exist at project root")
    }

    #if os(macOS)
    @Test("SwiftLint configuration contains security rules")
    func swiftLintConfigurationContainsSecurityRules() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Check for security-focused custom rules
        #expect(configContent.contains("no_print_statements"), "Configuration should contain no_print_statements rule")
        #expect(configContent.contains("no_sensitive_logging"), "Configuration should contain no_sensitive_logging rule")
        #expect(configContent.contains("use_navigation_stack"), "Configuration should contain use_navigation_stack rule")
        #expect(configContent.contains("no_swiftdata_parameter_passing"), "Configuration should contain no_swiftdata_parameter_passing rule")
    }
    #endif

    #if os(macOS)
    @Test("SwiftLint configuration includes project directories")
    func swiftLintConfigurationIncludesProjectDirectories() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Check for proper inclusion/exclusion rules
        #expect(configContent.contains("Traveling Snails"), "Configuration should include main app directory")
        #expect(configContent.contains("excluded:"), "Configuration should have exclusion rules")
        #expect(configContent.contains(".build"), "Configuration should exclude build directories")
    }
    #endif

    #if os(macOS)
    @Test("Package.swift includes SwiftLint dependency")
    func packageSwiftIncludesSwiftLintDependency() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let packageSwiftPath = projectRoot.appendingPathComponent("Package.swift")

        #expect(FileManager.default.fileExists(atPath: packageSwiftPath.path), "Package.swift should exist")

        let packageContent = try String(contentsOf: packageSwiftPath, encoding: .utf8)
        #expect(packageContent.contains("SwiftLint"), "Package.swift should include SwiftLint dependency")
        #expect(packageContent.contains("realm/SwiftLint"), "Package.swift should reference correct SwiftLint repository")
    }
    #endif

    @Test("Setup script exists and is executable")
    func setupScriptExistsAndIsExecutable() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let setupScriptPath = projectRoot.appendingPathComponent("Scripts/setup-swiftlint.sh")

        #expect(FileManager.default.fileExists(atPath: setupScriptPath.path), "Setup script should exist")

        // Check if script is executable
        let attributes = try FileManager.default.attributesOfItem(atPath: setupScriptPath.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        let isExecutable = (permissions?.intValue ?? 0) & 0o111 != 0

        #expect(isExecutable, "Setup script should be executable")
    }

    #if os(macOS)
    @Test("SwiftLint build script exists")
    func swiftLintBuildScriptExists() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let buildScriptPath = projectRoot.appendingPathComponent("Scripts/swiftlint-build-script.sh")

        #expect(FileManager.default.fileExists(atPath: buildScriptPath.path), "SwiftLint build script should exist")

        let scriptContent = try String(contentsOf: buildScriptPath, encoding: .utf8)
        #expect(scriptContent.contains("SwiftLint Script for Traveling Snails"), "Build script should be properly configured")
        #expect(scriptContent.contains("Security violations detected"), "Build script should check for security violations")
    }
    #endif

    #if os(macOS)
    @Test("SwiftLint can execute successfully")
    func swiftLintCanExecuteSuccessfully() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "swiftlint", "version"]

        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            #expect(process.terminationStatus == 0, "SwiftLint should execute successfully")
            #expect(output.contains("SwiftLint") || output.contains("version"), "SwiftLint should return version information")
        } catch {
            Issue.record("SwiftLint execution failed: \(error)")
        }
    }
    #endif

    #if os(macOS)
    @Test("Custom security rules are properly configured")
    func customSecurityRulesAreProperlyConfigured() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Verify security rule configuration
        #expect(configContent.contains("no_print_statements:"), "no_print_statements rule should be defined")
        #expect(configContent.contains("no_sensitive_logging:"), "no_sensitive_logging rule should be defined")
        #expect(configContent.contains("safe_error_messages:"), "safe_error_messages rule should be defined")

        // Verify rule exclusions for test files
        #expect(configContent.contains(".*Tests.*\\.swift$"), "Security rules should exclude test files")

        // Verify severity levels
        #expect(configContent.contains("severity: warning") || configContent.contains("severity: error"), "Rules should have appropriate severity levels")
    }
    #endif

    #if os(macOS)
    @Test("Modern Swift rules are properly configured")
    func modernSwiftRulesAreProperlyConfigured() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Verify modern Swift rules
        #expect(configContent.contains("use_navigation_stack:"), "use_navigation_stack rule should be defined")
        #expect(configContent.contains("no_state_object:"), "no_state_object rule should be defined")
        #expect(configContent.contains("use_l10n_enum:"), "use_l10n_enum rule should be defined")

        // Verify deprecated navigation patterns are flagged as error
        let navigationString = "Navigation" + "View"
        #expect(configContent.contains(navigationString), "Deprecated navigation should be flagged in rules")
        let stateObjectString = "@State" + "Object"
        let observableObjectString = "@Observable" + "Object"
        #expect(configContent.contains(stateObjectString) || configContent.contains(observableObjectString), "Old observable patterns should be flagged")
    }
    #endif

    #if os(macOS)
    @Test("SwiftData anti-patterns are properly configured")
    func swiftDataAntiPatternsAreProperlyConfigured() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Verify SwiftData rules
        #expect(configContent.contains("no_swiftdata_parameter_passing:"), "no_swiftdata_parameter_passing rule should be defined")

        // Verify it checks for model types
        #expect(configContent.contains("Trip") || configContent.contains("Activity"), "Rule should check for SwiftData model types")
    }
    #endif

    #if os(macOS)
    @Test("GitHub Actions workflow includes SwiftLint")
    func gitHubActionsWorkflowIncludesSwiftLint() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let workflowPath = projectRoot.appendingPathComponent(".github/workflows/swiftlint.yml")

        #expect(FileManager.default.fileExists(atPath: workflowPath.path), "SwiftLint GitHub Actions workflow should exist")

        let workflowContent = try String(contentsOf: workflowPath, encoding: .utf8)

        // Verify key workflow components
        #expect(workflowContent.contains("SwiftLint Security"), "Workflow should have security focus")
        #expect(workflowContent.contains("swift run swiftlint"), "Workflow should execute SwiftLint")
        #expect(workflowContent.contains("security violations"), "Workflow should check for security violations")
        #expect(workflowContent.contains("JSON"), "Workflow should use JSON parsing")
        #expect(workflowContent.contains("jq"), "Workflow should use jq for JSON processing")
    }
    #endif

    #if os(macOS)
    @Test("Rule regex patterns exclude test files")
    func ruleRegexPatternsExcludeTestFiles() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Verify test file exclusions
        let testExclusionPattern = ".*Tests.*\\.swift$"
        #expect(configContent.contains(testExclusionPattern), "Rules should exclude test files with proper regex")

        // Verify preview file exclusions  
        let previewExclusionPattern = ".*Preview.*\\.swift$"
        #expect(configContent.contains(previewExclusionPattern), "Rules should exclude preview files with proper regex")
    }
    #endif

    #if os(macOS)
    @Test("Rule severity levels are appropriate")
    func ruleSeverityLevelsAreAppropriate() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Security rules should be warnings or errors
        let securityRulePattern = #"no_print_statements:[\s\S]*?severity:\s*(warning|error)"#
        #expect(configContent.range(of: securityRulePattern, options: .regularExpression) != nil, "Security rules should have appropriate severity")

        // Deprecated navigation should be error
        let navigationRulePattern = #"use_navigation_stack:[\s\S]*?severity:\s*error"#
        #expect(configContent.range(of: navigationRulePattern, options: .regularExpression) != nil, "Deprecated API usage should be error severity")

        // Old observable patterns should be error (modern pattern required)
        let observableRulePattern = #"no_state_object:[\s\S]*?severity:\s*error"#
        #expect(configContent.range(of: observableRulePattern, options: .regularExpression) != nil, "Old observable patterns should be error severity")
    }
    #endif

    #if os(macOS)
    @Test("Print statement rule detects violations correctly")
    func printStatementRuleDetectsViolationsCorrectly() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Create a temporary file with print statements
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_print.swift")
        let testCode = """
        import Foundation

        func testFunction() {
            print("This should be caught by SwiftLint")
            Logger.shared.debug("This should not be caught")
            // print("This comment should not be caught")
        }
        """

        try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Run SwiftLint on the test file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "swiftlint", "lint", "--enable-rule", "no_print_statements", tempFile.path]
        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        #expect(output.contains("print"), "SwiftLint should detect print statement violations")
        #expect(output.contains("no_print_statements"), "Violation should reference the correct rule")
    }
    #endif

    #if os(macOS)
    @Test("Sensitive logging rule detects violations correctly")
    func sensitiveLoggingRuleDetectsViolationsCorrectly() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Create a temporary file with sensitive data in logging
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_sensitive.swift")
        let testCode = """
        import Foundation

        func authenticateUser() {
            let password = "secret123"
            let apiKey = "api_key_123"

            Logger.shared.debug("User password: \\(password)")
            Logger.shared.info("API key: \\(apiKey)")
            Logger.shared.info("Login successful")
        }
        """

        try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Run SwiftLint on the test file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "swiftlint", "lint", "--enable-rule", "no_sensitive_logging", tempFile.path]
        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        #expect(output.contains("password") || output.contains("apiKey"), "SwiftLint should detect sensitive data logging violations")
        #expect(output.contains("no_sensitive_logging"), "Violation should reference the correct rule")
    }
    #endif

    #if os(macOS)
    @Test("NavigationStack rule detects deprecated navigation patterns")
    func navigationStackRuleDetectsDeprecatedNavigationPatterns() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Create a temporary file with deprecated navigation usage
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_navigation.swift")
        let deprecatedNavigationComponent = "Navigation" + "View"
        let testCode = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                \(deprecatedNavigationComponent) {
                    Text("Hello World")
                }
            }
        }
        """

        try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Run SwiftLint on the test file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "swiftlint", "lint", "--enable-rule", "use_navigation_stack", tempFile.path]
        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let deprecatedNav = "Navigation" + "View"
        #expect(output.contains(deprecatedNav) || output.contains("NavigationStack"), "SwiftLint should detect deprecated navigation usage")
        #expect(output.contains("use_navigation_stack"), "Violation should reference the correct rule")
    }
    #endif

    #if os(macOS)
    @Test("StateObject rule detects deprecated observable patterns")
    func stateObjectRuleDetectsDeprecatedObservablePatterns() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Create a temporary file with deprecated observable patterns
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_stateobject.swift")
        let stateObjectAnnotation = "@State" + "Object"
        let observableObjectAnnotation = "@Observable" + "Object"
        let testCode = """
        import SwiftUI

        struct ContentView: View {
            \(stateObjectAnnotation) private var viewModel = MyViewModel()
            \(observableObjectAnnotation) var anotherModel: AnotherModel

            var body: some View {
                Text("Hello World")
            }
        }
        """

        try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Run SwiftLint on the test file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "swiftlint", "lint", "--enable-rule", "no_state_object", tempFile.path]
        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let stateObjCheck = "@State" + "Object"
        let observableObjCheck = "@Observable" + "Object"
        #expect(output.contains(stateObjCheck) || output.contains(observableObjCheck), "SwiftLint should detect deprecated observable patterns")
        #expect(output.contains("no_state_object"), "Violation should reference the correct rule")
    }
    #endif

    #if os(macOS)
    @Test("SwiftData parameter passing rule detects anti-patterns")
    func swiftDataParameterPassingRuleDetectsAntiPatterns() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Create a temporary file with SwiftData parameter passing
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_swiftdata.swift")
        let testCode = """
        import SwiftUI
        import SwiftData

        struct TripView: View {
            let trips: [Trip]
            let activities: [Activity]

            init(trips: [Trip], activities: [Activity]) {
                self.trips = trips
                self.activities = activities
            }

            var body: some View {
                Text("Hello World")
            }
        }
        """

        try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Run SwiftLint on the test file
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "swiftlint", "lint", "--enable-rule", "no_swiftdata_parameter_passing", tempFile.path]
        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        #expect(output.contains("Trip") || output.contains("Activity"), "SwiftLint should detect SwiftData model parameter passing")
        #expect(output.contains("no_swiftdata_parameter_passing"), "Violation should reference the correct rule")
    }
    #endif

    #if os(macOS)
    @Test("JSON output format works correctly")
    func jsonOutputFormatWorksCorrectly() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Create a simple test file with a violation
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_json.swift")
        let testCode = """
        import Foundation

        func testFunction() {
            print("This should produce a JSON violation")
        }
        """

        try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        // Run SwiftLint with JSON output
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "swiftlint", "lint", "--reporter", "json", tempFile.path]
        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        // Verify JSON format
        #expect(output.hasPrefix("[") && output.hasSuffix("]"), "Output should be valid JSON array")

        // Try to parse JSON
        guard let jsonData = output.data(using: .utf8) else {
            Issue.record("Could not convert output to data")
            return
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            #expect(jsonObject is [Any], "JSON should be an array")
        } catch {
            Issue.record("JSON parsing failed: \\(error)")
        }
    }
    #endif
}
