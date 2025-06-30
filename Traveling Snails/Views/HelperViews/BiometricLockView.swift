import SwiftUI

struct BiometricLockView: View {
    let trip: Trip
    @Binding var isAuthenticating: Bool
    let onAuthenticationSuccess: () -> Void
    private let authManager = BiometricAuthManager.shared

    init(trip: Trip, isAuthenticating: Binding<Bool>, onAuthenticationSuccess: @escaping () -> Void = {}) {
        self.trip = trip
        self._isAuthenticating = isAuthenticating
        self.onAuthenticationSuccess = onAuthenticationSuccess
        #if DEBUG
        Logger.shared.debug("BiometricLockView.init() for trip", category: .app)
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
        Logger.shared.debug("BiometricLockView.authenticateUser() - START, isAuthenticating: \(isAuthenticating)", category: .app)
        #endif

        guard !isAuthenticating else {
            #if DEBUG
            Logger.shared.debug("Already authenticating, returning early", category: .app)
            #endif
            return
        }

        #if DEBUG
        Logger.shared.debug("Setting isAuthenticating = true", category: .app)
        #endif
        isAuthenticating = true

        Task {
            // Add slight delay for better UX
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            #if DEBUG
            Logger.shared.debug("Calling authManager.authenticateTrip()", category: .app)
            #endif
            let success = await authManager.authenticateTrip(trip)
            #if DEBUG
            Logger.shared.debug("Authentication result: \(success)", category: .app)
            #endif

            await MainActor.run {
                // Only update isAuthenticating if authentication failed
                // If successful, the view will automatically switch due to @Observable
                if !success {
                    #if DEBUG
                    Logger.shared.debug("Authentication failed, setting isAuthenticating = false", category: .app)
                    #endif
                    isAuthenticating = false
                } else {
                    #if DEBUG
                    Logger.shared.debug("Authentication successful, allowing transition", category: .app)
                    #endif
                    isAuthenticating = false
                    onAuthenticationSuccess()
                }
            }

            #if DEBUG
            Logger.shared.debug("BiometricLockView.authenticateUser() - END", category: .app)
            #endif
        }
    }
}
