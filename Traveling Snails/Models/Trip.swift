//
//  Trip.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct Trip: Identifiable {
    let id: UUID
    var name: String
    var notes: String
    var createdDate: Date
    var isProtected: Bool

    var startDate: Date
    var endDate: Date
    var hasStartDate: Bool
    var hasEndDate: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        notes: String = "",
        createdDate: Date = Date(),
        isProtected: Bool = false,
        startDate: Date = .distantPast,
        endDate: Date = .distantFuture,
        hasStartDate: Bool = false,
        hasEndDate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdDate = createdDate
        self.isProtected = isProtected
        self.startDate = startDate
        self.endDate = endDate
        self.hasStartDate = hasStartDate || startDate != .distantPast
        self.hasEndDate = hasEndDate || endDate != .distantFuture
    }

    var hasDateRange: Bool {
        hasStartDate && hasEndDate
    }

    var effectiveStartDate: Date? {
        hasStartDate ? startDate : nil
    }

    var effectiveEndDate: Date? {
        hasEndDate ? endDate : nil
    }

    var dateRange: ClosedRange<Date>? {
        guard hasStartDate && hasEndDate else { return nil }
        return startDate...endDate
    }

    mutating func setStartDate(_ date: Date) {
        startDate = date
        hasStartDate = true
    }

    mutating func setEndDate(_ date: Date) {
        endDate = date
        hasEndDate = true
    }

    mutating func clearStartDate() {
        startDate = .distantPast
        hasStartDate = false
    }

    mutating func clearEndDate() {
        endDate = .distantFuture
        hasEndDate = false
    }
}
