import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct PrefilledAddActivityFeature {
    enum ActivityKind: Equatable {
        case lodging
        case transportation
        case activity
    }

    @ObservableState
    struct State {
        let trip: Trip
        let activityKind: ActivityKind
        var editData: TripActivityEditData
        @Presents var organizationPicker: OrganizationPickerFeature.State?
        var isSaving = false
        var shouldDismiss = false
        var errorMessage: String?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case ensureNoneOrganizationSucceeded(Organization)
        case showOrganizationPicker
        case organizationPicker(PresentationAction<OrganizationPickerFeature.Action>)
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
        case dismissHandled
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .showOrganizationPicker:
                state.organizationPicker = OrganizationPickerFeature.State(
                    selectedOrganizationID: state.editData.organization?.id
                )
                return .none

            case .organizationPicker(.dismiss):
                state.organizationPicker = nil
                return .none

            case .organizationPicker:
                return .none

            case .onAppear:
                guard state.editData.organization == nil else { return .none }
                return .run { send in
                    do {
                        let organization = try await database.write { db in
                            if let existing = try Organization.where({ $0.name.eq("None") }).fetchOne(db) {
                                return existing
                            }
                            let noneOrg = Organization(name: "None")
                            try Organization.insert { noneOrg }.execute(db)
                            return noneOrg
                        }
                        await send(.ensureNoneOrganizationSucceeded(organization))
                    } catch {
                        Logger.shared.error("Failed to ensure None organization: \(error.localizedDescription)", category: .database)
                    }
                }

            case .ensureNoneOrganizationSucceeded(let organization):
                state.editData.organization = organization
                return .none

            case .saveTapped:
                guard !state.isSaving, let organization = state.editData.organization else { return .none }
                state.isSaving = true
                state.errorMessage = nil
                let editData = state.editData
                let trip = state.trip
                let activityKind = state.activityKind
                return .run { send in
                    do {
                        try await database.write { db in
                            switch activityKind {
                            case .lodging:
                                let lodging = Lodging(
                                    name: editData.name,
                                    start: editData.start,
                                    checkInTZ: TimeZone(identifier: editData.startTZId),
                                    end: editData.end,
                                    checkOutTZ: TimeZone(identifier: editData.endTZId),
                                    cost: editData.cost,
                                    paid: editData.paid,
                                    reservation: editData.confirmationField,
                                    notes: editData.notes,
                                    trip: trip,
                                    organization: organization
                                )
                                try Lodging.upsert { lodging }.execute(db)

                            case .transportation:
                                let transportation = Transportation(
                                    name: editData.name,
                                    type: editData.transportationType ?? .plane,
                                    start: editData.start,
                                    startTZ: TimeZone(identifier: editData.startTZId),
                                    end: editData.end,
                                    endTZ: TimeZone(identifier: editData.endTZId),
                                    cost: editData.cost,
                                    paid: editData.paid,
                                    confirmation: editData.confirmationField,
                                    notes: editData.notes,
                                    trip: trip,
                                    organization: organization
                                )
                                try Transportation.upsert { transportation }.execute(db)
                                try TransportationLeg.where { $0.transportationID.eq(transportation.id) }.delete().execute(db)
                                try TransportationLeg.insert { TransportationLeg.makeDefaultLeg(for: transportation) }.execute(db)

                            case .activity:
                                let activity = Activity(
                                    name: editData.name,
                                    start: editData.start,
                                    startTZ: TimeZone(identifier: editData.startTZId),
                                    end: editData.end,
                                    endTZ: TimeZone(identifier: editData.endTZId),
                                    cost: editData.cost,
                                    paid: editData.paid,
                                    reservation: editData.confirmationField,
                                    notes: editData.notes,
                                    trip: trip,
                                    organization: organization
                                )
                                try Activity.upsert { activity }.execute(db)
                            }
                        }
                        await send(.saveSucceeded)
                    } catch {
                        Logger.shared.error("Failed to save prefilled activity: \(error.localizedDescription)", category: .database)
                        await send(.saveFailed("Failed to save \(editData.name.isEmpty ? "activity" : editData.name)."))
                    }
                }

            case .saveSucceeded:
                state.isSaving = false
                state.shouldDismiss = true
                return .none

            case .saveFailed(let message):
                state.isSaving = false
                state.errorMessage = message
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
        .ifLet(\.$organizationPicker, action: \.organizationPicker) {
            OrganizationPickerFeature()
        }
    }
}
