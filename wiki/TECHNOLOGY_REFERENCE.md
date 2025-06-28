# Technology Reference Documentation

*Detailed API reference - Use INTEGRATION_PATTERNS_GUIDE.md for primary workflow guidance*

## Verification Status Legend

- ✅ **VERIFIED**: Confirmed through official documentation or testing
- ⚠️ **UNCERTAIN**: API names/syntax may need verification
- 🚫 **AVOID**: Known issues or deprecated approaches

---

## SwiftData API Reference

### ✅ Model Definition (iOS 17+)
```swift
import SwiftData

@Model
class Trip {
    // Properties with defaults (CloudKit compatible)
    var destination: String = ""
    var startDate: Date = Date()
    var endDate: Date? = nil
    var isProtected: Bool = false
    
    // Relationship patterns
    @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
    private var _activities: [Activity]? = nil
    
    var activities: [Activity] {
        get { _activities ?? [] }
        set { _activities = newValue.isEmpty ? nil : newValue }
    }
    
    // iOS 18+ features
    @Index<Trip>([\.startDate])  // Performance indexing
    // @Unique<Trip>([\.destination])  // 🚫 Not compatible with CloudKit
    
    init(destination: String, startDate: Date = Date()) {
        self.destination = destination
        self.startDate = startDate
    }
}
```

### ✅ Container & Context Setup (iOS 17+)
```swift
// Basic setup - VERIFIED syntax
let container = try ModelContainer(for: [Trip.self, Activity.self])

// With CloudKit configuration - VERIFIED
let config = ModelConfiguration(
    schema: Schema([Trip.self, Activity.self]),
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .private("iCloud.com.yourteam.AppName")
)
let container = try ModelContainer(for: config)

// Context usage
let context = ModelContext(container)
```

### ✅ Querying Patterns (iOS 17+)
```swift
// SwiftUI @Query - VERIFIED
@Query(sort: \.startDate, order: .reverse) 
private var trips: [Trip]

// Filtered query - VERIFIED
@Query(filter: #Predicate<Trip> { trip in
    trip.startDate > Date().addingTimeInterval(-86400 * 30)
}, sort: [SortDescriptor(\.startDate)])
private var recentTrips: [Trip]

// Programmatic fetching - VERIFIED
let descriptor = FetchDescriptor<Trip>(
    predicate: #Predicate { $0.isProtected == false },
    sortBy: [SortDescriptor(\.startDate)]
)
let trips = try context.fetch(descriptor)
```

### 🚫 @ModelActor Issues (iOS 17-18)
```swift
// AVOID: @ModelActor has threading problems
@ModelActor
actor ProblematicDataManager {
    // Known issue: Runs on main thread despite being an actor
    func fetchData() throws {
        // This may block UI unexpectedly
    }
}
```

### ✅ Manual Actor Pattern (Recommended)
```swift
actor ReliableDataManager {
    private let modelExecutor: any ModelExecutor
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext { modelExecutor.modelContext }
    
    init(modelContainer: ModelContainer) {
        self.modelExecutor = DefaultSerialModelExecutor(
            modelContext: ModelContext(modelContainer)
        )
        self.modelContainer = modelContainer
    }
    
    func saveTrip(_ trip: Trip) throws {
        modelContext.insert(trip)
        try modelContext.save()
    }
    
    func fetchTrips() throws -> [Trip] {
        let descriptor = FetchDescriptor<Trip>()
        return try modelContext.fetch(descriptor)
    }
}
```

### CloudKit Compatibility Requirements
- ✅ All properties must be optional OR have default values
- ✅ All relationships must be optional (`[Type]?` not `[Type]`)
- 🚫 No `#Unique` constraints allowed
- 🚫 No `.deny` delete rules (use `.cascade`, `.nullify`, `.noAction`)
- ✅ Use private optional + public computed pattern for array relationships
- ⚠️ Limited relationship support (many-to-many relationships may not sync properly)
- ⚠️ No control over sync timing or custom record types
- ⚠️ Automatic sync cannot be configured or customized

---

## CloudKit API Reference

### ✅ Basic Setup (iOS 8+)
```swift
import CloudKit

let container = CKContainer.default()
let privateDB = container.privateCloudDatabase
let publicDB = container.publicCloudDatabase
let sharedDB = container.sharedCloudDatabase
```

