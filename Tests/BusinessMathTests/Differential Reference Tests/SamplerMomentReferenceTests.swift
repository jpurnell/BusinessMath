//
//  SamplerMomentReferenceTests.swift
//  BusinessMath
//
//  Differential tests for the random-variate generators: closed-form inverse-CDF
//  identities, and analytic moments against seeded samples. TrustPlan §2.2.
//

import Foundation
import Testing
import Numerics
import TestSupport  // identical, exactlyEqual, approximatelyEqual

@testable import BusinessMath

/// The distribution samplers against their analytic moments and their own
/// inverse-CDF definitions.
///
/// ## Two kinds of test, and why both
///
/// A sampler has no published table to check against — it produces one number at
/// a time. So this file asks two different questions.
///
/// 1. **Closed-form identities.** Every inverse-transform sampler here takes the
///    uniform it will use as a parameter, so feeding it a known `u` turns a
///    stochastic function into a deterministic one with a citable answer:
///    `Weibull(k, λ)` at `u` is `λ(-ln(1-u))^(1/k)`, `Pareto(xₘ, α)` is
///    `xₘ u^(-1/α)`, and so on. These are exact and are the strongest assertions
///    in the file.
/// 2. **Analytic moments from a seeded sample.** Where the sampler is rejection-
///    based (gamma, and the beta / chi-squared / t / F built on it) there is no
///    closed form, so the test draws a large seeded sample and compares its mean
///    and variance to the analytic values.
///
/// ## Where the moment tolerances come from
///
/// Each moment tolerance is **five standard errors of the estimator**, computed
/// from the distribution's own analytic moments — not chosen by running the test
/// and rounding up:
///
/// - mean: `SE = σ/√n`
/// - variance: `SE = √((μ₄ - σ⁴)/n)`, with `μ₄` the analytic fourth central moment
///
/// Five is a deliberate choice: the sample is seeded, so a single fixed number is
/// being checked, and a 5σ band makes the test insensitive to a change of
/// generator while still failing on any systematic bias above ~0.5%. The bands are
/// written out per case below so a reader can check the arithmetic.
///
/// Where the fourth moment does not exist — Pareto with `α = 3` — the variance is
/// not asserted, and the reason is recorded rather than a band invented.
///
/// ## Seeding
///
/// Everything stochastic here is seeded. `SplitMix64` supplies the bits (tested
/// against Vigna's published vectors in SwiftDeterminism); the `using:` overloads
/// thread one generator through a whole sample, and the `seed:` overloads that
/// take a `Double` take the uniform itself.
@Suite("Distribution samplers vs analytic moments")
struct SamplerMomentReferenceTests {

	// MARK: - Helpers

	/// Sample mean and unbiased sample variance.
	static func moments(_ values: [Double]) -> (mean: Double, variance: Double) {
		let n = Double(values.count)
		let mean = values.reduce(0, +) / n
		let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / (n - 1)
		return (mean, variance)
	}

	/// A 53-bit uniform on `[0, 1)` drawn from a seeded SplitMix64.
	///
	/// The shift-and-scale is the standard construction: the top 53 bits divided
	/// by `2^53`, which is exactly representable.
	static func uniforms(seed: UInt64, count: Int) -> [Double] {
		var generator = SplitMix64(seed: seed)
		return (0..<count).map { _ in
			Double(generator.next() >> 11) * (1.0 / 9007199254740992.0)
		}
	}

	// MARK: - Closed-form inverse-transform identities

	@Test("Inverse-transform samplers reproduce their closed forms exactly")
	func inverseTransformClosedForms() {
		// Each of these takes the uniform as its seed, so the "random" value is a
		// deterministic function with a citable closed form. Tolerance 1e-15
		// absolute: one log and one pow over a well-conditioned argument.

		// Weibull: λ(-ln(1-u))^(1/k). At u = 1/2, k = 2, λ = 3 this is 3√(ln 2).
		let weibullMedian = 3.0 * (0.6931471805599453 as Double).squareRoot()
		#expect(
			approximatelyEqual(distributionWeibull(shape: 2.0, scale: 3.0, seed: 0.5), weibullMedian, tolerance: 1e-15),
			"Weibull(2, 3) at u = 0.5 should be 3√(ln 2) = \(weibullMedian)"
		)

