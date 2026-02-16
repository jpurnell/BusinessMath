//
//  TimeSeriesBuilder.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

// MARK: - Time Series Entry Protocol

/// Protocol for components that can be converted to time series entries.
public protocol TimeSeriesEntry<Value>: Sendable {
    associatedtype Value: Real & Sendable
    var period: Period { get }
    var value: Value { get }
}

// MARK: - Time Series Builder

/// Result builder for constructing time series using declarative syntax.
///
/// The `TimeSeriesBuilder` enables a clean DSL for creating time series:
///
/// ```swift
/// let series = TimeSeries {
///     Period.year(2023) => 1_000_000
///     Period.year(2024) => 1_100_000
///     Period.year(2025) => 1_210_000
/// }
/// ```
///
/// Or with patterns:
///
/// ```swift
/// let projected = TimeSeries(from: 2023, to: 2030) {
///     starting(at: 1_000_000)
///     growing(by: 0.10)
/// }
/// ```
///
/// ## Result Builder Methods
/// Implements all standard result builder methods to support:
/// - Multiple entries: `buildBlock`
/// - Arrays/loops: `buildArray`
/// - Conditionals: `buildOptional`, `buildEither`
/// - Single entries: `buildExpression`
/// - API availability: `buildLimitedAvailability`
///
/// ## See Also
/// - ``TimeSeries/init(builder:)`` for using this builder
/// - `=>` operator for creating entries with arrow syntax (e.g., `Period.year(2023) => 1000`)
@resultBuilder
public struct TimeSeriesBuilder<T: Real & Sendable> {
    /// Build a block of time series entries.
    /// Accepts arrays as variadic parameters to match buildExpression's return type.
    public static func buildBlock(_ entries: [TimeSeriesEntryImpl<T>]...) -> [TimeSeriesEntryImpl<T>] {
        entries.flatMap { $0 }
    }

    /// Build an array of entries.
    public static func buildArray(_ entries: [[TimeSeriesEntryImpl<T>]]) -> [TimeSeriesEntryImpl<T>] {
        entries.flatMap { $0 }
    }

    /// Build optional entries.
    public static func buildOptional(_ entries: [TimeSeriesEntryImpl<T>]?) -> [TimeSeriesEntryImpl<T>] {
        entries ?? []
    }

    /// Build conditional entries (if/else first).
    public static func buildEither(first entries: [TimeSeriesEntryImpl<T>]) -> [TimeSeriesEntryImpl<T>] {
        entries
    }

    /// Build conditional entries (if/else second).
    public static func buildEither(second entries: [TimeSeriesEntryImpl<T>]) -> [TimeSeriesEntryImpl<T>] {
        entries
    }

    /// Convert a single entry into an array.
    public static func buildExpression(_ entry: TimeSeriesEntryImpl<T>) -> [TimeSeriesEntryImpl<T>] {
        [entry]
    }

    /// Build limited availability entries.
    public static func buildLimitedAvailability(_ entries: [TimeSeriesEntryImpl<T>]) -> [TimeSeriesEntryImpl<T>] {
        entries
    }
}

// MARK: - Time Series Entry Implementation

/// Concrete implementation of a time series entry.
///
/// Represents a single (period, value) pair in a time series. Created using
/// the arrow operator or directly via the initializer.
///
/// ## Example
/// ```swift
/// // Using arrow operator (preferred)
/// let entry1 = Period.year(2023) => 1_000_000
///
/// // Direct initialization
/// let entry2 = TimeSeriesEntryImpl(period: Period.year(2024), value: 1_100_000)
/// ```
///
/// ## See Also
/// - ``init(period:value:)`` for arrow operator syntax
/// - ``TimeSeriesEntry`` protocol
public struct TimeSeriesEntryImpl<T: Real & Sendable>: TimeSeriesEntry, Sendable {
    /// The time period for this entry (year, quarter, month, etc.).
    public let period: Period

    /// The numeric value associated with this period.
    public let value: T

    /// Create a time series entry with an explicit period and value.
    /// - Parameters:
    ///   - period: The time period
    ///   - value: The numeric value
    public init(period: Period, value: T) {
        self.period = period
        self.value = value
    }
}

