# Traveling Snails 🐌✈️

A comprehensive travel planning and management app built with SwiftUI for iOS 18+, iPadOS, and macOS. Organize your trips, manage accommodations, track activities, and store important documents all in one place.

## ✨ Features

### 🗺️ Trip Management

- Create and organize multiple trips with start/end dates
- Track total costs and activities per trip  
- Notes and detailed planning for each trip
- Timeline view of all trip activities

### 🏢 Organization Management

- Manage airlines, hotels, tour companies, and other travel organizations
- Store contact information, websites, logos, and addresses
- **Enhanced creation form** with logo URL and address fields featuring real-time security validation
- **SecureURLHandler integration** for safe logo URL input with visual security indicators
- Intelligent address picker with autocomplete and map integration
- Automatic organization linking to trips and activities
- Smart organization suggestions based on past usage
- Clean organization picker interface with proper "None" option handling

### 📅 Calendar & Timeline Views

- Interactive calendar views (day, week, month) for trip visualization
- Smooth activity creation workflow with intuitive type selection
- Smart timezone conversion showing local time across all activities
- Stable scroll positioning without jarring resets during interactions
- Visual activity scheduling with drag-and-drop interface

### 🎯 Activity Tracking

- Schedule activities with precise start/end times and timezones
- Cost tracking with multiple currency support
- Organization and location linking
- File attachments for tickets, confirmations, and photos
- Calendar integration for visual planning and timeline management
- **Reusable Component Architecture**: Modular activity form sections providing consistent UI patterns across add/edit/detail views with 63% code reduction
- **Performance Optimized**: Intelligent date conflict caching reduces computational complexity from O(n) to O(1) for large trips with hundreds of activities

### 🚗 Transportation & 🏨 Lodging

- Dedicated sections for flights, trains, rental cars, and accommodations
- **Smart transportation type icons** that display specific icons (✈️ airplane, 🚂 train, ⛴️ ferry, 🚗 car, 🚲 bicycle, 🚶 walking) in activity lists and forms
- **Real-time icon updates** when changing transportation types during activity creation and editing
- Confirmation number tracking
- Integration with organizations and trip timelines
- Cost analysis across all transportation and lodging

### 📎 File Attachments

- Embed files directly in the app (PDFs, images, documents)
- **Photo Library Integration**: Full photo permission handling with user-friendly guidance and real photo thumbnails
- Smart file organization by trip, activity, or lodging
- Quick preview and sharing capabilities with comprehensive file diagnostics
- Searchable file system across all attachments
- Mobile-optimized interface with proper touch spacing and functional preview/edit buttons
- Proper permission management for photo library access
- **Offline Support**: Files remain accessible even without network connectivity

### 🌐 Modern Features

- **iOS 18+ Native**: Built with latest SwiftUI and SwiftData
- **Enhanced Data Sync Reliability**: Robust CloudKit synchronization with comprehensive conflict resolution, exponential backoff for network failures, batch processing for large datasets, and protected trip sync controls with real-time diagnostic tools
- **Settings Sync**: Dark/light mode preferences and app settings automatically sync across all your devices in real-time
- **Import/Export with Enhanced Data Integrity**: Comprehensive data backup and restore functionality with robust file access permission management, complete file attachment relationship preservation, trip protection status retention, user-friendly error messages, and graceful handling of permission failures, security-scoped resources, and large files
- **Biometric Security**: Touch ID/Face ID protection for individual trips with password fallback support and robust dependency injection architecture
- **Adaptive Navigation**: Custom tab bar for iPad, native TabView for iPhone with intelligent deep navigation handling - trip selection from list properly returns to trip root when viewing activity details
- **Database Management**: Built-in cleanup tools with user feedback for data maintenance and detailed issue diagnostics showing specific problematic items
- **Internationalization**: Support for 10+ languages
- **Accessibility**: Full VoiceOver and accessibility support
- **Dark Mode**: Full dark/light mode support with system integration and user preference persistence
- **Enhanced Error Handling**: Comprehensive error recovery system with automatic retry using exponential backoff, persistent error state management, network failure resilience, and user-friendly error messages that provide clear guidance for resolution

### 🔍 Advanced Debugging & Data Integrity

