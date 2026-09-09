//
//  ETSFittingTests.swift
//  BusinessMath
//
//  RED phase — steps 3 and 4 of PROPOSAL_ets_fitting.md.
//
//  Nothing here asserts a number a spreadsheet would produce. Excel's ETS uses its own
//  initialisation and its own optimizer; matching its digits is not achievable and
//  pretending otherwise would produce tests that fail correct code. Every assertion is a
//  property or a relationship.
//
//  The load-bearing one is the grid comparison. An earlier draft of the proposal asserted
//  that the fitted in-sample SSE must be no worse than the library defaults 0.2/0.1/0.1 —
//  which a fitter that starts at the defaults and returns them unchanged satisfies, since
//  `≤` is satisfied by equality. What survives is: the fitted SSE must be no worse than
//  the best point of a 0.1-resolution grid over the feasible box. No fixed-point stub
//  passes that, because the grid contains the stub's answer by construction.
//
//  Measured 2026-09-09: both grid comparisons hold *strictly* — the search beats brute
//  force at this resolution rather than tying it. They are written as `≤` anyway, because
//  a series whose global optimum happens to sit on a grid point would legitimately tie and
//  a strict assertion would then fail correct code.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("ETS parameter fitting")
struct ETSFittingTests {

	// MARK: - Fixtures

