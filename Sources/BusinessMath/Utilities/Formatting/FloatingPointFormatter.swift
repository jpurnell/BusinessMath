//
//  FloatingPointFormatter.swift
//  BusinessMath
//
//  Created for Phase 8: Floating-Point Formatting
//

import Foundation

// MARK: - Display Non-Finite Values

/// The token a **human-readable** rendering uses for a number that is not finite.
///
/// This is the display half of a deliberate pair. Its counterpart is
/// `csvNonFiniteToken(_:)`, which renders the same three values for a **machine-readable**
/// column as the lowercase ASCII `nan`, `inf` and `-inf`. The two spellings differ on
/// purpose, and the difference is the whole signal:
///
/// | audience | `nan` | `+∞` | `-∞` | chosen because |
/// |---|---|---|---|---|
/// | a person reading a report | `NaN` | `∞` | `-∞` | it is what `FloatingPointFormatStyle` already writes, so a formatter's output and an unformatted `1.0.formatted()` agree |
/// | a parser reading a data column | `nan` | `inf` | `-inf` | it round-trips through `Double(_: String)`, `strtod` and `pandas`, and is locale-invariant |
///
/// Before this existed the display strategies below fell through to
/// `String(describing:)`, which writes the *machine* spelling — so a formatter whose stated
/// job is "clean, readable output" rendered `nan` and `inf`, byte-identical to a CSV field,
/// while `percent()` beside it rendered `NaN` and `∞`.
/// Two spellings of one value in one report is drift; two spellings across the display and
/// data boundary is a decision, and after this the lowercase spelling means exactly one
/// thing: *this column is going to be parsed*.
///
/// The sign is kept on an infinity because losing it would be a change of value, not of
/// presentation — `-∞` and `∞` are different answers, and a reader has no way to recover
/// which one was meant.
///
/// - Parameter value: The value being rendered for a person.
/// - Returns: The display token, or `nil` when `value` is finite and should be formatted
///   normally.
internal func displayNonFiniteToken<T: FloatingPoint>(_ value: T) -> String? {
    if value.isNaN {
        return "NaN"
    }
    if value.isInfinite {
        return value < 0 ? "-∞" : "∞"
    }
    return nil
}

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
    public func format(_ values: [Double]) -> [FormattedValue<Double>] { // recursion:safe — maps [Double] overload to scalar Double overload
        values.map { format($0) }
    }

    // MARK: - Private Formatting Methods

    /// Smart rounding: snap to integer if close, remove trailing zeros
    /// Locale-neutral fixed-decimal formatter. Drop-in replacement for the
    /// banned C-style format pattern (`%.Nf`). Uses POSIX locale and disables
    /// grouping separators to match `printf` semantics exactly.
    private func fixedDecimal(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func formatWithSmartRounding(_ value: Double, tolerance: Double) -> String {
        // Handle edge cases. Without this the caller would have been handed the machine
        // spelling — `nan`, `inf` — from a formatter whose output is meant to be read.
        if let nonFinite = displayNonFiniteToken(value) {
            return nonFinite
        }

        // Essentially zero?
        if abs(value) < tolerance {
            return "0"
        }

        // Close to an integer?
        let nearest = value.rounded()
        if abs(value - nearest) < tolerance {
            return fixedDecimal(nearest, decimals: 0)
        }

        // Otherwise, format with limited decimals and remove trailing zeros
        var formatted = fixedDecimal(value, decimals: 6)

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

        // Guard against edge cases. Without this the caller would have been handed the
        // machine spelling — `nan`, `inf` — from a formatter whose output is meant to be read.
        if let nonFinite = displayNonFiniteToken(value) { return nonFinite }
        if n <= 0 { return "0" }

        let magnitude = floor(log10(abs(value)))
        let scale = pow(10.0, magnitude - Double(n) + 1)
        let rounded = (value / scale).rounded() * scale

        // Determine decimal places needed
        let decimals = max(0, n - Int(magnitude) - 1)

        if decimals <= 0 {
            return fixedDecimal(rounded, decimals: 0)
        } else {
            var formatted = fixedDecimal(rounded, decimals: decimals)
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
        // Handle edge cases. Without this the caller would have been handed the machine
        // spelling — `nan`, `inf` — from a formatter whose output is meant to be read.
        if let nonFinite = displayNonFiniteToken(value) {
            return nonFinite
        }

        // 1. Check if essentially zero
        if abs(value) < tolerance {
            return "0"
        }

        // 2. Check if very close to an integer
        let nearest = value.rounded()
        if abs(value - nearest) < tolerance {
            return fixedDecimal(nearest, decimals: 0)
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

        var formatted = fixedDecimal(value, decimals: min(decimals, maxDecimals))

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

    /// Raw formatter (no formatting, just string conversion).
    ///
    /// The one formatter here that still spells a non-finite value `nan` or `inf`, because
    /// `String(describing:)` *is* its contract — it promises Swift's own rendering, not a
    /// presented one. A caller who wants the display spelling wants one of the strategies
    /// above; a caller who reached for `.raw` asked for the unformatted value.
    public static let raw = FloatingPointFormatter(strategy: .custom { String(describing: $0) })
}
