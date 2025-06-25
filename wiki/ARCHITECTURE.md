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
- **PermissionStatusManager**: Photo library permission management and user guidance

### 4. Manager Patterns

#### Manager Responsibilities:
- Singleton pattern for app-wide state management
- System permission and capability checking
- Cross-cutting concerns that don't fit in ViewModels or Services
- Hardware feature management (biometrics, camera, photos)

#### Established Manager Pattern:
```swift
@Observable
@MainActor
class PermissionStatusManager {
    static let shared = PermissionStatusManager()
    
    // MARK: - Permission Status Properties
    var photoLibraryAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    var canUsePhotoLibrary: Bool {
        switch photoLibraryAuthorizationStatus {
        case .authorized, .limited: return true
        default: return false
        }
    }
    
    // MARK: - Actions
    nonisolated func requestPhotoLibraryAccess() async -> PHAuthorizationStatus {
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
    
    func openAppSettings() {
        // Navigate to Settings app
    }
    
    private init() { } // Singleton enforcement
}
```

#### Current Managers:
- **BiometricAuthManager**: Touch ID/Face ID authentication and trip protection
- **PermissionStatusManager**: Photo library permission checking and user guidance

### 5. Dependency Injection

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
├── Components/         # Reusable UI components
│   └── ActivityForm/   # Modular activity section components
├── Unified/            # Generic/unified views
└── UnifiedTripActivities/ # Trip activity views

ViewModels/             # Business logic and state management
├── SettingsViewModel.swift  # Enhanced with database cleanup functionality
├── CalendarViewModel.swift
├── UniversalActivityFormViewModel.swift  # Enhanced with edit mode support
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

## Navigation State Management Patterns

### Deep Navigation Reset on External Selection

#### Problem Statement
When users navigate deeply into the app (e.g., Trip → Activity Detail), selecting a different trip from the sidebar should return them to the trip detail root, not keep them on the activity detail screen.

#### Solution Pattern: Notification-Based Navigation Reset

**✅ CORRECT Implementation:**

```swift
// 1. Define notification in the detail view file
extension Notification.Name {
    static let tripSelectedFromList = Notification.Name("tripSelectedFromList")
}

// 2. Listen for external selection in detail view
struct IsolatedTripDetailView: View {
    @State private var navigationPath = NavigationPath()
    let trip: Trip
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            // ... view content
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripSelectedFromList)) { notification in
            if let selectedTripId = notification.object as? UUID, selectedTripId == trip.id {
                let previousCount = navigationPath.count
                if previousCount > 0 {
                    navigationPath = NavigationPath()
                    print("📱 Trip selected from list - cleared navigation path (was \(previousCount) deep)")
                }
            }
        }
    }
}

// 3. Post notification when trip is selected from list
struct UnifiedNavigationView<Item: NavigationItem, DetailView: View>: View {
    // ... existing code
    
    .onTapGesture {
        // ... existing selection logic
        
        if let trip = item as? Trip {
            selectedTrip = trip
            // Notify detail view to reset navigation path
            NotificationCenter.default.post(name: .tripSelectedFromList, object: trip.id)
        }
    }
}
```

#### Key Benefits:
- **Decoupled Communication**: Navigation view and detail view don't need direct references
- **Scalable Pattern**: Can be extended for other deep navigation scenarios
- **User Experience**: Intuitive behavior - selecting trip from list goes to trip root
- **State Management**: Preserves proper navigation state without interference

#### When to Use This Pattern:
- Deep navigation that should reset on external selection
- Cross-view communication without tight coupling
- Navigation coordination between sidebar and detail views
- Any scenario where user expects "start fresh" behavior

#### Alternative Patterns (Not Recommended):
❌ **Binding Propagation**: Complex binding chains are fragile  
❌ **Direct Method Calls**: Requires tight coupling between views  
❌ **Environment Objects**: Overkill for simple coordination  

This notification pattern maintains the clean separation of concerns while providing responsive navigation behavior that meets user expectations.

## Reusable Component Architecture Patterns

### Component Reuse Strategy

The app implements a modular component system to eliminate code duplication and ensure UI consistency across different contexts (add/edit/detail views).

#### Component Design Principles

**✅ CORRECT Pattern - Reusable Section Components:**

