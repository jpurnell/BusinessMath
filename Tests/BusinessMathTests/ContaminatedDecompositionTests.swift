//
//  ContaminatedDecompositionTests.swift
//  BusinessMathTests
//
//  From the growth/seasonality leg of the contaminated-input sweep
//  (`project/plans/PHASE3_PROBE_FINDINGS.md` §2.3). Four findings, one of which was a wrong
//  *diagnosis* rather than a wrong answer.
//
//  1. `decomposeTimeSeries(.multiplicative)` wrote `T(1)` into the residual wherever
//     `trend x seasonal` was unusable, commented "Neutral multiplicative residual". It is not
//     neutral: 1 is the single most favourable thing a multiplicative decomposition can say
//     about a point, namely that the model reproduces it exactly. And because the centred
//     moving average is undefined for roughly `periodsPerYear / 2` positions at each end, it
//     fired on *clean* data. Measured on twelve constant observations of 100 at
//     periodsPerYear = 4, every one of the twelve residuals came back exactly 1.0 — including
//     indices 0, 1, 2 and 11, where the trend is `nan` and nothing was fitted at all.
//     The additive branch of the same `switch` already answered `nan` there, because
//     `value - nan - seasonal` propagates. The sibling decided the fix.
//
//  2. `seasonalIndices` let a `nan` observation through. The moving average absorbs it, so
//     the trend is `nan` across the whole window containing it and every ratio in that window
//     is dropped from the seasonal average with no diagnostic. Measured on
//     [100, 105, 110, 165, 110, 115, 120, 180] with index 3 contaminated, *every* season lost
//     all of its ratios and the `ratios.isEmpty` fallback fabricated `T(1)` four times:
//     [1.0, 1.0, 1.0, 1.0], normalised to a sum of exactly 4 — "this business has no seasonal
//     pattern" for data whose Q4 is 80% above its Q1. The clean answer is
//     [0.8697, 0.8913, 0.9075, 1.3315].
//
//  3. `ExponentialTrend.fit` reported a `nan` as
//     "Exponential trend requires all positive values" — byte-identical to the error a
//     genuinely negative observation produces, because `nan > 0` is false and the positivity
//     guard caught it. Contract §3.2: do not report contamination through a guard written for
//     something else. The caller was sent to fix a sign problem they did not have.
//
//  4. `LinearTrend.fit` did not complain at all. `slope` and `intercept` are pure arithmetic,
//     so `nan` propagated into both coefficients and the model stored them as non-nil — it
//     reported itself fitted, printed an equation from `summary`, and then projected only
//     `nan`.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Decomposition and trend fitting on contaminated input")
struct ContaminatedDecompositionTests {

	// MARK: - Fixtures

	/// Twelve quarters of a series with real seasonality: Q4 runs ~80% above Q1.
	private static let seasonalTwelve: [Double] = [
		100, 105, 110, 165,
		110, 115, 120, 180,
		120, 125, 130, 195
	]

	/// Two years of the same shape — the shortest input `seasonalIndices` accepts at ppy = 4.
	private static let seasonalEight: [Double] = [100, 105, 110, 165, 110, 115, 120, 180]

	/// A series a multiplicative decomposition explains *exactly*: constant level, no season.
	/// Trend is 100 wherever it is defined, every index is 1, so every interior residual is
	/// exactly 100 / (100 x 1) = 1. This is the control for finding 1 — it must keep reporting
	/// a perfect fit where the fit really is perfect.
	private static let perfectlyExplained: [Double] = Array(repeating: 100.0, count: 12)

	private func quarterly(_ values: [Double]) -> TimeSeries<Double> {
		var periods: [Period] = []
		for index in values.indices {
			let year: Int = 2020 + (index / 4)
			let quarter: Int = (index % 4) + 1
			periods.append(Period.quarter(year: year, quarter: quarter))
		}
		return TimeSeries(periods: periods, values: values, metadata: TimeSeriesMetadata(name: "Quarterly"))
	}

	// MARK: - 1. The multiplicative residual

	/// RED before the fix: all twelve residuals were exactly 1.0, the four undefined ones
	/// included.
	@Test("MultiplicativeResidual_WhereTheTrendIsUndefined_IsNotAPerfectFit")
	func multiplicativeResidualWhereTrendUndefinedIsNotAPerfectFit() throws {
		let series = quarterly(Self.perfectlyExplained)
		let decomposition = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .multiplicative)

		let trend: [Double] = decomposition.trend.valuesArray
		let residual: [Double] = decomposition.residual.valuesArray
		#expect(residual.count == trend.count)

