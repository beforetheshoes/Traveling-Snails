//
//  AppInitializationHangTest.swift
//  Traveling Snails Tests
//
//

import Testing
import Foundation
@testable import Traveling_Snails

@Suite("App Initialization Hang Test")
struct AppInitializationHangTest {
    
    @Test("Test should complete in under 5 seconds without hanging", .tags(.unit, .fast, .critical))
    func testBasicTestExecutionSpeed() async {
        let startTime = Date()
        
        // This is the simplest possible test - just check that true is true
        #expect(true == true)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Test should complete almost instantly (definitely under 1 second)
        #expect(duration < 1.0, "Test took \(duration) seconds - should be nearly instant")
        
        print("🚀 Test completed in \(duration) seconds")
    }
    
    @Test("Test environment detection should work quickly", .tags(.unit, .fast, .critical))
    func testEnvironmentDetection() async {
        let startTime = Date()
        
        // Check if test environment is detected
        let isTests = NSClassFromString("XCTestCase") != nil
        let hasTestEnv = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        
        #expect(isTests || hasTestEnv, "Should detect test environment")
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Environmental checks should be instant
        #expect(duration < 0.1, "Environment detection took \(duration) seconds - should be instant")
        
        print("🔍 Environment detection completed in \(duration) seconds")
    }
}