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
    var color: Color = .blue
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.textAlignment = .right
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        
        // Style the text field
        textField.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        textField.backgroundColor = UIColor.systemGray6
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 0
        
        // Add padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: textField.frame.height))
        textField.rightView = paddingView
        textField.rightViewMode = .always
        
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: textField.frame.height))
        textField.leftView = leftPaddingView
        textField.leftViewMode = .always
        
        // Initialize the text field with the current value
        let cents = Int(NSDecimalNumber(decimal: value * Decimal(100)).doubleValue.rounded())
        context.coordinator.centValue = cents
        textField.text = formatCurrency(cents)
        
        // Store color for focus animation
        context.coordinator.focusColor = UIColor(color)
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update if we're not currently editing AND the value changed
        if !uiView.isFirstResponder {
            let cents = Int(NSDecimalNumber(decimal: value * Decimal(100)).doubleValue.rounded())
            if context.coordinator.centValue != cents {
                context.coordinator.centValue = cents
                uiView.text = formatCurrency(cents)
            }
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
        var focusColor: UIColor?
        
        init(_ parent: CurrencyTextField) {
            self.parent = parent
            // Initialize with the current value
            self.centValue = Int(NSDecimalNumber(decimal: parent.value * Decimal(100)).doubleValue.rounded())
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Don't reset to 0 - keep the current value
            textField.text = parent.formatCurrency(centValue)
            textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
            
            // Add focus styling
            UIView.animate(withDuration: 0.2) {
                textField.layer.borderWidth = 2
                textField.layer.borderColor = self.focusColor?.cgColor ?? UIColor.blue.cgColor
            }
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            // Update the binding
            let newValue = Decimal(centValue) / Decimal(100)
            DispatchQueue.main.async {
                self.parent.value = newValue
            }
            
            // Remove focus styling
            UIView.animate(withDuration: 0.2) {
                textField.layer.borderWidth = 0
                textField.layer.borderColor = UIColor.clear.cgColor
            }
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
            
            // Update the binding in real-time as user types
            let newValue = Decimal(centValue) / Decimal(100)
            DispatchQueue.main.async {
                self.parent.value = newValue
            }
            
            textField.text = parent.formatCurrency(centValue)
            textField.selectedTextRange = textField.textRange(from: textField.endOfDocument, to: textField.endOfDocument)
            return false // We've handled the text change ourselves
        }
    }
}
