//
//  AddTrip.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct AddTrip: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<AddTripFeature>

    init(store: StoreOf<AddTripFeature>) {
        self._store = State(initialValue: store)
    }

    var body: some View {
        @Bindable var store = self.store

        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Name", text: $store.name)
                    TextField("Notes", text: $store.notes, axis: .vertical)
                }

                Section("Trip Dates (Optional)") {
                    Toggle("Set start date", isOn: $store.hasStartDate)

                    if store.hasStartDate {
                        DatePicker("Start Date", selection: $store.startDate, displayedComponents: .date)
                            .onChange(of: store.startDate) { _, newValue in
                                store.send(.startDateChanged(newValue))
                            }
                    }

                    Toggle("Set end date", isOn: $store.hasEndDate)

                    if store.hasEndDate {
                        DatePicker("End Date", selection: $store.endDate, displayedComponents: .date)
                            .onChange(of: store.endDate) { _, newValue in
                                store.send(.endDateChanged(newValue))
                            }
                    }

                    Text("Setting trip dates will limit date picker ranges when adding activities. You can always change these later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    store.send(.saveTapped)
                } label: {
                    Text("Add Trip")
                        .frame(maxWidth: .infinity)
                }
                .disabled(store.isSaveDisabled)
            }
            .navigationTitle("New Trip")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .platformLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            store.send(.dismissHandled)
        }
        .alert("Unable to Save", isPresented: .constant(store.errorMessage != nil)) {
            Button("OK") {
                store.send(.dismissError)
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
