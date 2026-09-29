//
//  AnalyticsRecoveryTests.swift
//  BusinessMath
//
//  Pins two things about `Time Series/TimeSeriesAnalytics.swift` that no existing test could
//  have caught, because both failures look exactly like a shorter or noisier answer rather than
//  a wrong one:
//
//  1. **Recovery.** A stateful operator that folds an unusable observation into its own state
//     never gets it back out. `PHASE3_PROBE_FINDINGS.md` §1.2 measured this across the
//     streaming operators — `FINAL OUTPUT NaN = true` for the whole tail of the series — and
//     the same shape lived here in `exponentialMovingAverage`, `movingAverage` and
//     `rollingSum`. The assertion that matters is not "it is NaN somewhere" but **where it
//     stops being NaN**, and the oracle for that is exact: from the recovery position onward,
//     the answer must be bit-identical to the answer for the same series with the bad
//     observation simply absent.
//
//  2. **The length invariant** (`CONTAMINATED_INPUT_CONTRACT.md` §3.5). `growthRate` dropped
//     the period whose base was zero, so the series came back shorter with no diagnostic —
//     and `count` is exactly what a caller checks.
//
//  Every suite carries a clean control that passes both before and after the fix. Without it a
//  suite that fails for an unrelated reason reads as a caught defect.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

// MARK: - Exponential moving average

@Suite("Recovery — exponentialMovingAverage")
struct ExponentialMovingAverageRecoveryTests {

	private let alpha: Double = 0.3

	/// Jan 2025 onward, `count` consecutive months.
	private func months(_ count: Int) -> [Period] {
		(1...count).map { Period.month(year: 2025, month: $0) }
	}

	/// Jan 2025 onward with `skipping` left out, so the surviving observations keep their order
	/// and their spacing assumption but the unusable one is simply not there.
	private func monthsOmitting(_ skipping: Int, upTo count: Int) -> [Period] {
		(1...count).filter { $0 != skipping }.map { Period.month(year: 2025, month: $0) }
	}

	@Test("A contaminated observation is marked, and the very next period is already correct")
	func recoversAtTheVeryNextPeriod() throws {
		// Index 5 (June) is unusable. Everything else is a clean ramp.
		let contaminatedValues: [Double] = [10, 20, 30, 40, 50, .nan, 70, 80, 90, 100, 110, 120]
		let survivingValues: [Double] = [10, 20, 30, 40, 50, 70, 80, 90, 100, 110, 120]

		let contaminated = TimeSeries(periods: months(12), values: contaminatedValues)
		let asIfAbsent = TimeSeries(periods: monthsOmitting(6, upTo: 12), values: survivingValues)

		let measured = contaminated.exponentialMovingAverage(alpha: alpha)
		let oracle = asIfAbsent.exponentialMovingAverage(alpha: alpha)

		// The length invariant first: one output per period, contamination included.
		#expect(measured.count == 12)

		// The contaminated period, and only it, is unusable.
		let atContamination: Bool = measured.valuesArray[5].isNaN
		#expect(atContamination)
		let recoveredImmediately: Bool = measured.valuesArray[6].isFinite
		#expect(recoveredImmediately)

		// The exact oracle. Position 6 of the contaminated run is position 5 of the run that
		// never saw the bad observation, and from there on the two must agree bit for bit —
		// the state carried across the gap is the same state, not a rebuilt approximation.
		let tail: [Double] = Array(measured.valuesArray[6...])
		let oracleTail: [Double] = Array(oracle.valuesArray[5...])
		#expect(tail.count == 6)
		#expect(agreeExactly(tail, oracleTail))

		// Measured before the fix: 7 of the 12 outputs were NaN — every one from index 5 to the
		// end — because the recursion feeds its own output back in.
		let contaminatedOutputs = measured.valuesArray.filter { !$0.isFinite }.count
		#expect(contaminatedOutputs == 1)
	}

	@Test("The prefix before the contamination is untouched — clean control")
	func prefixIsUnchangedByLaterContamination() {
		let contaminatedValues: [Double] = [10, 20, 30, 40, 50, .nan, 70, 80]
		let cleanValues: [Double] = [10, 20, 30, 40, 50, 60, 70, 80]

		let contaminated = TimeSeries(periods: months(8), values: contaminatedValues)
		let clean = TimeSeries(periods: months(8), values: cleanValues)

		let measured = contaminated.exponentialMovingAverage(alpha: alpha)
		let control = clean.exponentialMovingAverage(alpha: alpha)

		// Nothing about the fix may disturb what the operator already reported for the periods
		// that precede the bad one. This control passed before the fix and must keep passing.
		let prefix: [Double] = Array(measured.valuesArray[0..<5])
		let controlPrefix: [Double] = Array(control.valuesArray[0..<5])
		#expect(agreeExactly(prefix, controlPrefix))
		#expect(control.count == 8)
	}

