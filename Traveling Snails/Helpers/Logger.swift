//
//  Logger.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/10/25.
//

import Foundation
import os

/// Centralized logging system for the application
final class Logger {
    static let shared = Logger()
    
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.travelingsnails.app"
    private var loggers: [Category: os.Logger] = [:]
    
    private init() {
        setupLoggers()
    }
    
    enum Level: String, CaseIterable {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case critical = "🚨"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    enum Category: String, CaseIterable {
        case app = "App"
        case database = "Database"
        case filePicker = "FilePicker"
        case fileAttachment = "FileAttachment"
        case network = "Network"
        case ui = "UI"
        case cloudKit = "CloudKit"
        case export = "Export"
        case dataImport = "Import"  // Changed from 'import' to 'dataImport'
        case organization = "Organization"
        case trip = "Trip"
        case navigation = "Navigation"
        case settings = "Settings"
        case debug = "Debug"
        
        var emoji: String {
            switch self {
            case .app: return "🐌"
            case .database: return "💾"
            case .filePicker: return "📁"
            case .fileAttachment: return "📎"
            case .network: return "🌐"
            case .ui: return "🎨"
            case .cloudKit: return "☁️"
            case .export: return "📤"
            case .dataImport: return "📥"
            case .organization: return "🏢"
            case .trip: return "✈️"
            case .navigation: return "🧭"
            case .settings: return "⚙️"
            case .debug: return "🐛"
            }
        }
    }
    
    private func setupLoggers() {
        for category in Category.allCases {
            loggers[category] = os.Logger(subsystem: subsystem, category: category.rawValue)
        }
    }
    
    /// Log a message with specified level and category
    func log(
        _ message: String,
        category: Category = .app,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = formatMessage(message, category: category, level: level, file: fileName, function: function, line: line)
        
        guard let logger = loggers[category] else {
            print("⚠️ No logger found for category: \(category)")
            return
        }
        
        logger.log(level: level.osLogType, "\(formattedMessage)")
        
        // Also print to console in debug builds
        #if DEBUG
        print(formattedMessage)
        #endif
    }
    
    private func formatMessage(
        _ message: String,
        category: Category,
        level: Level,
        file: String,
        function: String,
        line: Int
    ) -> String {
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        return "\(timestamp) \(level.rawValue) \(category.emoji) [\(category.rawValue)] \(message) (\(file):\(line))"
    }
    
    /// Log an error with automatic error details extraction
    func logError(
        _ error: Error,
        message: String? = nil,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let errorMessage = message ?? "Error occurred"
        let fullMessage = "\(errorMessage): \(error.localizedDescription)"
        
        log(fullMessage, category: category, level: .error, file: file, function: function, line: line)
        
        // Log additional error details if available
        if let nsError = error as NSError? {
            let details = "Domain: \(nsError.domain), Code: \(nsError.code), UserInfo: \(nsError.userInfo)"
            log("Error details: \(details)", category: category, level: .debug, file: file, function: function, line: line)
        }
    }
    
    /// Log a database operation
    func logDatabase(
        _ operation: String,
        details: String? = nil,
        success: Bool = true,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let level: Level = success ? .info : .error
        let message = success ? "✅ \(operation)" : "❌ \(operation) failed"
        let fullMessage = details.map { detailsText in "\(message): \(detailsText)" } ?? message
        
        log(fullMessage, category: .database, level: level, file: file, function: function, line: line)
    }
    
    /// Log CloudKit operations
    func logCloudKit(
        _ operation: String,
        details: String? = nil,
        success: Bool = true,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let level: Level = success ? .info : .error
        let message = success ? "☁️ \(operation)" : "☁️ \(operation) failed"
        let fullMessage = details.map { detailsText in "\(message): \(detailsText)" } ?? message
        
        log(fullMessage, category: .cloudKit, level: level, file: file, function: function, line: line)
    }
    
    /// Log performance metrics
    func logPerformance(
        _ operation: String,
        duration: TimeInterval,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let formattedDuration = String(format: "%.3fs", duration)
        log("⏱️ \(operation) completed in \(formattedDuration)", category: category, level: .debug, file: file, function: function, line: line)
    }
    
    /// Log memory usage
    func logMemoryUsage(
        operation: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryUsage = memoryInfo.resident_size
            let memoryMB = Double(memoryUsage) / 1024.0 / 1024.0
            let message = operation.map { "📊 Memory usage after \($0): \(String(format: "%.1fMB", memoryMB))" } ?? "📊 Current memory usage: \(String(format: "%.1fMB", memoryMB))"
            log(message, category: .debug, level: .debug, file: file, function: function, line: line)
        }
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Debug logging - only appears in debug builds
    func debug(
        _ message: String,
        category: Category = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        log(message, category: category, level: .debug, file: file, function: function, line: line)
        #endif
    }
    
    /// Info logging
    func info(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, category: category, level: .info, file: file, function: function, line: line)
    }
    
    /// Warning logging
    func warning(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, category: category, level: .warning, file: file, function: function, line: line)
    }
    
    /// Error logging
    func error(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, category: category, level: .error, file: file, function: function, line: line)
    }
    
    /// Critical error logging
    func critical(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, category: category, level: .critical, file: file, function: function, line: line)
    }
}

// MARK: - Performance Measurement

extension Logger {
    /// Measure and log the execution time of a block
    func measure<T>(
        _ operation: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logPerformance(operation, duration: duration, category: category, file: file, function: function, line: line)
        return result
    }
    
    /// Async version of measure
    func measure<T>(
        _ operation: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        logPerformance(operation, duration: duration, category: category, file: file, function: function, line: line)
        return result
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
