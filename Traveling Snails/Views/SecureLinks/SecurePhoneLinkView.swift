//
//  SecurePhoneLinkView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI

struct SecurePhoneLink: View {
    let phoneNumber: String
    
    var body: some View {
        SecureContactLink(
            text: phoneNumber,
            urlString: "tel:\(phoneNumber)",
            contactType: .phone
        )
    }
}
