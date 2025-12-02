//
//  EnhancedBusinessMathError.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//  Phase 3: Enhanced Error Handling
//

import Foundation

/// Comprehensive enhanced error types for BusinessMath with actionable recovery suggestions
///
/// Phase 3 enhancements include:
/// - Error codes for tracking and documentation
/// - Detailed recovery suggestions
/// - Help anchors linking to documentation
/// - Context-aware error messages
///
/// Example:
/// ```swift
/// do {
///     let model = try buildFinancialModel(...)
/// } catch let error as EnhancedBusinessMathError {
///     print(error.localizedDescription)
///     print("Error Code: \(error.code)")
///
///     if let recovery = error.recoverySuggestion {
///         print("How to fix:\n\(recovery)")
///     }
///
///     if let helpURL = error.helpAnchor {
///         print("Learn more: \(helpURL)")
///     }
/// }
/// ```
public enum EnhancedBusinessMathError: LocalizedError, Sendable {
    // MARK: - Calculation Errors (E001-E099)

    /// Invalid input parameter
    case invalidInput(message: String, value: String? = nil, expectedRange: String? = nil)

    /// Calculation failed to complete
    case calculationFailed(operation: String, reason: String, suggestions: [String] = [])

    /// Division by zero attempted
    case divisionByZero(context: String)

    /// Numerical instability detected
    case numericalInstability(message: String, suggestions: [String] = [])

    // MARK: - Data Errors (E100-E199)

    /// Dimensions or sizes don't match
    case mismatchedDimensions(message: String, expected: String? = nil, actual: String? = nil)

    /// Data quality issue
    case dataQuality(message: String, context: [String: String] = [:])

    /// Missing required data for calculation
    case missingData(account: String, period: String)

    /// Insufficient data points for calculation
    case insufficientData(required: Int, actual: Int, context: String)

    // MARK: - Model Errors (E200-E299)

    /// Invalid driver configuration in financial model
    case invalidDriver(name: String, reason: String)

    /// Circular dependency detected in model calculations
    case circularDependency(path: [String])

    /// Inconsistent data detected
    case inconsistentData(description: String)

    // MARK: - Validation Errors (E300-E399)

    /// Validation failed with multiple errors
    case validationFailed(errors: [String])

    /// Negative value where positive required
    case negativeValue(name: String, value: Double, context: String)

