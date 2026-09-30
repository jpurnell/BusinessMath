//
//  ValidationFramework.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation
import Numerics

// MARK: - Warning Severity

/// Severity level for validation warnings
public enum WarningSeverity: Sendable { // legibility:reserved part of the public CalculationWarning shape surfaced by BMValidationResult
    case info
    case warning
    case error
}

// MARK: - Warning Type

/// Type classification for warnings
public enum WarningType: Sendable { // legibility:reserved part of the public CalculationWarning shape surfaced by BMValidationResult
    case missingData
    case outlier
    case numericalIssue
    case dimensionMismatch // LIVE: public warning type for matrix/vector validation
    case invalidValue
    case other
}

// MARK: - Calculation Warning

/// A warning generated during validation or calculation
public struct CalculationWarning: Sendable { // legibility:reserved exposed via BMValidationResult.warnings public API; consumed by downstream packages
    /// The severity of this warning
    public let severity: WarningSeverity

    /// The type classification
    public let type: WarningType

    /// Human-readable message describing the issue
    public let message: String

    /// Additional context about the warning
    public let context: [String: String]

    /// Recovery suggestions
    public let suggestions: [String]

    /// Creates a calculation warning with context and recovery suggestions.
    ///
    /// - Parameters:
    ///   - severity: Severity level (`.info`, `.warning`, or `.error`)
    ///   - type: Warning classification for filtering and categorization
    ///   - message: Human-readable description of the issue
    ///   - context: Additional key-value pairs providing context (e.g., variable names, values)
    ///   - suggestions: Array of recommended actions to resolve or mitigate the issue
    public init(
        severity: WarningSeverity,
        type: WarningType,
        message: String,
        context: [String: String] = [:],
        suggestions: [String] = []
    ) {
        self.severity = severity
        self.type = type
        self.message = message
        self.context = context
        self.suggestions = suggestions
    }
}

// MARK: - Validation Result

/// Result of a validation operation (BusinessMath validation)
public struct BMValidationResult: Sendable {
    /// Whether the validation passed (no errors)
    public let isValid: Bool

    /// All warnings (info, warning, and error severity)
    public let warnings: [CalculationWarning]

    /// Errors only (convenience accessor)
    public var errors: [CalculationWarning] {
        warnings.filter { $0.severity == .error }
    }

    /// Warnings only (convenience accessor)
    public var warningsOnly: [CalculationWarning] {
        warnings.filter { $0.severity == .warning }
    }

    /// Info messages only (convenience accessor)
    public var info: [CalculationWarning] {
        warnings.filter { $0.severity == .info }
    }

    /// Creates a validation result with validity status and warnings.
    ///
    /// - Parameters:
    ///   - isValid: Whether validation passed (true = no errors, false = has errors)
    ///   - warnings: Array of all warnings including info, warnings, and errors
    public init(isValid: Bool, warnings: [CalculationWarning] = []) {
        self.isValid = isValid
        self.warnings = warnings
    }

    /// Create a valid result with no warnings
    public static var valid: BMValidationResult {
        BMValidationResult(isValid: true, warnings: [])
    }

    /// Create an invalid result with errors
    public static func invalid(errors: [CalculationWarning]) -> BMValidationResult {
        BMValidationResult(isValid: false, warnings: errors)
    }
}

// MARK: - Validatable Protocol

/// Protocol for types that can be validated
public protocol Validatable {
    /// Validate this instance and return results
    func validate() -> BMValidationResult
}

// MARK: - TimeSeries Validation

extension TimeSeries: Validatable where T: Real & Sendable {
	/// Validate the instance and return a result
    public func validate() -> BMValidationResult {
        return validate(detectOutliers: false)
    }

    /// Validate time series and throw if errors are found.
    ///
    /// This method validates the time series and throws `BusinessMathError` if critical
    /// errors are detected (NaN values, infinite values, empty series, or period gaps).
    /// Use this when you need error handling instead of inspecting validation results.
    ///
    /// - Parameter detectOutliers: Whether to detect outliers (default: false)
	/// - Throws: ``BusinessMathError/dataQuality(message:context:)`` if validation fails
    ///
    /// ## Example
    /// ```swift
    /// let timeSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
    /// do {
    ///     try timeSeries.validateAndThrow()
    ///     // TimeSeries is valid, safe to use
    /// } catch let error as BusinessMathError {
    ///     print("Validation failed: \(error.errorDescription!)")
    ///     // Handle invalid time series
    /// }
    /// ```
    public func validateAndThrow(detectOutliers: Bool = false) throws {
        let result = validate(detectOutliers: detectOutliers)

        guard result.isValid else {
            // Collect error messages
            let errorMessages = result.errors.map { $0.message }.joined(separator: "; ")

            // Build context dictionary
            var context: [String: String] = [:]
            for error in result.errors {
                context.merge(error.context) { $1 }
            }
            context["errorCount"] = String(result.errors.count)

            throw BusinessMathError.dataQuality(
                message: errorMessages,
                context: context
            )
        }
    }