### ✅ Record Operations (iOS 15+ Async/Await)
```swift
// Create and save record - VERIFIED iOS 15+
let record = CKRecord(recordType: "Trip")
record["destination"] = "Paris" as CKRecordValue
record["startDate"] = Date() as CKRecordValue

do {
    let savedRecord = try await privateDB.save(record)
    print("Saved: \(savedRecord.recordID)")
} catch {
    print("Save failed: \(error)")
}

// Fetch single record - VERIFIED iOS 15+
let recordID = CKRecord.ID(recordName: "trip-123")
do {
    let fetchedRecord = try await privateDB.record(for: recordID)
    let destination = fetchedRecord["destination"] as? String
} catch {
    print("Fetch failed: \(error)")
}

// Query records - VERIFIED iOS 15+ returns tuple
let predicate = NSPredicate(format: "destination = %@", "Paris")
let query = CKQuery(recordType: "Trip", predicate: predicate)

do {
    let (matchResults, cursor) = try await privateDB.records(matching: query)
    
    for (recordID, result) in matchResults {
        switch result {
        case .success(let record):
            print("Found record: \(record)")
        case .failure(let error):
            print("Record error: \(error)")
        }
    }
    
    // Handle pagination if needed
    if let cursor = cursor {
        // Use cursor for next batch
    }
} catch {
    print("Query failed: \(error)")
}
```

### ✅ Sharing (iOS 10+)
```swift
// Create share - VERIFIED pattern
func createShare(for rootRecord: CKRecord) async throws -> CKShare {
    let share = CKShare(rootRecord: rootRecord)
    share[CKShare.SystemFieldKey.title] = "Shared Trip"
    
    do {
        let savedShare = try await privateDB.save(share)
        return savedShare
    } catch {
        throw error
    }
}

// Present sharing UI - SwiftUI pattern
import SwiftUI

struct ShareSheetView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // No updates needed
    }
}

// Usage in SwiftUI
struct ContentView: View {
    @State private var showingShareSheet = false
    @State private var shareToPresent: CKShare?
    
    var body: some View {
        Button("Share") {
            Task {
                do {
                    let share = try await createShare(for: tripRecord)
                    shareToPresent = share
                    showingShareSheet = true
                } catch {
                    print("Failed to create share: \(error)")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let share = shareToPresent {
                ShareSheetView(share: share, container: CKContainer.default())
            }
        }
    }
}
```

### ✅ Subscriptions (iOS 8+)
```swift
// Database subscription - VERIFIED
let subscription = CKDatabaseSubscription(subscriptionID: "trip-changes")

let notificationInfo = CKSubscription.NotificationInfo()
notificationInfo.shouldSendContentAvailable = true
subscription.notificationInfo = notificationInfo

do {
    let savedSubscription = try await privateDB.save(subscription)
    print("Subscription created: \(savedSubscription)")
} catch {
    print("Subscription failed: \(error)")
}
```

### ✅ Error Handling Patterns
```swift
func handleCloudKitError(_ error: Error) {
    guard let ckError = error as? CKError else { 
        print("Non-CloudKit error: \(error)")
        return 
    }
    
    switch ckError.code {
    case .networkUnavailable, .networkFailure:
        // Retry with exponential backoff
        scheduleRetryWithBackoff()
        
    case .notAuthenticated:
        // User not signed into iCloud
        showSignInPrompt()
        
    case .quotaExceeded:
        // Storage limit reached (per-user quota)
        showStorageUpgradePrompt()
        
    case .requestRateLimited:
        // Too many requests - implement exponential backoff
        // CloudKit enforces rate limits per device
        scheduleRetryWithBackoff(delaySeconds: 60)
        
    case .serverRecordChanged:
        // Handle conflicts
        resolveConflict(ckError)
        
    case .zoneNotFound:
        // Recreate zone
        createRecordZone()
        
    case .changeTokenExpired:
        // Reset sync state
        resetSyncState()
        
    default:
        print("Unhandled CloudKit error: \(ckError.localizedDescription)")
    }
}

func resolveConflict(_ error: CKError) {
    guard let clientRecord = error.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord,
          let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
        return
    }
    
    // Implement your conflict resolution strategy
    // Example: Last-writer-wins
    let mergedRecord = mergeRecords(client: clientRecord, server: serverRecord)
    
    Task {
        do {
            try await privateDB.save(mergedRecord)
        } catch {
            print("Failed to resolve conflict: \(error)")
        }
    }
}
```

