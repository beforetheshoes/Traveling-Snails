import ComposableArchitecture
import SQLiteData

@Reducer
struct CrossDeviceEditFileAttachmentFeature {
    @ObservableState
    struct State: Equatable {
        let attachment: EmbeddedFileAttachment
        var editedDescription = ""
        var isSaving = false
        var saveError: String?
        var shouldDismiss = false

        init(attachment: EmbeddedFileAttachment) {
            self.attachment = attachment
            self.editedDescription = attachment.fileDescription
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
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

            case .saveTapped:
                state.isSaving = true
                state.saveError = nil
                var updatedAttachment = state.attachment
                updatedAttachment.fileDescription = state.editedDescription
                let attachmentToSave = updatedAttachment
                return .run { send in
                    do {
                        try await database.write { db in
                            try EmbeddedFileAttachment.upsert { attachmentToSave }.execute(db)
                        }
                        await send(.saveSucceeded)
                    } catch {
                        Logger.shared.error("Failed to save file attachment: \(error.localizedDescription)", category: .fileAttachment)
                        await send(.saveFailed(L(L10n.Save.attachmentFailed)))
                    }
                }

            case .saveSucceeded:
                state.isSaving = false
                state.shouldDismiss = true
                return .none

            case .saveFailed(let message):
                state.isSaving = false
                state.saveError = message
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            }
        }
    }
}
