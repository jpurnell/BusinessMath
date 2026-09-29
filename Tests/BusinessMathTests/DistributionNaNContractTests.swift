//
//  DistributionNaNContractTests.swift
//  BusinessMathTests
//
//  The NaN clause of ``ContinuousDistribution``, asserted across every conformer at once.
//
//  Until v3.0.0-alpha.7 a `cdf` handed a NaN answered **0** — not by decision but because
//  `nan > min` is false like every comparison against a NaN, so the support guard caught it
//  and returned "P(X ≤ x) = 0" for an argument the function could not read. A caller taking
//  the complement got a survival probability of exactly 1. The conformers that happened to
//  propagate instead, and the four that screened `isFinite` and so filed a NaN with the
//  infinities, disagreed with them — which made the inconsistency the defect rather than any
//  one file. `quantile` was worse: the same NaN drew six different answers across the family,
//  from the support minimum to `+infinity`.
//
//  So the assertion that matters here is **uniformity**, not any individual value. Every
//  conformer is driven through one parameterised test, so a conformer added later that
//  forgets the rule fails on the day it lands rather than the day someone divides by its
//  answer.
//
//  The controls are the other half. Three behaviours share those guards and are *correct*:
//  a finite argument below the support is still 0, `cdf(-infinity)` is still 0, and
//  `cdf(+infinity)` is still 1. An infinity is an ordered point on the line and its CDF is
//  the limit; only the NaN path moved. Screening `isFinite` instead of `isNaN` would have
//  passed every assertion in the first half of this file and broken every one in the second,
//  which is the single most likely way to get this wrong.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("The NaN contract on ContinuousDistribution")
struct DistributionNaNContractTests {

	// MARK: - The conformers, as a uniform pair of functions

	/// One conformer, reduced to the two functions the contract speaks about.
	///
	/// `ContinuousDistribution` has an associated type, so a heterogeneous list needs either
	/// an existential or this. Closures are chosen because the sweep calls nothing else on
	/// these types, and because capturing the constructed value keeps each initialiser's
	/// arguments on the same line as the name they belong to.
	struct Conformer: Sendable {
		let name: String
		let cdf: @Sendable (Double) -> Double
		let quantile: @Sendable (Double) -> Double
	}

	/// Wraps a constructed distribution, so the list below reads as one line per conformer.
	private static func entry<D: ContinuousDistribution & Sendable>(
		_ name: String, _ distribution: D
	) -> Conformer where D.T == Double {
		Conformer(name: name,
				  cdf: { distribution.cdf($0) },
				  quantile: { distribution.quantile($0) })
	}

	/// Every `ContinuousDistribution` in the package, each with parameters inside its own
	/// admissible range.
	///
	/// Hoisted out of the `@Test` macro rather than written as a literal in `arguments:` —
	/// the macro expands its argument into generic closures, and this project has already
	/// lost a CI run to an array literal that was fine as a plain `let`.
	static let conformers: [Conformer] = buildConformers()

	/// How many types conform to `ContinuousDistribution` in `Sources/BusinessMath/Simulation`.
	///
	/// Counted from the declarations, not from this file, and asserted against the built list
	/// so that a failed initialiser cannot quietly shrink the sweep to whatever happened to
	/// construct. A fixture that does not prove it contains what it claims is not a fixture.
	static let declaredConformerCount = 46

	private static func buildConformers() -> [Conformer] {
		var built: [Conformer] = []
		built.append(contentsOf: nonFailableConformers())
		built.append(contentsOf: failableConformers())
		built.append(contentsOf: throwingConformers())
		return built
	}