```swift
/// Reusable section component for displaying and editing activity basic information
struct ActivityBasicInfoSection<T: TripActivityProtocol>: View {
    let activity: T?
    @Binding var editData: TripActivityEditData
    let isEditing: Bool
    let color: Color
    let icon: String
    let attachmentCount: Int
    
    var body: some View {
        ActivitySectionCard(
            headerIcon: icon,
            headerTitle: "Basic Information",
            headerColor: color
        ) {
            VStack(spacing: 16) {
                if isEditing {
                    editModeContent
                } else {
                    viewModeContent
                }
            }
        }
    }
}
```

**Key Design Decisions:**
- **Generic Type Constraints**: `<T: TripActivityProtocol>` allows the same component to work with Activity, Lodging, and Transportation
- **Mode-Based Rendering**: Single component handles both view and edit modes with `@ViewBuilder` conditional content
- **Consistent Wrapper**: `ActivitySectionCard` provides uniform styling and spacing across all sections
- **Flexible Parameters**: Optional activity for add mode, required editData binding for state management

#### Component Library Structure

```
Views/Components/ActivityForm/
├── ActivityBasicInfoSection.swift      # Name, icon, transportation type
├── ActivityLocationSection.swift       # Organization, custom location, map
├── ActivityScheduleSection.swift       # Date/time with timezone support
├── ActivityCostSection.swift          # Cost, payment status, per-night calculation
├── ActivityDetailsSection.swift       # Confirmation, notes, contact info
├── ActivityAttachmentsSection.swift   # File attachment management
├── ActivitySectionCard.swift          # Consistent section wrapper
└── ActivityFormField.swift            # Reusable form input field
```

### Component Reuse Benefits

#### Before Refactoring (Issue #14):
- **UnifiedTripActivityDetailView**: 951 lines of custom section implementations
- **Code Duplication**: Similar UI patterns repeated across add/edit/detail views
- **Maintenance Burden**: Changes required updating multiple similar implementations
- **Inconsistent UX**: Slight variations in styling and behavior between contexts

#### After Refactoring:
- **UnifiedTripActivityDetailView**: 352 lines (63% reduction) using reusable components
- **Consistent UI**: All activity sections use identical styling and behavior
- **Maintainability**: Single component to update for changes across all contexts
- **Enhanced Testing**: Components can be tested in isolation with comprehensive test coverage

### Component Testing Strategy

#### Comprehensive TDD Approach:
```swift
@Suite("Activity Section Components")
struct ActivitySectionComponentsTests {
    @Test("ActivityBasicInfoSection displays correctly in view mode")
    func testBasicInfoSectionViewMode() {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Test Trip", start: Date(), end: Date())
        let activity = Activity()
        activity.name = "Test Activity"
        activity.trip = trip
        
        let editData = TripActivityEditData(from: activity)
        
        // Test view mode rendering
        #expect(activity.name == "Test Activity")
        #expect(editData.name == "Test Activity")
    }
    
    @Test("ActivityBasicInfoSection allows editing in edit mode")
    func testBasicInfoSectionEditMode() {
        // Test edit mode functionality
        // Verify form fields are editable
        // Confirm data binding works correctly
    }
}
```

#### Test Coverage Areas:
1. **View Mode Display**: Verify correct data presentation for each activity type
2. **Edit Mode Functionality**: Confirm form fields work and bind to editData properly
3. **Type-Specific Behavior**: Test transportation type picker, lodging per-night calculation
4. **Error States**: Handle missing data, invalid inputs gracefully
5. **Accessibility**: VoiceOver labels and navigation work correctly

### Component Integration Pattern

#### Universal Form System Integration:
```swift
struct UniversalAddActivityFormContent: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Reuse the same components as detail view
                ActivityBasicInfoSection(
                    editData: $viewModel.editData,
                    isEditing: true,
                    color: Color(hex: viewModel.color),
                    icon: viewModel.icon,
                    attachmentCount: viewModel.attachments.count
                )
                
                ActivityLocationSection(
                    editData: $viewModel.editData,
                    isEditing: true,
                    color: Color(hex: viewModel.color),
                    supportsCustomLocation: viewModel.supportsCustomLocation,
                    showingOrganizationPicker: { viewModel.showingOrganizationPicker = true }
                )
                
                // ... other sections
            }
        }
    }
}
```

#### Detail View Integration:
```swift
struct UnifiedTripActivityDetailView<T: TripActivityProtocol>: View {
    let activity: T
    @State private var editData: TripActivityEditData
    @State private var isEditing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Same components, different context
                ActivityBasicInfoSection(
                    activity: activity,
                    editData: $editData,
                    isEditing: isEditing,
                    color: activity.color,
                    icon: activity.icon,
                    attachmentCount: attachments.count
                )
                
                // ... same section components
            }
        }
    }
}
```