	@Test("A leading contaminated observation lets the second period seed the average")
	func leadingContaminationSeedsFromTheSecondPeriod() {
		// The old code seeded `ema` from `T.zero` and keyed initialisation on `index == 0`, so
		// a bad first observation would have smoothed the second period against a zero nobody
		// measured. The state is now "no state yet", which the second period supplies.
		let contaminatedValues: [Double] = [.nan, 20, 30, 40, 50]
		let survivingValues: [Double] = [20, 30, 40, 50]

		let contaminated = TimeSeries(periods: months(5), values: contaminatedValues)
		let asIfAbsent = TimeSeries(periods: monthsOmitting(1, upTo: 5), values: survivingValues)

		let measured = contaminated.exponentialMovingAverage(alpha: alpha)
		let oracle = asIfAbsent.exponentialMovingAverage(alpha: alpha)

		#expect(measured.count == 5)
		let firstIsMarked: Bool = measured.valuesArray[0].isNaN
		#expect(firstIsMarked)

		let tail: [Double] = Array(measured.valuesArray[1...])
		#expect(agreeExactly(tail, oracle.valuesArray))
	}

	@Test("An infinite observation recovers on the same schedule as a NaN")
	func recoversFromAnInfiniteObservation() {
		// Narrowed to `isFinite` rather than `isNaN` deliberately: an infinite state is not
		// survivable either. `alpha * inf + (1 - alpha) * inf` is infinite for every alpha in
		// range, and the moment two like-signed infinities meet the state is NaN anyway — so
		// screening only NaN would leave a second permanent-contamination path open.
		let contaminatedValues: [Double] = [10, 20, .infinity, 40, 50, 60]
		let survivingValues: [Double] = [10, 20, 40, 50, 60]

		let contaminated = TimeSeries(periods: months(6), values: contaminatedValues)
		let asIfAbsent = TimeSeries(periods: monthsOmitting(3, upTo: 6), values: survivingValues)

		let measured = contaminated.exponentialMovingAverage(alpha: alpha)
		let oracle = asIfAbsent.exponentialMovingAverage(alpha: alpha)

		#expect(measured.count == 6)
		let markedNotPassedThrough: Bool = measured.valuesArray[2].isNaN
		#expect(markedNotPassedThrough)

		let tail: [Double] = Array(measured.valuesArray[3...])
		let oracleTail: [Double] = Array(oracle.valuesArray[2...])
		#expect(agreeExactly(tail, oracleTail))
	}

	@Test("Clean control — at alpha 1 the average is the observation, period for period")
	func cleanSeriesAtAlphaOneIsTheInput() {
		// Independent of the recursion's own arithmetic: alpha = 1 discards the state entirely,
		// so the output is the input and no formula is being checked against itself.
		let values: [Double] = [10, 20, 30, 40, 50, 60, 70]
		let series = TimeSeries(periods: months(7), values: values)

		let measured = series.exponentialMovingAverage(alpha: 1.0)

		#expect(measured.count == 7)
		#expect(agreeExactly(measured.valuesArray, values))
	}
}

// MARK: - Growth rate

@Suite("Length invariant — growthRate")
struct GrowthRateLengthInvariantTests {

	private let tolerance: Double = 1e-12

	private func months(_ count: Int) -> [Period] {
		(1...count).map { Period.month(year: 2025, month: $0) }
	}

	@Test("A zero base is kept and marked, not dropped from the result")
	func zeroBaseKeepsItsPeriod() throws {
		// Measured before the fix: three periods in, **one** growth rate out. The period whose
		// base was zero matched neither arm of `previousValue != T.zero` and was appended to
		// neither array, so `count` reported a shorter series than the span it covered.
		let periods = months(3)
		let series = TimeSeries(periods: periods, values: [100.0, 0.0, 50.0])

		let measured = series.growthRate(lag: 1)

		#expect(measured.count == 2)

		// Feb: a real collapse to zero, which is measurable and must stay a number.
		let february = try #require(measured[periods[1]])
		#expect(abs(february - (-1.0)) < tolerance)

		// Mar: growth from a zero base. Undefined rather than infinite — 0 -> 50 and 0 -> 5000
		// are equally "infinite", which is the signature of undefinedness — and the same answer
		// `cagr` gives for a non-positive beginning value.
		let march = try #require(measured[periods[2]])
		let marchIsUndefined: Bool = march.isNaN
		#expect(marchIsUndefined)
	}

