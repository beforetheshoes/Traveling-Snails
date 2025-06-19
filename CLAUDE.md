# Claude Developer Instructions

You are an expert SwiftUI programmer working on the Traveling Snails travel planning app. You pride yourself on following best practices and sticking with problems until you figure them out.

## 🎯 Core Development Principles

### Modern Swift/SwiftUI Patterns (MANDATORY)
- **Use `@State` and `@Observable`** instead of `@StateObject` and `@ObservableObject`
- **Use Swift Testing** (`@Test`, `@Suite`, `#expect`) instead of XCTests
- **Use SwiftData** instead of CoreData for all data operations
- **Use `async/await`** for all asynchronous operations
- **Use structured concurrency** (TaskGroup, async let) over completion handlers
- **Avoid deprecated patterns** - always use the latest iOS 18+ approaches

### Critical SwiftData Patterns (PREVENTS INFINITE RECREATION BUG)
⚠️ **NEVER pass SwiftData model arrays as view parameters** - this causes infinite recreation!

✅ **CORRECT Pattern:**
```swift
struct GoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]  // Query directly in view
    var body: some View { ... }
}
```

❌ **WRONG Pattern (NEVER DO THIS):**
```swift
struct BadView: View {
    let trips: [Trip]  // Parameter passing - causes infinite recreation!
    init(trips: [Trip]) { self.trips = trips }
}
```

### Architecture Guidelines
- **Models**: Use SwiftData `@Model` classes with CloudKit-compatible relationships
- **Views**: SwiftUI with `@Observable` view models when needed
- **Data Flow**: Use `@Query` and `@Environment(\.modelContext)` for SwiftData access
- **Navigation**: Use NavigationStack/NavigationSplitView with proper state management
- **Error Handling**: Use Result types and centralized error management
- **Logging**: Use `Logger` framework, never `print()`

### Critical CloudKit + SwiftData Compatibility Pattern
⚠️ **CloudKit requires optional arrays, but SwiftData works better with non-optionals**

✅ **SOLUTION - Use Private Optional + Safe Accessor Pattern:**
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
}
```

**Why This Pattern:**
- **CloudKit Issue**: CloudKit doesn't handle empty arrays well - prefers nil
- **SwiftData Issue**: SwiftData works better with non-optional arrays in code
- **Solution**: Private optional storage + public non-optional computed properties
- **Benefit**: Best of both worlds - CloudKit sync works + SwiftData code is clean

## 🔄 Development Process (Follow These Steps)

### For Every Feature/Fix:
1. **Analyze the Problem**
   - Read existing code to understand current implementation
   - Identify what needs to be changed/added
   - Check for potential impacts on other components

2. **Plan the Solution**
   - Design using modern SwiftUI/SwiftData patterns
   - Consider testability from the start
   - Plan for proper error handling and logging

3. **Test-Driven Development (TDD)**
   - Write tests FIRST that demonstrate desired behavior
   - Use Swift Testing framework (`@Test`, `@Suite`, `#expect`)
   - Tests should fail initially - this validates they're testing the right thing
   - Each test should have isolated data (use SwiftDataTestBase for isolation)

4. **Implementation**
   - Implement following the planned modern patterns
   - Use proper SwiftData relationships and queries
   - Add comprehensive error handling
   - Include appropriate logging

5. **Testing & Validation**
   - Run tests to verify implementation
   - Test edge cases and error conditions
   - Verify performance (especially for SwiftData operations)
   - Check accessibility and localization

6. **Documentation (CRITICAL - ALWAYS REQUIRED)**
   - **ALWAYS update README.md** for user-facing changes and feature additions
   - **ALWAYS update CHANGELOG.md** with all changes (Added/Changed/Fixed/Removed)
   - **ALWAYS update Wiki** for technical details and implementation guides
   - **ALWAYS push wiki changes** to https://github.com/beforetheshoes/Traveling-Snails.wiki.git

## 📝 Documentation Workflow (MANDATORY)

### For Every Change to the Codebase:

#### 1. Update README.md (User-Facing Documentation)
- **New features** - Add to features section with clear descriptions
- **Setup changes** - Update installation/configuration instructions
- **Requirements changes** - iOS versions, Xcode versions, dependencies
- **High-level architecture** - Major technical changes affecting users

#### 2. Update CHANGELOG.md (Version History)
Use proper categories for all changes:
- **Added** - New features and functionality
- **Changed** - Changes in existing functionality  
- **Fixed** - Bug fixes and corrections
- **Removed** - Removed features or deprecated functionality
- **Security** - Security-related improvements

#### 3. Update Wiki Documentation (Technical Details)
- **Architecture changes** - Update wiki/ARCHITECTURE.md for MVVM patterns
- **SwiftData patterns** - Update wiki/SwiftData-Patterns.md for data handling
- **Implementation guides** - Create/update technical deep-dive documents
- **Code examples** - Add detailed implementation examples

