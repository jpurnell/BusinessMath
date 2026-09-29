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
///
/// The `Sendable` conformance is unconditional and costs nothing: this is an enum of six
/// cases with no associated values, so it has no storage to protect. It is written out
/// because a `public` enum does not receive the implicit conformance a non-public one would,
/// and without it a caller under strict concurrency cannot send a method across an isolation
/// boundary — into a task group, or into `@Test(arguments:)`, which is where the absence was
/// first noticed.
public enum AggregationMethod: Sendable {
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
	/// ## Labels are carried through unchanged
	///
	/// A label names a **period**, not the value observed in it, and this operation changes no
	/// period: every label the caller supplied is on the result. Before this rule the labels
	/// were dropped, so a caller who named their periods got those names back only for as long
	/// as they never transformed the series — information they had supplied, discarded by an
	/// operation that had no view on it.
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let doubled = timeSeries.mapValues { $0 * 2.0 }
	/// ```
	public func mapValues(_ transform: (T) -> T) -> TimeSeries<T> {
		let newValues = valuesArray.map(transform)
		return carryingLabels(periods: periods, values: newValues)
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
	/// ## Labels follow their own periods
	///
	/// A retained period keeps the label the caller gave it; a period the predicate rejected
	/// takes its label with it. Nothing is reassigned, so a label never appears against a
	/// period other than the one it was written for. A retained period that the caller never
	/// labelled stays unlabelled — ``label(for:)`` answers `nil`, as it did on the source.
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

		return carryingLabels(periods: filteredPeriods, values: filteredValues)
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
	/// ## The receiver's labels, and only the receiver's
	///
	/// Two operands can name the same period differently, and there is no rule that resolves
	/// that disagreement without inventing one — picking the longer string, concatenating
	/// them, or preferring whichever happens to be non-`nil` would all put a name on the
	/// result that neither caller wrote. So the result carries **`self`'s** labels for the
	/// periods it emits, and `other`'s are not consulted. This is the rule the result's
	/// ``metadata`` already follows: the receiver is the series the result inherits
	/// its identity from.
	///
	/// The asymmetry is deliberate and reaches the operators, which are defined in terms of
	/// this method: `a + b` is labelled as `a` is, and `b + a` as `b` is, though the values
	/// agree. If the labels of both operands matter, combine them yourself — the operands are
	/// still in hand, and ``init(data:metadata:labels:)`` takes any map you decide on.
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

		return carryingLabels(periods: resultPeriods, values: resultValues)
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
	/// ## A filled period has no name
	///
	/// Labels are carried for the periods that were **observed** — those present in the
	/// source. A period this call filled gets none: its value was taken from a neighbour, and
	/// that neighbour's label is a name the caller wrote for a different period. Copying it
	/// across would put the caller's own words behind an observation they never made.
	///
	/// The converse does not hold: an absent label does not prove a period was filled, since a
	/// caller may label some periods and not others. Read ``label(for:)`` as "the
	/// name this period was given", never as a coverage flag.
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

		return carryingLabels(periods: nonNilPeriods, values: nonNilValues)
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
	/// ## A filled period has no name
	///
	/// Labels are carried for the periods that were **observed** — those present in the
	/// source. A period this call filled gets none: its value was taken from a neighbour, and
	/// that neighbour's label is a name the caller wrote for a different period. Copying it
	/// across would put the caller's own words behind an observation they never made.
	///
	/// The converse does not hold: an absent label does not prove a period was filled, since a
	/// caller may label some periods and not others. Read ``label(for:)`` as "the
	/// name this period was given", never as a coverage flag.
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

		return carryingLabels(periods: nonNilPeriods, values: nonNilValues)
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
	/// ## A filled period has no name
	///
	/// Labels are carried for the periods that were **observed** — those present in the
	/// source. A period this call filled gets none: the constant is the caller's assumption
	/// about a period nobody measured, and no name was ever written for it. Borrowing a
	/// neighbour's would put the caller's own words behind an observation they never made.
	///
	/// The converse does not hold: an absent label does not prove a period was filled, since a
	/// caller may label some periods and not others. Read ``label(for:)`` as "the
	/// name this period was given", never as a coverage flag.
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

		return carryingLabels(periods: targetPeriods, values: resultValues)
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
	/// ## An interpolated period has no name
	///
	/// Labels are carried for the periods that were **observed** — those present in the
	/// source. A period this call interpolated gets none: its value was computed from the
	/// known points on either side, and either of their labels is a name the caller wrote for
	/// a different period. Copying one across would put the caller's own words behind an
	/// observation they never made.
	///
	/// The converse does not hold: an absent label does not prove a period was interpolated,
	/// since a caller may label some periods and not others. Read ``label(for:)``
	/// as "the name this period was given", never as a coverage flag.
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

		return carryingLabels(periods: resultPeriods, values: resultValues)
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
	/// ## The result carries no labels, deliberately
	///
	/// ``labels`` on the result is always `nil`, whatever the source carried. This
	/// is a decision, not an oversight — every other operation in this file now carries the
	/// caller's labels through, and this one is the exception.
	///
	/// The periods in the result did not exist in the source. A label the caller wrote for
	/// March is a name for March; putting it on Q1 would say they had named the quarter, and
	/// naming the quarter after whichever of its months came first, or last, or happened to be
	/// labelled, is a choice they never made. There is no combining rule either: three month
	/// names do not reduce to a quarter name without writing prose nobody asked for. So the
	/// honest answer is that no label applies, and the result says so by having none.
	///
	/// A caller who wants the aggregate labelled is naming a period they can see in the
	/// result, and can say so directly:
	///
	/// ```swift
	/// let monthly = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
	/// let quarterly = monthly.aggregate(to: .quarterly, method: .sum)
	/// let quarterNames: [String] = quarterly.periods.indices.map { "Reporting quarter \($0 + 1)" }
	/// let named = TimeSeries(
	///     periods: quarterly.periods,
	///     values: quarterly.valuesArray,
	///     metadata: quarterly.metadata,
	///     labels: quarterNames
	/// )
	/// ```
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

		// No `carryingLabels` here, and that is the decision rather than the oversight it looks
		// like. Every other operation in this file carries the caller's labels to the periods
		// they were written for; these periods are new. A name written for March is not a name
		// for Q1, and there is no rule that turns three month names into a quarter name without
		// writing prose the caller never asked for. The result therefore has no labels at all,
		// which is the only honest thing it can say. See the DocC section above.
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

	// MARK: - Label Support

	/// Builds a result series over `resultPeriods`, carrying each period's own label from this
	/// series.
	///
	/// A label is a name the caller wrote for one particular period, so it travels with that
	/// period and with no other. A period that is in the result but was not in the source — one
	/// a fill or an interpolation introduced — is left unnamed rather than given a neighbour's
	/// name, because a neighbour's name is an observation the caller did not make.
	///
	/// - Parameters:
	///   - resultPeriods: The periods of the result, in the order they were produced.
	///   - resultValues: The values of the result, parallel to `resultPeriods`.
	/// - Returns: The result series, labelled where the source labelled the same period.
	private func carryingLabels(periods resultPeriods: [Period], values resultValues: [T]) -> TimeSeries<T> {
		// An unlabelled source has nothing to carry, and this keeps the common case on exactly
		// the initializer it used before labels were carried at all.
		guard let sourceLabels = labels else {
			return TimeSeries(periods: resultPeriods, values: resultValues, metadata: metadata)
		}

		var data: [Period: T] = [:]
		data.reserveCapacity(resultPeriods.count)
		for (period, value) in Swift.zip(resultPeriods, resultValues) {
			data[period] = value
		}

		var kept: [Period: String] = [:]
		kept.reserveCapacity(resultPeriods.count)
		for period in resultPeriods {
			// A period the source never named stays unnamed. The label map is allowed to be
			// partial — ``init(data:metadata:labels:)`` takes any map — so an absent entry is
			// the same "no name was given" it was on the way in, not a new claim.
			guard let label = sourceLabels[period] else { continue }
			kept[period] = label
		}

		// `kept` may be empty, when a labelled series kept only periods it had not named. The
		// empty map is retained rather than folded to `nil`: the caller did supply labels, and
		// `nil` would say they had not. Nothing reads the difference — ``label(for:)`` answers
		// `nil` either way — so this costs nothing and claims less.
		return TimeSeries(data: data, metadata: metadata, labels: kept)
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
