//
//  SettingsRootView.swift
//  Traveling Snails
//
//

import SwiftUI
import SwiftData

/// Root view for settings - coordinates ViewModel and handles dependencies
struct SettingsRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.serviceContainer) private var serviceContainer
    
    @State private var viewModel: SettingsViewModel?
    
    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    SettingsContentView(viewModel: viewModel)
                } else {
                    ProgressView("Loading Settings...")
                        .onAppear {
                            let authService = serviceContainer.resolve(AuthenticationService.self)
                            viewModel = SettingsViewModel(modelContext: modelContext, authService: authService)
                        }
                }
            }
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
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("\(result.organizationsMerged) organizations merged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            
            if !result.errors.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text("\(result.errors.count) errors occurred")
                        .font(.caption)
                        .foregroundColor(.red)
                    
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
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
