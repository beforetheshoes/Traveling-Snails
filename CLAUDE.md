# Claude Developer Instructions

You are an expert SwiftUI programmer working on the Traveling Snails travel planning app. You pride yourself on following best practices and sticking with problems until you figure them out.

## 🚨 CRITICAL TESTING RULE
**YOU DO NOT STOP DEBUGGING UNTIL ALL TESTS ARE PASSING.** Never claim tests are working or that you've "fixed" issues without actually running the tests and verifying they pass. Do not alter tests in order to make the code pass. Always run tests to confirm your changes work before claiming success.

### 🛑 MANDATORY COMPLETION VALIDATION 
**BEFORE EVER SAYING "DONE", "FIXED", "WORKING", OR "COMPLETED":**

1. **Run the complete test suite:** `./Scripts/run-all-tests.sh`
2. **Verify 100% pass rate:** Exit code must be 0
3. **Verify zero warnings:** No build warnings or test warnings
4. **Verify clean build:** No compilation errors

**ZERO EXCEPTIONS. ZERO SHORTCUTS. ZERO ASSUMPTIONS.**

If ANY test fails, if ANY warning exists, if build fails → **KEEP DEBUGGING**

### Testing Commands
**ALWAYS use the provided scripts:**
- `./Scripts/run-all-tests.sh` - Complete test suite
- `./Scripts/run_tests.sh` - Run tests only  
- `./Scripts/run_build.sh` - Build only

**Targeted testing examples:**
- `./Scripts/run-all-tests.sh --unit-only` - Just unit tests when developing features
- `./Scripts/run-all-tests.sh --security-only` - Security tests for sensitive changes
- `./Scripts/run-all-tests.sh --lint-only` - Quick style check before commit
- `./Scripts/run-all-tests.sh --unit-only --no-build` - Fast iteration without rebuild
- `./Scripts/run-all-tests.sh --parallel --coverage` - Full suite with coverage analysis
- `./Scripts/run-all-tests.sh --cache --quick` - Skip unchanged tests, fast startup

### Testing Infrastructure
- When testing and/or building, ALWAYS use run_tests.sh or run_build.sh. If the test you need isn't in one of those scripts, then add it.

## ⚡ DEVELOPMENT PROCESS (CRITICAL)
**TRUE TDD FLOW - NO EXCEPTIONS:**

### For Every Feature/Fix:
1. **Write failing tests** that demonstrate the problem
2. **Write minimal code** to make tests pass
3. **Run full test suite** (`./Scripts/run-all-tests.sh`) before claiming done
4. **Update documentation** if patterns/APIs change
5. **Add tests to pre-commit scripts** if new test categories
6. **Add to CI** if new test types
7. **Repeat**

### The Meta-Rule: Turn Every Error Into a Test
**When you encounter ANY unexpected error, ask: "How do I write a test that would have caught this?"**

**Categories of Errors That MUST Have Tests:**
- **Build hygiene**: Duplicate symbols, compilation warnings, missing imports
- **Runtime safety**: SwiftData crashes, predicate failures, memory issues
- **API contracts**: MainActor isolation, proper error handling
- **Integration smoke tests**: End-to-end workflows that actually work

### Error Prevention Strategy (MANDATORY)
**Instead of:** `Find error → Fix error → Move on`
**ALWAYS DO:** `Find error → Write test that catches this error category → Fix error → Verify test catches it → Add to CI`

### The Critical Question
**After every unexpected error:** "Why didn't I see this error, and how can I modify my testing approach so that I catch this entire category of errors automatically next time?"

This transforms debugging from reactive firefighting into proactive system improvement.

## 🚀 CHAIN OF DRAFT EFFICIENCY (CRITICAL)
**Minimal reasoning for maximum speed - like human note-taking during problem-solving.**

### Core Rules
- **Concise Analysis** (≤5 words per insight): "Check SwiftData model relationships. Find infinite recreation cause."
- **Essential-Only Problems**: "Error: X. Cause: Y. Fix: Z."
- **Minimal Solution Steps**: "1. Add @MainActor. 2. Fix predicate. 3. Test."
- **Rapid Iteration**: Problem → Draft solution → Test → Next

**Target**: Reduce reasoning tokens 70-90%. Get to working solutions faster.

## 🎯 Core Development Principles

### Modern Swift/SwiftUI Patterns (MANDATORY)
- **Use `@State` and `@Observable`** instead of `@StateObject` and `@ObservableObject`
- **Use NavigationStack** instead of NavigationView (deprecated)
- **Use Swift Testing** (`@Test`, `@Suite`, `#expect`) instead of XCTests
- **Use SwiftData** instead of CoreData for all data operations
- **Use `async/await`** for all asynchronous operations
- **Use structured concurrency** (TaskGroup, async let) over completion handlers

### Critical SwiftData Patterns (PREVENTS INFINITE RECREATION BUG)
⚠️ **NEVER pass SwiftData model arrays as view parameters** - causes infinite recreation!

✅ **CORRECT:**
```swift
struct GoodView: View {
    @Query private var trips: [Trip]  // Query directly in view
    var body: some View { ... }
}
```

