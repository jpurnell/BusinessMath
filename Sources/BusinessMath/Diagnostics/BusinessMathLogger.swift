//
//  BusinessMathLogger.swift
//  BusinessMath
//
//  Created on December 1, 2025.
//

#if canImport(OSLog)
import OSLog
#endif

import Foundation

// MARK: - Logger Extensions

#if canImport(OSLog)
/// Logging subsystem for BusinessMath
///
/// This extension provides category-specific loggers optimized for financial calculations,
/// model execution, and performance tracking. Uses Apple's OSLog framework for near-zero
/// overhead when disabled and seamless integration with Console.app and Instruments.
///
/// ## Usage
///
/// ```swift
/// let logger = Logger.businessMath
/// logger.info("Starting financial model calculation")
///
/// // Or use category-specific loggers
/// Logger.calculations.debug("NPV calculation started")
/// Logger.performance.notice("Operation completed in \(duration)s")
/// ```
///
/// ## Performance
///
/// - Near-zero overhead when logging is disabled
/// - Messages are lazily evaluated
/// - Privacy controls prevent sensitive data leakage
/// - Instruments integration for performance analysis
///
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public extension Logger {
    /// Main BusinessMath logger for general purpose logging
    ///
    /// Use this for general library operations, initialization, and high-level events.
    static let shared = Logger(
        subsystem: "com.justinpurnell.BusinessMath",
        category: "general"
    )

    /// Logger for model execution and building operations
    ///
    /// Use this to track model creation, builder operations, and structural changes.
    ///
    /// Example:
    /// ```swift
    /// Logger.modelExecution.info("Building financial model with 3 revenue streams")
    /// ```
    static let modelExecution = Logger(
        subsystem: "com.justinpurnell.BusinessMath",
		category: "model-execution"
    )

    /// Logger for mathematical calculations and formulas
    ///
    /// Use this to trace calculation steps, formulas, and numerical operations.
    ///
    /// Example:
    /// ```swift
    /// Logger.calculations.debug("Calculating NPV with discount rate: \(rate)")
    /// ```
    static let calculations = Logger(
        subsystem: "com.justinpurnell.BusinessMath",
		category: "calculations"
    )

    /// Logger for performance metrics and profiling
    ///
    /// Use this for timing information, performance measurements, and optimization tracking.
    ///
    /// Example:
    /// ```swift
    /// Logger.performance.notice("Monte Carlo simulation completed in \(duration)s")
    /// ```
    static let performance = Logger(
        subsystem: "com.justinpurnell.BusinessMath",
        category: "performance"
    )

    /// Logger for validation and error checking
    ///
    /// Use this for validation failures, constraint violations, and data integrity issues.
    ///
    /// Example:
    /// ```swift
    /// Logger.validation.warning("Negative revenue detected: \(value)")
    /// ```
    static let validation = Logger(
        subsystem: "com.justinpurnell.BusinessMath",
        category: "validation"
    )
}

