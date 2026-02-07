import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct TripDetailFeature {
    enum ViewMode: String, CaseIterable, Equatable {
        case list = "List"
        case calendar = "Calendar"

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .calendar: return "calendar"
            }
        }
    }

    enum ActiveSheet: String, Identifiable, Equatable {
        case addActivity
        case addLodging
        case addTransportation
        case editTrip
        case shareTrip

        var id: String { rawValue }
    }

    @ObservableState
    struct State: Equatable {
        let trip: Trip
        var path: [TripRoute]
        var resetToken: Int
        var lastHandledResetToken: Int

        var viewMode: ViewMode = .list
        var activeSheet: ActiveSheet?
        var showingCalendarView = false
        var showingRemoveProtectionConfirmation = false

        var isLocallyAuthenticated = false
        var isAuthenticating = false
        var canUseBiometrics = false
        var biometricAuthEnabled = false
        var isTripProtected = false
        var isFaceID = false

        var needsAuthentication: Bool {
            isTripProtected && !isLocallyAuthenticated
        }

        var biometricDisplayName: String {
            isFaceID ? "Face ID" : "Touch ID"
        }

        init(trip: Trip, initialPath: [TripRoute], resetToken: Int) {
            self.trip = trip
            self.path = initialPath
            self.resetToken = resetToken
            self.lastHandledResetToken = resetToken
        }
    }

    enum Action: Equatable {
        case onAppear
        case externalPathChanged([TripRoute])
        case resetTokenChanged(Int)
        case viewModeChanged(ViewMode)
        case activeSheetChanged(ActiveSheet?)
        case calendarPresentationChanged(Bool)
        case removeProtectionDialogChanged(Bool)

        case addActivityTapped
        case addLodgingTapped
        case addTransportationTapped
        case editTripTapped
        case shareTripTapped
        case fullCalendarTapped

        case activitySelected(TripRoute)

        case authenticateTapped
        case authenticationResponse(Bool)
        case lockTripTapped
        case protectTapped
        case removeProtectionConfirmed
        case refreshAuthState
        case authStateLoaded(
            canUseBiometrics: Bool,
            biometricAuthEnabled: Bool,
            isTripProtected: Bool,
            isLocallyAuthenticated: Bool,
            isFaceID: Bool
        )
    }

    @Dependency(\.biometricAuthClient) private var biometricAuthClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshAuthState)

            case .externalPathChanged(let newPath):
                if state.path != newPath {
                    state.path = newPath
                }
                return .none

            case .resetTokenChanged(let newToken):
                state.resetToken = newToken
                guard newToken != state.lastHandledResetToken else { return .none }
                state.lastHandledResetToken = newToken
                state.path = []
                return .none

            case .viewModeChanged(let mode):
                state.viewMode = mode
                return .none

            case .activeSheetChanged(let activeSheet):
                state.activeSheet = activeSheet
                return .none

            case .calendarPresentationChanged(let isPresented):
                state.showingCalendarView = isPresented
                return .none

            case .removeProtectionDialogChanged(let isPresented):
                state.showingRemoveProtectionConfirmation = isPresented
                return .none

            case .addActivityTapped:
                state.activeSheet = .addActivity
                return .none

            case .addLodgingTapped:
                state.activeSheet = .addLodging
                return .none

            case .addTransportationTapped:
                state.activeSheet = .addTransportation
                return .none

            case .editTripTapped:
                state.activeSheet = .editTrip
                return .none

            case .shareTripTapped:
                state.activeSheet = .shareTrip
                return .none

            case .fullCalendarTapped:
                state.showingCalendarView = true
                return .none

            case .activitySelected(let route):
                state.path.append(route)
                return .none

            case .authenticateTapped:
                guard !state.isAuthenticating else { return .none }
                state.isAuthenticating = true
                let trip = state.trip
                return .run { send in
                    let success = await biometricAuthClient.authenticateTrip(trip)
                    await send(.authenticationResponse(success))
                }

            case .authenticationResponse(let success):
                state.isAuthenticating = false
                if success {
                    state.isLocallyAuthenticated = true
                }
                return .send(.refreshAuthState)

            case .lockTripTapped:
                let trip = state.trip
                return .run { send in
                    await biometricAuthClient.lockTrip(trip)
                    await send(.refreshAuthState)
                }

            case .protectTapped:
                if state.isTripProtected {
                    state.showingRemoveProtectionConfirmation = true
                    return .none
                }

                let trip = state.trip
                return .run { send in
                    await biometricAuthClient.toggleProtection(trip)
                    await send(.refreshAuthState)
                }

            case .removeProtectionConfirmed:
                state.showingRemoveProtectionConfirmation = false
                let trip = state.trip
                return .run { send in
                    await biometricAuthClient.toggleProtection(trip)
                    await send(.refreshAuthState)
                }

            case .refreshAuthState:
                let trip = state.trip
                return .run { send in
                    let canUseBiometrics = await biometricAuthClient.canUseBiometrics()
                    let isEnabled = await biometricAuthClient.isEnabled()
                    let biometricType = await biometricAuthClient.biometricType()
                    let isTripProtected = await biometricAuthClient.isProtected(trip)
                    let isAuthenticated = await biometricAuthClient.isAuthenticated(trip)

                    await send(
                        .authStateLoaded(
                            canUseBiometrics: canUseBiometrics,
                            biometricAuthEnabled: isEnabled,
                            isTripProtected: isTripProtected,
                            isLocallyAuthenticated: isAuthenticated,
                            isFaceID: biometricType == .faceID
                        )
                    )
                }

            case .authStateLoaded(
                let canUseBiometrics,
                let biometricAuthEnabled,
                let isTripProtected,
                let isLocallyAuthenticated,
                let isFaceID
            ):
                state.canUseBiometrics = canUseBiometrics
                state.biometricAuthEnabled = biometricAuthEnabled
                state.isTripProtected = isTripProtected
                state.isLocallyAuthenticated = isLocallyAuthenticated
                state.isFaceID = isFaceID
                return .none
            }
        }
    }
}