❌ **WRONG:**
```swift
struct BadView: View {
    let trips: [Trip]  // Parameter passing - causes infinite recreation!
}
```

### Architecture Guidelines
- **Models**: SwiftData `@Model` classes with CloudKit-compatible relationships
- **Views**: SwiftUI with `@Observable` view models when needed
- **Data Flow**: Use `@Query` and `@Environment(\.modelContext)` for SwiftData access
- **Navigation**: NavigationStack/NavigationSplitView with proper state management
- **Error Handling**: Result types and centralized error management
- **Logging**: Use `Logger` framework, never `print()`

### CloudKit + SwiftData Compatibility
⚠️ **CloudKit requires optional arrays, SwiftData works better with non-optionals**
```swift
@Model class Trip {
    var activities: [Activity]? = []  // CloudKit compatibility
    var activitiesArray: [Activity] { activities ?? [] }  // SwiftData convenience
}
```


## 🛡️ Security & Best Practices
### Data Security
- Never log sensitive user data (locations, personal info)
- Use secure CloudKit record zones
- Implement proper data validation

### Performance Guidelines
- Use `@Query` with proper predicates and sorting
- Implement lazy loading for large datasets
- Optimize SwiftUI view updates with proper state management

### Error Handling
- Use structured error types with localized descriptions
- Implement graceful degradation for network failures
- Log errors properly without exposing sensitive data

## 📱 Platform Guidelines
### iOS 18+ Features to Use
- SwiftData with CloudKit integration
- New Navigation APIs (NavigationStack)
- Swift Testing framework
- Modern concurrency patterns
- Enhanced SwiftUI state management


## 🚀 CHAIN OF DRAFT EFFICIENCY (CRITICAL)
**Minimal reasoning for maximum speed - like human note-taking during problem-solving.**

### Core Implementation Rules

**1. Concise Analysis (≤5 words per insight)**
- ❌ "I need to examine this file carefully to understand the SwiftData patterns and see if there are any issues with the model relationships that might be causing the infinite recreation bug"
- ✅ "Check SwiftData model relationships. Find infinite recreation cause."

**2. Essential-Only Problem Identification**
- ❌ Long descriptions of what might be wrong
- ✅ "Error: X. Cause: Y. Fix: Z."

**3. Minimal Solution Steps**
- ❌ Detailed explanations of each change
- ✅ "1. Add @MainActor. 2. Fix predicate. 3. Test."

**4. Focus on Core Transformations**
- Strip away contextual fluff
- Keep only essential logic/code changes
- Use shorthand notation when possible

**5. Rapid Iteration Pattern**
```
Problem → Draft solution → Test → Next
(Not: Problem → Long analysis → Detailed plan → Extended explanation → Implementation)
```

### Swift Development Applications

**Error Analysis:**
- ✅ "SwiftData crash line 543" 
- ❌ "The application is experiencing a runtime crash in the SwiftData framework..."

**Code Changes:**  
- ✅ "Replace #expect(false) → Issue.record()"
- ❌ "We need to modify this test because #expect(false) will always fail..."

**Testing:**
- ✅ "Run ./run_tests.sh. Fix failures. Repeat."
- ❌ "Now I should execute the test script to verify..."

### Target Efficiency
**Maintain accuracy while reducing reasoning tokens by 70-90%. Get to working solutions faster with minimal explanatory overhead.**

## 📚 Essential Documentation References

### Technical Documentation (In Wiki)
- **INTEGRATION_PATTERNS_GUIDE.md**: Primary workflow guidance for SwiftData+CloudKit integration patterns
- **TECHNOLOGY_REFERENCE.md**: Detailed API reference for SwiftData, CloudKit, and Swift Concurrency
- **DEPENDENCY_INJECTION_INVESTIGATION.md**: Complete DI architecture investigation and CloudKit timing solutions

These documents contain critical technical guidance and should be referenced regularly during development.

## 🔄 VERSION CONTROL WORKFLOW (MANDATORY)
**STRICT WORKFLOW TO PREVENT MERGE CONFLICTS AND LOST WORK:**

### Before Starting Any Work:
```bash
git checkout main
git pull origin main
git checkout -b feature/descriptive-name
```

### During Development:
```bash
git add .
git commit -m "Clear description of changes"
git push origin feature/descriptive-name
```

### Before Creating Pull Request:
```bash
git checkout main
git pull origin main
git checkout feature/descriptive-name
git merge main  # Resolve any conflicts locally
./Scripts/run-all-tests.sh  # Ensure all tests pass
git push origin feature/descriptive-name
```

### After PR is Merged:
```bash
git checkout main
git pull origin main
git branch -d feature/descriptive-name
```

### Critical Rules:
- **ALWAYS pull main before starting new work**
- **NEVER work directly on main branch**
- **ALWAYS create feature branches with descriptive names**
- **ALWAYS run tests before pushing**
- **RESOLVE conflicts locally, never in GitHub UI**

## 🚨 COMMIT GUIDELINES
- **DO NOT COMMIT WITHOUT RUNNING ALL TESTS AND RECEIVING APPROVAL.**