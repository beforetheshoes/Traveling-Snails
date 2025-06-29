//
//  SecurePhoneLinkView.swift
//  Traveling Snails
//
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
