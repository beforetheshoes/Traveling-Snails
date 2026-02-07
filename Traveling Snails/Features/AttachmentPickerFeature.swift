import ComposableArchitecture

@Reducer
struct AttachmentPickerFeature {
    @ObservableState
    struct State: Equatable {
        var isProcessing = false
        var showingDocumentPicker = false
        var showingPhotosPicker = false
        var showingPermissionAlert = false
    }

    @CasePathable
    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case photoButtonTapped
        case photoPickerPresented(Bool)
        case documentPickerPresented(Bool)
        case processingChanged(Bool)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .photoButtonTapped:
                state.showingPhotosPicker = true
                return .none
            case .photoPickerPresented(let isPresented):
                state.showingPhotosPicker = isPresented
                return .none
            case .documentPickerPresented(let isPresented):
                state.showingDocumentPicker = isPresented
                return .none
            case .processingChanged(let isProcessing):
                state.isProcessing = isProcessing
                return .none
            }
        }
    }
}
