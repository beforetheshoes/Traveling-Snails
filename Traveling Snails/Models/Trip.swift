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
    var createdDate = Date()
    var isProtected: Bool = false

    // Trip date range with flags to indicate if they're set
    var startDate = Date.distantPast
    var endDate = Date.distantFuture
    var hasStartDate: Bool = false
    var hasEndDate: Bool = false

    // CRITICAL FIX: Use explicit relationships with proper inverse declarations
    // to prevent infinite loops and auto-insertion issues
    // CLOUDKIT REQUIRED: Optional relationships with SAFE accessors
    @Relationship(deleteRule: .cascade, inverse: \Lodging.trip)
    private var _lodging: [Lodging]?

    @Relationship(deleteRule: .cascade, inverse: \Transportation.trip)
    private var _transportation: [Transportation]?

    @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
    private var _activity: [Activity]?

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

    // MARK: - Date Range Caching Infrastructure
    
    // CLOUDKIT REQUIRED: Private cache storage with optional for CloudKit compatibility
    private var _cachedDateRange: ClosedRange<Date>?
    private var _cacheInvalidationKey: String?
    
    // Cache invalidation tracking
    private var currentCacheKey: String {
        // Create fingerprint based on activity dates and counts
        let activityDates = activity.flatMap { [$0.start, $0.end] }
        let lodgingDates = lodging.flatMap { [$0.start, $0.end] }
        let transportationDates = transportation.flatMap { [$0.start, $0.end] }
        
        let allDates = activityDates + lodgingDates + transportationDates
        let dateString = allDates.map { String($0.timeIntervalSince1970) }.sorted().joined(separator:",")
        let countString = "\(activity.count)-\(lodging.count)-\(transportation.count)"
        
        return "\(dateString)-\(countString)"
    }
    
    // Cache validity check
    var isCacheValid: Bool {
        guard let cachedKey = _cacheInvalidationKey else { return false }
        return cachedKey == currentCacheKey
    }
    
    // Cached date range accessor with automatic invalidation
    var cachedDateRange: ClosedRange<Date>? {
        // Check if cache is valid
        if isCacheValid, let cached = _cachedDateRange {
            return cached
        }
        
        // Recalculate and cache
        let newRange = calculateDateRange()
        _cachedDateRange = newRange
        _cacheInvalidationKey = currentCacheKey
        
        return newRange
    }
    
    // Private method to calculate date range (extracted from actualDateRange)
    private func calculateDateRange() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        var allActivityDates: [Date] = []
        
        // Convert all activity dates to start-of-day for consistent comparison
        // This matches the logic used in checkDateConflicts
        for lodging in lodging {
            let startDay = calendar.startOfDay(for: lodging.start)
            let endDay = calendar.startOfDay(for: lodging.end)
            allActivityDates.append(contentsOf: [startDay, endDay])
        }
        
        for transportation in transportation {
            let startDay = calendar.startOfDay(for: transportation.start)
            let endDay = calendar.startOfDay(for: transportation.end)
            allActivityDates.append(contentsOf: [startDay, endDay])
        }
        
        for activity in activity {
            let startDay = calendar.startOfDay(for: activity.start)
            let endDay = calendar.startOfDay(for: activity.end)
            allActivityDates.append(contentsOf: [startDay, endDay])
        }
        
        guard let earliestDate = allActivityDates.min(),
              let latestDate = allActivityDates.max() else { return nil }
        
        return earliestDate...latestDate
    }
    
    // Manual cache invalidation (for testing and explicit invalidation)
    func invalidateCache() {
        _cachedDateRange = nil
        _cacheInvalidationKey = nil
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
    
    // MARK: - Optimized Date Conflict Checking
    
    // Optimized version of date conflict checking using cached ranges
    func optimizedCheckDateConflicts() -> String? {
        guard totalActivities > 0 else { return nil }
        
        // Use cached date range instead of recalculating
        guard let activityRange = cachedDateRange else { return nil }
        
        // Compare with trip's set date range
        var conflicts: [String] = []
        
        if hasStartDate {
            let tripStartDay = Calendar.current.startOfDay(for: startDate)
            if activityRange.lowerBound < tripStartDay {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                conflicts.append("Activities start before trip (\(formatter.string(from: activityRange.lowerBound)) vs \(formatter.string(from: tripStartDay)))")
            }
        }
        
        if hasEndDate {
            let tripEndDay = Calendar.current.startOfDay(for: endDate)
            if activityRange.upperBound > tripEndDay {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                conflicts.append("Activities end after trip (\(formatter.string(from: activityRange.upperBound)) vs \(formatter.string(from: tripEndDay)))")
            }
        }
        
        return conflicts.isEmpty ? nil : conflicts.joined(separator: "\n")
    }
}
