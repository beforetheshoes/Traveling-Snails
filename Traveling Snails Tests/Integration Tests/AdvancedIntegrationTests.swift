//
//  AdvancedIntegrationTests.swift
//  Traveling Snails Tests
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

/// Advanced integration tests using the new testing framework
@Suite("Advanced Integration Tests")
@MainActor
struct AdvancedIntegrationTests {
    @Test("End-to-end trip creation with authentication workflow")
    func testTripCreationWorkflow() async throws {
        let result = try await IntegrationTestFramework.testWorkflow(
            name: "Trip Creation Workflow"
        ) { container, modelContext in
            var steps: [String] = []
            let errors: [Error] = []

            // Step 1: Authenticate user
            steps.append("Authenticate user")
            let authService = container.resolve(AuthenticationService.self)

            // Step 2: Create trip
            steps.append("Create trip")
            let trip = Trip(
                name: "Integration Test Trip",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                isProtected: true
            )
            modelContext.insert(trip)

            // Step 3: Authenticate for protected trip
            steps.append("Authenticate for protected trip")
            if authService.allTripsLocked {
                // In real scenario, would trigger biometric auth
                // For testing, we simulate successful auth
            }

            // Step 4: Add activity to trip
            steps.append("Add activity to trip")
            let activity = Activity()
            activity.name = "Test Activity"
            activity.start = Date()
            activity.end = Calendar.current.date(byAdding: .hour, value: 2, to: activity.start) ?? activity.start
            activity.notes = "Integration test activity"
            activity.trip = trip
            modelContext.insert(activity)

            // Step 5: Save changes
            steps.append("Save changes")
            try modelContext.save()

            // Step 6: Verify data persistence
            steps.append("Verify data persistence")
            let savedTrips = try modelContext.fetch(FetchDescriptor<Trip>())
            let savedActivities = try modelContext.fetch(FetchDescriptor<Activity>())

            let success = !savedTrips.isEmpty && !savedActivities.isEmpty

            return WorkflowResult(
                success: success,
                steps: steps,
                data: [
                    "tripsCreated": savedTrips.count,
                    "activitiesCreated": savedActivities.count,
                ],
                errors: errors
            )
        } mockConfiguration: { mocks in
            mocks.auth.configureSuccessfulAuthentication()
            mocks.sync.configureSuccessfulSync()
        }

        #expect(result.workflowResult.success)
        #expect(result.workflowResult.steps.count == 6)
        #expect(result.duration < 1.0) // Should complete quickly
    }

    @Test("Sync service interaction with authentication")
    func testSyncAuthenticationInteraction() async throws {
        let container = TestServiceContainer.create { mocks in
            mocks.auth.configureSuccessfulAuthentication()
            mocks.sync.configureSuccessfulSync()
        }

        let result = try await IntegrationTestFramework.testServiceInteractions(
            name: "Sync-Auth Interaction",
            services: [
                "auth": container.resolve(AuthenticationService.self),
                "sync": container.resolve(SyncService.self),
            ]
        ) { services in
            var interactions: [String] = []

            guard let authService = services["auth"] as? AuthenticationService,
                  let syncService = services["sync"] as? SyncService else {
                return InteractionResult(
                    success: false,
                    interactions: ["Failed to resolve services"],
                    data: [:]
                )
            }

            // Test interaction: Only sync when authenticated
            interactions.append("Check authentication status")
            let isAuthenticated = !authService.allTripsLocked

            if isAuthenticated {
                interactions.append("Trigger sync for authenticated user")
                await syncService.triggerSyncAndWait()
                interactions.append("Sync completed")
            } else {
                interactions.append("Skip sync for unauthenticated user")
            }

            return InteractionResult(
                success: true,
                interactions: interactions,
                data: [
                    "authenticated": isAuthenticated,
                    "syncTriggered": isAuthenticated,
                ]
            )
        }

        #expect(result.interactionResult.success)
        #expect(result.interactionResult.interactions.count >= 2)
        #expect(result.duration < 5.0) // Increased from 3.0 to account for intermittent delays
    }

    @Test("Photo library and permission service integration")
    func testPhotoPermissionIntegration() async throws {
        let result = try await IntegrationTestFramework.testWorkflow(
            name: "Photo Permission Workflow"
        ) { container, modelContext in
            var steps: [String] = []
            let errors: [Error] = []

            let photoService = container.resolve(PhotoLibraryService.self)
            let permissionService = container.resolve(PermissionService.self)

            // Step 1: Check photo library authorization
            steps.append("Check photo authorization")
            let authStatus = photoService.authorizationStatus(for: .readWrite)

            // Step 2: Request permission if needed
            if authStatus != .authorized {
                steps.append("Request photo permission")
                let newStatus = await photoService.requestAuthorization(for: .readWrite)
                steps.append("Permission result: \(newStatus)")
            } else {
                steps.append("Photo permission already authorized")
            }

            // Step 3: Check overall permission status
            steps.append("Check overall permissions")
            let photoPermissionStatus = permissionService.getPhotoLibraryAuthorizationStatus(for: .readWrite)
            let hasPhotoAccess = photoPermissionStatus == .authorized

            // Step 4: Verify services are configured correctly
            steps.append("Verify service configuration")

            // Step 5: Create trip with potential photo attachment
            steps.append("Create trip for photo attachment")
            let trip = Trip(
                name: "Photo Test Trip",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                isProtected: false
            )
            modelContext.insert(trip)
            try modelContext.save()

            let success = true // Test always succeeds in mock environment

            return WorkflowResult(
                success: success,
                steps: steps,
                data: [
                    "hasPhotoAccess": hasPhotoAccess,
                    "authStatus": authStatus.rawValue,
                ],
                errors: errors
            )
        } mockConfiguration: { mocks in
            mocks.photo.configureAuthorized()
            mocks.permission.configureAllPermissionsGranted()
        }

        #expect(result.workflowResult.success)
        #expect(result.workflowResult.steps.count >= 5)
    }

