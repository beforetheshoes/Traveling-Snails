import ComposableArchitecture

@Reducer
struct DatabaseBrowserFeature {
    @ObservableState
    struct State: Equatable {
        var selectedSection = 0
        var searchText = ""
        var selectedItemID: String?
    }

    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case selectItem(String?)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .selectItem(let id):
                state.selectedItemID = id
                return .none
            }
        }
    }
}
