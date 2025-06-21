# SwiftData Patterns and Anti-Patterns

This document outlines critical SwiftData usage patterns to prevent infinite view recreation bugs, ensure optimal performance, maintain proper test isolation, and enable CloudKit sync compatibility.

## 🚨 Critical Anti-Patterns (NEVER DO THESE)

### 1. Passing SwiftData Model Arrays as View Parameters

❌ **WRONG - Causes Infinite Recreation:**
```swift
struct BadTripListView: View {
    let trips: [Trip]  // Model array parameter - CAUSES INFINITE RECREATION!
    
    init(trips: [Trip]) {
        self.trips = trips
    }
    
    var body: some View {
        List(trips) { trip in
            Text(trip.name)
        }
    }
}

// Usage that triggers the bug:
struct ParentView: View {
    @Query private var trips: [Trip]
    
    var body: some View {
        BadTripListView(trips: trips)  // This causes infinite recreation!
    }
}
```

**Why this is wrong:**
- SwiftData models are observable objects
- Passing them as parameters triggers change notifications
- This causes the parent view to rebuild
- Which recreates the child view with "new" model array
- Leading to infinite recreation loop

### 2. Using @StateObject with SwiftData Models

❌ **WRONG:**
```swift
struct BadView: View {
    @StateObject private var trip: Trip  // Don't use @StateObject with SwiftData
    // ... rest of view
}
```

## ✅ Correct Patterns (ALWAYS USE THESE)

### 1. Direct @Query in Consuming Views

✅ **CORRECT:**
```swift
struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]  // Query directly in the view that needs the data
    
    var body: some View {
        List(trips) { trip in
            TripRowView(tripId: trip.id)  // Pass IDs, not models
        }
    }
}
```

### 2. Pass Model IDs, Fetch in Child Views

✅ **CORRECT:**
```swift
struct TripRowView: View {
    let tripId: UUID  // Pass ID, not the model
    
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    
    private var trip: Trip? {
        trips.first { $0.id == tripId }
    }
    
    var body: some View {
        if let trip = trip {
            Text(trip.name)
        }
    }
}
```

### 3. Use @Environment(\.modelContext) for Data Operations

✅ **CORRECT:**
```swift
struct AddTripView: View {
    @Environment(\.modelContext) private var modelContext  // For save operations
    @State private var name: String = ""
    
    var body: some View {
        Form {
            TextField("Trip Name", text: $name)
            Button("Save") {
                let trip = Trip(name: name)
                modelContext.insert(trip)
                try? modelContext.save()
            }
        }
    }
}
```

### 4. CloudKit Compatibility Pattern

✅ **CORRECT - Private Optional + Safe Accessor:**
```swift
@Model
class Trip {
    // CLOUDKIT REQUIRED: Optional relationships for CloudKit sync
    @Relationship(deleteRule: .cascade, inverse: \Lodging.trip)
    private var _lodging: [Lodging]? = nil
    
    // SAFE ACCESSORS: Never return nil, always return empty array
    var lodging: [Lodging] {
        get { _lodging ?? [] }
        set { _lodging = newValue.isEmpty ? nil : newValue }
    }
    
    // ... other properties
}
```

### 5. App Settings and Observable Pattern

✅ **CORRECT - @Observable Settings with ContentView Integration:**
```swift
// AppSettings.swift - Centralized app configuration
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    public var colorScheme: ColorSchemePreference {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme")
        }
    }
    
    private init() {
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "system"
        self.colorScheme = ColorSchemePreference(rawValue: savedScheme) ?? .system
    }
}

// ContentView.swift - Apply settings globally
struct ContentView: View {
    @State private var appSettings = AppSettings.shared
    
    var body: some View {
        // Main content here
        mainContent
            .preferredColorScheme(appSettings.colorScheme.colorScheme)
    }
}

// SettingsViewModel.swift - Expose settings to settings UI
@Observable @MainActor
class SettingsViewModel {
    private let appSettings = AppSettings.shared
    
    var colorScheme: ColorSchemePreference {
        get { appSettings.colorScheme }
        set { appSettings.colorScheme = newValue }
    }
}
```

**Why this pattern works:**
- Settings are centralized in `@Observable` class
- Changes automatically trigger UI updates
- UserDefaults persistence is handled automatically
- ContentView applies settings globally via `.preferredColorScheme()`
- Settings UI can bind directly to SettingsViewModel properties

## 🧪 Testing SwiftData Patterns

### Use SwiftDataTestBase for Isolated Tests

