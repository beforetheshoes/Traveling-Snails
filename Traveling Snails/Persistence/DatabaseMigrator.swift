//
//  DatabaseMigrator.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

func makeMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()

    migrator.registerMigration("Create core tables") { db in
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

        try #sql("CREATE INDEX IF NOT EXISTS \"idx_activities_tripID\" ON \"activities\"(\"tripID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_lodgings_tripID\" ON \"lodgings\"(\"tripID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportations_tripID\" ON \"transportations\"(\"tripID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_activities_orgID\" ON \"activities\"(\"organizationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_lodgings_orgID\" ON \"lodgings\"(\"organizationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportations_orgID\" ON \"transportations\"(\"organizationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_activities_start\" ON \"activities\"(\"start\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_lodgings_start\" ON \"lodgings\"(\"start\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportations_start\" ON \"transportations\"(\"start\")").execute(db)
    }

    migrator.registerMigration("Add transportation legs") { db in
        try #sql(
            """
            CREATE TABLE "transportationLegs" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "transportationID" TEXT NOT NULL REFERENCES "transportations"("id") ON DELETE CASCADE,
              "sortIndex" INTEGER NOT NULL DEFAULT 0,
              "type" TEXT NOT NULL DEFAULT 'plane',
              "departure" TEXT NOT NULL,
              "departureTZId" TEXT NOT NULL DEFAULT '',
              "departureLocationName" TEXT NOT NULL DEFAULT '',
              "departureAddressID" TEXT REFERENCES "addresses"("id") ON DELETE SET NULL,
              "departureGateOrPlatform" TEXT NOT NULL DEFAULT '',
              "departureTerminal" TEXT NOT NULL DEFAULT '',
              "arrival" TEXT NOT NULL,
              "arrivalTZId" TEXT NOT NULL DEFAULT '',
              "arrivalLocationName" TEXT NOT NULL DEFAULT '',
              "arrivalAddressID" TEXT REFERENCES "addresses"("id") ON DELETE SET NULL,
              "arrivalGateOrPlatform" TEXT NOT NULL DEFAULT '',
              "arrivalTerminal" TEXT NOT NULL DEFAULT '',
              "serviceNumber" TEXT NOT NULL DEFAULT '',
              "confirmation" TEXT NOT NULL DEFAULT '',
              "seatNumber" TEXT NOT NULL DEFAULT '',
              "cabinClass" TEXT NOT NULL DEFAULT 'unknown',
              "seatType" TEXT NOT NULL DEFAULT 'unknown',
              "boardingGroup" TEXT NOT NULL DEFAULT '',
              "notes" TEXT NOT NULL DEFAULT ''
            ) STRICT
            """
        ).execute(db)

        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportationLegs_transportationID\" ON \"transportationLegs\"(\"transportationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportationLegs_transportationID_sortIndex\" ON \"transportationLegs\"(\"transportationID\",\"sortIndex\")").execute(db)

        // Backfill: every existing Transportation gets exactly 1 default leg.
        let existingTransportations = try Transportation.fetchAll(db)
        if !existingTransportations.isEmpty {
            try TransportationLeg.insert {
                for transportation in existingTransportations {
                    TransportationLeg.makeDefaultLeg(for: transportation)
                }
            }.execute(db)
        }
    }

    // MARK: - Drop extra foreign keys for CloudKit sharing compatibility
    //
    // SQLiteData only shares child records that have EXACTLY ONE foreign key.
    // Activities, lodgings, transportations, transportationLegs, and embeddedFileAttachments
    // had multiple REFERENCES constraints (e.g. tripID + organizationID + addressID),
    // which prevented them from being included when sharing a Trip.
    //
    // This migration recreates each table keeping only the single foreign key
    // that points toward the shared root (Trip), dropping the others.
    // The columns themselves are preserved — only the REFERENCES constraints are removed.

    migrator.registerMigration("Drop extra foreign keys for sharing") { db in
        // --- activities: keep only tripID REFERENCES ---
        try #sql(
            """
            CREATE TABLE "activities_new" (
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
              "organizationID" TEXT,
              "addressID" TEXT,
              "customLocationName" TEXT NOT NULL DEFAULT '',
              "hideLocation" INTEGER NOT NULL DEFAULT 0
            ) STRICT
            """
        ).execute(db)
        try #sql("INSERT INTO \"activities_new\" SELECT * FROM \"activities\"").execute(db)
        try #sql("DROP TABLE \"activities\"").execute(db)
        try #sql("ALTER TABLE \"activities_new\" RENAME TO \"activities\"").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_activities_tripID\" ON \"activities\"(\"tripID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_activities_orgID\" ON \"activities\"(\"organizationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_activities_start\" ON \"activities\"(\"start\")").execute(db)

        // --- lodgings: keep only tripID REFERENCES ---
        try #sql(
            """
            CREATE TABLE "lodgings_new" (
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
              "organizationID" TEXT,
              "addressID" TEXT,
              "customLocationName" TEXT NOT NULL DEFAULT '',
              "hideLocation" INTEGER NOT NULL DEFAULT 0
            ) STRICT
            """
        ).execute(db)
        try #sql("INSERT INTO \"lodgings_new\" SELECT * FROM \"lodgings\"").execute(db)
        try #sql("DROP TABLE \"lodgings\"").execute(db)
        try #sql("ALTER TABLE \"lodgings_new\" RENAME TO \"lodgings\"").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_lodgings_tripID\" ON \"lodgings\"(\"tripID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_lodgings_orgID\" ON \"lodgings\"(\"organizationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_lodgings_start\" ON \"lodgings\"(\"start\")").execute(db)

        // --- transportations: keep only tripID REFERENCES ---
        try #sql(
            """
            CREATE TABLE "transportations_new" (
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
              "organizationID" TEXT
            ) STRICT
            """
        ).execute(db)
        try #sql("INSERT INTO \"transportations_new\" SELECT * FROM \"transportations\"").execute(db)
        try #sql("DROP TABLE \"transportations\"").execute(db)
        try #sql("ALTER TABLE \"transportations_new\" RENAME TO \"transportations\"").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportations_tripID\" ON \"transportations\"(\"tripID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportations_orgID\" ON \"transportations\"(\"organizationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportations_start\" ON \"transportations\"(\"start\")").execute(db)

        // --- transportationLegs: keep only transportationID REFERENCES ---
        try #sql(
            """
            CREATE TABLE "transportationLegs_new" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "transportationID" TEXT NOT NULL REFERENCES "transportations"("id") ON DELETE CASCADE,
              "sortIndex" INTEGER NOT NULL DEFAULT 0,
              "type" TEXT NOT NULL DEFAULT 'plane',
              "departure" TEXT NOT NULL,
              "departureTZId" TEXT NOT NULL DEFAULT '',
              "departureLocationName" TEXT NOT NULL DEFAULT '',
              "departureAddressID" TEXT,
              "departureGateOrPlatform" TEXT NOT NULL DEFAULT '',
              "departureTerminal" TEXT NOT NULL DEFAULT '',
              "arrival" TEXT NOT NULL,
              "arrivalTZId" TEXT NOT NULL DEFAULT '',
              "arrivalLocationName" TEXT NOT NULL DEFAULT '',
              "arrivalAddressID" TEXT,
              "arrivalGateOrPlatform" TEXT NOT NULL DEFAULT '',
              "arrivalTerminal" TEXT NOT NULL DEFAULT '',
              "serviceNumber" TEXT NOT NULL DEFAULT '',
              "confirmation" TEXT NOT NULL DEFAULT '',
              "seatNumber" TEXT NOT NULL DEFAULT '',
              "cabinClass" TEXT NOT NULL DEFAULT 'unknown',
              "seatType" TEXT NOT NULL DEFAULT 'unknown',
              "boardingGroup" TEXT NOT NULL DEFAULT '',
              "notes" TEXT NOT NULL DEFAULT ''
            ) STRICT
            """
        ).execute(db)
        try #sql("INSERT INTO \"transportationLegs_new\" SELECT * FROM \"transportationLegs\"").execute(db)
        try #sql("DROP TABLE \"transportationLegs\"").execute(db)
        try #sql("ALTER TABLE \"transportationLegs_new\" RENAME TO \"transportationLegs\"").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportationLegs_transportationID\" ON \"transportationLegs\"(\"transportationID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_transportationLegs_transportationID_sortIndex\" ON \"transportationLegs\"(\"transportationID\",\"sortIndex\")").execute(db)

        // --- embeddedFileAttachments: drop ALL foreign keys ---
        // Each attachment belongs to exactly one parent (activity, lodging, or transportation)
        // but the table has columns for all three. Since we can't have a single FK pointing
        // to the shared root, we drop all REFERENCES and manage integrity in application code.
        try #sql(
            """
            CREATE TABLE "embeddedFileAttachments_new" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "fileName" TEXT NOT NULL DEFAULT '',
              "originalFileName" TEXT NOT NULL DEFAULT '',
              "fileSize" INTEGER NOT NULL DEFAULT 0,
              "mimeType" TEXT NOT NULL DEFAULT '',
              "fileExtension" TEXT NOT NULL DEFAULT '',
              "createdDate" TEXT NOT NULL,
              "fileDescription" TEXT NOT NULL DEFAULT '',
              "fileData" BLOB,
              "activityID" TEXT,
              "lodgingID" TEXT,
              "transportationID" TEXT
            ) STRICT
            """
        ).execute(db)
        try #sql("INSERT INTO \"embeddedFileAttachments_new\" SELECT * FROM \"embeddedFileAttachments\"").execute(db)
        try #sql("DROP TABLE \"embeddedFileAttachments\"").execute(db)
        try #sql("ALTER TABLE \"embeddedFileAttachments_new\" RENAME TO \"embeddedFileAttachments\"").execute(db)
    }

    // MARK: - Add collections and book items tables

    migrator.registerMigration("Add collections and book items") { db in
        try #sql(
            """
            CREATE TABLE "collections" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "name" TEXT NOT NULL DEFAULT '',
              "notes" TEXT NOT NULL DEFAULT '',
              "type" TEXT NOT NULL DEFAULT 'book',
              "coverImageURL" TEXT NOT NULL DEFAULT '',
              "coverImageData" BLOB,
              "sortOrder" INTEGER NOT NULL DEFAULT 0,
              "isProtected" INTEGER NOT NULL DEFAULT 0,
              "createdDate" TEXT NOT NULL
            ) STRICT
            """
        ).execute(db)

        try #sql("CREATE INDEX IF NOT EXISTS \"idx_collections_type\" ON \"collections\"(\"type\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_collections_createdDate\" ON \"collections\"(\"createdDate\")").execute(db)

        try #sql(
            """
            CREATE TABLE "bookItems" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "collectionID" TEXT NOT NULL REFERENCES "collections"("id") ON DELETE CASCADE,
              "title" TEXT NOT NULL DEFAULT '',
              "author" TEXT NOT NULL DEFAULT '',
              "isbn" TEXT NOT NULL DEFAULT '',
              "publisher" TEXT NOT NULL DEFAULT '',
              "publishedDate" TEXT NOT NULL DEFAULT '',
              "pageCount" INTEGER NOT NULL DEFAULT 0,
              "description" TEXT NOT NULL DEFAULT '',
              "coverImageURL" TEXT NOT NULL DEFAULT '',
              "coverImageData" BLOB,
              "externalID" TEXT NOT NULL DEFAULT '',
              "rating" INTEGER NOT NULL DEFAULT 0,
              "status" TEXT NOT NULL DEFAULT 'wantToRead',
              "startedDate" TEXT NOT NULL,
              "finishedDate" TEXT NOT NULL,
              "hasStartedDate" INTEGER NOT NULL DEFAULT 0,
              "hasFinishedDate" INTEGER NOT NULL DEFAULT 0,
              "notes" TEXT NOT NULL DEFAULT '',
              "sortOrder" INTEGER NOT NULL DEFAULT 0,
              "createdDate" TEXT NOT NULL
            ) STRICT
            """
        ).execute(db)

        try #sql("CREATE INDEX IF NOT EXISTS \"idx_bookItems_collectionID\" ON \"bookItems\"(\"collectionID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_bookItems_externalID\" ON \"bookItems\"(\"externalID\")").execute(db)
    }

    // MARK: - Add movie and TV show items tables

    migrator.registerMigration("Add movie and TV show items") { db in
        try #sql(
            """
            CREATE TABLE "movieItems" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "collectionID" TEXT NOT NULL REFERENCES "collections"("id") ON DELETE CASCADE,
              "title" TEXT NOT NULL DEFAULT '',
              "overview" TEXT NOT NULL DEFAULT '',
              "releaseDate" TEXT NOT NULL DEFAULT '',
              "runtime" INTEGER NOT NULL DEFAULT 0,
              "director" TEXT NOT NULL DEFAULT '',
              "cast" TEXT NOT NULL DEFAULT '',
              "genres" TEXT NOT NULL DEFAULT '',
              "posterURL" TEXT NOT NULL DEFAULT '',
              "backdropURL" TEXT NOT NULL DEFAULT '',
              "coverImageData" BLOB,
              "externalID" TEXT NOT NULL DEFAULT '',
              "imdbID" TEXT NOT NULL DEFAULT '',
              "rating" INTEGER NOT NULL DEFAULT 0,
              "status" TEXT NOT NULL DEFAULT 'wantToWatch',
              "watchedDate" TEXT NOT NULL,
              "hasWatchedDate" INTEGER NOT NULL DEFAULT 0,
              "notes" TEXT NOT NULL DEFAULT '',
              "sortOrder" INTEGER NOT NULL DEFAULT 0,
              "createdDate" TEXT NOT NULL,
              "voteAverage" REAL NOT NULL DEFAULT 0,
              "originalLanguage" TEXT NOT NULL DEFAULT ''
            ) STRICT
            """
        ).execute(db)

        try #sql("CREATE INDEX IF NOT EXISTS \"idx_movieItems_collectionID\" ON \"movieItems\"(\"collectionID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_movieItems_externalID\" ON \"movieItems\"(\"externalID\")").execute(db)

        try #sql(
            """
            CREATE TABLE "tVShowItems" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "collectionID" TEXT NOT NULL REFERENCES "collections"("id") ON DELETE CASCADE,
              "title" TEXT NOT NULL DEFAULT '',
              "overview" TEXT NOT NULL DEFAULT '',
              "firstAirDate" TEXT NOT NULL DEFAULT '',
              "lastAirDate" TEXT NOT NULL DEFAULT '',
              "numberOfSeasons" INTEGER NOT NULL DEFAULT 0,
              "numberOfEpisodes" INTEGER NOT NULL DEFAULT 0,
              "creators" TEXT NOT NULL DEFAULT '',
              "cast" TEXT NOT NULL DEFAULT '',
              "genres" TEXT NOT NULL DEFAULT '',
              "posterURL" TEXT NOT NULL DEFAULT '',
              "backdropURL" TEXT NOT NULL DEFAULT '',
              "coverImageData" BLOB,
              "externalID" TEXT NOT NULL DEFAULT '',
              "imdbID" TEXT NOT NULL DEFAULT '',
              "rating" INTEGER NOT NULL DEFAULT 0,
              "status" TEXT NOT NULL DEFAULT 'wantToWatch',
              "showStatus" TEXT NOT NULL DEFAULT '',
              "notes" TEXT NOT NULL DEFAULT '',
              "sortOrder" INTEGER NOT NULL DEFAULT 0,
              "createdDate" TEXT NOT NULL,
              "voteAverage" REAL NOT NULL DEFAULT 0,
              "originalLanguage" TEXT NOT NULL DEFAULT '',
              "network" TEXT NOT NULL DEFAULT ''
            ) STRICT
            """
        ).execute(db)

        try #sql("CREATE INDEX IF NOT EXISTS \"idx_tVShowItems_collectionID\" ON \"tVShowItems\"(\"collectionID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_tVShowItems_externalID\" ON \"tVShowItems\"(\"externalID\")").execute(db)
    }

    // MARK: - Add restaurant items table

    migrator.registerMigration("Add restaurant items") { db in
        try #sql(
            """
            CREATE TABLE "restaurantItems" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "collectionID" TEXT NOT NULL REFERENCES "collections"("id") ON DELETE CASCADE,
              "title" TEXT NOT NULL DEFAULT '',
              "cuisine" TEXT NOT NULL DEFAULT '',
              "phone" TEXT NOT NULL DEFAULT '',
              "address" TEXT NOT NULL DEFAULT '',
              "latitude" REAL NOT NULL DEFAULT 0,
              "longitude" REAL NOT NULL DEFAULT 0,
              "priceLevel" INTEGER NOT NULL DEFAULT 0,
              "websiteURL" TEXT NOT NULL DEFAULT '',
              "coverImageData" BLOB,
              "externalID" TEXT NOT NULL DEFAULT '',
              "rating" INTEGER NOT NULL DEFAULT 0,
              "status" TEXT NOT NULL DEFAULT 'wantToVisit',
              "visitedDate" TEXT NOT NULL,
              "hasVisitedDate" INTEGER NOT NULL DEFAULT 0,
              "notes" TEXT NOT NULL DEFAULT '',
              "sortOrder" INTEGER NOT NULL DEFAULT 0,
              "createdDate" TEXT NOT NULL
            ) STRICT
            """
        ).execute(db)

        try #sql("CREATE INDEX IF NOT EXISTS \"idx_restaurantItems_collectionID\" ON \"restaurantItems\"(\"collectionID\")").execute(db)
        try #sql("CREATE INDEX IF NOT EXISTS \"idx_restaurantItems_externalID\" ON \"restaurantItems\"(\"externalID\")").execute(db)
    }

    // MARK: - Enrich restaurant items with additional fields

    migrator.registerMigration("Enrich restaurant items") { db in
        // These columns omit NOT NULL so that CloudKit sync can insert NULL
        // for records that were created before these fields existed.
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"category\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"city\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"state\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"postalCode\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"country\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"timeZoneIdentifier\" TEXT DEFAULT ''").execute(db)
    }

    // MARK: - Add cover image type tracking

    migrator.registerMigration("Add cover image type") { db in
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"coverImageType\" TEXT DEFAULT ''").execute(db)
    }

    migrator.registerMigration("Add item attribution columns") { db in
        try #sql("ALTER TABLE \"bookItems\" ADD COLUMN \"addedByUserRecordName\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"bookItems\" ADD COLUMN \"lastEditedByUserRecordName\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"movieItems\" ADD COLUMN \"addedByUserRecordName\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"movieItems\" ADD COLUMN \"lastEditedByUserRecordName\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"tvShowItems\" ADD COLUMN \"addedByUserRecordName\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"tvShowItems\" ADD COLUMN \"lastEditedByUserRecordName\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"addedByUserRecordName\" TEXT DEFAULT ''").execute(db)
        try #sql("ALTER TABLE \"restaurantItems\" ADD COLUMN \"lastEditedByUserRecordName\" TEXT DEFAULT ''").execute(db)
    }

    return migrator
}
