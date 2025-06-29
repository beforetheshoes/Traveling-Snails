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
}