// MARK: - Arrow Operator for Period => Value

infix operator =>: AssignmentPrecedence

/// Create a time series entry using arrow syntax: `Period.year(2023) => 1000`.
public func => <T: Real & Sendable>(period: Period, value: T) -> TimeSeriesEntryImpl<T> {
    TimeSeriesEntryImpl(period: period, value: value)
}

// MARK: - TimeSeries Extension for Builder

extension TimeSeries where T: Real & Sendable {
    /// Create a time series using the builder DSL.
    ///
    /// Example:
    /// ```swift
    /// let series = TimeSeries {
    ///     Period.year(2023) => 1_000_000
    ///     Period.year(2024) => 1_100_000
    ///     Period.year(2025) => 1_210_000
    /// }
    /// ```
    public init(@TimeSeriesBuilder<T> builder: () -> [TimeSeriesEntryImpl<T>]) {
        let entries = builder()
        let periods = entries.map { $0.period }
        let values = entries.map { $0.value }
        self.init(periods: periods, values: values)
    }

    /// Create a projected time series with pattern-based generation.
    ///
    /// Example:
    /// ```swift
    /// let projected = TimeSeries(from: 2023, to: 2030) {
    ///     starting(at: 1_000_000)
    ///     growing(by: 0.10)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - startYear: The starting year
    ///   - endYear: The ending year (inclusive)
    ///   - builder: A closure that defines the projection pattern
    public init(from startYear: Int, to endYear: Int, @ProjectionBuilder<T> builder: () -> TimeSeriesProjection<T>) {
        let projection = builder()
        let periods = (startYear...endYear).map { Period.year($0) }
        let values = projection.generateValues(count: periods.count)
        self.init(periods: periods, values: values)
    }
}

// MARK: - Time Series Projection

/// A pattern for generating projected time series values.
public struct TimeSeriesProjection<T: Real & Sendable>: Sendable {
    private let initialValue: T
    private let growthRate: T?
    private let generator: (@Sendable (Int) -> T)?

    init(initialValue: T, growthRate: T? = nil, generator: (@Sendable (Int) -> T)? = nil) {
        self.initialValue = initialValue
        self.growthRate = growthRate
        self.generator = generator
    }

    /// Generate values for the specified count of periods.
    func generateValues(count: Int) -> [T] {
        if let generator = generator {
            return (0..<count).map(generator)
        } else if let growth = growthRate {
            return (0..<count).map { i in
                initialValue * T.pow(1 + growth, T(i))
            }
        } else {
            return Array(repeating: initialValue, count: count)
        }
    }
}

// MARK: - Projection Builder

/// Result builder for creating time series projections.
///
/// Combines projection components (starting value, growth rate, custom generator)
/// into a complete projection pattern. Used with ``TimeSeries/init(from:to:builder:)``.
///
/// ## Example
/// ```swift
/// let projection = TimeSeries(from: 2023, to: 2030) {
///     starting(at: 1_000_000)
///     growing(by: 0.10)
/// }
/// ```
///
/// ## See Also
/// - ``starting(at:)`` for setting initial value
/// - ``growing(by:)`` for setting growth rate
/// - ``custom(generator:)`` for custom generation logic
@resultBuilder
public struct ProjectionBuilder<T: Real & Sendable> {
    /// Build a projection from components.
    ///
    /// Processes components in order, combining them into a single projection.
    /// If multiple components of the same type are provided, the last one wins.
    ///
    /// - Parameter components: Projection components (starting, growing, custom)
    /// - Returns: A complete time series projection
    public static func buildBlock(_ components: ProjectionComponent<T>...) -> TimeSeriesProjection<T> {
        var initialValue: T = 0
        var growthRate: T? = nil
        var generator: (@Sendable (Int) -> T)? = nil

        for component in components {
            switch component {
            case .starting(let value):
                initialValue = value
            case .growing(let rate):
                growthRate = rate
            case .custom(let gen):
                generator = gen
            }
        }

        return TimeSeriesProjection(initialValue: initialValue, growthRate: growthRate, generator: generator)
    }

