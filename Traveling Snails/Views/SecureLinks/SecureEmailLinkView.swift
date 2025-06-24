//
//  SecureEmailLinkView.swift
//  Traveling Snails
//
//

import SwiftUI

struct SecureEmailLink: View {
    let email: String
    
    var body: some View {
        SecureContactLink(
            text: email,
            urlString: "mailto:\(email)",
            contactType: .email
        )
    }
}
