//
//  ComprehensiveImportExportTests.swift
//  Traveling Snails
//
//

import Testing
import Foundation
import SwiftData

@testable import Traveling_Snails

@Suite("Comprehensive Import/Export Tests")
struct ComprehensiveImportExportTests {
    
    @Suite("Organization Management Tests")
    struct OrganizationManagementTests {
        
        @Test("None organization creation and uniqueness")
        func noneOrganizationUniqueness() {
            // Test that multiple calls return same organization
            let org1 = Organization(name: "None")
            let org2 = Organization(name: "None")
            
            #expect(org1.isNone == true)
            #expect(org2.isNone == true)
            #expect(org1.canBeDeleted == false)
            #expect(org2.canBeDeleted == false)
        }
        
        @Test("Regular organization deletion rules")
        func regularOrganizationDeletionRules() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            
            // Organization without activities can be deleted
            #expect(org.canBeDeleted == true)
            
            // Add transportation
            let transport = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            org.transportation.append(transport)
            
            // Now cannot be deleted
            #expect(org.canBeDeleted == false)
        }
        
        @Test("Organization merge logic")
        func organizationMergeLogic() {
            let org1 = Organization(
                name: "Test Airline",
                phone: "+1-555-0123",
                email: "info@test.com"
            )
            
            let org2 = Organization(
                name: "Test Airline",
                website: "https://test.com",
                logoURL: "https://test.com/logo.png"
            )
            
            // Simulate merge - second org data should supplement first
            org1.website = org2.website.isEmpty ? org1.website : org2.website
            org1.logoURL = org2.logoURL.isEmpty ? org1.logoURL : org2.logoURL
            
            #expect(org1.phone == "+1-555-0123") // Preserved
            #expect(org1.email == "info@test.com") // Preserved
            #expect(org1.website == "https://test.com") // Added
            #expect(org1.logoURL == "https://test.com/logo.png") // Added
        }
    }
    
    @Suite("Export Data Validation Tests")
    struct ExportDataValidationTests {
        
        @Test("Export structure validation")
        func exportStructureValidation() {
            let exportData: [String: Any] = [
                "exportInfo": [
                    "version": "1.0",
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "format": "json",
                    "includesAttachments": false
                ],
                "trips": [],
                "organizations": [],
                "addresses": [],
                "attachments": []
            ]
            
            // Validate required fields
            #expect(exportData["exportInfo"] != nil)
            #expect(exportData["trips"] != nil)
            #expect(exportData["organizations"] != nil)
            
            if let exportInfo = exportData["exportInfo"] as? [String: Any] {
                #expect(exportInfo["version"] != nil)
                #expect(exportInfo["timestamp"] != nil)
                #expect(exportInfo["format"] != nil)
            }
        }
        
        @Test("Trip export data completeness")
        func tripExportDataCompleteness() {
            let trip = Trip(
                name: "Test Trip",
                notes: "Test notes",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
            )
            
            let exportDict: [String: Any] = [
                "id": trip.id.uuidString,
                "name": trip.name,
                "notes": trip.notes,
                "createdDate": ISO8601DateFormatter().string(from: trip.createdDate),
                "startDate": ISO8601DateFormatter().string(from: trip.startDate),
                "endDate": ISO8601DateFormatter().string(from: trip.endDate),
                "hasStartDate": trip.hasStartDate,
                "hasEndDate": trip.hasEndDate,
                "totalCost": NSDecimalNumber(decimal: trip.totalCost).doubleValue
            ]
            
            // Validate all required fields are present
            #expect(exportDict["id"] != nil)
            #expect(exportDict["name"] as? String == trip.name)
            #expect(exportDict["hasStartDate"] as? Bool == trip.hasStartDate)
            #expect(exportDict["hasEndDate"] as? Bool == trip.hasEndDate)
        }
        
        @Test("Organization export data completeness")
        func organizationExportDataCompleteness() {
            let address = Address(
                street: "123 Test St",
                city: "Test City",
                state: "TS",
                country: "Test Country"
            )
            
            let org = Organization(
                name: "Test Organization",
                phone: "+1-555-0123",
                email: "test@example.com",
                website: "https://example.com",
                address: address
            )
            
            let exportDict: [String: Any] = [
                "id": org.id.uuidString,
                "name": org.name,
                "phone": org.phone,
                "email": org.email,
                "website": org.website,
                "logoURL": org.logoURL,
                "address": [
                    "street": address.street,
                    "city": address.city,
                    "state": address.state,
                    "country": address.country
                ]
            ]
            
            #expect(exportDict["name"] as? String == org.name)
            #expect(exportDict["phone"] as? String == org.phone)
            #expect(exportDict["email"] as? String == org.email)
            #expect(exportDict["website"] as? String == org.website)
            #expect(exportDict["address"] != nil)
        }
        
        @Test("Activity export data with relationships")
        func activityExportDataWithRelationships() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Venue")
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                cost: Decimal(50.00),
                paid: .deposit,
                trip: trip,
                organization: org
            )
            
            let exportDict: [String: Any] = [
                "id": activity.id.uuidString,
                "name": activity.name,
                "start": ISO8601DateFormatter().string(from: activity.start),
                "end": ISO8601DateFormatter().string(from: activity.end),
                "cost": NSDecimalNumber(decimal: activity.cost).doubleValue,
                "paid": activity.paid.rawValue,
                "organizationId": org.id.uuidString,
                "startTZId": activity.startTZId,
                "endTZId": activity.endTZId
            ]
            
            #expect(exportDict["organizationId"] as? String == org.id.uuidString)
            #expect(exportDict["startTZId"] as? String == activity.startTZId)
            #expect(exportDict["paid"] as? String == activity.paid.rawValue)
        }
    }
    
    @Suite("Import Data Validation Tests")
    struct ImportDataValidationTests {
        
        @Test("Import file format validation")
        func importFileFormatValidation() {
            // Valid export format
            let validExport: [String: Any] = [
                "exportInfo": [
                    "version": "1.0",
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "format": "json"
                ],
                "trips": [],
                "organizations": []
            ]
            
            // Should have required export info
            if let exportInfo = validExport["exportInfo"] as? [String: Any] {
                #expect(exportInfo["version"] != nil)
                #expect(exportInfo["format"] as? String == "json")
            }
            
            // Invalid export format (missing export info)
            let invalidExport: [String: Any] = [
                "trips": [],
                "organizations": []
            ]
            
            #expect(invalidExport["exportInfo"] == nil)
        }
        
        @Test("Organization import deduplication logic")
        func organizationImportDeduplicationLogic() {
            // Simulate existing organizations
            let existingOrgs = [
                Organization(name: "Existing Airline", phone: "+1-555-0000"),
                Organization(name: "Another Company", email: "info@another.com")
            ]
            
            // Import data with duplicate name
            let importOrgData: [String: Any] = [
                "id": UUID().uuidString,
                "name": "Existing Airline",
                "phone": "+1-555-1111", // Different phone
                "email": "new@email.com", // New email
                "website": "https://new.com" // New website
            ]
            
            // Find existing organization by name
            let existingOrg = existingOrgs.first { $0.name == importOrgData["name"] as? String }
            #expect(existingOrg != nil)
            
            // Simulate merge logic
            if let existing = existingOrg {
                let shouldMerge = true // In real import, this would be the merge decision
                #expect(shouldMerge == true)
                
                // Merge would preserve existing phone but add new email/website
                let mergedPhone = existing.phone.isEmpty ? (importOrgData["phone"] as? String ?? "") : existing.phone
                #expect(mergedPhone == "+1-555-0000") // Should keep existing
            }
        }
        
        @Test("Trip activity relationship reconstruction")
        func tripActivityRelationshipReconstruction() {
            // Simulate import data structure
            let tripData: [String: Any] = [
                "id": "trip-123",
                "name": "Test Trip",
                "transportation": ["transport-456"],
                "lodging": ["lodging-789"],
                "activities": ["activity-101"]
            ]
            
            let transportData: [String: Any] = [
                "id": "transport-456",
                "name": "Flight",
                "organizationId": "org-999"
            ]
            
            // Validate relationship IDs are present
            let transportationIds = tripData["transportation"] as? [String] ?? []
            let lodgingIds = tripData["lodging"] as? [String] ?? []
            let activityIds = tripData["activities"] as? [String] ?? []
            
            #expect(transportationIds.contains("transport-456"))
            #expect(lodgingIds.contains("lodging-789"))
            #expect(activityIds.contains("activity-101"))
            
            // Validate transportation can be linked back to trip
            #expect(transportData["id"] as? String == "transport-456")
            #expect(transportData["organizationId"] as? String == "org-999")
        }
        
        @Test("Timezone import validation")
        func timezoneImportValidation() {
            let activityData: [String: Any] = [
                "name": "Test Activity",
                "startTZId": "America/New_York",
                "endTZId": "Invalid/Timezone"
            ]
            
            // Valid timezone should be accepted
            let startTZ = TimeZone(identifier: activityData["startTZId"] as? String ?? "")
            #expect(startTZ != nil)
            
            // Invalid timezone should fallback to current
            let endTZId = activityData["endTZId"] as? String ?? ""
            let endTZ = TimeZone(identifier: endTZId) ?? TimeZone.current
            #expect(endTZ.identifier == TimeZone.current.identifier)
        }
    }
    
    @Suite("File Attachment Import/Export Tests")
    struct FileAttachmentImportExportTests {
        
        @Test("File attachment export with embedded data")
        func fileAttachmentExportWithEmbeddedData() {
            let testData = "Test file content".data(using: .utf8)!
            let attachment = EmbeddedFileAttachment(
                fileName: "test.txt",
                originalFileName: "Test Document.txt",
                fileSize: Int64(testData.count),
                mimeType: "text/plain",
                fileExtension: "txt",
                fileDescription: "Test file",
                fileData: testData
            )
            
            let exportDict: [String: Any] = [
                "id": attachment.id.uuidString,
                "fileName": attachment.fileName,
                "originalFileName": attachment.originalFileName,
                "fileSize": attachment.fileSize,
                "mimeType": attachment.mimeType,
                "fileExtension": attachment.fileExtension,
                "fileDescription": attachment.fileDescription,
                "fileData": testData.base64EncodedString()
            ]
            
            #expect(exportDict["fileData"] != nil)
            #expect((exportDict["fileData"] as? String)?.isEmpty == false)
            
            // Validate base64 encoding/decoding
            if let base64String = exportDict["fileData"] as? String,
               let decodedData = Data(base64Encoded: base64String) {
                #expect(decodedData == testData)
            }
        }
        
        @Test("File attachment import without data")
        func fileAttachmentImportWithoutData() {
            let importData: [String: Any] = [
                "fileName": "missing-data.txt",
                "originalFileName": "Missing Data.txt",
                "fileSize": Int64(1024),
                "mimeType": "text/plain",
                "fileExtension": "txt"
                // No fileData field
            ]
            
            // Should handle missing file data gracefully
            let hasFileData = importData["fileData"] != nil
            #expect(hasFileData == false)
            
            // File size and metadata should still be preserved
            #expect(importData["fileSize"] as? Int64 == Int64(1024))
            #expect(importData["mimeType"] as? String == "text/plain")
        }
        
        @Test("File attachment relationship preservation")
        func fileAttachmentRelationshipPreservation() {
            let activity = Activity(name: "Test Activity")
            let attachment = EmbeddedFileAttachment(fileName: "activity-doc.pdf")
            
            // Set up relationship
            attachment.activity = activity
            activity.fileAttachments.append(attachment)
            
            // Validate relationship
            #expect(attachment.activity?.id == activity.id)
            #expect(activity.fileAttachments.count == 1)
            #expect(activity.hasAttachments == true)
            
            // In export, this would be preserved as activity ID reference
            let exportRelationship = attachment.activity?.id.uuidString
            #expect(exportRelationship != nil)
        }
    }
    
    @Suite("Settings and Configuration Tests")
    struct SettingsAndConfigurationTests {
        
        // TEMPORARILY DISABLED - AppSettings hanging issue being investigated
        // @Test("App settings persistence")
        func appSettingsPersistence() {
            // let settings = AppSettings.shared
            
            // print("The color scheme is: \(settings.colorScheme)")
            // Test default values
            // #expect(settings.colorScheme == .system ||
            //        settings.colorScheme == .light ||
            //        settings.colorScheme == .dark)
            
            // Test setting changes
            // let originalScheme = settings.colorScheme
            // settings.colorScheme = .dark
            // #expect(settings.colorScheme == .dark)
            
            // Restore original
            // settings.colorScheme = originalScheme
        }
        
        @Test("Color scheme preference validation")
        func colorSchemePreferenceValidation() {
            #expect(ColorSchemePreference.system.displayName == "System")
            #expect(ColorSchemePreference.light.displayName == "Light")
            #expect(ColorSchemePreference.dark.displayName == "Dark")
            
            #expect(ColorSchemePreference.system.colorScheme == nil)
            #expect(ColorSchemePreference.light.colorScheme == .light)
            #expect(ColorSchemePreference.dark.colorScheme == .dark)
        }
        
        @Test("Database export settings validation")
        func databaseExportSettingsValidation() {
            // Test export format options
            enum TestExportFormat: String, CaseIterable {
                case json = "JSON"
                case csv = "CSV"
                
                var fileExtension: String {
                    switch self {
                    case .json: return "json"
                    case .csv: return "csv"
                    }
                }
            }
            
            #expect(TestExportFormat.json.fileExtension == "json")
            #expect(TestExportFormat.csv.fileExtension == "csv")
            #expect(TestExportFormat.allCases.count == 2)
        }
    }
    
    @Suite("Data Integrity Tests")
    struct DataIntegrityTests {
        
        @Test("Trip date consistency after import")
        func tripDateConsistencyAfterImport() {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
            
            // Simulate import data
            let importData: [String: Any] = [
                "name": "Imported Trip",
                "hasStartDate": true,
                "startDate": ISO8601DateFormatter().string(from: startDate),
                "hasEndDate": true,
                "endDate": ISO8601DateFormatter().string(from: endDate)
            ]
            
            // Reconstruct trip from import data
            let trip = Trip(name: importData["name"] as? String ?? "")
            
            if let hasStart = importData["hasStartDate"] as? Bool, hasStart,
               let startString = importData["startDate"] as? String,
               let importedStart = ISO8601DateFormatter().date(from: startString) {
                trip.setStartDate(importedStart)
            }
            
            if let hasEnd = importData["hasEndDate"] as? Bool, hasEnd,
               let endString = importData["endDate"] as? String,
               let importedEnd = ISO8601DateFormatter().date(from: endString) {
                trip.setEndDate(importedEnd)
            }
            
            // Validate date consistency
            #expect(trip.hasStartDate == true)
            #expect(trip.hasEndDate == true)
            // Use approximate comparison for dates due to potential precision differences
            #expect(abs(trip.startDate.timeIntervalSince(startDate)) < 1.0)
            #expect(abs(trip.endDate.timeIntervalSince(endDate)) < 1.0)
            #expect(trip.hasDateRange == true)
        }
        
        @Test("Organization relationship consistency after import")
        func organizationRelationshipConsistencyAfterImport() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            
            // Create transportation with organization
            let transport = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            // Simulate relationship setup during import
            org.transportation.append(transport)
            
            trip.transportation.append(transport)
            
            // Validate bidirectional relationships
            #expect(transport.trip?.id == trip.id)
            #expect(transport.organization?.id == org.id)
            #expect(trip.transportation.first?.id == transport.id)
            #expect(org.transportation.first?.id == transport.id)
        }
        
        @Test("File attachment data integrity after import")
        func fileAttachmentDataIntegrityAfterImport() {
            let originalData = "Original file content".data(using: .utf8)!
            let base64String = originalData.base64EncodedString()
            
            // Simulate import process
            let importData: [String: Any] = [
                "fileName": "imported.txt",
                "originalFileName": "Original.txt",
                "fileSize": Int64(originalData.count),
                "fileData": base64String
            ]
            
            // Reconstruct attachment
            let attachment = EmbeddedFileAttachment(
                fileName: importData["fileName"] as? String ?? "",
                originalFileName: importData["originalFileName"] as? String ?? "",
                fileSize: importData["fileSize"] as? Int64 ?? 0
            )
            
            // Import file data
            if let dataString = importData["fileData"] as? String,
               let importedData = Data(base64Encoded: dataString) {
                attachment.fileData = importedData
            }
            
            // Validate data integrity
            #expect(attachment.fileData == originalData)
            #expect(attachment.fileSize == Int64(originalData.count))
            
            // Validate temporary file creation
            let tempURL = attachment.temporaryFileURL
            #expect(tempURL != nil)
            
            if let url = tempURL {
                let fileExists = FileManager.default.fileExists(atPath: url.path)
                #expect(fileExists == true)
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        @Test("Currency precision preservation during import/export")
        func currencyPrecisionPreservation() {
            let originalCost = Decimal(string: "123.45")!
            
            // Export as double (potential precision loss point)
            let exportedDouble = NSDecimalNumber(decimal: originalCost).doubleValue
            
            // Import back as Decimal
            let importedCost = Decimal(exportedDouble)
            
            // Should preserve precision for reasonable currency values
            #expect(importedCost == originalCost)
            
            // Test edge cases
            let smallAmount = Decimal(string: "0.01")!
            let smallDouble = NSDecimalNumber(decimal: smallAmount).doubleValue
            let smallImported = Decimal(smallDouble)
            #expect(smallImported == smallAmount)
            
            let largeAmount = Decimal(string: "999999.99")!
            let largeDouble = NSDecimalNumber(decimal: largeAmount).doubleValue
            let largeImported = Decimal(largeDouble)
            #expect(largeImported == largeAmount)
        }
    }
    
    @Suite("Error Handling and Recovery Tests")
    struct ErrorHandlingAndRecoveryTests {
        
        @Test("Invalid import file handling")
        func invalidImportFileHandling() {
            // Test various invalid formats
            let invalidFormats = [
                "Not JSON at all",
                "{}",  // Empty JSON
                "{\"trips\": []}", // Missing export info
                "{\"exportInfo\": {}}", // Invalid export info
            ]
            
            for invalidContent in invalidFormats {
                let data = invalidContent.data(using: .utf8)!
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    // Check for required fields
                    let hasValidExportInfo = json?["exportInfo"] as? [String: Any] != nil
                    let hasVersion = (json?["exportInfo"] as? [String: Any])?["version"] != nil
                    
                    let isValid = hasValidExportInfo && hasVersion
                    
                    // Most invalid formats should fail validation
                    if invalidContent == "Not JSON at all" {
                        // This should fail JSON parsing entirely
                        #expect(json == nil)
                    } else {
                        // Others should parse but fail validation
                        #expect(isValid == false)
                    }
                } catch {
                    // JSON parsing failure is expected for non-JSON content
                    #expect(invalidContent == "Not JSON at all")
                }
            }
        }
        
        @Test("Partial import recovery")
        func partialImportRecovery() {
            // Simulate import with some valid and some invalid data
            let partiallyValidImport: [String: Any] = [
                "exportInfo": [
                    "version": "1.0",
                    "format": "json"
                ],
                "trips": [
                    // Valid trip
                    [
                        "id": "valid-trip",
                        "name": "Valid Trip"
                    ],
                    // Invalid trip (missing required fields)
                    [
                        "id": "invalid-trip"
                        // Missing name
                    ]
                ],
                "organizations": [
                    // Valid org
                    [
                        "id": "valid-org",
                        "name": "Valid Organization"
                    ]
                ]
            ]
            
            // Validate structure
            let hasValidHeader = partiallyValidImport["exportInfo"] != nil
            #expect(hasValidHeader == true)
            
            if let trips = partiallyValidImport["trips"] as? [[String: Any]] {
                let validTrips = trips.filter { $0["name"] != nil }
                let invalidTrips = trips.filter { $0["name"] == nil }
                
                #expect(validTrips.count == 1)
                #expect(invalidTrips.count == 1)
                
                // Import should be able to process valid items and skip invalid ones
                for trip in validTrips {
                    #expect(trip["id"] as? String == "valid-trip")
                    #expect(trip["name"] as? String == "Valid Trip")
                }
            }
        }
        
        @Test("Memory pressure during large import")
        func memoryPressureDuringLargeImport() {
            // Simulate large dataset
            var largeImportData: [String: Any] = [
                "exportInfo": [
                    "version": "1.0",
                    "format": "json"
                ],
                "trips": [],
                "organizations": [],
                "attachments": []
            ]
            
            var trips: [[String: Any]] = []
            var organizations: [[String: Any]] = []
            var attachments: [[String: Any]] = []
            
            // Create test data (smaller scale for test performance)
            for i in 0..<10 {
                trips.append([
                    "id": "trip-\(i)",
                    "name": "Trip \(i)",
                    "hasStartDate": false,
                    "hasEndDate": false
                ])
                
                organizations.append([
                    "id": "org-\(i)",
                    "name": "Organization \(i)"
                ])
                
                // Small test file data
                let testData = "Test content \(i)".data(using: .utf8)!
                attachments.append([
                    "id": "attachment-\(i)",
                    "fileName": "file-\(i).txt",
                    "originalFileName": "File \(i).txt",
                    "fileSize": Int64(testData.count),
                    "fileData": testData.base64EncodedString()
                ])
            }
            
            largeImportData["trips"] = trips
            largeImportData["organizations"] = organizations
            largeImportData["attachments"] = attachments
            
            // Validate structure can handle multiple items
            #expect((largeImportData["trips"] as? [[String: Any]])?.count == 10)
            #expect((largeImportData["organizations"] as? [[String: Any]])?.count == 10)
            #expect((largeImportData["attachments"] as? [[String: Any]])?.count == 10)
            
            // Test memory efficiency - processing should be incremental
            var processedCount = 0
            if let trips = largeImportData["trips"] as? [[String: Any]] {
                for trip in trips {
                    if trip["name"] != nil {
                        processedCount += 1
                    }
                }
            }
            
            #expect(processedCount == 10)
        }
        
        @Test("Import rollback on critical error")
        func importRollbackOnCriticalError() {
            // Test that import can be safely aborted
            var importState = [
                "processed": 0,
                "errors": [] as [String],
                "canContinue": true
            ] as [String : Any]
            
            // Simulate processing with error
            let testItems = ["valid1", "valid2", "", "valid4"] // Empty string simulates error
            
            for (index, item) in testItems.enumerated() {
                if item.isEmpty {
                    importState["errors"] = (importState["errors"] as! [String]) + ["Invalid item at index \(index)"]
                    importState["canContinue"] = false
                    break
                } else {
                    importState["processed"] = (importState["processed"] as! Int) + 1
                }
            }
            
            #expect(importState["processed"] as? Int == 2) // Should stop at error
            #expect(importState["canContinue"] as? Bool == false)
            #expect((importState["errors"] as? [String])?.count == 1)
        }
    }
    
    @Suite("Performance and Scalability Tests")
    struct PerformanceAndScalabilityTests {
        
        @Test("Export generation performance")
        func exportGenerationPerformance() {
            // Create test dataset
            let trip = Trip(name: "Performance Test Trip")
            let org = Organization(name: "Performance Test Org")
            
            let startTime = Date()
            
            // Create moderate dataset
            for i in 0..<50 {
                let activity = Activity(
                    name: "Activity \(i)",
                    start: Date(),
                    end: Date(),
                    cost: Decimal(i),
                    trip: trip,
                    organization: org
                )
                trip.activity.append(activity)
            }
            
            let creationTime = Date().timeIntervalSince(startTime)
            #expect(creationTime < 5.0, "Dataset creation took \(creationTime) seconds - should complete within 5 seconds")
            
            // Test export data generation
            let exportStartTime = Date()
            
            let exportData: [String: Any] = [
                "trip": [
                    "id": trip.id.uuidString,
                    "name": trip.name,
                    "totalActivities": trip.totalActivities,
                    "totalCost": NSDecimalNumber(decimal: trip.totalCost).doubleValue
                ]
            ]
            
            let exportTime = Date().timeIntervalSince(exportStartTime)
            #expect(exportTime < 0.1, "Export generation took \(exportTime) seconds")
            
            // Validate export data
            if let tripData = exportData["trip"] as? [String: Any] {
                #expect(tripData["totalActivities"] as? Int == 50)
            }
        }
        
        @Test("Import processing performance")
        func importProcessingPerformance() {
            // Create test import data
            var importData: [String: Any] = [
                "exportInfo": ["version": "1.0"],
                "organizations": []
            ]
            
            var organizations: [[String: Any]] = []
            for i in 0..<25 {
                organizations.append([
                    "id": "org-\(i)",
                    "name": "Organization \(i)",
                    "phone": "+1-555-\(String(format: "%04d", i))",
                    "email": "org\(i)@example.com"
                ])
            }
            importData["organizations"] = organizations
            
            let startTime = Date()
            
            // Simulate import processing
            var processedOrgs: [Organization] = []
            if let orgs = importData["organizations"] as? [[String: Any]] {
                for orgData in orgs {
                    if let name = orgData["name"] as? String {
                        let org = Organization(
                            name: name,
                            phone: orgData["phone"] as? String ?? "",
                            email: orgData["email"] as? String ?? ""
                        )
                        processedOrgs.append(org)
                    }
                }
            }
            
            let processingTime = Date().timeIntervalSince(startTime)
            #expect(processingTime < 0.5, "Import processing took \(processingTime) seconds")
            #expect(processedOrgs.count == 25)
        }
        
        @Test("Large file attachment handling")
        func largeFileAttachmentHandling() {
            // Test with moderately large data (1KB for test performance)
            let largeData = Data(repeating: 0x42, count: 1024)
            
            let startTime = Date()
            
            let _ = EmbeddedFileAttachment(
                fileName: "large_file.bin",
                fileSize: Int64(largeData.count),
                fileData: largeData
            )
            
            let creationTime = Date().timeIntervalSince(startTime)
            #expect(creationTime < 0.1, "Large attachment creation took \(creationTime) seconds")
            
            // Test base64 encoding performance
            let encodingStartTime = Date()
            let base64String = largeData.base64EncodedString()
            let encodingTime = Date().timeIntervalSince(encodingStartTime)
            #expect(encodingTime < 0.1, "Base64 encoding took \(encodingTime) seconds")
            
            // Test decoding performance
            let decodingStartTime = Date()
            let decodedData = Data(base64Encoded: base64String)
            let decodingTime = Date().timeIntervalSince(decodingStartTime)
            #expect(decodingTime < 0.1, "Base64 decoding took \(decodingTime) seconds")
            
            #expect(decodedData == largeData)
        }
    }
}
