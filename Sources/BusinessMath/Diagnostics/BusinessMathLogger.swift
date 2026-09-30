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


// MARK: - Cross-platform logging

// The fallback below is compiled on EVERY platform, under its own name, and aliased to
// `Logger` only where OSLog is absent.
//
// It used to live entirely behind `#else`, which meant no build a macOS developer ran
// compiled a line of it and no test they ran executed one. It was written in December with
// every severity, every category and every convenience method — and it had never compiled,
// because its primitives took a `String` while every call site in this package writes
// `\(value, privacy: .public)`. Ten months of green builds said nothing either way, and the
// defect surfaced only when a Linux toolchain was finally pointed at a package that depends
// on this one.
//
// Compiled here, it is exercised by the macOS test suite like anything else.


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
/// import OSLog
/// let logger = Logger.shared
/// logger.info("Application started")
/// logger.warning("Low memory condition")
/// ```

// MARK: - Message type for the fallback

/// The privacy annotation `os.Logger` interpolation accepts.
///
/// Carried so every call site written for OSLog compiles unchanged. The value is not
/// consulted: redaction on a platform with no unified log would withhold text from a
/// developer reading their own console, which protects nobody.
public struct OSLogPrivacy: Sendable {
    /// Rendered in full.
    public static let `public` = OSLogPrivacy()
    /// Rendered in full here; see the type's note.
    public static let `private` = OSLogPrivacy()
    /// Rendered in full here; see the type's note.
    public static let auto = OSLogPrivacy()
}

/// The numeric format `os.Logger` interpolation accepts.
public struct OSLogFloatFormatting: Sendable {
    let precision: Int?
    /// Fixed-point with the given number of fraction digits.
    /// - Parameter precision: Fraction digits to render.
    /// - Returns: A format carrying that precision.
    public static func fixed(precision: Int) -> OSLogFloatFormatting {
        OSLogFloatFormatting(precision: precision)
    }
    /// The default format.
    public static let fixed = OSLogFloatFormatting(precision: nil)
}

/// A log message assembled from a literal and its interpolations.
///
/// Exists because the previous fallback took a plain `String`, which cannot accept
/// `\(value, privacy:)` or `\(value, format:)` — so every call site in this package failed
/// to compile on Linux with "extra argument 'privacy' in call" even though a fallback logger
/// was present. A fallback that the call sites cannot call is not a fallback.
public struct BusinessMathLogMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation,
                                     CustomStringConvertible, Sendable {
    /// The fully rendered text.
    public let rendered: String

    /// The rendered text, so the existing `print("… \(message)")` bodies below need no edit.
    public var description: String { rendered }

    /// Creates a message from a literal with no interpolations.
    /// - Parameter value: The literal text.
    public init(stringLiteral value: String) { rendered = value }

    /// Creates a message from an interpolated literal.
    /// - Parameter stringInterpolation: The accumulated segments.
    public init(stringInterpolation: StringInterpolation) { rendered = stringInterpolation.text }

    /// Accepts the interpolation shapes `os.Logger` accepts.
    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        var text: String

        /// Creates the accumulator the compiler fills segment by segment.
        /// - Parameters:
        ///   - literalCapacity: Total length of the literal segments.
        ///   - interpolationCount: How many interpolations follow.
        public init(literalCapacity: Int, interpolationCount: Int) {
            text = ""
            text.reserveCapacity(literalCapacity + interpolationCount * 8)
        }

        /// Appends a literal segment.
        /// - Parameter literal: The text between interpolations.
        public mutating func appendLiteral(_ literal: String) { text += literal }

        /// `\(value)` and `\(value, privacy:)` alike.
        /// - Parameters:
        ///   - value: The value to render.
        ///   - privacy: Accepted and not consulted; see ``OSLogPrivacy``.
        public mutating func appendInterpolation(_ value: Any, privacy: OSLogPrivacy = .public) {
            text += Self.describe(value)
        }

        /// `\(value, format:)` and `\(value, format:, privacy:)`.
        /// - Parameters:
        ///   - value: The value to render.
        ///   - format: Fraction digits to apply when the value is a floating-point number.
        ///   - privacy: Accepted and not consulted; see ``OSLogPrivacy``.
        public mutating func appendInterpolation(
            _ value: Any,
            format: OSLogFloatFormatting,
            privacy: OSLogPrivacy = .public
        ) {
            if let precision = format.precision, let number = Self.asDouble(value) {
                // `formatted(.number…)` rather than `String(format:)`: the C printf ABI takes a
                // C string pointer for %s and fails at runtime rather than compile time, which
                // is why the safety checker refuses it — and it refused this line when it was
                // written that way.
                text += number.formatted(.number.precision(.fractionLength(precision)))
            } else {
                text += Self.describe(value)
            }
        }

        private static func describe(_ value: Any) -> String {
            if let text = value as? String { return text }
            if let convertible = value as? any CustomStringConvertible { return convertible.description }
            return String(describing: value)
        }

        private static func asDouble(_ value: Any) -> Double? {
            switch value {
            case let d as Double: return d
            case let f as Float: return Double(f)
            case let i as Int: return Double(i)
            default: return nil
            }
        }
    }
}

