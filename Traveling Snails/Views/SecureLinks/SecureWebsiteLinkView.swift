//
//  SecureWebsiteLinkView.swift
//  Traveling Snails
//
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
