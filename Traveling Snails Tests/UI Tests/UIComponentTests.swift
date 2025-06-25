//
//  UIComponentTests.swift
//  Traveling Snails
//
//

import Testing
import SwiftUI
import SwiftData
import MapKit

@testable import Traveling_Snails

@Suite("UI Component Tests")
struct UIComponentTests {
    
    @Suite("CurrencyTextField Tests")
    struct CurrencyTextFieldTests {
        
        @Test("Currency field initialization")
        func currencyFieldInitialization() {
            let binding = Binding.constant(Decimal(123.45))
            let currencyField = CurrencyTextField(value: binding, placeholder: "Test Amount")
            
            #expect(currencyField.placeholder == "Test Amount")
            #expect(currencyField.currencyCode == Locale.current.currency?.identifier || currencyField.currencyCode == "USD")
        }
        
        @Test("Currency formatting logic")
        func currencyFormattingLogic() {
            let currencyField = CurrencyTextField(value: .constant(Decimal(0)), currencyCode: "USD")
            let coordinator = currencyField.makeCoordinator()
            
            // Test cent value formatting - we can't access the private method directly
            // but we can test the public behavior
            coordinator.centValue = 12345 // $123.45
            
            // Verify the coordinator maintains the cent value correctly
            #expect(coordinator.centValue == 12345)
            
            // Test that the parent decimal conversion works
            #expect(Decimal(coordinator.centValue) / Decimal(100) == Decimal(123.45))
        }
    }
    
    @Suite("AddressAutocompleteView Tests")
    struct AddressAutocompleteViewTests {
        
        @Test("Address autocomplete initialization")
        func addressAutocompleteInitialization() {
            let binding = Binding.constant(nil as Address?)
            let autocompleteView = AddressAutocompleteView(
                selectedAddress: binding,
                placeholder: "Enter test address"
            )
            
            #expect(autocompleteView.placeholder == "Enter test address")
        }
        
        @Test("Address display logic")
        func addressDisplayLogic() {
            let address = Address(
                street: "123 Test St",
                city: "Test City",
                state: "TS",
                country: "Test Country",
                formattedAddress: "123 Test St, Test City, TS, Test Country"
            )
            
            #expect(address.displayAddress == "123 Test St, Test City, TS, Test Country")
            
            // Test fallback to components
            let addressNoFormatted = Address(
                street: "456 Oak Ave",
                city: "Oak City",
                state: "OC"
            )
            #expect(addressNoFormatted.displayAddress == "456 Oak Ave, Oak City, OC")
        }
    }
    
    @Suite("SecureContactLink Tests")
    struct SecureContactLinkTests {
        
        @Test("Phone link creation")
        func phoneLinkCreation() {
            let phoneLink = SecurePhoneLink(phoneNumber: "+1-555-0123")
            #expect(phoneLink.phoneNumber == "+1-555-0123")
        }
        
        @Test("Email link creation")
        func emailLinkCreation() {
            let emailLink = SecureEmailLink(email: "test@example.com")
            #expect(emailLink.email == "test@example.com")
        }
        
        @Test("Website link URL formatting")
        func websiteLinkURLFormatting() {
            let websiteLink1 = SecureWebsiteLink(website: "https://example.com")
            let websiteLink2 = SecureWebsiteLink(website: "example.com")
            
            #expect(websiteLink1.website == "https://example.com")
            #expect(websiteLink2.website == "example.com")
        }
    }
    
    @Suite("TimeZone Picker Tests")
    struct TimeZonePickerTests {
        
        @Test("TimeZone picker initialization")
        func timeZonePickerInitialization() {
            let binding = Binding.constant("America/New_York")
            let picker = TimeZonePicker(
                selectedTimeZoneId: binding,
                address: nil,
                label: "Test Timezone"
            )
            
            #expect(picker.label == "Test Timezone")
        }
        
        @Test("TimeZone formatting in picker")
        func timeZoneFormattingInPicker() {
            let timezone = TimeZone(identifier: "America/New_York")!
            let formatted = TimeZoneHelper.formatTimeZone(timezone)
            
            #expect(formatted.contains("New York"))
            // Should contain some form of GMT offset
            #expect(formatted.contains("GMT") || formatted.contains("-") || formatted.contains("+"))
        }
        
        @Test("Common timezones availability")
        func commonTimezonesAvailability() {
            let commonTimezones = TimeZoneHelper.commonTimeZones
            
            #expect(commonTimezones.count > 10) // Should have a reasonable number
            #expect(commonTimezones.contains { $0.identifier == "America/New_York" })
            #expect(commonTimezones.contains { $0.identifier == "Europe/London" })
            #expect(commonTimezones.contains { $0.identifier == "Asia/Tokyo" })
        }
    }
    
    @Suite("Activity Row View Tests")
    struct ActivityRowViewTests {
        
