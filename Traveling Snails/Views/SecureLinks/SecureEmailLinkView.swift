//
//  SecureEmailLinkView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
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