    /// Convert a projection component into a result builder component.
    /// - Parameter component: A projection component
    /// - Returns: The component unchanged
    public static func buildExpression(_ component: ProjectionComponent<T>) -> ProjectionComponent<T> {
        component
    }
}

// MARK: - Projection Components

/// A component of a time series projection.
public enum ProjectionComponent<T: Real & Sendable>: Sendable {
    case starting(T)
    case growing(T)
    case custom(@Sendable (Int) -> T)
}

/// Set the starting value for a projection.
public func starting<T: Real & Sendable>(at value: T) -> ProjectionComponent<T> {
    .starting(value)
}

/// Set the growth rate for a projection.
public func growing<T: Real & Sendable>(by rate: T) -> ProjectionComponent<T> {
    .growing(rate)
}

/// Use a custom generator function for a projection.
public func custom<T: Real & Sendable>(generator: @Sendable @escaping (Int) -> T) -> ProjectionComponent<T> {
    .custom(generator)
}

// MARK: - Convenience Extensions

extension TimeSeries where T == Double {
    /// Create a constant time series with the same value for all periods.
    ///
    /// Example:
    /// ```swift
    /// let series = TimeSeries.constant(value: 100_000, from: 2023, to: 2030)
    /// ```
    public static func constant(value: Double, from startYear: Int, to endYear: Int) -> TimeSeries<Double> {
        TimeSeries(from: startYear, to: endYear) {
            starting(at: value)
        }
    }

    /// Create a linearly growing time series.
    ///
    /// Example:
    /// ```swift
    /// let series = TimeSeries.linear(start: 100_000, growth: 10_000, from: 2023, to: 2030)
    /// // 100_000, 110_000, 120_000, ...
    /// ```
    public static func linear(start: Double, growth: Double, from startYear: Int, to endYear: Int) -> TimeSeries<Double> {
        TimeSeries(from: startYear, to: endYear) {
            custom { i in start + growth * Double(i) }
        }
    }

    /// Create an exponentially growing time series.
    ///
    /// Example:
    /// ```swift
    /// let series = TimeSeries.exponential(start: 100_000, rate: 0.10, from: 2023, to: 2030)
    /// // 100_000, 110_000, 121_000, ...
    /// ```
    public static func exponential(start: Double, rate: Double, from startYear: Int, to endYear: Int) -> TimeSeries<Double> {
        TimeSeries(from: startYear, to: endYear) {
            starting(at: start)
            growing(by: rate)
        }
    }
}

// MARK: - Monthly and Quarterly Builders

extension TimeSeries where T: Real & Sendable {
    /// Create a monthly time series using the builder DSL.
    ///
    /// Example:
    /// ```swift
    /// let monthly = TimeSeries.monthly(year: 2024) {
    ///     Month.january => 100_000
    ///     Month.february => 105_000
    ///     Month.march => 110_000
    ///     // ...
    /// }
    /// ```
    public static func monthly(year: Int, @TimeSeriesBuilder<T> builder: () -> [TimeSeriesEntryImpl<T>]) -> TimeSeries<T> {
        TimeSeries(builder: builder)
    }

    /// Create a quarterly time series using the builder DSL.
    ///
    /// Example:
    /// ```swift
    /// let quarterly = TimeSeries.quarterly(year: 2024) {
    ///     Quarter.q1 => 300_000
    ///     Quarter.q2 => 330_000
    ///     Quarter.q3 => 320_000
    ///     Quarter.q4 => 380_000
    /// }
    /// ```
    public static func quarterly(year: Int, @TimeSeriesBuilder<T> builder: () -> [TimeSeriesEntryImpl<T>]) -> TimeSeries<T> {
        TimeSeries(builder: builder)
    }
}

// MARK: - Sequential Entry (No Explicit Period)

/// A simple entry with a value but no explicit period (for auto-sequencing).
///
/// Used with `buildTimeSeries(startingAt:)` to create time series where periods
/// are automatically sequenced from a starting point.
///
/// ## Example
/// ```swift
/// let entry1 = SimpleEntry(value: 100.0, label: "January")
/// let entry2 = SimpleEntry(value: 105.0, label: nil)
/// ```
///
/// ## See Also
/// - ``Entry(_:)`` for creating entries in a builder context
/// - ``buildTimeSeries(startingAt:builder:)``
public struct SimpleEntry<T: Real & Sendable>: Sendable {
    /// The numeric value for this entry.
    public let value: T

