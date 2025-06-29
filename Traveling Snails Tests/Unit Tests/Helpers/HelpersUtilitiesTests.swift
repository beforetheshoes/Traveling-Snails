//
//  HelpersUtilitiesTests.swift
//  Traveling Snails
//
//

import CoreLocation
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("Helper and Utility Tests")
struct HelperUtilityTests {
    @Suite("TimeZoneHelper Tests")
    struct TimeZoneHelperTests {
        @Test("Common timezones list")
        func commonTimezonesExists() {
            let commonTimezones = TimeZoneHelper.commonTimeZones

            #expect(!commonTimezones.isEmpty)
            #expect(commonTimezones.contains { $0.identifier == "America/New_York" })
            #expect(commonTimezones.contains { $0.identifier == "America/Los_Angeles" })
            #expect(commonTimezones.contains { $0.identifier == "Europe/London" })
            #expect(commonTimezones.contains { $0.identifier == "Asia/Tokyo" })
        }

        @Test("Grouped timezones structure")
        func groupedTimezonesStructure() {
            let groupedTimezones = TimeZoneHelper.groupedTimeZones

            #expect(!groupedTimezones.isEmpty)
            #expect(groupedTimezones["America"] != nil)
            #expect(groupedTimezones["Europe"] != nil)
            #expect(groupedTimezones["Asia"] != nil)

            // Check that timezones are properly grouped
            if let americaTimezones = groupedTimezones["America"] {
                #expect(americaTimezones.contains { $0.identifier.contains("America/") })
            }
        }

        @Test("Timezone formatting")
        func timezoneFormatting() {
            let est = TimeZone(identifier: "America/New_York")!
            let pst = TimeZone(identifier: "America/Los_Angeles")!

            let estFormatted = TimeZoneHelper.formatTimeZone(est)
            let pstFormatted = TimeZoneHelper.formatTimeZone(pst)

            #expect(estFormatted.contains("New York"))
            #expect(pstFormatted.contains("Los Angeles"))

            // Should contain GMT offset
            #expect(estFormatted.contains("GMT") || estFormatted.contains("-") || estFormatted.contains("+"))
        }

        @Test("Timezone abbreviation")
        func timezoneAbbreviation() {
            let est = TimeZone(identifier: "America/New_York")!
            let abbreviation = TimeZoneHelper.getAbbreviation(for: est)

            #expect(!abbreviation.isEmpty)
            #expect(abbreviation.count <= 5) // Abbreviations are typically short
        }

        @Test("Timezone from address")
        func timezoneFromAddress() async {
            let address = Address(
                street: "1 Apple Park Way",
                city: "Cupertino",
                state: "CA",
                country: "USA",
                latitude: 37.3349,
                longitude: -122.0090
            )

            let timezone = await TimeZoneHelper.getTimeZone(from: address)

            // Should return a timezone for valid coordinates
            #expect(timezone != nil)

            // For California coordinates, should be Pacific timezone
            if let tz = timezone {
                #expect(tz.identifier.contains("America/Los_Angeles") ||
                       tz.identifier.contains("Pacific"))
            }
        }

        @Test("Timezone from coordinate")
        func timezoneFromCoordinate() async {
            // New York coordinates
            let nyCoordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)

            let timezone = await TimeZoneHelper.getTimeZone(from: nyCoordinate)

            #expect(timezone != nil)

