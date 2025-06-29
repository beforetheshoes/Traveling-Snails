//
//  SwiftLintIntegrationTests.swift
//  Traveling Snails Tests
//
//  Integration tests for SwiftLint security and code quality enforcement
//

import Foundation
import Testing

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
        
        // Verify NavigationView is flagged as error
        #expect(configContent.contains("NavigationView"), "NavigationView should be flagged in rules")
        #expect(configContent.contains("@StateObject") || configContent.contains("@ObservableObject"), "Old observable patterns should be flagged")
    }
    
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
    
    @Test("Rule regex patterns exclude comments and tests")
    func ruleRegexPatternsExcludeCommentsAndTests() async throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let swiftLintConfigPath = projectRoot.appendingPathComponent(".swiftlint.yml")
        let configContent = try String(contentsOf: swiftLintConfigPath, encoding: .utf8)

        // Verify patterns include comment exclusions
        #expect(configContent.contains("(?<!//"), "Rules should exclude commented code")
        #expect(configContent.contains("(?<!/\\*"), "Rules should exclude block comments")
        
        // Verify test file exclusions
        let testExclusionPattern = ".*Tests.*\\.swift$"
        #expect(configContent.contains(testExclusionPattern), "Rules should exclude test files with proper regex")
    }
    
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
        
        // NavigationView should be error (deprecated)
        let navigationRulePattern = #"use_navigation_stack:[\s\S]*?severity:\s*error"#
        #expect(configContent.range(of: navigationRulePattern, options: .regularExpression) != nil, "Deprecated API usage should be error severity")
        
        // StateObject should be error (modern pattern required)
        let observableRulePattern = #"no_state_object:[\s\S]*?severity:\s*error"#
        #expect(configContent.range(of: observableRulePattern, options: .regularExpression) != nil, "Old observable patterns should be error severity")
    }
}