### ✅ CloudKit Production Considerations
```swift
// CloudKit Quotas and Limits (approximate, subject to change):
// - Request rate: ~40 requests/second per device
// - Batch operations: Max 400 records per batch
// - Record size: 1MB max per record
// - Asset size: 250MB max per asset
// - Container storage: 10GB public DB, user's iCloud quota for private DB

// Implement retry with exponential backoff
func retryWithExponentialBackoff<T>(
    operation: @escaping () async throws -> T,
    maxRetries: Int = 5,
    initialDelay: TimeInterval = 1.0
) async throws -> T {
    var lastError: Error?
    var delay = initialDelay
    
    for attempt in 0..<maxRetries {
        do {
            return try await operation()
        } catch let error as CKError {
            lastError = error
            
            // Check if error is retryable
            switch error.code {
            case .requestRateLimited, .networkFailure, .networkUnavailable:
                // Wait with exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2  // Double the delay for next attempt
                
            default:
                // Non-retryable error
                throw error
            }
        } catch {
            // Non-CloudKit error
            throw error
        }
    }
    
    throw lastError ?? CKError(.networkFailure)
}

// Monitor quota usage
func checkQuotaBeforeLargeOperation() async throws {
    // Check user's available iCloud storage
    // Note: No direct API for this, implement estimation based on:
    // 1. Track your app's data usage
    // 2. Handle quotaExceeded errors gracefully
    // 3. Prompt users to manage iCloud storage when needed
}
```

---

## Swift Concurrency API Reference

### ✅ Basic Async/Await (iOS 13+ language, iOS 15+ APIs)
```swift
// Basic async function - VERIFIED
func fetchTripData() async throws -> Data {
    let url = URL(string: "https://api.example.com/trip")!
    let (data, _) = try await URLSession.shared.data(from: url)  // iOS 15+
    return data
}

// Calling async functions - VERIFIED
func loadTrip() async {
    do {
        let data = try await fetchTripData()
        await updateUI(with: data)
    } catch {
        await handleError(error)
    }
}
```

### ✅ Structured Concurrency (iOS 13+)
```swift
// Task groups - VERIFIED
func loadMultipleTrips(ids: [UUID]) async throws -> [Trip] {
    try await withThrowingTaskGroup(of: Trip.self) { group in
        for id in ids {
            group.addTask {
                try await fetchTrip(id: id)
            }
        }
        
        var trips: [Trip] = []
        for try await trip in group {
            trips.append(trip)
        }
        return trips
    }
}

// Async let - VERIFIED
func loadTripWithDetails(id: UUID) async throws -> (Trip, [Activity]) {
    async let trip = fetchTrip(id: id)
    async let activities = fetchActivities(tripId: id)
    
    return try await (trip, activities)
}
```

### ✅ Actors (iOS 13+)
```swift
actor DataCache {
    private var items: [UUID: Trip] = [:]
    
    func store(_ trip: Trip) {
        items[trip.id] = trip
    }
    
    func retrieve(id: UUID) -> Trip? {
        items[id]
    }
    
    // Non-isolated methods
    nonisolated func generateNewID() -> UUID {
        UUID()  // Cannot access mutable state from here
    }
}

// Usage
let cache = DataCache()
await cache.store(trip)           // Async call due to actor isolation
let retrieved = await cache.retrieve(id: tripID)  // Async call
let newID = cache.generateNewID() // Sync call - non-isolated
```

### ✅ MainActor (iOS 13+)
```swift
@MainActor
class UIViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    
    func loadTrips() async {
        isLoading = true
        defer { isLoading = false }
        
        // This automatically runs on main thread
        do {
            trips = try await dataService.fetchTrips()
        } catch {
            handleError(error)
        }
    }
    
    nonisolated func getStaticInfo() -> String {
        // Cannot access @Published properties from here
        return "Static information"
    }
}

// Explicit MainActor usage
func updateUIExplicitly() async {
    await MainActor.run {
        // Force execution on main thread
        label.text = "Updated"
    }
}
```

### ✅ Task Management (iOS 13+)
```swift
// Task creation and cancellation - VERIFIED
class OperationManager {
    private var currentTask: Task<Void, Never>?
    
    func startOperation() {
        currentTask = Task {
            while !Task.isCancelled {
                do {
                    try await performWork()
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                } catch {
                    if Task.isCancelled {
                        break
                    }
                    print("Operation error: \(error)")
                }
            }
        }
    }
    
    func stopOperation() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    private func performWork() async throws {
        // Check for cancellation periodically
        try Task.checkCancellation()
        
        // Do work
        await heavyOperation()
        
        // Cooperative scheduling
        await Task.yield()
    }
}
```

### ✅ AsyncSequence (iOS 13+)
```swift
// Custom AsyncSequence - VERIFIED pattern
struct DataUpdates: AsyncSequence {
    typealias Element = Data
    
    func makeAsyncIterator() -> DataAsyncIterator {
        DataAsyncIterator()
    }
}

struct DataAsyncIterator: AsyncIteratorProtocol {
    private var isRunning = true
    
    func next() async -> Data? {
        guard isRunning else { return nil }
        
        // Simulate async data arrival
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        if Bool.random() {
            isRunning = false
            return nil
        }
        
        return Data("Sample data".utf8)
    }
}

// Usage
for await data in DataUpdates() {
    await processData(data)
}
```