- **Comprehensive Issue Detection**: Automatically identifies 8 types of data integrity issues including blank entries, orphaned data, invalid timezones, and broken file attachments
- **Detailed Issue Lists**: Expandable views showing specific problematic items with contextual information instead of just counts
- **Smart Issue Descriptions**: Each issue type displays affected items with names, types, and relevant details (e.g., "Transportation: Flight ABC (timezone: Invalid/Zone)")
- **Bulk Issue Resolution**: Fix all detected issues at once or handle individual issue types
- **Data Validation Tools**: Built-in diagnostic suite to maintain database health and performance

## 🏗️ Architecture

### Modern SwiftUI/SwiftData Patterns

- **`@Observable` Classes**: Modern observation system replacing `@ObservableObject`
- **`@State` Properties**: Latest property wrapper patterns
- **NavigationStack**: Modern navigation using NavigationStack instead of deprecated NavigationView
- **Environment-Based Navigation**: Type-safe navigation coordination through `@Environment` instead of NotificationCenter
- **SwiftData Integration**: Native Core Data replacement for iOS 17+
- **CloudKit Sync**: Seamless cross-device synchronization with CloudKit
- **Structured Concurrency**: Async/await throughout the codebase
- **Swift Testing**: Modern testing framework with `@Test` and `@Suite`

### Critical SwiftData Patterns

⚠️ **This app follows strict SwiftData patterns to prevent infinite view recreation bugs and ensure real-time UI updates:**

✅ **CORRECT Pattern (Used Throughout App):**

```swift
struct TripDetailView: View {
    let trip: Trip
    @Query private var activities: [Activity]  // Real-time updates via @Query
    
    init(trip: Trip) {
        self.trip = trip
        // Filter by trip ID for proper isolation
        self._activities = Query(
            filter: #Predicate<Activity> { $0.trip?.id == trip.id }
        )
    }
}
```

❌ **WRONG Pattern (Never Used):**

```swift
struct BadView: View {
    let activities: [Activity]  // Parameter passing - causes infinite recreation!
    
    var allActivities: [ActivityWrapper] {
        trip.activity.map { ActivityWrapper($0) }  // Relationship access - no UI updates!
    }
}
```

**Why This Matters:** Using `@Query` ensures that when new activities are saved, the UI immediately reflects changes without requiring manual refresh or navigation. Direct relationship access (`trip.activity`) can miss SwiftData updates, leading to stale UI state.

### Code Organization

```
Traveling Snails/
├── Models/                 # SwiftData models and business logic
│   ├── Trip.swift          # Main trip model with safe relationships
│   ├── Activity.swift      # Activity model with timezone support
│   ├── Lodging.swift       # Lodging with cost tracking
│   └── Extensions/         # Model extensions and computed properties
├── Views/                  # SwiftUI views organized by feature
│   ├── Trips/              # Trip management views
│   ├── Calendar/           # Calendar and timeline views
│   ├── Organizations/      # Organization management
│   ├── FileAttachments/    # File management views
│   ├── Settings/           # App settings and configuration
│   ├── Components/         # Reusable UI components
│   │   └── ActivityForm/   # Modular activity section components
│   └── Unified/            # Shared navigation and utility views
├── ViewModels/             # @Observable view models
├── Managers/               # Business logic and data management
├── Helpers/                # Utilities, extensions, and helper classes
└── Tests/                  # Comprehensive test suite (Swift Testing)
```

### Key Architectural Components

- **Unified Navigation System**: Consistent navigation patterns across all sections
- **Reusable Component System**: Modular activity form sections that eliminate code duplication and ensure UI consistency
- **Centralized Constants**: Type-safe constant management with `UserDefaultsConstants`, `UIConstants`, and consolidated `NotificationNames` to eliminate scattered magic numbers and string literals
- **Error Handling**: Centralized error management with user-friendly messages
- **Logging System**: Comprehensive logging using native Logger framework
- **Localization Manager**: Dynamic language switching with 10+ language support
- **File Management**: Embedded file system with efficient storage and retrieval
- **SwiftData Integration**: Modern data persistence with proper relationship handling

## 🛠️ Technical Requirements

### Minimum Requirements

- **iOS 18.0+** / **iPadOS 18.0+** / **macOS 15.0+**
- **Xcode 16.0+**
- **Swift 6.0+**
- **iCloud account** (for cross-device sync)

