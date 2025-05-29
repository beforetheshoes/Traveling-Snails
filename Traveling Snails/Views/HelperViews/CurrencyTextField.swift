//
//  CurrencyTextField.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/25/25.
//

import SwiftUI
import UIKit

struct CurrencyTextField: UIViewRepresentable {
    @Binding var value: Decimal
    var placeholder: String = "Amount"
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if we're not currently editing
        if !uiView.isFirstResponder {
            let cents = Int(NSDecimalNumber(decimal: value * Decimal(100)).doubleValue.rounded())
            uiView.text = formatCurrency(cents)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func formatCurrency(_ cents: Int) -> String {
        let decimal = Decimal(cents) / Decimal(100)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: decimal as NSDecimalNumber) ?? "$0.00"
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: CurrencyTextField
        var centValue: Int = 0
        
        init(_ parent: CurrencyTextField) {
            self.parent = parent
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            centValue = 0
            textField.text = parent.formatCurrency(0)
            textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.value = Decimal(centValue) / Decimal(100)
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.isEmpty {
                // Backspace - remove last digit
                centValue = centValue / 10
            } else if let digit = Int(string), string.count == 1 {
                // Add digit to the right
                centValue = (centValue * 10) + digit
                centValue = min(centValue, 99999999) // Cap at $999,999.99
            } else {
                return false // Reject invalid input
            }
            
            textField.text = parent.formatCurrency(centValue)
            textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
            return false // We've handled the text change ourselves
        }
    }
}
