//
//  ZeroTrendSeasonalityTests.swift
//  BusinessMathTests
//
//  Two findings from `project/plans/PHASE3_PROBE_FINDINGS.md`, one of which is a non-defect
//  and is pinned here so it is not re-opened.
//
//  1. `seasonalIndices` fabricated an index on **clean** data, by two separate routes.
//
//     A seasonal index is a multiplier — `mean(value / trend)`, normalised so the indices
//     average to 1 — so it exists only while the trend keeps one sign. A trend that passes
//     through zero makes the ratio unbounded at the crossing and inverts it beyond, and the
//     normalisation then conceals the whole problem: the indices still sum to
//     `periodsPerYear`, which is the invariant a careful caller checks, while the season
//     ranking they encode can be inverted end to end. Neither case involves a single
//     contaminated observation; every value in both fixtures below is a real measurement.
//
//     The second route is pure geometry and needs no zero at all: at `periodsPerYear == 2`
//     the centred moving average of an even two-wide window is defined at only `count - 3`
//     positions, so the four observations the function advertises as sufficient leave one of
//     the two seasons with nothing. The `ratios.isEmpty` fallback then wrote `T(1)` — the
//     precise statement "this season carries no seasonal effect" — for a season that was
//     never measured.
//
//  2. ADF threw `noVariance("y has no variance (all values approximately equal)")` on a
//     clean, valid series running 100 to 210 in steps of 10. That is **not** a defect, and
//     the test at the bottom of this file pins it as correct behaviour with the reasoning, so
//     that the next reader of the probe transcript does not spend the afternoon on it again.
//

import Testing
import Foundation
@testable import BusinessMath

/// Elementwise comparison, so no assertion in this file compares `[Double]` with `==`.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
	// `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
	// deliberately marks unevaluable positions with `.nan`, so two NaNs in the same slot
	// are an agreement, not a mismatch — without this a marked position can never match.
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
}

/// Elementwise comparison within a tolerance, for values that pass through `Double` arithmetic.
private func agree(_ lhs: [Double], _ rhs: [Double], within tolerance: Double) -> Bool {
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { abs($0 - $1) < tolerance }
}

@Suite("Seasonal indices when the trend reaches or crosses zero")
struct ZeroTrendSeasonalityTests {

	// MARK: - Fixtures

	/// Three years of quarterly sales with a rising trend and a Q4 peak. The same series the
	/// source file's own comments are measured on.
	private let positiveTrend: [Double] = [
		100, 105, 110, 165,
		110, 115, 120, 180,
		120, 125, 130, 195
	]

	/// Exact indices for `positiveTrend` at `periodsPerYear: 4`, derived by evaluating the
	/// algorithm in exact rational arithmetic.
	///
	/// The centred four-wide moving average is defined at indices 3…10 and takes the values
	/// 485/4, 495/4, 505/4, 1035/8, 265/2, 135, 275/2, 1125/8. Dividing each observation by it
	/// gives the ratios 132/97, 8/9, 92/101, 64/69, 72/53, 8/9, 10/11, 208/225, which group by
	/// season into the means 8/9, 1011/1111, 4792/5175 and 6990/5141. Their own mean is
	/// 120729633367/118231175700, and dividing through by it gives the four values below.
	private let positiveTrendIndices: [Double] = [
		0.8704936432675882,
		0.8911590526655923,
		0.9068272909865831,
		1.3315200130802365
	]

	/// Rounding budget for the comparison above: the exact rationals are the same expression
	/// evaluated without error, and the library evaluates it in about twenty `Double`
	/// operations on quantities of order 1, so the accumulated relative error is several
	/// orders of magnitude inside this.
	private let indexTolerance: Double = 1e-12

	/// A business crossing from loss into profit, with a seasonal swing that is constant in
	/// currency: an exactly linear trend from -55 to +55 carrying the offsets
	/// [-5, 0, +5, +20]. Every value is a real, finite measurement.
	///
	/// Its centred moving average runs -30, -20, -10, 0, 10, 20, 30, 40 — it reaches zero
	/// exactly at index 6 and spans both signs. Before the guard this returned
	/// [0.8136, 0.6780, 1.0169, 1.4915], summing to exactly 4, reporting season 1 — the one
	/// season with no seasonal offset at all — as 32% below average. Season 3's two ratios
	/// were 0.1667 and 3.5, which measure distance from the crossing and nothing else.
	private let zeroCrossingTrend: [Double] = [
		-60, -45, -30, -5,
		-20, -5, 10, 35,
		20, 35, 50, 75
	]

