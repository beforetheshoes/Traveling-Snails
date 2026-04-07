//
//  MacCloudSharingView.swift
//  Traveling Snails
//

#if os(macOS)
import AppKit
import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct MacCloudSharingView: NSViewRepresentable {
    let sharedRecord: SharedRecord
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.presentSharingService(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sharedRecord: sharedRecord,
            onDismiss: onDismiss
        )
    }

    final class Coordinator: NSObject, NSCloudSharingServiceDelegate {
        let sharedRecord: SharedRecord
        let onDismiss: () -> Void

        init(
            sharedRecord: SharedRecord,
            onDismiss: @escaping () -> Void
        ) {
            self.sharedRecord = sharedRecord
            self.onDismiss = onDismiss
        }

        func presentSharingService(from view: NSView) {
            guard let service = NSSharingService(named: .cloudSharing) else {
                onDismiss()
                return
            }
            service.delegate = self

            let itemProvider = NSItemProvider()
            itemProvider.registerCloudKitShare(
                sharedRecord.share,
                container: CKContainer.default()
            )

            service.perform(withItems: [itemProvider])
        }

        // MARK: - NSCloudSharingServiceDelegate

        func sharingService(
            _ sharingService: NSSharingService,
            didCompleteForItems items: [Any],
            error: (any Error)?
        ) {
            onDismiss()
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didSave share: CKShare
        ) {
            // Share was saved successfully
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didStopSharing share: CKShare
        ) {
            // The SyncEngine will handle share cleanup on the next sync cycle
            onDismiss()
        }

        func options(
            for cloudKitSharingService: NSSharingService,
            share provider: NSItemProvider
        ) -> NSSharingService.CloudKitOptions {
            return [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        }
    }
}
#endif
