//
//  SettingsContentView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import Dependencies
import SwiftUI

struct SettingsContentView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        List {
            // Appearance Section
            AppearanceSection(store: store)

            // Data Management Section
            DataManagementSection(store: store)

            // File Attachments Section
            FileAttachmentsSection(store: store)

            // Security Section
            SecuritySection(store: store)

            // About Section
            AboutSection(store: store)

            #if DEBUG
            // Developer Section
            DeveloperSection(store: store)
            #endif

            // Import Result Display
            if let result = store.importResult {
                ImportResultSection(result: result)
            }
        }
        .navigationTitle("Settings")
        .sheet(item: Binding(
            get: { store.activeSheet },
            set: { store.send(.activeSheetChanged($0)) }
        )) { activeSheet in
            Group {
                switch activeSheet {
                case .dataBrowser:
                    DataBrowserView(
                        store: store.scope(
                            state: \.dataBrowser,
                            action: \.dataBrowser
                        )
                    )
                case .exportView:
                    DatabaseExportView(
                        store: store.scope(
                            state: \.databaseExport,
                            action: \.databaseExport
                        )
                    )
                case .fileAttachmentSettings:
                    FileAttachmentSettingsView(
                        store: store.scope(
                            state: \.fileAttachmentSettings,
                            action: \.fileAttachmentSettings
                        )
                    )
                case .databaseImportProgress:
                    DatabaseImportProgressView(
                        store: store.scope(
                            state: \.databaseImport,
                            action: \.databaseImport
                        )
                    )
                case .databaseCleanup:
                    DatabaseCleanupView(
                        store: store.scope(
                            state: \.databaseCleanup,
                            action: \.databaseCleanup
                        )
                    )
                }
            }
            #if os(macOS)
            .frame(minWidth: 600, minHeight: 450)
            #endif
        }
        .fileImporter(
            isPresented: $store.showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            store.send(.importPickerResult(result))
        }
        .alert("Import Failed", isPresented: $store.showingImportError) {
            Button("OK") { store.send(.dismissImportError) }
        } message: {
            Text(store.importError ?? L(L10n.Settings.Import.failed))
        }
        .onAppear { store.send(.onAppear) }
    }
}

// MARK: - Appearance Section

struct AppearanceSection: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        Section("Appearance") {
            #if os(macOS)
            Picker(selection: Binding(
                get: { store.colorSchemePreference },
                set: { store.send(.colorSchemeChanged($0)) }
            )) {
                Text("System").tag(ColorSchemePreference.system)
                Text("Light").tag(ColorSchemePreference.light)
                Text("Dark").tag(ColorSchemePreference.dark)
            } label: {
                Label("Appearance", systemImage: "moon.fill")
            }
            #else
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text("Dark Mode")

                Spacer()

                Picker("Color Scheme", selection: Binding(
                    get: { store.colorSchemePreference },
                    set: { store.send(.colorSchemeChanged($0)) }
                )) {
                    Text("System").tag(ColorSchemePreference.system)
                    Text("Light").tag(ColorSchemePreference.light)
                    Text("Dark").tag(ColorSchemePreference.dark)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            #endif
        }
    }
}

// MARK: - Data Management Section

struct DataManagementSection: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        Section("Data Management") {
            Button {
                store.send(.openDataBrowser)
            } label: {
                SettingsRow(
                    icon: "cylinder.split.1x2",
                    iconColor: .purple,
                    title: "Data Browser",
                    subtitle: "Browse and manage your travel data"
                )
            }
            .foregroundStyle(.primary)

            Button {
                store.send(.openExportView)
            } label: {
                SettingsRow(
                    icon: "square.and.arrow.up",
                    iconColor: .green,
                    title: "Export Data",
                    subtitle: "Create a backup of your data"
                )
            }
            .foregroundStyle(.primary)

            Button {
                store.send(.openImportPicker)
            } label: {
                SettingsRow(
                    icon: "square.and.arrow.down",
                    iconColor: .orange,
                    title: "Import Data",
                    subtitle: "Restore from a backup file"
                )
            }
            .foregroundStyle(.primary)

