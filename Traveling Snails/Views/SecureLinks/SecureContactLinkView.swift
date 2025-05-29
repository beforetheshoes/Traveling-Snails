//
//  SecureContactLinkView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI

struct SecureContactLink: View {
    let text: String
    let urlString: String
    let contactType: ContactType
    
    enum ContactType {
        case phone, email, website
    }
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isConfirmationAlert = false
    
    var body: some View {
        Button(text) {
            handleContactAction()
        }
        .foregroundColor(canOpenURL ? .blue : .secondary)
        .buttonStyle(.plain)
        .disabled(!canOpenURL)
        .alert(alertTitle, isPresented: $showingAlert) {
            if isConfirmationAlert {
                Button("Cancel", role: .cancel) { }
                Button("Open") {
                    SecureURLHandler.openURLDirectly(urlString)
                }
            } else {
                Button("OK") { }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canOpenURL: Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    private func handleContactAction() {
        // Phone and email are generally safe, only check websites for security
        if contactType == .website {
            let securityLevel = SecureURLHandler.evaluateURL(urlString)
            
            switch securityLevel {
            case .blocked:
                alertTitle = "Invalid URL"
                alertMessage = "This URL cannot be opened for security reasons."
                isConfirmationAlert = false
                showingAlert = true
                
            case .suspicious:
                alertTitle = "External Link"
                alertMessage = "This link will open in an external app or browser:\n\n\(urlString)\n\nDo you want to continue?"
                isConfirmationAlert = true
                showingAlert = true
                
            case .safe:
                SecureURLHandler.openURLDirectly(urlString)
            }
        } else {
            // Phone and email are trusted contact methods
            SecureURLHandler.openURLDirectly(urlString)
        }
    }
}