	private func monthly(_ values: [Double]) -> TimeSeries<Double> {
		let periods = (0..<values.count).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }
		return TimeSeries(periods: periods, values: values)
	}

	/// Additive seasonal series: level + trend + a cycle of length `m`, plus a repeatable
	/// sawtooth perturbation so the fit has something to trade off against.
	private func seasonalValues(cycle m: Int, cycles: Int) -> [Double] {
		let n = m * cycles
		var values: [Double] = []
		values.reserveCapacity(n)
		for t in 0..<n {
			let phase: Double = Double(t % m) / Double(m)
			let seasonal: Double = 20.0 * Foundation.sin(2.0 * Double.pi * phase)
			let level: Double = 100.0 + 0.5 * Double(t)
			let wobble: Double = Double((t * 7) % 5) - 2.0
			values.append(level + seasonal + wobble)
		}
		return values
	}

	/// A deterministic pseudo-random walk. Its optimal level smoothing is at the top of
	/// the box — the best forecast of tomorrow is today's value — so the library defaults
	/// of 0.2/0.1/0.1 are known to be poor on it.
	private func randomWalkValues(count n: Int, seed: UInt64) -> [Double] {
		var state = seed
		var level = 100.0
		var values: [Double] = []
		values.reserveCapacity(n)
		let scale = Double(UInt64(1) << 53)
		for _ in 0..<n {
			state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			let unit = Double(state >> 11) / scale
			let shock: Double = 10.0 * unit - 5.0
			level += shock
			values.append(level)
		}
		return values
	}

	/// A deterministic pseudo-random series with no structure at all.
	private func noiseValues(count n: Int, seed: UInt64) -> [Double] {
		var state = seed
		var values: [Double] = []
		values.reserveCapacity(n)
		let scale = Double(UInt64(1) << 53)
		for _ in 0..<n {
			state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			values.append(Double(state >> 11) / scale)
		}
		return values
	}

	/// The best in-sample SSE reachable on a 0.1-resolution grid over `[0, 1]`.
	///
	/// 11 values per searched parameter: 11³ = 1,331 trainings for a seasonal fit, 11² =
	/// 121 for a non-seasonal one. Affordable once, in a test, on a short series.
	private func gridBestSSE(values: [Double], seasonLength m: Int) -> Double {
		let axis: [Double] = (0...10).map { Double($0) / 10.0 }
		let gammaAxis: [Double] = m > 1 ? axis : [0.0]
		var best = Double.infinity
		for a in axis {
			for b in axis {
				for g in gammaAxis {
					let sse = etsSumSquaredResiduals(
						values: values, alpha: a, beta: b, gamma: g, seasonLength: m)
					if sse < best { best = sse }
				}
			}
		}
		return best
	}

	// MARK: - The assertion no stub passes

	@Test("Seasonal: the fitted SSE beats the best point of a 0.1-resolution grid")
	func seasonalBeatsGrid() throws {
		let values = seasonalValues(cycle: 4, cycles: 6)      // n = 24
		let series = monthly(values)
		let fit = try series.fitETS(seasonality: .periods(4), config: .default)
		let gridBest: Double = gridBestSSE(values: values, seasonLength: 4)
		let fitted: Double = fit.convergence.objective
		#expect(fitted <= gridBest, "fitted SSE \(fitted) must not lose to grid best \(gridBest)")
	}

	@Test("Non-seasonal: the fitted SSE beats the best point of a 0.1-resolution grid")
	func nonSeasonalBeatsGrid() throws {
		let values = randomWalkValues(count: 24, seed: 20_260_909)
		let series = monthly(values)
		let fit = try series.fitETS(seasonality: .none, config: .default)
		let gridBest: Double = gridBestSSE(values: values, seasonLength: 1)
		let fitted: Double = fit.convergence.objective
		#expect(fitted <= gridBest, "fitted SSE \(fitted) must not lose to grid best \(gridBest)")
	}

	@Test("The fitted SSE is strictly better than the library defaults on a random walk")
	func strictlyBeatsDefaults() throws {
		// A random walk's optimal level smoothing sits at the top of the box, so the
		// defaults 0.2 / 0.1 / 0.1 track it far too slowly. Strict, and it fails loudly.
		let values = randomWalkValues(count: 40, seed: 4_242_424_242)
		let series = monthly(values)
		let fit = try series.fitETS(seasonality: .none, config: .default)
		let defaultSSE = etsSumSquaredResiduals(
			values: values, alpha: 0.2, beta: 0.1, gamma: 0.1, seasonLength: 1)
		let fitted: Double = fit.convergence.objective
		#expect(fitted < defaultSSE, "fitted SSE \(fitted) must beat default SSE \(defaultSSE)")
	}

	// MARK: - Feasibility across the corpus

	@Test("Every fitted parameter lands inside [0, 1] on every corpus series")
	func parametersAlwaysFeasible() throws {
		let corpus: [(name: String, values: [Double], seasonality: ETSSeasonality)] = [
			("seasonal", seasonalValues(cycle: 4, cycles: 6), .detect),
			("trend", (0..<24).map { 100.0 + 3.0 * Double($0) }, .none),
			("constant", Array(repeating: 50.0, count: 24), .detect),
			("noise", noiseValues(count: 40, seed: 777_777), .detect),
			("random walk", randomWalkValues(count: 30, seed: 13_579), .none),
			("short", [10.0, 12.0, 9.0, 14.0], .none)
		]
		for entry in corpus {
			let fit = try monthly(entry.values).fitETS(seasonality: entry.seasonality, config: .default)
			#expect(fit.alpha >= 0.0 && fit.alpha <= 1.0, "alpha out of range on \(entry.name)")
			#expect(fit.beta >= 0.0 && fit.beta <= 1.0, "beta out of range on \(entry.name)")
			#expect(fit.gamma >= 0.0 && fit.gamma <= 1.0, "gamma out of range on \(entry.name)")
		}
	}

	@Test("A non-seasonal fit reports gamma as zero and a cycle length of 1")
	func nonSeasonalReportsZeroGamma() throws {
		let values = randomWalkValues(count: 24, seed: 8_675_309)
		let fit = try monthly(values).fitETS(seasonality: .none, config: .default)
		#expect(abs(fit.gamma) < 1e-15)
		#expect(fit.seasonLength == 1)
		#expect(fit.seasonalityWasDetected == false)
	}

	@Test("The search is deterministic: the same series fits to the same parameters")
	func searchIsDeterministic() throws {
		let series = monthly(seasonalValues(cycle: 4, cycles: 6))
		let first = try series.fitETS(seasonality: .periods(4), config: .default)
		let second = try series.fitETS(seasonality: .periods(4), config: .default)
		#expect(first.alpha.isEqual(to: second.alpha))
		#expect(first.beta.isEqual(to: second.beta))
		#expect(first.gamma.isEqual(to: second.gamma))
		#expect(first.convergence.evaluations == second.convergence.evaluations)
	}

	@Test("The reported parameters are the ones the returned model carries")
	func modelCarriesTheReportedParameters() throws {
		let series = monthly(seasonalValues(cycle: 4, cycles: 6))
		let fit = try series.fitETS(seasonality: .periods(4), config: .default)
		#expect(fit.model.alpha.isEqual(to: fit.alpha))
		#expect(fit.model.beta.isEqual(to: fit.beta))
		#expect(fit.model.gamma.isEqual(to: fit.gamma))
		#expect(fit.model.seasonalPeriods == fit.seasonLength)
	}

	// MARK: - Seasonality plumbing

	@Test("`.detect` recovers the cycle and says so")
	func detectRecoversCycle() throws {
		let series = monthly(seasonalValues(cycle: 12, cycles: 6))
		let fit = try series.fitETS(seasonality: .detect, config: .default)
		#expect(fit.seasonLength == 12)
		#expect(fit.seasonalityWasDetected == true)
	}

	@Test("An explicit cycle length is honoured and not recorded as detected")
	func explicitCycleIsHonoured() throws {
		let series = monthly(seasonalValues(cycle: 12, cycles: 6))
		let fit = try series.fitETS(seasonality: .periods(6), config: .default)
		#expect(fit.seasonLength == 6)
		#expect(fit.seasonalityWasDetected == false)
	}

	// MARK: - The fitted model, evaluated

	@Test("A fitted seasonal model beats seasonal-naive out of sample")
	func fittedModelBeatsSeasonalNaive() throws {
		let series = monthly(seasonalValues(cycle: 4, cycles: 12))   // n = 48
		let fit = try series.fitETS(seasonality: .periods(4), config: .default)
		let report = try series.backtest(
			fit.model,
			config: BacktestConfig(initialTrainSize: 24, horizon: 4, step: 4, seasonLength: 4))
		let mase = try #require(report.mase)
		#expect(mase < 1.0, "fitted model MASE \(mase) must beat the seasonal-naive benchmark")
	}

	@Test("In-sample errors are reported and agree with the standalone metrics")
	func inSampleErrorsAgreeWithStandaloneMetrics() throws {
		let values = seasonalValues(cycle: 4, cycles: 6)
		let series = monthly(values)
		let fit = try series.fitETS(seasonality: .periods(4), config: .default)
		var model = fit.model
		try model.train(values: values)
		let fitted: [Double] = zip(values, model.residuals).map { $0 - $1 }
		#expect(abs(fit.errors.mae - mae(values, fitted)) < 1e-12)
		#expect(abs(fit.errors.rmse - rmse(values, fitted)) < 1e-12)
		#expect(abs(fit.errors.mape - mape(values, fitted)) < 1e-12)
		#expect(abs(fit.errors.smape - smape(values, fitted)) < 1e-12)
	}

	@Test("A constant series reports no MASE rather than dividing by a zero scale")
	func constantSeriesHasNoMASE() throws {
		let series = monthly(Array(repeating: 50.0, count: 24))
		let fit = try series.fitETS(seasonality: .none, config: .default)
		#expect(fit.errors.mase == nil)
	}

	@Test("A series with a naive scale reports a MASE")
	func varyingSeriesReportsMASE() throws {
		let series = monthly(seasonalValues(cycle: 4, cycles: 6))
		let fit = try series.fitETS(seasonality: .periods(4), config: .default)
		let mase = try #require(fit.errors.mase)
		#expect(mase > 0.0)
	}

	// MARK: - Convergence reporting

	@Test("The fit says how many objective evaluations it spent")
	func convergenceReportsEvaluations() throws {
		let series = monthly(seasonalValues(cycle: 4, cycles: 6))
		let fit = try series.fitETS(seasonality: .periods(4), config: .default)
		#expect(fit.convergence.evaluations > 1)
		#expect(fit.convergence.objective >= 0.0)
		#expect(fit.convergence.objective.isFinite)
	}

	// MARK: - Refusals

	@Test("A series shorter than two seasonal cycles throws insufficientData")
	func tooShortForTheCycleThrows() {
		let series = monthly([1.0, 2.0, 3.0, 4.0, 5.0])
		#expect(throws: ForecastError.self) {
			_ = try series.fitETS(seasonality: .periods(4), config: .default)
		}
	}

	@Test("A non-positive explicit cycle length throws", arguments: [0, -1])
	func nonPositiveCycleThrows(length: Int) {
		let series = monthly(seasonalValues(cycle: 4, cycles: 6))
		#expect(throws: ForecastError.self) {
			_ = try series.fitETS(seasonality: .periods(length), config: .default)
		}
	}

	// MARK: - Configuration

	@Test("The default config keeps the search inside a box strictly inside [0, 1]")
	func defaultConfigBounds() {
		let config = ETSFitConfig.default
		#expect(config.lowerBound > 0.0)
		#expect(config.upperBound < 1.0)
		#expect(config.lowerBound < config.upperBound)
	}

	@Test("A nonsensical bound falls back to the default rather than deleting the box")
	func nonsensicalBoundsFallBack() {
		let inverted = ETSFitConfig(lowerBound: 0.9, upperBound: 0.1)
		#expect(inverted.lowerBound < inverted.upperBound)
		let unbounded = ETSFitConfig(lowerBound: -1.0, upperBound: 5.0)
		#expect(unbounded.lowerBound > 0.0)
		#expect(unbounded.upperBound < 1.0)
	}
}