### Recommended

- **iPhone 12 or newer** for optimal performance
- **iPad Air 4th generation or newer**
- **Mac with Apple Silicon** for development

### Code Quality & Security

This project uses **SwiftLint** with security-focused rules to maintain high code quality and security standards:

- **Security Rules**: Prevents logging of sensitive data and enforces secure coding patterns
- **Modern Swift Patterns**: Enforces use of `NavigationStack`, `@Observable`, and other iOS 18+ patterns
- **Consistent Code Style**: Maintains consistent formatting and naming conventions
- **Automated Checks**: Integrated into build process and CI/CD pipeline

**Key Security Enforcements:**
- ❌ **No `print()` statements** - Must use `Logger.shared` for all logging
- ⚠️ **Sensitive data detection** - Warns about potential data exposure in logs
- 🔄 **Modern SwiftUI patterns** - Enforces `NavigationStack` over deprecated `NavigationView`
- 📱 **SwiftData best practices** - Prevents parameter passing anti-patterns

**Setup Instructions:**
```bash
# Run the setup script to configure SwiftLint
./Scripts/setup-swiftlint.sh

# Check for violations
swift run swiftlint lint

# Auto-fix style issues
swift run swiftlint --autocorrect
```

## 🧪 Comprehensive Testing & CI/CD Pipeline

### Fail-Fast Testing Strategy

This project implements a **comprehensive fail-fast testing strategy** that prevents failing code from ever reaching production:

```
Pre-commit hooks (local) → Security Tests (CI) → Parallel Test Execution → Branch Protection
```

### Pre-commit Hooks (Local)

**Activated hooks block commits with security violations:**

```bash
# Install pre-commit hooks (one-time setup)
./Scripts/setup-pre-commit-hooks.sh

# Hooks automatically run on every commit:
# - SwiftLint security analysis on staged files
# - Blocks print() statements, sensitive logging
# - Validates commit message format
```

**What's blocked locally:**
- ❌ `print()` statements (must use `Logger.shared`)
- ❌ Sensitive data in logging
- ❌ Unsafe error message patterns
- ❌ Commits with security violations

### Automated Testing Suite

**87 comprehensive tests** covering all critical functionality:

| Test Category | Purpose | Test Count |
|---------------|---------|------------|
| 🔒 **Security Tests** | Block security violations, prevent data exposure | 4 tests |
| 🧪 **Unit Tests** | Core business logic, model validation | 15 tests |
| 🔗 **Integration Tests** | SwiftData/CloudKit integration, import/export | 8 tests |
| ⚡ **Performance Tests** | Detect infinite recreation bugs, memory leaks | 2 tests |
| 💾 **SwiftData Tests** | Data persistence, relationships, anti-patterns | 8 tests |
| 🎨 **UI Tests** | Navigation, user flows, component behavior | 28 tests |
| ⚙️ **Settings Tests** | Configuration, sync, user preferences | 7 tests |

### Running Tests Locally

```bash
# All tests with clean output
./Scripts/run-all-tests.sh

# Specific test categories
./Scripts/run-all-tests.sh --security-only
./Scripts/run-all-tests.sh --unit-only  
./Scripts/run-all-tests.sh --integration-only
./Scripts/run-all-tests.sh --performance-only

# Quick tests (no dependency resolution)
./Scripts/run-all-tests.sh --quick --unit-only

# Tests only (skip SwiftLint)
./Scripts/run-all-tests.sh --test-only
```

### CI/CD Pipeline (GitHub Actions)

**Build validation with local testing approach** - optimized for reliability and speed:

#### 🔒 Phase 1: Security Build Validation
- **Security-focused build validation** runs first and blocks pipeline if failed
- **Enhanced SwiftLint** analysis with detailed security reporting
- **Dependency scanning** for vulnerabilities  
- **Secret detection** for hardcoded credentials

#### 🏗️ Phase 2: Comprehensive Build Validation
- **Multi-target builds** - Debug and Release configurations
- **Cross-platform compilation** - macOS (iPad/iPhone variant) + iOS device compilation checks
- **Build validation matrix** - Parallel validation across different targets
- **Code signing disabled** - Fast builds with `CODE_SIGNING_ALLOWED=NO`

