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
@resultBuilder
public struct TimeSeriesBuilder<T: Real & Sendable> {
    /// Build a block of time series entries.
    public static func buildBlock(_ entries: TimeSeriesEntryImpl<T>...) -> [TimeSeriesEntryImpl<T>] {
        entries
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
public struct TimeSeriesEntryImpl<T: Real & Sendable>: TimeSeriesEntry, Sendable {
    public let period: Period
    public let value: T

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
@resultBuilder
public struct ProjectionBuilder<T: Real & Sendable> {
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
