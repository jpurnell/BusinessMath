//
//  TimeSeriesOperations.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - AggregationMethod

/// Methods for aggregating time series data to larger periods.
public enum AggregationMethod {
	/// Sum all values in the period.
	case sum

	/// Average all values in the period.
	case average

	/// Take the first value in the period.
	case first

	/// Take the last value in the period.
	case last

	/// Take the minimum value in the period.
	case min

	/// Take the maximum value in the period.
	case max
}

// MARK: - TimeSeries Operations

extension TimeSeries {

	// MARK: - Transformation

	/// Returns a new time series with transformed values.
	///
	/// - Parameter transform: A closure that transforms each value.
	/// - Returns: A new time series with transformed values.
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let doubled = timeSeries.mapValues { $0 * 2.0 }
	/// ```
	public func mapValues(_ transform: (T) -> T) -> TimeSeries<T> {
		let newValues = valuesArray.map(transform)
		return TimeSeries(periods: periods, values: newValues, metadata: metadata)
	}

	/// Returns a new time series containing only values that satisfy the predicate.
	///
	/// - Parameter predicate: A closure that tests each value.
	/// - Returns: A new time series with filtered values.
	///
	/// ## Unscoreable observations are kept
	///
	/// A `nan` observation is **retained whatever the predicate answers**, because the
	/// predicate never answered about it. Every comparison against a `nan` is false, so
	/// `{ $0 > 0 }` and `{ $0 <= 0 }` both reject the same row: the two halves of a
	/// partition together return fewer points than went in, and the difference is invisible.
	/// A caller reading `count` is told the observation was tested and failed, when it was
	/// never tested at all.
	///
	/// This is the contaminated-input contract §3.5 read for a filter. A filter's result is
	/// not indexed against its input, so element-for-element length is not the invariant
	/// here; what must hold is that **no observation leaves without a trace**. A predicate
	/// and its complement must between them cover every period in the series, and before
	/// this rule the unscoreable row appeared in *neither* half of its own partition — a
	/// value the caller supplied was simply gone, and `count`, the thing they would check,
	/// was the only evidence. It now appears in both, which is the honest answer: the
	/// predicate never decided. The retained value needs no separate marker because a `nan`
	/// already is one.
	///
	/// Infinities are left to the predicate. They order correctly — `.infinity > 0` is
	/// `true`, `-.infinity > 0` is `false` — so the partition is intact for them and §3.6
	/// applies: an infinity is a legitimate observation.
	///
	/// To drop unusable rows deliberately, say so rather than relying on a comparison:
	///
	/// ```swift
	/// let series = TimeSeries<Double>(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// var scoreable: [Period: Double] = [:]
	/// for period in series.periods {
	///     guard let value = series[period], !value.isNaN else { continue }
	///     scoreable[period] = value
	/// }
	/// let cleaned = TimeSeries(data: scoreable, metadata: series.metadata)
	/// ```
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let highValues = timeSeries.filterValues { $0 > 100.0 }
	/// ```
	public func filterValues(_ predicate: (T) -> Bool) -> TimeSeries<T> {
		var filteredPeriods: [Period] = []
		var filteredValues: [T] = []

		for period in periods {
			// A period with no value was never in the series; there is nothing to test and
			// nothing to report. This arm cannot fire for a series built by the public
			// initializers, whose periods are the value keys.
			guard let value = self[period] else { continue }

			// Without this the row would be deleted for failing a test it was never given:
			// `nan > 0` is false, and so is `nan <= 0`. The caller would have been told the
			// observation had been examined and rejected.
			let isUnscoreable: Bool = value.isNaN

			if isUnscoreable || predicate(value) {
				filteredPeriods.append(period)
				filteredValues.append(value)
			}
		}

		return TimeSeries(periods: filteredPeriods, values: filteredValues, metadata: metadata)
	}

	// MARK: - Binary Operations

