//
//  DatabaseImportManager.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/2/25.
//

import Foundation
import SwiftData

@Observable
class DatabaseImportManager {
    var importProgress: Double = 0.0
    var importStatus: String = ""
    var isImporting: Bool = false
    var importError: String?
    var importSuccess: Bool = false
    
    // Store imported objects for relationship building
    private var importedTrips: [String: Trip] = [:]
    private var importedOrganizations: [String: Organization] = [:]
    private var importedAddresses: [String: Address] = [:]
    
    struct ImportResult {
        let tripsImported: Int
        let organizationsImported: Int
        let addressesImported: Int
        let attachmentsImported: Int
        let transportationImported: Int
        let lodgingImported: Int
        let activitiesImported: Int
        let organizationsMerged: Int
        let errors: [String]
    }
    
    func importDatabase(from url: URL, into modelContext: ModelContext) async -> ImportResult {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importStatus = "Reading import file..."
            importError = nil
            importSuccess = false
            
            // Clear previous import maps
            importedTrips.removeAll()
            importedOrganizations.removeAll()
            importedAddresses.removeAll()
        }
        
        var result = ImportResult(
            tripsImported: 0,
            organizationsImported: 0,
            addressesImported: 0,
            attachmentsImported: 0,
            transportationImported: 0,
            lodgingImported: 0,
            activitiesImported: 0,
            organizationsMerged: 0,
            errors: []
        )
        
