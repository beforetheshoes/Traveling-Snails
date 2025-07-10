import SwiftUI
import CloudKit
import SwiftData

/// Comprehensive view for managing CloudKit trip sharing
struct TripSharingView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var sharingService: CKSyncEngineSharingService?
    @State private var sharingInfo: TripSharingInfo?
    @State private var isLoadingSharingInfo = false
    @State private var isCreatingShare = false
    @State private var isRemovingShare = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var shareURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                if let sharingInfo = sharingInfo {
                    if sharingInfo.isShared {
                        sharedTripSection(sharingInfo)
                    } else {
                        notSharedSection
                    }
                } else if isLoadingSharingInfo {
                    loadingSection
                } else {
                    notSharedSection
                }
                
                if let errorMessage = errorMessage {
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
                await initializeSharingService()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareURL = shareURL {
                    TripShareSheet(activityItems: [shareURL])
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var notSharedSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Share this trip")
                    .font(.headline)
                
                Text("Invite others to view and collaborate on this trip. Shared trips sync across all participant devices.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    Task {
                        await createShare()
                    }
                } label: {
                    HStack {
                        if isCreatingShare {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Create Share Link")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingShare || trip.isProtected)
            }
            .padding()
        } header: {
            Text("Trip Sharing")
        } footer: {
            if trip.isProtected {
                Text("Protected trips cannot be shared. Remove protection to enable sharing.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func sharedTripSection(_ info: TripSharingInfo) -> some View {
        Section {
            // Share status
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip is shared")
                        .font(.headline)
                    Text("\(info.participants.count) participant\(info.participants.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            // Share actions
            Button {
                if let shareURL = info.shareURL {
                    self.shareURL = shareURL
                    showingShareSheet = true
                }
            } label: {
                Label("Share Link", systemImage: "square.and.arrow.up")
            }
            .disabled(info.shareURL == nil)
            
            Button(role: .destructive) {
                Task {
                    await removeShare()
                }
            } label: {
                HStack {
                    if isRemovingShare {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Stop Sharing")
                }
            }
            .disabled(isRemovingShare)
        } header: {
            Text("Share Status")
        }
        
        if !info.participants.isEmpty {
            Section("Participants") {
                ForEach(Array(info.participants.enumerated()), id: \.offset) { index, participant in
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(participant.isEmpty ? "Unknown User" : participant)
                                .font(.subheadline)
                            
                            if index < info.permissions.count {
                                Text(permissionDescription(info.permissions[index]))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if index == 0 {
                            Text("Owner")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
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
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        } header: {
            Text("Error")
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeSharingService() async {
        do {
            let container = try ModelContainer(for: Trip.self, Activity.self, Transportation.self, Lodging.self, Organization.self, EmbeddedFileAttachment.self)
            await MainActor.run {
                sharingService = CKSyncEngineSharingService(modelContainer: container)
                isLoadingSharingInfo = true
            }
            
            let info = await sharingService?.getSharingInfo(for: trip)
            await MainActor.run {
                sharingInfo = info
                isLoadingSharingInfo = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to initialize sharing: \(error.localizedDescription)"
                showingError = true
                isLoadingSharingInfo = false
            }
        }
    }
    
    private func createShare() async {
        guard let sharingService = sharingService else {
            await MainActor.run {
                errorMessage = "Sharing service not available"
                showingError = true
            }
            return
        }
        
        await MainActor.run {
            isCreatingShare = true
            errorMessage = nil
        }
        
        do {
            let share = try await sharingService.createShare(for: trip)
            
            // Update sharing info
            let info = await sharingService.getSharingInfo(for: trip)
            
            await MainActor.run {
                sharingInfo = info
                shareURL = share.url
                isCreatingShare = false
                
                if share.url != nil {
                    showingShareSheet = true
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create share: \(error.localizedDescription)"
                showingError = true
                isCreatingShare = false
            }
        }
    }
    
    private func removeShare() async {
        guard let sharingService = sharingService else {
            await MainActor.run {
                errorMessage = "Sharing service not available"
                showingError = true
            }
            return
        }
        
        await MainActor.run {
            isRemovingShare = true
            errorMessage = nil
        }
        
        do {
            try await sharingService.removeShare(for: trip)
            
            // Update sharing info
            let info = await sharingService.getSharingInfo(for: trip)
            
            await MainActor.run {
                sharingInfo = info
                shareURL = nil
                isRemovingShare = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to remove share: \(error.localizedDescription)"
                showingError = true
                isRemovingShare = false
            }
        }
    }
    
    private func permissionDescription(_ permission: TripSharingPermission) -> String {
        switch permission {
        case .read:
            return "Can view"
        case .readOnly:
            return "Read only"
        case .readWrite:
            return "Can edit"
        case .readWriteDelete:
            return "Full access"
        }
    }
}

// MARK: - Share Sheet

struct TripShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TripSharingView(trip: Trip(name: "Sample Trip"))
    }
    .modelContainer(for: [Trip.self, Activity.self, Lodging.self, Transportation.self], inMemory: true)
}