    /// Validate with optional outlier detection
    public func validate(detectOutliers shouldDetectOutliers: Bool) -> BMValidationResult {
        var warnings: [CalculationWarning] = []

        // Check for empty time series
        if count == 0 {
            warnings.append(CalculationWarning(
                severity: .error,
                type: .invalidValue,
                message: "Time series is empty",
                suggestions: ["Add data points to the time series"]
            ))
            return BMValidationResult(isValid: false, warnings: warnings)
        }

        // Check for NaN values
        let nanIndices = valuesArray.enumerated().filter { $0.element.isNaN }.map { $0.offset }
        if !nanIndices.isEmpty {
            warnings.append(CalculationWarning(
                severity: .error,
                type: .numericalIssue,
                message: "Time series contains NaN values at \(nanIndices.count) position(s)",
                context: ["indices": nanIndices.map { String($0) }.joined(separator: ", ")],
                suggestions: [
                    "Remove or replace NaN values",
                    "Use interpolation to fill missing values",
                    "Check data source for calculation errors"
                ]
            ))
        }

        // Check for infinite values
        let infIndices = valuesArray.enumerated().filter { $0.element.isInfinite }.map { $0.offset }
        if !infIndices.isEmpty {
            warnings.append(CalculationWarning(
                severity: .error,
                type: .numericalIssue,
                message: "Time series contains infinite values at \(infIndices.count) position(s)",
                context: ["indices": infIndices.map { String($0) }.joined(separator: ", ")],
                suggestions: [
                    "Check for division by zero in calculations",
                    "Verify input data ranges",
                    "Cap extreme values if appropriate"
                ]
            ))
        }

        // Check for gaps in periods (for consecutive period types)
        if count > 1 {
            let gaps = detectPeriodGaps()
            if !gaps.isEmpty {
                warnings.append(CalculationWarning(
                    severity: .error,
                    type: .missingData,
                    message: "Time series has \(gaps.count) gap(s) in periods",
                    context: ["gapCount": String(gaps.count)],
                    suggestions: [
                        "Fill gaps using forward fill",
                        "Fill gaps using interpolation",
                        "Fill gaps with zero if appropriate",
                        "Verify data collection process"
                    ]
                ))
            }
        }

        // Outlier detection (optional)
        if shouldDetectOutliers && count > 3 {
            let outliers = detectOutliersInSeries()
            if !outliers.isEmpty {
                warnings.append(CalculationWarning(
                    severity: .warning,
                    type: .outlier,
                    message: "Time series contains \(outliers.count) potential outlier(s)",
                    context: ["indices": outliers.map { String($0) }.joined(separator: ", ")],
                    suggestions: [
                        "Review outliers to determine if they're legitimate",
                        "Consider removing or capping outliers",
                        "Investigate data collection issues",
                        "Use robust statistical methods if outliers are expected"
                    ]
                ))
            }
        }

        let hasErrors = warnings.contains { $0.severity == .error }
        return BMValidationResult(isValid: !hasErrors, warnings: warnings)
    }

    /// Detect gaps in periods by checking for missing consecutive periods.
    ///
    /// This method checks if the time series has gaps in its sequence of periods.
    /// For each consecutive pair of periods, it verifies they are adjacent by
    /// comparing the second period to the expected next period after the first.
    ///
    /// - Returns: Array of indices where gaps occur (the index after the gap).
    private func detectPeriodGaps() -> [Int] {
        guard count > 1 else { return [] }
        
        var gapIndices: [Int] = []
        
        // Check each consecutive pair of periods
        for i in 0..<(count - 1) {
            let currentPeriod = periods[i]
            let nextPeriod = periods[i + 1]
            
            // Check if periods are the same type
            if currentPeriod.type != nextPeriod.type {
                // Different period types - consider this a gap
                gapIndices.append(i + 1)
                continue
            }
            
            // Get the expected next period
            let expectedNext = currentPeriod.next()
            
            // If the actual next period doesn't match expected, there's a gap
            if nextPeriod != expectedNext {
                gapIndices.append(i + 1)
            }
        }
        
        return gapIndices
    }

