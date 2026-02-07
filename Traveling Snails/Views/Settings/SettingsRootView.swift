//
//  SettingsRootView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

/// Root view for settings - coordinates ViewModel and handles dependencies
struct SettingsRootView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            SettingsContentView(store: store)
        }
    }
}

struct ImportResultSummary: View {
    let result: DatabaseImportManager.ImportResult

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ResultItem(label: "Trips", count: result.tripsImported, color: .blue)
                ResultItem(label: "Organizations", count: result.organizationsImported, color: .red)
            }

            HStack {
                ResultItem(label: "Transportation", count: result.transportationImported, color: .green)
                ResultItem(label: "Lodging", count: result.lodgingImported, color: .orange)
            }

            HStack {
                ResultItem(label: "Activities", count: result.activitiesImported, color: .purple)
                ResultItem(label: "Attachments", count: result.attachmentsImported, color: .brown)
            }

            if result.organizationsMerged > 0 {
                HStack {
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Text("\(result.organizationsMerged) organizations merged")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.top, 4)
            }

            if !result.errors.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)

                    Text("\(result.errors.count) errors occurred")
                        .font(.caption)
                        .foregroundStyle(.red)

                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }
}

struct ResultItem: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
