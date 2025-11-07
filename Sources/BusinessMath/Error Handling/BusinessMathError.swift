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

        case .calculationFailed(let operation, let reason, _):
            return "\(operation) calculation failed: \(reason)"

        case .divisionByZero(let context):
				if let operation = context["operation"] {
                return "Division by zero in \(operation)"
            }
            return "Division by zero"

        case .numericalInstability(let message, _):
            return "Numerical instability: \(message)"

        case .mismatchedDimensions(let message, let context):
            var description = "Mismatched dimensions: \(message)"
            if let expected = context["expected"], let actual = context["actual"] {
                description += " (expected: \(expected), got: \(actual))"
            }
            return description

        case .dataQuality(let message, _):
            return "Data quality issue: \(message)"
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
