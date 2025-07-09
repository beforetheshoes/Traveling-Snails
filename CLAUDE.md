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

### 🚨 CRITICAL TEST FAILURE DETECTION
**CHUNK SCRIPTS HIDE INDIVIDUAL TEST FAILURES - YOU MUST DETECT THEM MANUALLY:**

#### 🔍 MANDATORY: Always Check Individual Test Failures
**The chunk scripts report "PASSED" even when individual tests fail. You MUST:**

1. **After ANY chunk test**: Check for .xcresult files and parse them for failures
2. **Parse xcresult files** using: `xcrun xcresulttool get --legacy --format json --path ./[filename].xcresult | jq -r '.issues.testFailureSummaries._values[] | "\(.documentLocationInCreatingWorkspace.url._value):\(.documentLocationInCreatingWorkspace.concreteLocation.line._value) \(.testCaseName._value): \(.message._value)"'`
3. **Never trust chunk-level "PASSED" status** - always verify individual test results

#### 📋 Test Failure Detection Commands
```bash
# Find all xcresult files
find . -name "*.xcresult" -type d

# Parse failures from xcresult (replace filename)
xcrun xcresulttool get --legacy --format json --path ./manual-test-results.xcresult | jq -r '.issues.testFailureSummaries._values[] | "\(.documentLocationInCreatingWorkspace.url._value):\(.documentLocationInCreatingWorkspace.concreteLocation.line._value) \(.testCaseName._value): \(.message._value)"'

# Find SwiftLint issues
jq -r '.[] | select(.severity == "error") | "\(.file):\(.line) \(.rule) - \(.reason)"' test-swiftlint.json
```

### Testing Commands
**ALWAYS use the provided scripts, BUT ALWAYS CHECK FOR INDIVIDUAL FAILURES:**

#### For Claude Code (Timeout-Friendly):
**CRITICAL: Chunks are for EXECUTION only. ALWAYS validate with detection script:**

- `./Scripts/test-chunk-0-config.sh` - **REQUIRED FIRST** - Setup + Build (~47s)
- `./Scripts/test-chunk-1.sh` - Unit Tests (~66s) 
- `./Scripts/test-chunk-2.sh` - Integration + SwiftData Tests (~45s)
- `./Scripts/test-chunk-3.sh` - UI + Accessibility Tests (~120s+ may timeout)
- `./Scripts/test-chunk-4.sh` - Performance + Security Tests (~90s)
- `./Scripts/test-chunk-5.sh` - SwiftLint Analysis (~60s)

**🚨 MANDATORY AFTER ANY TEST EXECUTION**: `./Scripts/detect-test-failures.sh`

**⚠️ NEVER TRUST CHUNK EXIT CODES** - Chunks report "PASSED" even when individual tests fail!

#### For Local Development:
- `./Scripts/run-all-tests.sh` - Complete test suite (5+ minutes) - **LOCAL ONLY, will timeout in Claude Code**
- Individual chunk execution for specific test categories
- Always followed by `./Scripts/detect-test-failures.sh` validation

### Testing Infrastructure
- **For Claude Code**: 
  - **Execution**: Run chunks individually to avoid 2-minute timeouts
  - **Validation**: ALWAYS run `./Scripts/detect-test-failures.sh` after ANY test execution
  - **Critical Rule**: Chunk exit codes are unreliable - only trust the detection script
- **For development**: Use `run-all-tests.sh` for complete LOCAL testing (will timeout in Claude Code), then validate with detection script
- **Golden Rule**: Every test execution MUST be followed by `detect-test-failures.sh`

### Chunked Testing System
The chunked testing system ensures 100% test coverage while working within Claude Code's 2-minute timeout constraints:

**Chunk 1** (Build + Unit Tests): Critical foundation - must pass for other chunks to run
**Chunk 2** (Integration + SwiftData Tests): Data layer validation  
**Chunk 3** (UI + Accessibility Tests): Interface and accessibility compliance
**Chunk 4** (Performance + Security Tests): Quality and security validation
**Chunk 5** (SwiftLint Analysis): Code style and security compliance

Each chunk is designed to complete within 90 seconds, ensuring compatibility with timeout constraints while maintaining comprehensive coverage.

