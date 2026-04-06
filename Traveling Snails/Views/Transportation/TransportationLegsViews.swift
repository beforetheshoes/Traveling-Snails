//
//  TransportationLegsViews.swift
//  Traveling Snails
//

import SwiftUI

struct TransportationLegsSummaryCard: View {
    let legs: [TransportationLeg]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Itinerary")
                    .font(.headline)
                Spacer()
                Text("\(legs.count) segment\(legs.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let first = sortedLegs.first, let last = sortedLegs.last {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Departure")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(format(date: first.departure, tzId: first.departureTZId))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(timeZoneInfo(first.departureTZId))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arrival")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(format(date: last.arrival, tzId: last.arrivalTZId))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(timeZoneInfo(last.arrivalTZId))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Add at least one leg.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.systemGray6)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var sortedLegs: [TransportationLeg] {
        legs.sorted(by: { $0.sortIndex < $1.sortIndex })
    }

    private func format(date: Date, tzId: String) -> String {
        let tz = TimeZone(identifier: tzId) ?? .current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = tz
        return formatter.string(from: date)
    }

    private func timeZoneInfo(_ tzId: String) -> String {
        let tz = TimeZone(identifier: tzId) ?? .current
        return "\(TimeZoneHelper.getAbbreviation(for: tz)) • \(tz.identifier)"
    }
}

struct TransportationLegsReadOnlyList: View {
    let legs: [TransportationLeg]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedLegs.enumerated()), id: \.element.id) { index, leg in
                TransportationLegRow(leg: leg, index: index)
                if index < sortedLegs.count - 1 {
                    TransportationLayoverRow(previous: leg, next: sortedLegs[index + 1])
                }
                if index < sortedLegs.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .padding()
        .background(Color.systemBackground)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    private var sortedLegs: [TransportationLeg] {
        legs.sorted(by: { $0.sortIndex < $1.sortIndex })
    }
}

private struct TransportationLegRow: View {
    let leg: TransportationLeg
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: leg.type.systemImage)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Segment \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if !leg.serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(leg.serviceNumber)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leg.departureLocationName.isEmpty ? "Departure" : leg.departureLocationName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(format(date: leg.departure, tzId: leg.departureTZId))
                            .font(.callout)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leg.arrivalLocationName.isEmpty ? "Arrival" : leg.arrivalLocationName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(format(date: leg.arrival, tzId: leg.arrivalTZId))
                            .font(.callout)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func format(date: Date, tzId: String) -> String {
        let tz = TimeZone(identifier: tzId) ?? .current
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = tz
        return formatter.string(from: date)
    }
}

private struct TransportationLayoverRow: View {
    let previous: TransportationLeg
    let next: TransportationLeg

    var body: some View {
        let layover = max(0, next.departure.timeIntervalSince(previous.arrival))
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Layover")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(format(duration: layover))
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            if !previous.arrivalLocationName.isEmpty {
                Text(previous.arrivalLocationName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 0)
    }

    private func format(duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct TransportationLegsEditorView: View {
    @Binding var legs: [TransportationLeg]
    let onAddLeg: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(Array(sortedLegs.enumerated()), id: \.element.id) { idx, leg in
                    if let index = legs.firstIndex(where: { $0.id == leg.id }) {
                        NavigationLink {
                            TransportationLegEditorView(leg: $legs[index])
                        } label: {
                            segmentRow(legs[index], segmentIndex: idx)
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } header: {
                Text("Segments")
            } footer: {
                Text("Layovers are the stops between segments.")
            }
        }
        .navigationTitle("Segments")
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button("Add segment") { onAddLeg() }
            }
            #if os(iOS)
            ToolbarItem(placement: .platformTrailing) {
                EditButton()
            }
            #endif
        }
    }

    private var sortedLegs: [TransportationLeg] {
        legs.sorted(by: { $0.sortIndex < $1.sortIndex })
    }

    private func segmentRow(_ leg: TransportationLeg, segmentIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Segment \(segmentIndex + 1)", systemImage: leg.type.systemImage)
                Spacer()
            }
            Text(routeSummary(for: leg))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func routeSummary(for leg: TransportationLeg) -> String {
        let from = leg.departureLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = leg.arrivalLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromText = from.isEmpty ? "Departure" : from
        let toText = to.isEmpty ? "Arrival" : to

        let service = leg.serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if service.isEmpty {
            return "\(fromText) -> \(toText)"
        }
        return "\(service) • \(fromText) -> \(toText)"
    }

    private func move(from source: IndexSet, to destination: Int) {
        var sorted = legs.sorted(by: { $0.sortIndex < $1.sortIndex })
        sorted.move(fromOffsets: source, toOffset: destination)
        legs = sorted.enumerated().map { index, leg in
            var updated = leg
            updated.sortIndex = index
            return updated
        }
    }

    private func delete(at offsets: IndexSet) {
        var sorted = legs.sorted(by: { $0.sortIndex < $1.sortIndex })
        guard sorted.count > 1 else { return }
        sorted.remove(atOffsets: offsets)
        if sorted.isEmpty {
            return
        }
        legs = sorted.enumerated().map { index, leg in
            var updated = leg
            updated.sortIndex = index
            return updated
        }
    }
}

struct TransportationLegEditorView: View {
    @Binding var leg: TransportationLeg

    private var departureTZ: TimeZone { TimeZone(identifier: leg.departureTZId) ?? .current }
    private var arrivalTZ: TimeZone { TimeZone(identifier: leg.arrivalTZId) ?? .current }

    var body: some View {
        Form {
            Section("Service") {
                Picker("Type", selection: $leg.type) {
                    ForEach(TransportationType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                TextField("Number (flight/train/bus)", text: $leg.serviceNumber)
                TextField("Confirmation", text: $leg.confirmation)
            }

            Section("Seat") {
                TextField("Seat number", text: $leg.seatNumber)
                Picker("Cabin class", selection: $leg.cabinClass) {
                    ForEach(CabinClass.allCases, id: \.self) { cabin in
                        Text(cabin.displayName).tag(cabin)
                    }
                }
                Picker("Seat type", selection: $leg.seatType) {
                    ForEach(SeatType.allCases, id: \.self) { seat in
                        Text(seat.displayName).tag(seat)
                    }
                }
                TextField("Boarding group", text: $leg.boardingGroup)
            }

            Section("Departure") {
                TextField("Location (e.g. JFK)", text: $leg.departureLocationName)
                DatePicker("Date & time", selection: $leg.departure)
                    .environment(\.timeZone, departureTZ)
                SimpleTimeZonePicker(selectedTimeZoneId: $leg.departureTZId, label: "Departure timezone")
                TextField("Gate/Platform", text: $leg.departureGateOrPlatform)
                TextField("Terminal", text: $leg.departureTerminal)
            }

            Section("Arrival") {
                TextField("Location (e.g. LAX)", text: $leg.arrivalLocationName)
                DatePicker("Date & time", selection: $leg.arrival)
                    .environment(\.timeZone, arrivalTZ)
                SimpleTimeZonePicker(selectedTimeZoneId: $leg.arrivalTZId, label: "Arrival timezone")
                TextField("Gate/Platform", text: $leg.arrivalGateOrPlatform)
                TextField("Terminal", text: $leg.arrivalTerminal)
            }

            Section("Notes") {
                TextField("Notes", text: $leg.notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle("Segment")
        .inlineNavigationBarTitle()
    }
}