	/// The same shape shifted up by 5, so the trend runs -25, -15, -5, 5, 15, 25, 35, 45 and
	/// never lands on zero. Nothing is filtered by the `trend != 0` test, and before the guard
	/// the indices came back [0.7975, 0.4557, 1.6835, 1.0633] — still summing to exactly 4,
	/// with the ranking inverted: the largest true seasonal effect (+20, season 3) reported as
	/// roughly average, and the neutral season as 54% below it.
	///
	/// This fixture is what makes the guard a test of the **sign span** rather than of
	/// equality with zero.
	private let signChangeWithoutZero: [Double] = [
		-55, -40, -25, 0,
		-15, 0, 15, 40,
		25, 40, 55, 80
	]

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: (0..<values.count).map { Period.year(2000 + $0) }, values: values)
	}

	// MARK: - Controls: an ordinary series must still get its indices

	@Test("Control_PositiveTrend_StillProducesItsIndices")
	func controlPositiveTrendStillProducesItsIndices() throws {
		let indices = try seasonalIndices(values: positiveTrend, periodsPerYear: 4)
		let matches: Bool = agree(indices, positiveTrendIndices, within: indexTolerance)
		#expect(matches, "a rising quarterly series stopped producing its derived seasonal indices")

		// The invariant a caller checks, asserted separately from the values themselves —
		// it is the thing the fabricated answers also satisfied.
		let sum: Double = indices.reduce(0, +)
		let sumIsFour: Bool = abs(sum - 4.0) < indexTolerance
		#expect(sumIsFour, "the seasonal indices stopped summing to periodsPerYear")

		let q4IsThePeak: Bool = indices[3] > indices[0] && indices[3] > indices[1] && indices[3] > indices[2]
		#expect(q4IsThePeak, "Q4 stopped being the strongest season on a series whose Q4 is 80% above its Q1")
	}

	/// A wholly negative trend is a coherent multiplicative statement — a loss that deepens
	/// every Q4 — and `(-v) / (-t)` is the ratio of the positive case, so the indices must be
	/// identical. This is the control that proves the guard tests the sign *span* and has not
	/// simply outlawed negative data.
	@Test("Control_WhollyNegativeTrend_ProducesTheSameIndices")
	func controlWhollyNegativeTrendProducesTheSameIndices() throws {
		let negated: [Double] = positiveTrend.map { -$0 }
		let indices = try seasonalIndices(values: negated, periodsPerYear: 4)
		let matches: Bool = agree(indices, positiveTrendIndices, within: indexTolerance)
		#expect(matches, "negating every observation changed the seasonal indices")
	}

	@Test("Control_TwoSeasonsWithFiveObservations_StillProducesIndices")
	func controlTwoSeasonsWithFiveObservationsStillProducesIndices() throws {
		// [10, 20, 30, 40, 50] at periodsPerYear 2: the centred two-wide average is defined at
		// indices 2 and 3 with the values 20 and 30, giving the single ratios 3/2 and 4/3.
		// Their mean is 17/12, so the indices are (3/2)/(17/12) = 18/17 and (4/3)/(17/12) =
		// 16/17.
		let fivePoints: [Double] = [10, 20, 30, 40, 50]
		let indices = try seasonalIndices(values: fivePoints, periodsPerYear: 2)
		let expected: [Double] = [18.0 / 17.0, 16.0 / 17.0]
		let matches: Bool = agree(indices, expected, within: indexTolerance)
		#expect(matches, "five observations at periodsPerYear 2 stopped producing their indices")
	}

	// MARK: - The trend reaches or crosses zero

	@Test("ZeroCrossingTrend_RefusesRatherThanReportingAPattern")
	func zeroCrossingTrendRefusesRatherThanReportingAPattern() {
		#expect(throws: SeasonalityError.self) {
			_ = try seasonalIndices(values: zeroCrossingTrend, periodsPerYear: 4)
		}
	}

	/// The `trend[i] != T.zero` filter inside the function sees nothing here, so this is the
	/// case the narrow reading of the defect would have missed entirely.
	@Test("SignChangeWithoutAnExactZero_AlsoRefuses")
	func signChangeWithoutAnExactZeroAlsoRefuses() {
		#expect(throws: SeasonalityError.self) {
			_ = try seasonalIndices(values: signChangeWithoutZero, periodsPerYear: 4)
		}
	}

	/// **Changed 2026-09-29.** The two methods used to agree here, and the earlier version of
	/// this test was parameterised over both to assert that. They agreed for a reason that was
	/// never about additive decomposition: the additive seasonal component was
	/// ``seasonalIndices(values:periodsPerYear:)`` re-centred (`index - mean(indices)`), so it
	/// inherited every ratio those indices were built from and was as undefined across a zero
	/// crossing as they are.
	///
	/// That component is now the per-season mean of `value - trend`, which divides by nothing,
	/// so `.additive` decomposes this series and recovers its planted offsets exactly —
	/// `Phase4StatementsAndSeriesTests.additiveDecompositionAcrossZeroCrossingRecoversPlantedOffsets`
	/// pins the numbers. The multiplicative refusal below is unchanged and is the one this file
	/// exists for.
	@Test("Decompose_ZeroCrossingTrend_StillRefusesUnderMultiplicative")
	func decomposeZeroCrossingTrendStillRefusesUnderMultiplicative() {
		let data = series(zeroCrossingTrend)
		#expect(throws: SeasonalityError.self) {
			_ = try decomposeTimeSeries(timeSeries: data, periodsPerYear: 4, method: .multiplicative)
		}
	}

	/// The other half of the same delta: the additive path no longer refuses, and this is where
	/// a reader of this file finds out. `seasonalIndices` itself is untouched and still refuses
	/// — see `zeroCrossingTrendRefusesRatherThanReportingAPattern` above — so the two are now
	/// deliberately different, which is the thing most likely to be "tidied" back.
	@Test("Decompose_ZeroCrossingTrend_NoLongerRefusesUnderAdditive")
	func decomposeZeroCrossingTrendNoLongerRefusesUnderAdditive() throws {
		let data = series(zeroCrossingTrend)
		let decomposition = try decomposeTimeSeries(timeSeries: data, periodsPerYear: 4, method: .additive)
		#expect(decomposition.seasonal.count == zeroCrossingTrend.count,
				"one seasonal value per observation")

		// The components sum to zero, which is the property that makes them additive indices
		// rather than re-centred ratios.
		let firstCycle: [Double] = Array(decomposition.seasonal.valuesArray[0..<4])
		let cycleSum: Double = firstCycle.reduce(0.0, +)
		#expect(abs(cycleSum) < 1e-9, "centred additive indices must sum to zero, got \(cycleSum)")
	}

	@Test(
		"Control_Decompose_PositiveTrend_StillSucceedsUnderBothMethods",
		arguments: [DecompositionMethod.additive, DecompositionMethod.multiplicative]
	)
	func controlDecomposePositiveTrendStillSucceedsUnderBothMethods(method: DecompositionMethod) throws {
		let data = series(positiveTrend)
		let decomposition = try decomposeTimeSeries(timeSeries: data, periodsPerYear: 4, method: method)
		#expect(decomposition.seasonal.count == positiveTrend.count,
				"the decomposition stopped emitting one seasonal value per observation")

		// The seasonal component repeats with the cycle, which is the property that survives
		// both methods and is not a restatement of the index values asserted above.
		let seasonalValues: [Double] = decomposition.seasonal.valuesArray
		let firstCycle: [Double] = Array(seasonalValues[0..<4])
		let secondCycle: [Double] = Array(seasonalValues[4..<8])
		let cyclesRepeat: Bool = agree(firstCycle, secondCycle)
		#expect(cyclesRepeat, "the seasonal component stopped repeating with the cycle")
	}

	// MARK: - A season with no usable trend position

	/// Clean, positive, monotone, and the shortest input the documented contract accepts at
	/// `periodsPerYear: 2`. The centred two-wide average is defined at index 2 alone, so
	/// season 0 gets the single ratio 1.5 and season 1 gets nothing. The fallback fabricated
	/// `1` for it, and after normalisation the caller was handed [1.2, 0.8] — a ±20% seasonal
	/// swing on a perfectly straight line — summing to exactly 2.
	@Test("SeasonWithNoUsableTrendPosition_RefusesRatherThanFabricatingOne")
	func seasonWithNoUsableTrendPositionRefusesRatherThanFabricatingOne() {
		let fourPoints: [Double] = [10, 20, 30, 40]
		#expect(throws: SeasonalityError.self) {
			_ = try seasonalIndices(values: fourPoints, periodsPerYear: 2)
		}
	}
}