	/// Combines two time series using a binary operation.
	///
	/// Only periods present in both time series are included in the result.
	///
	/// - Parameters:
	///   - other: The other time series to combine with.
	///   - operation: A closure that combines values from both series.
	/// - Returns: A new time series with combined values.
	///
	/// ## Example
	/// ```swift
	/// let ts1 = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let ts2 = TimeSeries(periods: Period.documentationQuarters, values: [10, 20, 30, 40])
	/// let sum = ts1.zip(with: ts2) { $0 + $1 }
	/// let product = ts1.zip(with: ts2) { $0 * $1 }
	/// ```
	public func zip(with other: TimeSeries<T>, _ operation: (T, T) -> T) -> TimeSeries<T> {
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for period in periods {
			if let value1 = self[period], let value2 = other[period] {
				resultPeriods.append(period)
				resultValues.append(operation(value1, value2))
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Missing Value Handling

	/// Fills missing values by propagating the last known value forward.
	///
	/// - Parameter targetPeriods: The complete set of periods to fill.
	/// - Returns: A new time series with forward-filled values.
	///
	/// ## Example
	/// ```swift
	/// let sparseSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let allMonths = (1...12).map { Period.month(year: 2025, month: $0) }
	/// let filled = sparseSeries.fillForward(over: allMonths)
	/// ```
	///
	/// - Note: This is one of the four ways to state, in your own code, what an unmeasured
	///   period is worth. ``aggregate(to:method:)`` will not choose one of them for you: it
	///   omits a target period the data does not cover end to end, so making the coverage
	///   explicit here is how a partial quarter becomes answerable.
	public func fillForward(over targetPeriods: [Period]) -> TimeSeries<T> {
		var resultValues: [T?] = []
		var lastKnownValue: T? = nil

		for period in targetPeriods {
			if let value = self[period] {
				lastKnownValue = value
				resultValues.append(value)
			} else {
				resultValues.append(lastKnownValue)
			}
		}

		let nonNilValues = resultValues.compactMap { $0 }
		let nonNilPeriods = Swift.zip(targetPeriods, resultValues).compactMap { period, value in
			value != nil ? period : nil
		}

		return TimeSeries(periods: nonNilPeriods, values: nonNilValues, metadata: metadata)
	}

	/// Fills missing values by propagating the next known value backward.
	///
	/// - Parameter targetPeriods: The complete set of periods to fill.
	/// - Returns: A new time series with backward-filled values.
	///
	/// ## Example
	/// ```swift
	/// let sparseSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let allMonths = (1...12).map { Period.month(year: 2025, month: $0) }
	/// let filled = sparseSeries.fillBackward(over: allMonths)
	/// ```
	///
	/// - Note: This is one of the four ways to state, in your own code, what an unmeasured
	///   period is worth. ``aggregate(to:method:)`` will not choose one of them for you: it
	///   omits a target period the data does not cover end to end, so making the coverage
	///   explicit here is how a partial quarter becomes answerable.
	public func fillBackward(over targetPeriods: [Period]) -> TimeSeries<T> {
		var resultValues: [T?] = Array(repeating: nil, count: targetPeriods.count)
		var nextKnownValue: T? = nil

		// Iterate backward
		for i in stride(from: targetPeriods.count - 1, through: 0, by: -1) {
			let period = targetPeriods[i]

			if let value = self[period] {
				nextKnownValue = value
				resultValues[i] = value
			} else {
				resultValues[i] = nextKnownValue
			}
		}

		let nonNilValues = resultValues.compactMap { $0 }
		let nonNilPeriods = Swift.zip(targetPeriods, resultValues).compactMap { period, value in
			value != nil ? period : nil
		}

		return TimeSeries(periods: nonNilPeriods, values: nonNilValues, metadata: metadata)
	}

	/// Fills missing values with a constant value.
	///
	/// - Parameters:
	///   - value: The constant value to use for missing periods.
	///   - targetPeriods: The complete set of periods to fill.
	/// - Returns: A new time series with missing values filled.
	///
	/// ## Example
	/// ```swift
	/// let sparseSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let allMonths = Period.documentationQuarters
	/// let filled = sparseSeries.fillMissing(with: 0.0, over: allMonths)
	/// ```
	///
	/// - Note: This is one of the four ways to state, in your own code, what an unmeasured
	///   period is worth. ``aggregate(to:method:)`` will not choose one of them for you: it
	///   omits a target period the data does not cover end to end, so making the coverage
	///   explicit here is how a partial quarter becomes answerable.
	public func fillMissing(with value: T, over targetPeriods: [Period]) -> TimeSeries<T> {
		var resultValues: [T] = []

		for period in targetPeriods {
			if let existingValue = self[period] {
				resultValues.append(existingValue)
			} else {
				resultValues.append(value)
			}
		}

		return TimeSeries(periods: targetPeriods, values: resultValues, metadata: metadata)
	}

	/// Fills missing values using linear interpolation.
	///
	/// Values between known points are estimated using linear interpolation.
	/// Periods outside the range of known values remain nil.
	///
	/// - Parameter targetPeriods: The complete set of periods to interpolate.
	/// - Returns: A new time series with interpolated values.
	///
	/// ## Example
	/// ```swift
	/// let sparseSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let allMonths = Period.documentationQuarters
	/// let interpolated = sparseSeries.interpolate(over: allMonths)
	/// ```
	///
	/// - Note: This is one of the four ways to state, in your own code, what an unmeasured
	///   period is worth. ``aggregate(to:method:)`` will not choose one of them for you: it
	///   omits a target period the data does not cover end to end, so making the coverage
	///   explicit here is how a partial quarter becomes answerable.
	public func interpolate(over targetPeriods: [Period]) -> TimeSeries<T> {
		guard !isEmpty else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		// Find first and last known values
		var firstKnownIndex: Int? = nil
		var lastKnownIndex: Int? = nil

		for (i, period) in targetPeriods.enumerated() {
			if self[period] != nil {
				if firstKnownIndex == nil {
					firstKnownIndex = i
				}
				lastKnownIndex = i
			}
		}

		guard let firstIndex = firstKnownIndex, let lastIndex = lastKnownIndex else {
			return TimeSeries(periods: [], values: [], metadata: metadata)
		}

		// Interpolate between first and last known values
		for i in firstIndex...lastIndex {
			let period = targetPeriods[i]

			if let knownValue = self[period] {
				resultPeriods.append(period)
				resultValues.append(knownValue)
			} else {
				// Find surrounding known values
				var prevIndex = i - 1
				while prevIndex >= firstIndex && self[targetPeriods[prevIndex]] == nil {
					prevIndex -= 1
				}

				var nextIndex = i + 1
				while nextIndex <= lastIndex && self[targetPeriods[nextIndex]] == nil {
					nextIndex += 1
				}

				if prevIndex >= firstIndex && nextIndex <= lastIndex {
					guard let prevValue = self[targetPeriods[prevIndex]],
						  let nextValue = self[targetPeriods[nextIndex]] else { continue }
					let steps = T(nextIndex - prevIndex)
					let position = T(i - prevIndex)
					let fraction = position / steps

					// Linear interpolation
					let interpolated = prevValue + (nextValue - prevValue) * fraction
					resultPeriods.append(period)
					resultValues.append(interpolated)
				}
			}
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Aggregation

	/// Aggregates the time series to a larger period type.
	///
	/// - Parameters:
	///   - targetType: The target period type (must be larger than current).
	///   - method: The aggregation method to use.
	/// - Returns: A new time series with aggregated values.
	///
	/// ## Only covered periods are emitted
	///
	/// A target period appears in the result **only where the data covers it end to end**.
	/// A quarter built from two of its three months, or a year built from eleven of its
	/// twelve, is left out rather than reported as though it were whole. This is the rule
	/// ``zip(with:_:)`` already follows — emit the periods the data actually spans, and
	/// narrow the domain rather than fabricate the observation.
	///
	/// Measured before the rule was applied, a monthly series missing one month returned
	/// four quarters exactly as a dense one did, and the short quarter was indistinguishable
	/// from a complete one in every method: `.average` gave the partial mean under the whole
	/// quarter's label, `.sum` and `.max` agreed digit for digit with a series where the
	/// missing month had been filled with zero — so "we did not measure" and "it was zero"
	/// arrived as one number — and `.min` and `.first` agreed with the dense series, making
	/// the incompleteness invisible.
	///
	/// A caller who wants the partial bucket is asking a different question and can say so,
	/// by making the coverage explicit before aggregating:
	///
	/// ```swift
	/// let months = (1...12).map { Period.month(year: 2025, month: $0) }
	/// let observed = [months[0], months[1], months[3]]
	/// let sparse = TimeSeries(periods: observed, values: [100.0, 110.0, 130.0])
	///
	/// // March was never measured, so Q1 is not answerable and is absent:
	/// let strict = sparse.aggregate(to: .quarterly, method: .sum)
	///
	/// // Say what an unmeasured month is worth, and the quarter becomes answerable:
	/// let assumingZero = sparse.fillMissing(with: 0.0, over: months)
	///                          .aggregate(to: .quarterly, method: .sum)
	/// ```
	///
	/// ``fillMissing(with:over:)``, ``fillForward(over:)``, ``fillBackward(over:)`` and
	/// ``interpolate(over:)`` each state, in the caller's own code, what an unmeasured
	/// period is to be treated as. This function will not choose one of them silently.
	///
	/// Coverage is checked for monthly, quarterly and semiannual sources — the reporting
	/// granularities where a missing period really is a missing observation. A **daily**
	/// source is deliberately exempt: a daily series is routinely and legitimately not dense
	/// (weekends, holidays, non-trading days), so "all ninety days present" is not what a
	/// covered quarter means for one. A sub-daily source, a source no finer than the target,
	/// and a bucket whose members are of mixed period types have no whole-number tiling to
	/// count against either, so all of these are emitted from whatever they contain.
	///
	/// ## Unusable observations
	///
	/// A bucket containing a `nan` aggregates to `nan` under `.sum`, `.average`, `.min` and
	/// `.max`, so the footprint of one bad observation does not depend on where in the
	/// bucket it sat. `.first` and `.last` name one designated observation and answer for
	/// that one only.
	///
	/// ## Example
	/// ```swift
	/// let monthly = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let company = Entity.documentationFixture
	/// // Aggregate monthly to quarterly
	/// let quarterly = monthly.aggregate(to: .quarterly, method: .sum)
	///
	/// // Aggregate monthly to annual
	/// let annual = monthly.aggregate(to: .annual, method: .average)
	///
	/// // Quarterly into halves, for a company moving to semiannual reporting
	/// let halves = quarterly.aggregate(to: .semiannual, method: .sum)
	/// ```
	///
	/// - Note: Supported targets are `.quarterly`, `.semiannual`, and `.annual`.
	///   Any other target — including `.custom`, which names one specific interval
	///   rather than a repeating bucket — yields an empty series.
	public func aggregate(to targetType: PeriodType, method: AggregationMethod) -> TimeSeries<T> {
		// Group periods by their target period, remembering which source granularities
		// landed in each bucket so coverage can be settled before anything is emitted.
		var groups: [Period: [T]] = [:]
		var sourceTypes: [Period: Set<PeriodType>] = [:]

		for period in periods {
			// A period with no value was never an observation. Counting it towards a
			// bucket's coverage would let an absent month vouch for the quarter it is
			// missing from.
			guard let value = self[period] else { continue }

			// A target this period cannot be assigned to is not a bucket at all — the
			// alternative would be inventing a repeating interval the caller never named.
			guard let targetPeriod = Self.bucket(containing: period, for: targetType) else { continue }

			groups[targetPeriod, default: []].append(value)
			sourceTypes[targetPeriod, default: []].insert(period.type)
		}

		// Apply aggregation method to each group
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for (targetPeriod, values) in groups.sorted(by: { $0.key < $1.key }) {
			// An empty bucket is never inserted above, so this cannot fire; were it to, the
			// alternative is an aggregate of nothing presented as a measurement.
			guard !values.isEmpty else { continue }

			// Narrow the domain (contaminated-input contract §3.7): an aggregate over a
			// period the data does not cover is not answerable. Without this the caller is
			// handed a short quarter under the same label, and the same shape, as a
			// complete one — and an annual total built from eleven months that no field of
			// the result distinguishes from one built from twelve.
			let observed: Set<PeriodType> = sourceTypes[targetPeriod] ?? []
			guard covers(targetPeriod, sourceTypes: observed) else { continue }

			resultPeriods.append(targetPeriod)
			resultValues.append(Self.combine(values, using: method))
		}

		return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
	}

	// MARK: - Aggregation Support

	/// Whether the series spans `targetPeriod` end to end at the granularity it was observed at.
	///
	/// - Parameters:
	///   - targetPeriod: The bucket being considered for emission.
	///   - sourceTypes: The period types of the observations that landed in that bucket.
	/// - Returns: `true` when every constituent period is present, or when the pair has no
	///   whole-number tiling to check against.
	private func covers(_ targetPeriod: Period, sourceTypes: Set<PeriodType>) -> Bool {
		// One granularity per bucket is the only case with a whole-number tiling. A bucket
		// holding both months and quarters has no count that means "complete", and answering
		// `false` there would withhold a period for a reason the caller was never given.
		guard sourceTypes.count == 1, let sourceType = sourceTypes.first else { return true }

		// No tiling exists, so "covered" is not a property of this pair. Answering `false`
		// would tell the caller the data is incomplete when nothing was measured about that.
		guard let required = Self.constituents(of: targetPeriod, at: sourceType) else { return true }

		return required.allSatisfy { self[$0] != nil }
	}

	/// The periods of `sourceType` that tile `targetPeriod`.
	///
	/// - Returns: The constituent periods, or `nil` where no whole-number tiling exists.
	private static func constituents(of targetPeriod: Period, at sourceType: PeriodType) -> [Period]? {
		let parts: [Period]

		switch sourceType {
		case .monthly:
			parts = targetPeriod.months()

		case .quarterly:
			parts = targetPeriod.quarters()

		case .semiannual:
			parts = targetPeriod.semiannuals()

		case .daily:
			// Deliberately unchecked. A daily series is routinely and legitimately not dense
			// — weekends, holidays, non-trading days — so "all 90 days present" is not what
			// a covered quarter means for one, and imposing it would return an empty series
			// for the commonest daily data there is. The reporting granularities above are
			// the ones where a missing period really is a missing observation.
			return nil

		case .millisecond, .second, .minute, .hourly, .annual, .custom:
			// `Period` enumerates exactly four subdivisions, and a quarter's milliseconds are
			// not a list anyone wants built. An `annual` or `custom` source is not finer than
			// any supported target, so it has no tiling either.
			return nil
		}

		// An empty subdivision means the granularities do not nest — a monthly target has no
		// whole quarters in it. Reporting that as "not covered" would drop every such bucket.
		return parts.isEmpty ? nil : parts
	}

	/// The target period a source period belongs to, or `nil` when the target is not a
	/// repeating bucket this series can be coarsened into.
	private static func bucket(containing period: Period, for targetType: PeriodType) -> Period? {
		let calendar = gregorianUTC

		switch targetType {
		case .quarterly:
			// Map month to quarter
			let components = calendar.dateComponents([.year, .month], from: period.startDate)
			let quarter = ((components.month ?? 1) - 1) / 3 + 1
			return Period.quarter(year: components.year ?? 0, quarter: quarter)

		case .semiannual:
			// Map month to half of the year
			let components = calendar.dateComponents([.year, .month], from: period.startDate)
			let half = ((components.month ?? 1) - 1) / 6 + 1
			return Period.semiannual(year: components.year ?? 0, half: half)

		case .annual:
			// Map any period to year
			let calendarYear = calendar.component(.year, from: period.startDate)
			return Period.year(calendarYear)

		case .custom:
			// There is no rule that groups periods into an arbitrary range: a custom
			// target names one specific interval, not a repeating bucket. Nothing is
			// emitted, matching the existing behaviour for non-coarsening targets.
			return nil

		case .millisecond, .second, .minute, .hourly, .daily, .monthly:
			// Can't aggregate to smaller or same period type
			return nil
		}
	}

	/// Reduces one bucket's observations to a single value.
	private static func combine(_ values: [T], using method: AggregationMethod) -> T {
		// The caller drops empty buckets before reaching here. Were one to arrive, `0` would
		// be an aggregate of nothing presented as a measurement — the zero-as-sentinel the
		// contract forbids — so the answer is that there is no answer.
		guard let firstValue = values.first else { return T.nan }

		switch method {
		case .sum:
			return values.reduce(T.zero, +)

		case .average:
			let total: T = values.reduce(T.zero, +)
			let observations: T = T(values.count)
			return total / observations

		case .first:
			return firstValue

		case .last:
			return values.last ?? firstValue

		case .min:
			// `min()` orders with `<`, and every comparison against a `nan` is false, so an
			// unscoreable observation is skipped rather than reported. The caller would have
			// been handed the smallest of the values that happened to compare — an extremum
			// over a subset nothing in the result mentions — and the number of quarters
			// affected would depend on where in the bucket the bad datum sat.
			let unscoreable: Bool = values.contains { $0.isNaN }
			let smallest: T = values.min() ?? firstValue
			return unscoreable ? T.nan : smallest

		case .max:
			// Same mechanism as `.min`: a skipped `nan` turns "one observation is unusable"
			// into a confident maximum drawn from the rest of the bucket.
			let unscoreable: Bool = values.contains { $0.isNaN }
			let largest: T = values.max() ?? firstValue
			return unscoreable ? T.nan : largest
		}
	}
}

// MARK: - Arithmetic Operators

/// Adds two time series element-wise.
///
/// Only periods present in both series are included in the result.
///
/// ## Example
/// ```swift
/// let ts1 = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
/// let ts2 = TimeSeries(periods: Period.documentationQuarters, values: [10, 20, 30, 40])
/// let revenue = ts1 + ts2
/// ```
public func + <T: Real & Sendable>(lhs: TimeSeries<T>, rhs: TimeSeries<T>) -> TimeSeries<T> {
	return lhs.zip(with: rhs, +)
}

/// Subtracts one time series from another element-wise.
///
/// Only periods present in both series are included in the result.
///
/// ## Example
/// ```swift
/// let expenses = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
/// // `revenue` without a binding resolves to a library function of that name.
/// let revenue = TimeSeries(periods: Period.documentationQuarters, values: [300, 320, 340, 360])
/// let netIncome = revenue - expenses
/// ```
public func - <T: Real & Sendable>(lhs: TimeSeries<T>, rhs: TimeSeries<T>) -> TimeSeries<T> {
	return lhs.zip(with: rhs, -)
}

/// Multiplies two time series element-wise.
///
/// Only periods present in both series are included in the result.
///
/// ## Example
/// ```swift
/// let quantity = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
/// let price = TimeSeries(periods: Period.documentationQuarters, values: [5, 5, 6, 6])
/// let total = quantity * price
/// ```
public func * <T: Real & Sendable>(lhs: TimeSeries<T>, rhs: TimeSeries<T>) -> TimeSeries<T> {
	return lhs.zip(with: rhs, *)
}

/// Divides one time series by another element-wise.
///
/// Only periods present in both series are included in the result.
///
/// ## Example
/// ```swift
/// let profit = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
/// let revenue = TimeSeries(periods: Period.documentationQuarters, values: [300, 320, 340, 360])
/// let margin = profit / revenue
/// ```
public func / <T: Real & Sendable>(lhs: TimeSeries<T>, rhs: TimeSeries<T>) -> TimeSeries<T> {
	return lhs.zip(with: rhs, /)
}
