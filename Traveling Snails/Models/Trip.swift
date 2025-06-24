//
//  Trip.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData

@Model
class Trip: Identifiable {
    var id = UUID()
    var name: String = ""
    var notes: String = ""
    var createdDate: Date = Date()
    var isProtected: Bool = false
    
    // Trip date range with flags to indicate if they're set
    var startDate: Date = Date.distantPast
    var endDate: Date = Date.distantFuture
    var hasStartDate: Bool = false
    var hasEndDate: Bool = false
    
    // CRITICAL FIX: Use explicit relationships with proper inverse declarations
    // to prevent infinite loops and auto-insertion issues
    // CLOUDKIT REQUIRED: Optional relationships with SAFE accessors
    @Relationship(deleteRule: .cascade, inverse: \Lodging.trip)
    private var _lodging: [Lodging]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Transportation.trip)
    private var _transportation: [Transportation]? = nil

    @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
    private var _activity: [Activity]? = nil
    
    // SAFE ACCESSORS: Never return nil, always return empty array if needed
    var lodging: [Lodging] {
        get { _lodging ?? [] }
        set { _lodging = newValue.isEmpty ? nil : newValue }
    }
    
    var transportation: [Transportation] {
        get { _transportation ?? [] }
        set { _transportation = newValue.isEmpty ? nil : newValue }
    }
    
    var activity: [Activity] {
        get { _activity ?? [] }
        set { _activity = newValue.isEmpty ? nil : newValue }
    }
    
    init(
        name: String = "",
        notes: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        isProtected: Bool = false
    ) {
        self.name = name
        self.notes = notes
        self.createdDate = Date()
        self.isProtected = isProtected
        
        if let start = startDate {
            self.startDate = start
            self.hasStartDate = true
        }
        
        if let end = endDate {
            self.endDate = end
            self.hasEndDate = true
        }
    }
    
    var totalCost: Decimal {
        let lodgingCost = lodging.reduce(Decimal(0)) { $0 + $1.cost }
        let transportationCost = transportation.reduce(Decimal(0)) { $0 + $1.cost }
        let activityCost = activity.reduce(Decimal(0)) { $0 + $1.cost }
        return lodgingCost + transportationCost + activityCost
    }

    var totalActivities: Int {
        lodging.count + transportation.count + activity.count
    }
    
    // Helper properties for date validation
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
    
    // Methods to set/clear dates
    func setStartDate(_ date: Date) {
        startDate = date
        hasStartDate = true
    }
    
    func setEndDate(_ date: Date) {
        endDate = date
        hasEndDate = true
    }
    
    func clearStartDate() {
        startDate = Date.distantPast
        hasStartDate = false
    }
    
    func clearEndDate() {
        endDate = Date.distantFuture
        hasEndDate = false
    }
    
    // Computed property to get the actual trip duration based on activities
    var actualDateRange: ClosedRange<Date>? {
        var allDates: [Date] = []

        allDates.append(contentsOf: lodging.flatMap { [$0.start, $0.end] })
        allDates.append(contentsOf: transportation.flatMap { [$0.start, $0.end] })
        allDates.append(contentsOf: activity.flatMap { [$0.start, $0.end] })

        guard let earliestDate = allDates.min(),
              let latestDate = allDates.max() else { return nil }

        return earliestDate...latestDate
    }
}
