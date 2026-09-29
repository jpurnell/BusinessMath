//
//  PartialPeriodAggregationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/28/26.
//
//  Phase 3 probe finding §2.1 and §2.2: a genuine gap with no contamination in it. Every
//  value finite and valid, the data merely incomplete — and the result carried no signal
//  that one quarter had been built from two months instead of three.
//
//  The assertion that matters here is the three-way one. A gapped series, a dense control
//  and a zero-filled control must no longer collapse into each other, and the fully covered
//  quarter in the same call must be untouched — that is what proves the change is targeted
//  rather than merely disruptive.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Partial-period aggregation")
struct PartialPeriodAggregationTests {

	// MARK: - Fixtures

	/// January through June 2025.
	let months: [Period] = (1...6).map { Period.month(year: 2025, month: $0) }

	/// Jan 100, Feb 200, Mar 300, Apr 400, May 500, Jun 600.
	let denseValues: [Double] = [100.0, 200.0, 300.0, 400.0, 500.0, 600.0]

	var q1: Period { Period.quarter(year: 2025, quarter: 1) }
	var q2: Period { Period.quarter(year: 2025, quarter: 2) }

	/// Every month measured. Q1 and Q2 are both covered end to end.
	var dense: TimeSeries<Double> {
		TimeSeries(periods: months, values: denseValues)
	}

	/// Months 1, 2, 4, 5, 6 — March was never measured. Q1 is short a month; Q2 is whole.
	var gap: TimeSeries<Double> {
		let observedPeriods: [Period] = [months[0], months[1], months[3], months[4], months[5]]
		let observedValues: [Double] = [100.0, 200.0, 400.0, 500.0, 600.0]
		return TimeSeries(periods: observedPeriods, values: observedValues)
	}

	/// The same six months, with March asserted to have been measured and to have been zero.
	var zeroFilled: TimeSeries<Double> {
		let filledValues: [Double] = [100.0, 200.0, 0.0, 400.0, 500.0, 600.0]
		return TimeSeries(periods: months, values: filledValues)
	}

	// MARK: - The three-way assertion, one method at a time
	//
	// Measured at `cb829637`, with the short quarter still emitted:
	//
	//   method     gap    dense   zeroFilled   what the gap did
	//   .average   150     200       100       a third answer, distinct from both controls
	//   .sum       300     600       300       identical to the zero-filled control
	//   .max       200     300       200       identical to the zero-filled control
	//   .min       100     100         0       identical to the dense control
	//   .first     100     100       100       identical to the dense control
	//   .last      200     300         0
	//
	// and every variant reported two quarters, so the result said nothing about which of
	// them had been built from two months.

