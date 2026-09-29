//
//  PeriodSequenceAggregationTests.swift
//  BusinessMath
//
//  `PeriodSequence.aggregate(_:to:method:)` was a second, independent implementation of the
//  rule `TimeSeries.aggregate(to:method:)` implements. The sibling was fixed; this one was
//  not, so for a while the answer a caller got depended on which type they reached for —
//  which is worse than neither being fixed.
//
//  The assertion this file exists for is the first one: **agreement**. For the same input,
//  the two spellings must return the same periods and the same values, across every method
//  and every target. That is the property whose absence created the defect, and it is the
//  one worth defending against a future edit to either side. The rest of the file pins the
//  behaviour the static spelling now inherits, mirroring `PartialPeriodAggregationTests`.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("PeriodSequence.aggregate agrees with TimeSeries.aggregate")
struct PeriodSequenceAggregationTests {

	// MARK: - Comparison helper
	//
	// Never `==` on `[Double]`. Two unscoreable values are treated as agreeing: a `nan` on
	// both sides is the two implementations giving the same answer, and `nan == nan` is
	// false, so an equality test would report a disagreement that is not there.

	private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
		guard lhs.count == rhs.count else { return false }
		for (left, right) in Swift.zip(lhs, rhs) {
			let bothUnscoreable: Bool = left.isNaN && right.isNaN
			let same: Bool = left.isEqual(to: right)
			if !bothUnscoreable && !same { return false }
		}
		return true
	}

	// MARK: - Fixtures

	/// January through June 2025.
	var months: [Period] { (1...6).map { Period.month(year: 2025, month: $0) } }

	var q1: Period { Period.quarter(year: 2025, quarter: 1) }
	var q2: Period { Period.quarter(year: 2025, quarter: 2) }
	var h1: Period { Period.semiannual(year: 2025, half: 1) }

	/// Jan 100 … Jun 600. Q1 and Q2 both covered end to end.
	var dense: TimeSeries<Double> {
		TimeSeries(periods: months, values: [100.0, 200.0, 300.0, 400.0, 500.0, 600.0])
	}

	/// Months 1, 2, 4, 5, 6 — March was never measured. Q1 is short a month; Q2 is whole.
	var gap: TimeSeries<Double> {
		let observed: [Period] = [months[0], months[1], months[3], months[4], months[5]]
		return TimeSeries(periods: observed, values: [100.0, 200.0, 400.0, 500.0, 600.0])
	}

	/// The same six months, with March asserted to have been measured and to have been zero.
	var zeroFilled: TimeSeries<Double> {
		TimeSeries(periods: months, values: [100.0, 200.0, 0.0, 400.0, 500.0, 600.0])
	}

	/// Dense, but February is unscoreable.
	var withUnscoreable: TimeSeries<Double> {
		TimeSeries(periods: months, values: [100.0, Double.nan, 300.0, 400.0, 500.0, 600.0])
	}

	/// Five trading days in January — a sparse calendar, not a gap.
	var sparseDaily: TimeSeries<Double> {
		let january = Period.month(year: 2025, month: 1)
		let tradingDays: [Period] = Array(january.days().prefix(5))
		return TimeSeries(periods: tradingDays, values: [10.0, 20.0, 30.0, 40.0, 50.0])
	}

	/// Q1 and Q2 2025 — a quarterly source, so H1 is covered and H2 is not.
	var quarterlySource: TimeSeries<Double> {
		let quarters: [Period] = [q1, q2]
		return TimeSeries(periods: quarters, values: [1000.0, 2000.0])
	}

	/// Dense, and carrying both metadata and a label on every month.
	var labelledAndDescribed: TimeSeries<Double> {
		let descriptions = TimeSeriesMetadata(name: "Revenue", description: "FY2025", unit: "USD")
		let names: [String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
		return TimeSeries(
			periods: months,
			values: [100.0, 200.0, 300.0, 400.0, 500.0, 600.0],
			metadata: descriptions,
			labels: names
		)
	}

	var everyFixture: [(name: String, series: TimeSeries<Double>)] {
		[
			("dense", dense),
			("gap", gap),
			("zeroFilled", zeroFilled),
			("withUnscoreable", withUnscoreable),
			("sparseDaily", sparseDaily),
			("quarterlySource", quarterlySource),
			("labelledAndDescribed", labelledAndDescribed)
		]
	}

	var everyMethod: [AggregationMethod] { [.sum, .average, .first, .last, .min, .max] }

	var everyTarget: [PeriodType] {
		// Both the supported coarsenings and the ones that must yield nothing. `.custom` is
		// where the two implementations used to disagree outright: the static spelling
		// returned the source periods unchanged, the method returned an empty series.
		[.quarterly, .semiannual, .annual, .monthly, .daily, .custom]
	}

	// MARK: - The assertion this file exists for

	@Test("Both spellings return the same periods and the same values, for every method and target")
	func theTwoSpellingsAgree() {
		for fixture in everyFixture {
			for target in everyTarget {
				for method in everyMethod {
					let viaStatic = PeriodSequence.aggregate(fixture.series, to: target, method: method)
					let viaMethod = fixture.series.aggregate(to: target, method: method)

					#expect(
						viaStatic.periods == viaMethod.periods,
						"periods disagree for \(fixture.name) → \(target) by \(method)"
					)

					let valuesAgree: Bool = agree(viaStatic.valuesArray, viaMethod.valuesArray)
					#expect(valuesAgree, "values disagree for \(fixture.name) → \(target) by \(method)")
				}
			}
		}
	}

	@Test("Both spellings carry the same metadata, and neither invents a label")
	func theTwoSpellingsAgreeOnMetadataAndLabels() {
		let source = labelledAndDescribed

		for method in everyMethod {
			let viaStatic = PeriodSequence.aggregate(source, to: .quarterly, method: method)
			let viaMethod = source.aggregate(to: .quarterly, method: method)

			// The static spelling used to build `TimeSeries(data:)` with neither argument,
			// so the caller's "Revenue / FY2025 / USD" was discarded by the aggregation.
			#expect(viaStatic.metadata == viaMethod.metadata)
			#expect(viaStatic.metadata.name == "Revenue")
			#expect(viaStatic.metadata.unit == "USD")

			// Neither spelling labels the result: "March" is not a name for Q1, and there is
			// no rule that turns three month names into a quarter name. `compactMap` rather
			// than a nil test, so what is asserted is the absence of any carried name.
			let staticNames: [String] = viaStatic.periods.compactMap { viaStatic.label(for: $0) }
			let methodNames: [String] = viaMethod.periods.compactMap { viaMethod.label(for: $0) }
			#expect(staticNames.isEmpty)
			#expect(methodNames.isEmpty)
		}
	}

	// MARK: - §2.1 The three-way case, through the static spelling
	//
	// Measured before the fix, with the short quarter still emitted:
	//
	//   method     gap    dense   zeroFilled   what the gap did
	//   .average   150     200       100       a third answer, distinct from both controls
	//   .sum       300     600       300       identical to the zero-filled control
	//   .max       200     300       200       identical to the zero-filled control
	//   .min       100     100         0       identical to the dense control
	//   .first     100     100       100       identical to the dense control
	//   .last      200     300         0
	//
	// and all three reported two quarters, so nothing in the result said which of them had
	// been built from two months.

	@Test("sum: the short quarter no longer answers as the zero-filled one")
	func sumDiscriminates() throws {
		let fromGap = PeriodSequence.aggregate(gap, to: .quarterly, method: .sum)
		let fromDense = PeriodSequence.aggregate(dense, to: .quarterly, method: .sum)
		let fromZeroFilled = PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: .sum)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 600.0))                 // 100 + 200 + 300

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 300.0))                  // 100 + 200 + 0

		// The old answer for the gap was 300.0 — the zero-filled control exactly.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("average: the partial mean is no longer offered as the quarter's mean")
	func averageDiscriminates() throws {
		let fromGap = PeriodSequence.aggregate(gap, to: .quarterly, method: .average)
		let fromDense = PeriodSequence.aggregate(dense, to: .quarterly, method: .average)
		let fromZeroFilled = PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: .average)

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
		let fromGap = PeriodSequence.aggregate(gap, to: .quarterly, method: .max)
		let fromDense = PeriodSequence.aggregate(dense, to: .quarterly, method: .max)
		let fromZeroFilled = PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: .max)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 300.0))                 // max(100, 200, 300)

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 200.0))                  // max(100, 200, 0)

		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("min: the incompleteness is no longer invisible")
	func minDiscriminates() throws {
		let fromGap = PeriodSequence.aggregate(gap, to: .quarterly, method: .min)
		let fromDense = PeriodSequence.aggregate(dense, to: .quarterly, method: .min)
		let fromZeroFilled = PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: .min)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 100.0))                 // min(100, 200, 300)

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 0.0))                    // min(100, 200, 0)

		// The old answer for the gap was 100.0 — the *dense* control exactly.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("first: the incompleteness is no longer invisible")
	func firstDiscriminates() throws {
		let fromGap = PeriodSequence.aggregate(gap, to: .quarterly, method: .first)
		let fromDense = PeriodSequence.aggregate(dense, to: .quarterly, method: .first)
		let fromZeroFilled = PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: .first)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 100.0))                 // January

		// The two controls agree under `.first`; the discrimination that matters here is
		// against the gap, which used to agree with them as well.
		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 100.0))
	}

	@Test("last: the short quarter no longer reports February as March")
	func lastDiscriminates() throws {
		let fromGap = PeriodSequence.aggregate(gap, to: .quarterly, method: .last)
		let fromDense = PeriodSequence.aggregate(dense, to: .quarterly, method: .last)
		let fromZeroFilled = PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: .last)

		#expect(!fromGap.periods.contains(q1))

		let denseQ1: Double = try #require(fromDense[q1])
		#expect(denseQ1.isEqual(to: 300.0))                 // March

		let zeroQ1: Double = try #require(fromZeroFilled[q1])
		#expect(zeroQ1.isEqual(to: 0.0))                    // March, asserted to be zero

		// The old answer for the gap was 200.0 — February, labelled as the quarter's last.
		#expect(!denseQ1.isEqual(to: zeroQ1))
	}

	@Test("The count now distinguishes a gapped series from a dense one")
	func quarterCountsDiffer() {
		let fromGap = PeriodSequence.aggregate(gap, to: .quarterly, method: .sum)
		let fromDense = PeriodSequence.aggregate(dense, to: .quarterly, method: .sum)
		let fromZeroFilled = PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: .sum)

		// All three used to report two quarters.
		#expect(fromGap.count == 1)
		#expect(fromDense.count == 2)
		#expect(fromZeroFilled.count == 2)
	}

	// MARK: - The covered control
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
			let fromGap: Double = try #require(PeriodSequence.aggregate(gap, to: .quarterly, method: method)[q2])
			let fromDense: Double = try #require(PeriodSequence.aggregate(dense, to: .quarterly, method: method)[q2])
			let fromZero: Double = try #require(PeriodSequence.aggregate(zeroFilled, to: .quarterly, method: method)[q2])

			#expect(fromGap.isEqual(to: expected))
			#expect(fromDense.isEqual(to: expected))
			#expect(fromZero.isEqual(to: expected))
		}
	}

	// MARK: - §2.2 The unscoreable observation is no longer dropped from an extremum

	@Test("min and max report a bucket containing an unscoreable observation as unscoreable")
	func extremaDoNotSkipTheUnscoreable() throws {
		// `min()` and `max()` order with `<`, and every comparison against a `nan` is false,
		// so February used to be skipped: `.min` answered 100 and `.max` answered 300 for a
		// quarter one of whose three observations does not exist — while `.sum` and
		// `.average` over the very same bucket answered `nan`.
		for method in [AggregationMethod.min, .max, .sum, .average] {
			let aggregated = PeriodSequence.aggregate(withUnscoreable, to: .quarterly, method: method)

			let poisoned: Double = try #require(aggregated[q1])
			#expect(poisoned.isNaN)

			// Q2 never saw it, and is a real answer.
			let clean: Double = try #require(aggregated[q2])
			#expect(clean.isFinite)
		}
	}

	@Test("first and last still answer for the one observation they name")
	func firstAndLastDesignateOneObservation() throws {
		// Position dependence is the definition of these two methods, not a defect, so this
		// pins it rather than changing it. January is scoreable, February is not.
		let firstOfQ1: Double = try #require(PeriodSequence.aggregate(withUnscoreable, to: .quarterly, method: .first)[q1])
		#expect(firstOfQ1.isEqual(to: 100.0))

		let lastOfQ1: Double = try #require(PeriodSequence.aggregate(withUnscoreable, to: .quarterly, method: .last)[q1])
		#expect(lastOfQ1.isEqual(to: 300.0))                // March, unaffected
	}

	// MARK: - The exemptions, carried across unchanged

	@Test("A daily source is exempt: a sparse calendar is not a gap")
	func dailySourceIsNotCoverageChecked() throws {
		// Under a coverage rule applied to daily data this quarter would need all ninety of
		// its days and the result would be empty — which is what a weekday-only price series
		// would get every time.
		let quarterly = PeriodSequence.aggregate(sparseDaily, to: .quarterly, method: .sum)

		let total: Double = try #require(quarterly[q1])
		#expect(total.isEqual(to: 150.0))                   // 10 + 20 + 30 + 40 + 50
	}

	@Test("A quarterly source tiles a half, and the uncovered half is withheld")
	func quarterlySourceCoversOnlyTheFirstHalf() throws {
		let halves = PeriodSequence.aggregate(quarterlySource, to: .semiannual, method: .sum)
		let h2 = Period.semiannual(year: 2025, half: 2)

		let firstHalf: Double = try #require(halves[h1])
		#expect(firstHalf.isEqual(to: 3000.0))              // 1000 + 2000

		#expect(!halves.periods.contains(h2))               // Q3 and Q4 were never measured
		#expect(halves.count == 1)
	}

	@Test("An annual total is not built from eleven months")
	func annualRequiresTwelveMonths() throws {
		let elevenPeriods: [Period] = (1...11).map { Period.month(year: 2025, month: $0) }
		let eleven = TimeSeries(periods: elevenPeriods, values: Array(repeating: 100.0, count: 11))

		let twelvePeriods: [Period] = (1...12).map { Period.month(year: 2025, month: $0) }
		let twelve = TimeSeries(periods: twelvePeriods, values: Array(repeating: 100.0, count: 12))

		let year = Period.year(2025)

		// 1,100 used to come back under the same label, and with the same shape, as 1,200.
		let short = PeriodSequence.aggregate(eleven, to: .annual, method: .sum)
		#expect(!short.periods.contains(year))
		#expect(short.count == 0)

		let complete: Double = try #require(PeriodSequence.aggregate(twelve, to: .annual, method: .sum)[year])
		#expect(complete.isEqual(to: 1200.0))               // 12 × 100
	}

	// MARK: - Targets that are not repeating buckets

	@Test("A custom target emits nothing rather than echoing the source periods")
	func customTargetEmitsNothing() {
		// This is where the two spellings disagreed outright. `mapToTargetPeriod` returned
		// the source period unchanged for `.custom`, so the caller got their monthly series
		// straight back from a call that claims to coarsen it — six months relabelled as an
		// aggregation. The method's `bucket` returns `nil`, and now so does this.
		let result = PeriodSequence.aggregate(dense, to: .custom, method: .sum)
		#expect(result.count == 0)
		#expect(result.periods.isEmpty)
	}

	@Test("A target no coarser than the source emits nothing")
	func sameOrFinerTargetEmitsNothing() {
		let sameGranularity = PeriodSequence.aggregate(dense, to: .monthly, method: .sum)
		#expect(sameGranularity.count == 0)

		let finer = PeriodSequence.aggregate(dense, to: .daily, method: .sum)
		#expect(finer.count == 0)
	}

	// MARK: - The caller can still ask the other question

	@Test("Filling the gap makes the quarter answerable again, on the caller's terms")
	func fillingRestoresTheQuarter() throws {
		let assumingZero = PeriodSequence.aggregate(
			gap.fillMissing(with: 0.0, over: months), to: .quarterly, method: .sum
		)
		let carryingForward = PeriodSequence.aggregate(
			gap.fillForward(over: months), to: .quarterly, method: .sum
		)
		let interpolating = PeriodSequence.aggregate(
			gap.interpolate(over: months), to: .quarterly, method: .sum
		)

		// "March was zero": 100 + 200 + 0
		let zeroAnswer: Double = try #require(assumingZero[q1])
		#expect(zeroAnswer.isEqual(to: 300.0))

		// "March was whatever February was": 100 + 200 + 200
		let carriedAnswer: Double = try #require(carryingForward[q1])
		#expect(carriedAnswer.isEqual(to: 500.0))

		// "March sat on the line between February and April": 100 + 200 + 300
		let interpolatedAnswer: Double = try #require(interpolating[q1])
		#expect(interpolatedAnswer.isEqual(to: 600.0))

		// Three defensible answers to the same question, and the caller chose which.
		#expect(!zeroAnswer.isEqual(to: carriedAnswer))
		#expect(!carriedAnswer.isEqual(to: interpolatedAnswer))
	}
}
