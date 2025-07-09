//
//  BackgroundModelContextManager.swift
//  Traveling Snails
//
//

import Foundation
import os.log
import SwiftData

/// Manages background ModelContext operations to prevent blocking the main thread
/// Uses manual actor pattern (not @ModelActor) to avoid threading issues in iOS 17-18
actor BackgroundModelContextManager {
    private let container: ModelContainer
    private let logger = Logger.secure(category: .database)

    /// Initialize with the main model container
    init(container: ModelContainer) {
        self.container = container
    }

    /// Perform a save operation in a background context
    /// - Parameter operation: The operation to perform with the background context
    /// - Returns: The result of the operation
    func performBackgroundSave<T>(
        operation: @escaping (ModelContext) async throws -> AppResult<T>
    ) async -> AppResult<T> {
        // Create a background context from the container
        let backgroundContext = ModelContext(container)

        do {
            logger.debug("Creating background context for save operation")

            // Perform the operation on the background context
            let result = try await operation(backgroundContext)

            // Log the result
            switch result {
            case .success:
                logger.debug("Background save operation completed successfully")
            case .failure(let error):
                logger.error("Background save operation failed: \(error.localizedDescription, privacy: .public)")
            }

            return result
        } catch {
            let appError = AppError.databaseSaveFailed("Background operation failed: \(error.localizedDescription)")
            logger.error("Background save operation threw error: \(error.localizedDescription, privacy: .public)")
            return .failure(appError)
        }
    }

    /// Convenience method for simple background saves
    /// - Parameters:
    ///   - modifications: Block to perform modifications on the background context
    ///   - context: Context description for logging
    /// - Returns: Result of the save operation
    func performBackgroundSave(
        context: String = "Background save",
        modifications: @escaping (ModelContext) throws -> Void
    ) async -> AppResult<Void> {
        await performBackgroundSave { backgroundContext in
            try modifications(backgroundContext)
            return backgroundContext.safeSave(context: context)
        }
    }
}

// MARK: - Extension for EditTripView Integration

extension BackgroundModelContextManager {
    /// Perform a trip save operation in background context
    /// - Parameters:
    ///   - tripId: The UUID of the trip to save
    ///   - modifications: Block to perform modifications on the trip
    /// - Returns: Result of the save operation
    func saveTripInBackground(
        tripId: UUID,
        modifications: @escaping (Trip) throws -> Void
    ) async -> AppResult<Void> {
        await performBackgroundSave { backgroundContext in
            // Fetch the trip in background context
            let fetchDescriptor = FetchDescriptor<Trip>(
                predicate: #Predicate<Trip> { $0.id == tripId }
            )

            let trips = try backgroundContext.fetch(fetchDescriptor)

            guard let trip = trips.first else {
                return .failure(.databaseLoadFailed("Trip with ID \(tripId) not found"))
            }

            // Apply modifications
            try modifications(trip)

            // Save the changes
            return backgroundContext.safeSave(context: "Trip save operation")
        }
    }
}