public struct BusinessMathFallbackLogger: Sendable {
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
    public func debug(_ message: BusinessMathLogMessage) {
        print("[\(category)] DEBUG: \(message)") // logging: Linux fallback — os.Logger unavailable on non-Darwin platforms
    }

    /// Logs an informational message.
    ///
    /// Info messages document normal application events and state changes.
    /// Outputs to console with `[category] INFO:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func info(_ message: BusinessMathLogMessage) {
        print("[\(category)] INFO: \(message)") // logging: Linux fallback — os.Logger unavailable on non-Darwin platforms
    }

    /// Logs a notice-level message.
    ///
    /// Notice messages highlight significant but normal events.
    /// Outputs to console with `[category] NOTICE:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func notice(_ message: BusinessMathLogMessage) {
        print("[\(category)] NOTICE: \(message)") // logging: Linux fallback — os.Logger unavailable on non-Darwin platforms
    }

    /// Logs a warning message.
    ///
    /// Warning messages indicate potential problems that don't prevent execution.
    /// Outputs to console with `[category] WARNING:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func warning(_ message: BusinessMathLogMessage) {
        print("[\(category)] WARNING: \(message)") // logging: Linux fallback — os.Logger unavailable on non-Darwin platforms
    }

    /// Logs an error message.
    ///
    /// Error messages indicate failures that impact functionality.
    /// Outputs to console with `[category] ERROR:` prefix.
    ///
    /// - Parameter message: The message to log.
    public func error(_ message: BusinessMathLogMessage) {
        print("[\(category)] ERROR: \(message)") // logging: Linux fallback — os.Logger unavailable on non-Darwin platforms
    }

    /// Logs a trace-level message (debug builds only).
    ///
    /// Trace messages provide very detailed execution information.
    /// Only outputs in DEBUG builds to avoid performance impact.
    ///
    /// - Parameter message: The message to log.
    public func trace(_ message: BusinessMathLogMessage) {
        // Trace is very verbose, only in debug builds
        #if DEBUG
        print("[\(category)] TRACE: \(message)") // logging: Linux fallback — os.Logger unavailable on non-Darwin platforms
        #endif
    }

    // Category loggers

    /// Main shared logger for general-purpose logging.
    public static let shared = BusinessMathFallbackLogger(subsystem: "com.justinpurnell.BusinessMath", category: "general")

    /// Logger for model execution and building operations.
    public static let modelExecution = BusinessMathFallbackLogger(subsystem: "com.justinpurnell.BusinessMath", category: "model-execution")

    /// Logger for mathematical calculations and formulas.
    public static let calculations = BusinessMathFallbackLogger(subsystem: "com.justinpurnell.BusinessMath", category: "calculations")

    /// Logger for performance metrics and profiling.
    public static let performance = BusinessMathFallbackLogger(subsystem: "com.justinpurnell.BusinessMath", category: "performance")

    /// Logger for validation and error checking.
    public static let validation = BusinessMathFallbackLogger(subsystem: "com.justinpurnell.BusinessMath", category: "validation")

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
        self.error("Failed \(name): \(error.localizedDescription)") // logging: Linux fallback — privacy annotations not available
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
            warning("\(message)")
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
            error("\(message)")
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
/// import OSLog
/// let logger = Logger.shared
/// logger.info("Starting financial model calculation")
///
/// // Or use category-specific loggers
/// Logger.calculations.debug("NPV calculation started")
/// let duration = 0.042
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
    /// import OSLog
    /// Logger.modelExecution.info("Building financial model with 3 revenue streams")
    /// ```
    static let modelExecution = Logger( // LIVE: category logger used by consumers for model execution tracing
        subsystem: "com.justinpurnell.BusinessMath",
		category: "model-execution"
    )

    /// Logger for mathematical calculations and formulas
    ///
    /// Use this to trace calculation steps, formulas, and numerical operations.
    ///
    /// Example:
    /// ```swift
    /// import OSLog
    /// let rate = 0.08
    /// Logger.calculations.debug("Calculating NPV with discount rate: \(rate)")
    /// ```
    static let calculations = Logger( // LIVE: category logger used by consumers for calculation tracing
        subsystem: "com.justinpurnell.BusinessMath",
		category: "calculations"
    )

    /// Logger for performance metrics and profiling
    ///
    /// Use this for timing information, performance measurements, and optimization tracking.
    ///
    /// Example:
    /// ```swift
    /// let simulation = try FinancialSimulation.documentationFixture
    /// import OSLog
    /// let duration = 1.42
    /// Logger.performance.notice("Monte Carlo simulation completed in \(duration)s")
    /// ```
    static let performance = Logger( // LIVE: category logger used by consumers for performance profiling
        subsystem: "com.justinpurnell.BusinessMath",
        category: "performance"
    )

    /// Logger for validation and error checking
    ///
    /// Use this for validation failures, constraint violations, and data integrity issues.
    ///
    /// Example:
    /// ```swift
    /// import OSLog
    /// let value = -12.5
    /// Logger.validation.warning("Negative revenue detected: \(value)")
    /// ```
    static let validation = Logger(
        subsystem: "com.justinpurnell.BusinessMath",
        category: "validation"
    )
}

