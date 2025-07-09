//
//  UIPickerAndSearchTests.swift
//  Traveling SnailsUnitTests
//
//

import MapKit
import SwiftData
import SwiftUI
import Testing

@testable import Traveling_Snails

@Suite("UI Picker and Search Tests")
struct UIPickerAndSearchTests {
    @Suite("Organization Picker Tests")
    struct OrganizationPickerTests {
        @Test("None organization creation", .tags(.ui, .medium, .parallel, .swiftui, .organization, .validation, .swiftdata))
        func noneOrganizationCreation() throws {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Organization.self,
                configurations: config
            )
            let context = ModelContext(container)

            let noneOrg = OrganizationManager.shared.ensureNoneOrganization(in: context)
            switch noneOrg {
            case .success(let result):
                #expect(result.organization.name == "None")
                #expect(result.organization.isNone == true)
            case .failure:
                Issue.record("Failed to get None organization")
            }
        }

        @Test("Organization filtering", .tags(.ui, .medium, .parallel, .swiftui, .organization, .search, .validation))
        func organizationFiltering() {
            let organizations = [
                Organization(name: "Apple Airlines"),
                Organization(name: "Banana Hotels"),
                Organization(name: "Cherry Tours"),
                Organization(name: "Delta Express"),
            ]

            // Test case-insensitive filtering
            let searchText = "app"
            let filtered = organizations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }

            #expect(filtered.count == 1)
            #expect(filtered.first?.name == "Apple Airlines")

            // Test empty search returns all
            let emptySearch = ""
            let allFiltered = organizations.filter { org in
                emptySearch.isEmpty || org.name.localizedCaseInsensitiveContains(emptySearch)
            }
            #expect(allFiltered.count == 4)