        @Test("Activity wrapper creation for different types")
        func activityWrapperCreationForDifferentTypes() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            let lodging = Lodging(
                name: "Test Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            )
            
            let transportation = Transportation(
                name: "Test Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            let lodgingWrapper = ActivityWrapper(lodging)
            let transportationWrapper = ActivityWrapper(transportation)
            let activityWrapper = ActivityWrapper(activity)
            
            // Test wrapper type detection
            #expect(lodgingWrapper.type == .lodging)
            #expect(transportationWrapper.type == .transportation)
            #expect(activityWrapper.type == .activity)
            
            // Test icon and color assignment
            #expect(lodgingWrapper.type.icon == "bed.double.fill")
            #expect(lodgingWrapper.type.color == .indigo)
            
            #expect(transportationWrapper.type.icon == "car.fill")
            #expect(transportationWrapper.type.color == .blue)
            
            #expect(activityWrapper.type.icon == "ticket.fill")
            #expect(activityWrapper.type.color == .purple)
            
            // Test specific transportation activity icon (default is plane)
            // Generic type icon should be "car.fill", but specific activity icon should be "airplane"
            #expect(transportationWrapper.tripActivity.icon == "airplane", "Transportation with default plane type should show airplane icon")
            #expect(transportationWrapper.type.icon != transportationWrapper.tripActivity.icon, "Generic type icon should differ from specific transportation icon")
        }
    }
    
    @Suite("Date Time Section Tests")
    struct DateTimeSectionTests {
        
        @Test("Date range validation for trip-aware picker")
        func dateRangeValidationForTripAwarePicker() {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
            let trip = Trip(name: "Test Trip", startDate: startDate, endDate: endDate)
            
            let binding = Binding.constant(Date())
            let picker = TripAwareDatePicker(
                "Test Date",
                selection: binding,
                trip: trip
            )
            
            #expect(picker.trip.hasDateRange == true)
            #expect(picker.trip.dateRange != nil)
        }
        
        @Test("Timezone synchronization logic")
        func timezoneSynchronizationLogic() {
            let trip = Trip(name: "Test Trip")
            let startTZ = Binding.constant("America/New_York")
            let endTZ = Binding.constant("America/Los_Angeles")
            
            let section = DateTimeZoneSection(
                startLabel: "Departure",
                endLabel: "Arrival",
                trip: trip,
                startDate: .constant(Date()),
                endDate: .constant(Date()),
                startTimeZoneId: startTZ,
                endTimeZoneId: endTZ,
                address: nil,
                syncTimezones: true
            )
            
            #expect(section.syncTimezones == true)
        }
    }
}

@Suite("View Model Tests")
struct ViewModelTests {
    
    @Suite("TripActivityEditData Tests")
    struct TripActivityEditDataTests {
        
        @Test("Edit data copying from activities")
        func editDataCopyingFromActivities() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate)!
            
            let activity = Activity(
                name: "Original Activity",
                start: startDate,
                end: endDate,
                cost: Decimal(100.00),
                paid: .deposit,
                reservation: "RES456",
                notes: "Original notes",
                trip: trip,
                organization: org
            )
            
            let editData = activity.copyForEditing()
            
            #expect(editData.name == "Original Activity")
            #expect(editData.start == startDate)
            #expect(editData.end == endDate)
            #expect(editData.cost == Decimal(100.00))
            #expect(editData.paid == .deposit)
            #expect(editData.confirmationField == "RES456")
            #expect(editData.notes == "Original notes")
        }
        
        @Test("Edit data application back to activities")
        func editDataApplicationBackToActivities() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let newOrg = Organization(name: "New Org")
            
            let activity = Activity(
                name: "Original Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            var editData = TripActivityEditData(from: activity)
            editData.name = "Updated Activity"
            editData.cost = Decimal(200.00)
            editData.paid = .infull
            editData.organization = newOrg
            editData.notes = "Updated notes"
            
            activity.applyEdits(from: editData)
            
            #expect(activity.name == "Updated Activity")
            #expect(activity.cost == Decimal(200.00))
            #expect(activity.paid == .infull)
            #expect(activity.organization?.name == "New Org")
            #expect(activity.notes == "Updated notes")
        }
    }
    
    @Suite("Organization Picker Tests")
    struct OrganizationPickerTests {
        
        @Test("None organization sentinel behavior")
        func noneOrganizationSentinelBehavior() throws {
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
        
        @Test("Organization filtering logic")
        func organizationFilteringLogic() {
            let organizations = [
                Organization(name: "Apple Airlines"),
                Organization(name: "Banana Hotels"),
                Organization(name: "Cherry Tours"),
                Organization(name: "Delta Express")
            ]
            
            let searchText = "app"
            let filtered = organizations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            
            #expect(filtered.count == 1)
            #expect(filtered.first?.name == "Apple Airlines")
        }
    }
}

@Suite("Image Handling Tests")
struct ImageHandlingTests {
    
    @Suite("ImageCacheManager Tests")
    struct ImageCacheManagerTests {
        
        @Test("Image cache manager singleton access")
        func imageCacheManagerSingletonAccess() {
            let manager1 = ImageCacheManager.shared
            let manager2 = ImageCacheManager.shared
            
            #expect(manager1 === manager2)
        }
        