	@Test("sum: the short quarter no longer answers as the zero-filled one")
	func sumDiscriminates() throws {
		let fromGap = gap.aggregate(to: .quarterly, method: .sum)
		let fromDense = dense.aggregate(to: .quarterly, method: .sum)
		let fromZeroFilled = zeroFilled.aggregate(to: .quarterly, method: .sum)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 600.0))                 // 100 + 200 + 300

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 300.0))                  // 100 + 200 + 0

		// The old answer for the gap was 300.0 — the zero-filled control exactly. "We did
		// not measure" and "it was zero" arrived as one number.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("average: the partial mean is no longer offered as the quarter's mean")
	func averageDiscriminates() throws {
		let fromGap = gap.aggregate(to: .quarterly, method: .average)
		let fromDense = dense.aggregate(to: .quarterly, method: .average)
		let fromZeroFilled = zeroFilled.aggregate(to: .quarterly, method: .average)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 200.0))                 // (100 + 200 + 300) / 3

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 100.0))                  // (100 + 200 + 0) / 3

		// The old answer for the gap was 150.0 — (100 + 200) / 2, a third number belonging
		// to neither control and reported under the whole quarter's label.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("max: the short quarter no longer answers as the zero-filled one")
	func maxDiscriminates() throws {
		let fromGap = gap.aggregate(to: .quarterly, method: .max)
		let fromDense = dense.aggregate(to: .quarterly, method: .max)
		let fromZeroFilled = zeroFilled.aggregate(to: .quarterly, method: .max)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 300.0))                 // max(100, 200, 300)

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 200.0))                  // max(100, 200, 0)

		// The old answer for the gap was 200.0 — the zero-filled control exactly.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("min: the incompleteness is no longer invisible")
	func minDiscriminates() throws {
		let fromGap = gap.aggregate(to: .quarterly, method: .min)
		let fromDense = dense.aggregate(to: .quarterly, method: .min)
		let fromZeroFilled = zeroFilled.aggregate(to: .quarterly, method: .min)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 100.0))                 // min(100, 200, 300)

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 0.0))                    // min(100, 200, 0)

		// The old answer for the gap was 100.0 — the *dense* control exactly, so a quarter
		// missing a third of its data was indistinguishable from a complete one.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("first: the incompleteness is no longer invisible")
	func firstDiscriminates() throws {
		let fromGap = gap.aggregate(to: .quarterly, method: .first)
		let fromDense = dense.aggregate(to: .quarterly, method: .first)
		let fromZeroFilled = zeroFilled.aggregate(to: .quarterly, method: .first)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 100.0))                 // January

		// `.first` names January in both controls, so the two controls agree here; the
		// discrimination that matters for this method is against the gap, which used to
		// agree with them as well.
		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 100.0))
	}

	@Test("last: the short quarter no longer reports February as March")
	func lastDiscriminates() throws {
		let fromGap = gap.aggregate(to: .quarterly, method: .last)
		let fromDense = dense.aggregate(to: .quarterly, method: .last)
		let fromZeroFilled = zeroFilled.aggregate(to: .quarterly, method: .last)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 300.0))                 // March

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 0.0))                    // March, asserted to be zero

		// The old answer for the gap was 200.0 — February, labelled as the quarter's last.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	// MARK: - The covered quarter is untouched
	//
	// Q2 (April, May, June) is complete in all three variants. If the coverage rule were
	// doing anything broader than declining the unanswerable, it would show here.

	@Test("A fully covered quarter answers identically in all three variants")
	func coveredQuarterIsUnchanged() throws {
		let expectations: [(AggregationMethod, Double)] = [
			(.sum, 1500.0),        // 400 + 500 + 600
			(.average, 500.0),     // 1500 / 3
			(.first, 400.0),       // April
			(.last, 600.0),        // June
			(.min, 400.0),
			(.max, 600.0)
		]

		for (method, expected) in expectations {
			let fromGap: Double = try #require(gap.aggregate(to: .quarterly, method: method)[q2])
			let fromDense: Double = try #require(dense.aggregate(to: .quarterly, method: method)[q2])
			let fromZero: Double = try #require(zeroFilled.aggregate(to: .quarterly, method: method)[q2])

			#expect(fromGap.isEqual(to: expected))
			#expect(fromDense.isEqual(to: expected))
			#expect(fromZero.isEqual(to: expected))
		}
	}

	@Test("The count now distinguishes a gapped series from a dense one")
	func quarterCountsDiffer() {
		let fromGap = gap.aggregate(to: .quarterly, method: .sum)
		let fromDense = dense.aggregate(to: .quarterly, method: .sum)
		let fromZeroFilled = zeroFilled.aggregate(to: .quarterly, method: .sum)

		// All three used to report two quarters.
		#expect(fromGap.count == 1)
		#expect(fromDense.count == 2)
		#expect(fromZeroFilled.count == 2)
	}

	// MARK: - Coarser targets

	@Test("An annual total is not built from eleven months")
	func annualRequiresTwelveMonths() throws {
		let elevenPeriods: [Period] = (1...11).map { Period.month(year: 2025, month: $0) }
		let elevenValues: [Double] = Array(repeating: 100.0, count: 11)
		let eleven = TimeSeries(periods: elevenPeriods, values: elevenValues)

		let twelvePeriods: [Period] = (1...12).map { Period.month(year: 2025, month: $0) }
		let twelveValues: [Double] = Array(repeating: 100.0, count: 12)
		let twelve = TimeSeries(periods: twelvePeriods, values: twelveValues)

		let year = Period.year(2025)

		// 1,100 used to come back under the same label, and with the same shape, as 1,200.
		#expect(!eleven.aggregate(to: .annual, method: .sum).periods.contains(year))
		#expect(eleven.aggregate(to: .annual, method: .sum).count == 0)

		let complete: Double = try #require(twelve.aggregate(to: .annual, method: .sum)[year])
		#expect(complete.isEqual(to: 1200.0))
	}

	@Test("A half needs both of its quarters")
	func semiannualRequiresBothQuarters() throws {
		let threeQuarters: [Period] = (1...3).map { Period.quarter(year: 2025, quarter: $0) }
		let series = TimeSeries(periods: threeQuarters, values: [10.0, 20.0, 30.0])

		let halves = series.aggregate(to: .semiannual, method: .sum)
		let h1 = Period.semiannual(year: 2025, half: 1)
		let h2 = Period.semiannual(year: 2025, half: 2)

		let firstHalf: Double = try #require(halves[h1])
		#expect(firstHalf.isEqual(to: 30.0))               // Q1 + Q2
		#expect(!halves.periods.contains(h2))               // Q4 was never measured
		#expect(halves.count == 1)
	}

	@Test("A daily series is exempt: a sparse calendar is not a gap")
	func dailySourceIsNotCoverageChecked() throws {
		// Five trading days in January. Under a coverage rule applied to daily data this
		// quarter would need all ninety of its days and the result would be empty — which
		// is what a weekday-only price series would get every time. Absence of a day is the
		// norm for daily data, not a missing observation.
		let january = Period.month(year: 2025, month: 1)
		let firstFiveDays: [Period] = Array(january.days().prefix(5))
		#expect(firstFiveDays.count == 5)

		let daily = TimeSeries(periods: firstFiveDays, values: [10.0, 20.0, 30.0, 40.0, 50.0])
		let quarterly = daily.aggregate(to: .quarterly, method: .sum)

		let total: Double = try #require(quarterly[q1])
		#expect(total.isEqual(to: 150.0))
	}

	// MARK: - The caller can still ask the other question

	@Test("Filling the gap makes the quarter answerable again, on the caller's terms")
	func fillingRestoresTheQuarter() throws {
		let assumingZero = gap.fillMissing(with: 0.0, over: months)
									.aggregate(to: .quarterly, method: .sum)
		let carryingForward = gap.fillForward(over: months)
									.aggregate(to: .quarterly, method: .sum)
		let interpolating = gap.interpolate(over: months)
									.aggregate(to: .quarterly, method: .sum)

		// "March was zero": 100 + 200 + 0
		let zeroAnswer: Double = try #require(assumingZero[q1])
		#expect(zeroAnswer.isEqual(to: 300.0))

		// "March was whatever February was": 100 + 200 + 200
		let carriedAnswer: Double = try #require(carryingForward[q1])
		#expect(carriedAnswer.isEqual(to: 500.0))

		// "March sat on the line between February and April": 100 + 200 + 300
		let interpolatedAnswer: Double = try #require(interpolating[q1])
		#expect(interpolatedAnswer.isEqual(to: 600.0))

		// Three defensible answers to the same question, and the caller chose which. That
		// is the whole reason `aggregate` declines to choose one of them silently.
		#expect(!zeroAnswer.isEqual(to: carriedAnswer))
		#expect(!carriedAnswer.isEqual(to: interpolatedAnswer))
	}

	// MARK: - §2.2 Position dependence

	@Test("sum, average, min and max have one footprint wherever the bad datum sat")
	func nanFootprintIsPositionIndependent() throws {
		let methods: [AggregationMethod] = [.sum, .average, .min, .max]

		for method in methods {
			for month in 1...3 {
				let aggregated = denseWithNaN(atMonth: month).aggregate(to: .quarterly, method: method)

				// Q1 contains the unscoreable observation. `.min` and `.max` used to answer
				// a finite number for two of these three placements, because `min()` orders
				// with `<` and every comparison against a nan is false — the observation was
				// dropped from the extremum and nothing in the result said so.
				let poisoned: Double = try #require(aggregated[q1])
				#expect(poisoned.isNaN)

				// Q2 never saw it, and is a real answer.
				let clean: Double = try #require(aggregated[q2])
				#expect(clean.isFinite)
			}
		}
	}

	@Test("first and last answer for the one observation they name")
	func firstAndLastAnswerForTheirOwnObservation() throws {
		// `.first` and `.last` do not aggregate over the bucket; they designate one member
		// of it. Position dependence is the definition of the method here, not a defect, so
		// this pins it rather than changing it.
		let januaryBad = denseWithNaN(atMonth: 1)
		let februaryBad = denseWithNaN(atMonth: 2)
		let marchBad = denseWithNaN(atMonth: 3)

		let firstFromJanuaryBad: Double = try #require(januaryBad.aggregate(to: .quarterly, method: .first)[q1])
		#expect(firstFromJanuaryBad.isNaN)

		let firstFromFebruaryBad: Double = try #require(februaryBad.aggregate(to: .quarterly, method: .first)[q1])
		#expect(firstFromFebruaryBad.isEqual(to: 100.0))

		let lastFromMarchBad: Double = try #require(marchBad.aggregate(to: .quarterly, method: .last)[q1])
		#expect(lastFromMarchBad.isNaN)

		let lastFromFebruaryBad: Double = try #require(februaryBad.aggregate(to: .quarterly, method: .last)[q1])
		#expect(lastFromFebruaryBad.isEqual(to: 300.0))
	}

	@Test("A clean series is unaffected by the nan rule")
	func cleanSeriesKeepsItsExtrema() throws {
		let quarterly = dense.aggregate(to: .quarterly, method: .min)
		let measured: Double = try #require(quarterly[q1])
		#expect(measured.isEqual(to: 100.0))

		let maxima = dense.aggregate(to: .quarterly, method: .max)
		let measuredMax: Double = try #require(maxima[q1])
		#expect(measuredMax.isEqual(to: 300.0))
	}

	// MARK: - filterValues and the §3.5 length invariant

	@Test("filterValues keeps an observation its predicate could not score")
	func filterKeepsUnscoreableRow() throws {
		let february = Period.month(year: 2025, month: 2)
		let series = withUnscoreable

		let positive = series.filterValues { $0 > 0.0 }

		// 100 and 200 pass, -50 genuinely fails, and the nan was never tested at all:
		// `nan > 0` is false for exactly the same reason `nan <= 0` is. It used to be
		// deleted here, and `count` — the thing a caller checks — was the only evidence.
		#expect(positive.count == 3)

		let retained: Double = try #require(positive[february])
		#expect(retained.isNaN)
	}

	@Test("A predicate and its complement between them lose no period")
	func filterPartitionCoversEveryPeriod() {
		let series = withUnscoreable
		let february = Period.month(year: 2025, month: 2)

		let passing = series.filterValues { $0 > 0.0 }
		let failing = series.filterValues { !($0 > 0.0) }

		// The unscoreable row used to appear in neither half of its own partition. It now
		// appears in both, which is the honest answer: the predicate never decided.
		#expect(passing.periods.contains(february))
		#expect(failing.periods.contains(february))

		for period in series.periods {
			let survives: Bool = passing.periods.contains(period) || failing.periods.contains(period)
			#expect(survives)
		}
	}

	@Test("An explicitly unscoreable-seeking predicate still finds it")
	func filterCanStillSelectTheUnscoreable() throws {
		let series = withUnscoreable
		let february = Period.month(year: 2025, month: 2)

		let unusable = series.filterValues { $0.isNaN }

		#expect(unusable.count == 1)
		let onlyValue: Double = try #require(unusable[february])
		#expect(onlyValue.isNaN)
	}

	@Test("Clean data filters exactly as before")
	func filterOnCleanDataIsUnchanged() throws {
		let periods: [Period] = (1...4).map { Period.month(year: 2025, month: $0) }
		let series = TimeSeries(periods: periods, values: [100.0, -20.0, -50.0, 200.0])

		let passing = series.filterValues { $0 > 0.0 }
		let failing = series.filterValues { !($0 > 0.0) }

		#expect(passing.count == 2)
		#expect(failing.count == 2)
		#expect(passing.count + failing.count == series.count)

		let january: Double = try #require(passing[periods[0]])
		#expect(january.isEqual(to: 100.0))
	}

	@Test("Infinities are left to the predicate")
	func filterLeavesInfinitiesToThePredicate() throws {
		let periods: [Period] = (1...3).map { Period.month(year: 2025, month: $0) }
		let series = TimeSeries(periods: periods, values: [100.0, Double.infinity, -Double.infinity])

		let passing = series.filterValues { $0 > 0.0 }

		// `.infinity > 0` is true and `-.infinity > 0` is false, so the partition is intact
		// for them without help. Contract §3.6: an infinity is a legitimate observation.
		#expect(passing.count == 2)
		let unbounded: Double = try #require(passing[periods[1]])
		#expect(unbounded.isInfinite)
		#expect(!passing.periods.contains(periods[2]))
	}

	// MARK: - Duplicate periods collapse on the way in

	@Test("init(validating:) refuses a repeated period")
	func validatingRefusesRepeatedPeriod() throws {
		let january = Period.month(year: 2025, month: 1)
		let february = Period.month(year: 2025, month: 2)
		let periods: [Period] = [january, february, january]
		let values: [Double] = [100.0, 200.0, 300.0]

		do {
			_ = try TimeSeries(validating: periods, values: values)
			Issue.record("Expected a repeated period to be refused, three observations in and two out")
		} catch let error as BusinessMathError {
			guard case .mismatchedDimensions(_, let expected, let actual) = error else {
				Issue.record("Wrong error case: \(error)")
				return
			}
			#expect(expected == "3")
			#expect(actual == "2")
		}
	}

	@Test("init(validating:) accepts unique periods unchanged")
	func validatingAcceptsUniquePeriods() throws {
		let periods: [Period] = (1...3).map { Period.month(year: 2025, month: $0) }
		let values: [Double] = [100.0, 200.0, 300.0]

		let series = try TimeSeries(validating: periods, values: values)

		#expect(series.count == 3)
		let march: Double = try #require(series[periods[2]])
		#expect(march.isEqual(to: 300.0))
	}

	@Test("The non-throwing initializer still collapses a repeat, as its documentation says")
	func nonThrowingInitStillCollapses() throws {
		let january = Period.month(year: 2025, month: 1)
		let february = Period.month(year: 2025, month: 2)
		let series = TimeSeries(periods: [january, february, january], values: [100.0, 200.0, 300.0])

		// Three periods and three values in, two points out, last value wins. This is
		// pinned rather than fixed: the behaviour is documented, narrowing it would be
		// source-breaking, and `init(validating:)` is where a caller who does not already
		// know their periods are unique is told.
		#expect(series.count == 2)
		let januaryValue: Double = try #require(series[january])
		#expect(januaryValue.isEqual(to: 300.0))
	}

	// MARK: - Fixture helpers

	/// The dense six months with one of them replaced by a `nan`.
	private func denseWithNaN(atMonth month: Int) -> TimeSeries<Double> {
		var contaminated: [Double] = denseValues
		contaminated[month - 1] = Double.nan
		return TimeSeries(periods: months, values: contaminated)
	}

	/// 100, nan, -50, 200 over January through April.
	private var withUnscoreable: TimeSeries<Double> {
		let periods: [Period] = (1...4).map { Period.month(year: 2025, month: $0) }
		return TimeSeries(periods: periods, values: [100.0, Double.nan, -50.0, 200.0])
	}
}