// MARK: - The ADF non-defect

/// `augmentedDickeyFuller` threw `noVariance` on a clean twelve-month series in the Phase 3
/// probe, and the transcript's KPSS statistic for the same fixture is reproduced below to
/// confirm this is that fixture.
///
/// **It is correct, and it is not a defect.** ADF does not regress on the series; it regresses
/// the first difference `Δy_t` on `y_{t-1}` and on lagged differences. A series that is
/// exactly linear has `Δy_t = 10` at every `t`, so the dependent vector is a constant and the
/// regression's zero-variance check fires — correctly. The design matrix is degenerate in the
/// same way: its two lagged-difference columns are also constant, hence collinear with the
/// intercept. There is no unit root to test for in an arithmetic progression.
///
/// The only thing wrong is the *wording*: `RegressionError.noVariance`'s message says "y has
/// no variance (all values approximately equal)", and its `y` is `Δy`, not the series the
/// caller handed in. A caller reading it about values running 100 to 210 goes looking for a
/// constant column that is not there. That message belongs to `MultipleLinearRegression.swift`
/// and is shared by every caller of it, so the diagnosis is documented on
/// `augmentedDickeyFuller` rather than rewritten here.
///
/// The cause is exactly-constant increments, not shortness and not a small sample: the control
/// below is the same length and the same rising shape with irregular increments, and it is
/// tested normally.
@Suite("ADF on an exactly linear series")
struct ExactlyLinearSeriesADFTests {

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: (0..<values.count).map { Period.month(year: 2024, month: $0 + 1) }, values: values)
	}

	/// The probe's fixture: twelve months, 100 to 210 in steps of 10.
	private let exactlyLinear: [Double] = (0..<12).map { 100.0 + 10.0 * Double($0) }

	@Test("ADF_ExactlyLinearSeries_DeclinesBecauseItsFirstDifferenceIsConstant")
	func adfExactlyLinearSeriesDeclinesBecauseItsFirstDifferenceIsConstant() {
		let data = series(exactlyLinear)
		#expect(throws: RegressionError.self) {
			_ = try data.augmentedDickeyFuller()
		}
	}

	/// KPSS answers on the same fixture, because it never differences the series. This pins
	/// that the two tests disagreeing here is the expected consequence of how they are built,
	/// not a symptom of bad data, and it identifies the fixture: the statistic below is the
	/// one in the Phase 3 probe transcript.
	@Test("KPSS_ExactlyLinearSeries_AnswersOnTheSameFixture")
	func kpssExactlyLinearSeriesAnswersOnTheSameFixture() throws {
		let data = series(exactlyLinear)
		let result = try data.kpss(regression: .level)
		// Derived from the definition on this fixture: the mean is 155, so the residuals are
		// -55, -45, … 55; their partial sums squared total 207 350, the Bartlett long-run
		// variance at the default lag 2 is 2786.111…, and 207350 / (144 × 2786.111…) is the
		// value below.
		let expectedStatistic: Double = 0.5168245264207378
		let statisticMatches: Bool = abs(Double(result.statistic) - expectedStatistic) < 1e-12
		#expect(statisticMatches, "KPSS stopped answering on the fixture ADF declines")
		#expect(!result.isStationary, "KPSS stopped calling a steadily rising series non-stationary")
	}

	/// Twelve observations again, rising from 100 to 222 again, but with irregular increments
	/// (8, 13, 6, 13, 15, 4, 15, 16, 7, 16, 9). ADF answers. This is the control that shows
	/// the refusal above is about the increments being exactly constant, not about the sample.
	@Test("Control_VaryingIncrements_ADFStillAnswersAtTheSameLength")
	func controlVaryingIncrementsADFStillAnswersAtTheSameLength() throws {
		let irregular: [Double] = [100, 108, 121, 127, 140, 155, 159, 174, 190, 197, 213, 222]
		let result = try series(irregular).augmentedDickeyFuller()
		let statisticIsFinite: Bool = Double(result.statistic).isFinite
		#expect(statisticIsFinite, "ADF stopped producing a usable statistic on an ordinary rising series")
		#expect(!result.isStationary, "ADF started rejecting the unit root on a steadily rising series")
	}
}
