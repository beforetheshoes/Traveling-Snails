# Traveling Snails - MVVM Architecture Patterns

## Overview
This document outlines the established MVVM architecture patterns used throughout the Traveling Snails codebase to ensure consistency and maintainability.

## Core Principles

### 1. Root View + Content View Pattern
Based on the article "Massive views are the cause of most architectural problems in SwiftUI apps", we split views into two categories:

#### Root Views
- Serve as coordinators between UI and business logic layers
- Manage ViewModels and dependencies
- Handle navigation and external integration
- Minimal UI code - mainly coordination logic
- Examples: `TripDetailView`, `SettingsView`, `TripCalendarView`

#### Content Views  
- Focus solely on UI layout and rendering
- Receive simple data types (String, Int, URL, etc.)
- No direct model dependencies
- Highly reusable and testable
- Examples: `SettingsContentView`, `CalendarContentView`, `AddActivityFormContent`

### 2. ViewModel Patterns

#### Established Conventions:
```swift
@Observable
class SomeViewModel {
    // MARK: - Dependencies (injected)
    let dependency: SomeService
    private let modelContext: ModelContext
    
    // MARK: - State Properties
    var publicState: String = ""
    private var privateState: Bool = false
    
    // MARK: - Initialization
    init(dependency: SomeService, modelContext: ModelContext) {
        self.dependency = dependency
        self.modelContext = modelContext
    }
    
    // MARK: - Public Actions
    func performAction() {
        // Business logic here
    }
}
```

### 3. Global Settings Management Pattern

#### AppSettings with Simplified @Observable + Environment Object Pattern
Used for app-wide configuration that needs persistence, global access, and iCloud synchronization:

```swift
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    // MARK: - Storage systems
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Private backing storage (prevents infinite @Observable loops)
    private var _colorScheme: ColorSchemePreference = .system
    private var _biometricTimeoutMinutes: Int = 5
    
    // MARK: - Public @Observable properties with computed accessors
    var colorScheme: ColorSchemePreference {
        get { _colorScheme }
        set {
            _colorScheme = newValue
            // Save to both stores for reliability
            userDefaults.set(newValue.rawValue, forKey: Keys.colorScheme)
            ubiquitousStore.set(newValue.rawValue, forKey: Keys.colorScheme)
            ubiquitousStore.synchronize()
        }
    }
    
    var biometricTimeoutMinutes: Int {
        get { _biometricTimeoutMinutes }
        set {
            _biometricTimeoutMinutes = newValue
            // Save to both stores
            userDefaults.set(newValue, forKey: Keys.biometricTimeoutMinutes)
            ubiquitousStore.set(newValue, forKey: Keys.biometricTimeoutMinutes)
            ubiquitousStore.synchronize()
        }
    }
    
    // Private init ensures singleton usage
    private init() {
        loadFromStorage()
        setupICloudNotifications()
    }
    
    private func loadFromStorage() {
        // Load with proper fallback hierarchy: UserDefaults -> iCloud -> defaults
        if let stored = userDefaults.string(forKey: Keys.colorScheme),
           let preference = ColorSchemePreference(rawValue: stored) {
            _colorScheme = preference
        } else if let cloud = ubiquitousStore.string(forKey: Keys.colorScheme),
                  let preference = ColorSchemePreference(rawValue: cloud) {
            _colorScheme = preference
        } else {
            _colorScheme = .system // Reset to default when both stores are empty
        }
        
        // Load biometric timeout with defaults
        let storedTimeout = userDefaults.integer(forKey: Keys.biometricTimeoutMinutes)
        if storedTimeout > 0 {
            _biometricTimeoutMinutes = storedTimeout
        } else {
            let cloudTimeout = Int(ubiquitousStore.longLong(forKey: Keys.biometricTimeoutMinutes))
            if cloudTimeout > 0 {
                _biometricTimeoutMinutes = cloudTimeout
            } else {
                _biometricTimeoutMinutes = 5 // Reset to default
            }
        }
    }
    
    private func setupICloudNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        ubiquitousStore.synchronize()
    }
    
    @objc private func iCloudChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        
        Task { @MainActor in
            // Handle external changes from other devices
            if changedKeys.contains(Keys.colorScheme) {
                if let cloudValue = self.ubiquitousStore.string(forKey: Keys.colorScheme),
                   let preference = ColorSchemePreference(rawValue: cloudValue),
                   preference != self._colorScheme {
                    
                    // Update backing storage directly to avoid writing back to iCloud
                    self._colorScheme = preference
                    // Also update UserDefaults for consistency
                    self.userDefaults.set(preference.rawValue, forKey: Keys.colorScheme)
                }
            }
            
            if changedKeys.contains(Keys.biometricTimeoutMinutes) {
                let cloudValue = Int(self.ubiquitousStore.longLong(forKey: Keys.biometricTimeoutMinutes))
                if cloudValue > 0 && cloudValue != self._biometricTimeoutMinutes {
                    // Update backing storage directly
                    self._biometricTimeoutMinutes = cloudValue
                    self.userDefaults.set(cloudValue, forKey: Keys.biometricTimeoutMinutes)
                }
            }
        }
    }
}
```