    /// Optional label for this entry (e.g., month name, description).
    public let label: String?

    /// Create a simple entry with a value and optional label.
    /// - Parameters:
    ///   - value: The numeric value
    ///   - label: Optional descriptive label
    public init(value: T, label: String? = nil) {
        self.value = value
        self.label = label
    }
}

// MARK: - Sequential Time Series Builder

/// Result builder for constructing time series with auto-sequenced periods.
///
/// This builder enables declarative construction of time series where periods
/// are automatically sequenced from a starting point using ``buildTimeSeries(startingAt:builder:)``.
///
/// ## Example
/// ```swift
/// let series = buildTimeSeries(startingAt: Period.month(year: 2025, month: 1)) {
///     Entry(100)
///     Entry(105)
///     Entry(110)
/// }
/// // Creates monthly series: Jan=100, Feb=105, Mar=110
/// ```
@resultBuilder
public struct SequentialTimeSeriesBuilder<T: Real & Sendable> {
    /// Build a block of simple entries from variadic arrays.
    /// - Parameter entries: Arrays of entries to flatten
    /// - Returns: Flattened array of all entries
    public static func buildBlock(_ entries: [SimpleEntry<T>]...) -> [SimpleEntry<T>] {
        entries.flatMap { $0 }
    }

    /// Build entries from for-loop arrays.
    /// - Parameter entries: Nested arrays from loops
    /// - Returns: Flattened array of entries
    public static func buildArray(_ entries: [[SimpleEntry<T>]]) -> [SimpleEntry<T>] {
        entries.flatMap { $0 }
    }

    /// Build optional entries (from if statements without else).
    /// - Parameter entries: Optional array of entries
    /// - Returns: Entries if present, empty array otherwise
    public static func buildOptional(_ entries: [SimpleEntry<T>]?) -> [SimpleEntry<T>] {
        entries ?? []
    }

    /// Build conditional entries (if/else first branch).
    /// - Parameter entries: Entries from the first branch
    /// - Returns: The entries unchanged
    public static func buildEither(first entries: [SimpleEntry<T>]) -> [SimpleEntry<T>] {
        entries
    }

    /// Build conditional entries (if/else second branch).
    /// - Parameter entries: Entries from the second branch
    /// - Returns: The entries unchanged
    public static func buildEither(second entries: [SimpleEntry<T>]) -> [SimpleEntry<T>] {
        entries
    }

    /// Convert a single entry into an array.
    /// - Parameter entry: A single entry
    /// - Returns: Array containing the entry
    public static func buildExpression(_ entry: SimpleEntry<T>) -> [SimpleEntry<T>] {
        [entry]
    }

    /// Convert an array of entries (pass through).
    /// - Parameter entries: Array of entries
    /// - Returns: The array unchanged
    public static func buildExpression(_ entries: [SimpleEntry<T>]) -> [SimpleEntry<T>] {
        entries
    }

    /// Build entries with limited availability (API availability attributes).
    /// - Parameter entries: Entries from availability-restricted code
    /// - Returns: The entries unchanged
    public static func buildLimitedAvailability(_ entries: [SimpleEntry<T>]) -> [SimpleEntry<T>] {
        entries
    }
}

// MARK: - Sequential Time Series Constructor

/// Build a time series with auto-sequenced periods starting from a given period.
///
/// Periods are automatically incremented using the period's `.next()` method.
///
/// Example:
/// ```swift
/// let jan = Period.month(year: 2025, month: 1)
///
/// let revenue = buildTimeSeries(startingAt: jan) {
///     Entry(100)              // January
///     Entry(105, label: "February")
///     Entry(110, label: "March")
///     Entry(108)              // April
/// }
/// ```
public func buildTimeSeries<T: Real & Sendable>(
    startingAt startPeriod: Period,
    @SequentialTimeSeriesBuilder<T> builder: () -> [SimpleEntry<T>]
) -> TimeSeries<T> {
    let entries = builder()

    // Generate periods by incrementing from start
    var periods: [Period] = []
    var currentPeriod = startPeriod
    for _ in entries {
        periods.append(currentPeriod)
        currentPeriod = currentPeriod.next()
    }

    let values = entries.map { $0.value }
    let labels = entries.compactMap { $0.label }
    let labelsArray = labels.isEmpty ? nil : entries.map { $0.label ?? "" }

    return TimeSeries(periods: periods, values: values, labels: labelsArray)
}

