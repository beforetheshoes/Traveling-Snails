//
//  AddLodgingView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import SwiftUI
import SwiftData

struct AddLodgingView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    var trip: Trip
    @State private var selectedName: String = ""
    @State private var selectedStartDate: Date = Date()
    @State private var selectedEndDate: Date = Date()
    @State private var selectedStartTimeZone: String = TimeZone.current.identifier
    @State private var selectedEndTimeZone: String = TimeZone.current.identifier
    @State private var selectedCost: Decimal = 0
    @State private var selectedPaidStatus: PaidStatus = .none
    @State private var selectedReservation: String = ""
    @State private var selectedNotes: String = ""
    @State private var selectedOrganization: Organization?
    
    let timeZones = TimeZone.knownTimeZoneIdentifiers
    
    var body: some View {
        Form {
            TextField("Name", text: $selectedName)
            
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
            
            Section("Check-in"){
                DatePicker("Date", selection: $selectedStartDate)
                
                Picker("Timezone", selection: $selectedStartTimeZone) {
                    ForEach(timeZones, id: \.self) { timeZone in
                        Text(timeZone).tag(timeZone)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Check-out"){
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
                TextField("Reservation number", text: $selectedReservation)
                
                TextField("Notes", text: $selectedNotes, axis: .vertical)
            }
            
            Button {
                saveLodging()
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
        .navigationTitle("Add Lodging")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func saveLodging() {
        guard let organization = selectedOrganization else {
            return // This shouldn't happen with the disabled button, but safety first
        }
        
        let lodging = Lodging(
            name: selectedName,
            start: selectedStartDate,
            checkInTZ: TimeZone(identifier: selectedStartTimeZone),
            end: selectedEndDate,
            checkOutTZ: TimeZone(identifier: selectedEndTimeZone),
            cost: selectedCost,
            paid: selectedPaidStatus,
            reservation: selectedReservation,
            notes: selectedNotes,
            trip: trip,
            organization: organization
        )
        
        trip.lodging.append(lodging)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save lodging: \(error)")
        }
    }
}
