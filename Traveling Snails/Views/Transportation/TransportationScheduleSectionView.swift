//
//  TransportationScheduleSectionView.swift
//  Traveling Snails
//

import SwiftUI

struct TransportationScheduleSectionView: View {
    let trip: Trip
    let icon: String
    let color: Color
    let isEditing: Bool
    @Binding var legs: [TransportationLeg]
    let legsValidationError: String?
    @Binding var showingLegsEditor: Bool

    @State private var showingAddLayoverSheet = false
    @State private var layoverDraft = LayoverDraft()

    var body: some View {
        ActivitySectionCard(
            headerIcon: icon,
            headerTitle: "Schedule",
            headerColor: color
        ) {
            VStack(spacing: 12) {
                TransportationLegsSummaryCard(legs: legs)

                if isEditing {
                    TransportationDateTimeSection(
                        trip: trip,
                        startDate: departureDateBinding,
                        endDate: finalArrivalDateBinding,
                        startTimeZoneId: departureTZBinding,
                        endTimeZoneId: finalArrivalTZBinding,
                        address: nil
                    )

                    if legs.count > 1 {
                        TransportationLayoversEditorList(legs: $legs)
                    }

                    if let error = legsValidationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack {
                        Button("Add layover") {
                            prepareLayoverDraft()
                            showingAddLayoverSheet = true
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button("Segment details") { showingLegsEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    TransportationLegsReadOnlyList(legs: legs)
                }
            }
        }
        .sheet(isPresented: $showingAddLayoverSheet) {
            NavigationStack {
                AddLayoverSheetView(
                    draft: $layoverDraft,
                    onCancel: { showingAddLayoverSheet = false },
                    onSave: {
                        addLayover(draft: layoverDraft)
                        showingAddLayoverSheet = false
                    }
                )
                .navigationTitle("Add layover")
                .inlineNavigationBarTitle()
            }
        }
    }

    private var departureDateBinding: Binding<Date> {
        Binding(
            get: { legs.first?.departure ?? Date() },
            set: { newValue in
                guard !legs.isEmpty else { return }
                legs[0].departure = newValue
            }
        )
    }

    private var finalArrivalDateBinding: Binding<Date> {
        Binding(
            get: { legs.last?.arrival ?? Date() },
            set: { newValue in
                guard !legs.isEmpty else { return }
                legs[legs.count - 1].arrival = newValue
            }
        )
    }

    private var departureTZBinding: Binding<String> {
        Binding(
            get: { legs.first?.departureTZId ?? TimeZone.current.identifier },
            set: { newValue in
                guard !legs.isEmpty else { return }
                legs[0].departureTZId = newValue
            }
        )
    }

    private var finalArrivalTZBinding: Binding<String> {
        Binding(
            get: { legs.last?.arrivalTZId ?? TimeZone.current.identifier },
            set: { newValue in
                guard !legs.isEmpty else { return }
                legs[legs.count - 1].arrivalTZId = newValue
            }
        )
    }

    private func prepareLayoverDraft() {
        guard let lastLeg = legs.sorted(by: { $0.sortIndex < $1.sortIndex }).last else { return }
        // Reasonable defaults: make the stop happen before the current final arrival.
        let proposedArrival = min(lastLeg.arrival, max(lastLeg.departure, lastLeg.arrival.addingTimeInterval(-2 * 3600)))
        let proposedDeparture = min(lastLeg.arrival, proposedArrival.addingTimeInterval(60 * 60))
        layoverDraft = LayoverDraft(
            locationName: "",
            arrival: proposedArrival,
            arrivalTZId: lastLeg.arrivalTZId,
            departure: proposedDeparture,
            departureTZId: lastLeg.arrivalTZId
        )
    }

    private func addLayover(draft: LayoverDraft) {
        guard legs.count >= 1 else { return }

        var sorted = legs.sorted(by: { $0.sortIndex < $1.sortIndex })
        let lastIndex = sorted.count - 1
        let originalLast = sorted[lastIndex]

        // Split the last segment into:
        // - segment to layover stop (arrival = layover arrival)
        // - segment from layover stop to final destination (arrival = original final arrival)
        var firstPart = originalLast
        firstPart.arrival = draft.arrival
        firstPart.arrivalTZId = draft.arrivalTZId
        firstPart.arrivalLocationName = draft.locationName
        firstPart.arrivalAddressID = nil
        firstPart.arrivalGateOrPlatform = ""
        firstPart.arrivalTerminal = ""

        let secondPart = TransportationLeg(
            transportationID: originalLast.transportationID,
            sortIndex: originalLast.sortIndex + 1,
            type: originalLast.type,
            departure: draft.departure,
            departureTZId: draft.departureTZId,
            departureLocationName: draft.locationName,
            departureAddressID: nil,
            departureGateOrPlatform: "",
            departureTerminal: "",
            arrival: originalLast.arrival,
            arrivalTZId: originalLast.arrivalTZId,
            arrivalLocationName: originalLast.arrivalLocationName,
            arrivalAddressID: originalLast.arrivalAddressID,
            arrivalGateOrPlatform: originalLast.arrivalGateOrPlatform,
            arrivalTerminal: originalLast.arrivalTerminal,
            // Clear per-segment details on the newly created segment so it doesn't inherit
            // "whole-trip" details the user might have typed into the single segment.
            serviceNumber: "",
            confirmation: "",
            seatNumber: "",
            cabinClass: .unknown,
            seatType: .unknown,
            boardingGroup: "",
            notes: ""
        )

        sorted[lastIndex] = firstPart
        sorted.insert(secondPart, at: lastIndex + 1)
        legs = sorted.enumerated().map { index, leg in
            var updated = leg
            updated.sortIndex = index
            return updated
        }
    }
}

private struct LayoverDraft: Equatable {
    var locationName: String = ""
    var arrival: Date = Date()
    var arrivalTZId: String = TimeZone.current.identifier
    var departure: Date = Date()
    var departureTZId: String = TimeZone.current.identifier

    var isValid: Bool {
        !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && departure >= arrival
    }
}

private struct AddLayoverSheetView: View {
    @Binding var draft: LayoverDraft
    let onCancel: () -> Void
    let onSave: () -> Void

    private var arrivalTZ: TimeZone { TimeZone(identifier: draft.arrivalTZId) ?? .current }
    private var departureTZ: TimeZone { TimeZone(identifier: draft.departureTZId) ?? .current }

    var body: some View {
        Form {
            Section("Stop") {
                TextField("Layover location (e.g. ORD)", text: $draft.locationName)
            }

            Section("Arrival to layover") {
                DatePicker("Date & time", selection: $draft.arrival)
                    .environment(\.timeZone, arrivalTZ)
                SimpleTimeZonePicker(selectedTimeZoneId: $draft.arrivalTZId, label: "Arrival timezone")
            }

            Section("Departure from layover") {
                DatePicker("Date & time", selection: $draft.departure)
                    .environment(\.timeZone, departureTZ)
                SimpleTimeZonePicker(selectedTimeZoneId: $draft.departureTZId, label: "Departure timezone")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { onSave() }
                    .disabled(!draft.isValid)
            }
        }
    }
}

private struct TransportationLayoversEditorList: View {
    @Binding var legs: [TransportationLeg]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Layovers")
                    .font(.headline)
                Spacer()
                Text("\(max(0, legs.count - 1))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(layoverIndices, id: \.self) { i in
                LayoverCard(
                    index: i,
                    locationName: layoverLocationBinding(i),
                    arrival: Binding(
                        get: { legs[i].arrival },
                        set: { legs[i].arrival = $0 }
                    ),
                    arrivalTZId: Binding(
                        get: { legs[i].arrivalTZId },
                        set: { legs[i].arrivalTZId = $0 }
                    ),
                    departure: Binding(
                        get: { legs[i + 1].departure },
                        set: { legs[i + 1].departure = $0 }
                    ),
                    departureTZId: Binding(
                        get: { legs[i + 1].departureTZId },
                        set: { legs[i + 1].departureTZId = $0 }
                    ),
                    onRemove: { removeLayover(at: i) }
                )
            }
        }
        .padding()
        .background(Color.systemGray6)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var layoverIndices: [Int] {
        guard legs.count >= 2 else { return [] }
        return Array(0..<(legs.count - 1))
    }

    private func layoverLocationBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: {
                let a = legs[i].arrivalLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !a.isEmpty { return a }
                return legs[i + 1].departureLocationName
            },
            set: { newValue in
                legs[i].arrivalLocationName = newValue
                legs[i + 1].departureLocationName = newValue
            }
        )
    }

