import SwiftUI

struct BiometricLockView: View {
    let trip: Trip
    @Binding var isAuthenticating: Bool
    let onAuthenticationSuccess: () -> Void
    private let biometricTypeProvider: () async -> BiometricType
    private let authenticateTrip: (Trip) async -> Bool
    @State private var isFaceID = false
    @State private var authenticationRequestID: UUID?

    init(
        trip: Trip,
        isAuthenticating: Binding<Bool>,
        onAuthenticationSuccess: @escaping () -> Void = {},
        biometricTypeProvider: @escaping () async -> BiometricType = BiometricLockView.defaultBiometricType,
        authenticateTrip: @escaping (Trip) async -> Bool = BiometricLockView.defaultAuthenticateTrip
    ) {
        self.trip = trip
        self._isAuthenticating = isAuthenticating
        self.onAuthenticationSuccess = onAuthenticationSuccess
        self.biometricTypeProvider = biometricTypeProvider
        self.authenticateTrip = authenticateTrip
        #if DEBUG
        Logger.secure(category: .app).debug("BiometricLockView.init() for trip")
        #endif
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isFaceID ? "faceid" : "touchid")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("This trip is protected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Authenticate to view trip details")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                requestAuthentication()
            } label: {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isFaceID ? "faceid" : "touchid")
                    }

                    Text("Authenticate with \(isFaceID ? "Face ID" : "Touch ID")")
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
        .inlineNavigationBarTitle()
        .task {
            let biometricType = await biometricTypeProvider()
            isFaceID = biometricType == .faceID
        }
        .task(id: authenticationRequestID) {
            await handleAuthenticationRequest()
        }
    }

    private func requestAuthentication() {
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
        authenticationRequestID = UUID()
    }

    @MainActor
    private func handleAuthenticationRequest() async {
        guard authenticationRequestID != nil else { return }

        // Add slight delay for better UX
        do {
            try await Task.sleep(nanoseconds: 100_000_000)
        } catch {
            isAuthenticating = false
            authenticationRequestID = nil
            return
        }

        #if DEBUG
        Logger.secure(category: .app).debug("Calling biometricAuthClient.authenticateTrip()")
        #endif
        let success = await authenticateTrip(trip)
        #if DEBUG
        Logger.secure(category: .app).debug("Authentication result: \(success, privacy: .public)")
        #endif

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

        authenticationRequestID = nil

        #if DEBUG
        Logger.secure(category: .app).debug("BiometricLockView.authenticateUser() - END")
        #endif
    }

    private static func defaultBiometricType() async -> BiometricType {
        await BiometricAuthClient.liveValue.biometricType()
    }

    private static func defaultAuthenticateTrip(_ trip: Trip) async -> Bool {
        await BiometricAuthClient.liveValue.authenticateTrip(trip)
    }
}
