//
//  ModelDebugger.swift
//  BusinessMath
//
//  Created on December 1, 2025.
//

import Foundation

#if canImport(OSLog)
import OSLog
#endif

// MARK: - Model Debugger

/// Debugging and diagnostic tools for financial models
///
/// The ModelDebugger provides comprehensive tools for understanding, diagnosing,
/// and validating financial models. It can trace calculations, identify issues,
/// and provide actionable suggestions for fixes.
///
/// ## Features
///
/// - **Calculation Tracing**: Understand how values are computed
/// - **Diagnostics**: Identify issues, warnings, and potential problems
/// - **Validation**: Check model consistency and constraints
/// - **Explanations**: Understand differences between expected and actual values
///
/// ## Example Usage
///
/// ```swift
/// let debugger = ModelDebugger()
///
/// // Trace a calculation
/// let trace = debugger.trace(value: "NPV") {
///     calculateNPV(cashFlows: flows, discountRate: 0.08)
/// }
/// print(trace.formatted())
///
/// // Diagnose issues
/// let report = debugger.diagnose(value: npv, expected: 50_000, tolerance: 0.01)
/// if report.hasIssues {
///     print(report.formatted())
/// }
/// ```
public struct ModelDebugger: Sendable {

    /// Logger for debug operations
    #if canImport(OSLog)
    private let logger = Logger.validation
    #endif

    /// Initialize a new model debugger
    public init() {}

    // MARK: - Calculation Tracing

    /// Trace how a value is calculated
    ///
    /// Executes the calculation and captures information about the computation,
    /// including inputs, intermediate steps, and the final result.
    ///
    /// - Parameters:
    ///   - value: Name of the value being calculated
    ///   - calculation: Closure that performs the calculation
    ///
    /// - Returns: A calculation trace containing the result and computation details
    ///
    /// Example:
    /// ```swift
    /// let trace = debugger.trace(value: "Revenue") {
    ///     price * quantity
    /// }
    /// ```
	public func trace<T>(
        value: String,
        calculation: () throws -> T
    ) -> DebugTrace<T> where T: Sendable {
        let start = Date()

        do {
            #if canImport(OSLog)
            logger.calculationStarted(value)
            #endif

            let result = try calculation()
            let duration = Date().timeIntervalSince(start)

            #if canImport(OSLog)
            logger.calculationCompleted(value, result: result, duration: duration)
            #endif

            return DebugTrace(
                value: value,
                result: result,
                error: nil,
                duration: duration,
                timestamp: start
            )
        } catch {
            let duration = Date().timeIntervalSince(start)

            #if canImport(OSLog)
            logger.calculationFailed(value, error: error)
            #endif

            return DebugTrace(
                value: value,
                result: nil,
                error: error,
                duration: duration,
                timestamp: start
            )
        }
    }

    /// Trace a calculation with explicit dependencies
    ///
    /// Similar to `trace()` but captures additional details about inputs,
    /// formulas, and dependencies for more thorough debugging.
    ///
    /// - Parameters:
    ///   - value: Name of the value being calculated
    ///   - dependencies: Dictionary of input values
    ///   - formula: The formula or expression used
    ///   - calculation: Closure that performs the calculation
    ///
    /// - Returns: Detailed trace with formula and dependencies
    ///
    /// Example:
    /// ```swift
    /// let trace = debugger.trace(
    ///     value: "NPV",
    ///     dependencies: ["rate": "0.08", "periods": "10"],
    ///     formula: "PV / (1 + rate)^periods"
    /// ) {
    ///     presentValue / pow(1.08, 10)
    /// }
    /// ```
    public func trace<T>(
        value: String,
        dependencies: [String: String],
        formula: String,
        calculation: () throws -> T
    ) throws -> DetailedDebugTrace<T> where T: Sendable {
        let start = Date()

        #if canImport(OSLog)
        logger.calculationStarted(value, context: dependencies)
        #endif

        let result = try calculation()
        let duration = Date().timeIntervalSince(start)

        #if canImport(OSLog)
        logger.calculationCompleted(value, result: result, duration: duration)
        #endif

        return DetailedDebugTrace(
            value: value,
            result: result,
            formula: formula,
            dependencies: dependencies,
            duration: duration,
            timestamp: start
        )
    }