#### 🛡️ Phase 3: Quality Gates
- **Build Summary** - Requires ALL build validations to pass
- **Branch Protection** - Blocks merges with failing builds
- **PR Reviews** - Requires at least 1 approval
- **Artifact Collection** - Build results for debugging

### Local vs CI Testing Strategy

#### 🏠 Local Development (Pre-commit Hooks)
- **Comprehensive test execution** - All 87 tests run locally where iOS simulators work perfectly
- **Security-first validation** - Security tests always run before commit
- **Critical path detection** - Full test suite for changes to Models/ViewModels/Managers
- **Fast feedback** - Issues caught in seconds during commit

#### ☁️ CI/CD (GitHub Actions) 
- **Build validation only** - No iOS simulator dependencies or flaky test execution
- **Security scanning** - Enhanced SwiftLint and dependency analysis
- **Compilation verification** - Ensures code builds across multiple targets
- **Deployment readiness** - Fast, reliable pipeline focused on build success

### Branch Protection Rules

**Main branch is protected** with these requirements:
- ✅ All 8 status checks must pass
- ✅ Branch must be up to date before merge
- ✅ Changes must be made through pull requests
- ✅ Stale reviews are dismissed on new commits
- ❌ Direct pushes to main are blocked
- ❌ Force pushes are disabled

### Benefits of This Approach

- **🚫 Zero failing code** reaches CI/CD - comprehensive testing happens locally first
- **⚡ Lightning-fast CI** - Build validation completes in minutes, not hours
- **🔒 Security-first** - Violations blocked at commit time, enhanced scanning in CI
- **💰 Cost effective** - No iOS simulator downloads or flaky test execution in CI
- **🛡️ Reliability** - No simulator dependency issues or CI environment conflicts
- **📊 Quality enforcement** - 87 tests run locally where they work perfectly
- **🔄 Developer-friendly** - Immediate feedback during development, not after push

### Testing Anti-Patterns Prevention

Our tests specifically prevent these critical SwiftData issues:

**❌ Infinite Recreation Bug:**
```swift
// This pattern causes infinite view recreation - BLOCKED by tests
struct BadView: View {
    let trips: [Trip]  // Parameter passing - causes infinite recreation!
}
```

**✅ Correct Pattern (Enforced):**
```swift  
struct GoodView: View {
    @Query private var trips: [Trip]  // Direct query - stable and efficient
}
```

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/traveling-snails.git
cd traveling-snails
```

### 2. Open in Xcode

```bash
open "Traveling Snails.xcodeproj"
```

### 3. Configure Development Team

1. Select the project in Xcode
2. Go to "Signing & Capabilities"
3. Select your development team
4. Ensure iCloud capability is properly configured

### 4. Build and Run

- Select your target device or simulator
- Press `Cmd+R` to build and run
- The app will create sample data on first launch for testing

### 5. Setup Pre-commit Hooks (Essential)

```bash
# Install enhanced pre-commit hooks for comprehensive local testing
./Scripts/setup-pre-commit-hooks.sh
```

**Important:** Pre-commit hooks now run comprehensive tests locally since CI focuses on build validation only.

### 6. Local Testing (Swift Testing Framework)

```bash
# Use our comprehensive test runner (runs locally)
./Scripts/run-all-tests.sh

# Run specific test categories for faster debugging
./Scripts/run-all-tests.sh --unit-only
./Scripts/run-all-tests.sh --security-only
./Scripts/run-all-tests.sh --performance-only

# Quick tests (no dependency resolution)
./Scripts/run-all-tests.sh --quick --unit-only

# Standard xcodebuild (basic)
xcodebuild test -project "Traveling Snails.xcodeproj" -scheme "Traveling Snails" -destination "platform=iOS Simulator,name=iPhone 16" | xcbeautify

