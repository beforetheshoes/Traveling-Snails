import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct OrganizationFeature {
    @ObservableState
    struct State: Equatable {
        var organization: Organization

        var isEditing = false
        var editedName = ""
        var editedPhone = ""
        var editedEmail = ""
        var editedWebsite = ""
        var editedAddress: Address?
        var editedLogoURL = ""

        var showingSaveError = false
        var saveErrorMessage = ""
        var showDeleteConfirmation = false
        var shouldDismiss = false

        init(organization: Organization) {
            self.organization = organization
        }

        var relatedTrips: [Trip] {
            var trips = Set<Trip>()
            trips.formUnion(organization.transportation.compactMap { $0.trip })
            trips.formUnion(organization.lodging.compactMap { $0.trip })
            trips.formUnion(organization.activity.compactMap { $0.trip })
            return Array(trips)
        }

        var canDeleteOrganization: Bool {
            guard !organization.isNone else { return false }
            return organization.transportation.isEmpty &&
                organization.lodging.isEmpty &&
                organization.activity.isEmpty
        }

        var deleteButtonTitle: String {
            if organization.isNone {
                return "Cannot Delete System Organization"
            }
            if !canDeleteOrganization {
                return "Cannot Delete - Has References"
            }
            return "Delete Organization"
        }

        var totalActivityCount: Int {
            organization.transportation.count + organization.lodging.count + organization.activity.count
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case organizationLoaded(Organization?)
        case startEditing
        case cancelEditing
        case saveTapped
        case saveSucceeded
        case saveFailed(String)
        case deleteTapped
        case deleteConfirmed
        case deleteSucceeded
        case deleteFailed(String)
        case dismissSaveError
        case dismissHandled
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                let organizationID = state.organization.id
                return .run { send in
                    let latestOrganization = try? await database.read { db in
                        try Organization.find(organizationID).fetchOne(db)
                    }
                    await send(.organizationLoaded(latestOrganization))
                }

            case .organizationLoaded(let organization):
                guard let organization else { return .none }
                state.organization = organization
                return .none

            case .startEditing:
                state.editedName = state.organization.name
                state.editedPhone = state.organization.phone
                state.editedEmail = state.organization.email
                state.editedWebsite = state.organization.website
                state.editedLogoURL = state.organization.logoURL
                state.editedAddress = (state.organization.address?.isEmpty == false) ? state.organization.address : nil
                state.isEditing = true
                return .none

            case .cancelEditing:
                state.isEditing = false
                state.editedName = ""
                state.editedPhone = ""
                state.editedEmail = ""
                state.editedWebsite = ""
                state.editedLogoURL = ""
                state.editedAddress = nil
                return .none

            case .saveTapped:
                if !state.organization.isNone && state.editedName.lowercased() == "none" {
                    state.saveErrorMessage = "Cannot rename organization to 'None' - this name is reserved for the system."
                    state.showingSaveError = true
                    return .none
                }

                if state.organization.isNone && state.editedName.lowercased() != "none" {
                    state.saveErrorMessage = "Cannot rename the system 'None' organization."
                    state.showingSaveError = true
                    return .none
                }

                let organization = state.organization
                let editedName = state.editedName
                let editedPhone = state.editedPhone
                let editedEmail = state.editedEmail
                let editedWebsite = state.editedWebsite
                let editedLogoURL = state.editedLogoURL
                let editedAddress = state.editedAddress

                return .run { send in
                    do {
                        try await database.write { db in
                            var updatedOrganization = organization
                            updatedOrganization.name = editedName
                            updatedOrganization.phone = editedPhone
                            updatedOrganization.email = editedEmail
                            updatedOrganization.website = editedWebsite
                            updatedOrganization.logoURL = editedLogoURL

                            if let newAddress = editedAddress, !newAddress.isEmpty {
                                let addressID = updatedOrganization.addressID ?? newAddress.id
                                let normalizedAddress = Address(
                                    id: addressID,
                                    street: newAddress.street,
                                    city: newAddress.city,
                                    state: newAddress.state,
                                    country: newAddress.country,
                                    postalCode: newAddress.postalCode,
                                    latitude: newAddress.latitude,
                                    longitude: newAddress.longitude,
                                    formattedAddress: newAddress.formattedAddress
                                )
                                try Address.upsert { normalizedAddress }.execute(db)
                                updatedOrganization.addressID = normalizedAddress.id
                            } else {
                                updatedOrganization.addressID = nil
                            }

                            try Organization.upsert { updatedOrganization }.execute(db)
                        }

                        await send(.saveSucceeded)
                    } catch {
                        await send(.saveFailed(L(L10n.Save.organizationFailed)))
                    }
                }

            case .saveSucceeded:
                state.isEditing = false
                return .send(.onAppear)

            case .saveFailed(let message):
                state.showingSaveError = true
                state.saveErrorMessage = message
                return .none

            case .deleteTapped:
                if state.canDeleteOrganization {
                    state.showDeleteConfirmation = true
                    return .none
                }

                if state.organization.isNone {
                    state.saveErrorMessage = "Cannot delete the system 'None' organization."
                } else {
                    let transportCount = state.organization.transportation.count
                    let lodgingCount = state.organization.lodging.count
                    let activityCount = state.organization.activity.count
                    state.saveErrorMessage = "Cannot delete '\(state.organization.name)'. It's used by \(transportCount) transportation, \(lodgingCount) lodging, and \(activityCount) activity records."
                }
                state.showingSaveError = true
                return .none

            case .deleteConfirmed:
                state.showDeleteConfirmation = false
                let organizationID = state.organization.id
                return .run { send in
                    do {
                        try await database.write { db in
                            try Organization.find(organizationID).delete().execute(db)
                        }
                        await send(.deleteSucceeded)
                    } catch {
                        await send(.deleteFailed(L(L10n.Delete.organizationFailed)))
                    }
                }

            case .deleteSucceeded:
                state.shouldDismiss = true
                return .none

            case .deleteFailed(let message):
                state.saveErrorMessage = message
                state.showingSaveError = true
                return .none

            case .dismissSaveError:
                state.showingSaveError = false
                state.saveErrorMessage = ""
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
    }
}
