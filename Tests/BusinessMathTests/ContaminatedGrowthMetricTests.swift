//
//  ContaminatedGrowthMetricTests.swift
//  BusinessMath
//
//  Pins the behaviour of the growth and forecast-error metrics when they are handed data they
//  cannot compute with, per `project/plans/CONTAMINATED_INPUT_CONTRACT.md` §3.1 (a non-throwing
//  function returning a floating-point value says "cannot be computed" with `.nan`) and §3.7
//  ("narrow the domain, don't fabricate the observation").
//
//  Every suite here carries a **control** that must pass both before and after the fix. The
//  control is the point: the defect was never that these functions returned a wrong number, it
//  was that "cannot be computed" and a legitimate favourable answer were the same number.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Contaminated input — growth and forecast-error metrics")
struct ContaminatedGrowthMetricTests {

	private let tolerance: Double = 1e-9

	// MARK: - Fixtures

	private var jan2020: Period { Period.month(year: 2020, month: 1) }
	private var jan2021: Period { Period.month(year: 2021, month: 1) }
	private var jan2025: Period { Period.month(year: 2025, month: 1) }

	// MARK: - cagr: three situations must not share one answer

	@Test("cagr control — a genuinely flat series still reports no growth")
	func cagrFlatSeriesReportsNoGrowth() {
		let flat = TimeSeries(periods: [jan2020, jan2025], values: [100.0, 100.0])

		let measured = flat.cagr(from: jan2020, to: jan2025)

		#expect(measured.isFinite)
		#expect(abs(measured) < tolerance)
	}

	@Test("cagr control — a real 10% trajectory is unchanged")
	func cagrMeasuresGrowth() {
		// 100 * 1.1^5 = 161.051, so the annualised rate is exactly 0.10.
		let ending: Double = 100.0 * pow(1.1, 5.0)
		let growing = TimeSeries(periods: [jan2020, jan2025], values: [100.0, ending])

		let measured = growing.cagr(from: jan2020, to: jan2025)
		let error: Double = abs(measured - 0.10)

		// Jan 2020 -> Jan 2025 is 1827 days, which the 365.25-day mean year makes 5.00205
		// years rather than 5.0, so the recovered rate lands 4.3e-5 below 0.10.
		#expect(error < 1e-4)
	}

	@Test("cagr — a contaminated start value is not reported as no growth")
	func cagrContaminatedStartIsNotZero() {
		let contaminated = TimeSeries(periods: [jan2020, jan2025], values: [Double.nan, 161.051])

		let measured = contaminated.cagr(from: jan2020, to: jan2025)

		#expect(measured.isNaN)
	}

	@Test("cagr — an absent period is not reported as no growth")
	func cagrAbsentPeriodIsNotZero() {
		// The series covers Jan 2020 and Jan 2025 only; Jan 2021 was never recorded.
		let sparse = TimeSeries(periods: [jan2020, jan2025], values: [100.0, 161.051])

		let measured = sparse.cagr(from: jan2021, to: jan2025)

		#expect(measured.isNaN)
	}

	@Test("cagr — flat, contaminated and absent no longer give one answer")
	func cagrThreeSituationsAreDistinguishable() {
		let flatSeries = TimeSeries(periods: [jan2020, jan2025], values: [100.0, 100.0])
		let contaminatedSeries = TimeSeries(periods: [jan2020, jan2025], values: [Double.nan, 161.051])

		let flat = flatSeries.cagr(from: jan2020, to: jan2025)
		let contaminated = contaminatedSeries.cagr(from: jan2020, to: jan2025)
		let absent = flatSeries.cagr(from: jan2021, to: jan2025)

		// Measured before the fix: all three were exactly 0.0, so a division whose statements
		// were simply missing ranked level with one that stood still.
		let flatIsContaminated = flat.isEqual(to: contaminated)
		let flatIsAbsent = flat.isEqual(to: absent)

		#expect(flat.isFinite)
		#expect(flatIsContaminated == false)
		#expect(flatIsAbsent == false)
		#expect(contaminated.isNaN)
		#expect(absent.isNaN)
	}

	@Test("cagr — a zero-length span is not reported as no growth")
	func cagrZeroLengthSpanIsNotZero() {
		let series = TimeSeries(periods: [jan2020, jan2025], values: [100.0, 161.051])

		let measured = series.cagr(from: jan2020, to: jan2020)

		#expect(measured.isNaN)
	}

	// MARK: - The two spellings of CAGR must agree