        do {
            // Read the file
            let data = try Data(contentsOf: url)
            
            await MainActor.run {
                importProgress = 0.1
                importStatus = "Parsing import data..."
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                await MainActor.run {
                    importError = "Invalid JSON format"
                    isImporting = false
                }
                return result
            }
            
            // Validate export format
            guard let exportInfo = json["exportInfo"] as? [String: Any],
                  let version = exportInfo["version"] as? String else {
                await MainActor.run {
                    importError = "Invalid export file format"
                    isImporting = false
                }
                return result
            }
            
            await MainActor.run {
                importProgress = 0.2
                importStatus = "Validating export version \(version)..."
            }
            
            // Ensure we have a valid None organization before importing
            await MainActor.run {
                importStatus = "Setting up None organization..."
                importProgress = 0.22
            }
            
            _ = Organization.createNoneOrganization(in: modelContext)
            
            // Step 1: Import organizations first (needed for relationships)
            if let organizationsData = json["organizations"] as? [[String: Any]] {
                await MainActor.run {
                    importStatus = "Importing organizations..."
                    importProgress = 0.25
                }
                
                var orgCount = 0
                var mergedCount = 0
                
                for (index, orgData) in organizationsData.enumerated() {
                    let importResult = await importOrganization(orgData, into: modelContext)
                    if let _ = importResult.organization {
                        if importResult.wasMerged {
                            mergedCount += 1
                        } else {
                            orgCount += 1
                        }
                    }
                    
                    await MainActor.run {
                        importProgress = 0.25 + (Double(index) / Double(organizationsData.count)) * 0.1
                    }
                }
                
                result = ImportResult(
                    tripsImported: result.tripsImported,
                    organizationsImported: orgCount,
                    addressesImported: result.addressesImported,
                    attachmentsImported: result.attachmentsImported,
                    transportationImported: result.transportationImported,
                    lodgingImported: result.lodgingImported,
                    activitiesImported: result.activitiesImported,
                    organizationsMerged: mergedCount,
                    errors: result.errors
                )
            }
            
            // Step 2: Import trips (without activities initially)
            if let tripsData = json["trips"] as? [[String: Any]] {
                await MainActor.run {
                    importStatus = "Importing trips..."
                    importProgress = 0.35
                }
                
                for (index, tripData) in tripsData.enumerated() {
                    if (await importTrip(tripData, into: modelContext)) != nil {
                        result = ImportResult(
                            tripsImported: result.tripsImported + 1,
                            organizationsImported: result.organizationsImported,
                            addressesImported: result.addressesImported,
                            attachmentsImported: result.attachmentsImported,
                            transportationImported: result.transportationImported,
                            lodgingImported: result.lodgingImported,
                            activitiesImported: result.activitiesImported,
                            organizationsMerged: result.organizationsMerged,
                            errors: result.errors
                        )
                    }
                    
                    await MainActor.run {
                        importProgress = 0.35 + (Double(index) / Double(tripsData.count)) * 0.15
                    }
                }
            }
            
            // Step 3: Import transportation and link to trips
            if let tripsData = json["trips"] as? [[String: Any]] {
                await MainActor.run {
                    importStatus = "Importing transportation..."
                    importProgress = 0.5
                }
                
                var transportationCount = 0
                for tripData in tripsData {
                    if let transportationIds = tripData["transportation"] as? [String],
                       let tripId = tripData["id"] as? String,
                       let trip = importedTrips[tripId] {
                        
                        // Find and import transportation from the original export
                        if let allTransportation = getAllTransportationFromExport(json) {
                            for transportData in allTransportation {
                                if let transportId = transportData["id"] as? String,
                                   transportationIds.contains(transportId) {
                                    if (await importTransportation(transportData, for: trip, into: modelContext)) != nil {
                                        transportationCount += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                result = ImportResult(
                    tripsImported: result.tripsImported,
                    organizationsImported: result.organizationsImported,
                    addressesImported: result.addressesImported,
                    attachmentsImported: result.attachmentsImported,
                    transportationImported: transportationCount,
                    lodgingImported: result.lodgingImported,
                    activitiesImported: result.activitiesImported,
                    organizationsMerged: result.organizationsMerged,
                    errors: result.errors
                )
            }
            
            // Step 4: Import lodging and link to trips
            if let tripsData = json["trips"] as? [[String: Any]] {
                await MainActor.run {
                    importStatus = "Importing lodging..."
                    importProgress = 0.65
                }
                
                var lodgingCount = 0
                for tripData in tripsData {
                    if let lodgingIds = tripData["lodging"] as? [String],
                       let tripId = tripData["id"] as? String,
                       let trip = importedTrips[tripId] {
                        
                        // Find and import lodging from the original export
                        if let allLodging = getAllLodgingFromExport(json) {
                            for lodgingData in allLodging {
                                if let lodgingId = lodgingData["id"] as? String,
                                   lodgingIds.contains(lodgingId) {
                                    if (await importLodging(lodgingData, for: trip, into: modelContext)) != nil {
                                        lodgingCount += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                result = ImportResult(
                    tripsImported: result.tripsImported,
                    organizationsImported: result.organizationsImported,
                    addressesImported: result.addressesImported,
                    attachmentsImported: result.attachmentsImported,
                    transportationImported: result.transportationImported,
                    lodgingImported: lodgingCount,
                    activitiesImported: result.activitiesImported,
                    organizationsMerged: result.organizationsMerged,
                    errors: result.errors
                )
            }
            
            // Step 5: Import activities and link to trips
            if let tripsData = json["trips"] as? [[String: Any]] {
                await MainActor.run {
                    importStatus = "Importing activities..."
                    importProgress = 0.8
                }
                
                var activitiesCount = 0
                for tripData in tripsData {
                    if let activityIds = tripData["activities"] as? [String],
                       let tripId = tripData["id"] as? String,
                       let trip = importedTrips[tripId] {
                        
                        // Find and import activities from the original export
                        if let allActivities = getAllActivitiesFromExport(json) {
                            for activityData in allActivities {
                                if let activityId = activityData["id"] as? String,
                                   activityIds.contains(activityId) {
                                    if (await importActivity(activityData, for: trip, into: modelContext)) != nil {
                                        activitiesCount += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                result = ImportResult(
                    tripsImported: result.tripsImported,
                    organizationsImported: result.organizationsImported,
                    addressesImported: result.addressesImported,
                    attachmentsImported: result.attachmentsImported,
                    transportationImported: result.transportationImported,
                    lodgingImported: result.lodgingImported,
                    activitiesImported: activitiesCount,
                    organizationsMerged: result.organizationsMerged,
                    errors: result.errors
                )
            }
            
            // Step 6: Import attachments if included
            if let attachmentsData = json["attachments"] as? [[String: Any]] {
                await MainActor.run {
                    importStatus = "Importing file attachments..."
                    importProgress = 0.9
                }
                
                for (index, attachmentData) in attachmentsData.enumerated() {
                    if (await importAttachment(attachmentData, into: modelContext)) != nil {
                        result = ImportResult(
                            tripsImported: result.tripsImported,
                            organizationsImported: result.organizationsImported,
                            addressesImported: result.addressesImported,
                            attachmentsImported: result.attachmentsImported + 1,
                            transportationImported: result.transportationImported,
                            lodgingImported: result.lodgingImported,
                            activitiesImported: result.activitiesImported,
                            organizationsMerged: result.organizationsMerged,
                            errors: result.errors
                        )
                    }
                    
                    await MainActor.run {
                        importProgress = 0.9 + (Double(index) / Double(attachmentsData.count)) * 0.05
                    }
                }
            }
            
            // Step 7: Clean up duplicate None organizations
            await MainActor.run {
                importStatus = "Cleaning up organizations..."
                importProgress = 0.95
            }
            
            Organization.cleanupDuplicateNoneOrganizations(in: modelContext)
            
            // Save all changes
            await MainActor.run {
                importStatus = "Saving imported data..."
                importProgress = 0.98
            }
            
            try modelContext.save()
            
            await MainActor.run {
                importProgress = 1.0
                importStatus = "Import completed successfully!"
                importSuccess = true
                isImporting = false
            }
            
        } catch {
            await MainActor.run {
                importError = "Import failed: \(error.localizedDescription)"
                isImporting = false
            }
        }
        
        return result
    }
    
    // Helper methods to extract activities from export JSON
    private func getAllTransportationFromExport(_ json: [String: Any]) -> [[String: Any]]? {
        // For now, we'll extract from embedded trip data
        // In a future version, we could store transportation separately in the export
        var allTransportation: [[String: Any]] = []
        
        if let tripsData = json["trips"] as? [[String: Any]] {
            for tripData in tripsData {
                if let embeddedTransportation = tripData["embeddedTransportation"] as? [[String: Any]] {
                    allTransportation.append(contentsOf: embeddedTransportation)
                }
            }
        }
        
        return allTransportation.isEmpty ? nil : allTransportation
    }
    
    private func getAllLodgingFromExport(_ json: [String: Any]) -> [[String: Any]]? {
        var allLodging: [[String: Any]] = []
        
        if let tripsData = json["trips"] as? [[String: Any]] {
            for tripData in tripsData {
                if let embeddedLodging = tripData["embeddedLodging"] as? [[String: Any]] {
                    allLodging.append(contentsOf: embeddedLodging)
                }
            }
        }
        
        return allLodging.isEmpty ? nil : allLodging
    }
    
    private func getAllActivitiesFromExport(_ json: [String: Any]) -> [[String: Any]]? {
        var allActivities: [[String: Any]] = []
        
        if let tripsData = json["trips"] as? [[String: Any]] {
            for tripData in tripsData {
                if let embeddedActivities = tripData["embeddedActivities"] as? [[String: Any]] {
                    allActivities.append(contentsOf: embeddedActivities)
                }
            }
        }
        
        return allActivities.isEmpty ? nil : allActivities
    }
    
    private func importOrganization(_ data: [String: Any], into modelContext: ModelContext) async -> (organization: Organization?, wasMerged: Bool) {
        guard let name = data["name"] as? String,
              let orgId = data["id"] as? String else {
            return (nil, false)
        }
        
        // Check if organization already exists by name
        let descriptor = FetchDescriptor<Organization>(
            predicate: #Predicate<Organization> { $0.name == name }
        )
        
        do {
            let existingOrgs = try modelContext.fetch(descriptor)
            
            if let existingOrg = existingOrgs.first {
                // Merge data into existing organization
                existingOrg.phone = data["phone"] as? String ?? existingOrg.phone
                existingOrg.email = data["email"] as? String ?? existingOrg.email
                existingOrg.website = data["website"] as? String ?? existingOrg.website
                existingOrg.logoURL = data["logoURL"] as? String ?? existingOrg.logoURL
                existingOrg.cachedLogoFilename = data["cachedLogoFilename"] as? String ?? existingOrg.cachedLogoFilename
                
                // Import address if present and merge
                if let addressData = data["address"] as? [String: Any], !addressData.isEmpty {
                    if existingOrg.address == nil {
                        existingOrg.address = importAddress(addressData)
                    }
                }
                
                // Store for relationship building
                importedOrganizations[orgId] = existingOrg
                
                return (existingOrg, true)
            }
        } catch {
            print("❌ Error checking for existing organization: \(error)")
        }
        
        // Create new organization
        let org = Organization(
            name: name,
            phone: data["phone"] as? String ?? "",
            email: data["email"] as? String ?? "",
            website: data["website"] as? String ?? "",
            logoURL: data["logoURL"] as? String ?? "",
            cachedLogoFilename: data["cachedLogoFilename"] as? String ?? ""
        )
        
        // Import address if present
        if let addressData = data["address"] as? [String: Any] {
            org.address = importAddress(addressData)
        }
        
        modelContext.insert(org)
        
        // Store for relationship building
        importedOrganizations[orgId] = org
        
        return (org, false)
    }
    
    private func importAddress(_ data: [String: Any]) -> Address {
        let address = Address(
            street: data["street"] as? String ?? "",
            city: data["city"] as? String ?? "",
            state: data["state"] as? String ?? "",
            country: data["country"] as? String ?? "",
            postalCode: data["postalCode"] as? String ?? "",
            latitude: data["latitude"] as? Double ?? 0.0,
            longitude: data["longitude"] as? Double ?? 0.0,
            formattedAddress: data["formattedAddress"] as? String ?? ""
        )
        
        if let addressId = data["id"] as? String {
            importedAddresses[addressId] = address
        }
        
        return address
    }
    
    private func importTrip(_ data: [String: Any], into modelContext: ModelContext) async -> Trip? {
        guard let name = data["name"] as? String,
              let tripId = data["id"] as? String else { return nil }
        
        let trip = Trip(
            name: name,
            notes: data["notes"] as? String ?? ""
        )
        
        // Set dates if present
        if let hasStartDate = data["hasStartDate"] as? Bool, hasStartDate,
           let startDateString = data["startDate"] as? String,
           let startDate = ISO8601DateFormatter().date(from: startDateString) {
            trip.setStartDate(startDate)
        }
        
        if let hasEndDate = data["hasEndDate"] as? Bool, hasEndDate,
           let endDateString = data["endDate"] as? String,
           let endDate = ISO8601DateFormatter().date(from: endDateString) {
            trip.setEndDate(endDate)
        }
        
        modelContext.insert(trip)
        
        // Store for relationship building
        importedTrips[tripId] = trip
        
        return trip
    }
    
    private func importTransportation(_ data: [String: Any], for trip: Trip, into modelContext: ModelContext) async -> Transportation? {
        guard let name = data["name"] as? String else { return nil }
        
        let typeString = data["type"] as? String ?? "plane"
        let type = TransportationType(rawValue: typeString) ?? .plane
        
        let transportation = Transportation(
            name: name,
            type: type,
            start: parseDate(data["start"] as? String) ?? Date(),
            end: parseDate(data["end"] as? String) ?? Date(),
            cost: Decimal(data["cost"] as? Double ?? 0.0),
            paid: PaidStatus(rawValue: data["paid"] as? String ?? "none") ?? .none,
            confirmation: data["confirmation"] as? String ?? "",
            notes: data["notes"] as? String ?? "",
            trip: trip
        )
        
        // Link to organization if available
        if let orgId = data["organizationId"] as? String,
           let organization = importedOrganizations[orgId] {
            transportation.organization = organization
        }
        
        // Set timezones
        transportation.startTZId = data["startTZId"] as? String ?? TimeZone.current.identifier
        transportation.endTZId = data["endTZId"] as? String ?? TimeZone.current.identifier
        
        modelContext.insert(transportation)
        return transportation
    }
    
    private func importLodging(_ data: [String: Any], for trip: Trip, into modelContext: ModelContext) async -> Lodging? {
        guard let name = data["name"] as? String else { return nil }
        
        let lodging = Lodging(
            name: name,
            start: parseDate(data["start"] as? String) ?? Date(),
            end: parseDate(data["end"] as? String) ?? Date(),
            cost: Decimal(data["cost"] as? Double ?? 0.0),
            paid: PaidStatus(rawValue: data["paid"] as? String ?? "none") ?? .none,
            reservation: data["reservation"] as? String ?? "",
            notes: data["notes"] as? String ?? "",
            trip: trip
        )
        
        // Link to organization if available
        if let orgId = data["organizationId"] as? String,
           let organization = importedOrganizations[orgId] {
            lodging.organization = organization
        }
        
        // Set timezones
        lodging.checkInTZId = data["startTZId"] as? String ?? TimeZone.current.identifier
        lodging.checkOutTZId = data["endTZId"] as? String ?? TimeZone.current.identifier
        
        modelContext.insert(lodging)
        return lodging
    }
    
    private func importActivity(_ data: [String: Any], for trip: Trip, into modelContext: ModelContext) async -> Activity? {
        guard let name = data["name"] as? String else { return nil }
        
        let activity = Activity(
            name: name,
            start: parseDate(data["start"] as? String) ?? Date(),
            end: parseDate(data["end"] as? String) ?? Date(),
            cost: Decimal(data["cost"] as? Double ?? 0.0),
            paid: PaidStatus(rawValue: data["paid"] as? String ?? "none") ?? .none,
            reservation: data["reservation"] as? String ?? "",
            notes: data["notes"] as? String ?? "",
            trip: trip
        )
        
        // Link to organization if available
        if let orgId = data["organizationId"] as? String,
           let organization = importedOrganizations[orgId] {
            activity.organization = organization
        }
        
        // Set timezones
        activity.startTZId = data["startTZId"] as? String ?? TimeZone.current.identifier
        activity.endTZId = data["endTZId"] as? String ?? TimeZone.current.identifier
        
        modelContext.insert(activity)
        return activity
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }
    
    private func importAttachment(_ data: [String: Any], into modelContext: ModelContext) async -> EmbeddedFileAttachment? {
        guard let fileName = data["fileName"] as? String,
              let originalFileName = data["originalFileName"] as? String else { return nil }
        
        let attachment = EmbeddedFileAttachment(
            fileName: fileName,
            originalFileName: originalFileName,
            fileSize: data["fileSize"] as? Int64 ?? 0,
            mimeType: data["mimeType"] as? String ?? "",
            fileExtension: data["fileExtension"] as? String ?? "",
            fileDescription: data["fileDescription"] as? String ?? ""
        )
        
        // Import file data if present
        if let fileDataString = data["fileData"] as? String,
           let fileData = Data(base64Encoded: fileDataString) {
            attachment.fileData = fileData
        }
        
        // Set creation date
        if let createdDateString = data["createdDate"] as? String,
           let createdDate = ISO8601DateFormatter().date(from: createdDateString) {
            attachment.createdDate = createdDate
        }
        
        modelContext.insert(attachment)
        return attachment
    }
}
