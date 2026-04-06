//
//  DatabaseImportProgressView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

struct DatabaseImportProgressView: View {
    @Bindable var store: StoreOf<DatabaseImportFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                if store.isImporting {
                    VStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("Importing Data")
                            .font(.title2)
                            .fontWeight(.semibold)

                        VStack(spacing: 12) {
                            ProgressView(value: store.importProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(1.2)

                            Text(store.importStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Text("\(Int(store.importProgress * 100))% Complete")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }

                        Text("Please don't close this screen during import")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if store.importSuccess {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("Import Successful!")
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let result = store.importResult {
                            VStack(spacing: 12) {
                                Text("Import Summary")
                                    .font(.headline)
                                    .padding(.bottom, 8)

                                ImportSummaryGrid(result: result)

                                if result.organizationsMerged > 0 {
                                    HStack {
                                        Image(systemName: "arrow.triangle.merge")
                                            .foregroundStyle(.orange)
                                        Text("\(result.organizationsMerged) organizations merged with existing data")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding()
                            .background(Color.systemGray6)
                            .clipShape(.rect(cornerRadius: 12))
                            .padding(.horizontal)
                        }

                        Text("Your data has been imported successfully. Duplicate organizations were automatically merged.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            store.send(.doneTapped)
                        } label: {
                            Label("Done", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                    .padding()
                } else if let error = store.importError {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)

                        Text("Import Failed")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(error)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            store.send(.doneTapped)
                        } label: {
                            Label("Close", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                    .padding()
                }

                Spacer()
            }
            .navigationTitle("Import Progress")
            .inlineNavigationBarTitle()
            .toolbar {
                if !store.isImporting {
                    ToolbarItem(placement: .platformTrailing) {
                        Button("Done") {
                            store.send(.doneTapped)
                        }
                    }
                }
            }
            .interactiveDismissDisabled(store.isImporting)
        }
    }
}

struct ImportSummaryGrid: View {
    let result: DatabaseImportManager.ImportResult

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            ImportStatCard(title: "Trips", count: result.tripsImported, icon: "airplane", color: .blue)
            ImportStatCard(title: "Transportation", count: result.transportationImported, icon: "car", color: .green)
            ImportStatCard(title: "Lodging", count: result.lodgingImported, icon: "bed.double", color: .orange)
            ImportStatCard(title: "Activities", count: result.activitiesImported, icon: "ticket", color: .purple)
            ImportStatCard(title: "Organizations", count: result.organizationsImported, icon: "building.2", color: .red)
            ImportStatCard(title: "Attachments", count: result.attachmentsImported, icon: "paperclip", color: .brown)
        }
    }
}

struct ImportStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }
}