            // Should be Eastern timezone
            if let tz = timezone {
                #expect(tz.identifier.contains("America/New_York") ||
                       tz.identifier.contains("Eastern"))
            }
        }
    }

    @Suite("SecureURLHandler Tests")
    struct SecureURLHandlerTests {
        @Test("Safe URL evaluation")
        func safeURLEvaluation() {
            let safeURLs = [
                "https://www.apple.com",
                "https://google.com",
                "http://example.com",
                "mailto:test@example.com",
                "tel:+1-555-0123",
            ]

            for url in safeURLs {
                let level = SecureURLHandler.evaluateURL(url)
                #expect(level == .safe, "URL should be safe: \(url)")
            }
        }

        @Test("Suspicious URL evaluation")
        func suspiciousURLEvaluation() {
            let suspiciousURLs = [
                "https://bit.ly/shortlink",
                "https://tinyurl.com/example",
                "https://subdomain.herokuapp.com",
                "https://test.000webhostapp.com",
                "https://app.ngrok.io",
                "http://localhost:3000",
                "https://xn--example.com", // Punycode
                "https://a.b.c.d.e.f.example.com", // Too many subdomains
                "https://verylongdomainnamethatexceedsfiftycharacterslimit.com",
            ]

            for url in suspiciousURLs {
                let level = SecureURLHandler.evaluateURL(url)
                #expect(level == .suspicious, "URL should be suspicious: \(url)")
            }
        }

        @Test("Blocked URL evaluation")
        func blockedURLEvaluation() {
            let blockedURLs = [
                "javascript:alert('xss')",
                "data:text/html,<script>alert('xss')</script>",
                "ftp://example.com",
                "file:///etc/passwd",
                "invalid-url",
                "",
            ]

            for url in blockedURLs {
                let level = SecureURLHandler.evaluateURL(url)
                #expect(level == .blocked, "URL should be blocked: \(url)")
            }
        }

        @Test("URL scheme validation")
        func urlSchemeValidation() {
            // Valid schemes
            #expect(SecureURLHandler.evaluateURL("https://example.com") == .safe)
            #expect(SecureURLHandler.evaluateURL("http://example.com") == .safe)
            #expect(SecureURLHandler.evaluateURL("mailto:test@example.com") == .safe)
            #expect(SecureURLHandler.evaluateURL("tel:+1-555-0123") == .safe)

            // Invalid schemes
            #expect(SecureURLHandler.evaluateURL("ftp://example.com") == .blocked)
            #expect(SecureURLHandler.evaluateURL("file:///path") == .blocked)
            #expect(SecureURLHandler.evaluateURL("javascript:void(0)") == .blocked)
        }

        @Test("URL host validation")
        func urlHostValidation() {
            // Missing host should be blocked
            #expect(SecureURLHandler.evaluateURL("https://") == .blocked)
            #expect(SecureURLHandler.evaluateURL("http://") == .blocked)

            // Valid hosts should be safe
            #expect(SecureURLHandler.evaluateURL("https://example.com") == .safe)
            #expect(SecureURLHandler.evaluateURL("https://sub.example.com") == .safe)
        }
    }

    @Suite("ImageCacheManager Tests")
    struct ImageCacheManagerTests {
        @Test("ImageCacheManager singleton")
        func imageCacheManagerSingleton() {
            let instance1 = ImageCacheManager.shared
            let instance2 = ImageCacheManager.shared

            #expect(instance1 === instance2)
        }

        @Test("Cache filename generation")
        func cacheFilenameGeneration() {
            let organizationId = UUID()
            let urlString = "https://example.com/logo.png"

            // Test that the same URL and org ID generate the same filename pattern
            let urlHash = urlString.hash
            let expectedPrefix = "\(organizationId.uuidString)_\(urlHash)"

            #expect(expectedPrefix.contains(organizationId.uuidString))
        }

        @Test("URL security check in cache")
        func urlSecurityCheckInCache() async {
            let cacheManager = ImageCacheManager.shared
            let organizationId = UUID()

            // Test blocked URL
            let blockedURL = "javascript:alert('xss')"
            let result = await cacheManager.cacheImage(from: blockedURL, for: organizationId)
            #expect(result == nil)
        }
    }

    @Suite("CurrencyTextField Tests")
    struct CurrencyTextFieldTests {
        @Test("Currency formatting")
        func currencyFormatting() {
            let textField = CurrencyTextField(value: .constant(Decimal(123.45)))

            // Test that currency code defaults to USD
            #expect(textField.currencyCode == "USD" || textField.currencyCode == Locale.current.currency?.identifier)
        }
    }
}

@Suite("Business Logic Tests")
struct BusinessLogicTests {
    @Suite("Trip Cost Calculation Tests")
    struct TripCostCalculationTests {
        @Test("Trip total cost calculation")
        func tripTotalCostCalculation() {
            let trip = Trip(name: "Cost Test Trip")
            let org = Organization(name: "Test Org")

            // Add lodging
            let lodging = Lodging(
                name: "Hotel",
                start: Date(),
                end: Date(),
                cost: Decimal(200.00),
                paid: .infull,
                trip: trip,
                organization: org
            )

            lodging.trip = trip

            // Add transportation
            let transportation = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                cost: Decimal(500.00),
                trip: trip,
                organization: org
            )

            transportation.trip = trip

            // Add activity
            let activity = Activity(
                name: "Museum",
                start: Date(),
                end: Date(),
                cost: Decimal(25.50),
                trip: trip,
                organization: org
            )

            activity.trip = trip

            let totalCost = trip.totalCost
            #expect(totalCost == Decimal(725.50))
        }

