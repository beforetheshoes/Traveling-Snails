# Changelog

All notable changes to the Traveling Snails project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Database Cleanup Tool in Settings for removing test data and resetting database
- Custom iPad tab bar for proper bottom navigation without title overlap
- Enhanced test isolation with TestConfiguration.swift and TestGuard
- CloudKit sync loading indicator for better user experience during data sync
- Performance test timeout adjustments for realistic expectations
- Comprehensive developer documentation (CLAUDE.md) with critical SwiftData patterns
- Swift Testing framework implementation replacing XCTests
- Organized test directory structure (Unit Tests, Integration Tests, UI Tests, SwiftData Tests, Security Tests)
- SwiftDataTestBase for isolated test environments
- CloudKit + SwiftData compatibility patterns with private optional + safe accessor approach
- Biometric authentication (Touch ID/Face ID) for individual trip protection
- Wiki documentation structure for technical details

### Changed
- iPad navigation now uses custom tab bar instead of NavigationSplitView for consistent UI
- Biometric authentication changed from global app protection to per-trip protection
- Test performance expectations adjusted for realistic device performance
- Enhanced database cleanup patterns to be more conservative with user data
- Migrated from XCTests to modern Swift Testing framework (@Test, @Suite)
- Updated README.md with adaptive navigation and database management features
- Reorganized test suite into logical directories for better maintainability

### Fixed
- iPad tab bar overlapping navigation titles by implementing custom bottom tab bar
- Test data contamination in real app database through improved isolation
- Performance test failures by adjusting timeout expectations (DirectoryRestructureIntegrationTests, CloudKitSwiftDataConformanceTests, SwiftDataRegressionTests)
- SwiftData infinite view recreation bugs through proper @Query usage patterns
- Biometric authentication crashes caused by missing NSFaceIDUsageDescription in Info.plist
- Swift 6 Sendable compliance errors in BiometricAuthManager
- iOS NavigationSplitView compatibility issues in ContentView

### Security
- Added NSFaceIDUsageDescription privacy permission for biometric authentication
- Enhanced test isolation to prevent accidental access to production data
- Improved error handling for LAContext operations with proper privacy compliance

### Removed
- Global biometric authentication settings (replaced with per-trip protection)
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