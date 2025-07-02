//
//  ModernTraveling_SnailsApp.swift
//  Traveling Snails
//
//

import CloudKit
import SwiftData
import SwiftUI

/// Modern app structure using pure dependency injection - no backward compatibility
@main
struct ModernTraveling_SnailsApp: App {
    @State private var showSplash = false
    @State private var hasShownSplashOnce = false
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer
    private let serviceContainer: ServiceContainer
    private let modernSyncManager: ModernSyncManager
    private let modernAppSettings: ModernAppSettings
    private let modernBiometricAuthManager: ModernBiometricAuthManager

    init() {
        do {
            let schema = Schema([
                Trip.self,
                Lodging.self,
                Organization.self,
                Transportation.self,
                Activity.self,
                Address.self,
                EmbeddedFileAttachment.self,
            ])

            // Check if running in test environment to avoid CloudKit issues
            #if DEBUG
            let hasXCTestCase = NSClassFromString("XCTestCase") != nil
            let hasXCTestConfig = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            // Force clear the isRunningTests flag if we're in a DEBUG build from Xcode
            UserDefaults.standard.set(false, forKey: "isRunningTests")
            let hasUserDefaultFlag = UserDefaults.standard.bool(forKey: "isRunningTests")
            // Debug: Check which UserDefaults domain we're actually using
            let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
            Logger.shared.debug("Debug: Bundle ID = \(bundleId)")
            // Only consider it a test environment if we have test config OR user default flag
            // XCTestCase may be loaded in DEBUG builds from Xcode, so we ignore it unless other conditions are met
            let isInTests = hasXCTestConfig || hasUserDefaultFlag

            Logger.shared.debug("Modern App Debug: XCTestCase=\(hasXCTestCase), XCTestConfig=\(hasXCTestConfig), UserDefault=\(hasUserDefaultFlag), isInTests=\(isInTests)")

            let modelConfiguration: ModelConfiguration
            if isInTests {
                Logger.shared.info("Modern App: Test environment detected, disabling CloudKit")
                modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            } else {
                Logger.shared.info("Modern App: Production environment, enabling CloudKit")
                modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
            }
            #else
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
            #endif

            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Initialize ServiceContainer and register all services
            serviceContainer = ServiceContainer()

            // Register production services
            let authService = ProductionAuthenticationService()
            serviceContainer.register(authService, as: AuthenticationService.self)

            let cloudService = iCloudStorageService()
            serviceContainer.register(cloudService, as: CloudStorageService.self)

            let photoService = SystemPhotoLibraryService()
            serviceContainer.register(photoService, as: PhotoLibraryService.self)

            let permissionService = SystemPermissionService()
            serviceContainer.register(permissionService, as: PermissionService.self)

            // Register sync service with model container
            let syncService = CloudKitSyncService(modelContainer: modelContainer)
            serviceContainer.register(syncService, as: SyncService.self)

            // Create modern managers from service container
            modernSyncManager = ModernSyncManager.from(container: serviceContainer)
            modernAppSettings = ModernAppSettings.from(container: serviceContainer)
            modernBiometricAuthManager = ModernBiometricAuthManager.from(container: serviceContainer)

            Logger.shared.info("Modern App: All services initialized successfully", category: .app)
        } catch {
            Logger.shared.critical("Could not create ModelContainer: \(error)", category: .app)
            fatalError("Could not create ModelContainer")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(modernAppSettings)
                    .environment(modernSyncManager)
                    .environment(modernBiometricAuthManager)
                    .environment(NavigationRouter.shared)
                    .serviceContainer(serviceContainer)
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
                    // REMOVED: Custom sync triggers - let SwiftData+CloudKit handle automatically
                    break
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