// MARK: - Convenience Logging Methods

/// Convenience logging methods for BusinessMath calculation, validation, and performance tracking.
///
/// These extensions provide domain-specific logging patterns for financial calculations,
/// model building, and performance monitoring with appropriate privacy controls.
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
    /// import OSLog
    /// let logger = Logger.shared
    /// let periods = Period.documentationQuarters
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
    /// import OSLog
    /// let logger = Logger.shared
    /// let npv = 1_234.56
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
    /// import OSLog
    /// let logger = Logger.shared
    /// let error: any Error = CancellationError()
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
    /// import OSLog
    /// let logger = Logger.shared
    /// logger.validationWarning("Value exceeds recommended range", field: "discountRate")
    /// ```
    func validationWarning(_ message: String, field: String? = nil) { // LIVE: public API for structured validation warning logging
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
    /// import OSLog
    /// let logger = Logger.shared
    /// logger.validationError("Negative value not allowed", field: "revenue")
    /// ```
    func validationError(_ message: String, field: String? = nil) { // LIVE: public API for structured validation error logging
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
    /// import OSLog
    /// let logger = Logger.shared
    /// logger.performance("Monte Carlo Simulation", duration: 2.34, context: "10,000 iterations")
    /// ```
    func performance(_ operation: String, duration: TimeInterval, context: String? = nil) { // LIVE: public API for structured performance metric logging
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
    /// import OSLog
    /// let logger = Logger.shared
    /// logger.performanceWarning("Model Building", duration: 5.2, threshold: 1.0)
    /// ```
    func performanceWarning(_ operation: String, duration: TimeInterval, threshold: TimeInterval) { // LIVE: public API for performance warning logging
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
    /// import OSLog
    /// let logger = Logger.shared
    /// logger.modelBuildingStarted("Financial Model", components: 5)
    /// ```
    func modelBuildingStarted(_ modelType: String, components: Int? = nil) { // LIVE: public API for model building lifecycle logging
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
    /// import OSLog
    /// let logger = Logger.shared
    /// logger.modelBuildingCompleted("Financial Model", duration: 0.12)
    /// ```
    func modelBuildingCompleted(_ modelType: String, duration: TimeInterval? = nil) { // LIVE: public API for model building lifecycle logging
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
/// import OSLog
/// let signpostID = OSSignpostID(log: .default)
/// Logger.performance.beginSignpost("NPV Calculation", id: signpostID)
/// let npv = BusinessMath.npv(discountRate: 0.08, cashFlows: [-1000, 400, 400, 400])
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
    /// import OSLog
    /// let logger = Logger.shared
    /// func performCalculation() {}
    /// logger.beginSignpost("Calculation")
    /// performCalculation()
    /// logger.endSignpost("Calculation")
    /// ```
    func beginSignpost(_ name: StaticString, id: OSSignpostID = .exclusive) { // LIVE: public API for Instruments signpost tracing
        os_signpost(.begin, log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest), name: name, signpostID: id)
    }

    /// End a signpost interval
    ///
    /// - Parameters:
    ///   - name: Name of the interval (must match `beginSignpost`)
    ///   - id: Signpost ID (default is exclusive, must match `beginSignpost`)
    func endSignpost(_ name: StaticString, id: OSSignpostID = .exclusive) { // LIVE: public API for Instruments signpost tracing
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
    /// import OSLog
    /// let logger = Logger.shared
    /// logger.signpostEvent("Cache Miss")
    /// ```
    func signpostEvent(_ name: StaticString, message: String? = nil) { // LIVE: public API for Instruments signpost event markers
        if let message = message {
            os_signpost(.event, log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest), name: name, "%{public}s", message)
        } else {
            os_signpost(.event, log: OSLog(subsystem: "com.justinpurnell.BusinessMath", category: .pointsOfInterest), name: name)
        }
    }
}

#else

/// `os.Logger` under its Apple spelling, where Apple's does not exist.
public typealias Logger = BusinessMathFallbackLogger

#endif