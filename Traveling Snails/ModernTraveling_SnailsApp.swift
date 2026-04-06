//
//  ModernTraveling_SnailsApp.swift
//  Traveling Snails
//
//

import CloudKit
import ComposableArchitecture
import Dependencies
import SQLiteData
import SwiftUI

#if os(iOS)
/// App delegate — configures the scene delegate for CloudKit share acceptance
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// Scene delegate — handles CloudKit share acceptance in both scenarios:
/// 1. App is already running when share link is tapped
/// 2. App is cold-launched via share link
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    @Dependency(\.defaultSyncEngine) var syncEngine

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            do {
                try await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
                Logger.shared.info("Accepted CloudKit share (app running)", category: .sync)
            } catch {
                Logger.shared.error("Failed to accept CloudKit share: \(error.localizedDescription)", category: .sync)
            }
        }
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let cloudKitShareMetadata = connectionOptions.cloudKitShareMetadata else { return }
        Task {
            do {
                try await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
                Logger.shared.info("Accepted CloudKit share (cold launch)", category: .sync)
            } catch {
                Logger.shared.error("Failed to accept CloudKit share on launch: \(error.localizedDescription)", category: .sync)
            }
        }
    }
}
#elseif os(macOS)
/// App delegate for macOS — handles CloudKit share acceptance
class AppDelegate: NSObject, NSApplicationDelegate {
    @Dependency(\.defaultSyncEngine) var syncEngine

    func application(_ application: NSApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task {
            do {
                try await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
                Logger.shared.info("Accepted CloudKit share (macOS)", category: .sync)
            } catch {
                Logger.shared.error("Failed to accept CloudKit share: \(error.localizedDescription)", category: .sync)
            }
        }
    }
}
#endif

/// Modern app structure using pure dependency injection
@main
struct ModernTraveling_SnailsApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @State private var showSplash = false
    @State private var hasShownSplashOnce = false

    @State private var syncEngineDelegate: AppSyncEngineDelegate
    private let appStore: StoreOf<AppFeature>

    init() {
        do {
            let syncEngineDelegate = AppSyncEngineDelegate()
            self._syncEngineDelegate = State(initialValue: syncEngineDelegate)

            Logger.shared.info("Modern App: Initializing database", category: .app)
            try prepareDependencies {
                try $0.bootstrapDatabase(syncEngineDelegate: syncEngineDelegate)
            }

            appStore = StoreOf<AppFeature>.init(initialState: AppFeature.State()) {
                AppFeature()
            }
        } catch {
            Logger.shared.critical("Could not initialize database: \(error)", category: .app)
            fatalError("Could not initialize database: \(error)")
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
                if !hasShownSplashOnce {
                    hasShownSplashOnce = true
                } else {
                    showSplash = false
                }
            }
        }
    }
}
