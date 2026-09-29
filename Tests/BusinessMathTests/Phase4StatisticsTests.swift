//
//  Phase4StatisticsTests.swift
//  BusinessMath
//
//  Shape G — `else { return T(0) }` after a validity guard — in `Statistics/`.
//
//  Every test here comes in a pair: the contaminated or degenerate case that used to be
//  answered with a confident zero, and a clean control computed from the same code path
//  whose answer does not move. The controls are what show the suite discriminates rather
//  than merely failing, and each expected value below is derived arithmetically in the
//  test itself rather than quoted from a previous run.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Phase 4 — Statistics: a fallback is an answer")
struct Phase4StatisticsTests {

	// MARK: - withinGroupAutocorrelation

	@Test("Contaminated residuals do not report the absence of autocorrelation")
	func autocorrelationRefusesContamination() throws {
		let grouping = try GroupingFactor([0, 0, 0, 1, 1, 1])
		// One `nan` makes its group's `denominator` `nan`, which fails `> 0` exactly as a
		// constant group does. The group was skipped, the eligible count fell to zero, and
		// the function returned 0.0 — which its own DocC reads as "no temporal dependence
		// within groups", the most reassuring answer a residual diagnostic can give.
		let contaminated: [Double] = [0.1, .nan, 0.3, 0.1, -0.1, 0.0]
		let rho: Double = withinGroupAutocorrelation(residuals: contaminated, grouping: grouping)
		#expect(rho.isNaN, "contaminated residuals reported rho = \(rho)")
	}

	@Test("Clean residuals still give a finite autocorrelation, and one group's absence still gives zero")
	func autocorrelationCleanControl() throws {
		let grouping = try GroupingFactor([0, 0, 0, 1, 1, 1])
		let clean: [Double] = [0.1, -0.2, 0.3, 0.1, -0.1, 0.0]
		let rho: Double = withinGroupAutocorrelation(residuals: clean, grouping: grouping)
		#expect(rho.isFinite, "clean residuals gave \(rho)")

		// The documented structural case: a lone observation has no lag-1 pair. Unchanged.
		let single = try GroupingFactor([0])
		let lone: Double = withinGroupAutocorrelation(residuals: [0.0], grouping: single)
		#expect(lone.isEqual(to: 0.0), "single-observation group gave \(lone)")
	}

	// MARK: - groupInfluence

