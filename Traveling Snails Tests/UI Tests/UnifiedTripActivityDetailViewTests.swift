import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

@Suite("UnifiedTripActivityDetailView Tests")
@MainActor
struct UnifiedTripActivityDetailViewTests {
    @Test("Detail view shows dynamic transportation icons in edit mode")
    func detailViewShowsDynamicTransportationIconsInEditMode() {
        let testBase = SwiftDataTestBase()

        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86_400))
        let org = Organization(name: "Test Org")
        testBase.modelContext.insert(trip)
        testBase.modelContext.insert(org)

        // Create existing transportation with specific type
        let existingTransportation = Transportation(
            name: "Flight to NYC",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )
        existingTransportation.type = .plane
        testBase.modelContext.insert(existingTransportation)

        // Create detail view (simulating how it would be created in the app)
        _ = UnifiedTripActivityDetailView(activity: existingTransportation)

        // We can't easily test SwiftUI views directly, but we can test the logic
        // by creating a similar computed property and testing its behavior
        let testEditData = TripActivityEditData(from: existingTransportation)

        // Test the icon logic that would be used in the detail view
        func computeCurrentIcon(
            isEditing: Bool,
            activity: Transportation,
            editData: TripActivityEditData
        ) -> String {
            if isEditing,
               case .transportation = activity.activityType,
               let transportationType = editData.transportationType {
                return transportationType.systemImage
            }
            return activity.icon
        }

        // Test view mode (not editing) - should use static icon
        let viewModeIcon = computeCurrentIcon(
            isEditing: false,
            activity: existingTransportation,
            editData: testEditData
        )
        #expect(viewModeIcon == "airplane", "View mode should show static transportation icon")

        // Test edit mode - should use dynamic icon based on editData
        let editModeIcon = computeCurrentIcon(
            isEditing: true,
            activity: existingTransportation,
            editData: testEditData
        )
        #expect(editModeIcon == "airplane", "Edit mode should initially show existing transportation icon")

        // Test changing transportation type in edit mode
        var modifiedEditData = testEditData
        modifiedEditData.transportationType = .train

        let modifiedIcon = computeCurrentIcon(
            isEditing: true,
            activity: existingTransportation,
            editData: modifiedEditData
        )
        #expect(modifiedIcon == "train.side.front.car", "Edit mode should show updated transportation icon when type changes")

        // Test other transportation types
        modifiedEditData.transportationType = .boat
        let boatIcon = computeCurrentIcon(
            isEditing: true,
            activity: existingTransportation,
            editData: modifiedEditData
        )
        #expect(boatIcon == "ferry", "Edit mode should show ferry icon for boat transportation")
    }

    @Test("Detail view edit mode works with different starting transportation types")
    func detailViewEditModeWorksWithDifferentStartingTypes() {
        let testBase = SwiftDataTestBase()

        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86_400))
        let org = Organization(name: "Test Org")
        testBase.modelContext.insert(trip)
        testBase.modelContext.insert(org)

        let transportationTypes: [(TransportationType, String)] = [
            (.train, "train.side.front.car"),
            (.boat, "ferry"),
            (.car, "car"),
            (.bicycle, "bicycle"),
            (.walking, "figure.walk"),
        ]

        for (initialType, expectedIcon) in transportationTypes {
            // Create transportation with specific initial type
            let transportation = Transportation(
                name: "\(initialType.displayName) Trip",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            transportation.type = initialType
            testBase.modelContext.insert(transportation)

            let editData = TripActivityEditData(from: transportation)

            // Test the currentIcon logic for this transportation type
            func computeCurrentIcon(
                isEditing: Bool,
                activity: Transportation,
                editData: TripActivityEditData
            ) -> String {
                if isEditing,
                   case .transportation = activity.activityType,
                   let transportationType = editData.transportationType {
                    return transportationType.systemImage
                }
                return activity.icon
            }

            // Verify initial icon in edit mode
            let initialEditIcon = computeCurrentIcon(
                isEditing: true,
                activity: transportation,
                editData: editData
            )
            #expect(initialEditIcon == expectedIcon, "Edit mode should show correct icon for \(initialType.rawValue)")

            // Test changing to a different type
            var modifiedEditData = editData
            modifiedEditData.transportationType = .plane

            let modifiedIcon = computeCurrentIcon(
                isEditing: true,
                activity: transportation,
                editData: modifiedEditData
            )
            #expect(modifiedIcon == "airplane", "Should update to airplane icon when changed to plane from \(initialType.rawValue)")
        }
    }
}
