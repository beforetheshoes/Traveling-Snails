//
//  UIConstants.swift
//  Traveling Snails
//
//

import SwiftUI

/// Centralized UI constants for consistent spacing, sizing, and timing throughout the app
/// This prevents magic numbers scattered across the codebase and ensures design consistency
enum UIConstants {
    
    // MARK: - Spacing Constants
    
    /// Standard spacing values used throughout the app for consistent layout
    enum Spacing {
        /// Extra small spacing: 4pt
        static let tiny: CGFloat = 4
        
        /// Small spacing: 8pt
        static let small: CGFloat = 8
        
        /// Medium spacing: 12pt
        static let medium: CGFloat = 12
        
        /// Large spacing: 16pt
        static let large: CGFloat = 16
        
        /// Extra large spacing: 20pt
        static let extraLarge: CGFloat = 20
    }
    
    // MARK: - Icon Size Constants
    
    /// Standard icon sizes for consistent visual hierarchy
    enum IconSizes {
        /// Small icons: 16pt (for inline use, small buttons)
        static let small: CGFloat = 16
        
        /// Medium icons: 24pt (for standard buttons, list items)
        static let medium: CGFloat = 24
        
        /// Large icons: 50pt (for prominent displays, headers)
        static let large: CGFloat = 50
    }
    
    // MARK: - Timing Constants
    
    /// Standard timing values for animations, delays, and timeouts
    enum Timing {
        /// Biometric authentication timeout in seconds
        static let biometricTimeoutSeconds: UInt64 = 30
        
        /// Polling interval for Mac Catalyst in seconds
        static let macCatalystPollingInterval: TimeInterval = 10.0
        
        /// Standard polling interval in seconds
        static let standardPollingInterval: TimeInterval = 30.0
        
        /// Nanosecond multiplier for sleep operations
        static let nanosecondMultiplier: UInt64 = 1_000_000_000
        
        /// Cross-device sync propagation delay in nanoseconds (200ms)
        static let crossDeviceSyncDelayNanoseconds: UInt64 = 200_000_000
        
        /// CloudKit processing delay in milliseconds
        static let cloudKitProcessingDelayMilliseconds: Int = 200
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    
    /// Apply standard spacing using UIConstants
    /// These provide convenient, semantically named spacing options
    
    /// Apply tiny padding (4pt)
    func paddingTiny() -> some View {
        padding(UIConstants.Spacing.tiny)
    }
    
    /// Apply small padding (8pt)
    func paddingSmall() -> some View {
        padding(UIConstants.Spacing.small)
    }
    
    /// Apply medium padding (12pt)
    func paddingMedium() -> some View {
        padding(UIConstants.Spacing.medium)
    }
    
    /// Apply large padding (16pt)
    func paddingLarge() -> some View {
        padding(UIConstants.Spacing.large)
    }
    
    /// Apply extra large padding (20pt)
    func paddingExtraLarge() -> some View {
        padding(UIConstants.Spacing.extraLarge)
    }
}

// MARK: - Image Extensions

extension Image {
    
    /// Apply standard icon sizing using UIConstants
    /// These provide consistent icon sizes throughout the app
    
    /// Apply small icon size (16pt)
    func iconSmall() -> some View {
        frame(width: UIConstants.IconSizes.small, height: UIConstants.IconSizes.small)
    }
    
    /// Apply medium icon size (24pt)
    func iconMedium() -> some View {
        frame(width: UIConstants.IconSizes.medium, height: UIConstants.IconSizes.medium)
    }
    
    /// Apply large icon size (50pt)
    func iconLarge() -> some View {
        frame(width: UIConstants.IconSizes.large, height: UIConstants.IconSizes.large)
    }
}