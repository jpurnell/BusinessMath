//
//  Phase4RiskTests.swift
//  BusinessMathTests
//
//  Phase 4, shape G — `guard <validity test> else { return T(0) }` — swept across
//  `Risk/`, `Scenario Analysis/` and `Combination and Permutation/`.
//
//  The guards were almost always right about *when* to stop. What they were wrong about is
//  that `0` is not a way of declining to answer; it is an answer, and in risk it is
//  systematically the answer nobody would question:
//
//      VaR 0            no threshold loss
//      CVaR 0           no expected shortfall
//      max drawdown 0   never closed below a previous peak
//      Sharpe 0         earned exactly the risk-free rate
//      Sortino 0        earned exactly the minimum acceptable return
//      excess kurtosis 0   exactly normal-tailed
//      skewness 0       perfectly symmetric, no crash tail
//      tail risk 1      the tail is no worse than the threshold
//      marginal VaR 0   adding exposure here costs no risk
//
//  Each of those came back from a sample with nothing in it, and each sorted a position
//  with no history ahead of every position that had one.
//
//  The tests below pair every refusal with a control that reaches the same constant *by
//  arithmetic*, because a suite that only checks the `nan` cannot tell a fixed contract from
//  a function that has stopped computing. Every expected value is derived in the test from
//  the definition, never transcribed.
//
//  Not every zero was wrong. `combination`, `permutation` and `factorial` return `Int`, have
//  no value meaning "no answer", and have throwing companions for callers who need the
//  distinction; `C(n, r) = 0` for `r > n` is an exact count either way. Those are asserted
//  here as kept, so a later sweep does not "fix" them.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

// MARK: - Kurtosis, the named defect

@Suite("Risk.Kurtosis no longer overrides the contract it delegates to")
struct Phase4KurtosisTests {

	/// The headline. `Kurtosis.calculate` documented itself as delegating to `kurtosisP`,
	/// and its own `guard !values.isEmpty else { return T(0) }` meant an empty sample never
	/// reached the delegate at all. Once `kurtosisP` began answering `nan` for no data, that
	/// guard was the last remaining route to an excess kurtosis of zero from an empty
	/// sample — and zero is the specific claim that the returns are exactly normal-tailed.
	@Test("EmptySample_IsUndefinedRatherThanNormalTailed")
	func emptySampleIsUndefined() {
		let empty: [Double] = []
		#expect(Kurtosis.calculate(values: empty).isNaN)
	}

	/// The control, and the reason the test above is not satisfied by a function that has
	/// simply stopped working. `[-1, -1, 1, 1]` has excess kurtosis of exactly -2:
	///
	///   mean = 0; population variance = (1 + 1 + 1 + 1) / 4 = 1, so s = 1
	///   m4 = Σ ((x - mean) / s)⁴ = 1 + 1 + 1 + 1 = 4
	///   excess kurtosis = m4 / n - 3 = 4 / 4 - 3 = -2
	///
	/// A two-point distribution is the flattest there is, so -2 is the theoretical floor.
	@Test("TwoPointSample_IsExactlyMinusTwo")
	func twoPointSampleIsMinusTwo() {
		let sample: [Double] = [-1, -1, 1, 1]
		let measured: Double = Kurtosis.calculate(values: sample)

		let n: Double = 4
		let fourthMoment: Double = 4
		let expected: Double = fourthMoment / n - 3

		#expect(expected.isEqual(to: -2.0))
		#expect(abs(measured - expected) < 1e-12)
	}

	/// The `TimeSeries` overload forwards to the array one, so it inherits both answers.
	@Test("TimeSeriesOverload_InheritsBoth")
	func timeSeriesOverloadInheritsBoth() {
		let values: [Double] = [-1, -1, 1, 1]
		let periods = values.enumerated().map { Period.month(year: 2026, month: $0.offset + 1) }
		let series = TimeSeries(periods: periods, values: values)
		let measured: Double = Kurtosis.calculate(returns: series)
		#expect(abs(measured - -2.0) < 1e-12)

		let emptySeries = TimeSeries(periods: [Period](), values: [Double]())
		#expect(Kurtosis.calculate(returns: emptySeries).isNaN)
	}
}

// MARK: - The rest of the wrapper family

@Suite("Risk statistics refuse an empty sample instead of flattering it")
struct Phase4EmptySampleTests {