```swift
@Test("SwiftData query performance")
func testQueryPerformance() {
    let testBase = SwiftDataTestBase()  // Isolated database
    
    // Create test data
    let trip = Trip(name: "Test Trip")
    testBase.modelContext.insert(trip)
    try testBase.modelContext.save()
    
    // Test queries
    let trips = try testBase.modelContext.fetch(FetchDescriptor<Trip>())
    #expect(trips.count == 1)
    #expect(trips.first?.name == "Test Trip")
}
```

## 🚀 Performance Guidelines

### 1. Efficient Queries

✅ **Use FetchDescriptor with proper sorting:**
```swift
@Query(
    sort: [SortDescriptor(\Trip.startDate, order: .reverse)],
    predicate: #Predicate<Trip> { trip in 
        trip.hasStartDate == true 
    }
)
private var upcomingTrips: [Trip]
```

### 2. Avoid Relationship Access in Loops

❌ **Slow:**
```swift
var totalCost: Decimal {
    var total: Decimal = 0
    for trip in trips {
        total += trip.totalCost  // Accessing computed property in loop
    }
    return total
}
```

✅ **Fast:**
```swift
var totalCost: Decimal {
    trips.reduce(Decimal(0)) { $0 + $1.totalCost }  // More efficient
}
```

### 3. Cache Expensive Computations

✅ **Good:**
```swift
@Model
class Trip {
    // ... properties
    
    // Cache expensive computation
    private var _cachedTotalCost: Decimal?
    
    var totalCost: Decimal {
        if let cached = _cachedTotalCost {
            return cached
        }
        
        let cost = lodging.reduce(Decimal(0)) { $0 + $1.cost } +
                   transportation.reduce(Decimal(0)) { $0 + $1.cost } +
                   activity.reduce(Decimal(0)) { $0 + $1.cost }
        
        _cachedTotalCost = cost
        return cost
    }
    
    // Invalidate cache when related data changes
    func invalidateCostCache() {
        _cachedTotalCost = nil
    }
}
```

## 🔍 Debugging SwiftData Issues

### 1. Enable SwiftData Logging

```swift
// In development builds
#if DEBUG
import OSLog
private let logger = Logger(subsystem: "TravelingSnails", category: "SwiftData")
#endif
```

### 2. Monitor View Recreation

```swift
struct DebugView: View {
    let trips: [Trip]
    
    var body: some View {
        #if DEBUG
        let _ = print("DebugView recreated with \(trips.count) trips")
        #endif
        
        List(trips) { trip in
            Text(trip.name)
        }
    }
}
```

### 3. Performance Testing

```swift
@Test("View recreation performance")
func testViewRecreationPerformance() {
    let testBase = SwiftDataTestBase()
    
    // Measure view recreation time
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // Perform operations that might trigger recreation
    // ...
    
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    #expect(timeElapsed < 0.1)  // Should complete in under 100ms
}
```

## 📋 Checklist for SwiftData Implementation

Before implementing any SwiftData-related feature:

- [ ] Are you using @Query directly in the consuming view?
- [ ] Are you passing model IDs instead of model objects?
- [ ] Are you using @Environment(\.modelContext) for data operations?
- [ ] Are your relationships using the CloudKit compatibility pattern?
- [ ] Do you have tests covering the SwiftData usage?
- [ ] Have you verified no infinite recreation occurs?

## 🧪 Test Isolation Patterns

### Critical Test Data Isolation

To prevent test data contamination in the production app, all SwiftData tests must use isolated containers:

#### SwiftDataTestBase Pattern (Recommended)
```swift
@MainActor
class MyTests {
    @Test("Isolated test example")
    func testWithIsolation() throws {
        let testBase = SwiftDataTestBase()
        
        // Create test data in isolated container
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()
        
        // Test business logic
        #expect(trip.name == "Test Trip")
        #expect(trip.totalActivities == 0)
    }
}
```

#### Manual Isolation Pattern
```swift
@Test("Manual isolation example")
func testWithManualIsolation() throws {
    // Create isolated in-memory container
    let config = ModelConfiguration(
        isStoredInMemoryOnly: true,
        allowsSave: true,
        groupContainer: .none,
        cloudKitDatabase: .none  // Explicitly disable CloudKit
    )
    
    let container = try ModelContainer(
        for: Trip.self, Organization.self, Activity.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    // Test with isolated data
    let trip = Trip(name: "Isolated Test")
    context.insert(trip)
    try context.save()
}
```

#### TestGuard for Environment Detection
```swift
@MainActor
struct TestGuard {
    static func ensureTestEnvironment() {
        #if DEBUG
        let isInTests = NSClassFromString("XCTestCase") != nil || 
                       ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        
        if isInTests {
            print("🧪 Test environment detected - ensuring data isolation")
            UserDefaults.standard.set(true, forKey: "isRunningTests")
        }
        #endif
    }
    
    static var isRunningTests: Bool {
        UserDefaults.standard.bool(forKey: "isRunningTests")
    }
}
```

