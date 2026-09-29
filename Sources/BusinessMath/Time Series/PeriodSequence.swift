//
//  PeriodSequence.swift
//  BusinessMath
//
//  Multi-period generation with temporal aggregation support.
//

import Foundation
import Numerics

/// Generates sequences of periods with aggregation support.
///
/// `PeriodSequence` provides factory methods for creating regular sequences
/// of periods (monthly, quarterly, annual) and static methods for aggregating
/// finer-grained time series into coarser periods.
///
/// ## Period Generation
///
/// ```swift
/// let periods = Period.documentationQuarters
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
/// let months = (0..<12).map { Period.month(year: 2025, month: $0 + 1) }
/// let monthlyRevenue = TimeSeries(periods: months, values: (0..<12).map { 100.0 + Double($0) })
///
/// // Sum monthly revenue into quarterly totals
/// let quarterly = PeriodSequence.aggregate(
///     monthlyRevenue,
///     to: .quarterly,
///     method: .sum
/// )
/// ```
public struct PeriodSequence: Sequence, Sendable {
    /// The type of element produced by iteration.
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

    /// Returns an iterator over the periods in this sequence.
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
    ///
    /// - Precondition: `end` must not precede `start`.
    public static func monthly(from start: Period, through end: Period) -> PeriodSequence {
        // A mismatch of period types is diagnosed by `PeriodRange` itself, and better than
        // this could; `Period` orders type-first, so testing `start <= end` alone would
        // report a quarterly-to-monthly range as reversed — a wrong diagnosis, sending the
        // caller after a problem they do not have.
        let runsBackwards: Bool = start.type == end.type && end < start

        // Otherwise the caller is told nothing at all: `PeriodRangeIterator` terminates only
        // on `current == end` and steps forward, so a range that starts after it ends never
        // reaches its terminator and `Array(_:)` grows until the process dies. A reversed
        // range is a caller error, and saying so is the one answer that is not a hang.
        guard !runsBackwards else {
            preconditionFailure("""
                PeriodSequence.monthly requires end (\(end.label)) not to precede start \
                (\(start.label)). A reversed range has no periods to walk.
                """)
        }
        return PeriodSequence(Array(start...end))
    }

    /// Generate quarterly periods for a date range.
    ///
    /// - Parameters:
    ///   - fromYear: Start year.
    ///   - fromQuarter: Start quarter (1-4).
    ///   - throughYear: End year.
    ///   - throughQuarter: End quarter (1-4).
    /// - Returns: A sequence of quarterly periods.
    ///
    /// - Precondition: The through-quarter must not precede the from-quarter.
    public static func quarterly(
        fromYear: Int,
        fromQuarter: Int,
        throughYear: Int,
        throughQuarter: Int
    ) -> PeriodSequence {
        let start = Period.quarter(year: fromYear, quarter: fromQuarter)
        let end = Period.quarter(year: throughYear, quarter: throughQuarter)
        // Same reason as `monthly(from:through:)`: without this the caller gets a walk that
        // never terminates rather than a diagnosis of the reversed range they asked for.
        guard start <= end else {
            preconditionFailure("""
                PeriodSequence.quarterly requires \(throughYear)-Q\(throughQuarter) not to \
                precede \(fromYear)-Q\(fromQuarter). A reversed range has no periods to walk.
                """)
        }
        return PeriodSequence(Array(start...end))
    }

    /// Generate semiannual periods for a range of halves.
    ///
    /// - Parameters:
    ///   - fromYear: Start year.
    ///   - fromHalf: Start half (1-2).
    ///   - throughYear: End year.
    ///   - throughHalf: End half (1-2).
    /// - Returns: A sequence of semiannual periods.
    ///
    /// - Precondition: The through-half must not precede the from-half.
    public static func semiannual(
        fromYear: Int,
        fromHalf: Int,
        throughYear: Int,
        throughHalf: Int
    ) -> PeriodSequence {
        let start = Period.semiannual(year: fromYear, half: fromHalf)
        let end = Period.semiannual(year: throughYear, half: throughHalf)
        // Same reason as `monthly(from:through:)`: without this the caller gets a walk that
        // never terminates rather than a diagnosis of the reversed range they asked for.
        guard start <= end else {
            preconditionFailure("""
                PeriodSequence.semiannual requires \(throughYear)-H\(throughHalf) not to \
                precede \(fromYear)-H\(fromHalf). A reversed range has no periods to walk.
                """)
        }
        return PeriodSequence(Array(start...end))
    }