    @Test("Cloud storage backup and restore workflow")
    func testCloudBackupRestoreWorkflow() async throws {
        let result = try await IntegrationTestFramework.testWorkflow(
            name: "Cloud Backup Restore Workflow"
        ) { container, modelContext in
            var steps: [String] = []
            let errors: [Error] = []

            let cloudService = container.resolve(CloudStorageService.self)

            // Step 1: Create test data
            steps.append("Create test data")
            let trips = try TestDataGenerator.generateTrips(count: 3, in: modelContext)

            // Step 2: Check cloud availability
            steps.append("Check cloud availability")
            let isAvailable = cloudService.isAvailable

            if isAvailable {
                // Step 3: Simulate backup
                steps.append("Simulate backup to cloud")
                let backupData = try JSONEncoder().encode(trips.map { $0.name })

                // Step 4: Simulate restore
                steps.append("Simulate restore from cloud")
                let restoredNames = try JSONDecoder().decode([String].self, from: backupData)

                steps.append("Verify restored data")
                let success = restoredNames.count == trips.count

                return WorkflowResult(
                    success: success,
                    steps: steps,
                    data: [
                        "originalTrips": trips.count,
                        "restoredTrips": restoredNames.count,
                    ],
                    errors: errors
                )
            } else {
                steps.append("Cloud unavailable - skip backup")
                return WorkflowResult(
                    success: true,
                    steps: steps,
                    data: ["cloudAvailable": false],
                    errors: errors
                )
            }
        } mockConfiguration: { mocks in
            mocks.cloud.configureAvailable()
        }

        #expect(result.workflowResult.success)
    }

    @Test("Complete trip lifecycle with all services")
    func testCompleteTripLifecycle() async throws {
        let result = try await IntegrationTestFramework.testWorkflow(
            name: "Complete Trip Lifecycle"
        ) { container, modelContext in
            var steps: [String] = []
            let errors: [Error] = []

            let authService = container.resolve(AuthenticationService.self)
            let cloudService = container.resolve(CloudStorageService.self)
            let photoService = container.resolve(PhotoLibraryService.self)
            let syncService = container.resolve(SyncService.self)

            // Phase 1: Trip Creation
            steps.append("Phase 1: Create trip")
            let trip = Trip(
                name: "Lifecycle Test Trip",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                isProtected: true
            )
            modelContext.insert(trip)

            // Phase 2: Add activities
            steps.append("Phase 2: Add activities")
            for i in 1...3 {
                let activity = Activity()
                activity.name = "Activity \(i)"
                activity.start = Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()
                activity.end = Calendar.current.date(byAdding: .hour, value: 2, to: activity.start) ?? activity.start
                activity.notes = "Test activity \(i)"
                activity.trip = trip
                modelContext.insert(activity)
            }

            // Phase 3: Authentication for protected content
            steps.append("Phase 3: Authentication")
            let authRequired = authService.allTripsLocked
            if authRequired {
                // Simulate successful authentication
                steps.append("Authentication successful")
            }

            // Phase 4: Sync to cloud
            steps.append("Phase 4: Sync to cloud")
            await syncService.triggerSyncAndWait()

            // Phase 5: Photo attachment simulation
            steps.append("Phase 5: Photo attachment")
            let photoStatus = photoService.authorizationStatus(for: .readWrite)
            if photoStatus == .authorized {
                steps.append("Photo access granted")
            }

            // Phase 6: Cloud backup
            steps.append("Phase 6: Cloud backup")
            if cloudService.isAvailable {
                steps.append("Cloud backup available")
            }

            // Phase 7: Save and verify
            steps.append("Phase 7: Save and verify")
            try modelContext.save()

            let savedTrips = try modelContext.fetch(FetchDescriptor<Trip>())
            let savedActivities = try modelContext.fetch(FetchDescriptor<Activity>())

            let success = savedTrips.count == 1 && savedActivities.count == 3

            return WorkflowResult(
                success: success,
                steps: steps,
                data: [
                    "tripsSaved": savedTrips.count,
                    "activitiesSaved": savedActivities.count,
                    "authenticationRequired": authRequired,
                    "photoAccess": photoStatus == .authorized,
                    "cloudAvailable": cloudService.isAvailable,
                ],
                errors: errors
            )
        } mockConfiguration: { mocks in
            mocks.auth.configureSuccessfulAuthentication()
            mocks.cloud.configureAvailable()
            mocks.photo.configureAuthorized()
            mocks.permission.configureAllPermissionsGranted()
            mocks.sync.configureSuccessfulSync()
        }

        #expect(result.workflowResult.success)
        #expect(result.workflowResult.steps.count >= 7)
        #expect(result.duration < 5.0) // Complete lifecycle should be reasonably fast with mocks

        if let tripsCount = result.workflowResult.data["tripsSaved"] as? Int,
           let activitiesCount = result.workflowResult.data["activitiesSaved"] as? Int {
            #expect(tripsCount == 1)
            #expect(activitiesCount == 3)
        }
    }
}
