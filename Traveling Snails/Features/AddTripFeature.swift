import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct AddTripFeature {
    @ObservableState
    struct State: Equatable {
        var name = ""
        var notes = ""
        var startDate = Date()
        var endDate = Date().addingTimeInterval(7 * 24 * 3600)
        var hasStartDate = false
        var hasEndDate = false
        var isSaving = false
        var errorMessage: String?
        var shouldDismiss = false

        var isSaveDisabled: Bool {
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
        }
    }

    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case startDateChanged(Date)
        case endDateChanged(Date)
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
        case dismissError
        case dismissHandled
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
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
                guard !state.isSaveDisabled else { return .none }
                state.isSaving = true
                state.errorMessage = nil

                let name = state.name
                let notes = state.notes
                let hasStartDate = state.hasStartDate
                let hasEndDate = state.hasEndDate
                let startDate = state.startDate
                let endDate = state.endDate

                return .run { send in
                    do {
                        var trip = Trip(name: name, notes: notes)
                        if hasStartDate { trip.setStartDate(startDate) }
                        if hasEndDate { trip.setEndDate(endDate) }
                        let tripToSave = trip

                        try await database.write { db in
                            try Trip.upsert { tripToSave }.execute(db)
                        }

                        await send(.saveSucceeded)
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .saveSucceeded:
                state.isSaving = false
                state.shouldDismiss = true
                return .none

            case .saveFailed(let message):
                state.isSaving = false
                state.errorMessage = message
                Logger.shared.error("Failed to save trip: \(message)", category: .database)
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
    }
}
