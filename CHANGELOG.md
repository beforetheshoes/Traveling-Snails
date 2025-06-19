# Changelog

All notable changes to the Traveling Snails project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive SwiftData regression tests to prevent infinite view recreation bugs
- Swift Testing framework implementation replacing XCTests
- Organized test directory structure (Unit Tests, Integration Tests, UI Tests, SwiftData Tests, Security Tests)
- SwiftDataTestBase for isolated test environments
- CloudKit + SwiftData compatibility patterns with private optional + safe accessor approach
- Biometric authentication (Touch ID/Face ID) for app security
- Comprehensive developer documentation (CLAUDE.md) with critical SwiftData patterns
- Wiki documentation structure for technical details

### Changed
- Migrated from XCTests to modern Swift Testing framework (@Test, @Suite)
- Moved CLAUDE.md to project root for better accessibility
- Updated README.md with biometric security features and modern architecture patterns
- Reorganized test suite into logical directories for better maintainability

### Fixed
- SwiftData infinite view recreation bugs through proper @Query usage patterns
- Test isolation issues with proper SwiftDataTestBase implementation

### Removed
- Roadmap section from README (replaced with changelog)
- Duplicate README.md from app bundle directory

---

## [1.0.0] - 2025-06-18

### Added
- Initial release of Traveling Snails travel planning app
- Core trip management functionality
- Activity tracking with timezone support
- Organization management for airlines, hotels, etc.
- File attachment system for tickets and documents
- SwiftUI + SwiftData modern architecture
- iCloud synchronization
- Multi-language support (10+ languages)
- Dark mode support
- Accessibility features

### Technical Features
- Modern SwiftUI patterns with @Observable
- SwiftData integration for data persistence
- CloudKit sync for cross-device functionality
- Comprehensive error handling and logging
- Structured concurrency with async/await

---

## Version History

- **1.0.0** - Initial release with core travel planning features
- **Unreleased** - SwiftData regression testing and security enhancements

For detailed technical changes and development guidelines, see the [Wiki](https://github.com/beforetheshoes/Traveling-Snails.wiki.git).