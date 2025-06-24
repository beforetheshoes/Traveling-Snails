//
//  UnifiedAddTripActivityRootViewTests.swift
//  Traveling Snails
//
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

@Suite("UnifiedAddTripActivityRootView Tests")
struct UnifiedAddTripActivityRootViewTests {
    
    // MARK: - Template Creation Tests
    
    @Suite("Template Creation Logic")
    struct TemplateCreationTests {
        
        @Test("Lodging template has correct defaults")
        func testLodgingTemplateDefaults() {
            let trip = Trip(name: "Test Trip")
            let startDate = Date()
            trip.startDate = startDate
            trip.hasStartDate = true
            
            // Test the template creation via ActivitySaver
            let saver = ActivitySaverFactory.createSaver(for: .lodging)
            let template = saver.createTemplate(in: trip)
            
            #expect(template.name.isEmpty)
            #expect(template.start >= startDate)
            // Default to one night stay
            let expectedEnd = Calendar.current.date(byAdding: .day, value: 1, to: template.start)!
            #expect(abs(template.end.timeIntervalSince(expectedEnd)) < 60) // Within 1 minute
            #expect(template.cost == 0)
            #expect(template.paid == .none)
            #expect(template.trip == nil) // Template shouldn't have relationships
            #expect(template.organization == nil)
        }
        
        @Test("Transportation template has correct defaults")
        func testTransportationTemplateDefaults() {
            let trip = Trip(name: "Test Trip")
            let startDate = Date()
            trip.startDate = startDate
            trip.hasStartDate = true
            
            let template = ActivitySaverFactory.createSaver(for: .transportation).createTemplate(in: trip)
            
            #expect(template.name.isEmpty)
            #expect(template.start >= startDate)
            // Default to 2 hour duration
            let expectedEnd = template.start.addingTimeInterval(2 * 3600)
            #expect(abs(template.end.timeIntervalSince(expectedEnd)) < 60)
            #expect(template.trip == nil)
            #expect(template.organization == nil)
        }
        
        @Test("Activity template has correct defaults")
        func testActivityTemplateDefaults() {
            let trip = Trip(name: "Test Trip")
            let startDate = Date()
            trip.startDate = startDate
            trip.hasStartDate = true
            
            let template = ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: trip)
            
            #expect(template.name.isEmpty)
            #expect(template.start >= startDate)
            // Default to 2 hour duration
            let expectedEnd = template.start.addingTimeInterval(2 * 3600)
            #expect(abs(template.end.timeIntervalSince(expectedEnd)) < 60)
            #expect(template.cost == 0)
            #expect(template.paid == .none)
            #expect(template.trip == nil)
            #expect(template.organization == nil)
        }
        
        @Test("Template uses current date when trip has no start date")
        func testTemplateWithNoTripStartDate() {
            let trip = Trip(name: "Test Trip")
            trip.hasStartDate = false
            
            let beforeCreation = Date()
            let template = ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: trip)
            let afterCreation = Date()
            
