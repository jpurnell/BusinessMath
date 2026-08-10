//
//  BoxMullerPoleGuardTests.swift
//  BusinessMath
//
//  The log(0) pole in Box-Muller, and the guards standing in front of it.
//

import Foundation
import Testing
import TestSupport  // Cross-platform math functions
@testable import BusinessMath

/// A generator that emits a scripted list of words, then a fixed benign word.
///
/// Lets a test steer `Double.random(in:using:)` onto the exact draw that sits on
/// the `log(0)` pole, which no seed search would reach in practice — the whole
/// problem with pole guards is that they are only ever exercised on the draw
/// nobody gets.
private struct ScriptedRNG: RandomNumberGenerator {
	private var words: [UInt64]
	private var index = 0

	init(_ words: [UInt64]) { self.words = words }

	mutating func next() -> UInt64 {
		defer { index += 1 }
		return index < words.count ? words[index] : 0x1234_5678_9abc_def0
	}
}

/// Box-Muller needs `u₁ ∈ (0, 1]`; `log(0)` is `-∞` and the radius comes out
/// non-finite. Four sites in this package inline the transform, and the guards
/// they used against that pole were all different — two clamped to a magic
/// constant, one shifted the argument, one had no guard at all.
///
/// A clamp is the wrong shape even when it keeps the result finite: it maps a
/// whole interval of draws onto a single value, so the clamp value carries a
/// point mass the normal distribution does not have. Drawing
/// `1 - Double.random(in: 0..<1)` instead is exact for every representable
/// `u < 1` (Sterbenz), and `u ↦ 1 - u` is measure-preserving, so the draw stays
/// exactly uniform on `(0, 1]`. See `git show d247691`.
@Suite("Box-Muller Pole Guards")
struct BoxMullerPoleGuardTests {

	// MARK: - distributionRayleigh

	/// The Rayleigh variate is the Box-Muller *radius*, so it meets the same pole
	/// and had no guard whatsoever.
	///
	/// `distributionUniform` quantizes its seed to a multiple of 1e-7
	/// (`(seed * 10_000_000).rounded(.down) / 10_000_000`), so every seed below
	/// 1e-7 — not just zero — became `u = 0` and the function returned `+∞`.
	/// That is one draw in ten million from the unseeded path, and it returns a
	/// number no downstream mean, variance or percentile can survive.
	@Test("Rayleigh is finite for every seed, including the ones that quantize to zero",
		  arguments: [0.0, 1e-12, 1e-9, 1e-8, 5e-8, 9.99e-8, 1e-7, 0.25, 0.5, 1.0])
	func rayleighIsFiniteAtThePole(seed: Double) {
		let value: Double = distributionRayleigh(mean: 1.0, seed: seed)
		#expect(value.isFinite, "distributionRayleigh(mean: 1, seed: \(seed)) = \(value)")
		#expect(value >= 0.0, "Rayleigh is non-negative by definition; got \(value)")
	}

	@Test("Rayleigh keeps its scale after the guard")
	func rayleighDistributionIsUnchangedAwayFromThePole() {
		// The guard must not move the bulk of the distribution. For a Rayleigh
		// with scale σ the mean is σ√(π/2) ≈ 1.2533σ.
		let rng = SeededRNG(seed: 20260809)
		var total = 0.0
		let n = 200_000
		for _ in 0..<n {
			total += distributionRayleigh(mean: 1.0, seed: rng.next()) as Double
		}
		let mean = total / Double(n)
		let expected = (Double.pi / 2).squareRoot()
		#expect(abs(mean - expected) < 0.02, "mean \(mean), expected ≈ \(expected)")
	}

	// MARK: - PortfolioUtilities

