# SwiftData + CloudKit + Swift Concurrency Integration Guide

*Primary reference for production app development - iOS 17+ for SwiftData, iOS 15+ for CloudKit async/await*

## Architecture Decision Framework

### SwiftData + CloudKit Sync vs. Direct CloudKit

#### Use SwiftData + CloudKit Sync When:
- ✅ Building new apps with standard CRUD operations
- ✅ Want automatic CloudKit record generation from SwiftData models
- ✅ Need seamless local + cloud storage with minimal CloudKit knowledge
- ✅ Can accept CloudKit sync constraints (SwiftData's CloudKit sync does not currently support all relationship types - e.g., many-to-many or required relationships may have limitations)
- ✅ OK with automatic sync that has limited configurability (no custom record types, versioning control, or sync timing)

#### Use Direct CloudKit When:
- ✅ Need fine-grained control over CloudKit operations
- ✅ Building CloudKit-first apps with complex sharing requirements
- ✅ Need public CloudKit database (SwiftData only supports private)
- ✅ Require advanced CloudKit features (custom zones, subscriptions, etc.)

### Threading Architecture Decision

#### Use Manual Actor Pattern (Recommended):
- ✅ **Always** for reliable background SwiftData operations
- ✅ When you need predictable threading behavior
- ✅ For production apps where thread safety is critical

#### Avoid @ModelActor Because:
- ❌ Known threading issues in iOS 17-18 (runs on main thread)
- ❌ Unpredictable behavior that can block UI
- ❌ Manual pattern is more reliable and explicit

## Required Xcode Project Setup

### 1. CloudKit Capability Configuration
```swift
// 1. Target Settings → Signing & Capabilities → + Capability → iCloud
// 2. Check "CloudKit" checkbox
// 3. Click + in Containers section
// 4. Create container: "iCloud.com.yourteam.AppName"
// 5. Add "Background Modes" capability
// 6. Check "Background app refresh" and "Remote notifications"
```

### 2. Container Identifier Requirements
```swift
// Development vs Production containers:
#if DEBUG
let containerIdentifier = "iCloud.com.yourteam.AppName.development"
#else
let containerIdentifier = "iCloud.com.yourteam.AppName"
#endif
```

## Core Integration Patterns

### 1. CloudKit-Compatible SwiftData Model

```swift
import SwiftData
import CloudKit

@Model
class Trip {
    // REQUIRED: All properties must have defaults or be optional for CloudKit
    var destination: String = ""
    var startDate: Date = Date()
    var endDate: Date? = nil
    var isProtected: Bool = false
    
    // CloudKit-compatible relationship pattern
    // CRITICAL: Private optional storage + public computed accessor
    @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
    private var _activities: [Activity]? = nil
    
    var activities: [Activity] {
        get { _activities ?? [] }
        set { 
            // CloudKit prefers nil over empty arrays
            _activities = newValue.isEmpty ? nil : newValue
        }
    }
    
    // Performance indexing (works with CloudKit)
    @Index<Trip>([\.startDate])
    
    init(destination: String, startDate: Date = Date()) {
        self.destination = destination
        self.startDate = startDate
    }
}

@Model 
class Activity {
    var title: String = ""
    var date: Date = Date()
    var notes: String = ""
    
    // REQUIRED: All relationships must be optional for CloudKit
    @Relationship(inverse: \Trip.activities)
    var trip: Trip? = nil
    
    init(title: String, date: Date = Date()) {
        self.title = title
        self.date = date
    }
}
```

### 2. Reliable Data Manager (Manual Actor Pattern)

```swift
import SwiftData

actor TripDataManager {
    // Manual actor implementation for reliable threading
    private let modelExecutor: any ModelExecutor
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelExecutor.modelContext }
    
    init(modelContainer: ModelContainer) {
        self.modelExecutor = DefaultSerialModelExecutor(
            modelContext: ModelContext(modelContainer)
        )
        self.modelContainer = modelContainer
    }
    
    func createTrip(destination: String, startDate: Date) async throws -> Trip {
        let trip = Trip(destination: destination, startDate: startDate)
        modelContext.insert(trip)
        try modelContext.save()
        return trip
    }
    
    func fetchTrips(predicate: Predicate<Trip>? = nil) async throws -> [Trip] {
        var descriptor = FetchDescriptor<Trip>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        if let predicate = predicate {
            descriptor.predicate = predicate
        }
        return try modelContext.fetch(descriptor)
    }
    
    func addActivity(to trip: Trip, title: String, date: Date) async throws {
        let activity = Activity(title: title, date: date)
        activity.trip = trip
        modelContext.insert(activity)
        try modelContext.save()
    }
    
    func deleteTrip(_ trip: Trip) async throws {
        modelContext.delete(trip)
        try modelContext.save()
    }
}
```

### 3. SwiftUI Integration with Proper Threading

```swift
import SwiftUI
import SwiftData

// ✅ CORRECT: Use @Query directly in views for data display
struct TripListView: View {
    @Query(sort: \.startDate, order: .reverse) 
    private var trips: [Trip]
    @Environment(\.modelContainer) private var container
    @State private var dataManager: TripDataManager?
    
    var body: some View {
        NavigationStack {
            List(trips) { trip in
                TripRowView(trip: trip)
            }
            .onAppear {
                if dataManager == nil {
                    dataManager = TripDataManager(modelContainer: container)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Trip") {
                        Task {
                            try? await dataManager?.createTrip(
                                destination: "New Trip",
                                startDate: Date()
                            )
                        }
                    }
                }
            }
        }
    }
}

// ✅ CORRECT: Filtered queries with proper initialization
struct FilteredTripView: View {
    let isProtected: Bool
    @Query private var trips: [Trip]
    
    init(isProtected: Bool) {
        self.isProtected = isProtected
        self._trips = Query(filter: #Predicate<Trip> { trip in
            trip.isProtected == isProtected
        })
    }
    
    var body: some View {
        List(trips) { trip in
            TripRowView(trip: trip)
        }
    }
}

// ✅ CORRECT: ViewModel for complex state management
@MainActor
class TripViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataManager: TripDataManager
    
    init(modelContainer: ModelContainer) {
        self.dataManager = TripDataManager(modelContainer: modelContainer)
    }
    
    func performBulkOperation() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Heavy operations run on actor's background thread
            let trips = try await dataManager.fetchTrips()
            // UI updates automatically happen on MainActor
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### 4. Complete App Setup

```swift
import SwiftUI
import SwiftData

@main
struct TravelingSnailsApp: App {
    let container: ModelContainer
    
    init() {
        do {
            #if DEBUG
            let identifier = "iCloud.com.yourteam.TravelingSnails.development"
            #else
            let identifier = "iCloud.com.yourteam.TravelingSnails"
            #endif
            
            let config = ModelConfiguration(
                schema: Schema([Trip.self, Activity.self]),
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(identifier)
            )
            container = try ModelContainer(for: config)
        } catch {
            fatalError("Failed to configure ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
```

## Critical Anti-Patterns

### ❌ NEVER Do These:

```swift
// WRONG: Passing SwiftData model arrays between views
struct BadView: View {
    let activities: [Activity]  // Causes infinite recreation!
}

// WRONG: Creating objects in view body
struct BadView: View {
    var body: some View {
        let viewModel = TripViewModel()  // Created on every update!
    }
}

// WRONG: Using @ModelActor (threading issues)
@ModelActor
actor BadDataManager {  // Runs on main thread despite being actor!
    func fetchData() { }
}

// WRONG: Non-optional relationships with CloudKit
@Model
class BadTrip {
    @Relationship(deleteRule: .cascade)
    var activities: [Activity] = []  // CloudKit sync will fail!
}

// WRONG: Unique constraints with CloudKit
@Model
class BadTrip {
    @Unique<Trip>([\.destination])  // CloudKit doesn't support this!
    var destination: String = ""
}

// WRONG: .deny delete rule with CloudKit
@Model
class BadTrip {
    @Relationship(deleteRule: .deny)  // Not supported by CloudKit
    var activities: [Activity]? = nil
}

// WRONG: Accessing ModelContext from background threads
func badBackgroundWork() {
    Task.detached {
        let context = ModelContext(container)  // Wrong thread!
        // This will crash or behave unpredictably
    }
}
```

## Threading and Async Patterns

### Safe Async Patterns
```swift
// ✅ CORRECT: MainActor for UI, Actor for data
@MainActor
class UIManager {
    func updateUI() async {
        // This automatically runs on main thread
        let data = try await dataManager.fetchTrips()
        // UI updates happen on main thread
    }
}

// ✅ CORRECT: Structured concurrency
func loadMultipleTrips(ids: [UUID]) async throws -> [Trip] {
    try await withThrowingTaskGroup(of: Trip.self) { group in
        for id in ids {
            group.addTask {
                try await dataManager.fetchTrip(id: id)
            }
        }
        
        var trips: [Trip] = []
        for try await trip in group {
            trips.append(trip)
        }
        return trips
    }
}

// ✅ CORRECT: Error handling in async context
func safeAsyncOperation() async {
    do {
        let result = try await riskyOperation()
        await MainActor.run {
            // Update UI on main thread
        }
    } catch let error as TripError {
        await MainActor.run {
            handleTripError(error)
        }
    } catch {
        await MainActor.run {
            handleGenericError(error)
        }
    }
}
```

## CloudKit Sync Troubleshooting

### When Models Don't Sync to CloudKit:
1. ✅ All relationships are optional (`[Type]?` not `[Type]`)
2. ✅ All properties have defaults or are optional
3. ✅ No `#Unique` constraints used
4. ✅ No `.deny` delete rules used
5. ✅ CloudKit container identifier is correct
6. ✅ User is signed into iCloud
7. ✅ CloudKit capability enabled in Xcode project
8. ✅ Check CloudKit quotas (each app has rate limits and storage quotas)
9. ✅ Monitor for CKError.quotaExceeded and CKError.requestRateLimited

### When Views Recreate Infinitely:
1. ✅ Using `@Query` directly in views (not passing arrays)
2. ✅ ViewModels created with `@State` or `@StateObject`
3. ✅ Not creating objects in view body
4. ✅ Use `Self._printChanges()` to debug view updates

### When Getting Threading Crashes:
1. ✅ Using manual actor pattern (not @ModelActor)
2. ✅ UI updates on `@MainActor`
3. ✅ Never accessing ModelContext from background threads directly
4. ✅ All async operations properly isolated

## Performance Optimization

### Efficient Query Patterns
```swift
// ✅ GOOD: Specific query with predicate
@Query(filter: #Predicate<Trip> { trip in
    trip.startDate >= Date().addingTimeInterval(-86400 * 30)
}, sort: [SortDescriptor(\.startDate)])
private var recentTrips: [Trip]

// ❌ BAD: Fetch all then filter in memory
@Query private var allTrips: [Trip]
var recentTrips: [Trip] {
    allTrips.filter { trip in
        trip.startDate >= Date().addingTimeInterval(-86400 * 30)
    }
}
```

### Background Processing
```swift
// ✅ CORRECT: Proper background context creation
actor BackgroundProcessor {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    func processBulkData() async throws {
        // This runs on actor's background thread
        let context = ModelContext(modelContainer)
        
        // Heavy work here
        for item in largeDataSet {
            let model = Trip(destination: item.destination, startDate: item.date)
            context.insert(model)
        }
        
        try context.save()
        // SwiftData + CloudKit will sync automatically
    }
}
```

## Testing Strategies

### Unit Testing with SwiftData
```swift
import XCTest
import SwiftData

class TripDataManagerTests: XCTestCase {
    var container: ModelContainer!
    var dataManager: TripDataManager!
    
    override func setUp() async throws {
        // In-memory container for isolated tests
        let config = ModelConfiguration(
            schema: Schema([Trip.self, Activity.self]),
            isStoredInMemoryOnly: true
        )
        container = try ModelContainer(for: config)
        dataManager = TripDataManager(modelContainer: container)
    }
    
    func testCreateTrip() async throws {
        let trip = try await dataManager.createTrip(
            destination: "Test Destination",
            startDate: Date()
        )
        
        XCTAssertEqual(trip.destination, "Test Destination")
        
        let fetchedTrips = try await dataManager.fetchTrips()
        XCTAssertEqual(fetchedTrips.count, 1)
    }
    
    func testConcurrentOperations() async throws {
        // Test that actor properly handles concurrent access
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? await self.dataManager.createTrip(
                        destination: "Trip \(i)",
                        startDate: Date()
                    )
                }
            }
        }
        
        let trips = try await dataManager.fetchTrips()
        XCTAssertEqual(trips.count, 100)
    }
}
```

### Mock Patterns for CloudKit Testing
```swift
protocol TripDataManaging {
    func fetchTrips() async throws -> [Trip]
    func createTrip(destination: String, startDate: Date) async throws -> Trip
}

// Real implementation uses TripDataManager
// Test implementation uses this mock:
actor MockTripDataManager: TripDataManaging {
    private var trips: [Trip] = []
    var shouldThrowError = false
    var networkDelay: TimeInterval = 0
    
    func fetchTrips() async throws -> [Trip] {
        if networkDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw TripError.networkUnavailable
        }
        
        return trips
    }
    
    func createTrip(destination: String, startDate: Date) async throws -> Trip {
        let trip = Trip(destination: destination, startDate: startDate)
        trips.append(trip)
        return trip
    }
}
```

## Error Handling

### Comprehensive Error Types
```swift
enum TripError: Error, LocalizedError {
    case networkUnavailable
    case invalidData
    case syncTimeout
    case cloudKitNotAvailable
    case userNotSignedIn
    case quotaExceeded
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection is unavailable"
        case .invalidData:
            return "The trip data is invalid or corrupted"
        case .syncTimeout:
            return "Sync operation timed out"
        case .cloudKitNotAvailable:
            return "CloudKit is not available"
        case .userNotSignedIn:
            return "Please sign in to iCloud to sync your trips"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .rateLimited:
            return "Too many requests - please wait before trying again"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .userNotSignedIn:
            return "Go to Settings > [Your Name] > iCloud to sign in"
        case .quotaExceeded:
            return "Free up iCloud storage or upgrade your plan"
        case .rateLimited:
            return "Wait a few minutes before retrying"
        default:
            return "Please try again later"
        }
    }
}

// Usage in async context
func handleErrors() async {
    do {
        try await dataManager.createTrip(destination: "Paris", startDate: Date())
    } catch let error as TripError {
        await MainActor.run {
            showError(error.localizedDescription, suggestion: error.recoverySuggestion)
        }
    } catch {
        await MainActor.run {
            showError("An unexpected error occurred: \(error.localizedDescription)")
        }
    }
}
```

## Version Compatibility Matrix

| Feature | Minimum iOS | Notes |
|---------|-------------|-------|
| SwiftData Basic | iOS 17.0+ | @Model, @Query, ModelContainer |
| CloudKit Async/Await | iOS 15.0+ | save(), record(for:), records(matching:) |
| Swift Concurrency | iOS 13.0+ | Language features only |
| Swift Concurrency APIs | iOS 15.0+ | URLSession async, etc. |
| @ModelActor | iOS 17.0+ | Has threading issues, use manual pattern |
| #Index, #Unique | iOS 18.0+ | #Unique not compatible with CloudKit |

---

## 📖 Related Wiki Pages

### Core Technical Documentation
- **[TECHNOLOGY_REFERENCE.md](TECHNOLOGY_REFERENCE.md)** - Detailed API syntax and specifications
- **[SwiftData-Patterns.md](SwiftData-Patterns.md)** - Specific SwiftData implementation patterns
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Overall app architecture and MVVM patterns

### Development Resources
- **[Development-Workflow.md](Development-Workflow.md)** - Testing procedures and contribution guidelines
- **[DEPENDENCY_INJECTION_INVESTIGATION.md](DEPENDENCY_INJECTION_INVESTIGATION.md)** - Advanced architectural experiments

### Quick Navigation
- **[Home.md](Home.md)** - Wiki overview and quick start guide

---

**Usage**: This is your primary reference for integration patterns. Start here for comprehensive technical guidance, then refer to specific technical documentation as needed.