	private static func nonFailableConformers() -> [Conformer] {
		// `5 as Int` rather than `5`: both `DistributionChiSquared` and `DistributionStudentT`
		// declare an `Int` and a `Double` initialiser under the same label, and an untyped
		// integer literal satisfies either.
		[
			entry("Beta", DistributionBeta(alpha: 2, beta: 3)),
			entry("ChiSquared", DistributionChiSquared(degreesOfFreedom: 5 as Int)),
			entry("Exponential", DistributionExponential(0.5)),
			entry("F", DistributionF(df1: 5, df2: 9)),
			entry("LogNormal", DistributionLogNormal(logMean: 0, logStdDev: 1)),
			entry("Logistic", DistributionLogistic(0, 1)),
			entry("Normal", DistributionNormal(0, 1)),
			entry("Pareto", DistributionPareto(scale: 2, shape: 3)),
			entry("Rayleigh", DistributionRayleigh(scale: 1)),
			entry("T", DistributionT(degreesOfFreedom: 5)),
			entry("Triangular", DistributionTriangular(low: 0, high: 10, base: 5)),
			entry("Uniform", DistributionUniform(0, 1)),
			entry("Weibull", DistributionWeibull(shape: 2, scale: 1))
		]
	}

	/// The failable initialisers. A `nil` drops its conformer from the sweep, which
	/// ``fixtureCoversEveryConformer()`` turns into a failure rather than a smaller pass.
	private static func failableConformers() -> [Conformer] {
		var built: [Conformer] = []
		if let d = DistributionBetaGeneralised(shape1: 2, shape2: 3, min: 0, max: 10) {
			built.append(entry("BetaGeneralised", d))
		}
		if let d = DistributionBetaSubjective(min: 0, likely: 4, mean: 5, max: 10) {
			built.append(entry("BetaSubjective", d))
		}
		if let d = DistributionBurr12(location: 0, scale: 1, shape1: 2, shape2: 3) {
			built.append(entry("Burr12", d))
		}
		if let d = DistributionDagum(location: 0, scale: 1, shape1: 2, shape2: 3) {
			built.append(entry("Dagum", d))
		}
		if let d = DistributionCauchy(location: 0, scale: 1) {
			built.append(entry("Cauchy", d))
		}
		if let d = DistributionCumul(lower: 0, upper: 10, values: [5], probabilities: [0.5]) {
			built.append(entry("Cumul", d))
		}
		if let d = DistributionDoubleTriangular(min: 0, likely: 5, max: 10, p: 0.5) {
			built.append(entry("DoubleTriangular", d))
		}
		if let d = DistributionErf(h: 1) {
			built.append(entry("Erf", d))
		}
		if let d = DistributionErlang(stages: 3, scale: 2) {
			built.append(entry("Erlang", d))
		}
		if let d = DistributionFatigueLife(location: 0, scale: 1, shape: 0.5) {
			built.append(entry("FatigueLife", d))
		}
		if let d = DistributionFrechet(location: 0, scale: 1, shape: 2) {
			built.append(entry("Frechet", d))
		}
		if let d = DistributionGamma(shape: 2, scale: 3) {
			built.append(entry("Gamma", d))
		}
		if let d = DistributionGeneral(lower: 0, upper: 10,
									   values: [0, 5, 10], weights: [1, 2, 1]) {
			built.append(entry("General", d))
		}
		if let d = DistributionHistogram(min: 0, max: 10, weights: [1, 2, 3, 2, 1]) {
			built.append(entry("Histogram", d))
		}
		if let d = DistributionHypSecant(loc: 0, scale: 1) {
			built.append(entry("HypSecant", d))
		}
		if let d = DistributionInverseGaussian(mu: 1, lambda: 2) {
			built.append(entry("InverseGaussian", d))
		}
		if let d = DistributionJohnsonSB(shape1: 0, shape2: 1, min: 0, max: 10) {
			built.append(entry("JohnsonSB", d))
		}
		if let d = DistributionJohnsonSU(shape1: 0, shape2: 1, location: 0, scale: 1) {
			built.append(entry("JohnsonSU", d))
		}
		if let d = DistributionKumaraswamy(shape1: 2, shape2: 3, min: 0, max: 1) {
			built.append(entry("Kumaraswamy", d))
		}
		if let d = DistributionLaplace(location: 0, scale: 1) {
			built.append(entry("Laplace", d))
		}
		if let d = DistributionLevy(location: 0, scale: 1) {
			built.append(entry("Levy", d))
		}
		if let d = DistributionLogLogistic(location: 0, scale: 1, shape: 2) {
			built.append(entry("LogLogistic", d))
		}
		if let d = DistributionMaxExtreme(location: 0, scale: 1) {
			built.append(entry("MaxExtreme", d))
		}
		if let d = DistributionMinExtreme(location: 0, scale: 1) {
			built.append(entry("MinExtreme", d))
		}
		if let d = DistributionMyerson(low: 1, mode: 2, high: 4) {
			built.append(entry("Myerson", d))
		}
		if let d = DistributionPareto2(scale: 2, shape: 3) {
			built.append(entry("Pareto2", d))
		}
		if let d = DistributionPearson5(alpha: 3, beta: 2) {
			built.append(entry("Pearson5", d))
		}
		if let d = DistributionPearson6(alpha1: 2, alpha2: 3, beta: 1) {
			built.append(entry("Pearson6", d))
		}
		if let d = DistributionPert(min: 0, likely: 5, max: 10) {
			built.append(entry("Pert", d))
		}
		if let d = DistributionReciprocal(min: 1, max: 10) {
			built.append(entry("Reciprocal", d))
		}
		if let d = DistributionStudentT(degreesOfFreedom: 5 as Int) {
			built.append(entry("StudentT", d))
		}
		return built
	}

