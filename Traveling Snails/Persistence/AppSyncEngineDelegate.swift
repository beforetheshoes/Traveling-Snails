//
//  AppSyncEngineDelegate.swift
//  Traveling Snails
//

import CloudKit
import Foundation
import SQLiteData

@MainActor
@Observable
final class AppSyncEngineDelegate: SyncEngineDelegate {
    var lastError: String?
    var isSyncing = false

    func syncEngine(
        _ syncEngine: SQLiteData.SyncEngine,
        accountChanged changeType: CKSyncEngine.Event.AccountChange.ChangeType
    ) async {
        switch changeType {
        case .signOut, .switchAccounts:
            lastError = L(L10n.Errors.CloudKit.authenticationFailed)
        case .signIn:
            break
        @unknown default:
            break
        }
    }
}
