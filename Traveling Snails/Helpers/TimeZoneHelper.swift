//
//  TimeZoneHelper.swift
//  Traveling Snails
//
//

import CoreLocation
import Foundation

struct TimeZoneHelper {
    // Get timezone from coordinates
    static func getTimeZone(from coordinate: CLLocationCoordinate2D) async -> TimeZone? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                guard let placemark = placemarks?.first,
                      let timeZone = placemark.timeZone else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: timeZone)
            }
        }
    }

    // Get timezone from address
    static func getTimeZone(from address: Address) async -> TimeZone? {
        guard let coordinate = address.coordinate else { return nil }
        return await getTimeZone(from: coordinate)
    }

    // Get common/preferred timezones for picker
    static var commonTimeZones: [TimeZone] {
        let identifiers = [
            // US Timezones
            "America/New_York",      // Eastern
            "America/Chicago",       // Central
            "America/Denver",        // Mountain
            "America/Los_Angeles",   // Pacific
            "America/Anchorage",     // Alaska
            "Pacific/Honolulu",      // Hawaii

            // Major International
            "Europe/London",         // GMT/BST
            "Europe/Paris",          // CET
            "Europe/Berlin",         // CET
            "Europe/Rome",           // CET
            "Europe/Madrid",         // CET
            "Europe/Amsterdam",      // CET
            "Europe/Stockholm",      // CET
            "Europe/Moscow",         // MSK

            "Asia/Tokyo",            // JST
            "Asia/Shanghai",         // CST
            "Asia/Hong_Kong",        // HKT
            "Asia/Singapore",        // SGT
            "Asia/Dubai",            // GST
            "Asia/Kolkata",          // IST
            "Asia/Bangkok",          // ICT

            "Australia/Sydney",      // AEDT/AEST
            "Australia/Melbourne",   // AEDT/AEST
            "Australia/Perth",       // AWST

            "Pacific/Auckland",      // NZDT/NZST

            "America/Toronto",       // Eastern (Canada)
            "America/Vancouver",     // Pacific (Canada)
            "America/Mexico_City",   // CST (Mexico)
            "America/Sao_Paulo",     // BRT (Brazil)
            "America/Buenos_Aires",  // ART (Argentina)

            "Africa/Cairo",          // EET
            "Africa/Johannesburg",   // SAST
        ]

        return identifiers.compactMap { TimeZone(identifier: $0) }
    }

    // Get all timezones grouped by region
    static var groupedTimeZones: [String: [TimeZone]] {
        let allIdentifiers = TimeZone.knownTimeZoneIdentifiers
        var grouped: [String: [TimeZone]] = [:]

        for identifier in allIdentifiers {
            guard let timeZone = TimeZone(identifier: identifier) else { continue }

            let components = identifier.split(separator: "/")
            let region = components.first?.replacingOccurrences(of: "_", with: " ") ?? "Other"

            if grouped[region] == nil {
                grouped[region] = []
            }
            grouped[region]?.append(timeZone)
        }

        // Sort each group by identifier
        for key in grouped.keys {
            grouped[key]?.sort { $0.identifier < $1.identifier }
        }

        return grouped
    }

    // Format timezone for display
    static func formatTimeZone(_ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "O" // GMT offset format

        let offset = formatter.string(from: Date())
        _ = timeZone.localizedName(for: .shortStandard, locale: .current) ?? timeZone.identifier
        let city = timeZone.identifier.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ") ?? ""

        return "\(city) (\(offset))"
    }

    // Get timezone abbreviation
    static func getAbbreviation(for timeZone: TimeZone) -> String {
        timeZone.abbreviation() ?? timeZone.identifier
    }
}
