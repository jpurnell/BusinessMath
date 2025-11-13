//
//  ValidationFramework.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation
import RealModule

// MARK: - Warning Severity

/// Severity level for validation warnings
public enum WarningSeverity: Sendable {
    case info
    case warning
    case error
}

// MARK: - Warning Type

/// Type classification for warnings
public enum WarningType: Sendable {
    case missingData
    case outlier
    case numericalIssue
    case dimensionMismatch
    case invalidValue
    case other
}

// MARK: - Calculation Warning

/// A warning generated during validation or calculation
public struct CalculationWarning: Sendable {
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
    public func validate() -> BMValidationResult {
        return validate(detectOutliers: false)
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

    /// Detect outliers using IQR method
    private func detectOutliersInSeries() -> [Int] {
        guard count > 3 else { return [] }

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

        // Check for negative values in revenue
        for (index, component) in revenueComponents.enumerated() {
            if component.amount < 0 {
                warnings.append(CalculationWarning(
                    severity: .warning,
                    type: .invalidValue,
                    message: "Revenue component '\(component.name)' has negative value",
                    context: ["component": component.name, "index": String(index)],
                    suggestions: ["Verify that negative revenue is intentional", "Consider using cost components for expenses"]
                ))
            }
        }

        let hasErrors = warnings.contains { $0.severity == .error }
        return BMValidationResult(isValid: !hasErrors, warnings: warnings)
    }
}