	/// `generateRandomReturns` guarded with
	/// `u1 == 0 ? Double.leastNormalMagnitude : u1`, which is a clamp wearing a
	/// conditional. `leastNormalMagnitude` is 2.2e-308, so the radius came out
	/// `sqrt(-2 · log(2.2e-308))` = 37.64 — a 37-sigma draw emitted as a point
	/// mass whenever the uniform landed on zero. At mean 0.10 and stdDev 0.05
	/// that is a +198% annual return.
	@Test("A degenerate uniform does not become a 37-sigma return")
	func portfolioReturnsPoleGuardHasNoAtom() {
		// Word 1 makes Double.random(in: 0.0...1.0) return exactly 0.0.
		var rng = ScriptedRNG([1])
		let returns = generateRandomReturns(count: 1, mean: 0.10, stdDev: 0.05, using: &rng)

		let value = returns[0]
		#expect(value.isFinite, "return was \(value)")

		let sigmas = abs(value - 0.10) / 0.05
		#expect(sigmas < 10.0,
				"pole draw produced a \(sigmas)-sigma return (\(value)); the old guard produced 37.64 sigma")
	}

	@Test("Portfolio returns keep their mean and dispersion")
	func portfolioReturnsDistributionUnchanged() {
		var rng = SeededRNG2(seed: 987_654_321)
		let n = 200_000
		let returns = generateRandomReturns(count: n, mean: 0.10, stdDev: 0.05, using: &rng)

		let mean = returns.sum / Double(n)
		var sumSquares = 0.0
		for i in 0..<n { sumSquares += (returns[i] - mean) * (returns[i] - mean) }
		let stdDev = (sumSquares / Double(n - 1)).squareRoot()

		#expect(abs(mean - 0.10) < 0.001, "mean \(mean)")
		#expect(abs(stdDev - 0.05) < 0.001, "stdDev \(stdDev)")
		#expect(returns.toArray().allSatisfy { $0.isFinite })
	}

	// MARK: - SimulatedAnnealing

	/// `SimulatedAnnealing.generateNeighbor` built its uniform as
	/// `Double(raw >> 32) / Double(UInt32.max)`, which is a **closed** `[0, 1]` —
	/// both endpoints are attainable — and then guarded the pole with
	/// `log(u1 + 1e-10)`.
	///
	/// At the upper endpoint that guard does not merely bias the draw, it
	/// produces `-2 · log(1 + 1e-10) < 0`, whose square root is `NaN`. The NaN
	/// then reaches `Int(scaledGaussian * 1_000_000)`, and converting a NaN to
	/// `Int` in Swift is a trap, not a wrong answer — it takes the process down.
	/// One draw in 2³² does that.
	///
	/// The same file already had the correct denominator twenty lines earlier
	/// (`Double(rng.next() >> 32) / Double(1 << 32)`), which is the half-open
	/// `[0, 1)` the transform needs.
	@Test("The uniform feeding Box-Muller is half-open, so the poles are unreachable")
	func simulatedAnnealingUniformIsHalfOpen() {
		let allOnes = UInt64.max

		// What the old expression did at the top of its range.
		let closedForm = Double(allOnes >> 32) / Double(UInt32.max)
		// Exactly 1, not near it: numerator and denominator are the same integer, so
		// the quotient is 1.0 with no rounding. The whole point of the assertion is that
		// the endpoint is *attained*, which a tolerance could not distinguish from
		// merely approached.
		#expect(identical(closedForm, 1.0), "the old denominator made u = 1 attainable")
		#expect((-2.0 * Foundation.log(closedForm + 1e-10)).squareRoot().isNaN,
				"log(1 + 1e-10) > 0, so the radius was the square root of a negative number")

		// What the correct denominator does.
		let halfOpen = Double(allOnes >> 32) / Double(UInt64(1) << 32)
		#expect(halfOpen < 1.0, "u must stay strictly below 1")
		#expect(halfOpen > 0.99999999)

		// And the shared transform is finite across the whole closed seed range.
		for seed in [0.0, 1e-12, halfOpen, 1.0] {
			let (z1, z2): (Double, Double) = boxMullerSeed(seed, 0.375)
			#expect(z1.isFinite && z2.isFinite, "boxMullerSeed(\(seed), 0.375) = (\(z1), \(z2))")
		}
	}

	@Test("Simulated annealing still converges after the transform is shared")
	func simulatedAnnealingStillConverges() throws {
		// Sphere function: the minimum is the origin.
		let objective: @Sendable (VectorN<Double>) -> Double = { $0.dot($0) }
		let config = SimulatedAnnealingConfig(
			initialTemperature: 100.0,
			finalTemperature: 0.001,
			coolingRate: 0.95,
			maxIterations: 1000,
			perturbationScale: 0.3,
			seed: 102
		)
		let optimizer = SimulatedAnnealing<VectorN<Double>>(
			config: config,
			searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
		)
		let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

		#expect(result.converged)
		#expect(result.value.isFinite)
		#expect(result.value < 5.0, "value \(result.value)")
		#expect(result.solution.toArray().allSatisfy { $0.isFinite })
	}

	// MARK: - Box-Muller correctness

	/// `boxMuellerSeed`'s second variate previously computed `cos(2π)` — the
	/// constant 1 — instead of `cos(2πu₂)`, so `z2` was the radius scaled by a
	/// uniform: not normal, and not independent of `z1`. Fixed in `dc42570`.
	/// This pins the shape so it cannot regress, and so the four inline copies
	/// can be checked against it.
	@Test("Both variates are standard normal and share a radius")
	func bothVariatesAreNormal() {
		let rng = SeededRNG(seed: 314_159)
		let n = 200_000
		var sum1 = 0.0, sum2 = 0.0, sumSq1 = 0.0, sumSq2 = 0.0, sumCross = 0.0

		for _ in 0..<n {
			let (z1, z2): (Double, Double) = boxMullerSeed(rng.next(), rng.next())
			sum1 += z1; sum2 += z2
			sumSq1 += z1 * z1; sumSq2 += z2 * z2
			sumCross += z1 * z2
		}

		let mean1 = sum1 / Double(n), mean2 = sum2 / Double(n)
		let var1 = sumSq1 / Double(n) - mean1 * mean1
		let var2 = sumSq2 / Double(n) - mean2 * mean2
		let covariance = sumCross / Double(n) - mean1 * mean2

		#expect(abs(mean1) < 0.02, "z1 mean \(mean1)")
		#expect(abs(mean2) < 0.02, "z2 mean \(mean2)")
		#expect(abs(var1 - 1.0) < 0.02, "z1 variance \(var1)")
		// The pre-dc42570 bug left z2 with variance 1/3 (radius × uniform), which
		// this bound rejects.
		#expect(abs(var2 - 1.0) < 0.02, "z2 variance \(var2)")
		#expect(abs(covariance) < 0.02, "z1/z2 covariance \(covariance)")
	}
}

/// Value-type LCG so `generateRandomReturns(using:)` can take it `inout`.
private struct SeededRNG2: RandomNumberGenerator {
	private var state: UInt64
	init(seed: UInt64) { self.state = seed | 1 }
	mutating func next() -> UInt64 {
		state ^= state << 13
		state ^= state >> 7
		state ^= state << 17
		return state
	}
}