#### Why NSUbiquitousKeyValueStore for User Settings

**✅ CORRECT Pattern (Current Implementation):**
- **NSUbiquitousKeyValueStore**: Purpose-built for user preferences that sync across devices
- **UserDefaults fallback**: Provides reliability when iCloud is unavailable
- **Automatic notifications**: Built-in change notifications when other devices update settings
- **Apple-recommended**: Official Apple solution for syncing user preferences

**❌ WRONG Pattern (Previous Implementation):**
- **SwiftData for user preferences**: Overkill for simple key-value settings
- **Fatal crashes**: SwiftData model lifecycle issues with singleton settings access
- **Complexity**: Relationship management unnecessary for simple preferences

#### @State Environment Object Pattern (Recommended)
For immediate UI response and simplified architecture, use direct environment object access:

```swift
// App Root - Provide AppSettings as environment object
struct Traveling_SnailsApp: App {
    @State private var appSettings = AppSettings.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appSettings) // Provide as environment object
        }
    }
}

// Content Views - Direct environment access (NO @Bindable layers)
struct AppearanceSection: View {
    @Environment(AppSettings.self) private var appSettings
    
    var body: some View {
        Picker("Color Scheme", selection: Binding(
            get: { appSettings.colorScheme },
            set: { appSettings.colorScheme = $0 }
        )) {
            Text("System").tag(ColorSchemePreference.system)
            Text("Light").tag(ColorSchemePreference.light)
            Text("Dark").tag(ColorSchemePreference.dark)
        }
        .pickerStyle(.segmented)
    }
}

// Global Application in ContentView
struct ContentView: View {
    @Environment(AppSettings.self) private var appSettings
    
    var body: some View {
        mainContent
            .preferredColorScheme(appSettings.colorScheme.colorScheme)
    }
}
```

#### ⚠️ Critical Pattern: Avoid Broken @Observable Chains

**❌ WRONG Pattern (Causes Broken Observation):**
```swift
// Multiple @Bindable layers break external change propagation
struct SettingsContentView: View {
    @Bindable var viewModel: SettingsViewModel // ❌ Extra abstraction layer
    
    var body: some View {
        AppearanceSection(viewModel: viewModel) // ❌ Parameter passing
    }
}

struct AppearanceSection: View {
    @Bindable var viewModel: SettingsViewModel // ❌ Another @Bindable layer
    // This prevents external iCloud changes from reaching the UI!
}
```

**✅ CORRECT Pattern (Direct Environment Access):**
```swift
// No abstraction layers - direct environment object access
struct SettingsContentView: View {
    var body: some View {
        AppearanceSection() // ✅ No parameter passing
    }
}

struct AppearanceSection: View {
    @Environment(AppSettings.self) private var appSettings // ✅ Direct access
    // External iCloud changes propagate immediately to UI!
}
```

#### Current ViewModels:
- **ActivityFormViewModel**: Form state management and validation
- **CalendarViewModel**: Calendar state and coordination
- **SettingsViewModel**: Settings operations and state

### 3. Service Layer Patterns

#### Service Responsibilities:
- Pure business logic operations
- Data transformation and validation
- External API interactions
- Stateless operations when possible

#### Examples:
- **ActivityTemplateProvider**: Template creation logic
- **ActivitySaveService**: Persistence operations
- **CalendarDateProvider**: Date calculations
- **DataManagementService**: Import/export operations

### 4. Dependency Injection

