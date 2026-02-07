import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct FileAttachmentSettingsFeature {
    @ObservableState
    struct State: Equatable {
        var showingClearConfirmation = false
        var showingCleanupConfirmation = false
        var orphanedAttachmentIDs: [UUID] = []
        var isScanning = false
        var isCleaning = false
        var isClearing = false
        var showingAlert = false
        var alertTitle = "Success"
        var alertMessage = ""
    }

    enum Action: Equatable {
        case findOrphanedTapped([EmbeddedFileAttachment])
        case clearAllTapped
        case cleanupOrphanedTapped
        case clearDialogChanged(Bool)
        case cleanupDialogChanged(Bool)
        case clearAllConfirmed(ids: [UUID], totalCount: Int)
        case cleanupOrphanedConfirmed
        case scanCompleted([UUID])
        case cleanupCompleted(Int)
        case clearAllCompleted(Int)
        case operationFailed(String)
        case dismissAlert
    }

    private enum CancelID {
        case scan
        case cleanup
        case clear
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.continuousClock) private var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .findOrphanedTapped(let attachments):
                state.isScanning = true
                return .run { send in
                    do {
                        try await clock.sleep(for: .milliseconds(250))
                    } catch {
                        return
                    }
                    let orphanedIDs = attachments
                        .filter { $0.activityID == nil && $0.lodgingID == nil && $0.transportationID == nil }
                        .map(\.id)
                    await send(.scanCompleted(orphanedIDs))
                }
                .cancellable(id: CancelID.scan, cancelInFlight: true)

            case .clearAllTapped:
                state.showingClearConfirmation = true
                return .none

            case .cleanupOrphanedTapped:
                state.showingCleanupConfirmation = true
                return .none

            case .clearDialogChanged(let isPresented):
                state.showingClearConfirmation = isPresented
                return .none

            case .cleanupDialogChanged(let isPresented):
                state.showingCleanupConfirmation = isPresented
                return .none

            case .clearAllConfirmed(let ids, let totalCount):
                state.showingClearConfirmation = false
                state.isClearing = true
                return .run { send in
                    do {
                        try await clock.sleep(for: .milliseconds(500))
                    } catch {
                        return
                    }
                    do {
                        if !ids.isEmpty {
                            try await database.write { db in
                                try EmbeddedFileAttachment
                                    .where { $0.id.in(ids) }
                                    .delete()
                                    .execute(db)
                            }
                        }
                        await send(.clearAllCompleted(totalCount))
                    } catch {
                        await send(.operationFailed(L(L10n.Database.Operations.cleanupFailed)))
                    }
                }
                .cancellable(id: CancelID.clear, cancelInFlight: true)

            case .cleanupOrphanedConfirmed:
                state.showingCleanupConfirmation = false
                state.isCleaning = true
                let ids = state.orphanedAttachmentIDs
                return .run { send in
                    do {
                        try await clock.sleep(for: .milliseconds(500))
                    } catch {
                        return
                    }
                    do {
                        if !ids.isEmpty {
                            try await database.write { db in
                                try EmbeddedFileAttachment
                                    .where { $0.id.in(ids) }
                                    .delete()
                                    .execute(db)
                            }
                        }
                        await send(.cleanupCompleted(ids.count))
                    } catch {
                        await send(.operationFailed(L(L10n.Database.Operations.cleanupFailed)))
                    }
                }
                .cancellable(id: CancelID.cleanup, cancelInFlight: true)

            case .scanCompleted(let orphanedIDs):
                state.isScanning = false
                state.orphanedAttachmentIDs = orphanedIDs
                state.alertTitle = "Success"
                if orphanedIDs.isEmpty {
                    state.alertMessage = "Scan complete. No orphaned files found."
                } else {
                    let count = orphanedIDs.count
                    state.alertMessage = "Scan complete. Found \(count) orphaned file\(count == 1 ? "" : "s")."
                }
                state.showingAlert = true
                Logger.shared.info(
                    "Orphaned attachments scan completed: \(orphanedIDs.count) found",
                    category: .fileManagement
                )
                return .none

            case .cleanupCompleted(let count):
                state.isCleaning = false
                state.orphanedAttachmentIDs = []
                state.alertTitle = "Success"
                state.alertMessage = "Successfully cleaned up \(count) orphaned file\(count == 1 ? "" : "s")."
                state.showingAlert = true
                Logger.shared.info(
                    "Orphaned attachments cleanup completed: \(count) files removed",
                    category: .fileManagement
                )
                return .none

            case .clearAllCompleted(let count):
                state.isClearing = false
                state.orphanedAttachmentIDs = []
                state.alertTitle = "Success"
                state.alertMessage = "Successfully cleared all \(count) attachment\(count == 1 ? "" : "s")."
                state.showingAlert = true
                Logger.shared.info("All attachments cleared: \(count) files removed", category: .fileManagement)
                return .none

            case .operationFailed(let message):
                state.isScanning = false
                state.isCleaning = false
                state.isClearing = false
                state.alertTitle = "Error"
                state.alertMessage = message
                state.showingAlert = true
                Logger.shared.error("Attachment settings operation failed: \(message)", category: .fileManagement)
                return .none

            case .dismissAlert:
                state.showingAlert = false
                return .none
            }
        }
    }
}