    private func removeLayover(at i: Int) {
        guard legs.count >= 2 else { return }
        // Merge segment i and i+1 into segment i (drop the stop in-between).
        let next = legs[i + 1]
        legs[i].arrival = next.arrival
        legs[i].arrivalTZId = next.arrivalTZId
        legs[i].arrivalLocationName = next.arrivalLocationName
        legs[i].arrivalAddressID = next.arrivalAddressID
        legs[i].arrivalGateOrPlatform = next.arrivalGateOrPlatform
        legs[i].arrivalTerminal = next.arrivalTerminal
        legs.remove(at: i + 1)
        legs = legs.enumerated().map { idx, leg in
            var updated = leg
            updated.sortIndex = idx
            return updated
        }
    }
}

private struct LayoverCard: View {
    let index: Int
    @Binding var locationName: String
    @Binding var arrival: Date
    @Binding var arrivalTZId: String
    @Binding var departure: Date
    @Binding var departureTZId: String
    let onRemove: () -> Void

    private var arrivalTZ: TimeZone { TimeZone(identifier: arrivalTZId) ?? .current }
    private var departureTZ: TimeZone { TimeZone(identifier: departureTZId) ?? .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Layover \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button(role: .destructive) { onRemove() } label: {
                    Label("Remove", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }

            TextField("Location (e.g. ORD)", text: $locationName)

            VStack(alignment: .leading, spacing: 8) {
                Text("Arrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker("Arrive", selection: $arrival)
                    .labelsHidden()
                    .environment(\.timeZone, arrivalTZ)
                SimpleTimeZonePicker(selectedTimeZoneId: $arrivalTZId, label: "Arrival timezone")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Depart")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker("Depart", selection: $departure)
                    .labelsHidden()
                    .environment(\.timeZone, departureTZ)
                SimpleTimeZonePicker(selectedTimeZoneId: $departureTZId, label: "Departure timezone")
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}
