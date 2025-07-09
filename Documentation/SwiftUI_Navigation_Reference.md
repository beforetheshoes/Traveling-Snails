# SwiftUI Navigation Reference Guide

## Core Navigation Components

### NavigationStack
- **Purpose**: Single-column stack-based navigation (replacement for NavigationView)
- **Availability**: iOS 16.0+
- **Best For**: iPhone, compact layouts, sequential navigation flows
- **Key Features**:
  - Type-erased NavigationPath for mixed navigation types
  - Programmatic navigation via path binding
  - Type-safe navigation destinations
  - Built-in back button handling

### NavigationSplitView  
- **Purpose**: Multi-column adaptive navigation (2-3 columns)
- **Availability**: iOS 16.0+
- **Best For**: iPad, macOS, large screen layouts
- **Key Features**:
  - Automatic column management
  - Sidebar, content, and detail columns
  - Platform-adaptive behavior
  - Automatic NavigationStack wrapping in columns

### TabView
- **Purpose**: Tab-based navigation with multiple root flows
- **Availability**: iOS 13.0+ (significant updates in iOS 18)
- **Best For**: Top-level navigation, multiple independent flows
- **Key Features**:
  - Independent navigation paths per tab
  - Customizable tab items
  - iOS 18 introduces optional `sidebarAdaptable` tab view style for iPad, which can be activated via `.tabViewStyle(.sidebarAdaptable)`
  - Tab customization support

## Architecture Hierarchy Rules

### Critical Rule: TabView as Root Container
```swift
// ✅ CORRECT: TabView at root level
TabView {
    NavigationStack(path: $homeNavigationPath) {
        HomeView()
    }
    .tabItem { Label("Home", systemImage: "house") }
    
    NavigationStack(path: $settingsNavigationPath) {
        SettingsView()
    }
    .tabItem { Label("Settings", systemImage: "gear") }
}

// ❌ WRONG: NavigationStack wrapping TabView
NavigationStack {
    TabView { ... } // Causes navigation conflicts
}
```

### NavigationSplitView Integration
```swift
// ✅ CORRECT: NavigationSplitView with internal NavigationStack
NavigationSplitView {
    SidebarView()
} content: {
    ContentView()
} detail: {
    NavigationStack(path: $detailPath) {
        DetailView()
            .navigationDestination(for: DetailRoute.self) { route in
                // Handle detail navigation
            }
    }
}

// ❌ WRONG: NavigationStack wrapping NavigationSplitView
NavigationStack {
    NavigationSplitView { ... } // Remove outer NavigationStack
}
```

## NavigationPath and Programmatic Navigation

### NavigationPath Capabilities
- **Type-erased container**: Can hold mixed types in single path
- **Path manipulation**: append(), removeLast(), isEmpty, count
- **Codable support**: Available if all types stored in the path conform to Codable
- **Limitations**: Can only pop from end, no middle removal

### Implementation Patterns
```swift
@Observable
class NavigationRouter {
    var path = NavigationPath()
    
    func navigate(to destination: any Hashable) {
        path.append(destination)
    }
    
    func navigateBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}
```

## iOS 18 Specific Issues and Workarounds

### Known Bug: TabView + NavigationStack Double Push
- **Issue**: Navigation destinations pushed twice when using NavigationStack inside TabView
- **Affected**: iOS 18.0 initial releases (may be resolved in later updates)
- **Root Cause**: This issue stems from SwiftUI observing @Published changes too late in the update cycle, causing navigation destinations to trigger twice. Using @State or @Binding directly in the view avoids this timing issue.
- **Workaround**: Use @State path directly in view instead of @Published router property

```swift
// Workaround for iOS 18 double-push bug
struct TabContentView: View {
    @State private var path: [Destination] = [] // Direct @State, not router
    
    var body: some View {
        NavigationStack(path: $path) {
            ContentView()
                .navigationDestination(for: Destination.self) { destination in
                    DestinationView(destination: destination)
                }
        }
    }
}
```

