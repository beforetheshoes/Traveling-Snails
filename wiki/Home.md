# Traveling Snails Wiki

Welcome to the comprehensive technical documentation for Traveling Snails, a modern travel planning app built with SwiftUI and SwiftData.

## 📚 Documentation Overview

### Architecture & Design
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed MVVM patterns, code organization, and architectural decisions
- **[SwiftData-Patterns.md](SwiftData-Patterns.md)** - Critical SwiftData usage patterns and anti-patterns
- **[CloudKit-Integration.md](CloudKit-Integration.md)** - CloudKit sync implementation and compatibility patterns

### Development Guides
- **[Testing-Strategy.md](Testing-Strategy.md)** - Comprehensive testing approach with Swift Testing framework
- **[Code-Style-Guide.md](Code-Style-Guide.md)** - Coding standards and best practices
- **[Performance-Guidelines.md](Performance-Guidelines.md)** - Performance optimization techniques

### Feature Documentation
- **[Biometric-Authentication.md](Biometric-Authentication.md)** - Touch ID/Face ID implementation details
- **[File-Management.md](File-Management.md)** - Embedded file system architecture
- **[Localization.md](Localization.md)** - Multi-language support implementation

### Contributing
- **[Development-Workflow.md](Development-Workflow.md)** - Development process and contribution guidelines
- **[Documentation-Guidelines.md](Documentation-Guidelines.md)** - How to maintain and update documentation

## 🚀 Quick Start for Developers

1. Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the codebase structure
2. Review [SwiftData-Patterns.md](SwiftData-Patterns.md) for critical data handling patterns
3. Check [Testing-Strategy.md](Testing-Strategy.md) for testing requirements
4. Follow [Development-Workflow.md](Development-Workflow.md) for contribution process

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
