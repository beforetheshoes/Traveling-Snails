//
//  SecureWebsiteLinkView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI

struct SecureWebsiteLink: View {
    let website: String
    
    private var formattedURL: String {
        website.hasPrefix("http") ? website : "https://\(website)"
    }
    
    var body: some View {
        SecureContactLink(
            text: website,
            urlString: formattedURL,
            contactType: .website
        )
    }
}