// MARK: - Convenience Logging Methods

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public extension Logger {

    // MARK: - Calculation Logging

    /// Log the start of a calculation operation
    ///
    /// - Parameters:
    ///   - name: Name of the calculation
    ///   - context: Optional context dictionary with additional information
    ///
    /// Example:
    /// ```swift
    /// logger.calculationStarted("NPV Calculation", context: ["rate": "0.08", "periods": "10"])
    /// ```
    func calculationStarted(_ name: String, context: [String: Any] = [:]) {
        self.debug("▶️ Starting calculation: \(name, privacy: .public)")
        if !context.isEmpty {
            let contextStr = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            self.trace("   Context: \(contextStr, privacy: .private)")
        }
    }

    /// Log successful completion of a calculation
    ///
    /// - Parameters:
    ///   - name: Name of the calculation
    ///   - result: The calculation result (will be marked as private)
    ///   - duration: Optional execution duration in seconds
    ///
    /// Example:
    /// ```swift
    /// logger.calculationCompleted("NPV Calculation", result: npv, duration: 0.042)
    /// ```
    func calculationCompleted(_ name: String, result: Any, duration: TimeInterval? = nil) {
        if let duration = duration {
            self.info("✅ Completed \(name, privacy: .public) in \(duration, format: .fixed(precision: 3), privacy: .public)s")
        } else {
            self.info("✅ Completed \(name, privacy: .public)")
        }
        self.trace("   Result: \(String(describing: result), privacy: .private)")
    }

    /// Log a calculation error or failure
    ///
    /// - Parameters:
    ///   - name: Name of the calculation
    ///   - error: The error that occurred
    ///
    /// Example:
    /// ```swift
    /// logger.calculationFailed("IRR Calculation", error: error)
    /// ```
    func calculationFailed(_ name: String, error: Error) {
        self.error("❌ Failed \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Validation Logging

    /// Log a validation warning
    ///
    /// - Parameters:
    ///   - message: Warning message
    ///   - field: Optional field name that triggered the warning
    ///
    /// Example:
    /// ```swift
    /// logger.validationWarning("Value exceeds recommended range", field: "discountRate")
    /// ```
    func validationWarning(_ message: String, field: String? = nil) {
        if let field = field {
            self.warning("⚠️ \(field, privacy: .public): \(message, privacy: .public)")
        } else {
            self.warning("⚠️ \(message, privacy: .public)")
        }
    }

    /// Log a validation error
    ///
    /// - Parameters:
    ///   - message: Error message
    ///   - field: Optional field name that failed validation
    ///
    /// Example:
    /// ```swift
    /// logger.validationError("Negative value not allowed", field: "revenue")
    /// ```
    func validationError(_ message: String, field: String? = nil) {
        if let field = field {
            self.error("🔴 \(field, privacy: .public): \(message, privacy: .public)")
        } else {
            self.error("🔴 \(message, privacy: .public)")
        }
    }

    // MARK: - Performance Logging

    /// Log a performance metric
    ///
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - duration: Execution duration in seconds
    ///   - context: Optional context description
    ///
    /// Example:
    /// ```swift
    /// logger.performance("Monte Carlo Simulation", duration: 2.34, context: "10,000 iterations")
    /// ```
    func performance(_ operation: String, duration: TimeInterval, context: String? = nil) {
        if let context = context {
            self.notice("⚡️ \(operation, privacy: .public) [\(context, privacy: .public)]: \(duration, format: .fixed(precision: 3), privacy: .public)s")
        } else {
            self.notice("⚡️ \(operation, privacy: .public): \(duration, format: .fixed(precision: 3), privacy: .public)s")
        }
    }

    /// Log a performance warning for slow operations
    ///
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - duration: Execution duration in seconds
    ///   - threshold: Expected threshold in seconds
    ///
    /// Example:
    /// ```swift
    /// logger.performanceWarning("Model Building", duration: 5.2, threshold: 1.0)
    /// ```
    func performanceWarning(_ operation: String, duration: TimeInterval, threshold: TimeInterval) {
        self.warning("🐌 \(operation, privacy: .public) took \(duration, format: .fixed(precision: 3), privacy: .public)s (expected < \(threshold, format: .fixed(precision: 3), privacy: .public)s)")
    }

    // MARK: - Model Execution Logging

    /// Log the start of model building
    ///
    /// - Parameters:
    ///   - modelType: Type of model being built
    ///   - components: Number of components
    ///
    /// Example:
    /// ```swift
    /// logger.modelBuildingStarted("Financial Model", components: 5)
    /// ```
    func modelBuildingStarted(_ modelType: String, components: Int? = nil) {
        if let components = components {
            self.info("🏗️ Building \(modelType, privacy: .public) with \(components, privacy: .public) component(s)")
        } else {
            self.info("🏗️ Building \(modelType, privacy: .public)")
        }
    }

    /// Log successful model building completion
    ///
    /// - Parameters:
    ///   - modelType: Type of model that was built
    ///   - duration: Optional build duration in seconds
    ///
    /// Example:
    /// ```swift
    /// logger.modelBuildingCompleted("Financial Model", duration: 0.12)
    /// ```
    func modelBuildingCompleted(_ modelType: String, duration: TimeInterval? = nil) {
        if let duration = duration {
            self.info("✨ Completed \(modelType, privacy: .public) in \(duration, format: .fixed(precision: 3), privacy: .public)s")
        } else {
            self.info("✨ Completed \(modelType, privacy: .public)")
        }
    }
}

// MARK: - Signpost Support

/// Signpost support for performance tracing in Instruments
///
/// Use signposts to create performance intervals that appear in Instruments' timeline.
/// This enables detailed performance analysis with minimal overhead.
///
/// Example:
/// ```swift
/// let signpostID = OSSignpostID(log: .performance)
/// Logger.performance.beginSignpost("NPV Calculation", id: signpostID)
/// let npv = calculateNPV()
/// Logger.performance.endSignpost("NPV Calculation", id: signpostID)
/// ```
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Logger {

    /// Begin a signpost interval for performance tracking
    ///
    /// Use this with `endSignpost` to track performance in Instruments.
    ///
    /// - Parameters:
    ///   - name: Name of the interval
    ///   - id: Signpost ID (default is exclusive)
    ///
	/// 
    /// Example:
    /// ```swift
    /// logger.beginSignpost("Calculation")
    /// performCalculation()
    /// logger.endSignpost("Calculation")
    /// ```
    func beginSignpost(_ name: StaticString, id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest), name: name, signpostID: id)
    }

    /// End a signpost interval
    ///
    /// - Parameters:
    ///   - name: Name of the interval (must match `beginSignpost`)
    ///   - id: Signpost ID (default is exclusive, must match `beginSignpost`)
    func endSignpost(_ name: StaticString, id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest), name: name, signpostID: id)
    }

    /// Create an event signpost (instantaneous point in time)
    ///
    /// - Parameters:
    ///   - name: Name of the event
    ///   - message: Optional message to include
    ///
    /// Example:
    /// ```swift
    /// logger.signpostEvent("Cache Miss")
    /// ```
    func signpostEvent(_ name: StaticString, message: String? = nil) {
        if let message = message {
            os_signpost(.event, log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest), name: name, "%{public}s", message)
        } else {
            os_signpost(.event, log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest), name: name)
        }
    }
}