    // MARK: - Diagnostics

    /// Diagnose a value against expected output
    ///
    /// Compares an actual value to an expected value and generates a diagnostic
    /// report with issues, warnings, and suggestions.
    ///
    /// - Parameters:
    ///   - value: The actual value
    ///   - expected: The expected value
    ///   - tolerance: Acceptable relative difference (0.01 = 1%)
    ///   - context: Optional context description
    ///
    /// - Returns: Diagnostic report with issues and suggestions
    ///
    /// Example:
    /// ```swift
    /// let report = debugger.diagnose(
    ///     value: calculatedNPV,
    ///     expected: 50_000,
    ///     tolerance: 0.05,  // 5% tolerance
    ///     context: "NPV Calculation"
    /// )
    /// ```
    public func diagnose(
        value: Double,
        expected: Double,
        tolerance: Double = 0.01,
        context: String? = nil
    ) -> DiagnosticReport {
        var issues: [DiagnosticIssue] = []
        var warnings: [DiagnosticWarning] = []
        var suggestions: [DiagnosticSuggestion] = []

        let difference = value - expected
        let percentDifference = expected != 0 ? abs(difference / expected) : 0

        // Check for NaN or infinity
        if value.isNaN {
            issues.append(DiagnosticIssue(
                severity: .error,
                message: "Value is NaN (Not a Number)",
                location: context,
                suggestion: "Check for division by zero or invalid operations"
            ))
        }

        if value.isInfinite {
            issues.append(DiagnosticIssue(
                severity: .error,
                message: "Value is infinite",
                location: context,
                suggestion: "Check for division by very small numbers or overflow"
            ))
        }

        // Check tolerance
        if !value.isNaN && !value.isInfinite && percentDifference > tolerance {
            issues.append(DiagnosticIssue(
                severity: .error,
                message: String(format: "Value differs from expected by %.2f%% (tolerance: %.2f%%)",
                              percentDifference * 100, tolerance * 100),
                location: context,
                suggestion: "Review calculation logic and input values"
            ))

            suggestions.append(DiagnosticSuggestion(
                message: "Actual: \(value), Expected: \(expected), Difference: \(difference)",
                action: "Verify formula implementation"
            ))
        }

        // Add warnings for edge cases
        if value == 0 && expected != 0 {
            warnings.append(DiagnosticWarning(
                message: "Value is zero but expected non-zero",
                location: context,
                suggestion: "Check if calculation is returning default/initial value"
            ))
        }

        return DiagnosticReport(
            timestamp: Date(),
            modelName: context,
            issues: issues,
            warnings: warnings,
            suggestions: suggestions
        )
    }

    // MARK: - Validation

    /// Validate a value against constraints
    ///
    /// Checks whether a value satisfies specified validation rules
    /// and returns a detailed report of any violations.
    ///
    /// - Parameters:
    ///   - value: The value to validate
    ///   - name: Name of the field being validated
    ///   - constraints: List of validation constraints
    ///
    /// - Returns: Validation report with violations
    ///
    /// Example:
    /// ```swift
    /// let report = debugger.validate(
    ///     value: discountRate,
    ///     name: "discountRate",
    ///     constraints: [.positive, .range(0.0, 1.0), .finite]
    /// )
    /// ```
    public func validate(
        value: Double,
        name: String,
        constraints: [ValidationConstraint]
    ) -> DebugValidationReport {
        var errors: [ValidationError] = []

        for constraint in constraints {
            let violation = constraint.validate(value: value, fieldName: name)
            if let violation = violation {
                errors.append(violation)
            }
        }

        return DebugValidationReport(
            timestamp: Date(),
            fieldName: name,
            value: value,
            errors: errors
        )
    }

