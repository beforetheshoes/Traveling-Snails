import ComposableArchitecture
import Foundation

@Reducer
struct OrganizationPickerFeature {
    @ObservableState
    struct State: Equatable {
        var selectedOrganizationID: Organization.ID?
        var searchText = ""
        @Presents var addOrganization: AddOrganizationFeature.State?
        var shouldDismiss = false

        init(selectedOrganizationID: Organization.ID? = nil) {
            self.selectedOrganizationID = selectedOrganizationID
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case organizationTapped(Organization.ID)
        case doneTapped
        case addNewTapped
        case addOrganization(PresentationAction<AddOrganizationFeature.Action>)
        case dismissHandled
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .organizationTapped(let organizationID):
                state.selectedOrganizationID = organizationID
                state.shouldDismiss = true
                return .none

            case .doneTapped:
                guard state.selectedOrganizationID != nil else { return .none }
                state.shouldDismiss = true
                return .none

            case .addNewTapped:
                state.addOrganization = AddOrganizationFeature.State(
                    prefilledName: state.searchText.isEmpty ? nil : state.searchText
                )
                return .none

            case .addOrganization(.presented(.delegate(.organizationCreated(let organizationID)))):
                state.selectedOrganizationID = organizationID
                state.addOrganization = nil
                state.shouldDismiss = true
                return .none

            case .addOrganization(.dismiss):
                state.addOrganization = nil
                return .none

            case .addOrganization:
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
        .ifLet(\.$addOrganization, action: \.addOrganization) {
            AddOrganizationFeature()
        }
    }
}
