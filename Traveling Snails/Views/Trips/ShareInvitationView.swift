import ComposableArchitecture
@preconcurrency import CloudKit
import SwiftUI

/// View for handling CloudKit share invitation acceptance
struct ShareInvitationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<ShareInvitationFeature>

    init(
        shareMetadata: CKShare.Metadata,
        store: StoreOf<ShareInvitationFeature>? = nil
    ) {
        let resolvedStore = store ?? Store(
            initialState: ShareInvitationFeature.State(shareMetadata: shareMetadata)
        ) {
            ShareInvitationFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("Trip Invitation")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let shareTitle = store.shareTitle {
                        Text("You've been invited to collaborate on:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(shareTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("You've been invited to collaborate on a trip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()

                Spacer()

                VStack(spacing: 12) {
                    if let ownerName = store.ownerName {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundStyle(.blue)
                            Text("Shared by: \(ownerName)")
                                .font(.subheadline)
                            Spacer()
                        }
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.green)
                        Text("Real-time collaboration")
                            .font(.subheadline)
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "icloud")
                            .foregroundStyle(.blue)
                        Text("Syncs across all devices")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        store.send(.acceptTapped)
                    } label: {
                        HStack {
                            if store.isAcceptingShare {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text("Accept Invitation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isAcceptingShare)

                    Button {
                        dismiss()
                    } label: {
                        Text("Decline")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isAcceptingShare)
                }
                .padding()

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: store.didAccept) { _, accepted in
            if accepted {
                dismiss()
            }
        }
    }
}

#Preview {
    Text("ShareInvitationView Preview")
        .navigationTitle("Share Invitation")
}
