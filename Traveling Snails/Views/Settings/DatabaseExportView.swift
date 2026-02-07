//
//  DatabaseExportView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct DatabaseExportView: View {
    private struct ShareSheetPayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<DatabaseExportFeature>

    @FetchAll private var allTrips: [Trip]
    @FetchAll private var allTransportation: [Transportation]
    @FetchAll private var allLodging: [Lodging]
    @FetchAll private var allActivities: [Activity]
    @FetchAll private var allOrganizations: [Organization]
    @FetchAll private var allAddresses: [Address]
    @FetchAll private var allAttachments: [EmbeddedFileAttachment]

    @State private var activeSheet: ShareSheetPayload?

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
                if store.isGenerating {
                    VStack(spacing: 16) {
                        ProgressView("Generating export...")
                            .scaleEffect(1.2)

                        Text("This may take a moment for large databases")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if !store.exportData.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)

                            VStack(alignment: .leading) {
                                Text("Export Ready")
                                    .font(.headline)
                                Text("Your data has been exported successfully")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 12))

                        // Enhanced preview with better visibility and error handling
                        ScrollView {
                            Group {
                                if store.exportData.hasPrefix("Error:") {
                                    // Error state with distinct styling
                                    Label(store.exportData, systemImage: "exclamationmark.triangle")
                                        .foregroundStyle(.red)
                                        .font(.callout)
                                        .padding()
                                } else if store.exportData.isEmpty {
                                    // Empty state
                                    Text("No data to preview")
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                        .italic()
                                        .padding()
                                } else if store.exportData.count > 50_000 {
                                    // Large data with truncation for performance
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .foregroundStyle(.orange)
                                            Text("Large Export Preview")
                                                .font(.headline)
                                                .foregroundStyle(.orange)
                                            Spacer()
                                            Text("\(store.exportData.count) characters")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.bottom, 4)

                                        Text("Preview (first 2000 characters):")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text(String(store.exportData.prefix(2000)) + "\n\n... (truncated for performance)")
                                            .font(.system(.callout, design: .monospaced))
                                            .foregroundStyle(.primary)
                                    }
                                    .padding()
                                } else {
                                    // Normal preview with improved readability
                                    Text(store.exportData)
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundStyle(.primary)
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
                            activeSheet = ShareSheetPayload(items: [createExportFile()])
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
                                .foregroundStyle(.blue)

                            Text("Export Your Data")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Create a backup of all your travel data including trips, activities, organizations, and more.")
                                .font(.body)
                                .foregroundStyle(.secondary)
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

                                    Picker("Format", selection: $store.exportFormat) {
                                        ForEach(DatabaseExportFeature.ExportFormat.allCases, id: \.self) { format in
                                            Text(format.rawValue).tag(format)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 120)
                                }

                                Toggle(isOn: $store.includeAttachments) {
                                    VStack(alignment: .leading) {
                                        Text("Include File Attachments")
                                            .fontWeight(.medium)
                                        Text("Embed file data in export (increases size)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(.rect(cornerRadius: 12))
                        }

                        // Protection Status Warning
                        if hasProtectedTrips {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lock.trianglebadge.exclamationmark")
                                        .foregroundStyle(.orange)
                                    Text("Protected Trips Notice")
                                        .font(.headline)
                                        .foregroundStyle(.orange)
                                }

                                Text("You have \(protectedTripsCount) protected trip\(protectedTripsCount == 1 ? "" : "s"). Trip protection status will be preserved in the export and restored during import.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)

                                Text("⚠️ Important: External export files contain trip data in plain text format. For maximum security, consider using internal app backups for protected trips.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(.top, 4)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }

                        VStack(spacing: 12) {
                            Button {
                                store.send(
                                    .generateTapped(
                                        .init(
                                            trips: allTrips,
                                            transportation: allTransportation,
                                            lodging: allLodging,
                                            activities: allActivities,
                                            organizations: allOrganizations,
                                            addresses: allAddresses,
                                            attachments: allAttachments
                                        )
                                    )
                                )
                            } label: {
                                Label("Generate Export", systemImage: "arrow.down.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(store.isGenerating)

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
        .sheet(item: $activeSheet) { payload in
            ShareSheet(items: payload.items)
        }
    }

    @ViewBuilder
    private func DataSummaryView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Summary")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
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
        .clipShape(.rect(cornerRadius: 12))
    }

    private func createExportFile() -> URL {
        let fileName = "TravelingSnails_Export_\(Date().timeIntervalSince1970).\(store.exportFormat.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try store.exportData.write(to: tempURL, atomically: true, encoding: .utf8)
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
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading) {
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
    }
}