	/// `Skewness` carried the identical wrapper guard as `Kurtosis`, with the identical
	/// consequence one step over: zero skewness is the claim that the return distribution is
	/// symmetric — no crash tail.
	@Test("Skewness_EmptySample_IsUndefined")
	func skewnessEmptyIsUndefined() {
		#expect(Skewness.calculate(values: [Double]()).isNaN)
	}

	/// Two controls, because symmetric data alone cannot tell a working skewness from a
	/// function that returns zero. `[-1, -1, 1, 1]` is symmetric and must be 0; `[-1, -1,
	/// -1, 3]` is not, and its value follows from the definition:
	///
	///   mean = 0; population variance = (1 + 1 + 1 + 9) / 4 = 3, so s = √3
	///   Σ ((x - mean) / s)³ = 3·(-1/√3)³ + (3/√3)³ = -1/√3 + 9/√3 = 8/√3
	///   skewness = (1/n) · that = 2/√3
	@Test("Skewness_Controls_AreDerivable")
	func skewnessControls() {
		let symmetric: [Double] = [-1, -1, 1, 1]
		#expect(abs(Skewness.calculate(values: symmetric) - 0.0) < 1e-12)

		let rightSkewed: [Double] = [-1, -1, -1, 3]
		let measured: Double = Skewness.calculate(values: rightSkewed)
		let rootThree: Double = 3.0.squareRoot()
		let expected: Double = 2.0 / rootThree

		#expect(abs(measured - expected) < 1e-10)
		#expect(measured > 0.0)
	}

	/// A Sharpe ratio of zero has a meaning of its own — the strategy earned exactly the
	/// risk-free rate — so it cannot also stand for "no returns were supplied".
	@Test("SharpeRatio_EmptySample_IsUndefined")
	func sharpeEmptyIsUndefined() {
		#expect(SharpeRatio.calculate(values: [Double](), riskFreeRate: 0.03).isNaN)
	}

	/// The control that makes the refusal meaningful: a real sample whose Sharpe *is* zero.
	/// `[0.02, 0.04]` has mean 0.03, which is the risk-free rate exactly, so the excess
	/// return is 0 and the ratio is 0 — computed, not substituted. The second case shows the
	/// scale is otherwise alive.
	@Test("SharpeRatio_ZeroKeepsItsOwnMeaning")
	func sharpeZeroIsEarned() {
		let matched: [Double] = [0.02, 0.04]
		let matchedSharpe: Double = SharpeRatio.calculate(values: matched, riskFreeRate: 0.03)
		#expect(abs(matchedSharpe - 0.0) < 1e-12)

		// mean = 0.04, excess = 0.02; sample standard deviation of [0.02, 0.06] is
		// √(((0.02 - 0.04)² + (0.06 - 0.04)²) / (2 - 1)) = √0.0008.
		let varying: [Double] = [0.02, 0.06]
		let measured: Double = SharpeRatio.calculate(values: varying, riskFreeRate: 0.02)
		let dispersion: Double = 0.0008.squareRoot()
		let expected: Double = 0.02 / dispersion

		#expect(abs(measured - expected) < 1e-12)
		#expect(measured > 0.0)
	}

	/// Sortino had the sharper version of the collision: a series with no downside periods
	/// at all already answers `±infinity`, the best outcome the ratio can describe. So "no
	/// losses" and "no data" sat at opposite ends of the scale and only one told the truth.
	@Test("SortinoRatio_EmptySample_IsUndefined")
	func sortinoEmptyIsUndefined() {
		#expect(SortinoRatio.calculate(values: [Double](), riskFreeRate: 0.03).isNaN)
	}

	/// Control. `[0.02, 0.06]` against a minimum acceptable return of 0.03:
	///
	///   mean = 0.04, so excess = 0.01
	///   downside periods = [0.02]; downside variance = (0.02 - 0.03)² / 1 = 0.0001
	///   downside deviation = 0.01, so the ratio is 0.01 / 0.01 = 1
	@Test("SortinoRatio_Control_IsExactlyOne")
	func sortinoControl() {
		let mixed: [Double] = [0.02, 0.06]
		let measured: Double = SortinoRatio.calculate(values: mixed, riskFreeRate: 0.03)

		let excess: Double = 0.04 - 0.03
		let downsideDeviation: Double = 0.0001.squareRoot()
		let expected: Double = excess / downsideDeviation

		#expect(abs(measured - expected) < 1e-9)
		#expect(abs(measured - 1.0) < 1e-9)
	}