	@Test("An uncomputable influence is reported per group, not by an empty array")
	func groupInfluencePreservesLength() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1])
		// A diverged fit: the variance components are `nan`, so `p * totalVar` fails `> 0`
		// exactly as a zero denominator does. The empty array this used to return is what a
		// caller following the documented recipe — "flag groups where influence >
		// 4 / groupCount" — iterates over: nothing flagged, which reads as a clean model.
		let diverged = Self.interceptResult(varianceRandom: .nan, varianceResidual: .nan)
		let influence: [Double] = groupInfluence(diverged, grouping: grouping)
		#expect(influence.count == 2, "expected one value per group, got \(influence.count)")
		let allUnknown: Bool = influence.allSatisfy { $0.isNaN }
		#expect(allUnknown, "expected every group marked unknown, got \(influence)")
	}

	@Test("A fitted model's influences are finite and non-negative")
	func groupInfluenceCleanControl() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1])
		let fitted = Self.interceptResult(varianceRandom: 1.0, varianceResidual: 3.0)
		let influence: [Double] = groupInfluence(fitted, grouping: grouping)
		#expect(influence.count == 2, "expected one value per group, got \(influence.count)")
		// D_g = n_g · mean(marginal residual in g)² / (p · (σ_u² + σ_e²)).
		// Group 0 holds (2, -2): mean 0, so D_0 = 0. Group 1 holds (1, 3): mean 2, so
		// D_1 = 2 · 4 / (1 · 4) = 2.
		let expectedFirst: Double = 0.0
		let expectedSecond: Double = 2.0
		#expect(abs(influence[0] - expectedFirst) < 1e-12, "group 0 gave \(influence[0])")
		#expect(abs(influence[1] - expectedSecond) < 1e-12, "group 1 gave \(influence[1])")
	}

	// MARK: - kernelWeights

	@Test("A compact kernel refuses a contaminated pair rather than weighting it zero")
	func kernelWeightsRefusesContamination() throws {
		// `abs(nan) <= 1` is false exactly as it is for a distant point, so the pair took a
		// weight of zero and dropped out of the weighted agreement — array length intact,
		// nothing to say an observation had been discarded. The Gaussian kernel propagated
		// the `nan` instead, so which answer you got depended on the kernel.
		#expect(throws: BusinessMathError.dataQuality(
			message: "Kernel weights require finite observations",
			context: ["invalid_count": "1"])) {
			_ = try kernelWeights([0.0, Double.nan, 4.0], [0.0, 2.0, 4.0],
								  target: 0.0, bandwidth: 1.0, kernel: .epanechnikov)
		}
	}

	@Test("Epanechnikov still weights a genuinely distant pair at zero")
	func kernelWeightsCleanControl() throws {
		let weights: [Double] = try kernelWeights([0.0, 2.0, 4.0], [0.0, 2.0, 4.0],
												  target: 0.0, bandwidth: 1.0,
												  kernel: .epanechnikov)
		// K(0) = 3/4 at the centre; |u| = 2 and 4 are outside the support, where zero is
		// the kernel's real value rather than a fallback.
		let peak: Double = 3.0 / 4.0
		#expect(abs(weights[0] - peak) < 1e-12, "centre weight was \(weights[0])")
		#expect(weights[1].isEqual(to: 0.0), "|u| = 2 weighted \(weights[1])")
		#expect(weights[2].isEqual(to: 0.0), "|u| = 4 weighted \(weights[2])")
	}

	// MARK: - Array2D.kendallW

	@Test("One item is not a measured absence of agreement")
	func array2DKendallWSingleColumn() {
		// The interpretation table on this method reads 0.0 as "No agreement beyond
		// chance" — a finding about judges who were never given two things to rank. The
		// free `kendallW(_:)` and `kendallWFromRankSums` both answer `nan` here, and so
		// does this type's own `fStatistic()`, which passes the same column count on.
		var array = Array2D<Double>(columns: 1, rows: 5, initialValue: 0.0)
		for row in 0..<5 { array[0, row] = 1.0 }
		let w: Double = array.kendallW()
		#expect(w.isNaN, "a single item reported W = \(w)")
	}

	@Test("Four items in perfect agreement still give W = 1")
	func array2DKendallWCleanControl() {
		var array = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)
		for row in 0..<3 {
			for col in 0..<4 { array[col, row] = Double(col + 1) }
		}
		let w: Double = array.kendallW()
		#expect(abs(w - 1.0) < 1e-12, "perfect agreement gave \(w)")
	}

	// MARK: - kurtosisP

	@Test("An empty sample is not exactly normal-tailed")
	func kurtosisPEmptySample() {
		// Excess kurtosis of zero means normal-tailed. A sample with no observations has no
		// tails; `varianceP` and `stdDevP`, which this function calls, both answer `nan`.
		let empty: [Double] = []
		let k: Double = kurtosisP(empty)
		#expect(k.isNaN, "an empty sample reported excess kurtosis \(k)")
	}

	@Test("A two-valued symmetric sample still gives its exact excess kurtosis")
	func kurtosisPCleanControl() {
		// mean 0, population variance (1+1+1+1)/4 = 1, so s = 1 and each standardised
		// deviate is ±1. The fourth moment is 4/4 = 1, and excess kurtosis is 1 − 3 = −2.
		let values: [Double] = [-1.0, -1.0, 1.0, 1.0]
		let k: Double = kurtosisP(values)
		let expected: Double = -2.0
		#expect(abs(k - expected) < 1e-12, "got \(k)")
	}

	// MARK: - binomialPMF

	@Test("An unreadable success probability is not an impossible outcome")
	func binomialPMFContaminatedProbability() {
		// `nan >= 0` and `nan <= 1` are both false, so a contaminated `p` fell into the
		// out-of-range branch and the function reported a probability of exactly zero —
		// "this outcome cannot occur" — which is what a likelihood multiplies by.
		let probability: Double = binomialPMF(n: 10, k: 3, p: Double.nan)
		#expect(probability.isNaN, "a NaN p gave P = \(probability)")
	}

	@Test("A fair coin and an out-of-range probability are both unchanged")
	func binomialPMFCleanControl() {
		// C(10,3) = 120 and p^3(1−p)^7 = 2^-10 at p = 1/2, so P = 120/1024 exactly.
		let fair: Double = binomialPMF(n: 10, k: 3, p: 0.5)
		let expected: Double = 120.0 / 1024.0
		#expect(abs(fair - expected) < 1e-15, "got \(fair)")
		// A readable-but-invalid probability keeps its documented zero: that guard is not
		// what changed.
		let invalid: Double = binomialPMF(n: 10, k: 3, p: 1.5)
		#expect(invalid.isEqual(to: 0.0), "p = 1.5 gave \(invalid)")
	}

	// MARK: - poissonCDF

	@Test("An unreadable count is not a cumulative probability of zero, and an infinite one does not hang")
	func poissonCDFBoundaryArguments() {
		// The rate guard three lines below already answered `nan` for a rate it could not
		// read; the argument was answered `T(0)`, a definite P(X ≤ x) = 0 and therefore a
		// survival probability of exactly 1 for the caller who takes the complement.
		let contaminated: Double = poissonCDF(Double.nan, µ: 2.0)
		#expect(contaminated.isNaN, "a NaN count gave P = \(contaminated)")
		// `(+∞).rounded(.down)` is `+∞`, and the `while T(n) < floored` loop that finds the
		// summation limit never terminates on it. Stated exactly instead: every Poisson
		// outcome lies below infinity.
		let unbounded: Double = poissonCDF(Double.infinity, µ: 2.0)
		#expect(unbounded.isEqual(to: 1.0), "P(X ≤ +∞) gave \(unbounded)")
	}

	@Test("Below the support and at zero, the Poisson CDF is unchanged")
	func poissonCDFCleanControl() {
		let below: Double = poissonCDF(-1.0, µ: 2.0)
		#expect(below.isEqual(to: 0.0), "P(X ≤ −1) gave \(below)")
		// P(X ≤ 0) = P(X = 0) = e^(−µ).
		let atZero: Double = poissonCDF(0.0, µ: 2.0)
		let expected: Double = Double.exp(-2.0)
		#expect(abs(atZero - expected) < 1e-14, "got \(atZero)")
	}

	// MARK: - exponential and lognormal

	@Test("An unreadable time is not a failure probability of zero")
	func exponentialRefusesContamination() {
		// The reliability reading: `1 − exponentialCDF(t)` came back as exactly 1 —
		// "nothing has failed yet" — from a `t` the function could not read. A contaminated
		// rate already propagated a `nan` through the arithmetic, so the two disagreed.
		let cdf: Double = exponentialCDF(Double.nan, λ: 0.5)
		#expect(cdf.isNaN, "a NaN time gave F = \(cdf)")
		let pdf: Double = exponentialPDF(Double.nan, λ: 0.5)
		#expect(pdf.isNaN, "a NaN time gave f = \(pdf)")
		let logNormal: Double = logNormalCDF(Double.nan, mean: 0.0, stdDev: 1.0)
		#expect(logNormal.isNaN, "a NaN argument gave F = \(logNormal)")
	}

	@Test("Below the support and at a known point, the exponential and lognormal are unchanged")
	func exponentialCleanControl() {
		let belowCDF: Double = exponentialCDF(-1.0, λ: 0.5)
		#expect(belowCDF.isEqual(to: 0.0), "F(−1) gave \(belowCDF)")
		// F(2) = 1 − e^(−λ·2) with λ = 1/2, so the exponent is exactly −1.
		let cdf: Double = exponentialCDF(2.0, λ: 0.5)
		let expectedCDF: Double = 1.0 - Double.exp(-1.0)
		#expect(abs(cdf - expectedCDF) < 1e-14, "got \(cdf)")
		// f(2) = λ·e^(−λ·2), same exponent.
		let pdf: Double = exponentialPDF(2.0, λ: 0.5)
		let expectedPDF: Double = 0.5 * Double.exp(-1.0)
		#expect(abs(pdf - expectedPDF) < 1e-14, "got \(pdf)")
		// ln(1) = 0, so the standardised score is 0 and the normal CDF there is 1/2.
		let logNormal: Double = logNormalCDF(1.0, mean: 0.0, stdDev: 1.0)
		#expect(abs(logNormal - 0.5) < 1e-12, "got \(logNormal)")
		// P(X ≤ 0) = 0 for a lognormal: that support guard is not what changed.
		let atZero: Double = logNormalCDF(0.0, mean: 0.0, stdDev: 1.0)
		#expect(atZero.isEqual(to: 0.0), "F(0) gave \(atZero)")
	}

	// MARK: - Brier score on unbounded scores

	@Test("An unbounded score overflows the Brier score and leaves the curve intact")
	func brierScoreOnUnboundedScores() throws {
		// Decided, not fixed. `ClassifierEvaluation` admits any finite score on purpose,
		// because a raw margin is only ever ordered; `(1e308 − 1)²` then overflows. The
		// infinity is left as it is: it is arithmetically honest and it sits at the *worst*
		// end of a loss scale, so a caller ranking models by it puts this one last. A `nan`
		// would be worse — it compares false against everything, which would make the
		// ranking unspecified rather than merely extreme.
		let evaluation = try #require(ClassifierEvaluation(scores: [1e308, 0.2],
														   outcomes: [true, false]))
		let curve = evaluation.calibration(buckets: 2)
		#expect(curve.brierScore.isInfinite, "got \(curve.brierScore)")
		#expect(curve.points.count == 2, "expected both buckets occupied, got \(curve.points.count)")
		// The curve itself is unharmed: the clamp puts the unbounded score in the top
		// bucket, where the observed rate is 1, and the low bucket's observed rate is 0.
		let lowObserved: Double = curve.points[0].observedRate
		let highObserved: Double = curve.points[1].observedRate
		#expect(lowObserved.isEqual(to: 0.0), "low bucket observed \(lowObserved)")
		#expect(highObserved.isEqual(to: 1.0), "top bucket observed \(highObserved)")
	}

	@Test("Probability scores give a finite Brier score on the same code path")
	func brierScoreCleanControl() throws {
		let evaluation = try #require(ClassifierEvaluation(scores: [0.8, 0.2],
														   outcomes: [true, false]))
		let curve = evaluation.calibration(buckets: 2)
		// mean((0.8 − 1)² , (0.2 − 0)²) = (0.04 + 0.04) / 2 = 0.04.
		let expected: Double = 0.04
		#expect(abs(curve.brierScore - expected) < 1e-15, "got \(curve.brierScore)")
	}
}

