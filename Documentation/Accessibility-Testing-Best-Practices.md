# Accessibility Testing Best Practices for SwiftUI + SwiftData Applications

## Table of Contents

1. [Foundation Principles](#foundation-principles)
2. [Testing Frameworks & APIs](#testing-frameworks--apis)
3. [SwiftData-Specific Accessibility Patterns](#swiftdata-specific-accessibility-patterns)
4. [VoiceOver Testing Patterns](#voiceover-testing-patterns)
5. [Switch Control Testing Patterns](#switch-control-testing-patterns)
6. [Voice Control Testing Patterns](#voice-control-testing-patterns)
7. [Screen Reader Testing Patterns](#screen-reader-testing-patterns)
8. [Implementation Guidelines](#implementation-guidelines)
9. [Performance Testing](#performance-testing)
10. [CI/CD Integration](#cicd-integration)
11. [Manual Testing Requirements](#manual-testing-requirements)

## Foundation Principles

### WCAG 2.1 AA Compliance for Mobile Applications

**Core Requirements:**
- **Perceivable**: All UI elements must be accessible to assistive technologies
- **Operable**: Interface must be navigable via assistive technologies
- **Understandable**: Content and functionality must be comprehensible
- **Robust**: Content must work across assistive technologies

### Apple Human Interface Guidelines Integration

**Key Guidelines:**
- Minimum touch target size: 44x44 points
- Meaningful accessibility labels (not just button text)
- Proper accessibility traits and hints
- Support for Dynamic Type (up to AX5 sizes)
- High contrast mode compatibility

### SwiftData Accessibility Considerations

**Critical Patterns:**
- Model accessibility doesn't break during background context operations
- Query results maintain accessibility during data updates
- CloudKit sync preserves accessibility information
- Large dataset queries don't degrade accessibility performance

## Testing Frameworks & APIs

### Swift Testing Framework Integration

**Modern Test Structure:**
```swift
@Suite("Accessibility Validation Suite")
@MainActor
struct AccessibilityTests {
    
    @Test("Basic accessibility audit compliance")
    func basicAccessibilityAudit() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Modern iOS 15+ comprehensive accessibility audit
        try app.performAccessibilityAudit()
    }
    
    @Test("Dynamic Type accessibility support")
    func dynamicTypeSupport() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test specific accessibility aspect
        try app.performAccessibilityAudit(for: .dynamicType)
    }
    
    @Test("Color contrast validation") 
    func colorContrastValidation() async throws {
        let app = XCUIApplication()
        app.launch()
        
        try app.performAccessibilityAudit(for: .contrast)
    }
}
```

### Custom Accessibility Test Engines

**Base Test Engine Pattern:**
```swift
protocol AccessibilityTestEngine {
    associatedtype TestCase
    
    func validateAccessibility(for testCase: TestCase) -> AccessibilityValidationResult
    func generateAccessibilityReport() -> AccessibilityReport
}

struct AccessibilityValidationResult {
    let isValid: Bool
    let violations: [AccessibilityViolation]
    let recommendations: [String]
}
```

## SwiftData-Specific Accessibility Patterns

### Model Context Accessibility Testing

**Background Context Pattern:**
```swift
@Test("SwiftData background context accessibility preservation")
func testBackgroundContextAccessibility() async throws {
    let testBase = SwiftDataTestBase()
    
    // Create model with accessibility information
    let trip = Trip(name: "Accessible Trip")
    trip.accessibilityLabel = "Summer vacation trip"
    trip.accessibilityHint = "Double tap to view trip details"
    
    testBase.modelContext.insert(trip)
    try testBase.modelContext.save()
    
    // Test background context operation
    let backgroundContext = testBase.container.newBackgroundContext()
    
    await backgroundContext.perform {
        let descriptor = FetchDescriptor<Trip>(predicate: #Predicate<Trip> { $0.id == trip.id })
        let fetchedTrips = try? backgroundContext.fetch(descriptor)
        let fetchedTrip = fetchedTrips?.first
        
        #expect(fetchedTrip?.accessibilityLabel == "Summer vacation trip")
        #expect(fetchedTrip?.accessibilityHint == "Double tap to view trip details")
    }
}
```

### Query Result Accessibility

**Large Dataset Pattern:**
```swift
@Test("Large dataset accessibility performance")
func testLargeDatasetAccessibility() async throws {
    let testBase = SwiftDataTestBase()
    
    // Create large dataset
    for i in 1...1000 {
        let trip = Trip(name: "Trip \(i)")
        trip.generateAccessibilityInfo() // Extension method
        testBase.modelContext.insert(trip)
    }
    try testBase.modelContext.save()
    
    // Test accessibility performance with large results
    let startTime = Date()
    
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to trips list - should load accessibility info efficiently
    let tripsList = app.collectionViews["TripsListView"]
    #expect(tripsList.exists)
    
    let endTime = Date()
    let timeInterval = endTime.timeIntervalSince(startTime)
    
    // Accessibility should not significantly impact performance
    #expect(timeInterval < 2.0, "Accessibility loading should complete within 2 seconds")
    
    // Verify accessibility is properly applied
    let firstTrip = tripsList.cells.firstMatch
    #expect(firstTrip.exists)
    #expect(!firstTrip.label.isEmpty)
}
```

## VoiceOver Testing Patterns

### Navigation Testing

**VoiceOver Navigation Flow:**
```swift
@Suite("VoiceOver Navigation Tests")
@MainActor 
struct VoiceOverNavigationTests {
    
    @Test("VoiceOver navigation order in trip list")
    func testVoiceOverNavigationOrder() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Simulate VoiceOver navigation
        let navigationElements = app.descendants(matching: .any)
            .allElementsBoundByAccessibilityElement
        
        // Verify logical navigation order
        var previousFrame = CGRect.zero
        for element in navigationElements {
            let currentFrame = element.frame
            
            // Verify elements are in logical reading order (top-to-bottom, left-to-right)
            if !previousFrame.isEmpty {
                #expect(currentFrame.origin.y >= previousFrame.origin.y - 10,
                       "Elements should follow logical reading order")
            }
            
            previousFrame = currentFrame
        }
    }
    
    @Test("VoiceOver error announcement priority")
    func testVoiceOverErrorAnnouncement() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Trigger an error condition
        let tripNameField = app.textFields["TripNameField"]
        tripNameField.tap()
        tripNameField.typeText("") // Empty name should trigger error
        
        let saveButton = app.buttons["SaveTripButton"]
        saveButton.tap()
        
        // Check for error announcement
        let errorAlert = app.alerts.firstMatch
        #expect(errorAlert.exists, "Error should be announced via alert")
        
        // Verify accessibility properties
        #expect(!errorAlert.label.isEmpty, "Error should have meaningful label")
        #expect(errorAlert.isAccessibilityElement, "Error should be accessibility element")
    }
}
```

### VoiceOver Gesture Testing

**Custom Gesture Patterns:**
```swift
@Test("VoiceOver custom actions for trip management")
func testVoiceOverCustomActions() async throws {
    let app = XCUIApplication()
    app.launch()
    
    let tripRow = app.cells["TripRow_0"]
    #expect(tripRow.exists)
    
    // Test custom accessibility actions
    let customActions = tripRow.customActions
    
    #expect(customActions.count >= 2, "Trip should have edit and delete custom actions")
    
    // Verify action names are meaningful
    let actionNames = customActions.map { $0.name }
    #expect(actionNames.contains("Edit Trip"), "Should have Edit Trip action")
    #expect(actionNames.contains("Delete Trip"), "Should have Delete Trip action")
}
```

## Switch Control Testing Patterns

### Tab Order Validation

**Switch Control Navigation:**
```swift
@Suite("Switch Control Navigation Tests")
@MainActor
struct SwitchControlTests {
    
    @Test("Switch Control tab order in edit trip view")
    func testSwitchControlTabOrder() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to edit trip view
        let addButton = app.buttons["AddTripButton"]
        addButton.tap()
        
        // Get all focusable elements in logical order
        let focusableElements = [
            app.textFields["TripNameField"],
            app.textFields["TripNotesField"], 
            app.switches["StartDateToggle"],
            app.datePickers["StartDatePicker"],
            app.switches["EndDateToggle"],
            app.datePickers["EndDatePicker"],
            app.buttons["SaveTripButton"],
            app.buttons["CancelButton"]
        ]
        
        // Verify all elements are accessible via Switch Control
        for element in focusableElements {
            if element.exists {
                #expect(element.isAccessibilityElement || element.children(matching: .any).count > 0,
                       "Element should be focusable by Switch Control")
            }
        }
    }
    
    @Test("Switch Control group navigation support")
    func testSwitchControlGroupNavigation() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to trip details with multiple sections
        let firstTrip = app.cells.firstMatch
        firstTrip.tap()
        
        // Verify sections are properly grouped for Switch Control
        let lodgingSection = app.otherElements["LodgingSection"]
        let transportationSection = app.otherElements["TransportationSection"]
        let activitiesSection = app.otherElements["ActivitiesSection"]
        
        // Each section should be navigable as a group
        for section in [lodgingSection, transportationSection, activitiesSection] {
            if section.exists {
                #expect(section.isAccessibilityElement || 
                       section.accessibilityElementsHidden == false,
                       "Section should support group navigation")
            }
        }
    }
}
```

### Escape Route Testing

**Emergency Navigation:**
```swift
@Test("Switch Control escape routes")
func testSwitchControlEscapeRoutes() async throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate deep into the app
    let firstTrip = app.cells.firstMatch
    firstTrip.tap()
    
    let firstActivity = app.cells.containing(.staticText, identifier: "ActivityCell").firstMatch
    firstActivity.tap()
    
    // Verify escape routes exist at each level
    let backButton = app.buttons["BackButton"]
    let closeButton = app.buttons["CloseButton"] 
    let cancelButton = app.buttons["CancelButton"]
    
    let escapeRoutes = [backButton, closeButton, cancelButton].filter { $0.exists }
    
    #expect(!escapeRoutes.isEmpty, "At least one escape route should be available")
    
    // Test escape route functionality
    if let escapeRoute = escapeRoutes.first {
        escapeRoute.tap()
        
        // Should navigate back or dismiss
        #expect(!firstActivity.exists || !firstTrip.exists,
               "Escape route should navigate back")
    }
}
```

## Voice Control Testing Patterns

### Voice Command Recognition

**Voice Control Commands:**
```swift
@Suite("Voice Control Integration Tests")
@MainActor
struct VoiceControlTests {
    
    @Test("Voice Control command recognition for trip management")
    func testVoiceControlCommands() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test that buttons have appropriate Voice Control names
        let addButton = app.buttons["AddTripButton"]
        #expect(addButton.exists)
        #expect(!addButton.label.isEmpty, "Button should have voice-friendly label")
        
        // Voice Control should work with "Tap Add Trip" command
        let expectedVoiceCommands = [
            "Tap Add Trip",
            "Add Trip", 
            "Tap Add"
        ]
        
        // Verify button label supports voice commands
        let buttonLabel = addButton.label.lowercased()
        let supportsVoiceCommand = expectedVoiceCommands.contains { command in
            buttonLabel.contains(command.lowercased().replacingOccurrences(of: "tap ", with: ""))
        }
        
        #expect(supportsVoiceCommand, "Button should support Voice Control commands")
    }
    
    @Test("Voice Control dictation support in text fields")
    func testVoiceControlDictation() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let addButton = app.buttons["AddTripButton"]
        addButton.tap()
        
        let nameField = app.textFields["TripNameField"]
        nameField.tap()
        
        // Verify text field supports dictation
        #expect(nameField.isAccessibilityElement, "Text field should be accessibility element")
        #expect(!nameField.placeholderValue?.isEmpty ?? false, "Should have meaningful placeholder")
        
        // Test that field accepts text input (simulating dictation)
        nameField.typeText("Summer Vacation")
        #expect(nameField.value as? String == "Summer Vacation",
               "Field should accept dictated text")
    }
}
```

### Numbered Command Support

**Numbered Element Access:**
```swift
@Test("Voice Control numbered commands")
func testVoiceControlNumberedCommands() async throws {
    let app = XCUIApplication()
    app.launch()
    
    // Get list of interactive elements that should support numbered commands
    let interactiveElements = app.descendants(matching: .any).allElementsBoundByIndex
        .filter { element in
            element.elementType == .button || 
            element.elementType == .textField ||
            element.elementType == .cell
        }
    
    // Voice Control assigns numbers to interactive elements
    for (index, element) in interactiveElements.enumerated() {
        if element.exists && element.isAccessibilityElement {
            #expect(!element.label.isEmpty, 
                   "Element \(index + 1) should have label for Voice Control")
        }
    }
    
    // Test specific numbered access patterns
    if interactiveElements.count >= 3 {
        let thirdElement = interactiveElements[2]
        
        // Simulate "Tap 3" voice command
        if thirdElement.exists {
            thirdElement.tap()
            // Should respond to numbered command
        }
    }
}
```

## Screen Reader Testing Patterns

### Content Structure Validation

**Semantic Structure:**
```swift
@Suite("Screen Reader Content Structure Tests")
@MainActor
struct ScreenReaderTests {
    
    @Test("Screen reader heading hierarchy")
    func testScreenReaderHeadingHierarchy() async throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to trip details
        let firstTrip = app.cells.firstMatch
        firstTrip.tap()
        
        // Verify proper heading hierarchy
        let headings = app.descendants(matching: .any)
            .matching(NSPredicate(format: "accessibilityTraits CONTAINS %d", UIAccessibilityTraits.header.rawValue))
            .allElementsBoundByIndex
        
        #expect(headings.count > 0, "Page should have proper heading structure")
        
        // Verify headings are in logical order
        var previousLevel = 0
        for heading in headings {
            if heading.exists {
                // Check that heading levels are logical (would need custom trait)
                #expect(!heading.label.isEmpty, "Heading should have meaningful text")
            }
        }
    }
    
    @Test("Screen reader content groups and landmarks")
    func testScreenReaderContentGroups() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let firstTrip = app.cells.firstMatch
        firstTrip.tap()
        
        // Verify content is properly grouped
        let contentGroups = [
            app.otherElements["TripDetailsHeader"],
            app.otherElements["LodgingSection"],
            app.otherElements["TransportationSection"], 
            app.otherElements["ActivitiesSection"],
            app.otherElements["TripActions"]
        ]
        
        for group in contentGroups {
            if group.exists {
                #expect(group.isAccessibilityElement || group.children(matching: .any).count > 0,
                       "Content group should be properly structured for screen readers")
            }
        }
    }
}
```

### Reading Flow Validation

**Logical Reading Order:**
```swift
@Test("Screen reader reading flow optimization") 
func testScreenReaderReadingFlow() async throws {
    let app = XCUIApplication()
    app.launch()
    
    // Test reading flow in trip list
    let tripsList = app.collectionViews["TripsListView"]
    let tripCells = tripsList.cells.allElementsBoundByIndex
    
    for cell in tripCells.prefix(3) { // Test first 3 cells
        if cell.exists {
            // Verify cell has proper reading order
            let cellElements = cell.descendants(matching: .any)
                .allElementsBoundByAccessibilityElement
            
            var expectedOrder = [
                "trip name",
                "trip dates", 
                "trip status",
                "action buttons"
            ]
            
            // Verify elements appear in logical reading order
            for (index, element) in cellElements.enumerated() {
                if element.isAccessibilityElement && !element.label.isEmpty {
                    // Check reading order makes sense
                    #expect(element.frame.origin.y >= (index > 0 ? cellElements[index-1].frame.origin.y : 0),
                           "Elements should follow logical reading order")
                }
            }
        }
    }
}
```

## Implementation Guidelines

### Accessibility Identifier Conventions

**Naming Standards:**
```swift
// View identifiers: ViewName + "View"
.accessibilityIdentifier("TripsListView")
.accessibilityIdentifier("EditTripView")

// Button identifiers: Action + Object + "Button"  
.accessibilityIdentifier("AddTripButton")
.accessibilityIdentifier("SaveTripButton")
.accessibilityIdentifier("DeleteTripButton")

// Field identifiers: FieldPurpose + "Field"
.accessibilityIdentifier("TripNameField")
.accessibilityIdentifier("TripNotesField")

// Section identifiers: SectionName + "Section"
.accessibilityIdentifier("LodgingSection")
.accessibilityIdentifier("ActivitiesSection")
```

### Label and Hint Generation

**Dynamic Label Patterns:**
```swift
extension Trip {
    var accessibilityLabel: String {
        var label = name.isEmpty ? NSLocalizedString("trip.untitled", value: "Untitled Trip", comment: "") : name
        
        if let dateRange = displaySubtitle {
            label += ", \(dateRange)"
        }
        
        if totalActivities > 0 {
            label += ", \(totalActivities) activities"
        }
        
        return label
    }
    
    var accessibilityHint: String {
        return NSLocalizedString("trip.accessibilityHint", 
                                value: "Double tap to view trip details", 
                                comment: "Accessibility hint for trip cells")
    }
    
    var accessibilityValue: String? {
        guard totalActivities > 0 else { return nil }
        return NSLocalizedString("trip.accessibilityValue", 
                                value: "\(totalActivities) activities planned",
                                comment: "Accessibility value for trip with activities")
    }
}
```

### SwiftData Model Extensions

**Accessibility Model Integration:**
```swift
extension Trip {
    func generateAccessibilityInfo() {
        // Generate consistent accessibility information
        self.accessibilityLabel = self.accessibilityLabel
        self.accessibilityHint = self.accessibilityHint
        
        // Store for efficient retrieval
        self.cachedAccessibilityInfo = AccessibilityInfo(
            label: accessibilityLabel,
            hint: accessibilityHint,
            value: accessibilityValue
        )
    }
    
    func updateAccessibilityForDataChange() {
        // Update accessibility when data changes
        generateAccessibilityInfo()
        
        // Notify accessibility system of changes
        NotificationCenter.default.post(
            name: UIAccessibility.announcementDidFinishNotification,
            object: nil,
            userInfo: [
                UIAccessibility.announcementStringValueUserInfoKey: "Trip updated"
            ]
        )
    }
}
```

## Performance Testing

### Large Dataset Accessibility

**Performance Benchmarks:**
```swift
@Suite("Accessibility Performance Tests")
@MainActor
struct AccessibilityPerformanceTests {
    
    @Test("Large dataset accessibility loading performance")
    func testLargeDatasetAccessibilityPerformance() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create large dataset
        let tripCount = 1000
        for i in 1...tripCount {
            let trip = Trip(name: "Performance Test Trip \(i)")
            trip.generateAccessibilityInfo()
            testBase.modelContext.insert(trip)
        }
        try testBase.modelContext.save()
        
        let app = XCUIApplication()
        
        // Measure accessibility loading time
        let startTime = Date()
        
        app.launch()
        
        // Wait for list to load
        let tripsList = app.collectionViews["TripsListView"]
        #expect(tripsList.waitForExistence(timeout: 5.0), "Trips list should load within 5 seconds")
        
        // Verify accessibility is working
        let firstCell = tripsList.cells.firstMatch
        #expect(firstCell.exists, "First cell should exist")
        #expect(!firstCell.label.isEmpty, "First cell should have accessibility label")
        
        let endTime = Date()
        let loadTime = endTime.timeIntervalSince(startTime)
        
        // Performance requirements
        #expect(loadTime < 3.0, "Large dataset should load with accessibility in under 3 seconds")
    }
    
    @Test("Accessibility memory usage with large datasets")
    func testAccessibilityMemoryUsage() async throws {
        // Monitor memory usage during accessibility operations
        let testBase = SwiftDataTestBase()
        
        let memoryBefore = getMemoryUsage()
        
        // Create large dataset with accessibility info
        for i in 1...5000 {
            let trip = Trip(name: "Memory Test Trip \(i)")
            trip.generateAccessibilityInfo()
            testBase.modelContext.insert(trip)
        }
        try testBase.modelContext.save()
        
        let memoryAfter = getMemoryUsage()
        let memoryIncrease = memoryAfter - memoryBefore
        
        // Memory increase should be reasonable
        #expect(memoryIncrease < 50_000_000, "Memory increase should be under 50MB for 5000 items")
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
```

## CI/CD Integration

### Automated Accessibility Validation

**CI Script Integration:**
```bash
#!/bin/bash
# Manual Accessibility Testing

echo "Running accessibility validation..."

# Run accessibility-specific tests
xcodebuild test \
  -scheme "Traveling Snails" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -only-testing:"Traveling SnailsTests/AccessibilityTests" \
  -resultBundlePath "./accessibility-test-results"

# Check for accessibility violations
if [ $? -ne 0 ]; then
    echo "❌ Accessibility tests failed"
    exit 1
fi

# Run automated accessibility audit on key flows
xcodebuild test \
  -scheme "Traveling Snails" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  -only-testing:"Traveling SnailsTests/AccessibilityAuditTests" \
  -resultBundlePath "./accessibility-audit-results"

if [ $? -ne 0 ]; then
    echo "❌ Accessibility audit failed"
    exit 1
fi

echo "✅ All accessibility tests passed"
```

### Test Suite Organization

**Accessibility Test Structure:**
```
Traveling Snails Tests/
├── Accessibility Tests/
│   ├── AccessibilityAuditTests.swift          # Modern performAccessibilityAudit tests
│   ├── VoiceOverNavigationTests.swift         # VoiceOver-specific testing
│   ├── SwitchControlTests.swift               # Switch Control navigation
│   ├── VoiceControlTests.swift                # Voice Control integration
│   ├── ScreenReaderTests.swift                # Screen reader compatibility
│   ├── AccessibilityPerformanceTests.swift    # Performance with accessibility
│   └── SwiftDataAccessibilityTests.swift      # SwiftData-specific patterns
├── Test Utilities/
│   ├── AccessibilityTestBase.swift            # Base test class
│   ├── AccessibilityTestEngines.swift         # Custom test engines
│   └── AccessibilityMatchers.swift            # Custom test matchers
```

## Manual Testing Requirements

### Essential Manual Testing Scenarios

**VoiceOver Manual Testing:**
1. **Complete App Navigation**: Navigate entire app using only VoiceOver gestures
2. **Data Entry Workflows**: Create/edit trips using VoiceOver
3. **Error Recovery**: Handle errors using VoiceOver announcements
4. **Large Dataset Navigation**: Navigate large trip lists efficiently

**Switch Control Manual Testing:**
1. **Tab Order Validation**: Verify logical tab order through all screens
2. **Group Navigation**: Test section-based navigation
3. **Emergency Exit**: Verify escape routes from all deep states

**Voice Control Manual Testing:**
1. **Command Recognition**: Test voice commands for all major actions
2. **Dictation Integration**: Test text input via dictation
3. **Number Navigation**: Verify numbered element access

**Dynamic Type Manual Testing:**
1. **Extreme Sizes**: Test with AX5 (largest) Dynamic Type size
2. **Layout Adaptation**: Verify layouts adapt properly
3. **Readability**: Ensure all text remains readable

### Testing Device Configuration

**Required Test Configurations:**
```
Device Configurations:
├── iPhone 15 Pro (iOS 18+)
│   ├── VoiceOver enabled
│   ├── Switch Control enabled  
│   ├── Voice Control enabled
│   ├── Dynamic Type: AX5 (largest)
│   ├── High Contrast: enabled
│   └── Reduce Motion: enabled
├── iPad Pro (iPadOS 18+)
│   ├── Same accessibility settings
│   └── Split View configurations
└── Apple Vision Pro (visionOS 2+)
    ├── Eye tracking navigation
    ├── Voice Control
    └── Accessibility zoom
```

### Documentation of Manual Testing Results

**Manual Test Report Template:**
```markdown
# Manual Accessibility Testing Report

## Test Configuration
- Device: [iPhone 15 Pro]
- OS Version: [iOS 18.0]
- App Version: [1.0.0]
- Accessibility Settings: [VoiceOver, High Contrast, AX5 Dynamic Type]

## Test Results

### VoiceOver Navigation
- [ ] ✅ Main navigation accessible
- [ ] ✅ Trip creation workflow accessible  
- [ ] ❌ Activity editing has label issues
- [ ] ✅ Error announcements work properly

### Critical Issues Found
1. **Activity Edit Form**: Missing accessibility labels on date pickers
2. **File Attachment List**: VoiceOver skips attachment thumbnails
3. **Error Recovery**: Some error actions not announced properly

### Recommendations
1. Add accessibility labels to date picker components
2. Implement thumbnail descriptions for file attachments
3. Review error announcement patterns
```

---

This document provides comprehensive guidance for implementing robust accessibility testing in SwiftUI applications using SwiftData. Regular updates should be made as new iOS accessibility features become available and testing patterns evolve.