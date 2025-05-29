//
//  AddressAutocompleteView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI
import MapKit

struct AddressAutocompleteView: View {
    @Binding var selectedAddress: Address?
    @State private var searchText = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: SearchCompleterDelegate?
    @State private var isSearching = false
    
    let placeholder: String
    
    init(selectedAddress: Binding<Address?>, placeholder: String = "Enter address") {
        self._selectedAddress = selectedAddress
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: searchText) { oldValue, newValue in
                        if newValue.isEmpty {
                            searchResults = []
                            selectedAddress = nil
                        } else {
                            searchCompleter.queryFragment = newValue
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        searchResults = []
                        selectedAddress = nil
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Selected address display
            if let address = selectedAddress {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text(address.displayAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // Search results
            if !searchResults.isEmpty && searchText.count > 2 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchResults.prefix(5), id: \.self) { completion in
                        Button {
                            selectAddress(from: completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if completion != searchResults.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.top, 4)
            }
        }
        .onAppear {
            setupSearchCompleter()
        }
    }
    
    private func setupSearchCompleter() {
        let delegate = SearchCompleterDelegate { results in
            DispatchQueue.main.async {
                self.searchResults = results
            }
        }
        searchCompleterDelegate = delegate
        searchCompleter.delegate = delegate
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }
    
    private func selectAddress(from completion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let mapItem = response.mapItems.first else {
                return
            }
            
            DispatchQueue.main.async {
                let address = Address(from: mapItem.placemark)
                self.selectedAddress = address
                self.searchText = address.displayAddress
                self.searchResults = []
            }
        }
    }
}

// Helper class to handle search completer delegate
class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let onResults: ([MKLocalSearchCompletion]) -> Void
    
    init(onResults: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onResults = onResults
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Handle error if needed
        print("Search completer error: \(error)")
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var address: Address?
        
        var body: some View {
            VStack {
                AddressAutocompleteView(selectedAddress: $address)
                    .padding()
                
                if let address = address {
                    Text("Selected: \(address.displayAddress)")
                        .padding()
                }
                
                Spacer()
            }
        }
    }
    
    return PreviewWrapper()
}