		// The centred moving average has no full window at 0, 1, 2 and 11. Take the positions
		// from the trend itself rather than hard-coding them.
		let undefined: [Int] = trend.indices.filter { trend[$0].isNaN }
		#expect(undefined.count == 4, "expected four undefined trend positions, got \(undefined)")
		for index in undefined {
			#expect(residual[index].isNaN, "residual at \(index) was \(residual[index]) with no trend to divide by")
		}
	}

	/// The control that must pass both before and after: where the model really does reproduce
	/// the observation, the residual is still exactly 1. Nothing here says "never report a
	/// good fit".
	@Test("MultiplicativeResidual_WhereTheFitIsExact_IsStillOne")
	func multiplicativeResidualWhereFitIsExactIsStillOne() throws {
		let series = quarterly(Self.perfectlyExplained)
		let decomposition = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .multiplicative)

		let trend: [Double] = decomposition.trend.valuesArray
		let residual: [Double] = decomposition.residual.valuesArray
		let defined: [Int] = trend.indices.filter { !trend[$0].isNaN }
		#expect(defined.count == 8, "expected eight fitted positions, got \(defined.count)")

		let one: Double = 1.0
		for index in defined {
			#expect(residual[index].isEqual(to: one), "residual at \(index) was \(residual[index])")
		}
	}

	/// The residual is only meaningful if it reconstructs the observation. Derived from the
	/// decomposition itself, so no expected value is recalled from anywhere.
	@Test("MultiplicativeComponents_AtFittedPositions_ReconstructTheObservation")
	func multiplicativeComponentsReconstructTheObservation() throws {
		let series = quarterly(Self.seasonalTwelve)
		let decomposition = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .multiplicative)

		let observed: [Double] = series.valuesArray
		let trend: [Double] = decomposition.trend.valuesArray
		let seasonal: [Double] = decomposition.seasonal.valuesArray
		let residual: [Double] = decomposition.residual.valuesArray

		for index in trend.indices where !trend[index].isNaN {
			let modelled: Double = trend[index] * seasonal[index]
			let reconstructed: Double = modelled * residual[index]
			let gap: Double = abs(reconstructed - observed[index])
			let bound: Double = 1e-9 * abs(observed[index])
			#expect(gap <= bound, "index \(index): rebuilt \(reconstructed) from \(observed[index])")
		}
	}

	/// The additive branch is the sibling that was already right, and stays right.
	@Test("AdditiveResidual_WhereTheTrendIsUndefined_WasAlreadyNaN")
	func additiveResidualWhereTrendUndefinedWasAlreadyNaN() throws {
		let series = quarterly(Self.perfectlyExplained)
		let decomposition = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .additive)

		let trend: [Double] = decomposition.trend.valuesArray
		let residual: [Double] = decomposition.residual.valuesArray
		for index in trend.indices where trend[index].isNaN {
			#expect(residual[index].isNaN, "additive residual at \(index) was \(residual[index])")
		}
	}

	/// With a contaminated observation the decomposition no longer produces components at all:
	/// it refuses, through `seasonalIndices`.
	@Test("Decompose_WithAContaminatedObservation_Refuses")
	func decomposeWithContaminatedObservationRefuses() {
		var values: [Double] = Self.seasonalTwelve
		values[5] = .nan
		let series = quarterly(values)

		#expect(throws: BusinessMathError.self) {
			_ = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .multiplicative)
		}
		#expect(throws: BusinessMathError.self) {
			_ = try decomposeTimeSeries(timeSeries: series, periodsPerYear: 4, method: .additive)
		}
	}

	// MARK: - 2. Seasonal indices

	/// RED before the fix: this returned [1.0, 1.0, 1.0, 1.0], summing to exactly 4, for data
	/// whose Q4 is 80% above its Q1.
	@Test("SeasonalIndices_WithAContaminatedObservation_Refuse")
	func seasonalIndicesWithContaminatedObservationRefuse() {
		var values: [Double] = Self.seasonalEight
		values[3] = .nan

		let thrown: Error? = capturedError { _ = try seasonalIndices(values: values, periodsPerYear: 4) }
		guard let error = thrown else {
			Issue.record("a contaminated series produced indices instead of an error")
			return
		}
		guard case let BusinessMathError.dataQuality(_, context) = error else {
			Issue.record("expected dataQuality, got \(error)")
			return
		}
		#expect(context["invalid_count"] == "1", "context was \(context)")
	}

	/// An infinity is unusable here for the same reason: it poisons the moving average and
	/// every ratio taken against it becomes `nan`.
	@Test("SeasonalIndices_WithAnInfiniteObservation_Refuse")
	func seasonalIndicesWithInfiniteObservationRefuse() {
		var values: [Double] = Self.seasonalEight
		values[3] = .infinity
		#expect(throws: BusinessMathError.self) {
			_ = try seasonalIndices(values: values, periodsPerYear: 4)
		}
	}

	/// Control: clean seasonal data still yields a seasonal pattern, normalised to sum to the
	/// number of seasons. Passes before and after.
	@Test("SeasonalIndices_OnCleanData_StillDescribeTheSeason")
	func seasonalIndicesOnCleanDataStillDescribeTheSeason() throws {
		let indices: [Double] = try seasonalIndices(values: Self.seasonalEight, periodsPerYear: 4)
		#expect(indices.count == 4)
		#expect(indices.allSatisfy { $0.isFinite })

		let sum: Double = indices.reduce(0, +)
		let drift: Double = abs(sum - 4.0)
		#expect(drift <= 1e-12, "indices summed to \(sum)")

		// Q4 of this series is 165/180 against a Q1 of 100/110, so its index must be the
		// largest and must exceed 1. Derived from the fixture, not recalled.
		let q4: Double = indices[3]
		let q1: Double = indices[0]
		#expect(q4 > q1, "Q4 index \(q4) did not exceed Q1 index \(q1)")
		#expect(q4 > 1.0, "Q4 index was \(q4)")
		#expect(q1 < 1.0, "Q1 index was \(q1)")
	}

	/// Control: a series with genuinely no season still reports none — an index of exactly 1
	/// per quarter. This is the answer contamination used to counterfeit, and it must remain
	/// reachable honestly.
	@Test("SeasonalIndices_OnAFlatSeries_AreExactlyOne")
	func seasonalIndicesOnFlatSeriesAreExactlyOne() throws {
		let indices: [Double] = try seasonalIndices(values: Self.perfectlyExplained, periodsPerYear: 4)
		#expect(indices.count == 4)
		let one: Double = 1.0
		#expect(indices.allSatisfy { $0.isEqual(to: one) }, "got \(indices)")
	}

	// MARK: - 3. The wrong diagnosis

	/// The actual defect: the two errors were byte-identical, so the error could not route a
	/// fix. This is the assertion that was red.
	@Test("ExponentialFit_NaNAndNegative_ProduceDistinguishableErrors")
	func exponentialFitNaNAndNegativeProduceDistinguishableErrors() {
		let contaminated: [Double] = [1000, .nan, 1323, 1520]
		let negative: [Double] = [1000, -1150, 1323, 1520]

		let fromNaN: Error? = capturedError {
			var model = ExponentialTrend<Double>()
			try model.fit(values: contaminated)
		}
		let fromNegative: Error? = capturedError {
			var model = ExponentialTrend<Double>()
			try model.fit(values: negative)
		}

		guard let nanError = fromNaN, let negativeError = fromNegative else {
			Issue.record("expected both fits to fail; got \(String(describing: fromNaN)) and \(String(describing: fromNegative))")
			return
		}

		let nanText: String = String(describing: nanError)
		let negativeText: String = String(describing: negativeError)
		#expect(nanText != negativeText, "both said: \(nanText)")

		// And the diagnoses are the right way round.
		guard case BusinessMathError.dataQuality = nanError else {
			Issue.record("a missing observation was reported as \(nanError)")
			return
		}
		guard case TrendModelError.invalidData = negativeError else {
			Issue.record("a negative observation was reported as \(negativeError)")
			return
		}
	}

	/// Control: the positivity guard still does the job it was written for. Passes before and
	/// after — the fix narrows it, it does not remove it.
	@Test("ExponentialFit_OnCleanPositiveData_StillFits")
	func exponentialFitOnCleanPositiveDataStillFits() throws {
		var model = ExponentialTrend<Double>()
		try model.fit(values: [1000, 1150, 1323, 1520])

		let rate: Double = try #require(model.growthRate)
		#expect(rate > 0, "a rising series fitted a growth rate of \(rate)")

		let projected: [Double] = model.projectValues(steps: 3)
		#expect(projected.count == 3)
		#expect(projected.allSatisfy { $0.isFinite })
	}

	@Test("ExponentialFit_OnZero_StillReportsTheSignProblem")
	func exponentialFitOnZeroStillReportsTheSignProblem() {
		#expect(throws: TrendModelError.self) {
			var model = ExponentialTrend<Double>()
			try model.fit(values: [1000, 0, 1323, 1520])
		}
	}

	/// The same wrong diagnosis lived in `LogisticTrend`, four hundred lines down the file and
	/// not on the probe's list.
	@Test("LogisticFit_NaNAndOverCapacity_ProduceDistinguishableErrors")
	func logisticFitNaNAndOverCapacityProduceDistinguishableErrors() throws {
		let fromNaN: Error? = capturedError {
			var model = LogisticTrend<Double>(capacity: 100_000)
			try model.fit(values: [1000, .nan, 15000])
		}
		let fromCapacity: Error? = capturedError {
			var model = LogisticTrend<Double>(capacity: 100_000)
			try model.fit(values: [1000, 150_000, 15000])
		}

		let nanError = try #require(fromNaN, "the contaminated fit reported success")
		let capacityError = try #require(fromCapacity, "the over-capacity fit reported success")

		// The defect itself: both inputs used to be reported as the same sign problem, so the
		// error could not route a fix. Distinguishability is the assertion that matters.
		let nanText = String(describing: nanError)
		let capacityText = String(describing: capacityError)
		#expect(nanText != capacityText, "both were reported as \(nanText)")
		guard case BusinessMathError.dataQuality = nanError else {
			Issue.record("a missing observation was reported as \(nanError)")
			return
		}
		guard case TrendModelError.invalidData = capacityError else {
			Issue.record("an over-capacity observation was reported as \(capacityError)")
			return
		}
	}

	// MARK: - 4. The fit that succeeded and could not project

	/// RED before the fix: `fit` returned normally and `projectValues` then returned
	/// [nan, nan, nan].
	@Test("LinearFit_WithAContaminatedObservation_Refuses")
	func linearFitWithContaminatedObservationRefuses() {
		let thrown: Error? = capturedError {
			var model = LinearTrend<Double>()
			try model.fit(values: [100, .nan, 120, 130])
		}
		guard let error = thrown else {
			Issue.record("the fit reported success on a contaminated series")
			return
		}
		guard case let BusinessMathError.dataQuality(_, context) = error else {
			Issue.record("expected dataQuality, got \(error)")
			return
		}
		#expect(context["invalid_count"] == "1", "context was \(context)")
	}

	/// The consequence the refusal removes: no model object is left behind claiming to be
	/// fitted.
	@Test("LinearModel_AfterARefusedFit_ReportsItselfUnfitted")
	func linearModelAfterRefusedFitReportsItselfUnfitted() {
		var model = LinearTrend<Double>()
		#expect(throws: BusinessMathError.self) {
			try model.fit(values: [100, .nan, 120, 130])
		}

		// Before the fix this read "LinearTrend: y = nanx + nan (fitted on 4 data points)".
		#expect(model.summary == "LinearTrend: Not fitted", "summary was \(model.summary)")
		#expect(model.projectValues(steps: 3).isEmpty, "got \(model.projectValues(steps: 3))")
	}

	/// And through the `TimeSeries` entry point, which is where a caller meets it.
	@Test("LinearFit_ToAContaminatedTimeSeries_Refuses")
	func linearFitToContaminatedTimeSeriesRefuses() {
		var values: [Double] = Self.seasonalTwelve
		values[7] = .nan
		let series = quarterly(values)

		#expect(throws: BusinessMathError.self) {
			var model = LinearTrend<Double>()
			try model.fit(to: series)
		}
	}

	/// Control: a clean rising series still fits and still projects finite numbers. Passes
	/// before and after.
	@Test("LinearFit_OnCleanData_StillProjects")
	func linearFitOnCleanDataStillProjects() throws {
		var model = LinearTrend<Double>()
		try model.fit(values: [100, 110, 120, 130])

		let slope: Double = try #require(model.slopeValue)
		let intercept: Double = try #require(model.interceptValue)
		// Exact for a perfectly linear series: y = 10x + 100.
		#expect(slope.isEqual(to: 10.0), "slope was \(slope)")
		#expect(intercept.isEqual(to: 100.0), "intercept was \(intercept)")

		// y = 10x + 100 continued at x = 4, 5, 6. Derived from the slope and intercept just
		// asserted, not recalled.
		let expected: [Double] = [140.0, 150.0, 160.0]
		let projected: [Double] = model.projectValues(steps: 3)
		#expect(agree(projected, expected), "got \(projected)")
	}

	/// `CustomTrend` is deliberately left alone: its `fit` reads only `values.count`, the
	/// projection comes from the caller's own closure, and a `nan` observation never reaches
	/// an arithmetic operation. Pinned so the omission is a decision rather than an oversight.
	@Test("CustomTrendFit_IgnoresObservationsEntirely")
	func customTrendFitIgnoresObservationsEntirely() throws {
		var model = CustomTrend<Double> { t in 100.0 + t }
		try model.fit(values: [100, .nan, 120])

		let projected: [Double] = model.projectValues(steps: 2)
		#expect(projected.count == 2)
		#expect(projected.allSatisfy { $0.isFinite }, "got \(projected)")
	}
}

// MARK: - File-scope helpers

/// Elementwise floating-point agreement, for the array comparisons `==` must never be used for.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) }
}

/// Captures a thrown error so its *identity* can be asserted, which is the point of finding 3.
private func capturedError(_ body: () throws -> Void) -> Error? {
	do {
		try body()
		return nil
	} catch {
		return error
	}
}