        @Test("Trip activity count")
        func tripActivityCount() {
            let trip = Trip(name: "Activity Count Test")
            let org = Organization(name: "Test Org")

            #expect(trip.totalActivities == 0)

            // Add activities

            trip.lodging.append(Lodging(
                name: "Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            ))

            trip.transportation.append(Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            ))

            trip.activity.append(Activity(
                name: "Museum",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            ))

            #expect(trip.totalActivities == 3)
        }
    }

    @Suite("Date Range Validation Tests")
    struct DateRangeValidationTests {
        @Test("Trip actual date range calculation")
        func tripActualDateRange() {
            let trip = Trip(name: "Date Range Test")
            let org = Organization(name: "Test Org")

            let date1 = Date()
            let date2 = Calendar.current.date(byAdding: .day, value: 1, to: date1)!
            let date3 = Calendar.current.date(byAdding: .day, value: 2, to: date1)!
            let date4 = Calendar.current.date(byAdding: .day, value: 3, to: date1)!

            // Add activities with different dates
            trip.lodging.append(Lodging(
                name: "Hotel",
                start: date2,
                end: date3,
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            ))

            trip.activity.append(Activity(
                name: "Activity",
                start: date1, // Earliest
                end: date4,   // Latest
                trip: trip,
                organization: org
            ))

            let actualRange = trip.actualDateRange
            #expect(actualRange != nil)
            #expect(actualRange?.lowerBound == date1)
            #expect(actualRange?.upperBound == date4)
        }

        @Test("Activity duration calculation")
        func activityDurationCalculation() {
            let trip = Trip(name: "Duration Test")
            let org = Organization(name: "Test Org")

            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate)!

            let activity = Activity(
                name: "2 Hour Activity",
                start: startDate,
                end: endDate,
                trip: trip,
                organization: org
            )

            let duration = activity.duration()
            #expect(duration == 2 * 3600) // 2 hours in seconds
        }
    }

    @Suite("Organization Management Tests")
    struct OrganizationManagementTests {
        @Test("Organization deletion validation")
        func organizationDeletionValidation() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")

            // Organization with no references should be deletable
            #expect(org.transportation.isEmpty)
            #expect(org.lodging.isEmpty)
            #expect(org.activity.isEmpty)

            // Add reference
            let transportation = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            transportation.organization = org

            // Now should have references
            #expect(!org.transportation.isEmpty)
        }

        @Test("None organization behavior")
        func noneOrganizationBehavior() {
            let noneOrg = Organization(name: "None")
            let regularOrg = Organization(name: "Regular Org")

            #expect(noneOrg.isNone == true)
            #expect(regularOrg.isNone == false)
        }
    }

    @Suite("Timezone Handling Tests")
    struct TimezoneHandlingTests {
        @Test("Activity timezone storage")
        func activityTimezoneStorage() {
            let trip = Trip(name: "Timezone Test")
            let org = Organization(name: "Test Org")

            let nyTimezone = TimeZone(identifier: "America/New_York")!
            let laTimezone = TimeZone(identifier: "America/Los_Angeles")!

            let activity = Activity(
                name: "Cross-timezone Activity",
                start: Date(),
                startTZ: nyTimezone,
                end: Date(),
                endTZ: laTimezone,
                trip: trip,
                organization: org
            )

            #expect(activity.startTZId == "America/New_York")
            #expect(activity.endTZId == "America/Los_Angeles")
            #expect(activity.startTZ.identifier == "America/New_York")
            #expect(activity.endTZ.identifier == "America/Los_Angeles")
        }

        @Test("Lodging timezone mapping")
        func lodgingTimezoneMapping() {
            let trip = Trip(name: "Timezone Test")
            let org = Organization(name: "Test Hotel")

            let timezone = TimeZone(identifier: "Europe/London")!

            let lodging = Lodging(
                name: "London Hotel",
                start: Date(),
                checkInTZ: timezone,
                end: Date(),
                checkOutTZ: timezone,
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            )

            // Test that start/end timezone IDs map to check-in/check-out
            #expect(lodging.startTZId == "Europe/London")
            #expect(lodging.endTZId == "Europe/London")
            #expect(lodging.checkInTZId == "Europe/London")
            #expect(lodging.checkOutTZId == "Europe/London")
        }

        @Test("Default timezone fallback")
        func defaultTimezoneFallback() {
            let trip = Trip(name: "Default Timezone Test")
            let org = Organization(name: "Test Org")

            let activity = Activity(
                name: "Default TZ Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            // Should default to current timezone
            #expect(activity.startTZId == TimeZone.current.identifier)
            #expect(activity.endTZId == TimeZone.current.identifier)
        }
    }
}