	@Test("Clean control — every period from the lag onward is present and correct")
	func cleanSeriesKeepsEveryPeriod() throws {
		let periods = months(4)
		let series = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.1])

		let measured = series.growthRate(lag: 1)

		#expect(measured.count == 3)
		for index in 1...3 {
			let rate = try #require(measured[periods[index]])
			#expect(abs(rate - 0.10) < 1e-9, "growth at index \(index) was \(rate)")
		}
	}

	@Test("A NaN observation contaminates two rates and then the series recovers")
	func nanContaminatesOnlyTheRatesThatUseIt() throws {
		// A growth rate reads exactly two observations, so a bad one can reach exactly two
		// rates: its own period and the one that uses it as a base. Nothing carries further,
		// which is the difference between this and the EMA above — and the reason the fix
		// belonged there and not here.
		let periods = months(4)
		let series = TimeSeries(periods: periods, values: [100.0, .nan, 50.0, 60.0])

		let measured = series.growthRate(lag: 1)

		#expect(measured.count == 3)
		let atContamination: Bool = try #require(measured[periods[1]]).isNaN
		#expect(atContamination)
		let usingItAsABase: Bool = try #require(measured[periods[2]]).isNaN
		#expect(usingItAsABase)

		let recovered = try #require(measured[periods[3]])
		#expect(abs(recovered - 0.2) < tolerance)
	}

	@Test("A lag the series cannot support yields nothing rather than trapping")
	func outOfDomainLagYieldsEmptySeries() {
		// Measured before the guard: `lag: -1` indexed `periods[-1]` and `lag: 9` formed a range
		// whose lower bound exceeded its upper. Both trapped, so the caller was told nothing at
		// all. `movingAverage(window:)` already answers an impossible window with an empty
		// series and this now matches it.
		let series = TimeSeries(periods: months(4), values: [100.0, 110.0, 121.0, 133.1])

		#expect(series.growthRate(lag: -1).isEmpty)
		#expect(series.growthRate(lag: 9).isEmpty)
		#expect(series.diff(lag: -1).isEmpty)
		#expect(series.diff(lag: 9).isEmpty)
	}
}

// MARK: - Window operators

@Suite("Recovery — window operators over a contaminated observation")
struct WindowOperatorRecoveryTests {

	private let tolerance: Double = 1e-12

	private func months(_ count: Int) -> [Period] {
		(1...count).map { Period.month(year: 2025, month: $0) }
	}

	@Test("movingAverage recovers as soon as the window passes the bad observation")
	func movingAverageRecoversOnceTheWindowPasses() {
		// Measured before the fix: `windowSum - oldValue` cannot subtract a NaN back out, so
		// every average from index 3 to the end was NaN — 5 of the 6 reported windows, the last
		// one included, for one bad month out of eight.
		let values: [Double] = [10, 20, 30, .nan, 50, 60, 70, 80]
		let series = TimeSeries(periods: months(8), values: values)

		let measured = series.movingAverage(window: 3)

		// Windows end at indices 2 through 7: six results.
		#expect(measured.count == 6)

		let firstWindow = measured.valuesArray[0]
		let firstWindowMean: Double = (10.0 + 20.0 + 30.0) / 3.0
		#expect(abs(firstWindow - firstWindowMean) < tolerance)

		// Indices 3, 4 and 5 of the series are the three windows containing the bad month.
		let spanning: [Double] = Array(measured.valuesArray[1...3])
		let allSpanningAreMarked: Bool = spanning.allSatisfy { $0.isNaN }
		#expect(allSpanningAreMarked)

		// The first window clear of it — May, June, July — is a real average again.
		let recovered = measured.valuesArray[4]
		let recoveredMean: Double = (50.0 + 60.0 + 70.0) / 3.0
		#expect(abs(recovered - recoveredMean) < tolerance)

		let lastWindow = measured.valuesArray[5]
		let lastWindowMean: Double = (60.0 + 70.0 + 80.0) / 3.0
		#expect(abs(lastWindow - lastWindowMean) < tolerance)
	}

	@Test("rollingSum recovers as soon as the window passes the bad observation")
	func rollingSumRecoversOnceTheWindowPasses() {
		let values: [Double] = [10, 20, 30, .nan, 50, 60, 70, 80]
		let series = TimeSeries(periods: months(8), values: values)

		let measured = series.rollingSum(window: 3)

		#expect(measured.count == 6)

		let spanning: [Double] = Array(measured.valuesArray[1...3])
		let allSpanningAreMarked: Bool = spanning.allSatisfy { $0.isNaN }
		#expect(allSpanningAreMarked)

		let recovered = measured.valuesArray[4]
		let recoveredTotal: Double = 50.0 + 60.0 + 70.0
		#expect(abs(recovered - recoveredTotal) < tolerance)
	}

