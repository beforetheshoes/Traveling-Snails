//
//  ActivitySubmitButton.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable submit button component for activity forms
struct ActivitySubmitButton: View {
    let title: String
    let isValid: Bool
    let isSaving: Bool
    let color: Color
    let saveError: Error?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 4)
                    }

                    Text(isSaving ? "Saving..." : title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid && !isSaving ? color : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isValid || isSaving)

            if let error = saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)

                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.bottom)
    }
}

#Preview {
    VStack(spacing: 30) {
        ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: nil
        ) {}

        ActivitySubmitButton(
            title: "Save Lodging",
            isValid: false,
            isSaving: false,
            color: .green,
            saveError: nil
        ) {}

        ActivitySubmitButton(
            title: "Save Transportation",
            isValid: true,
            isSaving: true,
            color: .orange,
            saveError: nil
        ) {}

        ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        ) {}
    }
    .padding()
}
