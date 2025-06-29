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
        print("🔒 BiometricLockView.init() for \(trip.name)")
    }

    var body: some View {
        // print("🔒 BiometricLockView.body for \(trip.name) - isAuthenticating: \(isAuthenticating)")
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
        print("🔓 BiometricLockView.authenticateUser() for \(trip.name) - START")
        print("   - isAuthenticating: \(isAuthenticating)")

        guard !isAuthenticating else {
            print("   - Already authenticating, returning early")
            return
        }

        print("   - Setting isAuthenticating = true")
        isAuthenticating = true

        Task {
            // Add slight delay for better UX
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            print("   - Calling authManager.authenticateTrip()")
            let success = await authManager.authenticateTrip(trip)
            print("   - Authentication result: \(success)")

            await MainActor.run {
                // Only update isAuthenticating if authentication failed
                // If successful, the view will automatically switch due to @Observable
                if !success {
                    print("   - Authentication failed, setting isAuthenticating = false")
                    isAuthenticating = false
                } else {
                    print("   - Authentication successful, allowing transition")
                    isAuthenticating = false
                    onAuthenticationSuccess()
                }
            }

            print("🔓 BiometricLockView.authenticateUser() for \(trip.name) - END")
        }
    }
}
