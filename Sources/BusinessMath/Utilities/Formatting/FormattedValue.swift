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
}

// MARK: - Hashable

extension FormattedValue: Hashable where T: Hashable {
    /// Hash based on raw value
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
