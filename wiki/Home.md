# Traveling Snails Wiki 🐌✈️

Welcome to the comprehensive technical documentation for Traveling Snails, a modern travel planning app built with SwiftUI and SwiftData.

## 📚 Documentation Overview

### Architecture & Design
- **[ARCHITECTURE](ARCHITECTURE)** - Detailed MVVM patterns, code organization, and architectural decisions
- **[SwiftData-Patterns](SwiftData-Patterns)** - Critical SwiftData usage patterns and anti-patterns
- **[INTEGRATION_PATTERNS_GUIDE](INTEGRATION_PATTERNS_GUIDE)** - Primary technical reference for SwiftData + CloudKit + Swift Concurrency
- **[TECHNOLOGY_REFERENCE](TECHNOLOGY_REFERENCE)** - Complete API reference for SwiftData, CloudKit, and Swift Concurrency

### Development Guides
- **[Development-Workflow](Development-Workflow)** - Development process, testing, and contribution guidelines
- **[DEPENDENCY_INJECTION_INVESTIGATION](DEPENDENCY_INJECTION_INVESTIGATION)** - Architecture experiments and findings

## 🚀 Quick Start for Developers

### Essential Reading Order
1. **[INTEGRATION_PATTERNS_GUIDE](INTEGRATION_PATTERNS_GUIDE)** - Start here for comprehensive technical overview
2. **[SwiftData-Patterns](SwiftData-Patterns)** - Critical anti-patterns to prevent infinite view recreation
3. **[Development-Workflow](Development-Workflow)** - Testing and development process
4. **[ARCHITECTURE](ARCHITECTURE)** - App structure and MVVM patterns

### Critical SwiftData Rules ⚠️
- **NEVER pass SwiftData model arrays as view parameters** - causes infinite recreation
- **ALWAYS use @Query directly in consuming views** - ensures real-time updates
- **ALWAYS use @Environment(\.modelContext) for data operations** - proper context management

### Modern Development Stack
- **SwiftUI + @Observable** (not @ObservableObject)
- **NavigationStack** (not NavigationView)
- **Swift Testing** (@Test/@Suite, not XCTests)
- **SwiftData** (with CloudKit sync)
- **Structured Concurrency** (async/await)

## 🎯 Key Technical Concepts

### Architecture Patterns
- **MVVM with @Observable ViewModels** - Modern observation system
- **Unified Navigation System** - Consistent navigation across all sections
- **Reusable Component Architecture** - Modular UI components with 63% code reduction
- **Error Handling System** - Centralized error management with user-friendly messages

### Data Management
- **SwiftData + CloudKit Integration** - Seamless cross-device sync with conflict resolution
- **Private Optional + Safe Accessor Pattern** - CloudKit-compatible relationships
- **Background Actor Pattern** - Reliable threading for data operations (not @ModelActor)
- **Performance-Optimized Queries** - Efficient data fetching and filtering

### Testing & Quality
- **Swift Testing Framework** - Modern @Test and @Suite patterns
- **SwiftDataTestBase** - Isolated test environments preventing contamination
- **TDD Methodology** - Tests written first for all new features
- **Performance Regression Testing** - Prevent infinite view recreation bugs

## 📖 Wiki Navigation

### By Topic
- **Data Handling**: [SwiftData-Patterns](SwiftData-Patterns) → [INTEGRATION_PATTERNS_GUIDE](INTEGRATION_PATTERNS_GUIDE)
- **App Architecture**: [ARCHITECTURE](ARCHITECTURE) → [Development-Workflow](Development-Workflow)
- **Technical APIs**: [TECHNOLOGY_REFERENCE](TECHNOLOGY_REFERENCE) → [INTEGRATION_PATTERNS_GUIDE](INTEGRATION_PATTERNS_GUIDE)

### By Experience Level
- **New Developers**: Start with [INTEGRATION_PATTERNS_GUIDE](INTEGRATION_PATTERNS_GUIDE) for comprehensive overview
- **SwiftData Focus**: [SwiftData-Patterns](SwiftData-Patterns) for critical anti-patterns and best practices
- **Architecture Review**: [ARCHITECTURE](ARCHITECTURE) for app structure and component organization
- **Advanced Topics**: [DEPENDENCY_INJECTION_INVESTIGATION](DEPENDENCY_INJECTION_INVESTIGATION) for experimental patterns

## 🔄 Documentation Workflow

When making changes to the codebase:

1. **Update README.md** - User-facing changes and feature additions
2. **Update CHANGELOG.md** - All changes with version information
3. **Update Wiki** - Technical details, architecture changes, and implementation guides
4. **Push Wiki changes** to `https://github.com/beforetheshoes/Traveling-Snails.wiki.git`

## 🛠️ Technical Stack

- **iOS 18+ / SwiftUI** - Modern declarative UI framework
- **SwiftData** - Modern data persistence replacing CoreData
- **CloudKit** - Cross-device synchronization
- **Swift Testing** - Modern testing framework
- **Biometric Authentication** - Touch ID/Face ID security

## 📋 Key Architectural Principles

- **MVVM Pattern** - Clear separation of concerns with Root/Content view patterns
- **SwiftData Best Practices** - Preventing infinite view recreation bugs
- **CloudKit Compatibility** - Private optional + safe accessor patterns
- **Test-Driven Development** - Comprehensive test coverage with isolated data
- **Modern Swift Patterns** - @Observable, NavigationStack, async/await

## 🔄 Wiki Maintenance

This wiki is actively maintained and should be updated when:
- New architectural patterns are established
- SwiftData usage patterns change
- Testing strategies evolve
- Performance optimizations are implemented

For contribution standards and update procedures, follow the guidelines in [Development-Workflow](Development-Workflow).

---

For user documentation and setup instructions, see the main [README.md](../README.md).