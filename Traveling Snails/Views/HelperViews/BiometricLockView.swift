import SwiftUI

struct BiometricLockView: View {
    let trip: Trip
    @Binding var isAuthenticating: Bool
    let onAuthenticationSuccess: () -> Void
    @Environment(ModernBiometricAuthManager.self) private var authManager

    init(trip: Trip, isAuthenticating: Binding<Bool>, onAuthenticationSuccess: @escaping () -> Void = {}) {
        self.trip = trip
        self._isAuthenticating = isAuthenticating
        self.onAuthenticationSuccess = onAuthenticationSuccess
        #if DEBUG
        Logger.secure(category: .app).debug("BiometricLockView.init() for trip")
        #endif
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Biometric icon
            Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("This trip is protected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Authenticate to view trip details")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Authentication button
            Button {
                authenticateUser()
            } label: {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                    }

                    Text("Authenticate with \(authManager.biometricType == .faceID ? "Face ID" : "Touch ID")")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func authenticateUser() {
        #if DEBUG
        Logger.secure(category: .app).debug("BiometricLockView.authenticateUser() - START, isAuthenticating: \(isAuthenticating, privacy: .public)")
        #endif

        guard !isAuthenticating else {
            #if DEBUG
            Logger.secure(category: .app).debug("Already authenticating, returning early")
            #endif
            return
        }

        #if DEBUG
        Logger.secure(category: .app).debug("Setting isAuthenticating = true")
        #endif
        isAuthenticating = true

        Task {
            // Add slight delay for better UX
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            #if DEBUG
            Logger.secure(category: .app).debug("Calling authManager.authenticateTrip()")
            #endif
            let success = await authManager.authenticateTrip(trip)
            #if DEBUG
            Logger.secure(category: .app).debug("Authentication result: \(success, privacy: .public)")
            #endif

            await MainActor.run {
                // Only update isAuthenticating if authentication failed
                // If successful, the view will automatically switch due to @Observable
                if !success {
                    #if DEBUG
                    Logger.secure(category: .app).debug("Authentication failed, setting isAuthenticating = false")
                    #endif
                    isAuthenticating = false
                } else {
                    #if DEBUG
                    Logger.secure(category: .app).debug("Authentication successful, allowing transition")
                    #endif
                    isAuthenticating = false
                    onAuthenticationSuccess()
                }
            }

            #if DEBUG
            Logger.secure(category: .app).debug("BiometricLockView.authenticateUser() - END")
            #endif
        }
    }
}
