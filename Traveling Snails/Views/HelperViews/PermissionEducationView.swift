//
//  PermissionEducationView.swift
//  Traveling Snails
//
//

import SwiftUI

/// A view that educates users about photo permissions and guides them to enable access
struct PermissionEducationView: View {
    let permissionType: EducationPermissionType
    let onSettingsButtonTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: permissionType.iconName)
                .font(.system(size: 48))
                .foregroundColor(.blue)

            // Title
            Text(permissionType.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            // Description
            Text(permissionType.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Buttons
            VStack(spacing: 12) {
                Button("Open Settings") {
                    onSettingsButtonTap()
                }
                .buttonStyle(.borderedProminent)

                Button("Not Now") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
}

// MARK: - Supporting Types

enum EducationPermissionType {
    case photoLibrary
    case camera

    var iconName: String {
        switch self {
        case .photoLibrary:
            return "photo.on.rectangle.angled"
        case .camera:
            return "camera"
        }
    }

    var title: String {
        switch self {
        case .photoLibrary:
            return "Photo Access Needed"
        case .camera:
            return "Camera Access Needed"
        }
    }

    var description: String {
        switch self {
        case .photoLibrary:
            return "To add photos to your trip activities, please enable photo library access in Settings. Your photos remain private and are only used for your travel planning."
        case .camera:
            return "To take photos directly for your trip activities, please enable camera access in Settings. Your photos remain private and are only used for your travel planning."
        }
    }
}

// MARK: - Convenience Modifiers

extension View {
    func permissionEducationAlert(
        isPresented: Binding<Bool>,
        permissionType: EducationPermissionType,
        onSettingsButtonTap: @escaping () -> Void
    ) -> some View {
        self.alert(permissionType.title, isPresented: isPresented) {
            Button("Open Settings") {
                onSettingsButtonTap()
            }
            Button("Cancel", role: .cancel) {
                // Dismiss alert
            }
        } message: {
            Text(permissionType.description)
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionEducationView(
        permissionType: .photoLibrary,
        onSettingsButtonTap: {
            print("Settings tapped")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
}
