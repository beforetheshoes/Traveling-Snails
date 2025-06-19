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

## File Organization

### Current Structure:
```
Views/
├── Calendar/           # Calendar-specific views
├── FileAttachments/    # File attachment views
├── HelperViews/        # Reusable UI components
├── Organizations/      # Organization views
├── Settings/           # Settings views
├── Trips/              # Trip views
├── Unified/            # Generic/unified views
└── UnifiedTripActivities/ # Trip activity views

ViewModels/             # Business logic and state management
├── ActivityFormViewModel.swift
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

This architecture ensures scalable, maintainable, and testable SwiftUI applications following established best practices.