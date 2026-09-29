//
//  TimeSeriesLabelPreservationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/28/26.
//
//  Every operation in `TimeSeriesOperations.swift` used to rebuild its result with
//  `labels: nil`, so a caller who named their periods got those names back only for as long
//  as they never transformed the series. Nothing was *claimed* — this is the quiet half of
//  the contaminated-input family: information the caller supplied, discarded by an operation
//  that had no view on it.
//
//  The decisions this file pins:
//
//    operation      labels on the result                        why
//    mapValues      all of them                                 no period changed
//    filterValues   those of the periods that survived          a label travels with its period
//    zip            the receiver's, for the emitted periods     `other`'s are not consulted
//    fill family    those of the periods actually observed      a filled period was never named
//    aggregate      none, deliberately                          the periods are new
//
//  The aggregate case is asserted rather than left silent on purpose. A deliberate omission
//  and an accidental one look identical in the code, and the next reader to notice that
//  quarters come back unlabelled should find a test saying so before they "fix" it.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Time series label preservation")
struct TimeSeriesLabelPreservationTests {

	// MARK: - Fixtures

	/// January through June 2025.
	let months: [Period] = (1...6).map { Period.month(year: 2025, month: $0) }

	/// Jan 100, Feb 200, Mar 300, Apr 400, May 500, Jun 600.
	let denseValues: [Double] = [100.0, 200.0, 300.0, 400.0, 500.0, 600.0]

	let monthNames: [String] = ["January", "February", "March", "April", "May", "June"]

	/// Six labelled months.
	var labelled: TimeSeries<Double> {
		TimeSeries(periods: months, values: denseValues, labels: monthNames)
	}

	/// The same six months with no labels at all.
	var unlabelled: TimeSeries<Double> {
		TimeSeries(periods: months, values: denseValues)
	}

	/// The names carried by a series, in its own period order, skipping any period it did not name.
	func names(of series: TimeSeries<Double>) -> [String] {
		series.periods.compactMap { series.label(for: $0) }
	}

	// MARK: - Value-wise transforms

	@Test("mapValues changes no period, so it keeps every label")
	func mapValuesKeepsEveryLabel() {
		let doubled = labelled.mapValues { $0 * 2.0 }

		#expect(names(of: doubled) == monthNames)
		#expect(doubled.periods == months)

		// The values really were transformed — the labels are not surviving because nothing
		// happened.
		let january: Double = doubled[months[0]] ?? .nan
		#expect(january.isEqual(to: 200.0))
	}

	@Test("An unlabelled series stays unlabelled through mapValues")
	func mapValuesInventsNoLabels() {
		let doubled = unlabelled.mapValues { $0 * 2.0 }
		let carried: [Period: String]? = doubled.labels

		#expect(carried == nil)
		#expect(names(of: doubled).isEmpty)
	}

	@Test("filterValues keeps the labels of the periods that survived, and only those")
	func filterValuesKeepsSurvivingLabels() {
		// Keeps April, May, June; drops January, February, March.
		let high = labelled.filterValues { $0 > 300.0 }

		#expect(high.periods == [months[3], months[4], months[5]])
		#expect(names(of: high) == ["April", "May", "June"])

		// A dropped period takes its name with it rather than leaving it behind on a
		// neighbour.
		let januaryName: String? = high.label(for: months[0])
		#expect(januaryName == nil)
	}

	@Test("A retained unscoreable row keeps its own label")
	func filterValuesKeepsTheLabelOfTheRowItCouldNotScore() {
		// March is unscoreable, so `filterValues` retains it whatever the predicate answers.
		// It must come back under its own name, not under a neighbour's and not anonymous.
		let contaminated: [Double] = [100.0, 200.0, .nan, 400.0, 500.0, 600.0]
		let series = TimeSeries(periods: months, values: contaminated, labels: monthNames)

		let high = series.filterValues { $0 > 300.0 }

		#expect(high.periods == [months[2], months[3], months[4], months[5]])
		#expect(names(of: high) == ["March", "April", "May", "June"])

		let marchValue: Double = high[months[2]] ?? 0.0
		#expect(marchValue.isNaN)
	}

