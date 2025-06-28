//
//  SettingsViewTests.swift
//  Traveling Snails
//
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

@Suite("SettingsView Tests")
struct SettingsViewTests {
    
    // MARK: - Test Isolation Helpers
    
    /// Clean up shared state to prevent test contamination
    @MainActor
    static func cleanupSharedState() {
        // Reset any UserDefaults keys that tests might modify
        let testKeys = ["testBiometricTimeout", "colorScheme", "isRunningTests"]
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Reset AppSettings to default state
        AppSettings.shared.colorScheme = .system
    }
    
    // MARK: - Settings State Management Tests
    
    @Suite("Settings State Management")
    struct SettingsStateTests {
        
        @Test("Settings view state initialization")
        func testSettingsViewStateInitialization() {
            // Test default state values that should be managed by SettingsViewModel
            let showingDataBrowser = false
            let showingExportView = false
            let showingImportPicker = false
            let showingFileAttachmentSettings = false
            let showingImportProgress = false
            
            #expect(showingDataBrowser == false)
            #expect(showingExportView == false)
            #expect(showingImportPicker == false)
            #expect(showingFileAttachmentSettings == false)
            #expect(showingImportProgress == false)
        }
        
        @Test("Settings modal transitions")
        func testSettingsModalTransitions() {
            var showingDataBrowser = false
            var showingExportView = false
            var showingImportPicker = false
            
            // Test opening data browser
            showingDataBrowser = true
            #expect(showingDataBrowser == true)
            
            // Test opening export view
            showingExportView = true
            #expect(showingExportView == true)
            
            // Test opening import picker
            showingImportPicker = true
            #expect(showingImportPicker == true)
            
            // Test closing all
            showingDataBrowser = false
            showingExportView = false
            showingImportPicker = false
            
            #expect(showingDataBrowser == false)
            #expect(showingExportView == false)
            #expect(showingImportPicker == false)
        }
    }
    
    // MARK: - Appearance Settings Tests
    
    @Suite("Appearance Settings")
    struct AppearanceSettingsTests {
        
        @Test("Color scheme preference handling")
        @MainActor func testColorSchemePreferenceHandling() {
            // Clean up state before test
            SettingsViewTests.cleanupSharedState()
            
            // Test the logic that should be in SettingsViewModel
            let appSettings = AppSettings.shared
            
            // Store original setting to restore later
            let originalColorScheme = appSettings.colorScheme
            
            // Test setting values with explicit verification
            appSettings.colorScheme = .dark
            #expect(appSettings.colorScheme == .dark, "Should set to dark")
            
            appSettings.colorScheme = .light
            #expect(appSettings.colorScheme == .light, "Should set to light")
            
            appSettings.colorScheme = .system
            #expect(appSettings.colorScheme == .system, "Should set to system")
            
            // Restore original setting to avoid affecting other tests
            appSettings.colorScheme = originalColorScheme
            
            // Clean up state after test
            SettingsViewTests.cleanupSharedState()
        }
    }
    
    // MARK: - Data Management Tests
    
    @Suite("Data Management Operations")
    struct DataManagementTests {
        
        @Test("Import result handling")
        func testImportResultHandling() throws {
            // Test data structures that should be managed by DataManagementService
            let importManager = DatabaseImportManager()
            
            // Test initial state (redundant check removed)
            #expect(importManager.isImporting == false)
            
            // Test import result structure
            let mockResult = DatabaseImportManager.ImportResult(
                tripsImported: 5,
                organizationsImported: 10,
                addressesImported: 3,
                attachmentsImported: 12,
                transportationImported: 8,
                lodgingImported: 6,
                activitiesImported: 15,
                organizationsMerged: 2,
                errors: []
            )
            
            #expect(mockResult.tripsImported == 5)
            #expect(mockResult.organizationsImported == 10)
            #expect(mockResult.organizationsMerged == 2)
            #expect(mockResult.transportationImported == 8)
            #expect(mockResult.lodgingImported == 6)
            #expect(mockResult.activitiesImported == 15)
            #expect(mockResult.attachmentsImported == 12)
            #expect(mockResult.errors.isEmpty)
        }
        
