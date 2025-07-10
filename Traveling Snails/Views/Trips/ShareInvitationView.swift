import SwiftUI
import CloudKit
import SwiftData

/// View for handling CloudKit share invitation acceptance
struct ShareInvitationView: View {
    let shareMetadata: CKShare.Metadata
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var sharingService: CKSyncEngineSharingService?
    @State private var isAcceptingShare = false
    @State private var acceptedTrip: Trip?
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Share invitation header
                VStack(spacing: 16) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("Trip Invitation")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let shareTitle = shareMetadata.share[CKShare.SystemFieldKey.title] as? String {
                        Text("You've been invited to collaborate on:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(shareTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("You've been invited to collaborate on a trip")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                
                Spacer()
                
                // Share details
                VStack(spacing: 12) {
                    if let ownerName = shareMetadata.ownerIdentity.nameComponents?.formatted() {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.blue)
                            Text("Shared by: \(ownerName)")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                        Text("Real-time collaboration")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        Text("Syncs across all devices")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await acceptInvitation()
                        }
                    } label: {
                        HStack {
                            if isAcceptingShare {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text("Accept Invitation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAcceptingShare)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Decline")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAcceptingShare)
                }
                .padding()
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationBarHidden(true)
            .task {
                await initializeSharingService()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeSharingService() async {
        do {
            let container = try ModelContainer(for: Trip.self, Activity.self, Transportation.self, Lodging.self, Organization.self, EmbeddedFileAttachment.self)
            await MainActor.run {
                sharingService = CKSyncEngineSharingService(modelContainer: container)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to initialize sharing: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func acceptInvitation() async {
        guard let sharingService = sharingService else {
            await MainActor.run {
                errorMessage = "Sharing service not available"
                showingError = true
            }
            return
        }
        
        await MainActor.run {
            isAcceptingShare = true
            errorMessage = nil
        }
        
        do {
            let trip = try await sharingService.acceptShare(with: shareMetadata)
            
            await MainActor.run {
                acceptedTrip = trip
                isAcceptingShare = false
                
                // Successfully accepted - dismiss view
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to accept invitation: \(error.localizedDescription)"
                showingError = true
                isAcceptingShare = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Note: Cannot create mock CKShare.Metadata in preview due to CloudKit restrictions
    // This preview will show a placeholder
    Text("ShareInvitationView Preview")
        .navigationTitle("Share Invitation")
        .modelContainer(for: [Trip.self, Activity.self, Lodging.self, Transportation.self], inMemory: true)
}