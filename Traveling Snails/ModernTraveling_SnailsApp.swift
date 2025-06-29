//
//  ModernTraveling_SnailsApp.swift
//  Traveling Snails
//
//

import CloudKit
import SwiftData
import SwiftUI

/// Modern app structure using dependency injection
/// This will eventually replace Traveling_SnailsApp.swift
/// Fixed with proper async CloudKit initialization timing
// @main - CloudKit timing issue persists, needs further investigation
struct ModernTraveling_SnailsApp: App {
    // MARK: - Properties

    @State private var showSplash = true
    @State private var hasShownSplashOnce = false
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer
    private let serviceContainer: ServiceContainer
    private let backwardCompatibilityAdapter: BackwardCompatibilityAdapter
    @State private var servicesConfigured = false

    // MARK: - Initialization

    init() {
        do {
            // Create schema
            let schema = Schema([
                Trip.self,
                Lodging.self,
                Organization.self,
                Transportation.self,
                Activity.self,
                Address.self,
                EmbeddedFileAttachment.self,
            ])

            // Check if running in test environment
            #if DEBUG
            let isInTests = NSClassFromString("XCTestCase") != nil ||
                          ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                          UserDefaults.standard.bool(forKey: "isRunningTests")

            let modelConfiguration: ModelConfiguration
            if isInTests {
                print("🧪 ModernApp: Test environment detected, using in-memory storage")
                modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            } else {
                // CRITICAL: Do NOT use cloudKitDatabase: .automatic during init() - causes "Early unexpected exit" crash
                // CloudKit configuration will be set up later in onAppear after app launch
                print("🏗️ ModernApp: Using local storage, CloudKit will be configured after app launch")
                modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            }
            #else
            // CRITICAL: Do NOT use cloudKitDatabase: .automatic during init() - causes "Early unexpected exit" crash
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            #endif

            // Create model container
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Create basic service container with MainActor isolation
            serviceContainer = ServiceContainer()
            print("✅ ModernApp: Basic ServiceContainer created")

            // Create backward compatibility adapter (minimal configuration)
            backwardCompatibilityAdapter = BackwardCompatibilityAdapter()
            print("✅ ModernApp: BackwardCompatibilityAdapter created")

            // NOTE: CloudKit/SyncManager registration is deferred to avoid startup crash
            // These will be configured asynchronously in onAppear to prevent blocking app startup

            print("✅ ModernApp: Dependency injection setup complete")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - App Body

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .serviceContainer(serviceContainer)
                    .backwardCompatibilityAdapter(backwardCompatibilityAdapter)
                    .environment(\.authenticationService, serviceContainer.tryResolve(AuthenticationService.self))
                    .environment(\.cloudStorageService, serviceContainer.tryResolve(CloudStorageService.self))
                    .environment(\.photoLibraryService, serviceContainer.tryResolve(PhotoLibraryService.self))
                    .environment(\.syncService, serviceContainer.tryResolve(SyncService.self))
                    .environment(\.permissionService, serviceContainer.tryResolve(PermissionService.self))
                    .opacity(showSplash ? 0 : 1)
                    .overlay {
                        if !servicesConfigured && !showSplash {
                            ProgressView("Configuring Services...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.3))
                        }
                    }

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

                // Configure all services asynchronously after app startup
                Task {
                    await configureAllServicesAsync()
                    await MainActor.run {
                        servicesConfigured = true
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // Reset authentication when app goes to background
                    if backwardCompatibilityAdapter.isFullyConfigured {
                        backwardCompatibilityAdapter.biometricAuthManager.resetSession()
                    }
                case .active, .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
        .modelContainer(modelContainer)
    }

    // MARK: - Async Configuration

    /// Configure all services asynchronously to avoid blocking app startup
    /// Uses proper Swift concurrency patterns for CloudKit initialization
    private func configureAllServicesAsync() async {
        // Check if running in test environment
        #if DEBUG
        let isInTests = NSClassFromString("XCTestCase") != nil ||
                      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                      UserDefaults.standard.bool(forKey: "isRunningTests")

        guard !isInTests else {
            print("🧪 ModernApp: Skipping async service configuration in test environment")
            return
        }
        #endif

        print("🔄 ModernApp: Starting async service configuration...")

        // Step 1: Configure CloudKit for ModelContainer (safe after app launch)
        await configureCloudKitForModelContainer()

        // Step 2: Register production services (safe during startup)
        let authService = ProductionAuthenticationService()
        serviceContainer.register(authService, as: AuthenticationService.self)

        let cloudService = iCloudStorageService()
        serviceContainer.register(cloudService, as: CloudStorageService.self)

        let photoService = SystemPhotoLibraryService()
        serviceContainer.register(photoService, as: PhotoLibraryService.self)

        let permissionService = SystemPermissionService()
        serviceContainer.register(permissionService, as: PermissionService.self)

        print("✅ ModernApp: Registered core services asynchronously")

        // Step 3: Configure backward compatibility adapter (basic configuration)
        backwardCompatibilityAdapter.configure(with: serviceContainer)
        print("✅ ModernApp: Configured BackwardCompatibilityAdapter asynchronously")

        // Step 4: Configure sync manager using async pattern
        // This will register CloudKitSyncService internally to avoid "Early unexpected exit" error
        await backwardCompatibilityAdapter.configureSyncManagerAsync(with: modelContainer)
        print("✅ ModernApp: Configured SyncManager asynchronously")

        print("✅ ModernApp: All services configured successfully")
    }

    /// Configure CloudKit for the ModelContainer after app launch (safe timing)
    private func configureCloudKitForModelContainer() async {
        print("🔄 ModernApp: Configuring CloudKit for SwiftData (post-launch)")

        // Note: Since ModelContainer is already created without CloudKit,
        // CloudKit sync will be handled by CloudKitSyncService which bridges
        // between local SwiftData storage and CloudKit

        // CloudKit account status check (safe after app launch)
        do {
            // This is now safe to call after app launch
            let container = CKContainer.default()
            let accountStatus = try await container.accountStatus()

            switch accountStatus {
            case .available:
                print("✅ ModernApp: CloudKit account available")
            case .noAccount:
                print("⚠️ ModernApp: No CloudKit account configured")
            case .restricted:
                print("⚠️ ModernApp: CloudKit account restricted")
            case .temporarilyUnavailable:
                print("⚠️ ModernApp: CloudKit temporarily unavailable")
            case .couldNotDetermine:
                print("⚠️ ModernApp: Could not determine CloudKit status")
            @unknown default:
                print("⚠️ ModernApp: Unknown CloudKit account status")
            }
        } catch {
            print("⚠️ ModernApp: CloudKit account status check failed: \(error)")
        }

        print("✅ ModernApp: CloudKit configuration completed")
    }
}

// MARK: - Preview Support

#if DEBUG
/// Preview-specific app configuration
struct PreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .serviceContainer(DefaultServiceContainerFactory.createPreviewContainer())
        }
        .modelContainer(for: [Trip.self, Lodging.self, Organization.self, Transportation.self, Activity.self, Address.self, EmbeddedFileAttachment.self], inMemory: true)
    }
}
#endif
