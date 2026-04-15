//
//  PeriodSequence.swift
//  BusinessMath
//
//  Multi-period generation with temporal aggregation support.
//

import Foundation
import RealModule

/// Generates sequences of periods with aggregation support.
///
/// `PeriodSequence` provides factory methods for creating regular sequences
/// of periods (monthly, quarterly, annual) and static methods for aggregating
/// finer-grained time series into coarser periods.
///
/// ## Period Generation
///
/// ```swift
/// // Monthly periods for 2026
/// let months = PeriodSequence.monthly(
///     from: .month(year: 2026, month: 1),
///     through: .month(year: 2026, month: 12)
/// )
/// for month in months { print(month.label) }
/// ```
///
/// ## Temporal Aggregation
///
/// ```swift
/// // Sum monthly revenue into quarterly totals
/// let quarterly = PeriodSequence.aggregate(
///     monthlyRevenue,
///     to: .quarterly,
///     method: .sum
/// )
/// ```
public struct PeriodSequence: Sequence, Sendable {
    public typealias Element = Period

    private let periods: [Period]

    /// Creates a sequence from an array of periods.
    public init(_ periods: [Period]) {
        self.periods = periods.sorted()
    }

    /// Creates a sequence from a `PeriodRange`.
    public init(_ range: PeriodRange) {
        self.periods = Array(range)
    }

    public func makeIterator() -> IndexingIterator<[Period]> {
        periods.makeIterator()
    }

    // MARK: - Factory Methods

    /// Generate monthly periods for a date range.
    ///
    /// - Parameters:
    ///   - start: First month (inclusive).
    ///   - end: Last month (inclusive).
    /// - Returns: A sequence of monthly periods from start through end.
    public static func monthly(from start: Period, through end: Period) -> PeriodSequence {
        PeriodSequence(Array(start...end))
    }

    /// Generate quarterly periods for a date range.
    ///
    /// - Parameters:
    ///   - fromYear: Start year.
    ///   - fromQuarter: Start quarter (1-4).
    ///   - throughYear: End year.
    ///   - throughQuarter: End quarter (1-4).
    /// - Returns: A sequence of quarterly periods.
    public static func quarterly(
        fromYear: Int,
        fromQuarter: Int,
        throughYear: Int,
        throughQuarter: Int
    ) -> PeriodSequence {
        let start = Period.quarter(year: fromYear, quarter: fromQuarter)
        let end = Period.quarter(year: throughYear, quarter: throughQuarter)
        return PeriodSequence(Array(start...end))
    }

    /// Generate annual periods.
    ///
    /// - Parameters:
    ///   - startYear: First year (inclusive).
    ///   - endYear: Last year (inclusive).
    /// - Returns: A sequence of annual periods.
    public static func annual(from startYear: Int, through endYear: Int) -> PeriodSequence {
        let start = Period.year(startYear)
        let end = Period.year(endYear)
        return PeriodSequence(Array(start...end))
    }

    // MARK: - Aggregation

    /// Aggregate a time series into coarser periods.
    ///
    /// Groups values from the source time series into target periods and
    /// applies the specified aggregation method.
    ///
    /// - Parameters:
    ///   - timeSeries: The finer-grained time series to aggregate.
    ///   - targetGranularity: The coarser period type (e.g., `.quarterly` from monthly).
    ///   - method: How to combine values within each target period.
    /// - Returns: A new time series at the target granularity.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Sum monthly revenue into quarterly
    /// let quarterly = PeriodSequence.aggregate(
    ///     monthlyRevenue,
    ///     to: .quarterly,
    ///     method: .sum
    /// )
    /// ```
    public static func aggregate<T: Real & Sendable>(
        _ timeSeries: TimeSeries<T>,
        to targetGranularity: PeriodType,
        method: AggregationMethod
    ) -> TimeSeries<T> where T: Codable {
        // Group source periods into target periods
        var groups: [Period: [(period: Period, value: T)]] = [:]

        for sourcePeriod in timeSeries.periods {
            guard let value = timeSeries[sourcePeriod] else { continue }
            let targetPeriod = mapToTargetPeriod(sourcePeriod, target: targetGranularity)
            groups[targetPeriod, default: []].append((sourcePeriod, value))
        }

        // Apply aggregation method to each group
        var resultValues: [Period: T] = [:]
        for (targetPeriod, entries) in groups {
            guard !entries.isEmpty else { continue }
            let values = entries.map(\.value)

            switch method {
            case .sum:
                resultValues[targetPeriod] = values.reduce(T.zero, +)
            case .average:
                let sum = values.reduce(T.zero, +)
                resultValues[targetPeriod] = sum / T(values.count)
            case .first:
                let sorted = entries.sorted { $0.period < $1.period }
                resultValues[targetPeriod] = sorted.first?.value ?? T.zero
            case .last:
                let sorted = entries.sorted { $0.period < $1.period }
                resultValues[targetPeriod] = sorted.last?.value ?? T.zero
            case .min:
                resultValues[targetPeriod] = values.min() ?? T.zero
            case .max:
                resultValues[targetPeriod] = values.max() ?? T.zero
            }
        }

        return TimeSeries(data: resultValues)
    }

    /// Maps a source period to its containing target period.
    private static func mapToTargetPeriod(_ source: Period, target: PeriodType) -> Period {
        let calendar = Calendar(identifier: .gregorian)
        let componentSet: Set<Calendar.Component> = [.year, .month]
        let components = calendar.dateComponents(componentSet, from: source.date)
        let year = components.year ?? 2000
        let month = components.month ?? 1

        switch target {
        case .quarterly:
            let quarter = (month - 1) / 3 + 1
            return Period.quarter(year: year, quarter: quarter)
        case .annual:
            return Period.year(year)
        default:
            return source
        }
    }
}

// AggregationMethod is defined in TimeSeriesOperations.swift
// with cases: .sum, .average, .first, .last, .min, .max
