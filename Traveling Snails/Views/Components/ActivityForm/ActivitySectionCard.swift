//
//  ActivitySectionCard.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/21/25.
//

import SwiftUI

/// Reusable section card component matching the Unified form's beautiful design
struct ActivitySectionCard<Content: View>: View {
    let headerIcon: String
    let headerTitle: String
    let headerColor: Color
    let content: Content
    
    init(
        headerIcon: String,
        headerTitle: String,
        headerColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.headerIcon = headerIcon
        self.headerTitle = headerTitle
        self.headerColor = headerColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header
            HStack {
                Image(systemName: headerIcon)
                    .font(.title3)
                    .foregroundColor(headerColor)
                
                Text(headerTitle)
                    .font(.headline)
                    .foregroundColor(headerColor)
            }
            
            // Content inside card background
            content
        }
        .padding(12)
        .background(headerColor.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 24) {
        ActivitySectionCard(
            headerIcon: "info.circle.fill",
            headerTitle: "Basic Information",
            headerColor: .blue
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Activity Name", text: .constant("Test Activity"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        
        ActivitySectionCard(
            headerIcon: "dollarsign.circle.fill",
            headerTitle: "Cost & Payment",
            headerColor: .green
        ) {
            VStack(spacing: 16) {
                HStack {
                    Text("Cost:")
                    Spacer()
                    Text("$150.00")
                        .fontWeight(.semibold)
                }
                
                Text("Payment Status: Paid")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding()
}