**🚨 CRITICAL WORKFLOW**: 
1. **Execute**: Run chunks for timeout management
2. **Validate**: Always run `./Scripts/detect-test-failures.sh` 
3. **Never trust chunk exit codes** - they mask individual failures!

## 🎯 SYSTEMATIC FAILURE ANALYSIS METHODOLOGY (CRITICAL)
**The approach that ensures ALL failures are detected and fixed systematically:**

### 🔍 Phase 1: Comprehensive Failure Detection
**NEVER accept "some tests passed" - detect EVERY failure:**

1. **Use the detection script**: `./Scripts/detect-test-failures.sh`
   - This script finds failures across ALL xcresult files
   - Parses individual test failures that chunk scripts might miss
   - Categorizes failures by type (accessibility, performance, etc.)

2. **Manual verification of critical areas**:
   - Always check for SwiftLint integration issues
   - Verify accessibility test completeness  
   - Look for performance baseline violations
   - Check for stress test throughput issues

3. **Create comprehensive TODO list**:
   - Document EVERY failure found
   - Categorize by priority (high for functional bugs, medium for performance)
   - Track status as you work through them

### 🛠️ Phase 2: Root Cause Analysis for Each Failure
**For EVERY failure, determine if it's a bug or unreasonable expectation:**

#### For Functional Failures:
- **Logic errors**: Fix the actual implementation 
- **Missing implementations**: Add the required code
- **Incorrect test expectations**: Only change tests if they test wrong behavior

#### For Performance Failures:
- **Investigate thoroughly**: Don't assume it's "just CI slowness"
- **Check for inefficiencies**: Look for unnecessary overhead in test setup
- **Validate baselines**: Ensure performance expectations are realistic but still catch regressions
- **Examples of proper analysis**:
  ```
  ❌ "CI is slow, ignore it"
  ✅ "Test creates unnecessary SwiftData contexts - fix measurement approach"
  ✅ "500ms baseline too aggressive for mock with overhead - adjust to 1000ms"
  ```

#### For Timing Failures:
- **Examine actual vs expected duration**
- **Check for blocking operations that could be optimized**
- **Adjust timeouts only if analysis shows the operation is fundamentally slower**

### 🔧 Phase 3: Systematic Fixing
**Fix ALL issues in priority order:**

1. **High Priority** (functional bugs):
   - SwiftLint integration failures
   - Accessibility test logic errors
   - Core functionality bugs
   - **CRITICAL**: Check for duplicate implementations between test files and main code

2. **Medium Priority** (performance issues):
   - Test measurement inefficiencies
   - Unrealistic performance baselines
   - Timeout adjustments

3. **Validate each fix**:
   - Test the specific area you fixed
   - Ensure the fix doesn't break other tests
   - Update TODO list with completion status

### 🚨 CRITICAL: Avoid Duplicate Implementation Traps
**Common failure pattern that must be checked:**

Test files sometimes contain their own implementations of classes/engines that should come from main code:
- `ErrorDisclosureEngine` in test file vs ErrorStateManagement.swift
- `ErrorAccessibilityEngine` duplicated with different logic
- Mock service implementations that differ from expected interfaces

**Solution methodology:**
1. **When test logic fails**: Check if test file has duplicate definitions
2. **Remove duplicates**: Keep implementation in main code, remove from test file
3. **Add comments**: Mark where real implementation is located
4. **Verify**: Ensure tests now use the correct, single implementation

### 🚨 Phase 4: Zero-Tolerance Validation
**NEVER declare victory until ALL tests pass:**

1. **Run comprehensive validation**
2. **Check detection script shows no failures**  
3. **Verify all TODOs are marked complete**
4. **Run full test suite as final confirmation**

### 📋 Mandatory Failure Analysis Questions
**For EVERY failure, ask these questions:**

1. **Is this a real bug or unreasonable test expectation?**
2. **What is the root cause (not just symptoms)?**
3. **Is the fix appropriate (doesn't mask real issues)?**
4. **Will this fix prevent similar failures in the future?**

### 🎯 Success Criteria
**The process is complete ONLY when:**
- ✅ Detection script shows zero failures
- ✅ All TODOs marked complete
- ✅ Full test suite passes
- ✅ All fixes have proper root cause analysis documented

**NEVER compromise on this methodology - it's what ensures comprehensive success.**

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