    /// Detect outliers using IQR method.
    ///
    /// An observation that is not a finite number is reported on its own, and the IQR is not
    /// computed at all. Two things went wrong here at once and each hid the other. `sorted()`
    /// is unspecified on a sample holding a `nan`, so `q1` and `q3` — taken **by index** from
    /// that array — came off an arbitrary permutation, and the bounds derived from them could
    /// call a perfectly ordinary observation an outlier or miss a real one. And the filter at
    /// the end asks `< lowerBound || > upperBound`, both false against a `nan`, so the single
    /// most obviously unusual reading in the series was the one observation this detector
    /// could never flag. The caller turns this into "review these observations", which is the
    /// right instruction for an unreadable reading as much as for an extreme one.
    private func detectOutliersInSeries() -> [Int] {
        guard count > 3 else { return [] }

        let unreadable: [Int] = valuesArray.enumerated()
            .filter { !$0.element.isFinite }
            .map { $0.offset }
        guard unreadable.isEmpty else { return unreadable }

        let sortedValues = valuesArray.sorted()
        let q1Index = sortedValues.count / 4
        let q3Index = (sortedValues.count * 3) / 4

        let q1 = sortedValues[q1Index]
        let q3 = sortedValues[q3Index]
        let iqr = q3 - q1

        // 1.5 * IQR for outlier detection
        let multiplier = iqr + (iqr / T(2))  // 1.5 = 1 + 0.5
        let lowerBound = q1 - multiplier
        let upperBound = q3 + multiplier

        return valuesArray.enumerated()
            .filter { $0.element < lowerBound || $0.element > upperBound }
            .map { $0.offset }
    }
}

// MARK: - FinancialModel Validation

extension FinancialModel: Validatable {
	/// Validates the model's components and reports what is wrong with them.
    ///
    /// Four conditions are reported, at three severities:
    ///
    /// | condition | severity | `isValid` |
    /// |---|---|---|
    /// | no components at all | `.info` | `true` |
    /// | costs but no revenue | `.warning` | `true` |
    /// | a revenue amount that is not finite | `.error` | `false` |
    /// | a revenue amount below zero | `.error` | `false` |
    ///
    /// **Negative revenue is an error.** It was a `.warning` until this was written, which —
    /// with the empty case at `.info` and the pre-revenue case at `.warning` — left this
    /// conformance unable to return `isValid == false` for any reason of its own. Revenue
    /// below zero is not a modelling choice a caller might have meant: it is a sign error, or
    /// an input contaminated on the way in. A refund, an allowance or a chargeback is an
    /// expense and belongs in `costComponents`, which is what the suggestion says.
    ///
    /// **Costs without revenue stays a warning.** A pre-revenue company is a real thing, its
    /// model is worth building, and it must keep validating.
    ///
    /// - Returns: A ``BMValidationResult`` whose `isValid` is `false` when any `.error`
    ///   warning was produced.
    public func validate() -> BMValidationResult {
        var warnings: [CalculationWarning] = []

        // Check for empty model
        if revenueComponents.isEmpty && costComponents.isEmpty {
            warnings.append(CalculationWarning(
                severity: .info,
                type: .other,
                message: "Financial model is empty (no revenue or cost components)",
                suggestions: ["Add revenue and cost components to the model"]
            ))
        }

        // Check for models with only costs (no revenue)
        if !costComponents.isEmpty && revenueComponents.isEmpty {
            warnings.append(CalculationWarning(
                severity: .warning,
                type: .other,
                message: "Financial model has costs but no revenue sources",
                suggestions: ["Add revenue components to calculate profitability"]
            ))
        }

        // Check for non-finite values in revenue.
        //
        // `nan < 0` is false, so an amount that is not a number matched the negative test
        // below and was reported as nothing at all. The `TimeSeries` conformance in this
        // same file already reports a non-finite observation as `.error` — that is the
        // sibling this follows, and the severity is taken from it rather than chosen: an
        // amount nobody could compute is not a judgement call about sign. The negative
        // branch below is now `.error` as well, on its own reasoning — the two arrived
        // there separately and neither depends on the other.
        for (index, component) in revenueComponents.enumerated() {
            guard component.amount.isFinite else {
                warnings.append(CalculationWarning(
                    severity: .error,
                    type: .numericalIssue,
                    message: "Revenue component '\(component.name)' has a value that is not finite",
                    context: ["component": component.name, "index": String(index), "value": String(component.amount)],
                    suggestions: [
                        "Check the calculation that produced this amount for division by zero",
                        "Replace the amount with a finite value"
                    ]
                ))
                continue
            }

            // Revenue below zero is an error, not a warning.
            //
            // Without this severity the caller was told "verify that negative revenue is
            // intentional" on a result whose `isValid` was still `true` — and a caller that
            // branches on `isValid`, which is the whole point of the type, never read the
            // sentence. Nothing legitimate produces it: a refund, an allowance or a
            // chargeback is an expense, and the suggestion says where it belongs.
            if component.amount < 0 {
                warnings.append(CalculationWarning(
                    severity: .error,
                    type: .invalidValue,
                    message: "Revenue component '\(component.name)' has negative value",
                    context: ["component": component.name, "index": String(index), "value": String(component.amount)],
                    suggestions: ["Move the amount to a cost component if it is an expense", "Correct the sign of the amount"]
                ))
            }
        }

        let hasErrors = warnings.contains { $0.severity == .error }
        return BMValidationResult(isValid: !hasErrors, warnings: warnings)
    }
}
