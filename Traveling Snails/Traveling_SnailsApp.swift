import SwiftUI
import SwiftData

@main
struct Traveling_SnailsApp: App {
    @State private var showSplash = true
    @State private var hasShownSplashOnce = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1) // Hide content while splash is showing
                
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
                    // Only reset authentication when app goes to background (not inactive)
                    BiometricAuthManager.shared.resetSession()
                case .active, .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
        .modelContainer(
            for: [
                Trip.self,
                Lodging.self,
                Organization.self,
                Transportation.self,
                Activity.self,
                Address.self,
                EmbeddedFileAttachment.self,
                SyncedSettings.self  // Add SyncedSettings to sync biometric settings
            ]
        )
    }
}
