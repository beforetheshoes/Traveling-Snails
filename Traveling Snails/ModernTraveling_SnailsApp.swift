//
//  ModernTraveling_SnailsApp.swift
//  Traveling Snails
//
//

import CloudKit
import ComposableArchitecture
import SQLiteData
import SwiftUI

/// Modern app structure using pure dependency injection - no backward compatibility
@main
struct ModernTraveling_SnailsApp: App {
    @State private var showSplash = false
    @State private var hasShownSplashOnce = false
    @Environment(\.scenePhase) private var scenePhase

    private let modernSyncManager: ModernSyncManager
    private let modernAppSettings: ModernAppSettings
    private let modernBiometricAuthManager: ModernBiometricAuthManager
    @State private var syncEngineDelegate: AppSyncEngineDelegate
    private let appStore: StoreOf<AppFeature>

    init() {
        do {
            let syncEngineDelegate = AppSyncEngineDelegate()
            self._syncEngineDelegate = State(initialValue: syncEngineDelegate)

            // Initialize production services directly
            let authService = ProductionAuthenticationService()
            let cloudService = iCloudStorageService()
            let photoService = SystemPhotoLibraryService()
            let permissionService = SystemPermissionService()
            let syncService = SQLiteDataSyncService()

            _ = photoService
            _ = permissionService

            // Create modern managers from concrete services
            modernSyncManager = ModernSyncManager(
                syncService: syncService,
                cloudStorageService: cloudService
            )
            modernAppSettings = ModernAppSettings(
                cloudStorageService: cloudService
            )
            modernBiometricAuthManager = ModernBiometricAuthManager(
                authService: authService
            )

            Logger.shared.info("Modern App: All services initialized successfully", category: .app)
            try prepareDependencies {
                try $0.bootstrapDatabase(syncEngineDelegate: syncEngineDelegate)
            }

            appStore = Store(initialState: AppFeature.State()) {
                AppFeature()
            }
        } catch {
            Logger.shared.critical("Could not initialize database: \(error)", category: .app)
            fatalError("Could not initialize database")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppView(store: appStore)
                    .environment(modernAppSettings)
                    .environment(modernSyncManager)
                    .environment(modernBiometricAuthManager)
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView(isVisible: $showSplash)
                        .transition(.opacity)
                        .onTapGesture {
                            showSplash = false
                        }
                }
            }
            .onAppear {
                // Only show splash on first launch
                if !hasShownSplashOnce {
                    hasShownSplashOnce = true
                } else {
                    showSplash = false
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // Use modern biometric auth manager
                    modernBiometricAuthManager.resetSession()
                case .active:
                    break
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