# Or in Xcode: Cmd+U
```

### 7. CI Build Validation

```bash
# What CI runs (build validation only - no tests)
xcodebuild build -project "Traveling Snails.xcodeproj" -scheme "Traveling Snails" -destination "platform=macOS,arch=arm64,variant=Designed for [iPad,iPhone]" CODE_SIGNING_ALLOWED=NO
```

**See the [Local vs CI Testing Strategy](#local-vs-ci-testing-strategy) section above for detailed information about our hybrid approach.**

## 📱 Usage Guide

### Creating Your First Trip

1. Open the app and tap the "Trips" tab
2. Tap the "+" button to create a new trip
3. Fill in trip details (name, dates, notes)
4. Save your trip

### Adding Activities

1. Navigate to your trip
2. Tap "Activities" section
3. Add activities with times, costs, and locations
4. Attach relevant files (tickets, confirmations)

### Managing Organizations

1. Go to "Organizations" tab
2. Add airlines, hotels, tour companies
3. Link organizations to your activities and bookings
4. The app will suggest organizations for future bookings

### File Management

1. Use the "Files" tab to view all attachments
2. Search across all files by name or type
3. Files are automatically organized by trip and activity
4. Tap any file for quick preview

## 🧪 Testing (Swift Testing Framework)

### Test Coverage

- **SwiftData Regression Tests**: Prevent infinite view recreation bugs
- **Unit Tests**: Core business logic and data models
- **Integration Tests**: Cross-component functionality
- **UI Tests**: Critical user flows and accessibility
- **Performance Tests**: Large dataset handling and memory usage

### Test Architecture

The app uses modern Swift Testing framework with isolated test data:

```swift
@MainActor
@Suite("Feature Tests")
struct FeatureTests {
    @Test("Specific behavior")
    func testSpecificBehavior() {
        let testBase = SwiftDataTestBase() // Isolated database
        // Test implementation
    }
}
```

### Running Tests with Test Runner Script

The project includes a comprehensive test runner script that provides advanced testing options:

```bash
# Run all tests and checks
./Scripts/run-all-tests.sh

# Run specific test categories
./Scripts/run-all-tests.sh --unit-only          # Run only unit tests
./Scripts/run-all-tests.sh --integration-only   # Run only integration tests
./Scripts/run-all-tests.sh --performance-only   # Run only performance tests
./Scripts/run-all-tests.sh --security-only      # Run only security tests

# Combine with other options
./Scripts/run-all-tests.sh --unit-only --quick  # Skip dependency resolution
./Scripts/run-all-tests.sh --lint-only          # Run only SwiftLint checks
./Scripts/run-all-tests.sh --no-clean           # Skip cleaning derived data
```

### Running Specific Test Suites Manually

```bash
# Run SwiftData regression tests
xcodebuild test -project "Traveling Snails.xcodeproj" -scheme "Traveling Snails" -only-testing "Traveling_SnailsUnitTests.SwiftDataRegressionTests"