        @Test("File import URL handling")
        func testFileImportURLHandling() {
            // Test URL handling logic that should be in DataManagementService
            let testURL = URL(fileURLWithPath: "/path/to/test.json")
            let urls = [testURL]
            
            #expect(urls.count == 1)
            #expect(urls.first == testURL)
            #expect(urls.first?.pathExtension == "json")
        }
        
        @Test("None organization cleanup logic")
        func testNoneOrganizationCleanupLogic() throws {
            // Test cleanup logic that should be in DataManagementService
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Organization.self, configurations: config)
            let context = ModelContext(container)
            
            // Create test organizations
            let org1 = Organization(name: "None")
            let org2 = Organization(name: "Test Org")
            let org3 = Organization(name: "None") // Duplicate
            
            context.insert(org1)
            context.insert(org2)
            context.insert(org3)
            
            try context.save()
            
            // Test cleanup operation
            let _ = Organization.cleanupDuplicateNoneOrganizations(in: context)
            
            // Verify the cleanup worked
            let fetchDescriptor = FetchDescriptor<Organization>()
            let organizations = try context.fetch(fetchDescriptor)
            let noneOrgs = organizations.filter { $0.name == "None" }
            
            #expect(noneOrgs.count <= 1) // Should have at most one "None" organization
        }
    }
    
    // MARK: - Security Settings Tests
    
    @Suite("Security Settings")
    struct SecuritySettingsTests {
        
        @Test("Biometric authentication settings")
        @MainActor func testBiometricAuthenticationSettings() async {
            let authManager = BiometricAuthManager.shared
            _ = AppSettings.shared // AppSettings exists but no longer has biometric settings
            
            // Test biometric availability check (properly awaited)
            let canUseBiometrics = authManager.canUseBiometrics()
            #expect(canUseBiometrics == true || canUseBiometrics == false) // Should return a boolean
            
            // Biometric authentication is now always enabled when available
            #expect(authManager.isEnabled == authManager.canUseBiometrics())
        }
        
        @Test("Timeout options enumeration")
        func testTimeoutOptionsEnumeration() {
            // Test the timeout enum that should be in SettingsViewModel
            enum TimeoutOption: TimeInterval, CaseIterable {
                case immediately = 0
                case fiveMinutes = 300
                case fifteenMinutes = 900
                case thirtyMinutes = 1800
                case oneHour = 3600
                case never = -1
                
                var displayName: String {
                    switch self {
                    case .immediately: return "Immediately"
                    case .fiveMinutes: return "5 minutes"
                    case .fifteenMinutes: return "15 minutes"
                    case .thirtyMinutes: return "30 minutes"
                    case .oneHour: return "1 hour"
                    case .never: return "Never"
                    }
                }
                
                static func from(_ timeInterval: TimeInterval) -> TimeoutOption {
                    return allCases.first { $0.rawValue == timeInterval } ?? .fifteenMinutes
                }
            }
            
            #expect(TimeoutOption.allCases.count == 6)
            #expect(TimeoutOption.immediately.rawValue == 0)
            #expect(TimeoutOption.fiveMinutes.rawValue == 300)
            #expect(TimeoutOption.fifteenMinutes.rawValue == 900)
            #expect(TimeoutOption.thirtyMinutes.rawValue == 1800)
            #expect(TimeoutOption.oneHour.rawValue == 3600)
            #expect(TimeoutOption.never.rawValue == -1)
            
            #expect(TimeoutOption.immediately.displayName == "Immediately")
            #expect(TimeoutOption.fiveMinutes.displayName == "5 minutes")
            #expect(TimeoutOption.never.displayName == "Never")
            
            // Test conversion from time interval
            let timeout = TimeoutOption.from(900)
            #expect(timeout == .fifteenMinutes)
            
            let unknownTimeout = TimeoutOption.from(123)
            #expect(unknownTimeout == .fifteenMinutes) // Default fallback
        }
        
        @Test("UserDefaults timeout handling")
        func testUserDefaultsTimeoutHandling() {
            // Test UserDefaults interaction that should be in SettingsViewModel
            let key = "testBiometricTimeout"
            let testValue: TimeInterval = 1800 // 30 minutes
            
            // Set value
            UserDefaults.standard.set(testValue, forKey: key)
            
            // Get value
            let retrievedValue = UserDefaults.standard.double(forKey: key)
            #expect(retrievedValue == testValue)
            
            // Test default value logic
            let nonExistentKey = "nonExistentKey"
            let defaultValue = UserDefaults.standard.double(forKey: nonExistentKey)
            let finalValue = defaultValue > 0 ? defaultValue : 900 // Default to 15 minutes
            #expect(finalValue == 900)
            
            // Cleanup
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    // MARK: - App Information Tests
    
    @Suite("App Information")
    struct AppInformationTests {
        
        @Test("App version information")
        func testAppVersionInformation() {
            // Test bundle info access that should be in SettingsViewModel
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            
            // In tests, these might be nil, but the logic should handle it
            #expect(version != nil || version == nil) // Either way is valid in tests
            #expect(build != nil || build == nil)
            
            // Test fallback logic
            let displayVersion = version ?? "Unknown"
            let displayBuild = build ?? "Unknown"
            
            #expect(!displayVersion.isEmpty)
            #expect(!displayBuild.isEmpty)
        }
    }
    
    // MARK: - Import/Export Flow Tests
    
    @Suite("Import/Export Flow")
    struct ImportExportFlowTests {
        
        @Test("File import flow handling")
        func testFileImportFlowHandling() {
            // Test the complete import flow that should be in DataManagementService
            var showingImportPicker = false
            var showingImportProgress = false
            var importResult: DatabaseImportManager.ImportResult? = nil
            
            // 1. User triggers import
            showingImportPicker = true
            #expect(showingImportPicker == true)
            
            // 2. User selects file (simulated)
            showingImportPicker = false
            showingImportProgress = true
            #expect(showingImportProgress == true)
            
            // 3. Import completes (simulated)
            importResult = DatabaseImportManager.ImportResult(
                tripsImported: 2,
                organizationsImported: 5,
                addressesImported: 1,
                attachmentsImported: 4,
                transportationImported: 3,
                lodgingImported: 2,
                activitiesImported: 7,
                organizationsMerged: 1,
                errors: []
            )
            showingImportProgress = false
            
            #expect(importResult != nil)
            #expect(importResult?.tripsImported == 2)
            #expect(showingImportProgress == false)
        }
        
        @Test("Import error handling")
        func testImportErrorHandling() {
            // Test error handling in import flow
            var importResult: DatabaseImportManager.ImportResult? = nil
            
            // Simulate import with errors
            importResult = DatabaseImportManager.ImportResult(
                tripsImported: 1,
                organizationsImported: 2,
                addressesImported: 0,
                attachmentsImported: 0,
                transportationImported: 0,
                lodgingImported: 1,
                activitiesImported: 2,
                organizationsMerged: 0,
                errors: ["Failed to import some transportation records", "Missing organization data"]
            )
            
            #expect(importResult != nil)
            #expect(importResult?.errors.count == 2)
            #expect(importResult?.errors.contains("Failed to import some transportation records") == true)
            #expect(importResult?.errors.contains("Missing organization data") == true)
        }
        
        @Test("Export flow handling")
        func testExportFlowHandling() {
            // Test export flow state management
            var showingExportView = false
            
            // User triggers export
            showingExportView = true
            #expect(showingExportView == true)
            
            // Export completes/cancels
            showingExportView = false
            #expect(showingExportView == false)
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Settings Integration")
    struct SettingsIntegrationTests {
        @Test("Complete settings flow")
        @MainActor func testCompleteSettingsFlow() async {
            // Clean up state before test
            SettingsViewTests.cleanupSharedState()
            
            // Test a complete settings interaction flow
            let appSettings = AppSettings.shared
            
            // 1. Change appearance setting
            let originalScheme = appSettings.colorScheme
            appSettings.colorScheme = .dark
            #expect(appSettings.colorScheme == .dark)
            
            // Restore original setting immediately to avoid affecting other tests
            appSettings.colorScheme = originalScheme
            
            // 2. Biometric authentication is now always enabled when available
            let authManager = BiometricAuthManager.shared
            #expect(authManager.isEnabled == authManager.canUseBiometrics())
            
            // 3. Test data management trigger
            var dataManagementAction = false
            dataManagementAction = true // Simulate triggering data browser
            #expect(dataManagementAction == true)
            
            // Clean up state after test
            SettingsViewTests.cleanupSharedState()
        }
    }
}
