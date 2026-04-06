import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct AddOrganizationFeature {
    @ObservableState
    struct State: Equatable {
        let prefilledName: String?

        var name = ""
        var phone = ""
        var email = ""
        var website = ""
        var logoURL = ""
        var logoURLSecurityLevel: SecureURLHandler.URLSecurityLevel = .safe
        var selectedAddress: Address?

        var showBlockedURLAlert = false
        var showSuspiciousURLAlert = false
        var showSaveErrorAlert = false
        var errorMessage = ""

        var isSaving = false
        var shouldDismiss = false
        var createdOrganizationID: Organization.ID?

        init(prefilledName: String? = nil) {
            self.prefilledName = prefilledName
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case logoURLChanged(String)
        case saveTapped
        case saveConfirmedAfterWarning
        case saveSucceeded(Organization.ID)
        case saveFailed(String)
        case dismissBlockedURLAlert
        case dismissSuspiciousURLAlert
        case dismissSaveErrorAlert
        case dismissHandled
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case organizationCreated(Organization.ID)
        }
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                if let prefilledName = state.prefilledName, state.name.isEmpty {
                    state.name = prefilledName
                }
                return .none

            case .logoURLChanged(let newValue):
                let trimmedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                state.logoURLSecurityLevel = trimmedValue.isEmpty ? .safe : SecureURLHandler.evaluateURL(trimmedValue)
                return .none

            case .saveTapped:
                let trimmedLogoURL = state.logoURL.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmedLogoURL.isEmpty {
                    return performSave(state: &state)
                }

                let level = SecureURLHandler.evaluateURL(trimmedLogoURL)
                switch level {
                case .blocked:
                    state.errorMessage = SecureURLHandler.alertMessage(for: .blocked, action: .cache, url: trimmedLogoURL)
                    state.showBlockedURLAlert = true
                    return .none
                case .suspicious:
                    state.errorMessage = SecureURLHandler.alertMessage(for: .suspicious, action: .cache, url: trimmedLogoURL)
                    state.showSuspiciousURLAlert = true
                    return .none
                case .safe:
                    return performSave(state: &state)
                }

            case .saveConfirmedAfterWarning:
                state.showSuspiciousURLAlert = false
                return performSave(state: &state)

            case .saveSucceeded(let organizationID):
                state.isSaving = false
                state.createdOrganizationID = organizationID
                state.shouldDismiss = true
                return .send(.delegate(.organizationCreated(organizationID)))

            case .delegate:
                return .none

            case .saveFailed(let message):
                state.isSaving = false
                state.errorMessage = message
                state.showSaveErrorAlert = true
                return .none

            case .dismissBlockedURLAlert:
                state.showBlockedURLAlert = false
                return .none

            case .dismissSuspiciousURLAlert:
                state.showSuspiciousURLAlert = false
                return .none

            case .dismissSaveErrorAlert:
                state.showSaveErrorAlert = false
                state.errorMessage = ""
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
    }

    private func performSave(state: inout State) -> Effect<Action> {
        state.isSaving = true

        let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = state.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let website = state.website.trimmingCharacters(in: .whitespacesAndNewlines)
        let logoURL = state.logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedAddress = state.selectedAddress

        return .run { send in
            do {
                let organizationID = try await database.write { db in
                    var organization = Organization(
                        name: name,
                        phone: phone,
                        email: email,
                        website: website,
                        logoURL: logoURL
                    )

                    if let selectedAddress, !selectedAddress.isEmpty {
                        let normalizedAddress = Address(
                            id: selectedAddress.id,
                            street: selectedAddress.street,
                            city: selectedAddress.city,
                            state: selectedAddress.state,
                            country: selectedAddress.country,
                            postalCode: selectedAddress.postalCode,
                            latitude: selectedAddress.latitude,
                            longitude: selectedAddress.longitude,
                            formattedAddress: selectedAddress.formattedAddress
                        )
                        try Address.upsert { normalizedAddress }.execute(db)
                        organization.addressID = normalizedAddress.id
                    }

                    try Organization.upsert { organization }.execute(db)
                    return organization.id
                }

                await send(.saveSucceeded(organizationID))
            } catch {
                Logger.shared.error("Failed to save organization: \(error.localizedDescription)", category: .database)
                await send(.saveFailed(L(L10n.Save.organizationFailed)))
            }
        }
    }
}