	// MARK: - Binary operations

	@Test("zip carries the receiver's labels and does not consult the other operand's")
	func zipCarriesTheReceiversLabels() {
		let otherNames: [String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
		let other = TimeSeries(periods: months, values: denseValues, labels: otherNames)

		let leftFirst = labelled.zip(with: other, +)
		#expect(names(of: leftFirst) == monthNames)

		// The asymmetry is the decision, so it is asserted in both directions: there is no
		// merge rule, and the result is named by whichever series the call was made on.
		let rightFirst = other.zip(with: labelled, +)
		#expect(names(of: rightFirst) == otherNames)
	}

	@Test("zip emits only the shared periods, and labels only those")
	func zipLabelsOnlyTheSharedPeriods() {
		// April, May and June only.
		let laterPeriods: [Period] = [months[3], months[4], months[5]]
		let laterValues: [Double] = [10.0, 20.0, 30.0]
		let later = TimeSeries(periods: laterPeriods, values: laterValues)

		let combined = labelled.zip(with: later, +)

		#expect(combined.periods == laterPeriods)
		#expect(names(of: combined) == ["April", "May", "June"])

		let januaryName: String? = combined.label(for: months[0])
		#expect(januaryName == nil)
	}

	@Test("The arithmetic operators inherit the left operand's labels")
	func operatorsInheritTheLeftOperandsLabels() {
		let otherNames: [String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
		let other = TimeSeries(periods: months, values: denseValues, labels: otherNames)

		// The operators are defined in terms of `zip`, so `a + b` is labelled as `a` is.
		#expect(names(of: labelled + other) == monthNames)
		#expect(names(of: other + labelled) == otherNames)
	}

	// MARK: - The fill family
	//
	// In each of these the source holds January and March; February is introduced by the call.
	// February's value came from a neighbour, and a neighbour's label is a name the caller
	// wrote for a different period, so February must come back unnamed.

	/// January (100) and March (300), labelled. February was never measured.
	var gapped: TimeSeries<Double> {
		let observedPeriods: [Period] = [months[0], months[2]]
		let observedValues: [Double] = [100.0, 300.0]
		let observedNames: [String] = ["January", "March"]
		return TimeSeries(periods: observedPeriods, values: observedValues, labels: observedNames)
	}

	/// January, February, March.
	var firstQuarterMonths: [Period] { [months[0], months[1], months[2]] }

	@Test("fillForward names the observed periods and leaves the filled one unnamed")
	func fillForwardLeavesTheFilledPeriodUnnamed() {
		let filled = gapped.fillForward(over: firstQuarterMonths)

		#expect(filled.periods == firstQuarterMonths)
		#expect(names(of: filled) == ["January", "March"])

		// February carries January's *value* — that is what a forward fill is — but it must
		// not carry January's *name*.
		let februaryValue: Double = filled[months[1]] ?? .nan
		#expect(februaryValue.isEqual(to: 100.0))

		let februaryName: String? = filled.label(for: months[1])
		#expect(februaryName == nil)
	}

	@Test("fillBackward names the observed periods and leaves the filled one unnamed")
	func fillBackwardLeavesTheFilledPeriodUnnamed() {
		let filled = gapped.fillBackward(over: firstQuarterMonths)

		#expect(filled.periods == firstQuarterMonths)
		#expect(names(of: filled) == ["January", "March"])

		let februaryValue: Double = filled[months[1]] ?? .nan
		#expect(februaryValue.isEqual(to: 300.0))

		let februaryName: String? = filled.label(for: months[1])
		#expect(februaryName == nil)
	}

	@Test("fillMissing names the observed periods and leaves the constant one unnamed")
	func fillMissingLeavesTheFilledPeriodUnnamed() {
		let filled = gapped.fillMissing(with: 0.0, over: firstQuarterMonths)

		#expect(filled.periods == firstQuarterMonths)
		#expect(names(of: filled) == ["January", "March"])

		// The constant is the caller's assumption about a period nobody measured; no name was
		// ever written for it.
		let februaryValue: Double = filled[months[1]] ?? .nan
		#expect(februaryValue.isEqual(to: 0.0))

		let februaryName: String? = filled.label(for: months[1])
		#expect(februaryName == nil)
	}

	@Test("interpolate names the known points and leaves the estimated one unnamed")
	func interpolateLeavesTheEstimatedPeriodUnnamed() {
		let interpolated = gapped.interpolate(over: firstQuarterMonths)

		#expect(interpolated.periods == firstQuarterMonths)
		#expect(names(of: interpolated) == ["January", "March"])

		// Halfway between 100 and 300.
		let februaryValue: Double = interpolated[months[1]] ?? .nan
		#expect(februaryValue.isEqual(to: 200.0))

		let februaryName: String? = interpolated.label(for: months[1])
		#expect(februaryName == nil)
	}

	// MARK: - Aggregation

	@Test("aggregate carries no labels, deliberately")
	func aggregateCarriesNoLabels() {
		// January, February and March are all present, so Q1 is covered end to end and is
		// emitted. The question here is only what it is called.
		let quarterly = labelled.aggregate(to: .quarterly, method: .sum)

		let q1 = Period.quarter(year: 2025, quarter: 1)
		#expect(quarterly.periods.contains(q1))

		let total: Double = quarterly[q1] ?? .nan
		#expect(total.isEqual(to: 600.0))

		// This is the decision, not an oversight. A name written for March is not a name for
		// Q1, and there is no rule that reduces three month names to a quarter name without
		// inventing one. The result says so by carrying nothing at all.
		let carried: [Period: String]? = quarterly.labels
		#expect(carried == nil)
		#expect(names(of: quarterly).isEmpty)
	}

	@Test("aggregate carries no labels even when the source period and the target coincide")
	func aggregateCarriesNoLabelsForAnUnchangedBoundary() {
		// A quarterly source aggregated to annual: the boundary months line up exactly, which
		// is the case where borrowing a constituent's name would look most defensible. It is
		// still a different period, so it is still unnamed.
		let quarters: [Period] = (1...4).map { Period.quarter(year: 2025, quarter: $0) }
		let quarterValues: [Double] = [100.0, 200.0, 300.0, 400.0]
		let quarterNames: [String] = ["Q1", "Q2", "Q3", "Q4"]
		let series = TimeSeries(periods: quarters, values: quarterValues, labels: quarterNames)

		let annual = series.aggregate(to: .annual, method: .sum)

		let year = Period.year(2025)
		let total: Double = annual[year] ?? .nan
		#expect(total.isEqual(to: 1000.0))

		let carried: [Period: String]? = annual.labels
		#expect(carried == nil)
	}

	// MARK: - AggregationMethod is Sendable

	/// Every case of the enum, hoisted out of the `@Test` macro rather than written as a
	/// literal inside `arguments:` — the macro expands its argument into generic closures, and
	/// this project has already lost a CI run to a literal array that was fine as a plain `let`.
	static let everyMethod: [AggregationMethod] = [.sum, .average, .first, .last, .min, .max]

	@Test("AggregationMethod crosses an isolation boundary",
		  arguments: TimeSeriesLabelPreservationTests.everyMethod)
	func aggregationMethodIsSendable(method: AggregationMethod) {
		// `@Test(arguments:)` requires `Sendable`, so this test compiling is the assertion
		// about the conformance. The body pins that a fully covered quarter answers under
		// every method, which is what the argument is for.
		let quarterly = labelled.aggregate(to: .quarterly, method: method)
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let answer: Double = quarterly[q1] ?? .nan
		#expect(answer.isFinite)
	}
}