	private static func throwingConformers() -> [Conformer] {
		var built: [Conformer] = []
		// a₁ + a₂·ln(p/(1−p)) with a₂ positive is the logistic, which is increasing on (0, 1)
		// and so passes the feasibility check the initialiser runs.
		if let d = try? DistributionMetalog(coefficients: [0, 1], boundedness: .unbounded) {
			built.append(entry("Metalog", d))
		}
		if let d = try? DistributionMomentFit(mean: 0, standardDeviation: 1,
											  skewness: 0, kurtosis: 3) {
			built.append(entry("MomentFit", d))
		}
		return built
	}

	// MARK: - The fixture proves it contains what it claims

	/// Every declared conformer built, and none silently missing.
	///
	/// Without this the sweep below would still pass with half the list, and a `nil`
	/// initialiser would read as a green run.
	@Test("Every conformer is present in the sweep")
	func fixtureCoversEveryConformer() {
		let built: Int = Self.conformers.count
		let declared: Int = Self.declaredConformerCount
		#expect(built == declared,
				"built \(built) of \(declared); a failed initialiser drops its conformer from the sweep silently")

		let names: Set<String> = Set(Self.conformers.map(\.name))
		let distinct: Int = names.count
		#expect(distinct == built,
				"the fixture names \(built) conformers but \(distinct) are distinct, so one is being asserted twice and another not at all")
	}

	// MARK: - The rule

	/// `cdf(nan)` is `nan`, for every conformer.
	@Test("cdf answers a NaN with a NaN", arguments: DistributionNaNContractTests.conformers)
	func cdfOfNaNIsNaN(conformer: Conformer) {
		let answer: Double = conformer.cdf(Double.nan)
		let isNotANumber: Bool = answer.isNaN
		#expect(isNotANumber, "\(conformer.name).cdf(nan) returned \(answer)")
	}

	/// `quantile(nan)` is `nan`, for every conformer.
	@Test("quantile answers a NaN with a NaN",
		  arguments: DistributionNaNContractTests.conformers)
	func quantileOfNaNIsNaN(conformer: Conformer) {
		let answer: Double = conformer.quantile(Double.nan)
		let isNotANumber: Bool = answer.isNaN
		#expect(isNotANumber, "\(conformer.name).quantile(nan) returned \(answer)")
	}

	/// A NaN cannot be laundered into a value by going round the loop.
	///
	/// The round trip is how a NaN used to become a number: `cdf(nan)` gave `0`, and
	/// `quantile(0)` gave the support minimum — a finite, plottable value with nothing left
	/// on it to say where it came from.
	@Test("A NaN survives the round trip", arguments: DistributionNaNContractTests.conformers)
	func roundTripDoesNotLaunderNaN(conformer: Conformer) {
		let probability: Double = conformer.cdf(Double.nan)
		let backAgain: Double = conformer.quantile(probability)
		let isNotANumber: Bool = backAgain.isNaN
		#expect(isNotANumber,
				"\(conformer.name): quantile(cdf(nan)) returned \(backAgain), a value for an argument that was never readable")
	}

	// MARK: - Controls: what must NOT have changed

	/// CONTROL. A **finite** argument below the support is still exactly 0.
	///
	/// This is the clause `ContinuousDistribution` promises so a caller can plot across a
	/// range without knowing where the support ends. Each value below is strictly under its
	/// distribution's lower bound and strictly finite, so it exercises the support guard the
	/// NaN screen now sits in front of, rather than the screen itself.
	@Test("A finite argument below the support is still zero")
	func finiteArgumentBelowSupportIsStillZero() throws {
		let pareto = DistributionPareto(scale: 2, shape: 3)
		let belowScale: Double = pareto.cdf(1.0)
		#expect(belowScale.isEqual(to: 0.0), "Pareto below xₘ; got \(belowScale)")

		let weibull = DistributionWeibull(shape: 2, scale: 1)
		let belowZero: Double = weibull.cdf(-1.0)
		#expect(belowZero.isEqual(to: 0.0), "Weibull below zero; got \(belowZero)")

		let rayleigh = DistributionRayleigh(scale: 1)
		let rayleighBelow: Double = rayleigh.cdf(-1.0)
		#expect(rayleighBelow.isEqual(to: 0.0), "Rayleigh below zero; got \(rayleighBelow)")

		let lomax = try #require(DistributionPareto2(scale: 2, shape: 3))
		let lomaxBelow: Double = lomax.cdf(-1.0)
		#expect(lomaxBelow.isEqual(to: 0.0), "Pareto2 below zero; got \(lomaxBelow)")

		let kumaraswamy = try #require(DistributionKumaraswamy(shape1: 2, shape2: 3,
															   min: 0, max: 1))
		let kumaraswamyBelow: Double = kumaraswamy.cdf(-0.5)
		#expect(kumaraswamyBelow.isEqual(to: 0.0),
				"Kumaraswamy below min; got \(kumaraswamyBelow)")

		let pert = try #require(DistributionPert(min: 0, likely: 5, max: 10))
		let pertBelow: Double = pert.cdf(-1.0)
		#expect(pertBelow.isEqual(to: 0.0), "Pert below min; got \(pertBelow)")

		// And above the support it is still exactly one, the other half of the same clause.
		let pertAbove: Double = pert.cdf(11.0)
		#expect(pertAbove.isEqual(to: 1.0), "Pert above max; got \(pertAbove)")
	}

	/// CONTROL. `cdf(-infinity)` is 0 and `cdf(+infinity)` is 1.
	///
	/// An infinity is not a NaN. It is an ordered point on the line and its CDF is the limit,
	/// so the infinity path is left exactly as it was. The first four conformers here are the
	/// ones that reach those limits through `guard x.isFinite else { return x > 0 ? 1 : 0 }`
	/// — the guard that gets both infinities right and used to land a NaN on `0` alongside
	/// them. They are the whole reason the fix screens `isNaN` rather than `isFinite`: the
	/// lazier screen passes every assertion above this line and breaks every one below it.
	@Test("Infinities still answer with their limits")
	func infinitiesStillAnswerWithTheirLimits() throws {
		let metalog = try DistributionMetalog(coefficients: [0, 1], boundedness: .unbounded)
		let metalogLow: Double = metalog.cdf(-Double.infinity)
		let metalogHigh: Double = metalog.cdf(Double.infinity)
		#expect(metalogLow.isEqual(to: 0.0), "Metalog at -inf; got \(metalogLow)")
		#expect(metalogHigh.isEqual(to: 1.0), "Metalog at +inf; got \(metalogHigh)")

		let momentFit = try DistributionMomentFit(mean: 0, standardDeviation: 1,
												  skewness: 0, kurtosis: 3)
		let momentFitLow: Double = momentFit.cdf(-Double.infinity)
		let momentFitHigh: Double = momentFit.cdf(Double.infinity)
		#expect(momentFitLow.isEqual(to: 0.0), "MomentFit at -inf; got \(momentFitLow)")
		#expect(momentFitHigh.isEqual(to: 1.0), "MomentFit at +inf; got \(momentFitHigh)")

		let myerson = try #require(DistributionMyerson(low: 1, mode: 2, high: 4))
		let myersonLow: Double = myerson.cdf(-Double.infinity)
		let myersonHigh: Double = myerson.cdf(Double.infinity)
		#expect(myersonLow.isEqual(to: 0.0), "Myerson at -inf; got \(myersonLow)")
		#expect(myersonHigh.isEqual(to: 1.0), "Myerson at +inf; got \(myersonHigh)")

		let studentT = try #require(DistributionStudentT(degreesOfFreedom: 5 as Int))
		let studentLow: Double = studentT.cdf(-Double.infinity)
		let studentHigh: Double = studentT.cdf(Double.infinity)
		#expect(studentLow.isEqual(to: 0.0), "StudentT at -inf; got \(studentLow)")
		#expect(studentHigh.isEqual(to: 1.0), "StudentT at +inf; got \(studentHigh)")

		// Four more that reach the limits through ordinary arithmetic or a support guard
		// rather than through a finiteness screen, so both routes are covered.
		let normal = DistributionNormal(0, 1)
		let normalLow: Double = normal.cdf(-Double.infinity)
		let normalHigh: Double = normal.cdf(Double.infinity)
		#expect(normalLow.isEqual(to: 0.0), "Normal at -inf; got \(normalLow)")
		#expect(normalHigh.isEqual(to: 1.0), "Normal at +inf; got \(normalHigh)")

		let uniform = DistributionUniform(0, 1)
		let uniformLow: Double = uniform.cdf(-Double.infinity)
		let uniformHigh: Double = uniform.cdf(Double.infinity)
		#expect(uniformLow.isEqual(to: 0.0), "Uniform at -inf; got \(uniformLow)")
		#expect(uniformHigh.isEqual(to: 1.0), "Uniform at +inf; got \(uniformHigh)")

		let cauchy = try #require(DistributionCauchy(location: 0, scale: 1))
		let cauchyLow: Double = cauchy.cdf(-Double.infinity)
		let cauchyHigh: Double = cauchy.cdf(Double.infinity)
		#expect(cauchyLow.isEqual(to: 0.0), "Cauchy at -inf; got \(cauchyLow)")
		#expect(cauchyHigh.isEqual(to: 1.0), "Cauchy at +inf; got \(cauchyHigh)")

		let exponential = DistributionExponential(0.5)
		let exponentialLow: Double = exponential.cdf(-Double.infinity)
		let exponentialHigh: Double = exponential.cdf(Double.infinity)
		#expect(exponentialLow.isEqual(to: 0.0), "Exponential at -inf; got \(exponentialLow)")
		#expect(exponentialHigh.isEqual(to: 1.0), "Exponential at +inf; got \(exponentialHigh)")
	}

	/// CONTROL. The interior is untouched.
	///
	/// A guard placed at the top of a function is the cheapest possible way to change an
	/// answer it was not meant to change. The tolerance is loose on purpose: this is not an
	/// accuracy test — `DistributionRetrofitTests` owns that, against a reference — it asks
	/// whether the guard swallowed an ordinary value, and every way it could have would move
	/// the median to a support bound or an infinity, not to the seventh decimal.
	@Test("The interior is unchanged", arguments: DistributionNaNContractTests.conformers)
	func interiorIsUnchanged(conformer: Conformer) throws {
		let median: Double = conformer.quantile(0.5)
		let medianIsUsable: Bool = median.isFinite
		try #require(medianIsUsable, "\(conformer.name).quantile(0.5) returned \(median)")

		let backAgain: Double = conformer.cdf(median)
		let roundTripError: Double = abs(backAgain - 0.5)
		#expect(roundTripError < 1e-4,
				"\(conformer.name): cdf(quantile(0.5)) = \(backAgain), off by \(roundTripError)")

		let lower: Double = conformer.quantile(0.25)
		let upper: Double = conformer.quantile(0.75)
		let increasing: Bool = lower <= median && median <= upper
		#expect(increasing,
				"\(conformer.name): quantile is not increasing across 0.25/0.5/0.75 — \(lower), \(median), \(upper)")
	}
}
