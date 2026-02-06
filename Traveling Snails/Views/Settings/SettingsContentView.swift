//
//  SettingsContentView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

struct SettingsContentView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        List {
            // Appearance Section
            AppearanceSection()

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
            DeveloperSection()
            #endif

            // Import Result Display
            if let result = store.importResult {
                ImportResultSection(result: result)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $store.showingDataBrowser) {
            DataBrowserView()
        }
        .sheet(isPresented: $store.showingExportView) {
            DatabaseExportView()
        }
        .fileImporter(
            isPresented: $store.showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            store.send(.importPickerResult(result))
        }
        .sheet(isPresented: $store.showingFileAttachmentSettings) {
            FileAttachmentSettingsView()
        }
        .sheet(isPresented: $store.showingImportProgress) {
            DatabaseImportProgressView(importManager: store.importManager)
        }
        .sheet(isPresented: $store.showingDatabaseCleanup) {
            DatabaseCleanupView()
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
    @Environment(ModernAppSettings.self) private var appSettings

    var body: some View {
        Section("Appearance") {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text("Dark Mode")

                Spacer()

                Picker("Color Scheme", selection: Binding(
                    get: { appSettings.colorScheme },
                    set: { appSettings.colorScheme = $0 }
                )) {
                    Text("System").tag(ColorSchemePreference.system)
                    Text("Light").tag(ColorSchemePreference.light)
                    Text("Dark").tag(ColorSchemePreference.dark)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            #if DEBUG
            Button("🧪 Test iCloud Sync") {
                AppSettings.shared.forceSyncTest()
            }
            .foregroundColor(.orange)
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
            .foregroundColor(.primary)

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
            .foregroundColor(.primary)

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
            .foregroundColor(.primary)

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
            .foregroundColor(.primary)

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
            .foregroundColor(.primary)
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
            .foregroundColor(.primary)
        }
    }
}

// MARK: - Security Section

struct SecuritySection: View {
    let store: StoreOf<SettingsFeature>
    @Environment(ModernBiometricAuthManager.self) private var authManager
    @Environment(ModernAppSettings.self) private var appSettings

    var body: some View {
        Section {
            if authManager.canUseBiometrics() {
                HStack {
                    Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                        .foregroundColor(.green)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text("\(authManager.biometricType == .faceID ? "Face ID" : "Touch ID") Available")
                            .font(.headline)
                        Text("You can protect individual trips with biometric authentication")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                HStack {
                    Text("Auto-lock timeout")
                    Spacer()
                    Menu {
                        ForEach(SettingsTimeoutOption.allCases, id: \.self) { option in
                            Button(option.displayName) {
                                let minutes = Int(option.rawValue / 60)
                                appSettings.biometricTimeoutMinutes = minutes
                            }
                        }
                    } label: {
                        Text(SettingsTimeoutOption.from(TimeInterval(appSettings.biometricTimeoutMinutes * 60)).displayName)
                            .foregroundColor(.blue)
                    }
                }

                if !store.allTripsLocked {
                    Button("Lock All Protected Trips Now") {
                        store.send(.lockAllProtectedTripsTapped)
                    }
                    .foregroundColor(.red)
                } else {
                    Text("All Protected Trips Are Locked")
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "faceid")
                        .foregroundColor(.gray)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text("Biometric Authentication Unavailable")
                            .font(.headline)
                        Text("This device doesn't support biometric authentication")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
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
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text("Version")

                Spacer()

                Text(store.appVersion)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "number")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text("Build")

                Spacer()

                Text(store.buildNumber)
                    .foregroundColor(.secondary)
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
    var body: some View {
        Section("Developer") {
            NavigationLink {
                SyncDiagnosticView()
            } label: {
                SettingsRow(
                    icon: "ladybug",
                    iconColor: .red,
                    title: "Sync Diagnostics",
                    subtitle: "Debug and diagnose CloudKit sync issues"
                )
            }
            .foregroundColor(.primary)
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
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
