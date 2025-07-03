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

    // Date conflict caching infrastructure - CloudKit compatible storage
    private var _cachedDateRange: String?  // JSON-encoded ClosedRange<Date>
    private var _cacheInvalidationKey: String?

    // SAFE ACCESSORS: Never return nil, always return empty array if needed
    var lodging: [Lodging] {
        get { _lodging ?? [] }
        set {
            _lodging = newValue.isEmpty ? nil : newValue
            invalidateCache()
        }
    }

    var transportation: [Transportation] {
        get { _transportation ?? [] }
        set {
            _transportation = newValue.isEmpty ? nil : newValue
            invalidateCache()
        }
    }

    var activity: [Activity] {
        get { _activity ?? [] }
        set {
            _activity = newValue.isEmpty ? nil : newValue
            invalidateCache()
        }
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

    // MARK: - Date Conflict Caching Implementation

    /// Current cache invalidation key based on activity fingerprint
    private var currentCacheKey: String {
        // Combine all activity types into a single array
        var allActivities: [any TripActivityProtocol] = []
        allActivities.append(contentsOf: lodging)
        allActivities.append(contentsOf: transportation)
        allActivities.append(contentsOf: activity)

        let activityCount = allActivities.count

        // Create a fingerprint based on activity dates and count
        let dateFingerprint = allActivities
            .flatMap { [$0.start, $0.end] }
            .map { String(format: "%.0f", $0.timeIntervalSince1970) }
            .sorted()
            .joined(separator: ",")

        return "\(activityCount):\(dateFingerprint)"
    }

    /// Check if the current cache is valid
    private var isCacheValid: Bool {
        guard let cachedKey = _cacheInvalidationKey else { return false }
        return cachedKey == currentCacheKey
    }

    /// Cached date range accessor with automatic invalidation
    var cachedDateRange: ClosedRange<Date>? {
        // Check if cache is valid
        if isCacheValid, let cachedRangeJSON = _cachedDateRange {
            // Deserialize the cached range
            if let data = cachedRangeJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(CachedDateRange.self, from: data) {
                return decoded.startDate...decoded.endDate
            }
        }

        // Recalculate and cache
        let newRange = calculateDateRange()
        if let range = newRange {
            // Serialize and store the range
            let cachedRange = CachedDateRange(startDate: range.lowerBound, endDate: range.upperBound)
            if let encoded = try? JSONEncoder().encode(cachedRange),
               let jsonString = String(data: encoded, encoding: .utf8) {
                _cachedDateRange = jsonString
                _cacheInvalidationKey = currentCacheKey
            }
        } else {
            _cachedDateRange = nil
            _cacheInvalidationKey = currentCacheKey
        }

        return newRange
    }

    /// Calculate the cached date range from all activities (using start-of-day for conflict detection)
    private func calculateDateRange() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        var allActivityDates: [Date] = []

        // For each activity, convert the start/end times to local date components
        // This ensures we're comparing actual calendar days rather than timezone-specific moments
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

        guard let earliestActivityDay = allActivityDates.min(),
              let latestActivityDay = allActivityDates.max() else { return nil }

        return earliestActivityDay...latestActivityDay
    }

    /// Invalidate the cache when activities change
    private func invalidateCache() {
        _cachedDateRange = nil
        _cacheInvalidationKey = nil
    }

    /// Optimized date conflict checking using cached results
    func optimizedCheckDateConflicts(hasStartDate: Bool = false, startDate: Date = Date(),
                                   hasEndDate: Bool = false, endDate: Date = Date()) -> String? {
        guard totalActivities > 0 else { return nil }

        // Use cached date range for O(1) access
        guard let activityRange = cachedDateRange else { return nil }

        let calendar = Calendar.current
        var conflicts: [String] = []

        // Convert trip dates to start of day for fair comparison
        let tripStartDay = hasStartDate ? calendar.startOfDay(for: startDate) : nil
        let tripEndDay = hasEndDate ? calendar.startOfDay(for: endDate) : nil

        if let tripStart = tripStartDay, tripStart > activityRange.lowerBound {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            conflicts.append("Trip start date (\(formatter.string(from: tripStart))) is after activities starting on \(formatter.string(from: activityRange.lowerBound))")
        }

        if let tripEnd = tripEndDay, tripEnd < activityRange.upperBound {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            conflicts.append("Trip end date (\(formatter.string(from: tripEnd))) is before activities ending on \(formatter.string(from: activityRange.upperBound))")
        }

        if !conflicts.isEmpty {
            return conflicts.joined(separator: ". ") + ". Activities outside the trip date range may not be selectable when editing."
        }

        return nil
    }
}

/// Helper struct for JSON serialization of date ranges
private struct CachedDateRange: Codable {
    let startDate: Date
    let endDate: Date
}