    /// Value outside acceptable range
    case outOfRange(value: Double, min: Double, max: Double, context: String)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message, let value, let expectedRange):
            var description = "Invalid input: \(message)"
            if let value = value {
                description += " (provided: \(value))"
            }
            if let expectedRange = expectedRange {
                description += " (expected: \(expectedRange))"
            }
            return description

        case .calculationFailed(let operation, let reason, let suggestions):
            var description = "\(operation) calculation failed: \(reason)"
            if !suggestions.isEmpty {
                description += "\nSuggestions:"
                for suggestion in suggestions {
                    description += "\n• \(suggestion)"
                }
            }
            return description

        case .divisionByZero(let context):
            return "Division by zero in \(context)"

        case .numericalInstability(let message, let suggestions):
            var description = "Numerical instability: \(message)"
            if !suggestions.isEmpty {
                description += "\nSuggestions: \(suggestions.joined(separator: ", "))"
            }
            return description

        case .mismatchedDimensions(let message, let expected, let actual):
            var description = "Mismatched dimensions: \(message)"
            if let expected = expected, let actual = actual {
                description += " (expected: \(expected), got: \(actual))"
            }
            return description

        case .dataQuality(let message, let context):
            var description = "Data quality issue: \(message)"
            if !context.isEmpty {
                for (key, value) in context.sorted(by: { $0.key < $1.key }) {
                    description += "; \(key): \(value)"
                }
            }
            return description

        case .missingData(let account, let period):
            return "Missing data for '\(account)' in period \(period)"

        case .insufficientData(let required, let actual, let context):
            return "Insufficient data for \(context): need \(required), got \(actual)"

        case .invalidDriver(let name, let reason):
            return "Invalid driver '\(name)': \(reason)"

        case .circularDependency(let path):
            return "Circular dependency detected: \(path.joined(separator: " → "))"

        case .inconsistentData(let description):
            return "Data inconsistency: \(description)"

        case .validationFailed(let errors):
            return "Validation failed with \(errors.count) error(s):\n" + errors.map { "• \($0)" }.joined(separator: "\n")

        case .negativeValue(let name, let value, let context):
            return "Negative value for '\(name)' (\(value)) in \(context)"

        case .outOfRange(let value, let min, let max, let context):
            return "Value \(value) out of range [\(min), \(max)] in \(context)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidInput(_, _, let expectedRange):
            if let expectedRange = expectedRange {
                return "Please provide a value within the range: \(expectedRange)"
            }
            return "Please check your input values and try again"

        case .calculationFailed(_, _, let suggestions):
            guard !suggestions.isEmpty else {
                return "Try adjusting your input parameters or using a different calculation method"
            }
            return "Possible solutions:\n" + suggestions.map { "• \($0)" }.joined(separator: "\n")

        case .divisionByZero:
            return """
            Division by zero detected.
            Check for:
            • Zero revenue or zero base values
            • Percentage calculations with zero denominators
            • Missing data being treated as zero
            """

        case .numericalInstability(_, let suggestions):
            guard !suggestions.isEmpty else {
                return "Try using more precise input values or a more stable calculation method"
            }
            return "Possible solutions:\n" + suggestions.map { "• \($0)" }.joined(separator: "\n")

        case .mismatchedDimensions:
            return "Ensure all time series have matching periods before combining them"

        case .dataQuality:
            return "Clean or interpolate your data before performing calculations"

        case .missingData(let account, _):
            return """
            Provide data for '\(account)' by:
            • Adding a driver for this account
            • Setting a default value
            • Using fillMissing() or interpolate() on the time series
            """

        case .insufficientData(let required, _, let context):
            return """
            \(context) requires at least \(required) data points.
            Consider:
            • Providing more historical data
            • Using a shorter analysis period
            • Using a simpler model that requires less data
            """

        case .invalidDriver(_, let reason):
            if reason.contains("negative") {
                return "Ensure all driver values are positive. Check input data for errors."
            }
            return "Review driver configuration and ensure all parameters are valid."

        case .circularDependency(let path):
            return """
            Break the circular dependency by:
            • Reordering calculations
            • Using an iterative solver
            • Introducing an intermediate value

            Dependency path: \(path.joined(separator: " → "))
            """

        case .inconsistentData:
            return "Review your data for logical consistency and correct any discrepancies"

        case .validationFailed:
            return "Fix the validation errors listed above to proceed"

        case .negativeValue(let name, _, _):
            return """
            '\(name)' should not be negative.
            Verify:
            • Input data is correct
            • Calculations are not producing unintended negative results
            • Use absolute value if negative is mathematically possible but semantically invalid
            """

        case .outOfRange(_, let min, let max, _):
            return "Adjust the value to fall within the valid range [\(min), \(max)]"
        }
    }

    public var failureReason: String? {
        // Could provide technical details for debugging
        return nil
    }

    public var helpAnchor: String? {
        // Link to documentation
        return "https://businessmath.com/errors/\(self.code)"
    }

    // MARK: - Error Codes

    /// Unique error code for tracking and documentation
    public var code: String {
        switch self {
        // Calculation Errors (E001-E099)
        case .invalidInput: return "E001"
        case .calculationFailed: return "E002"
        case .divisionByZero: return "E003"
        case .numericalInstability: return "E004"

        // Data Errors (E100-E199)
        case .mismatchedDimensions: return "E100"
        case .dataQuality: return "E101"
        case .missingData: return "E102"
        case .insufficientData: return "E103"

        // Model Errors (E200-E299)
        case .invalidDriver: return "E200"
        case .circularDependency: return "E201"
        case .inconsistentData: return "E202"

        // Validation Errors (E300-E399)
        case .validationFailed: return "E300"
        case .negativeValue: return "E301"
        case .outOfRange: return "E302"
        }
    }
}

// MARK: - Error Aggregator

/// Utility for collecting and throwing multiple errors
public struct ErrorAggregator: Sendable {
    private var errors: [Error] = []

    public init() {}

    /// Add an error to the collection
    public mutating func add(_ error: Error) {
        errors.append(error)
    }

    /// Add multiple errors to the collection
    public mutating func addMany(_ errors: [Error]) {
        self.errors.append(contentsOf: errors)
    }

    /// Throw if any errors were collected
    public func throwIfNeeded() throws {
        guard !errors.isEmpty else { return }

        if errors.count == 1 {
            throw errors[0]
        } else {
            let errorMessages = errors.map { ($0 as? LocalizedError)?.errorDescription ?? $0.localizedDescription }
            throw EnhancedBusinessMathError.validationFailed(errors: errorMessages)
        }
    }

    /// Check if any errors were collected
    public var hasErrors: Bool {
        !errors.isEmpty
    }

    /// Count of collected errors
    public var count: Int {
        errors.count
    }

    /// Get all collected errors
    public var allErrors: [Error] {
        errors
    }
}
