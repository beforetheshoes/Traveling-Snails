# Development Workflow

This document outlines the development process, contribution guidelines, and documentation maintenance workflow for Traveling Snails.

## 🔄 Documentation Workflow (CRITICAL)

For every change to the codebase, developers MUST update documentation in this order:

### 1. Update README.md
- **User-facing changes**: New features, setup instructions, usage guidelines
- **High-level architecture changes**: Major technical shifts that affect users
- **Requirements changes**: iOS version, Xcode version, dependencies

### 2. Update CHANGELOG.md
- **All changes** must be documented with proper categorization:
  - `Added` - New features
  - `Changed` - Changes in existing functionality
  - `Fixed` - Bug fixes
  - `Removed` - Removed features
  - `Security` - Security-related changes

### 3. Update Wiki Documentation
- **Technical implementation details**: Architecture patterns, code examples
- **Developer guides**: Testing strategies, performance guidelines
- **Feature deep-dives**: Detailed implementation documentation

### 4. Push Wiki Changes
After updating wiki documents:
```bash
cd wiki/
git init  # If not already initialized
git remote add origin https://github.com/beforetheshoes/Traveling-Snails.wiki.git
git add .
git commit -m "Update wiki documentation for [feature/change]"
git push origin main
```

## 🛠️ Development Process

### 1. Before Starting Work
- [ ] Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand codebase structure
- [ ] Review [SwiftData-Patterns.md](SwiftData-Patterns.md) for data handling requirements
- [ ] Check existing issues and PRs to avoid duplicate work
- [ ] Create feature branch: `git checkout -b feature/your-feature-name`

### 2. Test-Driven Development (TDD)
Follow the **Red-Green-Refactor** cycle:

#### Red Phase - Write Failing Tests
```swift
@Test("New feature should work correctly")
func testNewFeature() {
    let testBase = SwiftDataTestBase()
    
    // Test the behavior you want to implement
    let result = someNewFeature()
    #expect(result == expectedValue)  // This should fail initially
}
```

#### Green Phase - Implement Minimum Code
```swift
func someNewFeature() -> ExpectedType {
    // Implement just enough to make the test pass
    return expectedValue
}
```

#### Refactor Phase - Clean Up
- Improve code quality while keeping tests green
- Follow established patterns from [ARCHITECTURE.md](ARCHITECTURE.md)
- Ensure SwiftData patterns from [SwiftData-Patterns.md](SwiftData-Patterns.md) are followed

### 3. Code Quality Requirements
- [ ] All SwiftData usage follows anti-infinite-recreation patterns
- [ ] Use `@Observable` instead of `@ObservableObject`
- [ ] Use Swift Testing framework (`@Test`, `@Suite`)
- [ ] Add localization keys for all user-facing strings
- [ ] Use `Logger` instead of `print()` statements
- [ ] Follow dependency injection patterns

### 4. Testing Requirements
- [ ] Unit tests for business logic
- [ ] Integration tests for cross-component functionality
- [ ] SwiftData regression tests using `SwiftDataTestBase`
- [ ] UI tests for critical user flows
- [ ] Performance tests for data-heavy operations

## 🔍 Code Review Process

### Pull Request Checklist
- [ ] **Tests**: All new functionality has comprehensive tests
- [ ] **SwiftData**: Follows established patterns (no infinite recreation)
- [ ] **Documentation**: README, CHANGELOG, and Wiki updated appropriately
- [ ] **Code Style**: Follows Swift API Design Guidelines
- [ ] **Performance**: No performance regressions
- [ ] **Accessibility**: VoiceOver and accessibility features work
- [ ] **Localization**: All user-facing strings are localized

### Review Guidelines
1. **Architecture Compliance**: Does the code follow MVVM patterns?
2. **SwiftData Safety**: Are the critical anti-patterns avoided?
3. **Test Coverage**: Are edge cases and error conditions tested?
4. **Documentation**: Is the code self-documenting with clear names?
5. **Performance**: Will this change impact app performance?

## 🚀 Release Process

### 1. Pre-Release Checklist
- [ ] All tests pass (`Cmd+U` in Xcode)
- [ ] Performance tests show no regressions
- [ ] Documentation is up to date
- [ ] CHANGELOG.md reflects all changes
- [ ] Version number updated in project settings

### 2. Release Documentation
- [ ] Update CHANGELOG.md with release date
- [ ] Create release notes summarizing key changes
- [ ] Update README.md if user-facing changes occurred
- [ ] Push wiki changes for any technical updates

### 3. Post-Release
- [ ] Monitor for any issues or crashes
- [ ] Update wiki with lessons learned
- [ ] Plan next iteration based on feedback

## 🏗️ Architecture Guidelines

### MVVM Implementation
- **Root Views**: Coordinate between UI and business logic
- **Content Views**: Focus solely on UI rendering
- **ViewModels**: Handle business logic and state management
- **Services**: Pure business logic operations

### File Organization
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

### Dependency Injection
- ViewModels receive dependencies through initializers
- Root Views handle environment dependencies
- Services are injected into ViewModels
- No direct environment access in ViewModels

## 🔒 Security Guidelines

### Code Security
- Never log sensitive user data (trip details, file contents)
- Validate all user inputs before processing
- Use proper error messages that don't expose internals
- Handle file attachments securely with type/size validation

### Biometric Authentication
- Use LocalAuthentication framework properly
- Graceful fallback when biometrics unavailable
- Clear user messaging about authentication requirements
- Secure storage of authentication state

## 📝 Documentation Standards

### Code Comments
- Document **why**, not just **what**
- Use proper Swift documentation format for public APIs
- Include code examples for complex implementations
- Keep comments up to date with code changes

### Wiki Updates
- Technical details go in wiki, not README
- Include code examples and implementation patterns
- Link related documents for comprehensive coverage
- Update table of contents when adding new pages

---

Following this workflow ensures high-quality, maintainable code and comprehensive documentation for the Traveling Snails project.