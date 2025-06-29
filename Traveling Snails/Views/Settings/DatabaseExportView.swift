//
//  DatabaseExportView.swift
//  Traveling Snails
//
//

import SwiftUI
import SwiftData

struct DatabaseExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allTrips: [Trip]
    @Query private var allTransportation: [Transportation]
    @Query private var allLodging: [Lodging]
    @Query private var allActivities: [Activity]
    @Query private var allOrganizations: [Organization]
    @Query private var allAddresses: [Address]
    @Query private var allAttachments: [EmbeddedFileAttachment]
    
    @State private var exportData = ""
    @State private var isGenerating = false
    @State private var showingShareSheet = false
    @State private var exportFormat: ExportFormat = .json
    @State private var includeAttachments = false
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            }
        }
        
        var mimeType: String {
            switch self {
            case .json: return "application/json"
            case .csv: return "text/csv"
            }
        }
    }
    
    // Responsive padding based on device type
    private var navigationBarPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 80 : 20
    }
    
    // Check for protected trips
    private var hasProtectedTrips: Bool {
        allTrips.contains { $0.isProtected }
    }
    
    private var protectedTripsCount: Int {
        allTrips.filter { $0.isProtected }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView("Generating export...")
                            .scaleEffect(1.2)
                        
                        Text("This may take a moment for large databases")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if !exportData.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Export Ready")
                                    .font(.headline)
                                Text("Your data has been exported successfully")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Enhanced preview with better visibility and error handling
                        ScrollView {
                            Group {
                                if exportData.hasPrefix("Error:") {
                                    // Error state with distinct styling
                                    Label(exportData, systemImage: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                        .font(.callout)
                                        .padding()
                                } else if exportData.isEmpty {
                                    // Empty state
                                    Text("No data to preview")
                                        .foregroundColor(.secondary)
                                        .font(.callout)
                                        .italic()
                                        .padding()
                                } else if exportData.count > 50000 {
                                    // Large data with truncation for performance
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .foregroundColor(.orange)
                                            Text("Large Export Preview")
                                                .font(.headline)
                                                .foregroundColor(.orange)
                                            Spacer()
                                            Text("\(exportData.count) characters")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.bottom, 4)
                                        
                                        Text("Preview (first 2000 characters):")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(String(exportData.prefix(2000)) + "\n\n... (truncated for performance)")
                                            .font(.system(.callout, design: .monospaced))
                                            .foregroundColor(.primary)
                                    }
                                    .padding()
                                } else {
                                    // Normal preview with improved readability
                                    Text(exportData)
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .padding()
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .frame(maxHeight: 300)
                        
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Share Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Export Your Data")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Create a backup of all your travel data including trips, activities, organizations, and more.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Export Options")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Format:")
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Picker("Format", selection: $exportFormat) {
                                        ForEach(ExportFormat.allCases, id: \.self) { format in
                                            Text(format.rawValue).tag(format)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 120)
                                }
                                
                                Toggle(isOn: $includeAttachments) {
                                    VStack(alignment: .leading) {
                                        Text("Include File Attachments")
                                            .fontWeight(.medium)
                                        Text("Embed file data in export (increases size)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Protection Status Warning
                        if hasProtectedTrips {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lock.trianglebadge.exclamationmark")
                                        .foregroundColor(.orange)
                                    Text("Protected Trips Notice")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                Text("You have \(protectedTripsCount) protected trip\(protectedTripsCount == 1 ? "" : "s"). Trip protection status will be preserved in the export and restored during import.")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                
                                Text("⚠️ Important: External export files contain trip data in plain text format. For maximum security, consider using internal app backups for protected trips.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.top, 4)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        VStack(spacing: 12) {
                            Button {
                                generateExport()
                            } label: {
                                Label("Generate Export", systemImage: "arrow.down.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isGenerating)
                            
                            DataSummaryView()
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding(.top, navigationBarPadding)
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [createExportFile()])
        }
    }
    
    @ViewBuilder
    private func DataSummaryView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Summary")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                DataCountCard(title: "Trips", count: allTrips.count, icon: "airplane")
                DataCountCard(title: "Transportation", count: allTransportation.count, icon: "car")
                DataCountCard(title: "Lodging", count: allLodging.count, icon: "bed.double")
                DataCountCard(title: "Activities", count: allActivities.count, icon: "ticket")
                DataCountCard(title: "Organizations", count: allOrganizations.count, icon: "building.2")
                DataCountCard(title: "Attachments", count: allAttachments.count, icon: "paperclip")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func generateExport() {
        isGenerating = true
        
        Task {
            let export: String
            
            switch exportFormat {
            case .json:
                export = await generateJSONExport()
            case .csv:
                export = await generateCSVExport()
            }
            
            await MainActor.run {
                exportData = export
                isGenerating = false
            }
        }
    }
    
    private func generateJSONExport() async -> String {
        let exportStructure: [String: Any] = [
            "exportInfo": [
                "version": "1.0",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "format": "json",
                "includesAttachments": includeAttachments
            ],
            "trips": allTrips.map { tripToDict($0) },
            "organizations": allOrganizations.map { organizationToDict($0) },
            "addresses": allAddresses.map { addressToDict($0) },
            "attachments": includeAttachments ? allAttachments.map { attachmentToDict($0) } : []
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportStructure, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "Error generating JSON"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func generateCSVExport() async -> String {
        var csv = "Export Generated: \(Date().formatted())\n\n"
        
        // Trips CSV
        csv += "=== TRIPS ===\n"
        csv += "ID,Name,Notes,Start Date,End Date,Has Start Date,Has End Date,Total Cost,Is Protected\n"
        for trip in allTrips {
            csv += "\"\(trip.id)\",\"\(trip.name)\",\"\(trip.notes)\",\"\(trip.startDate)\",\"\(trip.endDate)\",\(trip.hasStartDate),\(trip.hasEndDate),\(trip.totalCost),\(trip.isProtected)\n"
        }
        
        // Transportation CSV
        csv += "\n=== TRANSPORTATION ===\n"
        csv += "ID,Name,Type,Trip ID,Organization ID,Start,End,Cost,Paid,Confirmation,Notes\n"
        for transport in allTransportation {
            csv += "\"\(transport.id)\",\"\(transport.name)\",\"\(transport.type.rawValue)\",\"\(transport.trip?.id.uuidString ?? "")\",\"\(transport.organization?.id.uuidString ?? "")\",\"\(transport.start)\",\"\(transport.end)\",\(transport.cost),\"\(transport.paid.rawValue)\",\"\(transport.confirmation)\",\"\(transport.notes)\"\n"
        }
        
        // Lodging CSV
        csv += "\n=== LODGING ===\n"
        csv += "ID,Name,Trip ID,Organization ID,Start,End,Cost,Paid,Reservation,Notes\n"
        for lodging in allLodging {
            csv += "\"\(lodging.id)\",\"\(lodging.name)\",\"\(lodging.trip?.id.uuidString ?? "")\",\"\(lodging.organization?.id.uuidString ?? "")\",\"\(lodging.start)\",\"\(lodging.end)\",\(lodging.cost),\"\(lodging.paid.rawValue)\",\"\(lodging.reservation)\",\"\(lodging.notes)\"\n"
        }
        
        // Activities CSV
        csv += "\n=== ACTIVITIES ===\n"
        csv += "ID,Name,Trip ID,Organization ID,Start,End,Cost,Paid,Reservation,Notes\n"
        for activity in allActivities {
            csv += "\"\(activity.id)\",\"\(activity.name)\",\"\(activity.trip?.id.uuidString ?? "")\",\"\(activity.organization?.id.uuidString ?? "")\",\"\(activity.start)\",\"\(activity.end)\",\(activity.cost),\"\(activity.paid.rawValue)\",\"\(activity.reservation)\",\"\(activity.notes)\"\n"
        }
        
        // Organizations CSV
        csv += "\n=== ORGANIZATIONS ===\n"
        csv += "ID,Name,Phone,Email,Website,Logo URL\n"
        for org in allOrganizations {
            csv += "\"\(org.id)\",\"\(org.name)\",\"\(org.phone)\",\"\(org.email)\",\"\(org.website)\",\"\(org.logoURL)\"\n"
        }
        
        return csv
    }
    
    // Helper functions to convert models to dictionaries
    private func tripToDict(_ trip: Trip) -> [String: Any] {
        var tripDict: [String: Any] = [
            "id": trip.id.uuidString,
            "name": trip.name,
            "notes": trip.notes,
            "createdDate": ISO8601DateFormatter().string(from: trip.createdDate),
            "startDate": ISO8601DateFormatter().string(from: trip.startDate),
            "endDate": ISO8601DateFormatter().string(from: trip.endDate),
            "hasStartDate": trip.hasStartDate,
            "hasEndDate": trip.hasEndDate,
            "totalCost": NSDecimalNumber(decimal: trip.totalCost).doubleValue,
            "isProtected": trip.isProtected,
            "transportation": trip.transportation.map { $0.id.uuidString },
            "lodging": trip.lodging.map { $0.id.uuidString },
            "activities": trip.activity.map { $0.id.uuidString }
        ]
        
        // Embed full activity data for easier import
        tripDict["embeddedTransportation"] = trip.transportation.map { transportationToDict($0) }
        tripDict["embeddedLodging"] = trip.lodging.map { lodgingToDict($0) }
        tripDict["embeddedActivities"] = trip.activity.map { activityToDict($0) }
        
        return tripDict
    }
    
    private func transportationToDict(_ transportation: Transportation) -> [String: Any] {
        return [
            "id": transportation.id.uuidString,
            "name": transportation.name,
            "type": transportation.type.rawValue,
            "start": ISO8601DateFormatter().string(from: transportation.start),
            "end": ISO8601DateFormatter().string(from: transportation.end),
            "startTZId": transportation.startTZId,
            "endTZId": transportation.endTZId,
            "cost": NSDecimalNumber(decimal: transportation.cost).doubleValue,
            "paid": transportation.paid.rawValue,
            "confirmation": transportation.confirmation,
            "notes": transportation.notes,
            "organizationId": transportation.organization?.id.uuidString ?? ""
        ]
    }
    
    private func lodgingToDict(_ lodging: Lodging) -> [String: Any] {
        return [
            "id": lodging.id.uuidString,
            "name": lodging.name,
            "start": ISO8601DateFormatter().string(from: lodging.start),
            "end": ISO8601DateFormatter().string(from: lodging.end),
            "startTZId": lodging.startTZId,
            "endTZId": lodging.endTZId,
            "cost": NSDecimalNumber(decimal: lodging.cost).doubleValue,
            "paid": lodging.paid.rawValue,
            "reservation": lodging.reservation,
            "notes": lodging.notes,
            "organizationId": lodging.organization?.id.uuidString ?? "",
            "customLocationName": lodging.customLocationName,
            "hideLocation": lodging.hideLocation
        ]
    }
    
    private func activityToDict(_ activity: Activity) -> [String: Any] {
        return [
            "id": activity.id.uuidString,
            "name": activity.name,
            "start": ISO8601DateFormatter().string(from: activity.start),
            "end": ISO8601DateFormatter().string(from: activity.end),
            "startTZId": activity.startTZId,
            "endTZId": activity.endTZId,
            "cost": NSDecimalNumber(decimal: activity.cost).doubleValue,
            "paid": activity.paid.rawValue,
            "reservation": activity.reservation,
            "notes": activity.notes,
            "organizationId": activity.organization?.id.uuidString ?? "",
            "customLocationName": activity.customLocationName,
            "hideLocation": activity.hideLocation
        ]
    }
    
    private func organizationToDict(_ org: Organization) -> [String: Any] {
        return [
            "id": org.id.uuidString,
            "name": org.name,
            "phone": org.phone,
            "email": org.email,
            "website": org.website,
            "logoURL": org.logoURL,
            "cachedLogoFilename": org.cachedLogoFilename,
            "address": org.address != nil ? addressToDict(org.address!) : NSNull()
        ]
    }
    
    private func addressToDict(_ address: Address) -> [String: Any] {
        return [
            "id": address.id.uuidString,
            "street": address.street,
            "city": address.city,
            "state": address.state,
            "country": address.country,
            "postalCode": address.postalCode,
            "latitude": address.latitude,
            "longitude": address.longitude,
            "formattedAddress": address.formattedAddress
        ]
    }
    
    private func attachmentToDict(_ attachment: EmbeddedFileAttachment) -> [String: Any] {
        var dict: [String: Any] = [
            "id": attachment.id.uuidString,
            "fileName": attachment.fileName,
            "originalFileName": attachment.originalFileName,
            "fileSize": attachment.fileSize,
            "mimeType": attachment.mimeType,
            "fileExtension": attachment.fileExtension,
            "createdDate": ISO8601DateFormatter().string(from: attachment.createdDate),
            "fileDescription": attachment.fileDescription
        ]
        
        // Include parent relationship information for proper restoration
        if let activity = attachment.activity {
            dict["parentType"] = "activity"
            dict["parentId"] = activity.id.uuidString
        } else if let lodging = attachment.lodging {
            dict["parentType"] = "lodging"
            dict["parentId"] = lodging.id.uuidString
        } else if let transportation = attachment.transportation {
            dict["parentType"] = "transportation"
            dict["parentId"] = transportation.id.uuidString
        }
        
        if includeAttachments, let fileData = attachment.fileData {
            dict["fileData"] = fileData.base64EncodedString()
        }
        
        return dict
    }
    
    private func createExportFile() -> URL {
        let fileName = "TravelingSnails_Export_\(Date().timeIntervalSince1970).\(exportFormat.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try exportData.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            Logger.shared.error("Failed to create export file: \(error.localizedDescription)", category: .export)
            return tempURL
        }
    }
}

struct DataCountCard: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading) {
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
