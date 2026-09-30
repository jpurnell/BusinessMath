//
//  FormattedValue.swift
//  BusinessMath
//
//  Created for Phase 8: Floating-Point Formatting
//

import Foundation

/// A wrapper that stores both raw and formatted values for floating-point numbers.
///
/// `FormattedValue` provides clean display while preserving full precision:
/// - Printing shows the formatted value
/// - Calculations use the raw value
/// - Can access both at any time
///
/// ## Example
/// ```swift
/// let formatter = FloatingPointFormatter(strategy: .smartRounding())
/// let value = formatter.format(2.9999999999999964)
///
/// print(value)              // "3"
/// let raw = value.rawValue  // 2.9999999999999964
/// let str = value.formatted // "3"
/// ```
@frozen
public struct FormattedValue<T: FloatingPoint & Sendable & Codable>: CustomStringConvertible, Codable, Sendable {

    // MARK: - Properties

    /// The raw, unformatted value with full precision
    public let rawValue: T

    /// The formatted string representation
    public let formatted: String

    // MARK: - Initialization

    /// Create a formatted value
    /// - Parameters:
    ///   - rawValue: The actual numerical value
    ///   - formatted: The formatted string representation
    public init(rawValue: T, formatted: String) {
        self.rawValue = rawValue
        self.formatted = formatted
    }

    // MARK: - CustomStringConvertible

    /// Description returns formatted value for clean printing
    public var description: String {
        formatted
    }

    // MARK: - Codable

    /// Encode only the raw value (formatted is derived)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Decode raw value and format with default formatter
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(T.self)
        self.rawValue = value
        // Use default formatting when decoding
        self.formatted = String(describing: value)
    }
}

// MARK: - Equatable

extension FormattedValue: Equatable {
    /// Equality based on raw values
    public static func == (lhs: FormattedValue, rhs: FormattedValue) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

// MARK: - Comparable

extension FormattedValue: Comparable where T: Comparable {
    /// Comparison based on raw values
    public static func < (lhs: FormattedValue, rhs: FormattedValue) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// `<=` and `>=` are supplied rather than inherited, and that is the whole point of them.
    ///
    /// Swift synthesises the two inclusive operators from `<` as negations — `a <= b` becomes
    /// `!(b < a)` and `a >= b` becomes `!(a < b)`. For a type wrapping a floating-point value
    /// that inverts the IEEE answer: every comparison against a NaN is false, so the negation
    /// is **true**. A wrapper supplying only `<` therefore reports that an unusable value is
    /// both at least and at most any other, and a validation guard written `guard a >= b`
    /// fails *open* — it admits the value it was written to reject.
    ///
    /// Measured on `Date`, which has exactly this shape and where it was a live defect:
    ///
    /// ```
    /// raw Double : nan >= x            -> false
    /// Date       : nanDate >= realDate -> TRUE
    /// control    : Date(0) >= Date(1.7e9) -> false   // a real inversion is still rejected
    /// ```
    ///
    /// `FormattedValue` is constrained to `T: FloatingPoint`, so unlike `Date` the hazard is
    /// not conditional — every instantiation wraps a float. Delegating to the wrapped value's
    /// own operators makes the wrapper answer what the number answers.
    ///
    /// Note `==` is already correct for the same reason and is deliberately left alone: it
    /// delegates to `rawValue`, so a NaN is not equal to itself, exactly as the underlying
    /// value is not. That does mean a NaN-valued instance is a poor `Set` member or dictionary
    /// key — but so is a bare `Double`, and hiding the difference would be worse.
    public static func <= (lhs: FormattedValue, rhs: FormattedValue) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

    /// The other half of the pair. See ``<=(_:_:)`` for why both are written out.
    public static func >= (lhs: FormattedValue, rhs: FormattedValue) -> Bool {
        lhs.rawValue >= rhs.rawValue
    }
}

// MARK: - Hashable

extension FormattedValue: Hashable where T: Hashable {
    /// Hash based on raw value
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