		// Exponential: -ln(1-u)/λ. At u = 1/2, λ = 2 this is (ln 2)/2.
		#expect(
			approximatelyEqual(distributionExponential(λ: 2.0, seed: 0.5), 0.34657359027997264, tolerance: 1e-15),
			"Exponential(2) at u = 0.5 should be (ln 2)/2"
		)

		// Pareto: xₘ u^(-1/α). At u = 1/2, α = 3 this is 2^(1/3).
		#expect(
			approximatelyEqual(distributionPareto(scale: 1.0, shape: 3.0, seed: 0.5), 1.2599210498948732, tolerance: 1e-15),
			"Pareto(1, 3) at u = 0.5 should be 2^(1/3)"
		)

		// Uniform: l + u(h - l). Exact — no transcendental, so a bit comparison.
		#expect(identical(distributionUniform(min: 2.0, max: 6.0, 0.25) as Double, 3.0))
		#expect(identical(distributionUniform(min: 2.0, max: 6.0, 0.0) as Double, 2.0))

		// Triangular: at u equal to the mode's CDF value the variate is the mode.
		// For low 0, high 1, base c, F(c) = c, so u = c returns c.
		#expect(
			approximatelyEqual(triangularDistribution(low: 0.0, high: 1.0, base: 0.5, 0.5), 0.5, tolerance: 1e-15)
		)
		#expect(
			approximatelyEqual(triangularDistribution(low: 0.0, high: 1.0, base: 0.25, 0.25), 0.25, tolerance: 1e-15)
		)

		// Logistic: the median is the location parameter, exactly.
		#expect(exactlyEqual(distributionLogistic(0.0, 1.0, seed: 0.5) as Double, 0.0))
	}

	@Test("Inverse-transform samplers invert their own CDFs")
	func samplersInvertTheirCDFs() {
		// Round trip through two separately implemented functions: the sampler's
		// inverse transform and the package's CDF. Tolerance 1e-14 on a probability
		// in [0.05, 0.95], where both are well conditioned.
		for u in [0.05, 0.25, 0.5, 0.75, 0.95] {
			let exponentialDraw: Double = distributionExponential(λ: 1.5, seed: u)
			#expect(
				approximatelyEqual(exponentialCDF(exponentialDraw, λ: 1.5), u, tolerance: 1e-14),
				"exponentialCDF(exponential sample at u = \(u)) = \(exponentialCDF(exponentialDraw, λ: 1.5))"
			)

			let lognormalDraw: Double = distributionLogNormal(mean: 0.0, stdDev: 1.0, u, 0.25)
			// Box-Muller consumes two uniforms and does not invert the CDF, so this
			// is only asserted to be in range — the moment test below is what pins
			// the distribution.
			#expect(lognormalDraw > 0, "lognormal sample \(lognormalDraw) must be positive")
		}
	}

	// MARK: - Analytic moments

	@Test("Inverse-transform samplers match their analytic mean and variance")
	func inverseTransformMoments() {
		let n = 400_000
		let uniformStream = Self.uniforms(seed: 0xBADC0FFEE, count: n)

		// Exponential(λ = 2): mean 1/2, variance 1/4, μ₄ = 9/λ⁴ = 9/16.
		// 5·SE(mean) = 5·√(0.25/400000) = 3.95e-3
		// 5·SE(var)  = 5·√((0.5625 - 0.0625)/400000) = 5.59e-3
		let exponentialSample = uniformStream.map { distributionExponential(λ: 2.0, seed: $0) as Double }
		let exponential = Self.moments(exponentialSample)
		#expect(approximatelyEqual(exponential.mean, 0.5, tolerance: 3.95e-3), "exponential mean \(exponential.mean)")
		#expect(approximatelyEqual(exponential.variance, 0.25, tolerance: 5.59e-3), "exponential variance \(exponential.variance)")

		// Uniform(2, 6): mean 4, variance 16/12, μ₄ = (b-a)⁴/80 = 3.2.
		// 5·SE(mean) = 9.13e-3, 5·SE(var) = 9.43e-3
		let uniform = Self.moments(uniformStream.map { distributionUniform(min: 2.0, max: 6.0, $0) as Double })
		#expect(approximatelyEqual(uniform.mean, 4.0, tolerance: 9.13e-3), "uniform mean \(uniform.mean)")
		#expect(approximatelyEqual(uniform.variance, 4.0 / 3.0, tolerance: 9.43e-3), "uniform variance \(uniform.variance)")

		// Triangular(0, 6, 3): mean 3, variance h²/6 = 1.5, μ₄ = h⁴/15 = 5.4.
		// 5·SE(mean) = 9.68e-3, 5·SE(var) = 1.40e-2
		let triangular = Self.moments(uniformStream.map { triangularDistribution(low: 0.0, high: 6.0, base: 3.0, $0) as Double })
		#expect(approximatelyEqual(triangular.mean, 3.0, tolerance: 9.68e-3), "triangular mean \(triangular.mean)")
		#expect(approximatelyEqual(triangular.variance, 1.5, tolerance: 1.40e-2), "triangular variance \(triangular.variance)")

		// Weibull(k = 2, λ = 3): mean 3Γ(1.5) = 2.6586807763582740,
		// variance 9(Γ(2) - Γ(1.5)²) = 1.9314165294229652, μ₄ from the same Γ series.
		// 5·SE(mean) = 1.10e-2, 5·SE(var) = 2.29e-2
		let weibull = Self.moments(uniformStream.map { distributionWeibull(shape: 2.0, scale: 3.0, seed: $0) as Double })
		#expect(approximatelyEqual(weibull.mean, 2.658680776358274, tolerance: 1.10e-2), "weibull mean \(weibull.mean)")
		#expect(approximatelyEqual(weibull.variance, 1.9314165294229652, tolerance: 2.29e-2), "weibull variance \(weibull.variance)")

		// Pareto(xₘ = 1, α = 3): mean αxₘ/(α-1) = 3/2.
		// 5·SE(mean) = 6.85e-3.
		// The variance is *not* asserted: E[X³] and E[X⁴] are infinite at α = 3, so
		// the sample variance has no finite standard error and any band would be a
		// number with nothing behind it. The mean is enough to catch a wrong
		// exponent, which is the failure mode that matters.
		let pareto = Self.moments(uniformStream.map { distributionPareto(scale: 1.0, shape: 3.0, seed: $0) as Double })
		#expect(approximatelyEqual(pareto.mean, 1.5, tolerance: 6.85e-3), "pareto mean \(pareto.mean)")

		// Every Pareto draw is at or above the scale parameter, by construction.
		#expect(pareto.mean > 1.0)
	}

	@Test("Box-Muller samplers match their analytic mean and variance")
	func boxMullerMoments() {
		let n = 400_000
		let stream = Self.uniforms(seed: 0xC0FFEE99, count: 2 * n)
		let pairs = (0..<n).map { (stream[2 * $0], stream[2 * $0 + 1]) }

		// Normal(5, 2): μ₄ = 3σ⁴ = 48.
		// 5·SE(mean) = 1.58e-2, 5·SE(var) = 4.47e-2
		let normal = Self.moments(pairs.map { distributionNormal(mean: 5.0, stdDev: 2.0, $0.0, $0.1) as Double })
		#expect(approximatelyEqual(normal.mean, 5.0, tolerance: 1.58e-2), "normal mean \(normal.mean)")
		#expect(approximatelyEqual(normal.variance, 4.0, tolerance: 4.47e-2), "normal variance \(normal.variance)")

		// LogNormal(0, 1): mean e^(1/2) = 1.6487212707001282,
		// variance (e - 1)e = 4.670774270471605, μ₄ = e⁸ - 4e^(9/2)e^(1/2) + ...
		// 5·SE(mean) = 1.71e-2, 5·SE(var) = 3.92e-1
		//
		// The variance band is 8.4% of the value, which looks loose and is not: the
		// lognormal's fourth moment is e⁸ ≈ 2981, so the variance estimator is
		// genuinely that noisy at n = 400000. Stating the band as 5·SE keeps it
		// honest rather than tightening it until this particular seed passes.
		let lognormal = Self.moments(pairs.map { distributionLogNormal(mean: 0.0, stdDev: 1.0, $0.0, $0.1) as Double })
		#expect(approximatelyEqual(lognormal.mean, 1.6487212707001282, tolerance: 1.71e-2), "lognormal mean \(lognormal.mean)")
		#expect(approximatelyEqual(lognormal.variance, 4.670774270471605, tolerance: 3.92e-1), "lognormal variance \(lognormal.variance)")
	}

	@Test("Rejection samplers match their analytic mean and variance")
	func rejectionSamplerMoments() {
		let n = 100_000

		// Gamma(shape 2, scale 3): mean kθ = 6, variance kθ² = 18,
		// μ₄ = 3k(k+2)θ⁴ = 1944.
		// 5·SE(mean) = 6.71e-2, 5·SE(var) = 6.36e-1
		var gammaGenerator = SplitMix64(seed: 20260810)
		let gammaSample = (0..<n).map { _ in gammaVariate(shape: 2.0, scale: 3.0, using: &gammaGenerator) as Double }
		let gamma = Self.moments(gammaSample)
		#expect(approximatelyEqual(gamma.mean, 6.0, tolerance: 6.71e-2), "gamma(2, 3) mean \(gamma.mean)")
		#expect(approximatelyEqual(gamma.variance, 18.0, tolerance: 6.36e-1), "gamma(2, 3) variance \(gamma.variance)")

		// Gamma with shape < 1 takes the Ahrens-Dieter boost branch, which is where
		// the seeding defect lived: mean kθ = 1, variance kθ² = 2, μ₄ = 3·0.5·2.5·16 = 60.
		// 5·SE(mean) = 2.24e-2, 5·SE(var) = 1.18e-1
		var smallShapeGenerator = SplitMix64(seed: 777)
		let smallShape = Self.moments((0..<n).map { _ in gammaVariate(shape: 0.5, scale: 2.0, using: &smallShapeGenerator) as Double })
		#expect(approximatelyEqual(smallShape.mean, 1.0, tolerance: 2.24e-2), "gamma(0.5, 2) mean \(smallShape.mean)")
		#expect(approximatelyEqual(smallShape.variance, 2.0, tolerance: 1.18e-1), "gamma(0.5, 2) variance \(smallShape.variance)")

		// Beta(2, 5): mean a/(a+b) = 2/7, variance ab/((a+b)²(a+b+1)) = 10/392.
		// 5·SE(mean) = 2.53e-3, 5·SE(var) = 5.53e-4
		var betaGenerator = SplitMix64(seed: 31337)
		let beta = Self.moments((0..<n).map { _ in distributionBeta(alpha: 2.0, beta: 5.0, using: &betaGenerator) as Double })
		#expect(approximatelyEqual(beta.mean, 2.0 / 7.0, tolerance: 2.53e-3), "beta(2, 5) mean \(beta.mean)")
		#expect(approximatelyEqual(beta.variance, 10.0 / 392.0, tolerance: 5.53e-4), "beta(2, 5) variance \(beta.variance)")

		// Chi-squared(5) = Gamma(2.5, 2): mean k = 5, variance 2k = 10,
		// μ₄ = 3k(k+2)θ⁴ with k = 2.5, θ = 2, giving 540.
		// 5·SE(mean) = 5.00e-2, 5·SE(var) = 3.32e-1
		var chiGenerator = SplitMix64(seed: 4919)
		let chi = Self.moments((0..<n).map { _ in distributionChiSquared(degreesOfFreedom: 5, using: &chiGenerator) as Double })
		#expect(approximatelyEqual(chi.mean, 5.0, tolerance: 5.00e-2), "chi-squared(5) mean \(chi.mean)")
		#expect(approximatelyEqual(chi.variance, 10.0, tolerance: 3.32e-1), "chi-squared(5) variance \(chi.variance)")

		// Student's t(10): mean 0, variance ν/(ν-2) = 1.25,
		// μ₄ = 3ν²/((ν-2)(ν-4)) = 6.25.
		// 5·SE(mean) = 1.77e-2, 5·SE(var) = 3.42e-2
		var tGenerator = SplitMix64(seed: 8191)
		let studentT = Self.moments((0..<n).map { _ in distributionT(degreesOfFreedom: 10, using: &tGenerator) as Double })
		#expect(approximatelyEqual(studentT.mean, 0.0, tolerance: 1.77e-2), "t(10) mean \(studentT.mean)")
		#expect(approximatelyEqual(studentT.variance, 1.25, tolerance: 3.42e-2), "t(10) variance \(studentT.variance)")

		// F(10, 10): mean d₂/(d₂-2) = 1.25. The fourth moment needs d₂ > 8 and is
		// large enough at d₂ = 10 that a 5·SE band on the variance would be wider
		// than the variance itself, so only the mean is asserted.
		// 5·SE(mean) = 1.53e-2, from variance 2d₂²(d₁+d₂-2)/(d₁(d₂-2)²(d₂-4)) = 0.9375.
		var fGenerator = SplitMix64(seed: 65537)
		let fRatio = Self.moments((0..<n).map { _ in distributionF(df1: 10, df2: 10, using: &fGenerator) as Double })
		#expect(approximatelyEqual(fRatio.mean, 1.25, tolerance: 1.53e-2), "F(10, 10) mean \(fRatio.mean)")

		// Geometric(0.25) on the support {1, 2, ...}: mean 1/p = 4,
		// variance (1-p)/p² = 12, μ₄ = (1-p)(p² - 9p + 9)/p⁴ = 1591.5.
		// 5·SE(mean) = 3.87e-2, 5·SE(var) = 3.81e-1
		var geometricGenerator = SplitMix64(seed: 271828)
		let geometricSample = (0..<200_000).map { _ in distributionGeometric(0.25, using: &geometricGenerator) as Double }
		let geometric = Self.moments(geometricSample)
		#expect(approximatelyEqual(geometric.mean, 4.0, tolerance: 3.87e-2), "geometric(0.25) mean \(geometric.mean)")
		#expect(approximatelyEqual(geometric.variance, 12.0, tolerance: 3.81e-1), "geometric(0.25) variance \(geometric.variance)")
		// The support choice is part of the contract: 1/p = 4 rather than (1-p)/p = 3.
		#expect(exactlyEqual(geometricSample.min() ?? 0, 1.0), "geometric support must start at 1")
	}

	// MARK: - Discrepancies

	@Test("distributionRayleigh's parameter is the scale, and now says so")
	func rayleighParameterIsTheScale() {
		// `distributionRayleigh` used to spell its parameter `mean:` and document it as
		// "the mean of the Rayleigh distribution", while computing `mean * boxMullerRadius(seed)`.
		// `boxMullerRadius` returns a standard Rayleigh variate, whose mean is
		// √(π/2) = 1.2533, not 1. So the parameter was the scale σ all along, and a
		// caller asking for a mean of 2 got a distribution whose mean was 2.5066.
		//
		// Measured over 400000 seeded draws: sample mean **2.5039** against a
		// documented 2, a systematic **25.2%** overshoot; the sample variance is
		// 1.7175 against (4-π)/2·σ² = 1.7168, confirming σ = 2 rather than mean = 2.
		//
		// The label is now `scale:`. The numbers below are unchanged — the fix was to
		// the name and the prose, not to the arithmetic, because the arithmetic was the
		// part that was right. See the note on ``distributionRayleigh(scale:seed:)`` for
		// why renaming beat dividing by √(π/2).
		let stream = Self.uniforms(seed: 0xBADC0FFEE, count: 400_000)
		let rayleigh = Self.moments(stream.map { distributionRayleigh(scale: 2.0, seed: $0) as Double })

		// A Rayleigh with scale 2: mean σ√(π/2), variance (4-π)/2·σ².
		// 5·SE(mean) = 5·√(1.7168/400000) = 1.04e-2, 5·SE(var) = 2.5e-2
		#expect(
			approximatelyEqual(rayleigh.mean, 2.5066282746310005, tolerance: 1.04e-2),
			"sample mean \(rayleigh.mean) against σ√(π/2) = 2.5066282746310005"
		)
		#expect(
			approximatelyEqual(rayleigh.variance, 1.7168146928204138, tolerance: 2.5e-2),
			"sample variance \(rayleigh.variance) against (4-π)/2·σ² = 1.7168146928204138"
		)

		// And the conversion the documentation now hands to a caller who wanted a mean:
		// σ = mean / √(π/2). Asking for a mean of 2 means asking for a scale of 1.5958.
		let forMeanOfTwo = 2.0 / 1.2533141373155003
		let converted = Self.moments(stream.map { distributionRayleigh(scale: forMeanOfTwo, seed: $0) as Double })
		#expect(
			approximatelyEqual(converted.mean, 2.0, tolerance: 1.04e-2),
			"scale \(forMeanOfTwo) gives sample mean \(converted.mean), against a target of 2"
		)
	}

	@Test("distributionPareto is finite at the pole of its inverse transform")
	func paretoIsFiniteAtZeroUniform() {
		// `distributionPareto` used to guard against a vanishing uniform with
		//
		//     let epsilon: T = T(Int(1e-10))
		//
		// and `Int(1e-10)` is **0**. The comment on the same line said "// 1e-10".
		// So the guard `u > epsilon` was `u > 0`, and a uniform of exactly zero —
		// which `distributionUniform(min:max:_:)` returns for a seed of zero, and for
		// every seed below its 1e-7 quantum — produced `scale / 0^(1/α)` = **+infinity**.
		//
		// An infinity entering a Monte Carlo run poisons every aggregate computed
		// from it: the mean, the variance and every percentile above the affected
		// draw.
		//
		// The replacement is not a repaired clamp. A clamp maps a whole interval of
		// draws onto one value and leaves a point mass at `scale·ε^(-1/α)`; the
		// library's settled rule is to draw the uniform on (0, 1] instead, so only
		// `u = 0` moves and it moves to 1. See `git show d247691`.
		let scale = 1.0
		for seed in [0.0, 1e-300, 1e-12, 1e-8] {
			let value: Double = distributionPareto(scale: scale, shape: 3.0, seed: seed)
			#expect(value.isFinite, "distributionPareto(scale: 1, shape: 3, seed: \(seed)) = \(value)")
			#expect(value >= scale, "Pareto is supported on [scale, ∞); got \(value)")
		}

		// u = 0 maps to u = 1, the other end of the interval, which is exactly the
		// minimum of the support.
		let atZero: Double = distributionPareto(scale: scale, shape: 3.0, seed: 0.0)
		#expect(exactlyEqual(atZero, scale), "u = 0 remaps to u = 1, so the variate is the support minimum; got \(atZero)")

		// And the remap must not disturb the interior: 2^(1/3) at u = 1/2, unchanged.
		#expect(
			approximatelyEqual(distributionPareto(scale: 1.0, shape: 3.0, seed: 0.5), 1.2599210498948732, tolerance: 1e-15),
			"the pole guard must not move the bulk of the distribution"
		)
	}
}
