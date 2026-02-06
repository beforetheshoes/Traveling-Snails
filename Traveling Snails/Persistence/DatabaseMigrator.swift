//
//  DatabaseMigrator.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

func makeMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()

    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

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

    return migrator
}
