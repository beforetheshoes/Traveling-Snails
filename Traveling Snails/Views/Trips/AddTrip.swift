//
//  AddTrip.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

struct AddTrip: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) var modelContext

    @State var name: String = ""
    @State var notes: String = ""
    @State var startDate = Date()
    @State var endDate = Date().addingTimeInterval(7 * 24 * 3600) // Default to 1 week later
    @State var hasStartDate: Bool = false
    @State var hasEndDate: Bool = false

    func saveTrip() {
        let trip = Trip(
            name: name,
            notes: notes,
            startDate: hasStartDate ? startDate : nil,
            endDate: hasEndDate ? endDate : nil
        )
        modelContext.insert(trip)

        do {
            try modelContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            // Handle save error - for now just print, could add error state
            print("Failed to save trip: \(error)")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Name", text: $name)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section("Trip Dates (Optional)") {
                    Toggle("Set start date", isOn: $hasStartDate)

                    if hasStartDate {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                            .onChange(of: startDate) { _, newValue in
                                // Ensure end date is after start date if both are set
                                if hasEndDate && endDate <= newValue {
                                    endDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                                }
                            }
                    }

                    Toggle("Set end date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                            .onChange(of: endDate) { _, newValue in
                                // Ensure start date is before end date if both are set
                                if hasStartDate && startDate >= newValue {
                                    startDate = Calendar.current.date(byAdding: .day, value: -1, to: newValue) ?? newValue
                                }
                            }
                    }

                    Text("Setting trip dates will limit date picker ranges when adding activities. You can always change these later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: saveTrip) {
                    Text("Add Trip")
                        .frame(maxWidth: .infinity)
                }
                .disabled(name.isEmpty)
            }
            .navigationBarTitle("New Trip", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
