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
            let modernSyncManager = ModernSyncManager(
                syncService: syncService,
                cloudStorageService: cloudService
            )
            ModernSyncManager.shared = modernSyncManager
            let modernBiometricAuthManager = ModernBiometricAuthManager(
                authService: authService
            )
            ModernBiometricAuthManager.shared = modernBiometricAuthManager

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
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView(isVisible: $showSplash)
                        .transition(.opacity)
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
        }
    }
}
