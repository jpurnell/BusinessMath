//
//  DoubleExtensions.swift
//  BusinessMath
//
//  Created for Phase 8: Floating-Point Formatting
//

import Foundation

// MARK: - Double Formatting Extensions
/// Formatters used throughout the system
public extension Double {

    /// Round to nearest integer if very close (within tolerance)
    ///
    /// Useful for cleaning up floating-point noise near integer values.
    ///
    /// ## Example
    /// ```swift
    /// let value = 2.9999999999999964
    /// print(value.smartRounded())  // 3.0
    ///
    /// let exact = 2.75
    /// print(exact.smartRounded())  // 2.75 (unchanged)
    /// ```
    ///
    /// - Parameter tolerance: How close to an integer to snap (default: 1e-8)
    /// - Returns: Rounded value if close to integer, otherwise original value
    func smartRounded(tolerance: Double = 1e-8) -> Double {
        let nearest = self.rounded()
        if abs(self - nearest) < tolerance {
            return nearest
        }
        return self
    }

    /// Format with specified number of significant figures
    ///
    /// Provides consistent precision across different magnitudes.
    ///
    /// ## Example
    /// ```swift
    /// print(123456.789.significantFigures(3))   // "123000"
    /// print(1.23456789.significantFigures(3))   // "1.23"
    /// print(0.00123456.significantFigures(3))   // "0.00123"
    /// ```
    ///
    /// - Parameter n: Number of significant figures
    /// - Returns: Formatted string
    func significantFigures(_ n: Int) -> String {
        let formatter = FloatingPointFormatter(strategy: .significantFigures(count: n))
        return formatter.format(self).formatted
    }

    /// Format with context-aware precision
    ///
    /// Adapts decimal places based on value magnitude and snaps to integers when appropriate.
    ///
    /// ## Example
    /// ```swift
    /// print(2.9999999999999964.number())  // "3"
    /// print(0.7500000000000002.number())  // "0.75"
    /// print(12345.6789.number())          // "12345.7"
    /// ```
    ///
    /// - Parameters:
    ///   - maxDecimals: Maximum decimal places to show (default: 6)
    ///   - snapToInteger: Whether to snap to integers when close (default: true)
    /// - Returns: Formatted string
    func formatted(maxDecimals: Int = 6, snapToInteger: Bool = true) -> String {
        let tolerance = snapToInteger ? 1e-8 : 0.0
        let formatter = FloatingPointFormatter(strategy: .contextAware(tolerance: tolerance, maxDecimals: maxDecimals))
        return formatter.format(self).formatted
    }

    /// Format as FormattedValue with specified strategy
    ///
    /// Returns a FormattedValue containing both raw and formatted representations.
    ///
    /// ## Example
    /// ```swift
    /// let value = 2.9999999999999964.formatted(with: .smartRounding())
    /// print(value)              // "3"
    /// let raw = value.rawValue  // 2.9999999999999964
    /// ```
    ///
    /// - Parameter strategy: The formatting strategy to use
    /// - Returns: FormattedValue containing raw and formatted values
    func formatted(with strategy: FloatingPointFormatter.Strategy) -> FormattedValue<Double> {
        let formatter = FloatingPointFormatter(strategy: strategy)
        return formatter.format(self)
    }
}

// MARK: - Array Extensions
/// Formatters used throughout the system
public extension Array where Element == Double {

    /// Format all values in the array
    ///
    /// ## Example
    /// ```swift
    /// let values = [2.9999, 3.0001, 0.75]
    /// print(values.number())  // "[3, 3, 0.75]"
    /// ```
    ///
    /// - Parameter strategy: The formatting strategy to use (default: smart rounding)
    /// - Returns: Array of formatted strings
    func formatted(with strategy: FloatingPointFormatter.Strategy = .smartRounding()) -> [String] {
        let formatter = FloatingPointFormatter(strategy: strategy)
        return formatter.format(self).map(\.formatted)
    }

    /// Format array as a string representation
    ///
    /// ## Example
    /// ```swift
    /// let values = [2.9999, 3.0001, 0.75]
    /// print(values.formattedDescription())  // "[3, 3, 0.75]"
    /// ```
    ///
    /// - Parameter strategy: The formatting strategy to use (default: smart rounding)
    /// - Returns: String representation of formatted array
    func formattedDescription(with strategy: FloatingPointFormatter.Strategy = .smartRounding()) -> String {
        "[" + formatted(with: strategy).joined(separator: ", ") + "]"
    }
}
