# SwiftData Patterns and Anti-Patterns

This document outlines critical SwiftData usage patterns to prevent infinite view recreation bugs and ensure optimal performance.

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

---

Following these patterns ensures stable, performant SwiftData operations throughout the Traveling Snails app.