            Button {
                store.send(.cleanupNoneOrganizationsTapped)
            } label: {
                SettingsRow(
                    icon: "building.2.crop.circle.badge.checkmark",
                    iconColor: .blue,
                    title: "Fix Duplicate Organizations",
                    subtitle: "Clean up duplicate 'None' organizations"
                )
            }
            .foregroundStyle(.primary)

            Button {
                store.send(.openDatabaseCleanup)
            } label: {
                SettingsRow(
                    icon: "trash.circle",
                    iconColor: .red,
                    title: "Database Cleanup",
                    subtitle: "Remove test data and reset database"
                )
            }
            .foregroundStyle(.primary)
        }
        .alert("Organization Cleanup", isPresented: $store.showingOrganizationCleanupAlert) {
            Button("OK") { }
        } message: {
            Text(store.organizationCleanupMessage)
        }
    }
}

// MARK: - File Attachments Section

struct FileAttachmentsSection: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        Section("File Attachments") {
            Button {
                store.send(.openFileAttachmentSettings)
            } label: {
                SettingsRow(
                    icon: "paperclip",
                    iconColor: .brown,
                    title: "Attachment Settings",
                    subtitle: "Manage file attachments and storage"
                )
            }
            .foregroundStyle(.primary)
        }
    }
}

// MARK: - Security Section

struct SecuritySection: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        Section {
            if store.canUseBiometrics {
                HStack {
                    Image(systemName: store.isFaceID ? "faceid" : "touchid")
                        .foregroundStyle(.green)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text("\(store.isFaceID ? "Face ID" : "Touch ID") Available")
                            .font(.headline)
                        Text("You can protect individual trips with biometric authentication")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                HStack {
                    Text("Auto-lock timeout")
                    Spacer()
                    Menu {
                        ForEach(SettingsTimeoutOption.allCases, id: \.self) { option in
                            Button(option.displayName) {
                                let minutes = Int(option.rawValue / 60)
                                store.send(.biometricTimeoutChanged(minutes))
                            }
                        }
                    } label: {
                        Text(SettingsTimeoutOption.from(TimeInterval(store.biometricTimeoutMinutes * 60)).displayName)
                            .foregroundStyle(.blue)
                    }
                }

                if !store.allTripsLocked {
                    Button("Lock All Protected Trips Now") {
                        store.send(.lockAllProtectedTripsTapped)
                    }
                    .foregroundStyle(.red)
                } else {
                    Text("All Protected Trips Are Locked")
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "faceid")
                        .foregroundStyle(.gray)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text("Biometric Authentication Unavailable")
                            .font(.headline)
                        Text("This device doesn't support biometric authentication")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Security")
        } footer: {
            Text("Biometric authentication is always enabled when available. You can protect individual trips by enabling protection in trip settings. Auto-lock will require re-authentication after the specified time.")
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text("Version")

                Spacer()

                Text(store.appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "number")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text("Build")

                Spacer()

                Text(store.buildNumber)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Import Result Section

struct ImportResultSection: View {
    let result: DatabaseImportManager.ImportResult

    var body: some View {
        Section("Last Import Results") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Import Summary")
                    .font(.headline)

                ImportResultSummary(result: result)
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Developer Section

#if DEBUG
struct DeveloperSection: View {
    let store: StoreOf<SettingsFeature>

    @State private var refreshResult: String?

    var body: some View {
        Section("Developer") {
            NavigationLink {
                SyncDiagnosticView(
                    store: store.scope(
                        state: \.syncDiagnostic,
                        action: \.syncDiagnostic
                    )
                )
            } label: {
                SettingsRow(
                    icon: "ladybug",
                    iconColor: .red,
                    title: "Sync Diagnostics",
                    subtitle: "Debug and diagnose CloudKit sync issues"
                )
            }
            .foregroundStyle(.primary)

            Button {
                refreshResult = nil
                Task {
                    await APIKeyManager.shared.refreshKeys()
                    refreshResult = "Keys refreshed from CloudKit"
                }
            } label: {
                SettingsRow(
                    icon: "arrow.clockwise.icloud",
                    iconColor: .blue,
                    title: "Refresh API Keys",
                    subtitle: refreshResult ?? "Re-fetch keys from CloudKit"
                )
            }
        }
    }
}
#endif

// MARK: - Reusable Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
