# Traveling Snails Wiki

Welcome to the comprehensive technical documentation for Traveling Snails, a modern travel planning app built with SwiftUI and SwiftData.

## 📚 Documentation Overview

### Architecture & Design
- **[ARCHITECTURE](ARCHITECTURE)** - Detailed MVVM patterns, code organization, and architectural decisions
- **[SwiftData-Patterns](SwiftData-Patterns)** - Critical SwiftData usage patterns and anti-patterns
- **[CloudKit-Integration](CloudKit-Integration)** - CloudKit sync implementation and compatibility patterns

### Development Guides
- **[Testing-Strategy](Testing-Strategy)** - Comprehensive testing approach with Swift Testing framework
- **[Code-Style-Guide](Code-Style-Guide)** - Coding standards and best practices
- **[Performance-Guidelines](Performance-Guidelines)** - Performance optimization techniques

### Feature Documentation
- **[Biometric-Authentication](Biometric-Authentication)** - Touch ID/Face ID implementation details
- **[File-Management](File-Management)** - Embedded file system architecture
- **[Localization](Localization)** - Multi-language support implementation

### Contributing
- **[Development-Workflow](Development-Workflow)** - Development process and contribution guidelines
- **[Documentation-Guidelines](Documentation-Guidelines)** - How to maintain and update documentation

## 🚀 Quick Start for Developers

1. Read [ARCHITECTURE](ARCHITECTURE) to understand the codebase structure
2. Review [SwiftData-Patterns](SwiftData-Patterns) for critical data handling patterns
3. Check [Testing-Strategy](Testing-Strategy) for testing requirements
4. Follow [Development-Workflow](Development-Workflow) for contribution process

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
- **Dependency Injection** - Testable and maintainable code architecture
- **SwiftData Best Practices** - Preventing infinite view recreation bugs
- **CloudKit Compatibility** - Private optional + safe accessor patterns
- **Test-Driven Development** - Comprehensive test coverage with isolated data

---

For user documentation and setup instructions, see the main [README.md](../README.md).
