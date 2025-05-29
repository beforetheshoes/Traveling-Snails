//
//  AddTransportationView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import SwiftUI
import SwiftData

struct AddTransportationView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    var trip: Trip
    @State private var selectedName: String = ""
    @State private var selectedStartDate: Date = Date()
    @State private var selectedEndDate: Date = Date()
    @State private var selectedStartTimeZone: String = TimeZone.current.identifier
    @State private var selectedEndTimeZone: String = TimeZone.current.identifier
    @State private var selectedType: TransportationType = .plane
    @State private var selectedCost: Decimal = 0
    @State private var selectedPaidStatus: PaidStatus = .none
    @State private var selectedConfirmation: String = ""
    @State private var selectedNotes: String = ""
    @State private var selectedOrganization: Organization?
    
    let timeZones = TimeZone.knownTimeZoneIdentifiers

    var body: some View {
        Form {
            TextField("Name", text: $selectedName)
            
            Picker("Type", selection: $selectedType) {
                ForEach(TransportationType.allCases, id: \.self) { transportationType in
                    Text(transportationType.rawValue.capitalized).tag(transportationType)
                }
            }
            .pickerStyle(.menu)
            
            Section("Organization") {
                NavigationLink {
                    OrganizationPicker(selectedOrganization: $selectedOrganization)
                } label: {
                    HStack {
                        Text("Organization")
                        
                        Spacer()
                        
                        if let org = selectedOrganization {
                            Text(org.name)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Required")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Section("Departure"){
                DatePicker("Date", selection: $selectedStartDate)
                
                Picker("Timezone", selection: $selectedStartTimeZone) {
                    ForEach(timeZones, id: \.self) { timeZone in
                        Text(timeZone).tag(timeZone)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Arrival"){
                DatePicker("Date", selection: $selectedEndDate)
                
                Picker(selection: $selectedEndTimeZone) {
                    ForEach(timeZones, id: \.self) { timeZone in
                        Text(timeZone).tag(timeZone)
                    }
                } label: {
                    Text("Timezone")
                }
                .pickerStyle(.menu)
            }
            
            Section{
                HStack {
                    Text("Cost")
                    
                    Spacer()
                    
                    CurrencyTextField(value: $selectedCost)
                }
                
                Picker(selection: $selectedPaidStatus) {
                    ForEach(PaidStatus.allCases, id: \.self) { thisPaidStatus in
                        Text(thisPaidStatus.displayName).tag(thisPaidStatus)
                    }
                } label: {
                    Text("Paid status")
                }
            }
            
            Section("Details") {
                TextField("Confirmation number", text: $selectedConfirmation)
                
                TextField("Notes", text: $selectedNotes, axis: .vertical)
            }
            
            Button {
                saveTransportation()
            } label: {
                Text("Submit")
                    .foregroundStyle(Color(.white))
                    .frame(maxWidth: .infinity, maxHeight: 45)
                    .padding([.top, .bottom], 5)
                    .dynamicTypeSize(.small)
            }
            .frame(height: 45)
            .background(Color(.blue))
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding([.bottom, .top], 10)
            
        }
        .formStyle(.grouped)
        .navigationTitle("Add Transportation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func saveTransportation() {
        guard let organization = selectedOrganization else {
            return // This shouldn't happen with the disabled button, but safety first
        }
        
        let transportation = Transportation(
            name: selectedName,
            type: selectedType,
            start: selectedStartDate,
            startTZ: TimeZone(identifier: selectedStartTimeZone),
            end: selectedEndDate,
            endTZ: TimeZone(identifier: selectedEndTimeZone),
            cost: selectedCost,
            paid: selectedPaidStatus,
            confirmation: selectedConfirmation,
            notes: selectedNotes,
            trip: trip,
            organization: organization
        )
        
        trip.transportation.append(transportation)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save transportation: \(error)")
        }
    }
}

#Preview {
    AddTransportationView(trip: Trip(name: "Test Trip"))
        .modelContainer(for: Trip.self, inMemory: true)
}