    // MARK: - Explanations

    /// Explain why two values differ
    ///
    /// Analyzes the difference between actual and expected values
    /// and provides possible reasons and suggestions.
    ///
    /// - Parameters:
    ///   - actual: The actual value
    ///   - expected: The expected value
    ///   - context: Optional context description
    ///
    /// - Returns: Explanation with possible reasons
    ///
    /// Example:
    /// ```swift
    /// let explanation = debugger.explain(
    ///     actual: 90_000,
    ///     expected: 100_000,
    ///     context: "Revenue"
    /// )
    /// print(explanation.possibleReasons)
    /// ```
    public func explain(
        actual: Double,
        expected: Double,
        context: String? = nil
    ) -> Explanation {
        let difference = actual - expected
        let percentDifference = expected != 0 ? (difference / expected) * 100 : 0

        var possibleReasons: [String] = []
        var suggestions: [String] = []

        // Analyze the difference
        if actual.isNaN || expected.isNaN {
            possibleReasons.append("NaN value indicates invalid calculation")
            suggestions.append("Check for division by zero or square root of negative numbers")
        } else if actual.isInfinite || expected.isInfinite {
            possibleReasons.append("Infinite value indicates overflow or division by zero")
            suggestions.append("Check denominators and ensure values are within reasonable ranges")
        } else if difference == 0 {
            possibleReasons.append("Values match exactly")
        } else {
            // Provide context-aware analysis
            if actual < expected {
                possibleReasons.append("Actual value is lower than expected")
                suggestions.append("Check if all revenue sources are included")
                suggestions.append("Verify growth rates and multipliers")
            } else {
                possibleReasons.append("Actual value is higher than expected")
                suggestions.append("Check for double-counting")
                suggestions.append("Verify cost reductions or efficiency gains")
            }

            // Additional analysis based on magnitude
            if abs(percentDifference) > 50 {
                possibleReasons.append("Large discrepancy suggests fundamental calculation error")
                suggestions.append("Double-check the formula implementation")
                suggestions.append("Verify units and scaling factors")
            } else if abs(percentDifference) > 10 {
                possibleReasons.append("Moderate discrepancy may indicate data or parameter issues")
                suggestions.append("Review input data accuracy")
                suggestions.append("Check for rounding or precision issues")
            }
        }

        return Explanation(
            actual: actual,
            expected: expected,
            difference: difference,
            percentageDifference: percentDifference,
            possibleReasons: possibleReasons,
            suggestions: suggestions,
            context: context
        )
    }
}

// MARK: - Calculation Trace Types

/// Result of a basic calculation trace
public struct DebugTrace<T: Sendable> {
    /// Name of the value being calculated
    public let value: String

    /// The calculated result (nil if error occurred)
    public let result: T?

    /// Error that occurred during calculation (nil if successful)
    public let error: Error?

    /// Time taken for the calculation
    public let duration: TimeInterval

    /// When the calculation was performed
    public let timestamp: Date

    /// Format as a simple description
    public func formatted() -> String {
        if let result = result {
            return """
            Calculation: \(value)
            Result: \(result)
            Duration: \(String(format: "%.3f", duration))s
            Timestamp: \(timestamp)
            """
        } else if let error = error {
            return """
            Calculation: \(value)
            Error: \(error.localizedDescription)
            Duration: \(String(format: "%.3f", duration))s
            Timestamp: \(timestamp)
            """
        } else {
            return """
            Calculation: \(value)
            Result: Unknown
            Duration: \(String(format: "%.3f", duration))s
            """
        }
    }
}

/// Detailed calculation trace with dependencies and formula
public struct DetailedDebugTrace<T: Sendable> {
    /// Name of the value being calculated
    public let value: String

    /// The calculated result
    public let result: T

    /// Formula used for calculation
    public let formula: String

    /// Input dependencies (as strings for Sendable conformance)
    public let dependencies: [String: String]

    /// Time taken for the calculation
    public let duration: TimeInterval

