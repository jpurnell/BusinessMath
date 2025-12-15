//
//  FloatingPointFormatter.swift
//  BusinessMath
//
//  Created for Phase 8: Floating-Point Formatting
//

import Foundation

/// Formats floating-point numbers with intelligent strategies to handle numerical noise.
///
/// Optimization results often have floating-point noise in the least significant digits.
/// `FloatingPointFormatter` provides several strategies to present clean, readable output
/// while preserving full precision in the raw values.
///
/// ## Example
/// ```swift
/// let formatter = FloatingPointFormatter(strategy: .smartRounding())
/// let result = formatter.format(2.9999999999999964)
/// print(result)  // "3"
/// let raw = result.rawValue  // 2.9999999999999964
/// ```
public struct FloatingPointFormatter: Sendable {

    // MARK: - Strategy

    /// Formatting strategies for different use cases
    public enum Strategy: Sendable {
        /// Snap to nearest integer if very close, remove trailing zeros
        case smartRounding(tolerance: Double = 1e-8)

        /// Format with specified number of significant figures
        case significantFigures(count: Int)

        /// Adapt precision based on value magnitude
        case contextAware(tolerance: Double = 1e-8, maxDecimals: Int = 6)

        /// Custom formatting function
        case custom(@Sendable (Double) -> String)
    }

    // MARK: - Properties

    /// The formatting strategy to use
    public let strategy: Strategy

    // MARK: - Initialization

    /// Create a formatter with the specified strategy
    /// - Parameter strategy: The formatting strategy to use
    public init(strategy: Strategy = .smartRounding()) {
        self.strategy = strategy
    }

    // MARK: - Formatting

    /// Format a single value
    /// - Parameter value: The value to format
    /// - Returns: A FormattedValue containing both raw and formatted representations
    public func format(_ value: Double) -> FormattedValue<Double> {
        let formatted: String

        switch strategy {
        case .smartRounding(let tolerance):
            formatted = formatWithSmartRounding(value, tolerance: tolerance)

        case .significantFigures(let count):
            formatted = formatWithSigFigs(value, count)

        case .contextAware(let tolerance, let maxDecimals):
            formatted = formatContextAware(value, tolerance: tolerance, maxDecimals: maxDecimals)

        case .custom(let formatFunc):
            formatted = formatFunc(value)
        }

        return FormattedValue(rawValue: value, formatted: formatted)
    }

    /// Format an array of values
    /// - Parameter values: The values to format
    /// - Returns: Array of FormattedValues
    public func format(_ values: [Double]) -> [FormattedValue<Double>] {
        values.map { format($0) }
    }

    // MARK: - Private Formatting Methods

    /// Smart rounding: snap to integer if close, remove trailing zeros
    private func formatWithSmartRounding(_ value: Double, tolerance: Double) -> String {
        // Handle edge cases
        if !value.isFinite {
            return String(describing: value)
        }

        // Essentially zero?
        if abs(value) < tolerance {
            return "0"
        }

        // Close to an integer?
        let nearest = value.rounded()
        if abs(value - nearest) < tolerance {
            return String(format: "%.0f", nearest)
        }

        // Otherwise, format with limited decimals and remove trailing zeros
        var formatted = String(format: "%.6f", value)

        // Remove trailing zeros
        if formatted.contains(".") {
            while formatted.last == "0" {
                formatted.removeLast()
            }
            if formatted.last == "." {
                formatted.removeLast()
            }
        }

        return formatted
    }

    /// Format with significant figures
    private func formatWithSigFigs(_ value: Double, _ n: Int) -> String {
        if value == 0 { return "0" }

        // Guard against edge cases
        if !value.isFinite { return String(describing: value) }
        if n <= 0 { return "0" }

        let magnitude = floor(log10(abs(value)))
        let scale = pow(10.0, magnitude - Double(n) + 1)
        let rounded = (value / scale).rounded() * scale

        // Determine decimal places needed
        let decimals = max(0, n - Int(magnitude) - 1)

        if decimals <= 0 {
            return String(format: "%.0f", rounded)
        } else {
            var formatted = String(format: "%.\(decimals)f", rounded)
            // Remove trailing zeros
            while formatted.contains(".") && (formatted.last == "0" || formatted.last == ".") {
                formatted.removeLast()
                if formatted.last == "." {
                    formatted.removeLast()
                    break
                }
            }
            return formatted
        }
    }

    /// Context-aware formatting: adapt precision to magnitude
    private func formatContextAware(_ value: Double, tolerance: Double, maxDecimals: Int) -> String {
        // Handle edge cases
        if !value.isFinite {
            return String(describing: value)
        }

        // 1. Check if essentially zero
        if abs(value) < tolerance {
            return "0"
        }

        // 2. Check if very close to an integer
        let nearest = value.rounded()
        if abs(value - nearest) < tolerance {
            return String(format: "%.0f", nearest)
        }

        // 3. Use appropriate decimal places based on magnitude
        let magnitude = abs(value)
        let decimals: Int
        if magnitude >= 1000 {
            decimals = 1
        } else if magnitude >= 10 {
            decimals = 2
        } else if magnitude >= 1 {
            decimals = 3
        } else if magnitude >= 0.01 {
            decimals = 4
        } else {
            decimals = 6
        }

        var formatted = String(format: "%.\(min(decimals, maxDecimals))f", value)

        // 4. Remove trailing zeros
        if formatted.contains(".") {
            while formatted.last == "0" {
                formatted.removeLast()
            }
            if formatted.last == "." {
                formatted.removeLast()
            }
        }

        return formatted
    }
}

// MARK: - Default Formatters

extension FloatingPointFormatter {
    /// Default formatter for optimization results
    public static let optimization = FloatingPointFormatter(strategy: .contextAware())

    /// Default formatter for financial values (4 significant figures)
    public static let financial = FloatingPointFormatter(strategy: .significantFigures(count: 4))

    /// Default formatter for probabilities (3 significant figures)
    public static let probability = FloatingPointFormatter(strategy: .significantFigures(count: 3))

    /// Raw formatter (no formatting, just string conversion)
    public static let raw = FloatingPointFormatter(strategy: .custom { String(describing: $0) })
}