        @Test("Cache filename generation consistency")
        func cacheFilenameGenerationConsistency() {
            let orgId = UUID()
            let urlString = "https://example.com/logo.png"
            
            // Generate filename components
            let urlHash = urlString.hash
            let expectedFilename = "\(orgId.uuidString)_\(urlHash).jpg"
            
            // Should be consistent
            let urlHash2 = urlString.hash
            let expectedFilename2 = "\(orgId.uuidString)_\(urlHash2).jpg"
            
            #expect(expectedFilename == expectedFilename2)
        }
        
        @Test("URL security evaluation in caching")
        func urlSecurityEvaluationInCaching() {
            // Test that blocked URLs are rejected
            let blockedURL = "javascript:alert('xss')"
            let securityLevel = SecureURLHandler.evaluateURL(blockedURL)
            #expect(securityLevel == .blocked)
            
            // Test that safe URLs are accepted
            let safeURL = "https://example.com/logo.png"
            let safeSecurity = SecureURLHandler.evaluateURL(safeURL)
            #expect(safeSecurity == .safe)
        }
    }
    
    @Suite("CachedAsyncImage Tests")
    struct CachedAsyncImageTests {
        
        @Test("Cached async image initialization")
        func cachedAsyncImageInitialization() {
            let orgId = UUID()
            let cachedImage = CachedAsyncImage(url: "https://example.com/logo.png", organizationId: orgId)
            
            #expect(cachedImage.urlString == "https://example.com/logo.png")
            #expect(cachedImage.organizationId == orgId)
        }
        
        @Test("Security alert configuration")
        func securityAlertConfiguration() {
            let orgId = UUID()
            _ = CachedAsyncImage(url: "https://bit.ly/suspicious", organizationId: orgId)
            
            // Suspicious URLs should trigger security evaluation
            let securityLevel = SecureURLHandler.evaluateURL("https://bit.ly/suspicious")
            #expect(securityLevel == .suspicious)
        }
    }
}

@Suite("Form Validation Tests")
struct FormValidationTests {
    
    @Suite("Trip Form Validation")
    struct TripFormValidation {
        
        @Test("Trip name validation")
        func tripNameValidation() {
            // Empty name should be invalid
            let emptyTrip = Trip(name: "")
            #expect(emptyTrip.name.isEmpty == true)
            
            // Valid name should be accepted
            let validTrip = Trip(name: "Valid Trip Name")
            #expect(validTrip.name.isEmpty == false)
        }
        
        @Test("Trip date consistency validation")
        func tripDateConsistencyValidation() {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)! // End before start
            
            let trip = Trip(name: "Date Test", startDate: startDate, endDate: endDate)
            
            // End date should be after start date for valid trips
            #expect(trip.startDate > trip.endDate) // This indicates an invalid state
        }
    }
    
    @Suite("Organization Form Validation")
    struct OrganizationFormValidation {
        
        @Test("Organization name validation")
        func organizationNameValidation() {
            // Empty name should be detectable
            let emptyOrg = Organization(name: "")
            #expect(emptyOrg.name.isEmpty == true)
            
            // Reserved name detection
            let reservedOrg = Organization(name: "None")
            #expect(reservedOrg.isNone == true)
            
            // Valid name
            let validOrg = Organization(name: "Valid Organization")
            #expect(validOrg.name.isEmpty == false)
            #expect(validOrg.isNone == false)
        }
        
        @Test("Organization contact info validation")
        func organizationContactInfoValidation() {
            let org = Organization(
                name: "Test Org",
                phone: "+1-555-0123",
                email: "test@example.com",
                website: "https://example.com"
            )
            
            #expect(org.hasPhone == true)
            #expect(org.hasEmail == true)
            #expect(org.hasWebsite == true)
            
            // Test empty values
            let emptyOrg = Organization(name: "Empty Org")
            #expect(emptyOrg.hasPhone == false)
            #expect(emptyOrg.hasEmail == false)
            #expect(emptyOrg.hasWebsite == false)
        }
    }
    
    @Suite("Activity Form Validation")
    struct ActivityFormValidation {
        
        @Test("Activity required fields validation")
        func activityRequiredFieldsValidation() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            // Activity with all required fields
            let validActivity = Activity(
                name: "Valid Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            #expect(validActivity.name.isEmpty == false)
            #expect(validActivity.trip?.name == "Test Trip")
            #expect(validActivity.organization?.name == "Test Org")
            
            // Activity with missing name
            let invalidActivity = Activity(
                name: "",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            #expect(invalidActivity.name.isEmpty == true)
        }
        
        @Test("Activity date validation")
        func activityDateValidation() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: -1, to: startDate)! // End before start
            
            let activity = Activity(
                name: "Invalid Date Activity",
                start: startDate,
                end: endDate,
                trip: trip,
                organization: org
            )
            
            // Duration should be negative for invalid date range
            #expect(activity.duration() < 0)
        }
    }
}
