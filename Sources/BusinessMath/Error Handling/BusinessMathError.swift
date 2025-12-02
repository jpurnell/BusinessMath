//
//  BusinessMathError.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation

/// Comprehensive error type for BusinessMath library.
///
/// This error type provides rich error messages with context, recovery suggestions,
/// and human-readable descriptions for all BusinessMath operations.
///
/// Example:
/// ```swift
/// do {
///     let result = try calculateIRR(cashFlows: flows)
/// } catch let error as BusinessMathError {
///     print(error.localizedDescription)
///     // "IRR calculation failed: Failed to converge after 100 iterations"
///
///     if case .calculationFailed(_, _, let suggestions) = error {
///         print("Suggestions:")
///         suggestions.forEach { print("- \($0)") }
///     }
/// }
/// ```
public enum BusinessMathError: Error, Sendable {
    /// Invalid input parameter (e.g., negative discount rate, empty cash flows)
    case invalidInput(message: String, context: [String: String])

    /// Calculation failed to complete (e.g., IRR non-convergence)
    case calculationFailed(operation: String, reason: String, suggestions: [String])

    /// Division by zero attempted
    case divisionByZero(context: [String: String])

    /// Numerical instability detected
    case numericalInstability(message: String, suggestions: [String])

    /// Dimensions or sizes don't match (e.g., mismatched time series periods)
    case mismatchedDimensions(message: String, context: [String: String])

    /// Data quality issue (handled through validation framework, but can be thrown directly)
    case dataQuality(message: String, context: [String: String])

    // MARK: - Phase 3 Enhanced Errors

    /// Invalid driver configuration in financial model
    case invalidDriver(name: String, reason: String)

    /// Circular dependency detected in model calculations
    case circularDependency(path: [String])

    /// Missing required data for calculation
    case missingData(account: String, period: String)

    /// Validation failed with multiple errors
    case validationFailed(errors: [String])

    /// Inconsistent data detected
    case inconsistentData(description: String)

    /// Insufficient data points for calculation
    case insufficientData(required: Int, actual: Int, context: String)

    /// Negative value where positive required
    case negativeValue(name: String, value: Double, context: String)

    /// Value outside acceptable range
    case outOfRange(value: Double, min: Double, max: Double, context: String)
}

// MARK: - LocalizedError Conformance

extension BusinessMathError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message, let context):
            var description = "Invalid input: \(message)"
            if let value = context["value"] {
                description += " (provided: \(value))"
            }
				if let expectedRange = context["expectedRange"] {
                description += " (expected: \(expectedRange))"
            }
            return description

        case .calculationFailed(let operation, let reason, let suggestions):
				var description: String = "\(operation) calculation failed: \(reason)"
				if !suggestions.isEmpty {
					for suggestion in suggestions {
						description += "\nSuggestion: \(suggestion)"
					}
				}
				return description

        case .divisionByZero(let context):
				if let operation = context["operation"] {
                return "Division by zero in \(operation)"
            }
            return "Division by zero"

        case .numericalInstability(let message, let suggestions):
				var description: String = "Numerical instability: \(message)"
				if !message.isEmpty {
					description += ": \(suggestions.joined(separator: ", "))"
				}
            return description

        case .mismatchedDimensions(let message, let context):
            var description = "Mismatched dimensions: \(message)"
            if let expected = context["expected"], let actual = context["actual"] {
                description += " (expected: \(expected), got: \(actual))"
            }
            return description

        case .dataQuality(let message, let context):
            var description: String = "Data quality issue: \(message)"
				if !context.isEmpty {
					for contextItem in context {
						description += "; \(contextItem.key): \(contextItem.value)"
					}
				}
				return description

        case .invalidDriver(let name, let reason):
            return "Invalid driver '\(name)': \(reason)"

        case .circularDependency(let path):
            return "Circular dependency detected: \(path.joined(separator: " → "))"

        case .missingData(let account, let period):
            return "Missing data for '\(account)' in period \(period)"

        case .validationFailed(let errors):
            return "Validation failed with \(errors.count) error(s):\n" + errors.map { "• \($0)" }.joined(separator: "\n")

        case .inconsistentData(let description):
            return "Data inconsistency: \(description)"

        case .insufficientData(let required, let actual, let context):
            return "Insufficient data for \(context): need \(required), got \(actual)"

        case .negativeValue(let name, let value, let context):
            return "Negative value for '\(name)' (\(value)) in \(context)"

        case .outOfRange(let value, let min, let max, let context):
            return "Value \(value) out of range [\(min), \(max)] in \(context)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .calculationFailed(_, _, let suggestions),
             .numericalInstability(_, let suggestions):
            guard !suggestions.isEmpty else { return nil }
            return "Possible solutions:\n" + suggestions.map { "• \($0)" }.joined(separator: "\n")

        case .invalidInput(_, let context):
            if let expectedRange = context["expectedRange"] {
                return "Please provide a value within the range: \(expectedRange)"
            }
            return "Please check your input values and try again"

        case .divisionByZero:
            return "Ensure the denominator is non-zero before performing this calculation"

        case .mismatchedDimensions:
            return "Ensure all time series have matching periods before combining them"

        case .dataQuality:
            return "Clean or interpolate your data before performing calculations"

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

        case .missingData(let account, _):
            return """
            Provide data for '\(account)' by:
            • Adding a driver for this account
            • Setting a default value
            • Using fillMissing() or interpolate() on the time series
            """

        case .validationFailed:
            return "Fix the validation errors listed above to proceed"

        case .inconsistentData:
            return "Review your data for logical consistency and correct any discrepancies"

        case .insufficientData(let required, _, let context):
            return """
            \(context) requires at least \(required) data points.
            Consider:
            • Providing more historical data
            • Using a shorter analysis period
            • Using a simpler model that requires less data
            """

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
}

// MARK: - Convenience Constructors

extension BusinessMathError {
    /// Create invalidInput error with convenience parameters
    public static func invalidInput(message: String, value: String? = nil, expectedRange: String? = nil) -> BusinessMathError {
        var context: [String: String] = [:]
        if let value = value {
            context["value"] = value
        }
        if let range = expectedRange {
            context["expectedRange"] = range
        }
        return .invalidInput(message: message, context: context)
    }
}