    /// When the calculation was performed
    public let timestamp: Date

    /// Format as a tree structure
    public func asTree() -> String {
        var output = """
        \(value) = \(result)
        Formula: \(formula)
        Duration: \(String(format: "%.3f", duration))s

        Dependencies:
        """

        for (name, value) in dependencies.sorted(by: { $0.key < $1.key }) {
            output += "\n  ├─ \(name) = \(value)"
        }

        return output
    }

    /// Format as JSON for export
    public func asJSON() throws -> String {
        let dict: [String: Any] = [
            "value": value,
            "result": String(describing: result),
            "formula": formula,
            "duration": duration,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "dependencies": dependencies
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Diagnostic Types

/// Comprehensive diagnostic report
public struct DiagnosticReport: Sendable {
    /// When the diagnostic was run
    public let timestamp: Date

    /// Name of the model being diagnosed
    public let modelName: String?

    /// Critical issues found
    public let issues: [DiagnosticIssue]

    /// Warnings found
    public let warnings: [DiagnosticWarning]

    /// Suggestions for improvement
    public let suggestions: [DiagnosticSuggestion]

    /// Whether any errors were found
    public var hasErrors: Bool { !issues.isEmpty }

    /// Whether any warnings were found
    public var hasWarnings: Bool { !warnings.isEmpty }

    /// Whether any issues were found (errors or warnings)
    public var hasIssues: Bool { hasErrors || hasWarnings }

    /// Context for the diagnostic (alias for modelName)
    public var context: String? { modelName }

    /// Pretty-print the report
    public func formatted() -> String {
        var output = "=== Diagnostic Report ===\n"
        if let name = modelName {
            output += "Model: \(name)\n"
        }
        output += "Timestamp: \(timestamp)\n\n"

        if hasErrors {
            output += "❌ ERRORS (\(issues.count)):\n"
            for (index, issue) in issues.enumerated() {
                output += "\(index + 1). \(issue.message)\n"
                if let location = issue.location {
                    output += "   Location: \(location)\n"
                }
                if let suggestion = issue.suggestion {
                    output += "   💡 \(suggestion)\n"
                }
                output += "\n"
            }
        }

        if hasWarnings {
            output += "⚠️  WARNINGS (\(warnings.count)):\n"
            for (index, warning) in warnings.enumerated() {
                output += "\(index + 1). \(warning.message)\n"
                if let location = warning.location {
                    output += "   Location: \(location)\n"
                }
                if let suggestion = warning.suggestion {
                    output += "   💡 \(suggestion)\n"
                }
                output += "\n"
            }
        }

        if !suggestions.isEmpty {
            output += "💭 SUGGESTIONS (\(suggestions.count)):\n"
            for (index, suggestion) in suggestions.enumerated() {
                output += "\(index + 1). \(suggestion.message)\n"
                if let action = suggestion.action {
                    output += "   → \(action)\n"
                }
                output += "\n"
            }
        }

        if !hasIssues {
            output += "✅ No issues found!\n"
        }

        return output
    }
}

/// A diagnostic issue (error or warning)
public struct DiagnosticIssue: Sendable {
    /// Severity level
    public enum Severity: Sendable {
        case error      // Prevents correct calculation
        case warning    // Suspicious but may be valid
        case info       // Informational
    }

    /// Severity of the issue
    public let severity: Severity

    /// Description of the issue
    public let message: String

    /// Where the issue occurred
    public let location: String?

    /// Suggested fix
    public let suggestion: String?
}

/// A diagnostic warning
public struct DiagnosticWarning: Sendable {
    /// Description of the warning
    public let message: String

    /// Where the warning occurred
    public let location: String?

    /// Suggested action
    public let suggestion: String?
}

/// A diagnostic suggestion
public struct DiagnosticSuggestion: Sendable {
    /// The suggestion message
    public let message: String

    /// Recommended action
    public let action: String?
}

// MARK: - Validation Types

/// Result of a debug validation check
public struct DebugValidationReport: Sendable {
    /// When the validation was performed
    public let timestamp: Date

    /// Name of the field validated
    public let fieldName: String

    /// The value that was validated
    public let value: Double

    /// Validation errors found
    public let errors: [ValidationError]

    /// Whether validation passed
    public var isValid: Bool { errors.isEmpty }

    /// List of constraint violations
    public var violations: [ValidationError] { errors }

    /// Format as human-readable text
    public func formatted() -> String {
        var output = "=== Validation Report ===\n"
        output += "Field: \(fieldName)\n"
        output += "Value: \(value)\n"
        output += "Timestamp: \(timestamp)\n\n"

        if isValid {
            output += "✅ Validation passed\n"
        } else {
            output += "❌ Validation failed with \(errors.count) error(s):\n\n"
            for (index, error) in errors.enumerated() {
                output += "\(index + 1). \(error.description)\n"
            }
        }

        return output
    }
}

/// Validation constraints for debugging
public enum ValidationConstraint: Sendable {
    case positive
    case nonNegative
    case range(Double, Double)
    case nonZero
    case finite
    case maxValue(Double)
    case minValue(Double)

    /// Validate a value against this constraint
    func validate(value: Double, fieldName: String) -> ValidationError? {
        switch self {
        case .positive:
            if value <= 0 {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "positive",
                    message: "Value must be positive",
                    suggestion: "Ensure \(fieldName) is greater than zero"
                )
            }

        case .nonNegative:
            if value < 0 {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "non-negative",
                    message: "Value must be non-negative",
                    suggestion: "Ensure \(fieldName) is greater than or equal to zero"
                )
            }

        case .range(let min, let max):
            if value < min || value > max {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "range",
                    message: "Value must be between \(min) and \(max)",
                    suggestion: "Adjust \(fieldName) to fall within the valid range"
                )
            }

        case .nonZero:
            if value == 0 {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "non-zero",
                    message: "Value must not be zero",
                    suggestion: "Provide a non-zero value for \(fieldName)"
                )
            }

        case .finite:
            if !value.isFinite {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "finite",
                    message: "Value must be finite (not NaN or infinite)",
                    suggestion: "Check calculation for division by zero or overflow"
                )
            }

