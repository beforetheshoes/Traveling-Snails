import ComposableArchitecture
import SwiftUI
import SQLiteData

/// Comprehensive view for managing CloudKit trip sharing
struct TripSharingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<TripSharingFeature>

    init(
        trip: Trip,
        store: StoreOf<TripSharingFeature>? = nil
    ) {
        let resolvedStore = store ?? Store(
            initialState: TripSharingFeature.State(trip: trip)
        ) {
            TripSharingFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    var body: some View {
        NavigationStack {
            List {
                if let sharingInfo = store.sharingInfo {
                    if sharingInfo.isShared {
                        sharedTripSection(sharingInfo)
                    } else {
                        notSharedSection
                    }
                } else if store.isLoadingSharingInfo {
                    loadingSection
                } else {
                    notSharedSection
                }

                if let errorMessage = store.errorMessage {
                    errorSection(errorMessage)
                }
            }
            .navigationTitle("Share Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                store.send(.onAppear)
            }
            .sheet(item: Binding(
                get: { store.activeShareSheet },
                set: { _ in store.send(.shareSheetDismissed) }
            )) { payload in
                TripShareSheet(
                    activityItems: payload.url.map { [$0] } ?? payload.activityItems
                )
            }
        }
    }

    @ViewBuilder
    private var notSharedSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Share this trip")
                    .font(.headline)

                Text("Invite others to view and collaborate on this trip. Shared trips sync across all participant devices.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    store.send(.createShareTapped)
                } label: {
                    HStack {
                        if store.isCreatingShare {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Create Share Link")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isCreatingShare || store.trip.isProtected)
            }
            .padding()
        } header: {
            Text("Trip Sharing")
        } footer: {
            if store.trip.isProtected {
                Text("Protected trips cannot be shared. Remove protection to enable sharing.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func sharedTripSection(_ info: TripSharingSnapshot) -> some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    let inviteeCount = max(0, info.participants.filter { !$0.isOwner }.count)
                    if inviteeCount == 0 {
                        Text("Share link created")
                            .font(.headline)
                        Text("Ready to invite others")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Trip is shared")
                            .font(.headline)
                        Text("\(inviteeCount) invitee\(inviteeCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                let inviteeCount = max(0, info.participants.filter { !$0.isOwner }.count)
                Image(systemName: inviteeCount == 0 ? "link.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(inviteeCount == 0 ? .orange : .green)
            }

            if let shareURL = info.shareURL {
                Button {
                    store.send(.shareURLTapped(shareURL))
                } label: {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        Text("Share link not available")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") {
                            store.send(.refreshTapped)
                        }
                        .font(.caption)
                    }

                    Text("Share link unavailable. CloudKit sharing requires a physical device and may not work in development builds.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()

                    Button {
                        store.send(.shareTextTapped)
                    } label: {
                        Label("Share Trip Details", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(.blue)
                    .font(.caption)
                }
            }

            if info.shareURL != nil {
                Button {
                    // Future: Open invite interface
                } label: {
                    Label("Invite Others", systemImage: "person.badge.plus")
                }
                .foregroundStyle(.blue)
            }

            Button(role: .destructive) {
                store.send(.removeShareTapped)
            } label: {
                HStack {
                    if store.isRemovingShare {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Stop Sharing")
                }
            }
            .disabled(store.isRemovingShare)
        } header: {
            Text("Share Status")
        }

        if !info.participants.isEmpty {
            Section("Participants") {
                ForEach(info.participants) { participant in
                    HStack {
                        Image(systemName: participant.isOwner ? "person.crop.circle.fill" : "person.circle")
                            .foregroundStyle(participant.isOwner ? .blue : .secondary)

                        VStack(alignment: .leading) {
                            Text(participant.displayName)
                                .font(.subheadline)
                                .fontWeight(participant.isOwner ? .medium : .regular)

                            Text(participant.permissionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if participant.isOwner {
                            Text("Owner")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .clipShape(.rect(cornerRadius: 4))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading sharing information...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        }
    }

    @ViewBuilder
    private func errorSection(_ message: String) -> some View {
        Section {
            Label {
                Text(message)
                    .foregroundStyle(.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Error")
        }
    }
}

struct TripShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

#Preview {
    NavigationStack {
        TripSharingView(trip: Trip(name: "Sample Trip"))
    }
}
