//
//  InverseTransformSeedingTests.swift
//  BusinessMath
//
//  The three entry points every inverse-transform sampler now has, and what each one means.
//

import Testing
import TestSupport
import Foundation
@testable import BusinessMath

/// `quantileAt:`, `seed:` and `using:` on the inverse-transform families.
///
/// These five families used to have one entry point, `seed: Double?`, and it was not a
/// sampler: with a uniform supplied it *is* the quantile function evaluated at that uniform,
/// and with `nil` it drew one itself. That left `seed:` meaning a `UInt64` stream on the
/// rejection-based families (Gamma, Beta, t, χ², F, geometric) and a uniform in `(0, 1)` on
/// these — one label, two meanings, in one API.
///
/// Now each family has three, and the names say which is which:
///
/// - **`quantileAt u:`** — the quantile function at `u`. Deterministic, no generator involved,
///   and testable against a closed form at full precision rather than through a sample mean.
/// - **`seed: UInt64?`** — a draw from a named stream, matching every other sampler.
/// - **`using: inout G`** — a draw from the caller's generator, so one stream can feed several
///   families in a known order.
///
/// The uniform for the latter two comes from ``openUnitUniform(_:using:)``, on the **open**
/// interval: every quantile here takes a logarithm or a reciprocal, so an endpoint turns a
/// legal uniform into a non-finite variate.
@Suite("Inverse-transform seeding")
struct InverseTransformSeedingTests {

	// MARK: - The quantile at a half is the median, in closed form

	@Test("At u = 0.5 each family returns its analytic median")
	func mediansAtHalf() {
		// Closed forms, so these are equalities rather than tolerances on a sample.
		let halfLog: Double = Foundation.log(2.0)

		let exponential: Double = distributionExponential(λ: 2.0, quantileAt: 0.5)
		#expect(abs(exponential - halfLog / 2.0) < 1e-15, "exponential median \(exponential)")

		let pareto: Double = distributionPareto(scale: 1.0, shape: 2.0, quantileAt: 0.5)
		#expect(abs(pareto - 2.0.squareRoot()) < 1e-14, "Pareto median \(pareto)")

		let weibull: Double = distributionWeibull(shape: 2.0, scale: 5.0, quantileAt: 0.5)
		#expect(abs(weibull - 5.0 * halfLog.squareRoot()) < 1e-14, "Weibull median \(weibull)")

		// σ√(2 ln 2) either way: u = 0.5 is the one point that cannot tell `u` from `1 − u`,
		// which is why the grid tests below exist and why Rayleigh's inverted convention
		// survived until one of them ran.
		let rayleighTarget: Double = 10.0 * (2.0 * halfLog).squareRoot()
		let rayleigh: Double = distributionRayleigh(scale: 10.0, quantileAt: 0.5)
		#expect(abs(rayleigh - rayleighTarget) < 1e-14, "Rayleigh median \(rayleigh)")

		// The logistic quantile is μ + s·ln(u/(1−u)), and ln(1) is exactly zero, so this one
		// is exact rather than nearly so.
		let logistic: Double = distributionLogistic(50.0, 10.0, quantileAt: 0.5)
		#expect(identical(logistic, 50.0), "logistic median \(logistic)")
	}

	// MARK: - The quantile across a grid

	/// Plain literals: arithmetic inside an array literal fed through the `@Test` macro is
	/// what makes the type checker give up.
	static let grid: [Double] = [0.001, 0.01, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.99, 0.999]

