//
//  WorkingCurrencyTextField.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/5/25.
//

import SwiftUI

struct FancyCurrencyTextField: View {
    @Binding var value: Decimal
    @FocusState private var isFocused: Bool
    @State private var textValue: String = ""
    let color: Color
    
    init(value: Binding<Decimal>, color: Color = .blue) {
        self._value = value
        self.color = color
    }
    
    // Convenience initializer for views without activity context
    init(value: Binding<Decimal>) {
        self._value = value
        self.color = .blue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Currency symbol in a circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Text("$")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                TextField("0.00", text: $textValue)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .font(.system(size: 18, weight: .medium))
                    .onChange(of: textValue) { _, newValue in
                        updateDecimalValue(from: newValue)
                    }
                    .onAppear {
                        textValue = formatDecimalForEditing(value)
                    }
                    .onChange(of: value) { _, newValue in
                        if !isFocused {
                            textValue = formatDecimalForEditing(newValue)
                        }
                    }
                
                if isFocused {
                    Text("Enter amount in USD")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            
            Spacer()
            
            // Current formatted value
            if !isFocused && value > 0 {
                Text(value, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? color : Color.clear, lineWidth: 2)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
    
    private func updateDecimalValue(from text: String) {
        let cleanedText = text.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        
        if let double = Double(cleanedText) {
            value = Decimal(double)
        } else if cleanedText.isEmpty {
            value = 0
        }
    }
    
    private func formatDecimalForEditing(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: decimal as NSDecimalNumber) ?? "0"
    }
}
