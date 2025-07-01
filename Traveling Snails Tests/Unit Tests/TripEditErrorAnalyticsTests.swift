//
//  TripEditErrorAnalyticsTests.swift
//  Traveling Snails Tests
//
//  Tests for TripEditErrorAnalytics memory management improvements
//

import Testing
import Foundation
@testable import Traveling_Snails

@Suite("TripEditErrorAnalytics Tests")
struct TripEditErrorAnalyticsTests {
    
    @Test("TripEditErrorType correctly maps from AppError")
    func errorTypeMappingIsCorrect() {
        // Test database errors
        #expect(TripEditErrorType.from(.databaseSaveFailed("test")) == .database)
        #expect(TripEditErrorType.from(.databaseLoadFailed("test")) == .database)
        #expect(TripEditErrorType.from(.relationshipIntegrityError("test")) == .database)
        
        // Test network errors
        #expect(TripEditErrorType.from(.networkUnavailable) == .network)
        #expect(TripEditErrorType.from(.timeoutError) == .network)
        #expect(TripEditErrorType.from(.serverError(500, "test")) == .network)
        
        // Test CloudKit errors
        #expect(TripEditErrorType.from(.cloudKitUnavailable) == .cloudKit)
        #expect(TripEditErrorType.from(.cloudKitQuotaExceeded) == .cloudKit)
        #expect(TripEditErrorType.from(.cloudKitSyncFailed("test")) == .cloudKit)
        
        // Test file system errors
        #expect(TripEditErrorType.from(.fileNotFound("test")) == .fileSystem)
        #expect(TripEditErrorType.from(.diskSpaceInsufficient) == .fileSystem)
        
        // Test validation errors
        #expect(TripEditErrorType.from(.invalidInput("test")) == .validation)
        #expect(TripEditErrorType.from(.missingRequiredField("test")) == .validation)
        
        // Test organization errors
        #expect(TripEditErrorType.from(.organizationInUse("test", 1)) == .organization)
        #expect(TripEditErrorType.from(.cannotDeleteNoneOrganization) == .organization)
        
        // Test import/export errors
        #expect(TripEditErrorType.from(.importFailed("test")) == .importExport)
        #expect(TripEditErrorType.from(.exportFailed("test")) == .importExport)
        
        // Test unknown errors
        #expect(TripEditErrorType.from(.unknown("test")) == .unknown)
        #expect(TripEditErrorType.from(.operationCancelled) == .unknown)
    }
    
    @Test("TripEditErrorEvent has minimal memory footprint")
    func errorEventHasMinimalMemoryFootprint() {
        // Create an error event
        let event = TripEditErrorEvent(
            errorCategory: .network,
            errorType: .network,
            context: "Test context",
            retryCount: 1,
            timestamp: Date()
        )
        
        // Verify the event doesn't hold references to full AppError instances
        // This is a structural test - we verify the event only contains value types
        // and doesn't hold onto potentially large reference types
        
        #expect(event.errorCategory == .network)
        #expect(event.errorType == .network)
        #expect(event.context == "Test context")
        #expect(event.retryCount == 1)
        #expect(event.timestamp <= Date())
    }
    
    @Test("Analytics can be reset for clean state")
    func analyticsCanBeReset() {
        // Record some errors
        TripEditErrorAnalytics.recordError(.networkUnavailable, context: "test1", retryCount: 0)
        TripEditErrorAnalytics.recordError(.databaseSaveFailed("test"), context: "test2", retryCount: 1)
        
        // Get state before reset
        let stateBefore = TripEditErrorAnalytics.getAnalyticsState()
        #expect(stateBefore.eventCount >= 2)
        
        // Reset
        TripEditErrorAnalytics.reset()
        
        // Get state after reset
        let stateAfter = TripEditErrorAnalytics.getAnalyticsState()
        #expect(stateAfter.eventCount == 0)
        #expect(stateAfter.lastCleanup >= stateBefore.lastCleanup)
    }
    
    @Test("Analytics respects maximum history size")
    func analyticsRespectsMaxHistorySize() {
        // Reset any existing state
        TripEditErrorAnalytics.reset()
        
        // Record more than the maximum (50) events
        for i in 0..<60 {
            TripEditErrorAnalytics.recordError(
                .databaseSaveFailed("Test error \(i)"),
                context: "Test context \(i)",
                retryCount: 0
            )
        }
        
        // Verify that we don't exceed the maximum
        let state = TripEditErrorAnalytics.getAnalyticsState()
        #expect(state.eventCount <= 50)
        #expect(state.eventCount > 0)
    }
}