#### ViewModels receive dependencies through initializers:
```swift
// Good: Dependencies injected
init(trip: Trip, modelContext: ModelContext, service: SomeService) {
    self.trip = trip
    self.modelContext = modelContext
    self.service = service
}

// Avoid: Direct environment access in ViewModels
@Environment(\.modelContext) private var modelContext // ❌ Don't do this in ViewModels
```

#### Root Views handle environment dependencies:
```swift
struct SomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SomeViewModel?
    
    var body: some View {
        if let viewModel = viewModel {
            SomeContentView(viewModel: viewModel)
        } else {
            ProgressView("Loading...")
                .onAppear {
                    viewModel = SomeViewModel(modelContext: modelContext)
                }
        }
    }
}
```

### 5. Testing Patterns

#### TDD Approach:
1. **Red**: Write failing tests expecting new architecture
2. **Green**: Implement minimum code to make tests pass
3. **Refactor**: Clean up while keeping tests green

#### Test Structure:
```swift
@Suite("Component Tests")
struct ComponentTests {
    @Suite("Business Logic")
    struct BusinessLogicTests {
        @Test("specific behavior")
        func testSpecificBehavior() {
            // Test business logic in isolation
        }
    }
    
    @Suite("UI Behavior") 
    struct UIBehaviorTests {
        @Test("ui interaction")
        func testUIInteraction() {
            // Test UI behavior with mock dependencies
        }
    }
}
```

## Platform-Specific Navigation Architecture

### Modern Navigation Patterns (iOS 18+)

The app uses modern SwiftUI navigation patterns for optimal performance and compatibility:

#### NavigationStack (Not NavigationView)
✅ **CORRECT - Modern Pattern:**
```swift
struct ModernView: View {
    var body: some View {
        NavigationStack {  // ✅ Use NavigationStack for iOS 16+
            List {
                // Content here
            }
            .navigationTitle("Title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

❌ **DEPRECATED - Avoid NavigationView:**
```swift
struct DeprecatedView: View {
    var body: some View {
        NavigationView {  // ❌ NavigationView is deprecated in iOS 16+
            List {
                // Content here
            }
            .navigationTitle("Title")
        }
    }
}
```

**Why NavigationStack is Better:**
- **Performance**: Better memory management and rendering performance
- **iOS 18+ Optimized**: Takes advantage of latest SwiftUI improvements
- **Future-Proof**: NavigationView is deprecated and will be removed
- **Consistent Behavior**: More predictable navigation behavior across platforms

### Adaptive Navigation Pattern

The app implements platform-specific navigation to provide optimal user experience:

#### iPhone Navigation
```swift
// Native TabView for bottom tab bar
TabView(selection: $selectedTab) {
    tripsTab.tabItem { Label("Trips", systemImage: "airplane") }.tag(0)
    organizationsTab.tabItem { Label("Organizations", systemImage: "building.2") }.tag(1)
    settingsTab.tabItem { Label("Settings", systemImage: "gear") }.tag(2)
}
```

#### iPad Navigation  
```swift
// Custom bottom tab bar to avoid navigation title overlap
VStack(spacing: 0) {
    // Content area with switch statement for selected tab
    switch selectedTab {
    case 0: tripsTab
    case 1: organizationsTab  
    case 2: settingsTab
    default: tripsTab
    }
    
    // Custom bottom tab bar with material background
    HStack(spacing: 0) {
        iPadTabButton(title: "Trips", icon: "airplane", isSelected: selectedTab == 0)
        iPadTabButton(title: "Organizations", icon: "building.2", isSelected: selectedTab == 1) 
        iPadTabButton(title: "Settings", icon: "gear", isSelected: selectedTab == 2)
    }
    .frame(height: 60)
    .background(.regularMaterial)
}
```

### Navigation Best Practices

#### 1. Always Use NavigationStack
```swift
// All navigation containers use NavigationStack
struct AddTrip: View {
    var body: some View {
        NavigationStack {  // Modern, performant navigation
            Form {
                // Form content
            }
            .navigationTitle("New Trip")
        }
    }
}
```

#### 2. Navigation State Management
```swift
struct UnifiedNavigationView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar content
        } detail: {
            // Detail content with proper navigation state
        }
    }
}
```

### Benefits of Modern Navigation:
- **iPhone**: Native TabView provides system-standard bottom tabs
- **iPad**: Custom implementation avoids navigation title overlap issues
- **Performance**: NavigationStack provides better performance than NavigationView
- **iOS 18+ Optimized**: Takes advantage of latest SwiftUI navigation improvements
- **Consistent UX**: Both platforms feel native while maintaining feature parity
- **Maintainable**: Shared content views with platform-specific navigation containers

## File Organization

### Current Structure:
```
Views/
├── Calendar/           # Calendar-specific views
├── FileAttachments/    # File attachment views
├── HelperViews/        # Reusable UI components
├── Organizations/      # Organization views
├── Settings/           # Settings views including DatabaseCleanupView
├── Trips/              # Trip views
├── Unified/            # Generic/unified views
└── UnifiedTripActivities/ # Trip activity views

