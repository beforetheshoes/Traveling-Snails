//
//  iCloudStorageService.swift
//  Traveling Snails
//
//

import Foundation

/// Production implementation of CloudStorageService using NSUbiquitousKeyValueStore
/// NSUbiquitousKeyValueStore is thread-safe, so this service is naturally Sendable
final class iCloudStorageService: CloudStorageService, Sendable {
    // MARK: - Properties

    // NSUbiquitousKeyValueStore is not marked as Sendable but is documented as thread-safe
    // nonisolated(unsafe) is appropriate here because NSUbiquitousKeyValueStore is immutable after initialization
    // and all its methods are thread-safe according to Apple documentation
    nonisolated(unsafe) private let store: NSUbiquitousKeyValueStore

    // MARK: - Initialization

    init() {
        self.store = NSUbiquitousKeyValueStore.default
        setupNotifications()
    }

    // MARK: - CloudStorageService Implementation

    func setString(_ value: String, forKey key: String) {
        store.set(value, forKey: key)
    }

    func getString(forKey key: String) -> String? {
        store.string(forKey: key)
    }

    func setInteger(_ value: Int, forKey key: String) {
        store.set(value, forKey: key)
    }

    func getInteger(forKey key: String) -> Int {
        Int(store.longLong(forKey: key))
    }

    func setBoolean(_ value: Bool, forKey key: String) {
        store.set(value, forKey: key)
    }

    func getBoolean(forKey key: String) -> Bool {
        store.bool(forKey: key)
    }

    func setDouble(_ value: Double, forKey key: String) {
        store.set(value, forKey: key)
    }

    func getDouble(forKey key: String) -> Double {
        store.double(forKey: key)
    }

    func removeValue(forKey key: String) {
        store.removeObject(forKey: key)
    }

    @discardableResult
    func synchronize() -> Bool {
        store.synchronize()
    }

    var isAvailable: Bool {
        // Check if iCloud account is available
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )

        // Initial synchronization
        store.synchronize()
    }

    @objc private func iCloudChanged(_ notification: Notification) {
        Logger.shared.debug("iCloud storage changed notification received")

        guard let userInfo = notification.userInfo else { return }

        // Extract changed keys and reason
        var notificationUserInfo: [String: Any] = [:]

        if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            notificationUserInfo[CloudStorageNotificationKey.changedKeys] = changedKeys
        }

        if let reasonNumber = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber {
            let reason: CloudStorageChangeReason
            switch reasonNumber.intValue {
            case NSUbiquitousKeyValueStoreServerChange:
                reason = .serverChange
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                reason = .initialSyncChange
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                reason = .quotaViolationChange
            case NSUbiquitousKeyValueStoreAccountChange:
                reason = .accountChange
            default:
                reason = .serverChange
            }
            notificationUserInfo[CloudStorageNotificationKey.reasonForChange] = reason
        }

        // Post our abstracted notification
        NotificationCenter.default.post(
            name: .cloudStorageDidChangeExternally,
            object: self,
            userInfo: notificationUserInfo
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