### Database Cleanup for Production

#### DatabaseCleanupView Implementation
```swift
// In Settings -> Data Management
struct DatabaseCleanupView: View {
    @Environment(\.modelContext) private var modelContext
    
    private func removeTestData() {
        let testPatterns = [
            "test trip", "debug", "sample", "demo", 
            "Trip 0", "Trip 1", "Performance Test",
            "unprotected trip", "protected trip"
        ]
        
        // Conservative pattern matching to avoid removing real data
        for trip in trips {
            let tripName = trip.name.lowercased()
            if testPatterns.contains(where: { tripName.contains($0.lowercased()) }) {
                modelContext.delete(trip)
            }
        }
    }
}
```

### Test Isolation Verification

#### Pre-Test Checks
```swift
@MainActor
class IsolatedTestBase {
    func verifyIsolation() throws {
        let trips = try testModelContext.fetch(FetchDescriptor<Trip>())
        let organizations = try testModelContext.fetch(FetchDescriptor<Organization>())
        
        guard trips.isEmpty && organizations.isEmpty else {
            throw TestIsolationError.dataContamination
        }
    }
}

enum TestIsolationError: Error {
    case dataContamination
    case mainContainerAccess
}
```

### Benefits of Proper Test Isolation

1. **No Production Data Contamination**: Tests never affect real user data
2. **Reliable Test Results**: Each test starts with clean state
3. **Parallel Test Execution**: Tests can run concurrently without conflicts
4. **CloudKit Safety**: Tests don't trigger CloudKit sync operations
5. **Performance**: In-memory tests run faster than disk-based tests

## 🔄 User Preferences and Settings Sync Pattern

### Critical: Use NSUbiquitousKeyValueStore for User Preferences

❌ **WRONG - SwiftData for User Preferences (Causes Fatal Crashes):**
User preferences (color scheme, biometric timeout, etc.) should NEVER use SwiftData models. This causes fatal ModelContext lifecycle crashes when accessing settings from singleton classes.

✅ **CORRECT - NSUbiquitousKeyValueStore for User Preferences:**
```swift
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let userDefaults = UserDefaults.standard
    
    public var colorScheme: ColorSchemePreference {
        get {
            // Try iCloud first, fallback to UserDefaults, then system default
            if let cloudValue = ubiquitousStore.string(forKey: Keys.colorScheme),
               let preference = ColorSchemePreference(rawValue: cloudValue) {
                return preference
            }
            if let localValue = userDefaults.string(forKey: Keys.colorScheme),
               let preference = ColorSchemePreference(rawValue: localValue) {
                return preference
            }
            return .system
        }
        set {
            // Write to both stores simultaneously for reliability
            ubiquitousStore.set(newValue.rawValue, forKey: Keys.colorScheme)
            userDefaults.set(newValue.rawValue, forKey: Keys.colorScheme)
            ubiquitousStore.synchronize()
        }
    }
    
    private init() {
        setupNotificationHandling()
    }
    
    private func setupNotificationHandling() {
        // Handle iCloud changes from other devices
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore,
            queue: .main
        ) { [weak self] notification in
            self?.handleiCloudChange(notification)
        }
    }
}
```

### When to Use Each Pattern

#### Use NSUbiquitousKeyValueStore for:
- ✅ **User preferences** (color scheme, notification settings, etc.)
- ✅ **App configuration** (biometric timeout, language preference)
- ✅ **Simple key-value data** that needs cross-device sync
- ✅ **Settings that need immediate availability** (no model context required)

#### Use SwiftData for:
- ✅ **Complex relational data** (trips, activities, organizations)
- ✅ **Large datasets** with relationships and queries
- ✅ **Data that benefits from model relationships** and computed properties
- ✅ **Content that needs offline sync** with conflict resolution

### Benefits of NSUbiquitousKeyValueStore for User Preferences

1. **Purpose-Built**: Apple's official solution for user preferences sync
2. **No Fatal Crashes**: No ModelContext lifecycle issues
3. **Immediate Availability**: Works without model context setup
4. **Automatic Notifications**: Built-in change notifications from other devices
5. **Reliability**: UserDefaults fallback when iCloud unavailable
6. **Simplicity**: No complex model relationships needed

---

Following these patterns ensures stable, performant SwiftData operations throughout the Traveling Snails app while maintaining robust test isolation and seamless cross-device sync for user preferences.