### Enhanced ViewModel Pattern for Component Support

#### UniversalActivityFormViewModel Edit Mode Enhancement:
```swift
@Observable
class UniversalActivityFormViewModel {
    // MARK: - Edit mode support
    private let existingActivity: (any TripActivityProtocol)?
    let isEditMode: Bool
    
    /// Initialize for editing an existing activity
    init<T: TripActivityProtocol>(existingActivity: T, modelContext: ModelContext) {
        self.existingActivity = existingActivity
        self.isEditMode = true
        self.editData = TripActivityEditData(from: existingActivity)
        self.attachments = existingActivity.fileAttachments
        // ... proper initialization
    }
    
    private func updateExistingActivity() throws {
        guard let existingActivity = existingActivity else { return }
        
        // Type-safe updates based on activity type
        updateActivityProperties(existingActivity)
        updateActivityAttachments(existingActivity)
        try modelContext.save()
    }
}
```

### Component Reuse Metrics

#### Quantifiable Improvements:
- **Lines of Code**: Reduced from 951 to 352 lines (63% reduction)
- **Code Duplication**: Eliminated ~600 lines of duplicate section implementations
- **Test Coverage**: Added 25+ isolated component tests
- **Maintainability**: 6 reusable components vs 5 custom implementations
- **Consistency**: 100% UI pattern consistency across add/edit/detail contexts

This component architecture establishes a foundation for future UI consistency and dramatically reduces the maintenance burden while improving user experience through standardized interfaces.

## Smart Transportation Icon System

### Dynamic Icon Resolution Pattern

**Problem**: Transportation activities displayed generic car icons instead of specific transportation type icons (airplane, train, ferry, etc.), creating poor visual differentiation and user experience inconsistency.

**✅ CORRECT Solution - Reactive Icon System:**

```swift
// In UniversalActivityFormViewModel - Real-time form updates
var currentIcon: String {
    // For transportation activities, use the selected transportation type icon
    if case .transportation = activityType,
       let transportationType = editData.transportationType {
        return transportationType.systemImage
    }
    // For other activity types, use the default icon
    return icon
}

// In UnifiedTripActivityDetailView - Edit mode support
private var currentIcon: String {
    // In edit mode for transportation activities, use the selected transportation type icon
    if isEditing,
       case .transportation = activity.activityType,
       let transportationType = editData.transportationType {
        return transportationType.systemImage
    }
    // Otherwise, use the activity's default icon
    return activity.icon
}
```

### Activity List Icon Pattern

**ActivityRowView and ActivityTimelineRow Updates:**
```swift
// ❌ BEFORE - Generic car icon for all transportation
Image(systemName: wrapper.type.icon) // Always "car.fill"

// ✅ AFTER - Specific transportation type icons
Image(systemName: wrapper.tripActivity.icon) // "airplane", "train.side.front.car", etc.
```

### Transportation Type Icon Mapping

```swift
enum TransportationType: String, CaseIterable, Codable {
    case train, plane, boat, car, bicycle, walking
    
    var systemImage: String {
        switch self {
        case .train: return "train.side.front.car"
        case .plane: return "airplane"
        case .boat: return "ferry"
        case .car: return "car"
        case .bicycle: return "bicycle"
        case .walking: return "figure.walk"
        }
    }
}
```

### Reactive Icon Update Benefits

1. **Immediate Visual Feedback**: Icons update instantly when users change transportation types
2. **Form System Coverage**: Works in both create (UniversalAddActivityFormContent) and edit (UnifiedTripActivityDetailView) modes
3. **List Consistency**: Activity lists show specific transportation type icons
4. **No Save Required**: Real-time updates without needing to save changes first
5. **Backward Compatible**: Non-transportation activities continue using static icons

### Technical Implementation

**Two Form Systems Enhanced:**
- **UniversalAddActivityFormContent**: Used for creating new activities
- **UnifiedTripActivityDetailView**: Used for editing existing activities

Both systems now use computed properties that leverage SwiftUI's `@Observable` pattern for automatic UI updates when `editData.transportationType` changes.

**Key Design Decisions:**
- **Generic vs Specific Icons**: ActivityWrapper.type.icon remains generic ("car.fill") while tripActivity.icon returns specific transportation type icons
- **Reactive Pattern**: Uses SwiftUI's @Observable for automatic UI updates
- **Dual Form Support**: Consistent behavior across both create and edit workflows
- **Zero Breaking Changes**: Maintains all existing functionality while adding new capabilities