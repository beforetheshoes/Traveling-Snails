import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct EditTripFeature {
    @ObservableState
    struct State: Equatable {
        let trip: Trip
        var name: String
        var notes: String
        var startDate: Date
        var endDate: Date
        var hasStartDate: Bool
        var hasEndDate: Bool

        var showDeleteConfirmation = false
        var showDateRangeWarning = false
        var dateRangeWarningMessage = ""

        var isSaving = false
        var isOffline = false
        var errorMessage: String?
        var showErrorAlert = false
        var shouldDismiss = false

        init(trip: Trip) {
            self.trip = trip
            self.name = trip.name
            self.notes = trip.notes
            self.hasStartDate = trip.hasStartDate
            self.startDate = trip.hasStartDate ? trip.startDate : Date()
            self.hasEndDate = trip.hasEndDate
            self.endDate = trip.hasEndDate ? trip.endDate : Date().addingTimeInterval(7 * 24 * 3600)
        }

        var saveDisabled: Bool {
            isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case syncStatusLoaded(isOffline: Bool)
        case startDateChanged(Date)
        case endDateChanged(Date)

        case saveTapped
        case confirmSaveDespiteDateConflict
        case saveSucceeded
        case saveFailed(String)

        case deleteTapped
        case deleteConfirmed
        case deleteSucceeded
        case deleteFailed(String)

        case dismissErrorAlert
        case dismissHandled
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.syncClient) private var syncClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let snapshot = await syncClient.status()
                    await send(.syncStatusLoaded(isOffline: snapshot.networkStatus == .offline))
                }

            case .syncStatusLoaded(let isOffline):
                state.isOffline = isOffline
                return .none

            case .binding:
                return .none

            case .startDateChanged(let newValue):
                guard state.hasEndDate, state.endDate <= newValue else { return .none }
                state.endDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                return .none

            case .endDateChanged(let newValue):
                guard state.hasStartDate, state.startDate >= newValue else { return .none }
                state.startDate = Calendar.current.date(byAdding: .day, value: -1, to: newValue) ?? newValue
                return .none

            case .saveTapped:
                guard !state.saveDisabled else { return .none }
                if let conflictMessage = state.trip.optimizedCheckDateConflicts(
                    hasStartDate: state.hasStartDate,
                    startDate: state.startDate,
                    hasEndDate: state.hasEndDate,
                    endDate: state.endDate
                ) {
                    state.dateRangeWarningMessage = conflictMessage
                    state.showDateRangeWarning = true
                    return .none
                }
                return saveTrip(&state)

            case .confirmSaveDespiteDateConflict:
                state.showDateRangeWarning = false
                return saveTrip(&state)

            case .saveSucceeded:
                state.isSaving = false
                state.shouldDismiss = true
                if !state.isOffline {
                    return .run { _ in
                        await syncClient.triggerSync()
                    }
                }
                return .none

            case .saveFailed(let message):
                state.isSaving = false
                state.errorMessage = message
                state.showErrorAlert = true
                return .none

            case .deleteTapped:
                state.showDeleteConfirmation = true
                return .none

            case .deleteConfirmed:
                state.showDeleteConfirmation = false
                state.isSaving = true
                let tripID = state.trip.id
                return .run { send in
                    do {
                        try await database.write { db in
                            try Trip.find(tripID).delete().execute(db)
                        }
                        await send(.deleteSucceeded)
                    } catch {
                        await send(.deleteFailed(error.localizedDescription))
                    }
                }

            case .deleteSucceeded:
                state.isSaving = false
                state.shouldDismiss = true
                return .run { _ in
                    await syncClient.triggerSync()
                }

            case .deleteFailed(let message):
                state.isSaving = false
                state.errorMessage = message
                state.showErrorAlert = true
                return .none

            case .dismissErrorAlert:
                state.showErrorAlert = false
                state.errorMessage = nil
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
    }

    private func saveTrip(_ state: inout State) -> Effect<Action> {
        state.isSaving = true
        state.errorMessage = nil

        let trip = state.trip
        let name = state.name
        let notes = state.notes
        let hasStartDate = state.hasStartDate
        let startDate = state.startDate
        let hasEndDate = state.hasEndDate
        let endDate = state.endDate

        return .run { send in
            do {
                var updatedTrip = trip
                updatedTrip.name = name
                updatedTrip.notes = notes

                if hasStartDate {
                    updatedTrip.setStartDate(startDate)
                } else {
                    updatedTrip.clearStartDate()
                }

                if hasEndDate {
                    updatedTrip.setEndDate(endDate)
                } else {
                    updatedTrip.clearEndDate()
                }

                let tripToSave = updatedTrip
                try await database.write { db in
                    try Trip.upsert { tripToSave }.execute(db)
                }

                await send(.saveSucceeded)
            } catch {
                await send(.saveFailed(error.localizedDescription))
            }
        }
    }
}