	/// A VaR of zero is the single most reassuring number a risk screen can print.
	@Test("ValueAtRisk_EmptySample_IsUndefined")
	func varEmptyIsUndefined() {
		#expect(ValueAtRisk.calculate(values: [Double](), confidenceLevel: 0.95).isNaN)
		#expect(ValueAtRisk.var95(values: [Double]()).isNaN)
		#expect(ValueAtRisk.var99(values: [Double]()).isNaN)
	}

	/// Control, derived from the type-7 quantile the implementation documents. For five
	/// sorted observations at α = 0.05 the position is 0.05 · (5 - 1) = 0.2, so the answer
	/// interpolates one fifth of the way from the first order statistic to the second:
	/// -0.04 + 0.2 · (-0.02 - -0.04) = -0.036.
	@Test("ValueAtRisk_Control_Interpolates")
	func varControl() {
		let sample: [Double] = [-0.04, -0.02, 0.0, 0.02, 0.04]
		let measured: Double = ValueAtRisk.calculate(values: sample, confidenceLevel: 0.95)

		let position: Double = 0.05 * 4.0
		let gap: Double = -0.02 - -0.04
		let expected: Double = -0.04 + position * gap

		#expect(abs(measured - expected) < 1e-12)
		#expect(measured < 0.0)
	}

	@Test("ConditionalValueAtRisk_EmptySample_IsUndefined")
	func cvarEmptyIsUndefined() {
		#expect(ConditionalValueAtRisk.calculate(values: [Double](), confidenceLevel: 0.95).isNaN)
		#expect(ConditionalValueAtRisk.cvar95(values: [Double]()).isNaN)
	}

	/// Control. The threshold is the VaR computed above, -0.036; the only observation at or
	/// below it is -0.04, so the expected shortfall is that observation itself.
	@Test("ConditionalValueAtRisk_Control_AveragesTheTail")
	func cvarControl() {
		let sample: [Double] = [-0.04, -0.02, 0.0, 0.02, 0.04]
		let measured: Double = ConditionalValueAtRisk.calculate(values: sample, confidenceLevel: 0.95)
		#expect(abs(measured - -0.04) < 1e-12)
	}

	/// `TailRisk` divides the two, so it inherits the refusal — and it used to have a
	/// fabricated constant of its own, answering `1` (the floor of its documented range,
	/// "the tail is no worse than the threshold") whenever the VaR was zero.
	@Test("TailRisk_EmptySample_IsUndefined")
	func tailRiskEmptyIsUndefined() {
		#expect(TailRisk.calculate(values: [Double](), confidenceLevel: 0.95).isNaN)
	}

	/// Control: the ratio of the two values derived above, |-0.04 / -0.036|.
	@Test("TailRisk_Control_IsTheRatio")
	func tailRiskControl() {
		let sample: [Double] = [-0.04, -0.02, 0.0, 0.02, 0.04]
		let measured: Double = TailRisk.calculate(values: sample, confidenceLevel: 0.95)

		let threshold: Double = -0.036
		let shortfall: Double = -0.04
		let expected: Double = shortfall / threshold

		#expect(abs(measured - expected) < 1e-9)
		#expect(measured > 1.0)
	}
}

// MARK: - Max drawdown: two defects in one guard

@Suite("Max drawdown separates no curve from a curve that never fell")
struct Phase4MaxDrawdownTests {

	/// `guard values.count > 1 else { return T(0) }` refused the empty array with the best
	/// number on the scale.
	@Test("EmptySample_IsUndefined")
	func emptyIsUndefined() {
		#expect(MaxDrawdown.calculate(values: [Double]()).isNaN)
	}

	/// And it refused a *single* return, which was not a sentinel at all but arithmetic the
	/// function declined to do. One return is one period of a curve starting at 1.
	///
	/// This is the assertion that distinguishes the fix from the guard: the old code passed
	/// `[0.05] -> 0` and would still pass it today, but reported `[-0.08]` — a real 8%
	/// loss — as no loss at all.
	@Test("SingleReturn_IsComputedNotShortCircuited")
	func singleReturnIsComputed() {
		let gain: Double = MaxDrawdown.calculate(values: [0.05])
		#expect(abs(gain - 0.0) < 1e-12)

		let loss: Double = MaxDrawdown.calculate(values: [-0.08])
		let trough: Double = 1.0 + -0.08
		let expected: Double = (1.0 - trough) / 1.0
		#expect(abs(loss - expected) < 1e-12)
		#expect(loss > 0.0)
	}