	@Test("cagr spellings agree on a contaminated beginning value")
	func cagrSpellingsAgreeOnContamination() {
		let contaminated = TimeSeries(periods: [jan2020, jan2025], values: [Double.nan, 161.051])

		let fromMethod = contaminated.cagr(from: jan2020, to: jan2025)
		let fromFunction = cagr(beginningValue: Double.nan, endingValue: 161.051, years: 5.0)

		#expect(fromMethod.isNaN)
		#expect(fromFunction.isNaN)
	}

	@Test("cagr spellings agree on a zero beginning value")
	func cagrSpellingsAgreeOnZeroBeginning() {
		let fromZero = TimeSeries(periods: [jan2020, jan2025], values: [0.0, 161.051])

		let fromMethod = fromZero.cagr(from: jan2020, to: jan2025)
		let fromFunction = cagr(beginningValue: 0.0, endingValue: 161.051, years: 5.0)

		// Measured before the fix: the free function returned +infinity and the method
		// returned 0.0 for the same situation.
		#expect(fromMethod.isNaN)
		#expect(fromFunction.isNaN)
		#expect(fromMethod.isInfinite == false)
		#expect(fromFunction.isInfinite == false)
	}

	@Test("cagr spellings agree on a zero-length span")
	func cagrSpellingsAgreeOnZeroSpan() {
		let series = TimeSeries(periods: [jan2020, jan2025], values: [100.0, 161.051])

		let fromMethod = series.cagr(from: jan2020, to: jan2020)
		let fromFunction = cagr(beginningValue: 100.0, endingValue: 161.051, years: 0.0)

		#expect(fromMethod.isNaN)
		#expect(fromFunction.isNaN)
	}

	@Test("free cagr — a negative or infinite span is not answerable")
	func freeCagrRejectsUnusableSpans() {
		let negativeSpan = cagr(beginningValue: 100.0, endingValue: 150.0, years: -5.0)
		let infiniteSpan = cagr(beginningValue: 100.0, endingValue: 150.0, years: Double.infinity)

		// Measured before the fix: the negative span returned a plausible finite rate and the
		// infinite span returned exactly 0.0 — "did not grow" — because pow(x, 0) is 1.
		#expect(negativeSpan.isNaN)
		#expect(infiniteSpan.isNaN)
	}

	@Test("free cagr — an infinite beginning value is not a 100% annual loss")
	func freeCagrRejectsInfiniteBeginning() {
		let measured = cagr(beginningValue: Double.infinity, endingValue: 150.0, years: 5.0)

		// Measured before the fix: the ratio collapsed to 0, so this returned exactly -1.0.
		#expect(measured.isNaN)
	}

	@Test("free cagr control — flat and growing trajectories are unchanged")
	func freeCagrControls() {
		let flat = cagr(beginningValue: 1000.0, endingValue: 1000.0, years: 5.0)
		let growing = cagr(beginningValue: 10_000.0, endingValue: 15_000.0, years: 5.0)
		let growingError: Double = abs(growing - 0.0845)

		#expect(abs(flat) < tolerance)
		#expect(growingError < 0.001)
	}

	// MARK: - forecastError: no field may claim success while another reports failure

