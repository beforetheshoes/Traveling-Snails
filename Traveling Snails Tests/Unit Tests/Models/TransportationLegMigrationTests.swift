import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("TransportationLeg migrations", .serialized)
struct TransportationLegMigrationTests {
    @Test("Existing transportations get backfilled with 1 leg", .tags(.unit, .medium, .database))
    func backfillsExistingTransportation() throws {
        let dbq = try DatabaseQueue(path: ":memory:")

        // Simulate an "old" database that had core tables but not transportationLegs,
        // and that already recorded the core migration as applied.
        try dbq.write { db in
            // Create core tables (same as the first migration).
            try #sql(
                """
                CREATE TABLE "addresses" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "street" TEXT NOT NULL DEFAULT '',
                  "city" TEXT NOT NULL DEFAULT '',
                  "state" TEXT NOT NULL DEFAULT '',
                  "country" TEXT NOT NULL DEFAULT '',
                  "postalCode" TEXT NOT NULL DEFAULT '',
                  "latitude" REAL NOT NULL DEFAULT 0,
                  "longitude" REAL NOT NULL DEFAULT 0,
                  "formattedAddress" TEXT NOT NULL DEFAULT ''
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "organizations" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL DEFAULT '',
                  "phone" TEXT NOT NULL DEFAULT '',
                  "email" TEXT NOT NULL DEFAULT '',
                  "website" TEXT NOT NULL DEFAULT '',
                  "logoURL" TEXT NOT NULL DEFAULT '',
                  "cachedLogoFilename" TEXT NOT NULL DEFAULT '',
                  "addressID" TEXT REFERENCES "addresses"("id") ON DELETE SET NULL
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "trips" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL DEFAULT '',
                  "notes" TEXT NOT NULL DEFAULT '',
                  "createdDate" TEXT NOT NULL,
                  "isProtected" INTEGER NOT NULL DEFAULT 0,
                  "startDate" TEXT NOT NULL,
                  "endDate" TEXT NOT NULL,
                  "hasStartDate" INTEGER NOT NULL DEFAULT 0,
                  "hasEndDate" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "activities" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL DEFAULT '',
                  "start" TEXT NOT NULL,
                  "startTZId" TEXT NOT NULL DEFAULT '',
                  "end" TEXT NOT NULL,
                  "endTZId" TEXT NOT NULL DEFAULT '',
                  "cost" TEXT NOT NULL DEFAULT '0',
                  "paid" TEXT NOT NULL DEFAULT 'none',
                  "reservation" TEXT NOT NULL DEFAULT '',
                  "notes" TEXT NOT NULL DEFAULT '',
                  "tripID" TEXT REFERENCES "trips"("id") ON DELETE CASCADE,
                  "organizationID" TEXT REFERENCES "organizations"("id") ON DELETE SET NULL,
                  "addressID" TEXT REFERENCES "addresses"("id") ON DELETE SET NULL,
                  "customLocationName" TEXT NOT NULL DEFAULT '',
                  "hideLocation" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "lodgings" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL DEFAULT '',
                  "start" TEXT NOT NULL,
                  "checkInTZId" TEXT NOT NULL DEFAULT '',
                  "end" TEXT NOT NULL,
                  "checkOutTZId" TEXT NOT NULL DEFAULT '',
                  "cost" TEXT NOT NULL DEFAULT '0',
                  "paid" TEXT NOT NULL DEFAULT 'none',
                  "reservation" TEXT NOT NULL DEFAULT '',
                  "notes" TEXT NOT NULL DEFAULT '',
                  "tripID" TEXT REFERENCES "trips"("id") ON DELETE CASCADE,
                  "organizationID" TEXT REFERENCES "organizations"("id") ON DELETE SET NULL,
                  "addressID" TEXT REFERENCES "addresses"("id") ON DELETE SET NULL,
                  "customLocationName" TEXT NOT NULL DEFAULT '',
                  "hideLocation" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "transportations" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL DEFAULT '',
                  "type" TEXT NOT NULL DEFAULT 'plane',
                  "start" TEXT NOT NULL,
                  "startTZId" TEXT NOT NULL DEFAULT '',
                  "end" TEXT NOT NULL,
                  "endTZId" TEXT NOT NULL DEFAULT '',
                  "cost" TEXT NOT NULL DEFAULT '0',
                  "paid" TEXT NOT NULL DEFAULT 'none',
                  "confirmation" TEXT NOT NULL DEFAULT '',
                  "notes" TEXT NOT NULL DEFAULT '',
                  "tripID" TEXT REFERENCES "trips"("id") ON DELETE CASCADE,
                  "organizationID" TEXT REFERENCES "organizations"("id") ON DELETE SET NULL
                ) STRICT
                """
            ).execute(db)

            try #sql(
                """
                CREATE TABLE "embeddedFileAttachments" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "fileName" TEXT NOT NULL DEFAULT '',
                  "originalFileName" TEXT NOT NULL DEFAULT '',
                  "fileSize" INTEGER NOT NULL DEFAULT 0,
                  "mimeType" TEXT NOT NULL DEFAULT '',
                  "fileExtension" TEXT NOT NULL DEFAULT '',
                  "createdDate" TEXT NOT NULL,
                  "fileDescription" TEXT NOT NULL DEFAULT '',
                  "fileData" BLOB,
                  "activityID" TEXT REFERENCES "activities"("id") ON DELETE CASCADE,
                  "lodgingID" TEXT REFERENCES "lodgings"("id") ON DELETE CASCADE,
                  "transportationID" TEXT REFERENCES "transportations"("id") ON DELETE CASCADE
                ) STRICT
                """
            ).execute(db)

            // Mark the first migration as applied (GRDB uses grdb_migrations with identifier only).
            try #sql(
                """
                CREATE TABLE IF NOT EXISTS "grdb_migrations" (
                  "identifier" TEXT NOT NULL PRIMARY KEY
                )
                """
            ).execute(db)
            try #sql("INSERT OR REPLACE INTO grdb_migrations(identifier) VALUES('Create core tables')")
                .execute(db)

            // Insert one transportation row.
            let transportation = Transportation(
                name: "Flight 1",
                type: .plane,
                start: Date(timeIntervalSince1970: 1_700_000_000),
                startTZId: "America/New_York",
                end: Date(timeIntervalSince1970: 1_700_003_600),
                endTZId: "America/Los_Angeles",
                cost: 123,
                paid: .none,
                confirmation: "ABC123",
                notes: ""
            )
            try Transportation.insert { transportation }.execute(db)
        }

        // Now run the app migrator; it should apply the new migration and backfill legs.
        var migrator = makeMigrator()
        try migrator.migrate(dbq)

        let legs = try dbq.read { db in
            try TransportationLeg.fetchAll(db)
        }
        #expect(legs.count == 1)
        let leg = try #require(legs.first)
        #expect(leg.sortIndex == 0)
        #expect(leg.departureTZId == "America/New_York")
        #expect(leg.arrivalTZId == "America/Los_Angeles")
        #expect(leg.type == .plane)
    }
}