	/// A multi-period control, so the loop itself is exercised: the curve runs
	/// 1.0 -> 1.0 -> 0.9 -> 0.9, a peak-to-trough decline of 10%.
	@Test("MultiPeriod_Control")
	func multiPeriodControl() {
		let measured: Double = MaxDrawdown.calculate(values: [0.0, -0.10, 0.0])
		let peak: Double = 1.0
		let trough: Double = 1.0 + -0.10
		let expected: Double = (peak - trough) / peak
		#expect(abs(measured - expected) < 1e-12)
	}
}

// MARK: - The aggregate that bypassed all of them

@Suite("ComprehensiveRiskMetrics reports what its metrics say")
struct Phase4ComprehensiveRiskMetricsTests {

	/// The aggregate had its own empty-sample block — nine hand-written constants under the
	/// comment "Edge case: no data" — which short-circuited before any of the eight types
	/// were called. Fixing each of them individually would have changed nothing here.
	///
	/// Asserted field by field rather than with `allSatisfy(\.isNaN)`, which does not
	/// compile inside `#expect`.
	@Test("EmptySample_EveryFieldIsUndefined")
	func emptySampleEveryFieldIsUndefined() {
		let metrics = ComprehensiveRiskMetrics(valuesArray: [Double](), riskFreeRate: 0.02)

		#expect(metrics.var95.isNaN)
		#expect(metrics.var99.isNaN)
		#expect(metrics.cvar95.isNaN)
		#expect(metrics.maxDrawdown.isNaN)
		#expect(metrics.sharpeRatio.isNaN)
		#expect(metrics.sortinoRatio.isNaN)
		#expect(metrics.tailRisk.isNaN)
		#expect(metrics.skewness.isNaN)
		#expect(metrics.kurtosis.isNaN)
	}

	/// The control: a real sample still produces a real report, and each field agrees with
	/// the focused type it is built from. Agreement is the property that matters, because the
	/// deleted block was a second implementation that could drift from the first.
	@Test("RealSample_AgreesWithTheFocusedTypes")
	func realSampleAgreesWithFocusedTypes() {
		let returns: [Double] = [0.04, -0.02, 0.06, -0.01, 0.03]
		let metrics = ComprehensiveRiskMetrics(valuesArray: returns, riskFreeRate: 0.01)

		let expectedVar95: Double = ValueAtRisk.var95(values: returns)
		let expectedDrawdown: Double = MaxDrawdown.calculate(values: returns)
		let expectedKurtosis: Double = Kurtosis.calculate(values: returns)

		#expect(abs(metrics.var95 - expectedVar95) < 1e-12)
		#expect(abs(metrics.maxDrawdown - expectedDrawdown) < 1e-12)
		#expect(abs(metrics.kurtosis - expectedKurtosis) < 1e-12)
		#expect(metrics.var95.isFinite)
		#expect(metrics.maxDrawdown > 0.0)
	}
}

// MARK: - Marginal VaR

@Suite("Marginal VaR refuses a derivative that does not exist")
struct Phase4MarginalVaRTests {

	/// The old comment conceded the case and then contradicted itself: "derivative is
	/// undefined; return 0 to avoid NaN". A marginal VaR of 0 says adding exposure to this
	/// entity costs no portfolio risk — the result that makes a position look free to grow.
	@Test("ZeroPortfolioVaR_IsUndefined")
	func zeroPortfolioVaRIsUndefined() {
		let noExposure: [Double] = [0.0, 0.0]
		let correlations: [[Double]] = [[1.0, 0.0], [0.0, 1.0]]

		let marginal: Double = RiskAggregator<Double>.marginalVaR(
			entity: 0,
			individualVaRs: noExposure,
			correlations: correlations
		)
		#expect(marginal.isNaN)
	}

	/// Control, derived from the definition dVaR/dv_i = (C v)_i / √(vᵀ C v). With
	/// v = [100, 0] and the identity correlation matrix, vᵀCv = 10000, so the portfolio VaR
	/// is 100 and (C v)₀ = 100; the marginal is exactly 1.
	@Test("UncorrelatedSingleExposure_IsExactlyOne")
	func uncorrelatedSingleExposure() {
		let exposures: [Double] = [100.0, 0.0]
		let correlations: [[Double]] = [[1.0, 0.0], [0.0, 1.0]]

		let marginal: Double = RiskAggregator<Double>.marginalVaR(
			entity: 0,
			individualVaRs: exposures,
			correlations: correlations
		)

		let portfolioVaR: Double = 10000.0.squareRoot()
		let expected: Double = 100.0 / portfolioVaR

		#expect(abs(marginal - expected) < 1e-12)
		#expect(abs(marginal - 1.0) < 1e-12)
	}