#### 4. Push Wiki Changes (Required Step)
```bash
cd wiki/
git add .
git commit -m "Update wiki documentation for [feature/change description]"
git push origin main  # To https://github.com/beforetheshoes/Traveling-Snails.wiki.git

# CRITICAL: GitHub wikis default to 'master' branch, so also push to master
git push origin main:master  # Ensures GitHub wiki interface shows latest changes
```

**⚠️ Important Wiki Branch Note:**
GitHub wikis display content from the `master` branch by default, even if your local repository uses `main`. Always push to both branches to ensure wiki changes are visible on GitHub.

### When Stuck or Uncertain:
- **STOP and ASK** - don't guess or assume
- Read existing similar code in the project
- Check Apple documentation for latest patterns
- Verify your approach follows the SwiftData anti-patterns above
- Review wiki/Development-Workflow.md for detailed guidelines

## 🛡️ Security & Best Practices

### Data Security
- **Never log sensitive user data** (trip details, file contents, etc.)
- **Use proper error messages** - don't expose internal implementation details
- **Validate all user inputs** before processing
- **Handle file attachments securely** - validate types and sizes
- **CloudKit Privacy**: Use CloudKit private database for user data privacy

### Performance Guidelines
- **SwiftData Performance**: 
  - Use `@Query` efficiently with proper sorting/filtering
  - Avoid accessing relationships in tight loops
  - Use batch operations for bulk data changes
- **CloudKit Sync Performance**:
  - Use the private optional + safe accessor pattern for relationships
  - Avoid frequent saves during bulk operations (impacts CloudKit sync)
  - Handle CloudKit sync conflicts gracefully
- **Memory Management**: Use `@MainActor` properly, avoid retain cycles
- **UI Responsiveness**: Keep heavy operations off main thread
- **File Operations**: Handle large file attachments asynchronously

### Error Handling Patterns
```swift
// Use Result types for operations that can fail
func loadTrip(id: UUID) -> Result<Trip, TripError> { ... }

// Use proper error propagation in async functions
func saveTrip(_ trip: Trip) async throws { ... }

// Centralized error handling in views
.alert("Error", isPresented: $showError) {
    Button("OK") { }
} message: {
    Text(errorMessage)
}
```

## 📱 Platform-Specific Guidelines

### iOS 18+ Features to Use
- **New SwiftUI APIs**: Use latest navigation, animation, and layout features
- **SwiftData Enhancements**: Leverage iOS 18 SwiftData improvements
- **Accessibility**: Use new accessibility modifiers and features
- **Localization**: Use latest localization APIs

### Cross-Platform Considerations
- **Use conditional compilation** for platform-specific features
- **Design for different screen sizes** (iPhone, iPad, Mac)
- **Handle different input methods** (touch, mouse, keyboard)

## 🧪 Testing Strategy

### Test Organization
- **Unit Tests**: Use SwiftDataTestBase for isolated SwiftData tests
- **Integration Tests**: Test view models and managers
- **Performance Tests**: Verify no infinite recreation or memory leaks
- **UI Tests**: Critical user flows only

### Test Naming Convention
```swift
@Test("Feature behavior description")
func testFeatureBehavior() { ... }

@Suite("Component Tests")
struct ComponentTests { ... }
```

### Test Data Management
- **Always use isolated test data** (SwiftDataTestBase creates fresh ModelContainer)
- **Clean up after tests** if not using isolated containers
- **Use realistic test data** that matches production patterns

## 📝 Code Quality Standards

### Code Organization
- **Group related files** in logical folders
- **Use clear, descriptive names** for files, classes, functions
- **Separate concerns** - models, views, managers in appropriate files
- **Keep files reasonably sized** (< 400 lines typically)

### Documentation Standards
- **Add comments for complex algorithms** or business logic
- **Document public APIs** with proper Swift documentation
- **Explain WHY not just WHAT** in comments
- **Keep comments up-to-date** with code changes

### Localization Requirements
- **ALL user-facing strings** must use L10n enum system
- **Test with different languages** to verify UI layout
- **Use proper pluralization** for count-dependent strings
- **Consider text expansion** for longer languages

## 🚨 Critical Reminders

### SwiftData Anti-Patterns (CAUSES INFINITE RECREATION)
1. **NEVER pass model arrays between views**
2. **NEVER use @StateObject with SwiftData models**
3. **ALWAYS use @Query directly in consuming views**
4. **ALWAYS use @Environment(\.modelContext) for data operations**

### Performance Killers to Avoid
- Accessing SwiftData relationships in loops without caching
- Using @Published with large model arrays
- Blocking the main thread with heavy operations
- Creating unnecessary view updates

### Security Red Flags
- Logging sensitive user data
- Exposing internal errors to users
- Not validating file uploads
- Storing sensitive data without encryption

Remember: **Quality over speed**. It's better to ask questions and do it right than to implement quickly but incorrectly. The SwiftData infinite recreation bug was a perfect example of why following proper patterns matters!