    /// Generate annual periods.
    ///
    /// - Parameters:
    ///   - startYear: First year (inclusive).
    ///   - endYear: Last year (inclusive).
    /// - Returns: A sequence of annual periods.
    ///
    /// - Precondition: `endYear` must not precede `startYear`.
    public static func annual(from startYear: Int, through endYear: Int) -> PeriodSequence {
        // Same reason as `monthly(from:through:)`: without this the caller gets a walk that
        // never terminates rather than a diagnosis of the reversed range they asked for.
        guard startYear <= endYear else {
            preconditionFailure("""
                PeriodSequence.annual requires endYear (\(endYear)) not to precede startYear \
                (\(startYear)). A reversed range has no periods to walk.
                """)
        }
        let start = Period.year(startYear)
        let end = Period.year(endYear)
        return PeriodSequence(Array(start...end))
    }

    // MARK: - Aggregation

    /// Aggregate a time series into coarser periods.
    ///
    /// This is a convenience spelling of ``TimeSeries/aggregate(to:method:)`` and forwards
    /// to it unchanged. It performs no grouping, no coverage test and no reduction of its
    /// own, so the two spellings cannot disagree about the same input.
    ///
    /// That is the whole point of the forwarding. This function used to be a **second,
    /// independent implementation** of the same rule, and the two drifted: the method
    /// emitted only the target periods its data covered end to end, while this one emitted
    /// a quarter built from two months as though it were whole, substituted `0` for six
    /// different "no value" conditions, dropped an unscoreable observation out of `.min`
    /// and `.max`, discarded the caller's metadata, and answered `.custom` with the source
    /// period rather than with nothing. Which answer a caller received depended on which
    /// type they happened to reach for. One rule now has one implementation.
    ///
    /// The behaviour this inherits, in summary — the method's own documentation is the
    /// specification:
    ///
    /// - A target period is emitted **only where the source covers it end to end**. A
    ///   quarter built from two of its three months is left out rather than reported as
    ///   though it were whole. Use ``TimeSeries/fillMissing(with:over:)``,
    ///   ``TimeSeries/fillForward(over:)``, ``TimeSeries/fillBackward(over:)`` or
    ///   ``TimeSeries/interpolate(over:)`` to say in your own code what an unmeasured
    ///   period is worth, and the bucket becomes answerable.
    /// - Coverage is checked for monthly, quarterly and semiannual sources. A **daily**
    ///   source is exempt — weekends and holidays make a sparse calendar the norm, not a
    ///   gap — as are sub-daily sources, a source no finer than the target, and a bucket
    ///   holding more than one source granularity, none of which have a whole-number
    ///   tiling to count against.
    /// - A bucket containing a `nan` aggregates to `nan` under `.sum`, `.average`, `.min`
    ///   and `.max`. `.first` and `.last` answer for the one observation they name.
    /// - Supported targets are `.quarterly`, `.semiannual` and `.annual`. Any other target
    ///   — including `.custom`, which names one specific interval rather than a repeating
    ///   bucket — yields an empty series.
    /// - The source's ``TimeSeries/metadata`` is carried to the result; its
    ///   ``TimeSeries/labels`` deliberately are not, because the result's periods did not
    ///   exist in the source and "March" is not a name for Q1.
    ///
    /// - Parameters:
    ///   - timeSeries: The finer-grained time series to aggregate.
    ///   - targetGranularity: The coarser period type (e.g., `.quarterly` from monthly).
    ///   - method: How to combine values within each target period.
    /// - Returns: A new time series at the target granularity, containing only the periods
    ///   the source covers.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let months = (0..<12).map { Period.month(year: 2025, month: $0 + 1) }
    /// let monthlyRevenue = TimeSeries(periods: months, values: (0..<12).map { 100.0 + Double($0) })
    ///
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
        // Forwarding, not delegating-then-adjusting. Any post-processing here would be the
        // start of a second rule, which is exactly the defect this replaced.
        timeSeries.aggregate(to: targetGranularity, method: method)
    }
}

// AggregationMethod is defined in TimeSeriesOperations.swift
// with cases: .sum, .average, .first, .last, .min, .max