## Modern Architecture Patterns

### Router Pattern
```swift
@Observable
class AppRouter {
    var homeNavigationPath = NavigationPath()
    var settingsNavigationPath = NavigationPath()
    var selectedTab: AppTab = .home
    
    func navigate(to destination: any Hashable, in tab: AppTab) {
        switch tab {
        case .home:
            homeNavigationPath.append(destination)
        case .settings:
            settingsNavigationPath.append(destination)
        }
    }
}
```

### Coordinator Pattern Adaptation
```swift
protocol NavigationCoordinator: AnyObject {
    associatedtype Route: Hashable
    func handle(_ route: Route)
}

@Observable
class FeatureCoordinator: NavigationCoordinator {
    var path = NavigationPath()
    
    func handle(_ route: FeatureRoute) {
        switch route {
        case .detail(let item):
            path.append(item)
        case .back:
            path.removeLast()
        }
    }
}
```

### Environment-Based Navigation
```swift
struct NavigationEnvironmentKey: EnvironmentKey {
    static var defaultValue: NavigationAction = NavigationAction { _ in }
}

extension EnvironmentValues {
    var navigate: NavigationAction {
        get { self[NavigationEnvironmentKey.self] }
        set { self[NavigationEnvironmentKey.self] = newValue }
    }
}
```

## Platform-Adaptive Strategies

### Size Class Based Adaptation
```swift
struct AdaptiveNavigationView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                SidebarView()
            } detail: {
                NavigationStack(path: $navigationPath) {
                    DetailView()
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestinationView(route: route)
                        }
                }
            }
        } else {
            TabView {
                NavigationStack(path: $navigationPath) {
                    CompactView()
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestinationView(route: route)
                        }
                }
                .tabItem { Label("Main", systemImage: "house") }
            }
        }
    }
}
```

## Anti-Patterns to Avoid

### Navigation Hierarchy Violations
1. **Never nest TabView inside NavigationStack**
2. **Never wrap NavigationSplitView in NavigationStack**
3. **Never pass NavigationPath between unrelated views**

### State Management Issues
1. **Don't create @Observable navigation objects in view body**
2. **Don't use @StateObject with navigation routers** (use @State instead)
3. **Don't share single NavigationPath across multiple tabs**

### iOS 18 Specific Pitfalls
1. **Avoid @Published NavigationPath in router classes** (causes double-push)
2. **Don't rely on deprecated TabView APIs**
3. **Test navigation thoroughly on iOS 18 simulators**

## Navigation Destination Management

### Type-Based Routing
```swift
enum AppDestination: Hashable {
    case userProfile(User)
    case settings(SettingsSection)
    case detail(String)
}

NavigationStack(path: $navigationPath) {
    RootView()
        .navigationDestination(for: AppDestination.self) { destination in
            switch destination {
            case .userProfile(let user):
                UserProfileView(user: user)
            case .settings(let section):
                SettingsView(section: section)
            case .detail(let id):
                DetailView(id: id)
            }
        }
}
```

## Testing Considerations

### Navigation State Testing
- Test path manipulation methods
- Verify correct destination mapping
- Test deep linking scenarios
- Validate state restoration

### iOS 18 Compatibility Testing
- Test on iOS 18 simulators specifically
- Verify tab navigation doesn't double-push
- Test adaptive layout transitions
- Validate deprecation warning handling

## Migration Guidelines

### From NavigationView to NavigationStack
1. Replace NavigationView with NavigationStack
2. Add NavigationPath binding for programmatic navigation
3. Convert NavigationLink(destination:) to NavigationLink(value:)
4. Add navigationDestination modifiers
5. Update navigation state management

### Preparing for Future iOS Versions
- Use @Observable instead of ObservableObject
- Consider using `.navigationTransition(_:)` (iOS 18+) to customize navigation animations in supported contexts, though options are currently limited
- Plan for further TabView evolution
- Consider adaptive design requirements