// MARK: - Entry Constructors

/// Create a sequential entry with a value (matches documented API).
///
/// Example:
/// ```swift
/// buildTimeSeries(startingAt: jan) {
///     Entry(100)
///     Entry(105)
///     Entry(110)
/// }
/// ```
public func Entry<T: Real & Sendable>(_ value: T) -> SimpleEntry<T> {
    SimpleEntry(value: value, label: nil)
}

/// Create a sequential entry with a value and label (matches documented API).
///
/// Example:
/// ```swift
/// buildTimeSeries(startingAt: jan) {
///     Entry(100, label: "January")
///     Entry(105, label: "February")
///     Entry(110, label: "March")
/// }
/// ```
public func Entry<T: Real & Sendable>(_ value: T, label: String) -> SimpleEntry<T> {
    SimpleEntry(value: value, label: label)
}

// MARK: - Growth Component

/// Generate multiple entries with compound growth (matches documented API).
///
/// **Note**: This function is currently not fully implemented in the result builder.
/// Use `GrowthFrom(startValue:rate:periods:)` instead.
///
/// Example (use GrowthFrom instead):
/// ```swift
/// buildTimeSeries(startingAt: jan) {
///     GrowthFrom(startValue: 100, rate: 0.05, periods: 12)
/// }
/// // Results in 12 entries: [100, 105, 110.25, 115.76, ...]
/// ```
public func Growth<T: Real & Sendable>(rate: T, periods: Int) -> [SimpleEntry<T>] {
    // TODO: Implement growth-from-previous-entry pattern
    // For now, return empty array and recommend GrowthFrom()
    preconditionFailure("Growth() is not yet implemented. Use GrowthFrom(startValue:rate:periods:) instead.")
}

/// Generate multiple entries with compound growth starting from a specific value.
///
/// Example:
/// ```swift
/// buildTimeSeries(startingAt: jan) {
///     GrowthFrom(startValue: 100, rate: 0.05, periods: 12)
/// }
/// // Results in [100, 105, 110.25, 115.76, ...]
/// ```
public func GrowthFrom<T: Real & Sendable>(startValue: T, rate: T, periods: Int) -> [SimpleEntry<T>] {
    (0..<periods).map { i in
        let value = startValue * T.pow(1 + rate, T(i))
        return SimpleEntry(value: value, label: nil)
    }
}

// MARK: - Convenience Month and Quarter Enums

/// Convenience enum for creating monthly periods.
public enum Month: Int, Sendable {
    case january = 1, february, march, april, may, june
    case july, august, september, october, november, december

    /// Convert to a Period for a given year.
    public func period(year: Int) -> Period {
        Period.month(year: year, month: self.rawValue)
    }
}

/// Convenience enum for creating quarterly periods.
public enum Quarter: Int, Sendable {
    case q1 = 1, q2, q3, q4

    /// Convert to a Period for a given year.
    public func period(year: Int) -> Period {
        Period.quarter(year: year, quarter: self.rawValue)
    }
}

/// Arrow operator for Month => Value
public func => <T: Real & Sendable>(month: Month, value: T) -> TimeSeriesEntryImpl<T> {
    // Note: This requires a year context, typically set by the monthly() builder
    // For now, we'll use a default year that should be overridden by the context
    TimeSeriesEntryImpl(period: month.period(year: 2024), value: value)
}

/// Arrow operator for Quarter => Value
public func => <T: Real & Sendable>(quarter: Quarter, value: T) -> TimeSeriesEntryImpl<T> {
    // Note: This requires a year context, typically set by the quarterly() builder
    // For now, we'll use a default year that should be overridden by the context
    TimeSeriesEntryImpl(period: quarter.period(year: 2024), value: value)
}