#else

// MARK: - Linux Fallback Support

/// Fallback logger for Linux platforms using print statements.
///
/// This provides basic logging functionality on platforms without OSLog.
/// Uses simple print statements with category prefixes. For production use on Linux,
/// consider integrating swift-log for more sophisticated logging capabilities.
///
/// ## Platform Availability
/// This implementation is used automatically on Linux and other platforms that don't support OSLog.
/// On Apple platforms (macOS, iOS, tvOS, watchOS), the OSLog-based implementation is used instead.
///
/// ## Example
/// ```swift
/// let logger = Logger.shared
/// logger.info("Application started")
/// logger.warning("Low memory condition")
/// ```
public struct Logger: Sendable {
    let subsystem: String
    let category: String

    /// Creates a logger with the specified subsystem and category.
    ///
    /// - Parameters:
    ///   - subsystem: Reverse DNS notation identifying the subsystem (e.g., "com.example.app").
    ///   - category: Category name for grouping related log messages (e.g., "networking", "database").
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    /// Logs a debug-level message.
    ///
    /// Debug messages provide detailed information for diagnosing problems.
    /// Outputs to console with `[category] DEBUG:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func debug(_ message: String) {
        print("[\(category)] DEBUG: \(message)")
    }

    /// Logs an informational message.
    ///
    /// Info messages document normal application events and state changes.
    /// Outputs to console with `[category] INFO:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func info(_ message: String) {
        print("[\(category)] INFO: \(message)")
    }

    /// Logs a notice-level message.
    ///
    /// Notice messages highlight significant but normal events.
    /// Outputs to console with `[category] NOTICE:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func notice(_ message: String) {
        print("[\(category)] NOTICE: \(message)")
    }

    /// Logs a warning message.
    ///
    /// Warning messages indicate potential problems that don't prevent execution.
    /// Outputs to console with `[category] WARNING:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func warning(_ message: String) {
        print("[\(category)] WARNING: \(message)")
    }

    /// Logs an error message.
    ///
    /// Error messages indicate failures that impact functionality.
    /// Outputs to console with `[category] ERROR:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func error(_ message: String) {
        print("[\(category)] ERROR: \(message)")
    }

    /// Logs a trace-level message (debug builds only).
    ///
    /// Trace messages provide very detailed execution information.
    /// Only outputs in DEBUG builds to avoid performance impact.
    ///
    /// - Parameter message: The message to log.
    public func trace(_ message: String) {
        // Trace is very verbose, only in debug builds
        #if DEBUG
        print("[\(category)] TRACE: \(message)")
        #endif
    }

    // Category loggers

    /// Main shared logger for general-purpose logging.
    public static let shared = Logger(subsystem: "com.justinpurnell.BusinessMath", category: "general")

    /// Logger for model execution and building operations.
    public static let modelExecution = Logger(subsystem: "com.justinpurnell.BusinessMath", category: "model-execution")

    /// Logger for mathematical calculations and formulas.
    public static let calculations = Logger(subsystem: "com.justinpurnell.BusinessMath", category: "calculations")

    /// Logger for performance metrics and profiling.
    public static let performance = Logger(subsystem: "com.justinpurnell.BusinessMath", category: "performance")

    /// Logger for validation and error checking.
    public static let validation = Logger(subsystem: "com.justinpurnell.BusinessMath", category: "validation")

    // Convenience methods (simplified for Linux)

    /// Logs the start of a calculation operation (simplified for Linux).
    ///
    /// - Parameters:
    ///   - name: Name of the calculation.
    ///   - context: Optional context dictionary (simplified implementation logs name only).
    public func calculationStarted(_ name: String, context: [String: Any] = [:]) {
        info("Starting calculation: \(name)")
    }

    /// Logs successful completion of a calculation (simplified for Linux).
    ///
    /// - Parameters:
    ///   - name: Name of the calculation.
    ///   - result: The calculation result.
    ///   - duration: Optional execution duration in seconds.
    public func calculationCompleted(_ name: String, result: Any, duration: TimeInterval? = nil) {
        if let duration = duration {
			info("Completed \(name) in \(duration.number(3))s")
        } else {
            info("Completed \(name)")
        }
    }

    /// Logs a calculation error or failure (simplified for Linux).
    ///
    /// - Parameters:
    ///   - name: Name of the calculation.
    ///   - error: The error that occurred.
    public func calculationFailed(_ name: String, error: Error) {
        self.error("Failed \(name): \(error.localizedDescription)")
    }

    /// Logs a validation warning (simplified for Linux).
    ///
    /// - Parameters:
    ///   - message: Warning message.
    ///   - field: Optional field name that triggered the warning.
    public func validationWarning(_ message: String, field: String? = nil) {
        if let field = field {
            warning("\(field): \(message)")
        } else {
            warning(message)
        }
    }

    /// Logs a validation error (simplified for Linux).
    ///
    /// - Parameters:
    ///   - message: Error message.
    ///   - field: Optional field name that failed validation.
    public func validationError(_ message: String, field: String? = nil) {
        if let field = field {
            error("\(field): \(message)")
        } else {
            error(message)
        }
    }

    /// Logs a performance metric (simplified for Linux).
    ///
    /// - Parameters:
    ///   - operation: Name of the operation.
    ///   - duration: Execution duration in seconds.
    ///   - context: Optional context description.
    public func performance(_ operation: String, duration: TimeInterval, context: String? = nil) {
        if let context = context {
            notice("\(operation) [\(context)]: \(duration.number(3))s")
        } else {
            notice("\(operation): \(duration.number(3))s")
        }
    }

    /// Logs a performance warning for slow operations (simplified for Linux).
    ///
    /// - Parameters:
    ///   - operation: Name of the operation.
    ///   - duration: Execution duration in seconds.
    ///   - threshold: Expected threshold in seconds.
    public func performanceWarning(_ operation: String, duration: TimeInterval, threshold: TimeInterval) {
        warning("\(operation) took \(duration.number(3))s (expected < \(threshold.number(3))s)")
    }

    /// Logs the start of model building (simplified for Linux).
    ///
    /// - Parameters:
    ///   - modelType: Type of model being built.
    ///   - components: Number of components.
    public func modelBuildingStarted(_ modelType: String, components: Int? = nil) {
        if let components = components {
            info("Building \(modelType) with \(components) component(s)")
        } else {
            info("Building \(modelType)")
        }
    }

    /// Logs successful model building completion (simplified for Linux).
    ///
    /// - Parameters:
    ///   - modelType: Type of model that was built.
    ///   - duration: Optional build duration in seconds.
    public func modelBuildingCompleted(_ modelType: String, duration: TimeInterval? = nil) {
        if let duration = duration {
            info("Completed \(modelType) in \(duration.number(3))s")
        } else {
            info("Completed \(modelType)")
        }
    }
}
#endif
