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
- Store contact information, websites, and logos
- Automatic organization linking to trips and activities
- Smart organization suggestions based on past usage

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

### 🚗 Transportation & 🏨 Lodging

- Dedicated sections for flights, trains, rental cars, and accommodations
- Confirmation number tracking
- Integration with organizations and trip timelines
- Cost analysis across all transportation and lodging

### 📎 File Attachments

- Embed files directly in the app (PDFs, images, documents)
- Smart file organization by trip, activity, or lodging
- Quick preview and sharing capabilities
- Searchable file system across all attachments

### 🌐 Modern Features

- **iOS 18+ Native**: Built with latest SwiftUI and SwiftData
- **Cross-Device Sync**: iCloud integration for seamless device synchronization of all travel data (trips, activities, organizations) plus automatic settings sync using iCloud Key-Value Store
- **Settings Sync**: Dark/light mode preferences and app settings automatically sync across all your devices in real-time
- **Biometric Security**: Touch ID/Face ID protection for individual trips
- **Adaptive Navigation**: Custom tab bar for iPad, native TabView for iPhone
- **Database Management**: Built-in cleanup tools with user feedback for data maintenance
- **Internationalization**: Support for 10+ languages
- **Accessibility**: Full VoiceOver and accessibility support
- **Dark Mode**: Full dark/light mode support with system integration and user preference persistence

## 🏗️ Architecture

### Modern SwiftUI/SwiftData Patterns

- **`@Observable` Classes**: Modern observation system replacing `@ObservableObject`
- **`@State` Properties**: Latest property wrapper patterns
- **NavigationStack**: Modern navigation using NavigationStack instead of deprecated NavigationView
- **SwiftData Integration**: Native Core Data replacement for iOS 17+
- **CloudKit Sync**: Seamless cross-device synchronization with CloudKit
- **Structured Concurrency**: Async/await throughout the codebase
- **Swift Testing**: Modern testing framework with `@Test` and `@Suite`

### Critical SwiftData Patterns

⚠️ **This app follows strict SwiftData patterns to prevent infinite view recreation bugs:**

✅ **CORRECT Pattern (Used Throughout App):**

```swift
struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]  // Query directly in view
    var body: some View { ... }
}
```

❌ **WRONG Pattern (Never Used):**

```swift
struct BadView: View {
    let trips: [Trip]  // Parameter passing - causes infinite recreation!
    init(trips: [Trip]) { self.trips = trips }
}
```

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
│   └── Unified/            # Shared navigation and utility views
├── ViewModels/             # @Observable view models
├── Managers/               # Business logic and data management
├── Helpers/                # Utilities, extensions, and helper classes
└── Tests/                  # Comprehensive test suite (Swift Testing)
```

### Key Architectural Components

- **Unified Navigation System**: Consistent navigation patterns across all sections
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

### 5. Running Tests (Swift Testing Framework)

```bash
# Run all tests
xcodebuild test -project "Traveling Snails.xcodeproj" -scheme "Traveling Snails" -destination "platform=iOS Simulator,name=iPhone 16"

# Or in Xcode: Cmd+U
```

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

### Running Specific Test Suites

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
- **Privacy-First Logging**: No sensitive data in logs
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

- **Documentation**: Check this README and CLAUDE.md for development guidelines
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
