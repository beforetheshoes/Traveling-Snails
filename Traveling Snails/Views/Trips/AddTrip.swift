//
//  AddTrip.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import SwiftUI
import SwiftData

struct AddTrip: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) var modelContext
    
    @State var name: String = ""
    
    func SaveTrip() {
        let trip = Trip(name: name)
        modelContext.insert(trip)
        presentationMode.wrappedValue.dismiss()
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
            }
            Button(action: SaveTrip) {
                Text("Add Trip")
            }
            .navigationBarTitle(Text("New Trip"))
        }
    }
}