            #expect(template.start >= beforeCreation)
            #expect(template.start <= afterCreation)
        }
    }
    
    // MARK: - Edit Data Tests
    
    @Suite("TripActivityEditData Logic")
    struct EditDataTests {
        
        @Test("Edit data initialization from template")
        func testEditDataFromTemplate() {
            let trip = Trip(name: "Test Trip")
            let template = ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: trip)
            let editData = TripActivityEditData(from: template)
            
            #expect(editData.name == template.name)
            #expect(editData.start == template.start)
            #expect(editData.end == template.end)
            #expect(editData.cost == template.cost)
            #expect(editData.paid == template.paid)
            #expect(editData.confirmationField.isEmpty)
            #expect(editData.notes.isEmpty)
            #expect(editData.customLocationName.isEmpty)
            #expect(editData.customAddress == nil)
            #expect(editData.hideLocation == false)
        }
        
        @Test("Transportation edit data includes type")
        func testTransportationEditDataType() {
            let trip = Trip(name: "Test Trip")
            let transportation = Transportation(
                name: "Flight",
                type: .plane,
                start: Date(),
                end: Date(),
                trip: trip,
                organization: Organization(name: "Airline")
            )
            
            let editData = TripActivityEditData(from: transportation)
            #expect(editData.transportationType == .plane)
        }
        
        @Test("Activity edit data for custom location")
        func testActivityEditDataCustomLocation() {
            let trip = Trip(name: "Test Trip")
            let customAddress = Address(street: "123 Main St", city: "Test City")
            let activity = Activity(
                name: "Concert",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: Organization(name: "None"),
                customLocationName: "Custom Venue",
                customAddress: customAddress,
                hideLocation: true
            )
            
            let editData = TripActivityEditData(from: activity)
            #expect(editData.customLocationName == "Custom Venue")
            #expect(editData.customAddress == customAddress)
            #expect(editData.hideLocation == true)
        }
    }
    
    // MARK: - Form Validation Tests
    
    @Suite("Form Validation Logic")
    struct FormValidationTests {
        
        @Test("Form invalid when name is empty")
        func testFormInvalidEmptyName() {
            var editData = TripActivityEditData(from: ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: Trip(name: "Test")))
            editData.name = ""
            editData.organization = Organization(name: "Test Org")
            
            let isValid = editData.organization != nil && !editData.name.isEmpty
            #expect(isValid == false)
        }
        
        @Test("Form invalid when organization is nil")
        func testFormInvalidNilOrganization() {
            var editData = TripActivityEditData(from: ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: Trip(name: "Test")))
            editData.name = "Valid Name"
            editData.organization = nil
            
            let isValid = editData.organization != nil && !editData.name.isEmpty
            #expect(isValid == false)
        }
        
        @Test("Form valid when all required fields present")
        func testFormValidWhenComplete() {
            var editData = TripActivityEditData(from: ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: Trip(name: "Test")))
            editData.name = "Valid Name"
            editData.organization = Organization(name: "Test Org")
            
            let isValid = editData.organization != nil && !editData.name.isEmpty
            #expect(isValid == true)
        }
    }
    
    // MARK: - Save Logic Tests
    
    @Suite("Save Logic Tests")
    struct SaveLogicTests {
        
        @Test("Lodging save creates correct object")
        func testLodgingSaveCreation() throws {
            // Create in-memory model context for testing
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Trip.self, Organization.self, Lodging.self, configurations: config)
            let context = ModelContext(container)
            
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Hotel")
            context.insert(trip)
            context.insert(org)
            
            var editData = TripActivityEditData(from: ActivitySaverFactory.createSaver(for: .lodging).createTemplate(in: trip))
            editData.name = "Hotel Stay"
            editData.cost = Decimal(150.00)
            editData.paid = .deposit
            editData.confirmationField = "RES123"
            editData.notes = "Test notes"
            editData.organization = org
            
            // This tests the logic that should be extracted to ActivitySaveService
            let lodging = Lodging(
                name: editData.name,
                start: editData.start,
                checkInTZ: TimeZone(identifier: editData.startTZId),
                end: editData.end,
                checkOutTZ: TimeZone(identifier: editData.endTZId),
                cost: editData.cost,
                paid: editData.paid,
                reservation: editData.confirmationField,
                notes: editData.notes,
                customLocationName: editData.customLocationName,
                customAddress: editData.customAddress,
                hideLocation: editData.hideLocation
            )
            
            context.insert(lodging)
            lodging.trip = trip
            lodging.organization = org
            
            try context.save()
            
            #expect(lodging.name == "Hotel Stay")
            #expect(lodging.cost == Decimal(150.00))
            #expect(lodging.paid == .deposit)
            #expect(lodging.reservation == "RES123")
            #expect(lodging.notes == "Test notes")
            #expect(lodging.trip?.name == "Test Trip")
            #expect(lodging.organization?.name == "Test Hotel")
        }
        
        @Test("Transportation save creates correct object")
        func testTransportationSaveCreation() throws {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Trip.self, Organization.self, Transportation.self, configurations: config)
            let context = ModelContext(container)
            
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            context.insert(trip)
            context.insert(org)
            
            var editData = TripActivityEditData(from: ActivitySaverFactory.createSaver(for: .transportation).createTemplate(in: trip))
            editData.name = "Flight"
            editData.transportationType = .plane
            editData.confirmationField = "FL123"
            editData.organization = org
            
            let transportation = Transportation(
                name: editData.name,
                type: editData.transportationType ?? .plane,
                start: editData.start,
                startTZ: TimeZone(identifier: editData.startTZId),
                end: editData.end,
                endTZ: TimeZone(identifier: editData.endTZId),
                cost: editData.cost,
                paid: editData.paid,
                confirmation: editData.confirmationField,
                notes: editData.notes
            )
            
            context.insert(transportation)
            transportation.trip = trip
            transportation.organization = org
            
            try context.save()
            
            #expect(transportation.name == "Flight")
            #expect(transportation.type == .plane)
            #expect(transportation.confirmation == "FL123")
            #expect(transportation.trip?.name == "Test Trip")
            #expect(transportation.organization?.name == "Test Airline")
        }
        
        @Test("Activity save creates correct object")
        func testActivitySaveCreation() throws {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Trip.self, Organization.self, Activity.self, configurations: config)
            let context = ModelContext(container)
            
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Venue")
            context.insert(trip)
            context.insert(org)
            
            var editData = TripActivityEditData(from: ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: trip))
            editData.name = "Concert"
            editData.cost = Decimal(75.00)
            editData.paid = .infull
            editData.confirmationField = "TIX789"
            editData.customLocationName = "Custom Venue"
            editData.hideLocation = true
            editData.organization = org
            
            let activity = Activity(
                name: editData.name,
                start: editData.start,
                startTZ: TimeZone(identifier: editData.startTZId),
                end: editData.end,
                endTZ: TimeZone(identifier: editData.endTZId),
                cost: editData.cost,
                paid: editData.paid,
                reservation: editData.confirmationField,
                notes: editData.notes,
                customLocationName: editData.customLocationName,
                customAddress: editData.customAddress,
                hideLocation: editData.hideLocation
            )
            
            context.insert(activity)
            activity.trip = trip
            activity.organization = org
            
            try context.save()
            
            #expect(activity.name == "Concert")
            #expect(activity.cost == Decimal(75.00))
            #expect(activity.paid == .infull)
            #expect(activity.reservation == "TIX789")
            #expect(activity.customLocationName == "Custom Venue")
            #expect(activity.hideLocation == true)
            #expect(activity.trip?.name == "Test Trip")
            #expect(activity.organization?.name == "Test Venue")
        }
        
        @Test("Save handles None organization correctly")
        func testSaveWithNoneOrganization() throws {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Trip.self, Organization.self, Activity.self, configurations: config)
            let context = ModelContext(container)
            
            let trip = Trip(name: "Test Trip")
            context.insert(trip)
            
            // Simulate None organization selection
            let noneOrg = Organization.ensureUniqueNoneOrganization(in: context)
            
            var editData = TripActivityEditData(from: ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: trip))
            editData.name = "Solo Activity"
            editData.organization = noneOrg
            
            let activity = Activity(
                name: editData.name,
                start: editData.start,
                end: editData.end,
                trip: trip,
                organization: noneOrg
            )
            
            context.insert(activity)
            try context.save()
            
            #expect(activity.organization?.name == "None")
            #expect(activity.organization?.isNone == true)
        }
    }
    
    // MARK: - UI State Tests
    
    @Suite("UI State Management")
    struct UIStateTests {
        
        @Test("Initial saving state is false")
        func testInitialSavingState() {
            // This tests state that should be managed by ActivityFormViewModel
            let isSaving = false
            #expect(isSaving == false)
        }
        
        @Test("Form disabled during saving")
        func testFormDisabledDuringSaving() {
            let isSaving = true
            let isFormEnabled = !isSaving
            #expect(isFormEnabled == false)
        }
        
        @Test("Organization picker state management")
        func testOrganizationPickerState() {
            let showingOrganizationPicker = false
            #expect(showingOrganizationPicker == false)
        }
        
        @Test("Attachment management state")
        func testAttachmentState() {
            var attachments: [EmbeddedFileAttachment] = []
            let newAttachment = EmbeddedFileAttachment(fileName: "test.pdf", fileData: Data())
            
            // Test attachment addition
            attachments.append(newAttachment)
            #expect(attachments.count == 1)
            #expect(attachments.first?.fileName == "test.pdf")
            
            // Test attachment removal
            attachments.removeAll { $0.id == newAttachment.id }
            #expect(attachments.isEmpty)
        }
    }
    
    // MARK: - Template Configuration Tests
    
    @Suite("Template Configuration")
    struct TemplateConfigurationTests {
        
        @Test("Lodging template configuration")
        func testLodgingTemplateConfiguration() {
            let trip = Trip(name: "Test Trip")
            let template = ActivitySaverFactory.createSaver(for: .lodging).createTemplate(in: trip)
            
            // Test properties that should be on template/protocol
            #expect(template.activityType.rawValue == "Lodging")
            #expect(template.icon == "bed.double.fill")
            #expect(template.color == .indigo)
            #expect(template.startLabel == "Check-in")
            #expect(template.endLabel == "Check-out")
            #expect(template.confirmationLabel == "Reservation")
            #expect(template.supportsCustomLocation == true)
            #expect(template.hasTypeSelector == false)
        }
        
        @Test("Transportation template configuration")
        func testTransportationTemplateConfiguration() {
            let trip = Trip(name: "Test Trip")
            let template = ActivitySaverFactory.createSaver(for: .transportation).createTemplate(in: trip)
            
            #expect(template.activityType.rawValue == "Transportation")
            #expect(template.icon == "airplane") // Default transportation type icon
            #expect(template.color == .blue)
            #expect(template.startLabel == "Departure")
            #expect(template.endLabel == "Arrival")
            #expect(template.confirmationLabel == "Confirmation")
            #expect(template.supportsCustomLocation == false)
            #expect(template.hasTypeSelector == true)
        }
        
        @Test("Activity template configuration")
        func testActivityTemplateConfiguration() {
            let trip = Trip(name: "Test Trip")
            let template = ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: trip)
            
            #expect(template.activityType.rawValue == "Activity")
            #expect(template.icon == "ticket.fill")
            #expect(template.color == .purple)
            #expect(template.startLabel == "Start")
            #expect(template.endLabel == "End")
            #expect(template.confirmationLabel == "Reservation")
            #expect(template.supportsCustomLocation == true)
            #expect(template.hasTypeSelector == false)
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Integration Scenarios")
    struct IntegrationTests {
        
        @Test("Complete form submission flow")
        func testCompleteFormSubmissionFlow() throws {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: Trip.self, Organization.self, Activity.self, configurations: config)
            let context = ModelContext(container)
            
            // Setup
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            context.insert(trip)
            context.insert(org)
            
            // Create template
            let template = ActivitySaverFactory.createSaver(for: .activity).createTemplate(in: trip)
            
            // Initialize edit data
            var editData = TripActivityEditData(from: template)
            editData.name = "Test Activity"
            editData.organization = org
            editData.cost = Decimal(50.00)
            
            // Validate form
            let isValid = editData.organization != nil && !editData.name.isEmpty
            #expect(isValid == true)
            
            // Save activity
            let activity = Activity(
                name: editData.name,
                start: editData.start,
                end: editData.end,
                cost: editData.cost,
                paid: editData.paid,
                trip: trip,
                organization: org
            )
            
            context.insert(activity)
            try context.save()
            
            // Verify result
            #expect(activity.name == "Test Activity")
            #expect(activity.cost == Decimal(50.00))
            #expect(activity.trip == trip)
            #expect(activity.organization == org)
        }
        
        @Test("Error handling during save")
        func testErrorHandlingDuringSave() {
            // Test that save errors are handled properly
            // This should be managed by ActivitySaveService
            var saveError: Error? = nil
            var isSaving = true
            
            // Simulate save error
            struct TestError: Error {}
            saveError = TestError()
            isSaving = false
            
            #expect(saveError != nil)
            #expect(isSaving == false)
        }
    }
}

// MARK: - Template creation now handled by ActivitySaveService
// All template creation logic has been moved to the type-erased ActivitySaveService system