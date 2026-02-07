import ComposableArchitecture
import Foundation

@Reducer
struct OrganizationPickerFeature {
    @ObservableState
    struct State: Equatable {
        var selectedOrganizationID: Organization.ID?
        var searchText = ""
        var showingAddOrganization = false
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
        case addSheetChanged(Bool)
        case organizationCreated(Organization.ID)
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
                state.showingAddOrganization = true
                return .none

            case .addSheetChanged(let isPresented):
                state.showingAddOrganization = isPresented
                return .none

            case .organizationCreated(let organizationID):
                state.selectedOrganizationID = organizationID
                state.showingAddOrganization = false
                state.shouldDismiss = true
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
    }
}
