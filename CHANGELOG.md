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
- NSUbiquitousKeyValueStore implementation for user preferences with automatic iCloud sync
- Comprehensive notification handling for iCloud key-value store changes (server changes, account changes, quota violations)
- UserDefaults fallback when iCloud unavailable for robust settings management
- Simplified @Observable AppSettings architecture with @State environment object pattern for immediate UI response
- Cross-device dark/light mode settings sync with real-time updates

### Changed
- iPad navigation now uses custom tab bar instead of NavigationSplitView for consistent UI
- Biometric authentication changed from global app protection to per-trip protection
- Test performance expectations adjusted for realistic device performance
- Enhanced database cleanup patterns to be more conservative with user data
- User preferences sync method from SwiftData to NSUbiquitousKeyValueStore for improved reliability and purpose-built iCloud sync
- AppSettings architecture simplified from complex abstraction layers to direct @Observable with @State environment object pattern
- Settings UI updated to use direct environment object access instead of multiple @Bindable wrapper layers
- Migrated all NavigationView instances to NavigationStack for modern iOS 18+ compatibility

### Fixed
- SwiftData fatal crashes in AppSettings caused by stale model references and ModelContext lifecycle issues
- Settings sync reliability issues between devices using proper Apple-provided iCloud Key-Value Store
- Broken @Observable chain in settings UI that prevented external iCloud changes from updating the interface
- AppSettings singleton behavior now properly handles external notification changes from other devices
- Test failures related to singleton caching behavior by implementing reloadFromStorage() debug method
- Migrated from XCTests to modern Swift Testing framework (@Test, @Suite)
- Updated README.md with adaptive navigation and database management features
- User preferences (color scheme, biometric timeout) now sync via iCloud instead of being device-local
- AppSettings refactored to use SwiftData instead of UserDefaults for CloudKit compatibility
- Reorganized test suite into logical directories for better maintainability
- Dark/light mode toggle not applying user preference to app interface
- iPad tab bar overlapping navigation titles by implementing custom bottom tab bar
- Test data contamination in real app database through improved isolation
- Performance test failures by adjusting timeout expectations (DirectoryRestructureIntegrationTests, CloudKitSwiftDataConformanceTests, SwiftDataRegressionTests)
- SwiftData infinite view recreation bugs through proper @Query usage patterns
- Biometric authentication crashes caused by missing NSFaceIDUsageDescription in Info.plist
- Swift 6 Sendable compliance errors in BiometricAuthManager
- iOS NavigationSplitView compatibility issues in ContentView
- **Critical infinite recreation bug** in UniversalAddTripActivityRootView where @Observable view models were created directly in view body causing constant recreation and performance issues

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