	@Test("The exponential quantile is −ln(1−u)/λ across the grid",
		  arguments: InverseTransformSeedingTests.grid)
	func exponentialQuantile(u: Double) {
		let actual: Double = distributionExponential(λ: 2.0, quantileAt: u)
		let expected: Double = -Foundation.log(1.0 - u) / 2.0
		#expect(abs(actual - expected) < 1e-13 * Swift.max(1.0, expected),
				"u \(u): got \(actual), closed form \(expected)")
	}

	@Test("The Weibull quantile is λ(−ln(1−u))^(1/k) across the grid",
		  arguments: InverseTransformSeedingTests.grid)
	func weibullQuantile(u: Double) {
		let actual: Double = distributionWeibull(shape: 2.0, scale: 5.0, quantileAt: u)
		let inner: Double = -Foundation.log(1.0 - u)
		let expected: Double = 5.0 * Foundation.pow(inner, 0.5)
		#expect(abs(actual - expected) < 1e-13 * Swift.max(1.0, expected),
				"u \(u): got \(actual), closed form \(expected)")
	}

	@Test("The Rayleigh quantile is σ√(−2 ln(1−u)) across the grid",
		  arguments: InverseTransformSeedingTests.grid)
	func rayleighQuantile(u: Double) {
		let actual: Double = distributionRayleigh(scale: 3.0, quantileAt: u)
		let inner: Double = -2.0 * Foundation.log(1.0 - u)
		let expected: Double = 3.0 * inner.squareRoot()
		#expect(abs(actual - expected) < 1e-13 * Swift.max(1.0, expected),
				"u \(u): got \(actual), closed form \(expected)")
	}

	// MARK: - The free function and the type are the same function

	@Test("quantileAt: agrees with the type's own quantile, in all five families",
		  arguments: InverseTransformSeedingTests.grid)
	func freeFunctionMatchesTypeQuantile(p: Double) {
		// An identity across two independent code paths, not a fixture. Each family
		// implements its quantile twice — once as a free function taking a uniform, once on
		// the type conforming to `ContinuousDistribution` — and neither was checked against
		// the other. Rayleigh's disagreed: the free function decreased in its argument where
		// the type increased, because the transform underneath consumes the uniform as a
		// radius driver. Nothing caught it, because the only shared test point was u = 0.5,
		// where `u` and `1 − u` are the same number.
		let exponential: Double = distributionExponential(λ: 2.0, quantileAt: p)
		#expect(abs(exponential - DistributionExponential(2.0).quantile(p)) < 1e-12,
				"exponential at \(p): free \(exponential), type \(DistributionExponential(2.0).quantile(p))")

		let rayleigh: Double = distributionRayleigh(scale: 3.0, quantileAt: p)
		#expect(abs(rayleigh - DistributionRayleigh(scale: 3.0).quantile(p)) < 1e-12,
				"Rayleigh at \(p): free \(rayleigh), type \(DistributionRayleigh(scale: 3.0).quantile(p))")

		let weibull: Double = distributionWeibull(shape: 2.0, scale: 5.0, quantileAt: p)
		let weibullType: Double = DistributionWeibull(shape: 2.0, scale: 5.0).quantile(p)
		#expect(abs(weibull - weibullType) < 1e-12 * Swift.max(1.0, weibullType),
				"Weibull at \(p): free \(weibull), type \(weibullType)")

		let pareto: Double = distributionPareto(scale: 1.0, shape: 2.0, quantileAt: p)
		let paretoType: Double = DistributionPareto(scale: 1.0, shape: 2.0).quantile(p)
		#expect(abs(pareto - paretoType) < 1e-12 * Swift.max(1.0, paretoType),
				"Pareto at \(p): free \(pareto), type \(paretoType)")

		let logistic: Double = distributionLogistic(0.0, 1.0, quantileAt: p)
		let logisticType: Double = DistributionLogistic(0.0, 1.0).quantile(p)
		#expect(abs(logistic - logisticType) < 1e-12 * Swift.max(1.0, abs(logisticType)),
				"logistic at \(p): free \(logistic), type \(logisticType)")
	}

	// MARK: - The two draws agree with the quantile, and with each other

	@Test("using: draws one uniform and evaluates the quantile at it")
	func usingMatchesTheQuantile() {
		// The generator is stepped twice from the same seed: once through the sampler, once
		// through the uniform it is documented to draw. Agreement says the sampler is the
		// quantile plus exactly one draw, which is the contract a caller interleaving
		// families on one stream depends on.
		var samplerRNG = DeterministicRNG(seed: 9_001)
		let drawn: Double = distributionExponential(λ: 1.5, using: &samplerRNG)

		var uniformRNG = DeterministicRNG(seed: 9_001)
		let u: Double = openUnitUniform(Double.self, using: &uniformRNG)
		let viaQuantile: Double = distributionExponential(λ: 1.5, quantileAt: u)

		#expect(identical(drawn, viaQuantile),
				"using: gave \(drawn), the quantile at its own uniform gives \(viaQuantile)")
	}

	@Test("seed: is reproducible, and different seeds differ")
	func seedIsReproducible() {
		let first: Double = distributionPareto(scale: 2.0, shape: 3.0, seed: 4_242)
		let again: Double = distributionPareto(scale: 2.0, shape: 3.0, seed: 4_242)
		#expect(identical(first, again), "the same seed gave \(first) then \(again)")

		// And the seed has to be doing something, or reproducibility is vacuous.
		let other: Double = distributionPareto(scale: 2.0, shape: 3.0, seed: 9_999)
		#expect(!identical(first, other), "two different seeds both gave \(first)")
	}

	@Test("seed: agrees with using: on the same stream")
	func seedAgreesWithUsing() {
		// `seed:` is documented as `using:` over a DeterministicRNG named by that seed.
		var generator = DeterministicRNG(seed: 777)
		let viaGenerator: Double = distributionRayleigh(scale: 4.0, using: &generator)
		let viaSeed: Double = distributionRayleigh(scale: 4.0, seed: 777)
		#expect(identical(viaSeed, viaGenerator),
				"seed: gave \(viaSeed), using: on the same stream gave \(viaGenerator)")
	}

	@Test("Every family is finite over many seeded draws")
	func seededDrawsAreFinite() {
		// The reason the uniform is open. A closed interval makes `log(0)` reachable from a
		// legal draw: rare enough to survive a test suite, common enough to reach production.
		for seed in UInt64(0)..<UInt64(5_000) {
			let e: Double = distributionExponential(λ: 2.0, seed: seed)
			let p: Double = distributionPareto(scale: 1.0, shape: 2.0, seed: seed)
			let w: Double = distributionWeibull(shape: 2.0, scale: 5.0, seed: seed)
			let r: Double = distributionRayleigh(scale: 3.0, seed: seed)
			let l: Double = distributionLogistic(0.0, 1.0, seed: seed)
			#expect(e.isFinite && p.isFinite && w.isFinite && r.isFinite && l.isFinite,
					"seed \(seed): exponential \(e), Pareto \(p), Weibull \(w), Rayleigh \(r), logistic \(l)")
		}
	}
}