# Run UI component tests
xcodebuild test -project "Traveling Snails.xcodeproj" -scheme "Traveling Snails" -only-testing "Traveling_SnailsUnitTests.UIComponentTests"
```

### Test Data Isolation

- Each test gets a fresh, isolated in-memory SwiftData database
- No test pollution or cross-test dependencies
- Proper cleanup and verification of test state
- **Mock Service Architecture**: Comprehensive dependency injection preventing LocalAuthentication hanging in simulator tests
- **Performance Regression Testing**: Automated detection of test timing issues and hanging prevention

## 🌍 Localization

### Supported Languages

- English (en)
- Spanish (es)
- French (fr)
- German (de)
- Italian (it)
- Portuguese (pt)
- Japanese (ja)
- Korean (ko)
- Chinese Simplified (zh-Hans)
- Chinese Traditional (zh-Hant)

### Adding New Languages

1. Add language to `LocalizationManager.swift` supported languages list
2. Create new `.lproj` folder in Resources
3. Add `Localizable.strings` file with translations
4. Update `L10n` enum with new localization keys

### Translation Keys

All user-facing strings use the `L10n` enum system:

```swift
Text(localized: L10n.Trips.title)  // "Trips"
Text(L(L10n.General.save))         // "Save"
```

## 🔧 Configuration

### App Settings

- **Color Scheme**: System, Light, or Dark mode with real-time switching, local persistence, and automatic iCloud sync across devices
- **Language**: Dynamic language switching
- **iCloud Sync**: Enable/disable cross-device synchronization
- **Data Export**: Export all data as JSON
- **Database Cleanup**: Remove test data and reset database
- **Biometric Security**: Per-trip protection and timeout settings

### Development Configuration

- **Debug Mode**: Additional debugging tools and sample data
- **Logging Levels**: Configurable logging verbosity
- **Performance Monitoring**: Built-in performance measurement tools
- **Test Database**: Isolated testing environment

## 🤝 Contributing

### Development Guidelines

1. **Modern SwiftUI**: Use `@Observable` instead of `@ObservableObject`
2. **iOS 18+ Features**: Leverage latest SwiftUI capabilities including NavigationStack
3. **SwiftData Patterns**: Follow anti-infinite-recreation patterns
4. **Swift Testing**: Use `@Test` and `@Suite` for all tests
5. **Testing**: All new features require comprehensive tests
6. **Localization**: Add localization keys for all user-facing strings
7. **Error Handling**: Use centralized error handling system
8. **Logging**: Use Logger framework instead of print statements

### Critical SwiftData Rules

- **NEVER pass SwiftData model arrays as view parameters**
- **ALWAYS use @Query directly in consuming views**
- **ALWAYS use @Environment(\.modelContext) for data operations**
- **Use SwiftDataTestBase for isolated test data**

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public interfaces
- Maintain consistent indentation and formatting
- Follow the patterns established in CLAUDE.md

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests FIRST using Swift Testing framework
4. Implement following SwiftData best practices
5. Ensure all tests pass
6. Update documentation as needed
7. Submit a pull request with detailed description

## 🔒 Security & Performance

### Security Features

- **Biometric Authentication**: Touch ID/Face ID protection for sensitive data
- **Secure File Handling**: Validated file types and sizes
- **Privacy-First Logging**: Comprehensive security framework preventing sensitive data exposure in logs
  - **Logger Framework Integration**: Uses iOS Logger with explicit privacy levels (`privacy: .public`) for safe data logging
  - **Debug Guards**: All debug logs wrapped in `#if DEBUG` preprocessor directives to ensure complete removal from production builds
  - **Sensitive Data Detection**: Automated test suites detect and prevent logging of trip names, personal information, locations, and security credentials
  - **Secure Patterns**: ID-based logging replacing direct model object exposure
- **Input Validation**: All user inputs are properly validated
- **Error Sanitization**: Internal errors are not exposed to users

### Performance Optimizations

- **Efficient SwiftData Queries**: Proper sorting and filtering at database level
- **Memory Management**: Careful relationship access patterns
- **Async Operations**: Non-blocking file and data operations
- **UI Responsiveness**: Main thread protection for heavy operations

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Getting Help

- **User Documentation**: This README for features and setup instructions
- **Developer Documentation**: See [wiki](https://github.com/beforetheshoes/Traveling-Snails.wiki.git) for comprehensive technical guides
  - **[INTEGRATION_PATTERNS_GUIDE.md](https://github.com/beforetheshoes/Traveling-Snails.wiki.git/blob/main/INTEGRATION_PATTERNS_GUIDE.md)** - Primary technical reference
  - **[SwiftData-Patterns.md](https://github.com/beforetheshoes/Traveling-Snails.wiki.git/blob/main/SwiftData-Patterns.md)** - Critical anti-patterns and best practices
  - **[Development-Workflow.md](https://github.com/beforetheshoes/Traveling-Snails.wiki.git/blob/main/Development-Workflow.md)** - Testing and contribution guidelines
  - **[ARCHITECTURE.md](https://github.com/beforetheshoes/Traveling-Snails.wiki.git/blob/main/ARCHITECTURE.md)** - App structure and MVVM patterns
- **Development Guidelines**: CLAUDE.md for critical SwiftData patterns and testing rules
- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Join GitHub Discussions for questions and ideas

### Known Issues

- Large file attachments (>10MB) may impact performance
- iCloud sync requires stable internet connection
- Some localization strings may be incomplete in beta languages

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and release notes.

## 🛡️ Data Safety

### SwiftData Reliability

This app implements proven patterns to prevent the SwiftData infinite view recreation bug that can cause:

- Excessive CPU usage and battery drain
- UI freezing and poor user experience  
- Memory leaks and app crashes

Our architecture ensures stable, performant SwiftData operations through:

- Proper `@Query` usage patterns
- Isolated test environments
- Performance regression testing
- Comprehensive documentation of anti-patterns

---

**Built with ❤️ using SwiftUI, SwiftData, Swift Testing, and modern iOS development practices.**
