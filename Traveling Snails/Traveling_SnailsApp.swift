import SwiftUI
import SwiftData

@main
struct Traveling_SnailsApp: App {
    @State private var appSettings = AppSettings.shared
    @State private var syncManager = SyncManager.shared
    @State private var showSplash = false
    @State private var hasShownSplashOnce = false
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Trip.self,
                Lodging.self,
                Organization.self,
                Transportation.self,
                Activity.self,
                Address.self,
                EmbeddedFileAttachment.self
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
            print("🔍 Debug: Bundle ID = \(bundleId)")
            // Only consider it a test environment if we have test config OR user default flag
            // XCTestCase may be loaded in DEBUG builds from Xcode, so we ignore it unless other conditions are met
            let isInTests = hasXCTestConfig || hasUserDefaultFlag
            
            print("🔍 App Debug: XCTestCase=\(hasXCTestCase), XCTestConfig=\(hasXCTestConfig), UserDefault=\(hasUserDefaultFlag), isInTests=\(isInTests)")
            
            let modelConfiguration: ModelConfiguration
            if isInTests {
                print("🧪 App: Test environment detected, disabling CloudKit")
                modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            } else {
                print("🐌 App: Production environment, enabling CloudKit")
                modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
            }
            #else
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
            #endif
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Configure the SyncManager only if not in tests
            #if DEBUG
            if !isInTests {
                syncManager.configure(with: modelContainer)
            } else {
                print("🧪 App: Skipping SyncManager configuration in test environment")
            }
            #else
            syncManager.configure(with: modelContainer)
            #endif

        } catch {
            // This is a fatal error in a shipping app.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(appSettings)
                    .environment(syncManager)
                    .environment(NavigationRouter.shared)
                    .opacity(showSplash ? 0 : 1) // Hide content while splash is showing
                
//                if showSplash {
//                    SplashView(isVisible: $showSplash)
//                        .transition(.opacity)
//                        .onTapGesture {
//                            showSplash = false
//                        }
//                }
            }
//            .onAppear {
//                // Only show splash on first launch
//                if !hasShownSplashOnce {
//                    hasShownSplashOnce = true
//                } else {
//                    showSplash = false
//                }
//            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // Only reset authentication when app goes to background (not inactive)
                    BiometricAuthManager.shared.resetSession()
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