// MARK: - Fixtures

extension Phase4StatisticsTests {

	/// A minimal two-group ``RandomInterceptResult`` whose variance components and marginal
	/// residuals are set directly, so a diverged fit can be presented to a diagnostic
	/// without running one.
	///
	/// Marginal residuals are `(2, −2)` in group 0 and `(1, 3)` in group 1, chosen so the
	/// group means are 0 and 2 — a group that contributes nothing and one that contributes
	/// a computable amount, rather than two that are the same.
	static func interceptResult(varianceRandom: Double,
								varianceResidual: Double) -> RandomInterceptResult<Double> {
		RandomInterceptResult(
			beta: [0.0],
			standardErrors: [1.0],
			tStatistics: [0.0],
			pValues: [1.0],
			varianceRandom: varianceRandom,
			varianceResidual: varianceResidual,
			icc: 0.25,
			remlLogLikelihood: -1.0,
			aic: 4.0,
			bic: 4.0,
			randomEffects: [0.0, 0.0],
			residuals: [2.0, -2.0, 1.0, 3.0],
			marginalResiduals: [2.0, -2.0, 1.0, 3.0],
			fittedValues: [0.0, 0.0, 0.0, 0.0],
			observations: 4,
			groups: 2,
			fixedEffectsCount: 1,
			iterations: 1,
			converged: true)
	}
}