	@Test("rollingMin marks the window instead of silently omitting the observation")
	func rollingMinMarksTheWindowRatherThanSwallowingTheValue() {
		// The position-dependence is the point. `Swift.min(a, b)` is `b < a ? b : a` and every
		// comparison against NaN is false, so measured before the fix this series gave:
		//   window ending Apr (20, 30, NaN) -> 20   — the bad month discarded
		//   window ending May (30, NaN, 50) -> 30   — discarded again
		//   window ending Jun (NaN, 50, 60) -> NaN  — it seeded the accumulator, so it survived
		// Three windows containing the same bad month, two of them reporting a plausible
		// minimum of the *rest* of the window under the window's own label.
		let values: [Double] = [10, 20, 30, .nan, 50, 60, 70]
		let series = TimeSeries(periods: months(7), values: values)

		let measured = series.rollingMin(window: 3)

		#expect(measured.count == 5)

		let clean = measured.valuesArray[0]
		#expect(abs(clean - 10.0) < tolerance)

		let spanning: [Double] = Array(measured.valuesArray[1...3])
		let allSpanningAreMarked: Bool = spanning.allSatisfy { $0.isNaN }
		#expect(allSpanningAreMarked)

		let recovered = measured.valuesArray[4]
		#expect(abs(recovered - 50.0) < tolerance)
	}

	@Test("rollingMax marks the window instead of silently omitting the observation")
	func rollingMaxMarksTheWindowRatherThanSwallowingTheValue() {
		let values: [Double] = [10, 20, 30, .nan, 50, 60, 70]
		let series = TimeSeries(periods: months(7), values: values)

		let measured = series.rollingMax(window: 3)

		#expect(measured.count == 5)

		let clean = measured.valuesArray[0]
		#expect(abs(clean - 30.0) < tolerance)

		let spanning: [Double] = Array(measured.valuesArray[1...3])
		let allSpanningAreMarked: Bool = spanning.allSatisfy { $0.isNaN }
		#expect(allSpanningAreMarked)

		let recovered = measured.valuesArray[4]
		#expect(abs(recovered - 70.0) < tolerance)
	}

	@Test("Clean control — the window operators are unchanged on complete data")
	func cleanControlsAreUnchanged() {
		let values: [Double] = [10, 20, 30, 40, 50, 60, 70, 80]
		let series = TimeSeries(periods: months(8), values: values)

		let averages = series.movingAverage(window: 3)
		let sums = series.rollingSum(window: 3)
		let mins = series.rollingMin(window: 3)
		let maxes = series.rollingMax(window: 3)

		let expectedAverages: [Double] = [20, 30, 40, 50, 60, 70]
		let expectedSums: [Double] = [60, 90, 120, 150, 180, 210]
		let expectedMins: [Double] = [10, 20, 30, 40, 50, 60]
		let expectedMaxes: [Double] = [30, 40, 50, 60, 70, 80]

		#expect(agreeExactly(averages.valuesArray, expectedAverages))
		#expect(agreeExactly(sums.valuesArray, expectedSums))
		#expect(agreeExactly(mins.valuesArray, expectedMins))
		#expect(agreeExactly(maxes.valuesArray, expectedMaxes))
	}

	@Test("cumulative does not recover, and that is the correct answer")
	func cumulativeDoesNotRecoverByDesign() {
		// Pinned so that a later sweep does not "fix" it into agreement with the window
		// operators. Nothing ever leaves a running total: if one of the observations a total
		// contains is unusable then the total is unusable, permanently and by definition. The
		// window operators recover because an observation eventually falls out of the window.
		let values: [Double] = [10, 20, .nan, 40, 50]
		let series = TimeSeries(periods: months(5), values: values)

		let measured = series.cumulative()

		#expect(measured.count == 5)

		let beforeIsUsable: Bool = measured.valuesArray[0].isFinite && measured.valuesArray[1].isFinite
		#expect(beforeIsUsable)

		let afterward: [Double] = Array(measured.valuesArray[2...])
		let allAfterwardAreMarked: Bool = afterward.allSatisfy { $0.isNaN }
		#expect(allAfterwardAreMarked)
	}
}

// MARK: - Helpers

/// Elementwise floating-point identity.
///
/// `==` on `[Double]` is the wrong tool twice over: it is unsafe on floating point generally,
/// and it silently succeeds on element counts that happen to match after a value was dropped —
/// which is the exact defect half this file exists to catch. `isEqual(to:)` is also `false` for
/// NaN on both sides, so every NaN position here is asserted separately and deliberately rather
/// than being compared through this.
private func agreeExactly(_ lhs: [Double], _ rhs: [Double]) -> Bool {
	// `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
	// deliberately marks unevaluable positions with `.nan`, so two NaNs in the same slot
	// are an agreement, not a mismatch — without this a marked position can never match.
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
}
