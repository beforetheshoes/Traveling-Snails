//
//  SQLiteDataCoreTests.swift
//  Traveling Snails Tests
//

import Foundation
import Testing
@testable import Traveling_Snails

@Suite("SQLiteData Core Tests")
struct SQLiteDataCoreTests {
    @Test("Trip CRUD round-trip")
    @MainActor
    func testTripCRUD() throws {
        let testBase = SQLiteDataTestBase()
        try testBase.verifyDatabaseEmpty()

        let tripID = UUID()
        try testBase.database.write { db in
            let trip = Trip(
                id: tripID,
                name: "Test Trip",
                notes: "Notes",
                createdDate: Date(),
                isProtected: false,
                startDate: Date(),
                endDate: Date(),
                hasStartDate: true,
                hasEndDate: true
            )
            try Trip.upsert { trip }.execute(db)
        }

        let trip = try testBase.database.read { db in
            try Trip.find(tripID).fetchOne(db)
        }
        #expect(trip != nil)
        #expect(trip?.name == "Test Trip")

        try testBase.database.write { db in
            try Trip.find(tripID).update {
                $0.name = "Updated Trip"
            }.execute(db)
        }

        let updatedTrip = try testBase.database.read { db in
            try Trip.find(tripID).fetchOne(db)
        }
        #expect(updatedTrip?.name == "Updated Trip")

        try testBase.database.write { db in
            try Trip.find(tripID).delete().execute(db)
        }

        let deletedTrip = try testBase.database.read { db in
            try Trip.find(tripID).fetchOne(db)
        }
        #expect(deletedTrip == nil)
    }

    @Test("Cascade delete removes dependent activities")
    @MainActor
    func testCascadeDeleteActivities() throws {
        let testBase = SQLiteDataTestBase()

        let tripID = UUID()
        let activityID = UUID()
        try testBase.database.write { db in
            let trip = Trip(id: tripID, name: "Trip")
            try Trip.upsert { trip }.execute(db)

            let activity = Activity(
                id: activityID,
                name: "Activity",
                start: Date(),
                startTZId: TimeZone.current.identifier,
                end: Date(),
                endTZId: TimeZone.current.identifier,
                cost: 0,
                paid: .none,
                reservation: "",
                notes: "",
                tripID: tripID
            )
            try Activity.upsert { activity }.execute(db)
        }

        let activity = try testBase.database.read { db in
            try Activity.find(activityID).fetchOne(db)
        }
        #expect(activity != nil)

        try testBase.database.write { db in
            try Trip.find(tripID).delete().execute(db)
        }

        let deletedActivity = try testBase.database.read { db in
            try Activity.find(activityID).fetchOne(db)
        }
        #expect(deletedActivity == nil)
    }
}
