import ComposableArchitecture
import SQLiteData

@Reducer
struct EmbeddedFileAttachmentListFeature {
    @ObservableState
    struct State: Equatable {
        var errorMessage: String?
        var isProcessing = false
    }

    enum Action: Equatable {
        case removeAttachmentTapped(EmbeddedFileAttachment)
        case removeAttachmentSucceeded
        case removeAttachmentFailed(String)
        case showError(String)
        case clearError
    }

    private enum CancelID {
        case errorDismiss
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.continuousClock) private var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .removeAttachmentTapped(let attachment):
                state.isProcessing = true
                return .run { send in
                    do {
                        try await database.write { db in
                            try EmbeddedFileAttachment.find(attachment.id).delete().execute(db)
                        }
                        await send(.removeAttachmentSucceeded)
                    } catch {
                        Logger.shared.error("Failed to remove attachment: \(error.localizedDescription)", category: .fileAttachment)
                        await send(.removeAttachmentFailed(L(L10n.Delete.attachmentFailed)))
                    }
                }

            case .removeAttachmentSucceeded:
                state.isProcessing = false
                return .none

            case .removeAttachmentFailed(let message):
                state.isProcessing = false
                state.errorMessage = message
                return .run { send in
                    do {
                        try await clock.sleep(for: .seconds(5))
                    } catch {
                        return
                    }
                    await send(.clearError)
                }
                .cancellable(id: CancelID.errorDismiss, cancelInFlight: true)

            case .showError(let message):
                state.errorMessage = message
                return .run { send in
                    do {
                        try await clock.sleep(for: .seconds(5))
                    } catch {
                        return
                    }
                    await send(.clearError)
                }
                .cancellable(id: CancelID.errorDismiss, cancelInFlight: true)

            case .clearError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