	/// Component VaR keeps its zero, and this records why rather than leaving it to look
	/// like an oversight: Euler allocation's contract is that the components sum to the
	/// portfolio VaR, and zeros satisfy that exactly when the total is zero. A marginal VaR
	/// is a rate and has no such identity to fall back on.
	@Test("ComponentVaR_ZeroTotal_AllocatesZero")
	func componentVaRZeroTotalAllocatesZero() {
		let noExposure: [Double] = [0.0, 0.0]
		let weights: [Double] = [0.5, 0.5]
		let correlations: [[Double]] = [[1.0, 0.0], [0.0, 1.0]]

		let components = RiskAggregator<Double>.componentVaR(
			individualVaRs: noExposure,
			weights: weights,
			correlations: correlations
		)

		#expect(components.count == 2)
		#expect(agree(components, [0.0, 0.0]))
	}
}

// MARK: - Scenario analysis

@Suite("A simulation that produced nothing reports nothing")
struct Phase4ScenarioAnalysisTests {

	/// `percentileFromSorted` guarded the empty case and returned `0.0` — the currency
	/// amount zero, a break-even quarter — and every caller inherited it. The old source
	/// comment defended the value on the grounds that it was "as it always has" been.
	@Test("EmptySimulation_PercentileIsUndefined")
	func emptySimulationPercentileIsUndefined() {
		let simulation = FinancialSimulation(projections: [])
		let p50: Double = simulation.percentile(0.50) { _ in 0.0 }
		#expect(p50.isNaN)
	}

	/// The consequence worth naming separately: both bounds came from the same helper, so a
	/// simulation with no projections reported the interval [0, 0] — perfect certainty about
	/// a number nobody computed.
	@Test("EmptySimulation_ConfidenceIntervalIsUndefined")
	func emptySimulationConfidenceIntervalIsUndefined() {
		let simulation = FinancialSimulation(projections: [])
		let interval = simulation.confidenceInterval(0.95) { _ in 0.0 }
		#expect(interval.lowerBound.isNaN)
		#expect(interval.upperBound.isNaN)
	}

	/// And value at risk, which is the percentile under another name.
	@Test("EmptySimulation_ValueAtRiskIsUndefined")
	func emptySimulationValueAtRiskIsUndefined() {
		let simulation = FinancialSimulation(projections: [])
		let var95: Double = simulation.valueAtRisk(0.95) { _ in 0.0 }
		#expect(var95.isNaN)
	}

	/// `outputRange` is documented as the number to rank drivers by. `0` means the driver
	/// was varied and the output did not move — the finding that gets a driver dropped from
	/// the analysis. An unmeasured driver had been earning it.
	@Test("UnmeasuredSensitivity_OutputRangeIsUndefined")
	func unmeasuredSensitivityIsUndefined() {
		let unmeasured = ScenarioSensitivityAnalysis(
			inputDriver: "Revenue",
			inputValues: [],
			outputValues: []
		)
		#expect(unmeasured.outputRange.isNaN)
	}

	/// Two controls: a driver that genuinely does not move the output keeps its zero, and
	/// one that does reports max - min.
	@Test("MeasuredSensitivity_OutputRangeIsTheSpread")
	func measuredSensitivityIsTheSpread() {
		let flat = ScenarioSensitivityAnalysis(
			inputDriver: "Revenue",
			inputValues: [1.0, 2.0, 3.0],
			outputValues: [500.0, 500.0, 500.0]
		)
		#expect(abs(flat.outputRange - 0.0) < 1e-12)

		let responsive = ScenarioSensitivityAnalysis(
			inputDriver: "Revenue",
			inputValues: [1.0, 2.0, 3.0],
			outputValues: [400.0, 500.0, 750.0]
		)
		let expected: Double = 750.0 - 400.0
		#expect(abs(responsive.outputRange - expected) < 1e-12)
	}
}

// MARK: - Combinatorics: which zeros were counts

@Suite("Combinatorics distinguishes an exact zero from an undefined query")
struct Phase4CombinatoricsTests {

