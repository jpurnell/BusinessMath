//
//  MonteCarloIntegrationSeedTests.swift
//  BusinessMathTests
//
//  `integrate(_:iterations:seed:)` advertised a seed that could not affect the
//  result: the running-mean recurrence erased it on the first iteration, and the
//  samples came from the global RNG regardless. These tests pin the contract the
//  parameter always claimed — same seed, same answer — and the unbiasedness that
//  a correct accumulator has to preserve.
//

import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison
import Foundation
@testable import BusinessMath

@Suite("Monte Carlo integration determinism")
struct MonteCarloIntegrationSeedTests {

	/// x² over [0, 1] — the integral is exactly 1/3.
	private let square: (Double) -> Double = { $0 * $0 }

	@Test("Same seed produces the same estimate")
	func sameSeedIsReproducible() {
		let first = integrate(square, iterations: 10_000, seed: 42)
		let second = integrate(square, iterations: 10_000, seed: 42)
		#expect(first == second)
	}

	@Test("Different seeds produce different estimates")
	func differentSeedsDiverge() {
		let a = integrate(square, iterations: 10_000, seed: 1)
		let b = integrate(square, iterations: 10_000, seed: 2)
		#expect(a != b)
	}

	/// Tolerance rationale: for X ~ U(0,1), Var(X²) = 1/5 − 1/9 = 4/45, so the
	/// standard error of the mean at n = 100,000 is sqrt(4/45 / 100_000) ≈ 9.4e-4.
	/// 0.005 is ≈5.3 standard errors — wide enough that no legitimate seed fails,
	/// tight enough that the old `var m = T(randomSeed)` bias (a U(0,1) draw
	/// contributing 1/n of itself, plus any accumulator that fails to average)
	/// could not hide inside it.
	@Test("Seeded estimate of x² over [0,1] approaches 1/3")
	func seededEstimateIsUnbiased() {
		let estimate = integrate(square, iterations: 100_000, seed: 20_260_809)
		#expect(abs(estimate - 1.0 / 3.0) < 0.005)
	}

	@Test("Unseeded runs still integrate correctly")
	func unseededEstimateIsUnbiased() {
		let estimate = integrate(square, iterations: 100_000)
		#expect(abs(estimate - 1.0 / 3.0) < 0.01)
	}

	@Test("Caller-supplied generator reproduces the estimate")
	func callerSuppliedGeneratorIsReproducible() {
		var g1 = SplitMix64(seed: 7)
		var g2 = SplitMix64(seed: 7)
		let a: Double = integrate(square, iterations: 10_000, using: &g1)
		let b: Double = integrate(square, iterations: 10_000, using: &g2)
		#expect(identical(a, b))
	}

	/// A single sample is already the estimate: the accumulator must not carry a
	/// seed-derived value into it. With `n == 1` any such contamination is the whole
	/// answer rather than 1/n of it.
	@Test("One iteration returns exactly f(sample)")
	func singleIterationIsTheSample() {
		var g1 = SplitMix64(seed: 11)
		var g2 = SplitMix64(seed: 11)
		let estimate: Double = integrate(square, iterations: 1, using: &g1)
		let sample: Double = distributionUniform(Double.random(in: 0..<1, using: &g2))
		#expect(identical(estimate, square(sample)))
	}

	@Test("Non-positive iteration counts return zero")
	func nonPositiveIterationsReturnZero() {
		var rng = SplitMix64(seed: 5)
		let estimate: Double = integrate(square, iterations: 0, using: &rng)
		#expect(estimate == 0)
	}
}