        case .maxValue(let max):
            if value > max {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "max-value",
                    message: "Value exceeds maximum of \(max)",
                    suggestion: "Reduce \(fieldName) to be at most \(max)"
                )
            }

        case .minValue(let min):
            if value < min {
                return ValidationError(
                    field: fieldName,
                    value: value,
                    rule: "min-value",
                    message: "Value is below minimum of \(min)",
                    suggestion: "Increase \(fieldName) to be at least \(min)"
                )
            }
        }

        return nil
    }
}

// MARK: - Explanation Types

/// Explanation of value differences
public struct Explanation: Sendable {
    /// The actual value
    public let actual: Double

    /// The expected value
    public let expected: Double

    /// Absolute difference (actual - expected)
    public let difference: Double

    /// Percentage difference
    public let percentageDifference: Double

    /// Possible reasons for the difference
    public let possibleReasons: [String]

    /// Suggestions for investigation
    public let suggestions: [String]

    /// Context for the explanation
    public let context: String?

    /// Format as human-readable text
    public func formatted() -> String {
        var output = "=== Value Difference Explanation ===\n"
        if let ctx = context {
            output += "Context: \(ctx)\n"
        }
        output += String(format: "Actual: %.2f\n", actual)
        output += String(format: "Expected: %.2f\n", expected)
        output += String(format: "Difference: %.2f (%.2f%%)\n\n", difference, percentageDifference)

        if !possibleReasons.isEmpty {
            output += "Possible Reasons:\n"
            for reason in possibleReasons {
                output += "  • \(reason)\n"
            }
            output += "\n"
        }

        if !suggestions.isEmpty {
            output += "Suggestions:\n"
            for suggestion in suggestions {
                output += "  → \(suggestion)\n"
            }
        }

        return output
    }
}