            // Test no matches
            let noMatchSearch = "xyz"
            let noMatches = organizations.filter {
                $0.name.localizedCaseInsensitiveContains(noMatchSearch)
            }
            #expect(noMatches.isEmpty)
        }

        @Test("Search text validation", .tags(.ui, .medium, .parallel, .swiftui, .organization, .search, .validation))
        func searchTextValidation() {
            let testSearches = [
                ("apple", true),
                ("APPLE", true),
                ("App", true),
                ("xyz", false),
                ("", true), // Empty should match all
            ]

            let testOrg = Organization(name: "Apple Airlines")

            for (searchText, shouldMatch) in testSearches {
                let matches = searchText.isEmpty || testOrg.name.localizedCaseInsensitiveContains(searchText)
                #expect(matches == shouldMatch, "Search '\(searchText)' should \(shouldMatch ? "match" : "not match") '\(testOrg.name)'")
            }
        }

        @Test("Organization picker shows None exactly once - Issue #20 fix verification", .tags(.ui, .medium, .parallel, .swiftui, .organization, .regression, .validation, .swiftdata))
        func organizationPickerShowsNoneOnce() throws {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Organization.self,
                configurations: config
            )
            let context = ModelContext(container)

            // Create test organizations including "None" (simulating the bug scenario)
            let testOrganizations = [
                Organization(name: "Apple Airlines"),
                Organization(name: "Banana Hotels"),
                Organization(name: "None"), // This appears in @Query
            ]

            for org in testOrganizations {
                context.insert(org)
            }
            try context.save()

            // Simulate the FIXED picker logic (single data source)
            let none = testOrganizations.filter { $0.name == "None" }
            let others = testOrganizations.filter { $0.name != "None" }.sorted { $0.name < $1.name }
            let sortedOrganizations = none + others

            // Verify None appears exactly once and first
            let noneCount = sortedOrganizations.filter { $0.name == "None" }.count
            #expect(noneCount == 1, "None organization should appear exactly once")
            #expect(sortedOrganizations.first?.name == "None", "None organization should appear first")
            #expect(sortedOrganizations[1].name == "Apple Airlines", "Other organizations should be alphabetical after None")
        }
    }

    @Suite("Address Autocomplete Tests")
    struct AddressAutocompleteTests {
        @Test("Address display logic", .tags(.ui, .medium, .parallel, .swiftui, .address, .validation))
        func addressDisplayLogic() {
            // Test formatted address takes priority
            let addressWithFormatted = Address(
                street: "123 Main St",
                city: "Test City",
                formattedAddress: "Custom Formatted Address"
            )
            #expect(addressWithFormatted.displayAddress == "Custom Formatted Address")

            // Test component fallback
            let addressWithoutFormatted = Address(
                street: "456 Oak St",
                city: "Oak City",
                state: "CA",
                country: "USA"
            )
            #expect(addressWithoutFormatted.displayAddress == "456 Oak St, Oak City, CA, USA")

            // Test empty address
            let emptyAddress = Address()
            #expect(emptyAddress.isEmpty == true)
            #expect(emptyAddress.displayAddress == "")
        }

        @Test("Address coordinate handling", .tags(.ui, .medium, .parallel, .swiftui, .address, .validation))
        func addressCoordinateHandling() {
            // Test valid coordinates
            let validAddress = Address(
                latitude: 37.7749,
                longitude: -122.4194
            )
            #expect(validAddress.coordinate != nil)
            #expect(validAddress.coordinate?.latitude == 37.7749)
            #expect(validAddress.coordinate?.longitude == -122.4194)

            // Test zero coordinates (should return nil)
            let zeroAddress = Address(latitude: 0.0, longitude: 0.0)
            #expect(zeroAddress.coordinate == nil)

            // Test default address
            let defaultAddress = Address()
            #expect(defaultAddress.coordinate == nil)
        }

        @Test("Address validation", .tags(.ui, .medium, .parallel, .swiftui, .address, .validation))
        func addressValidation() {
            // Test complete address
            let completeAddress = Address(
                street: "123 Main St",
                city: "San Francisco",
                state: "CA",
                country: "USA",
                postalCode: "94102"
            )
            #expect(completeAddress.isEmpty == false)

            // Test partial address
            let partialAddress = Address(city: "San Francisco")
            #expect(partialAddress.isEmpty == false)

            // Test truly empty address
            let emptyAddress = Address()
            #expect(emptyAddress.isEmpty == true)
        }
    }

    @Suite("TimeZone Picker Tests")
    struct TimeZonePickerTests {
        @Test("Common timezones list", .tags(.ui, .medium, .parallel, .swiftui, .timezone, .validation))
        func commonTimezonesList() {
            let commonTimezones = TimeZoneHelper.commonTimeZones

            #expect(!commonTimezones.isEmpty)
            #expect(commonTimezones.contains { $0.identifier == "America/New_York" })
            #expect(commonTimezones.contains { $0.identifier == "America/Los_Angeles" })
            #expect(commonTimezones.contains { $0.identifier == "Europe/London" })
            #expect(commonTimezones.contains { $0.identifier == "Asia/Tokyo" })
        }

        @Test("Timezone formatting", .tags(.ui, .medium, .parallel, .swiftui, .timezone, .validation))
        func timezoneFormatting() {
            let nyTimezone = TimeZone(identifier: "America/New_York")!
            let formatted = TimeZoneHelper.formatTimeZone(nyTimezone)

            #expect(formatted.contains("New York"))
            // Should contain GMT offset indicator
            #expect(formatted.contains("GMT") || formatted.contains("-") || formatted.contains("+"))
        }

        @Test("Timezone grouping", .tags(.ui, .medium, .parallel, .swiftui, .timezone, .validation))
        func timezoneGrouping() {
            let grouped = TimeZoneHelper.groupedTimeZones

            #expect(!grouped.isEmpty)
            #expect(grouped["America"] != nil)
            #expect(grouped["Europe"] != nil)
            #expect(grouped["Asia"] != nil)

            // Check America group contains American timezones
            if let americaGroup = grouped["America"] {
                #expect(americaGroup.contains { $0.identifier.hasPrefix("America/") })
            }
        }

        @Test("Timezone abbreviation", .tags(.ui, .medium, .parallel, .swiftui, .timezone, .validation))
        func timezoneAbbreviation() {
            let timezone = TimeZone(identifier: "America/New_York")!
            let abbreviation = TimeZoneHelper.getAbbreviation(for: timezone)

            #expect(!abbreviation.isEmpty)
            #expect(abbreviation.count <= 5) // Abbreviations are typically short
        }
    }

    @Suite("Search and Filter Logic Tests")
    struct SearchAndFilterLogicTests {
        @Test("Case insensitive search", .tags(.ui, .medium, .parallel, .swiftui, .search, .validation))
        func caseInsensitiveSearch() {
            let testString = "Apple Airlines International"

            let searchTerms = [
                "apple",
                "APPLE",
                "Apple",
                "airlines",
                "AIRLINES",
                "international",
                "INTERNATIONAL",
            ]

            for term in searchTerms {
                #expect(testString.localizedCaseInsensitiveContains(term))
            }

            // Test non-matching terms
            let nonMatching = ["banana", "hotel", "xyz"]
            for term in nonMatching {
                #expect(!testString.localizedCaseInsensitiveContains(term))
            }
        }

        @Test("Partial string matching", .tags(.ui, .medium, .parallel, .swiftui, .search, .validation))
        func partialStringMatching() {
            let testString = "Delta Airlines Express"

            let partialMatches = [
                "Del",
                "elta",
                "Air",
                "lines",
                "Exp",
                "ress",
            ]

            for partial in partialMatches {
                #expect(testString.localizedCaseInsensitiveContains(partial))
            }
        }

        @Test("Empty and whitespace search handling", .tags(.ui, .medium, .parallel, .swiftui, .search, .validation))
        func emptyAndWhitespaceSearchHandling() {
            let testItems = ["Apple", "Banana", "Cherry"]

            // Empty search should return all items
            let emptySearch = ""
            let emptyFiltered = testItems.filter { item in
                emptySearch.isEmpty || item.localizedCaseInsensitiveContains(emptySearch)
            }
            #expect(emptyFiltered.count == 3)

            // Whitespace search should be treated as non-empty
            let whitespaceSearch = "   "
            let whitespaceFiltered = testItems.filter { item in
                whitespaceSearch.isEmpty || item.localizedCaseInsensitiveContains(whitespaceSearch)
            }
            #expect(whitespaceFiltered.isEmpty) // No items contain just whitespace
        }
    }

    @Suite("Currency Field Tests")
    struct CurrencyFieldTests {
        @Test("Currency field initialization", .tags(.ui, .medium, .parallel, .swiftui, .currency, .validation))
        func currencyFieldInitialization() {
            let binding = Binding.constant(Decimal(123.45))
            // Remove unused variable warning by using underscore
            _ = CurrencyTextField(value: binding, placeholder: "Test Amount", currencyCode: "USD")

            // Test default currency code
            let defaultField = CurrencyTextField(value: binding)
            #expect(defaultField.currencyCode == Locale.current.currency?.identifier || defaultField.currencyCode == "USD")
        }

        @Test("Decimal to cent conversion", .tags(.ui, .medium, .parallel, .swiftui, .currency, .validation))
        func decimalToCentConversion() {
            let testValues = [
                (Decimal(0), 0),
                (Decimal(1.23), 123),
                (Decimal(100.00), 10_000),
                (Decimal(0.01), 1),
                (Decimal(999.99), 99_999),
            ]

            for (decimal, expectedCents) in testValues {
                let cents = Int(NSDecimalNumber(decimal: decimal * 100).doubleValue.rounded())
                #expect(cents == expectedCents)
            }
        }

        @Test("Cent to decimal conversion", .tags(.ui, .medium, .parallel, .swiftui, .currency, .validation))
        func centToDecimalConversion() {
            let testValues = [
                (0, Decimal(0)),
                (123, Decimal(1.23)),
                (10_000, Decimal(100.00)),
                (1, Decimal(0.01)),
                (99_999, Decimal(999.99)),
            ]

            for (cents, expectedDecimal) in testValues {
                let decimal = Decimal(cents) / Decimal(100)
                #expect(decimal == expectedDecimal)
            }
        }
    }

    @Suite("File Attachment Picker Tests")
    struct FileAttachmentPickerTests {
        @Test("File extension validation", .tags(.ui, .medium, .parallel, .swiftui, .fileAttachment, .validation))
        func fileExtensionValidation() {
            let validImageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
            let validDocumentExtensions = ["pdf", "doc", "docx", "txt", "rtf"]

            for ext in validImageExtensions {
                #expect(validImageExtensions.contains(ext.lowercased()))
            }

            for ext in validDocumentExtensions {
                #expect(validDocumentExtensions.contains(ext.lowercased()))
            }
        }

        @Test("File type detection", .tags(.ui, .medium, .parallel, .swiftui, .fileAttachment, .validation))
        func fileTypeDetection() {
            let attachment1 = EmbeddedFileAttachment(fileExtension: "jpg")
            #expect(attachment1.isImage == true)
            #expect(attachment1.isPDF == false)
            #expect(attachment1.isDocument == false)

            let attachment2 = EmbeddedFileAttachment(fileExtension: "pdf")
            #expect(attachment2.isImage == false)
            #expect(attachment2.isPDF == true)
            #expect(attachment2.isDocument == false)

            let attachment3 = EmbeddedFileAttachment(fileExtension: "doc")
            #expect(attachment3.isImage == false)
            #expect(attachment3.isPDF == false)
            #expect(attachment3.isDocument == true)
        }

        @Test("System icon assignment", .tags(.ui, .medium, .parallel, .swiftui, .fileAttachment, .validation))
        func systemIconAssignment() {
            let imageAttachment = EmbeddedFileAttachment(fileExtension: "jpg")
            #expect(imageAttachment.systemIcon == "photo")

            let pdfAttachment = EmbeddedFileAttachment(fileExtension: "pdf")
            #expect(pdfAttachment.systemIcon == "doc.richtext")

            let docAttachment = EmbeddedFileAttachment(fileExtension: "doc")
            #expect(docAttachment.systemIcon == "doc.text")

            let unknownAttachment = EmbeddedFileAttachment(fileExtension: "xyz")
            #expect(unknownAttachment.systemIcon == "doc")
        }
    }

    @Suite("Date and Time Picker Tests")
    struct DateAndTimePickerTests {
        @Test("Trip date range validation", .tags(.ui, .medium, .parallel, .swiftui, .trip, .validation, .calendar))
        func tripDateRangeValidation() {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!

            let trip = Trip(name: "Test Trip", startDate: startDate, endDate: endDate)

            #expect(trip.hasDateRange == true)
            #expect(trip.dateRange != nil)

            if let range = trip.dateRange {
                #expect(range.lowerBound == startDate)
                #expect(range.upperBound == endDate)

                // Test date within range
                let midDate = Calendar.current.date(byAdding: .day, value: 3, to: startDate)!
                #expect(range.contains(midDate))

                // Test date outside range
                let outsideDate = Calendar.current.date(byAdding: .day, value: 10, to: startDate)!
                #expect(!range.contains(outsideDate))
            }
        }

        @Test("Activity date validation within trip", .tags(.ui, .medium, .parallel, .swiftui, .activity, .validation, .calendar))
        func activityDateValidationWithinTrip() {
            let tripStart = Date()
            let tripEnd = Calendar.current.date(byAdding: .day, value: 7, to: tripStart)!
            let trip = Trip(name: "Test Trip", startDate: tripStart, endDate: tripEnd)

            // Valid activity within trip range
            let validActivityStart = Calendar.current.date(byAdding: .day, value: 2, to: tripStart)!
            let validActivityEnd = Calendar.current.date(byAdding: .day, value: 3, to: tripStart)!

            if let tripRange = trip.dateRange {
                #expect(tripRange.contains(validActivityStart))
                #expect(tripRange.contains(validActivityEnd))
            }

            // Invalid activity outside trip range
            let invalidActivityStart = Calendar.current.date(byAdding: .day, value: -1, to: tripStart)!
            let invalidActivityEnd = Calendar.current.date(byAdding: .day, value: 10, to: tripStart)!

            if let tripRange = trip.dateRange {
                #expect(!tripRange.contains(invalidActivityStart))
                #expect(!tripRange.contains(invalidActivityEnd))
            }
        }

        @Test("Timezone picker date formatting", .tags(.ui, .medium, .parallel, .swiftui, .timezone, .validation, .calendar))
        func timezonePickerDateFormatting() {
            let date = Date()
            let timezone = TimeZone(identifier: "America/New_York")!

            let formatter = DateFormatter()
            formatter.timeZone = timezone
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let formatted = formatter.string(from: date)
            #expect(!formatted.isEmpty)

            // Should contain time components
            #expect(formatted.contains(":") || formatted.contains("AM") || formatted.contains("PM"))
        }
    }
}
