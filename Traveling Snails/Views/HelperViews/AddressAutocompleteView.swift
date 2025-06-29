//
//  AddressAutocompleteView.swift
//  Traveling Snails
//
//

import MapKit
import SwiftUI

struct AddressAutocompleteView: View {
    @Binding var selectedAddress: Address?
    @State private var searchText = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: SearchCompleterDelegate?
    @State private var isSearching = false
    @State private var showResults = false
    @State private var hasSelectedAddress = false

    let placeholder: String

    init(selectedAddress: Binding<Address?>, placeholder: String = "Enter address") {
        self._selectedAddress = selectedAddress
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: searchText) { _, newValue in
                        handleSearchTextChange(newValue)
                    }
                    .onTapGesture {
                        if !hasSelectedAddress && !searchText.isEmpty {
                            showResults = true
                            searchCompleter.queryFragment = searchText
                        }
                    }

                if !searchText.isEmpty {
                    Button("Clear") {
                        clearSelection()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }

            // Selected address display
            if let address = selectedAddress, hasSelectedAddress {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Selected Address:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(address.displayAddress)
                            .font(.body)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Button("Change") {
                        changeAddress()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            // Search results
            if showResults && !searchResults.isEmpty && searchText.count > 2 && !hasSelectedAddress {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Search Results")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    ForEach(searchResults.prefix(5), id: \.self) { completion in
                        Button {
                            selectAddress(from: completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
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
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color(.systemBackground))

                        if completion != searchResults.prefix(5).last {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.top, 4)
            }

            // Loading indicator
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding address...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }
        }
        .onAppear {
            setupSearchCompleter()
            // Check if we already have a selected address (but not if it's empty)
            if selectedAddress != nil && selectedAddress?.isEmpty == false {
                hasSelectedAddress = true
                if let address = selectedAddress {
                    searchText = address.displayAddress
                }
            }
        }
        .onChange(of: selectedAddress) { _, newValue in
            // Handle external changes to selectedAddress
            if newValue == nil || newValue?.isEmpty == true {
                // Address was cleared externally or is empty
                hasSelectedAddress = false
                searchText = ""
            } else if newValue != nil && newValue?.isEmpty == false && !hasSelectedAddress {
                // Address was set externally with valid data
                hasSelectedAddress = true
                if let address = newValue {
                    searchText = address.displayAddress
                }
            }
        }
    }

    private func handleSearchTextChange(_ newValue: String) {
        if newValue.isEmpty {
            clearSelection()
            return
        }

        // Only search if we don't have a selected address
        if !hasSelectedAddress {
            showResults = true
            // Add a small delay to prevent too many API calls
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.searchText == newValue && !self.hasSelectedAddress {
                    self.searchCompleter.queryFragment = newValue
                }
            }
        }
    }

    private func clearSelection() {
        searchText = ""
        searchResults = []
        selectedAddress = nil
        showResults = false
        hasSelectedAddress = false
        searchCompleter.queryFragment = ""
    }

    private func changeAddress() {
        hasSelectedAddress = false
        selectedAddress = nil
        showResults = true
        if !searchText.isEmpty {
            searchCompleter.queryFragment = searchText
        }
    }

    private func setupSearchCompleter() {
        let delegate = SearchCompleterDelegate { results in
            DispatchQueue.main.async {
                // Only update results if we're still in search mode
                if !self.hasSelectedAddress {
                    self.searchResults = results
                }
            }
        }
        searchCompleterDelegate = delegate
        searchCompleter.delegate = delegate
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }

    private func selectAddress(from completion: MKLocalSearchCompletion) {
        // Immediately set flags to prevent UI flickering
        showResults = false
        isSearching = true

        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false

                guard let response = response,
                      let mapItem = response.mapItems.first else {
                    print("Failed to get location for completion: \(error?.localizedDescription ?? "Unknown error")")
                    // Reset to search mode on error
                    self.showResults = true
                    return
                }

                let address = Address(from: mapItem.placemark)

                // Set everything in the right order
                self.selectedAddress = address
                self.searchText = address.displayAddress
                self.hasSelectedAddress = true
                self.searchResults = []
                self.searchCompleter.queryFragment = ""
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
                    VStack(alignment: .leading) {
                        Text("Selected Address Details:")
                            .font(.headline)
                        Text("Display: \(address.displayAddress)")
                        Text("Street: \(address.street)")
                        Text("City: \(address.city)")
                        Text("State: \(address.state)")
                        Text("Country: \(address.country)")
                        if let coordinate = address.coordinate {
                            Text("Coordinates: \(coordinate.latitude), \(coordinate.longitude)")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                }

                Spacer()
            }
        }
    }

    return PreviewWrapper()
}