	@Test("forecastError control — a clean comparison scores every metric")
	func forecastErrorCleanControl() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0])
		let forecast = TimeSeries(periods: periods, values: [98.0, 112.0, 118.0])

		let metrics = actual.forecastError(against: forecast)

		// Errors are 2, -2, 2 in magnitude, so MAE and RMSE are both exactly 2.
		let expectedMAE: Double = (2.0 + 2.0 + 2.0) / 3.0
		let maeError: Double = abs(metrics.mae - expectedMAE)
		let rmseError: Double = abs(metrics.rmse - 2.0)

		#expect(metrics.count == 3)
		#expect(maeError < tolerance)
		#expect(rmseError < tolerance)
		#expect(metrics.mape.isFinite)
		#expect(metrics.mape > 0.0)
	}

	@Test("forecastError — a contaminated observation leaves no field claiming success")
	func forecastErrorContaminatedIsInternallyConsistent() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, Double.nan, 120.0])
		let forecast = TimeSeries(periods: periods, values: [98.0, 112.0, 118.0])

		let metrics = actual.forecastError(against: forecast)

		// Measured before the fix: rmse = NaN while mape = 0.0 — the best score MAPE can take,
		// in the same returned value that admitted the computation had failed.
		#expect(metrics.rmse.isNaN)
		#expect(metrics.mae.isNaN)
		#expect(metrics.mape.isNaN)
		#expect(metrics.count == 3)
	}

	@Test("forecastError — an infinite observation leaves no field claiming success")
	func forecastErrorInfiniteIsInternallyConsistent() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, Double.infinity, 120.0])
		let forecast = TimeSeries(periods: periods, values: [98.0, 112.0, 118.0])

		let metrics = actual.forecastError(against: forecast)

		// Measured before the fix: rmse and mae were +infinity — a ranked, comparable score —
		// while mape divided the infinity out and reported NaN, then got rewritten to 0.0.
		#expect(metrics.rmse.isNaN)
		#expect(metrics.mae.isNaN)
		#expect(metrics.mape.isNaN)
		#expect(metrics.count == 3)
	}

	@Test("forecastError — series with no overlap score nothing, not perfectly")
	func forecastErrorNoOverlapIsNotPerfect() {
		let actualPeriods = (1...3).map { Period.month(year: 2025, month: $0) }
		let forecastPeriods = (7...9).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: actualPeriods, values: [100.0, 110.0, 120.0])
		let forecast = TimeSeries(periods: forecastPeriods, values: [98.0, 112.0, 118.0])

		let metrics = actual.forecastError(against: forecast)

		// Measured before the fix: rmse = mae = mape = 0.0, three perfect scores for a
		// comparison that never took place.
		#expect(metrics.count == 0)
		#expect(metrics.rmse.isNaN)
		#expect(metrics.mae.isNaN)
		#expect(metrics.mape.isNaN)
	}

	@Test("forecastError — all-zero actuals leave MAPE undefined, not perfect")
	func forecastErrorAllZeroActualsLeaveMAPEUndefined() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [0.0, 0.0, 0.0])
		let forecast = TimeSeries(periods: periods, values: [10.0, 10.0, 10.0])

		let metrics = actual.forecastError(against: forecast)

		// MAPE's own domain is empty here — every actual is zero, so there is no percentage
		// to take. That is a different statement from "the comparison failed": RMSE and MAE
		// are genuine measurements of a forecast that was out by 10 every period.
		let maeError: Double = abs(metrics.mae - 10.0)
		let rmseError: Double = abs(metrics.rmse - 10.0)

		#expect(metrics.mape.isNaN)
		#expect(maeError < tolerance)
		#expect(rmseError < tolerance)
		#expect(metrics.count == 3)
	}

	@Test("forecastError — a zero actual among non-zero ones still scores MAPE")
	func forecastErrorControlSkipsZeroActualsOnly() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [0.0, 100.0, 0.0, 100.0])
		let forecast = TimeSeries(periods: periods, values: [10.0, 110.0, 10.0, 90.0])

		let metrics = actual.forecastError(against: forecast)

		// Only the two non-zero actuals contribute: (10/100 + 10/100) / 2 = 0.10.
		let expectedMAPE: Double = (0.1 + 0.1) / 2.0
		let mapeError: Double = abs(metrics.mape - expectedMAPE)

		#expect(mapeError < tolerance)
		#expect(metrics.count == 4)
	}

	// MARK: - Window operations across a genuine gap (no NaN involved)

	/// Jan, Feb, Apr, May 2025 — March was never recorded. Every value is finite and valid.
	private func gappedSeries() -> TimeSeries<Double> {
		let gapped = [1, 2, 4, 5].map { Period.month(year: 2025, month: $0) }
		return TimeSeries(periods: gapped, values: [10.0, 20.0, 40.0, 50.0])
	}

	/// Jan through May 2025, complete.
	private func denseSeries() -> TimeSeries<Double> {
		let dense = (1...5).map { Period.month(year: 2025, month: $0) }
		return TimeSeries(periods: dense, values: [10.0, 20.0, 30.0, 40.0, 50.0])
	}

	@Test("movingAverage control — a complete series is unchanged")
	func movingAverageDenseControl() {
		let dense = denseSeries()

		let smoothed = dense.movingAverage(window: 3)

		// (10+20+30)/3, (20+30+40)/3, (30+40+50)/3
		let expected: [Double] = [20.0, 30.0, 40.0]

		#expect(smoothed.count == 3)
		#expect(agree(smoothed.valuesArray, expected))
	}

	@Test("movingAverage — a three-period window never straddles a missing month")
	func movingAverageOmitsWindowsSpanningAGap() {
		let gapped = gappedSeries()

		let smoothed = gapped.movingAverage(window: 3)

		// Measured before the fix: two results. Apr carried (10+20+40)/3 and May carried
		// (20+40+50)/3 — a three-month average of Feb, Apr and May, labelled May, with
		// nothing in the result to say a month had been skipped. Neither window is contiguous,
		// so the series has no three-period average anywhere and `count` now says so.
		#expect(smoothed.isEmpty)
		#expect(smoothed.count == 0)
	}

	@Test("movingAverage — windows that do not straddle the gap still report")
	func movingAverageKeepsContiguousWindows() throws {
		let gapped = gappedSeries()

		let smoothed = gapped.movingAverage(window: 2)

		// Jan+Feb = 15 at Feb; Feb+Apr straddles the gap and is dropped; Apr+May = 45 at May.
		let expected: [Double] = [15.0, 45.0]

		#expect(smoothed.count == 2)
		#expect(agree(smoothed.valuesArray, expected))
		let feb = try #require(smoothed[Period.month(year: 2025, month: 2)])
		#expect(abs(feb - 15.0) < tolerance)
	}

	@Test("rollingSum — a trailing total is never built from fewer periods than it claims")
	func rollingSumOmitsWindowsSpanningAGap() {
		let gapped = gappedSeries()

		let overTheGap = gapped.rollingSum(window: 3)
		let contiguous = gapped.rollingSum(window: 2)
		let expected: [Double] = [30.0, 90.0]

		// Measured before the fix: a three-period sum of 20+40+50 = 110 labelled May, which is
		// exactly what a complete Mar+Apr+May would have looked like.
		#expect(overTheGap.isEmpty)
		#expect(contiguous.count == 2)
		#expect(agree(contiguous.valuesArray, expected))
	}

	@Test("rollingMin — an extremum over a gap is the most plausible wrong answer")
	func rollingMinOmitsWindowsSpanningAGap() {
		let gapped = gappedSeries()

		let overTheGap = gapped.rollingMin(window: 3)
		let contiguous = gapped.rollingMin(window: 2)
		let expected: [Double] = [10.0, 40.0]

		#expect(overTheGap.isEmpty)
		#expect(contiguous.count == 2)
		#expect(agree(contiguous.valuesArray, expected))
	}

	@Test("rollingMax — an extremum over a gap is the most plausible wrong answer")
	func rollingMaxOmitsWindowsSpanningAGap() {
		let gapped = gappedSeries()

		let overTheGap = gapped.rollingMax(window: 3)
		let contiguous = gapped.rollingMax(window: 2)
		let expected: [Double] = [20.0, 50.0]

		#expect(overTheGap.isEmpty)
		#expect(contiguous.count == 2)
		#expect(agree(contiguous.valuesArray, expected))
	}

	@Test("rolling controls — a complete series is unchanged for sum, min and max")
	func rollingDenseControls() {
		let dense = denseSeries()

		let sums = dense.rollingSum(window: 3)
		let mins = dense.rollingMin(window: 3)
		let maxes = dense.rollingMax(window: 3)

		let expectedSums: [Double] = [60.0, 90.0, 120.0]
		let expectedMins: [Double] = [10.0, 20.0, 30.0]
		let expectedMaxes: [Double] = [30.0, 40.0, 50.0]

		#expect(agree(sums.valuesArray, expectedSums))
		#expect(agree(mins.valuesArray, expectedMins))
		#expect(agree(maxes.valuesArray, expectedMaxes))
	}

	@Test("window operations on irregular periods keep the behaviour they had")
	func windowOperationsOnCustomPeriodsAreUnaffected() {
		// A `custom` range has no defined successor, so adjacency cannot be established.
		// The gap check must not silently empty these results — that would be a far larger
		// and equally unannounced change than the defect it exists to fix.
		let secondsPerDay: Double = 86_400.0
		let base = Date(timeIntervalSince1970: 1_700_000_000)
		let stubs: [Period] = (0..<4).map { index in
			let startOffset: Double = Double(index) * 30.0 * secondsPerDay
			let endOffset: Double = Double(index + 1) * 30.0 * secondsPerDay
			return Period.custom(start: base.addingTimeInterval(startOffset),
								 end: base.addingTimeInterval(endOffset))
		}
		let irregular = TimeSeries(periods: stubs, values: [10.0, 20.0, 30.0, 40.0])

		let smoothed = irregular.movingAverage(window: 2)
		let expected: [Double] = [15.0, 25.0, 35.0]

		#expect(smoothed.count == 3)
		#expect(agree(smoothed.valuesArray, expected))
	}
}

// MARK: - File-scope helpers

/// Elementwise floating-point comparison. `==` on `[Double]` is forbidden in this suite:
/// it is exact, and `nan != nan`, so a contaminated array can compare unequal to itself.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) }
}