---

## Testing Patterns

### ✅ SwiftData Testing (iOS 17+)
```swift
import XCTest
import SwiftData

class DataManagerTests: XCTestCase {
    var container: ModelContainer!
    var dataManager: TripDataManager!
    
    override func setUp() async throws {
        // In-memory container for isolated tests - VERIFIED
        let config = ModelConfiguration(
            schema: Schema([Trip.self, Activity.self]),
            isStoredInMemoryOnly: true
        )
        container = try ModelContainer(for: config)
        dataManager = TripDataManager(modelContainer: container)
    }
    
    override func tearDown() async throws {
        container = nil
        dataManager = nil
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
}
```

### ✅ Async Testing Patterns (iOS 13+)
```swift
func testAsyncOperation() async throws {
    let result = try await asyncFunction()
    XCTAssertEqual(result.count, 5)
}

func testConcurrentOperations() async throws {
    async let operation1 = performAsyncOperation1()
    async let operation2 = performAsyncOperation2()
    
    let (result1, result2) = try await (operation1, operation2)
    
    XCTAssertNotNil(result1)
    XCTAssertNotNil(result2)
}

func testActorBehavior() async throws {
    let actor = TestActor()
    
    // Test concurrent access
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask {
                await actor.increment(by: i)
            }
        }
    }
    
    let finalValue = await actor.getValue()
    XCTAssertEqual(finalValue, 4950) // Sum of 0-99
}
```

---

## Debugging Tools

### ⚠️ SwiftData Debugging (iOS 17+)
```bash
# Launch arguments in Xcode scheme - UNCERTAIN: Flag names may vary
-SwiftData.SQLDebug 1
-SwiftData.Logging.stderr 1
-SwiftData.Debug 1
-SwiftData.CloudKit.Debug 1

# Alternative approach - check Console.app for SwiftData logs
```

### ✅ View Recreation Debugging (iOS 13+)
```swift
struct DebugView: View {
    var body: some View {
        let _ = Self._printChanges()  // Shows what caused view update
        
        VStack {
            Text("Content")
        }
    }
}
```

### ✅ Actor Debugging (iOS 13+)
```swift
actor DebuggableActor {
    private var operations: [String] = []
    
    func logOperation(_ name: String) {
        operations.append("\(Date()): \(name)")
    }
    
    func getOperationLog() -> [String] {
        operations
    }
}
```

### CloudKit Debugging
- ✅ Use CloudKit Console (developer.icloud.com) for schema inspection
- ✅ Monitor CloudKit logs in Console.app
- ✅ Check Settings > [Your Name] > iCloud on device for sync status

---

## API Availability Matrix

| API | iOS Version | Status | Notes |
|-----|-------------|--------|-------|
| SwiftData @Model | 17.0+ | ✅ Stable | Core functionality |
| SwiftData @Query | 17.0+ | ✅ Stable | SwiftUI integration |
| SwiftData #Index | 18.0+ | ✅ Stable | Performance feature |
| SwiftData #Unique | 18.0+ | 🚫 Avoid | Not CloudKit compatible |
| @ModelActor | 17.0+ | 🚫 Avoid | Threading issues |
| CloudKit basic ops | 8.0+ | ✅ Stable | save, fetch, delete |
| CloudKit async/await | 15.0+ | ✅ Stable | Modern APIs |
| Swift async/await | 13.0+ | ✅ Stable | Language feature |
| Swift Actors | 13.0+ | ✅ Stable | Language feature |
| URLSession async | 15.0+ | ✅ Stable | Framework API |

---

## 📖 Related Wiki Pages

### Integration and Patterns
- **[INTEGRATION_PATTERNS_GUIDE.md](INTEGRATION_PATTERNS_GUIDE.md)** - Primary technical guide for practical implementation
- **[SwiftData-Patterns.md](SwiftData-Patterns.md)** - Specific SwiftData usage patterns and examples

### Architecture and Development
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - App structure and MVVM patterns
- **[Development-Workflow.md](Development-Workflow.md)** - Testing procedures and development guidelines

### Quick Navigation
- **[Home.md](Home.md)** - Wiki overview and getting started guide

---

**Note**: This reference provides detailed API syntax. For integration patterns and workflows, use [INTEGRATION_PATTERNS_GUIDE.md](INTEGRATION_PATTERNS_GUIDE.md) as your primary reference.