ViewModels/             # Business logic and state management
├── SettingsViewModel.swift  # Enhanced with database cleanup functionality
├── CalendarViewModel.swift
└── SettingsViewModel.swift

Helpers/                # Utility functions
Managers/               # Service layer classes
Models/                 # Data models and extensions
```

### Target Structure (Post-Refactoring):
```
Views/
├── Root/               # Root views (MVVM coordinators)
├── Content/            # Content views (UI only)
└── Components/         # Reusable UI components

ViewModels/             # Business logic and state management
Services/               # Pure business logic services
Helpers/                # Utility functions
Models/                 # Data models and extensions
```

## Code Quality Standards

### ✅ Good Patterns:
- ViewModels under 200 lines
- Content views under 100 lines
- Clear separation of concerns
- Dependency injection
- Comprehensive test coverage

### ❌ Anti-Patterns:
- Views over 200 lines (massive views)
- Business logic in view `body` 
- Direct model access in content views
- Environment dependencies in ViewModels
- Untestable code

## Next Steps

1. **UnifiedNavigationView Refactoring**: Split 492-line view into proper MVVM
2. **Directory Restructure**: Organize files by responsibility
3. **File Renaming**: Clear naming conventions (Root/Content suffixes)
4. **Service Extraction**: Move remaining business logic to services

## Calendar Architecture Patterns

### Calendar View Hierarchy
The calendar system follows the Root View + Content View pattern:

#### CalendarRootView (Coordinator)
- Manages CalendarViewModel lifecycle
- Handles navigation between calendar modes (day, week, month)
- Coordinates with trip data and activity management

#### CalendarContentView (UI Layer)
- Renders calendar interface without business logic
- Delegates user interactions to ViewModel
- Manages sheet presentations and confirmation dialogs

### Calendar-Specific Patterns

#### Timezone Conversion Pattern
```swift
// Extract time components from original timezone
var calendar = Calendar.current
calendar.timeZone = sourceTimeZone
let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

// Create new date in local timezone
calendar.timeZone = TimeZone.current
return calendar.date(from: components) ?? date
```

**Benefits:**
- Consistent "what time will this be for me" display
- Preserves original timezone data for accuracy
- Improves user experience for multi-timezone trips

#### Scroll State Management
```swift
@State private var hasAutoScrolled = false

.onAppear {
    if !hasAutoScrolled {
        scrollToOptimalStartTime(proxy: proxy)
        hasAutoScrolled = true
    }
}
.onChange(of: date) { _, _ in
    hasAutoScrolled = false // Reset for new dates
}
```

**Purpose:**
- Prevents unwanted scroll resets during dialog interactions
- Maintains user scroll position during sheet presentations
- Allows proper auto-scroll when navigating to new dates

#### Dialog State Management Anti-Pattern
```swift
// ❌ WRONG - Aggressive lifecycle management
.onDisappear {
    viewModel.cancelActivityCreation() // Interferes with dialogs
}

// ✅ CORRECT - Let dialogs manage their own lifecycle
.confirmationDialog(...) {
    Button("Cancel", role: .cancel) {
        viewModel.cancelActivityCreation() // User-initiated only
    }
}
```

### Calendar Performance Optimizations

#### ActivityWrapper Equatable Conformance
```swift
struct ActivityWrapper: Identifiable, Equatable {
    static func == (lhs: ActivityWrapper, rhs: ActivityWrapper) -> Bool {
        return lhs.tripActivity.id == rhs.tripActivity.id
    }
}
```

**Benefits:**
- Reduces unnecessary SwiftUI view updates
- Improves calendar rendering performance
- Better diff algorithms for large activity lists

This architecture ensures scalable, maintainable, and testable SwiftUI applications following established best practices.