	/// The proof that the negative-input zeros were never a considered convention: the two
	/// functions disagreed with each other about the same input. `factorialDouble(-3)`
	/// answered `0` while `logFactorial(-3)` answered `0` *in log space*, which exponentiates
	/// to 1. Γ has a pole at every non-positive integer; neither value existed.
	@Test("NegativeFactorial_IsUndefinedInBothSpaces")
	func negativeFactorialIsUndefined() {
		#expect(factorialDouble(-3).isNaN)
		#expect(logFactorial(-3).isNaN)
		#expect(factorialDouble(-1).isNaN)
		#expect(logFactorial(-1).isNaN)

		// The old pair, restated: these must now agree, and they agree by both refusing.
		let direct: Double = factorialDouble(-3)
		let viaLog: Double = Foundation.exp(logFactorial(-3))
		#expect(direct.isNaN)
		#expect(viaLog.isNaN)
	}

	/// Controls. 5! = 120 exactly, and its logarithm is the logarithm of that.
	@Test("Factorial_Controls")
	func factorialControls() {
		#expect(abs(factorialDouble(5) - 120.0) < 1e-12)
		#expect(abs(factorialDouble(0) - 1.0) < 1e-12)

		let expectedLog: Double = Foundation.log(120.0)
		#expect(abs(logFactorial(5) - expectedLog) < 1e-12)
		#expect(abs(logFactorial(1) - 0.0) < 1e-12)
	}

	/// `r > n` and a negative argument shared one guard and one `0`. Only the first is a
	/// count: there really are zero ways to choose six elements from five.
	@Test("ChoosingTooMany_IsExactlyZero")
	func choosingTooManyIsZero() {
		#expect(combinationDouble(5, c: 6).isEqual(to: 0.0))
		#expect(permutationDouble(5, p: 6).isEqual(to: 0.0))
		#expect(logCombination(5, c: 6).isEqual(to: -Double.infinity))
		#expect(logPermutation(5, p: 6).isEqual(to: -Double.infinity))
	}

	/// A negative `n` or `r` names no set and no arrangement, so there is no count to report
	/// as zero.
	@Test("NegativeArguments_AreUndefined")
	func negativeArgumentsAreUndefined() {
		#expect(combinationDouble(-1, c: 0).isNaN)
		#expect(combinationDouble(5, c: -1).isNaN)
		#expect(permutationDouble(-1, p: 0).isNaN)
		#expect(permutationDouble(5, p: -1).isNaN)
		#expect(logCombination(-1, c: 0).isNaN)
		#expect(logPermutation(-1, p: 0).isNaN)
	}

	/// Controls, so the refusals above are not satisfied by a function that refuses
	/// everything. C(5, 3) = 10 and P(5, 3) = 60, and the log forms exponentiate to the same.
	@Test("Combinatorics_Controls")
	func combinatoricsControls() {
		#expect(abs(combinationDouble(5, c: 3) - 10.0) < 1e-9)
		#expect(abs(permutationDouble(5, p: 3) - 60.0) < 1e-9)

		let logC: Double = logCombination(5, c: 3)
		let expectedLogC: Double = Foundation.log(10.0)
		#expect(abs(logC - expectedLogC) < 1e-9)

		let logP: Double = logPermutation(5, p: 3)
		let expectedLogP: Double = Foundation.log(60.0)
		#expect(abs(logP - expectedLogP) < 1e-9)
	}

	/// Recorded as kept, not overlooked. The `Int` overloads have no value meaning "no
	/// answer", and `combinationChecked`/`permutationChecked`/`factorialChecked` throw for
	/// callers who need the distinction. A later sweep that "fixes" these to match the
	/// `Double` ones would break this test, which is the point.
	@Test("IntegerOverloads_KeepTheirSentinelZero")
	func integerOverloadsKeepZero() {
		#expect(combination(5, c: 6) == 0)
		#expect(permutation(5, p: 6) == 0)
		#expect(combination(-1, c: 0) == 0)
		#expect(permutation(-1, p: 0) == 0)
		#expect(factorial(-1) == 0)

		// The companion that makes the sentinel safe.
		#expect(throws: BusinessMathError.self) { _ = try factorialChecked(-1) }
		#expect(throws: BusinessMathError.self) { _ = try combinationChecked(-1, c: 0) }
		#expect(throws: BusinessMathError.self) { _ = try permutationChecked(-1, p: 0) }
	}
}

// MARK: - Helpers

/// Elementwise comparison that treats `nan` as matching `nan`. `isEqual(to:)` is IEEE
/// equality, so `Double.nan.isEqual(to: .nan)` is false and a plain `zip`/`allSatisfy` over
/// it would report two identical undefined vectors as different.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
}
