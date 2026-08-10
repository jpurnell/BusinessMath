//
//  SeededDistributionsSimpleTests.swift
//  BusinessMathTests
//
//  RED-phase tests for SeedableDistribution conformances of the simple
//  distributions: Uniform, Triangular, Exponential, LogNormal, Rayleigh.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("SeedableDistribution simple conformances")
struct SeededDistributionsSimpleTests {

	/// Draws `count` seeded samples from `distribution` using a fresh SplitMix64.
	private func samples<D: SeedableDistribution<Double>>(_ distribution: D, seed: UInt64, count: Int) -> [Double] {
		var rng = SplitMix64(seed: seed)
		return (0..<count).map { _ in distribution.next(using: &rng) }
	}

	/// Sample mean of `values`.
	private func mean(_ values: [Double]) -> Double {
		values.reduce(0, +) / Double(values.count)
	}

	/// Unbiased sample variance of `values`.
	private func variance(_ values: [Double]) -> Double {
		let m = mean(values)
		return values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count - 1)
	}

	// MARK: - DistributionUniform

	@Test("DistributionUniform: same seed yields identical sample stream")
	func uniformDeterministicStream() {
		let dist = DistributionUniform(2.0, 10.0)
		#expect(samples(dist, seed: 42, count: 50) == samples(dist, seed: 42, count: 50))
	}

	@Test("DistributionUniform: different seeds yield different streams")
	func uniformSeedsDiverge() {
		let dist = DistributionUniform(2.0, 10.0)
		#expect(samples(dist, seed: 1, count: 50) != samples(dist, seed: 2, count: 50))
	}

	@Test("DistributionUniform: seeded samples match analytic moments")
	func uniformSeededMoments() {
		// Uniform(a, b): mean (a + b) / 2, variance (b - a)^2 / 12.
		let dist = DistributionUniform(2.0, 10.0)
		let s = samples(dist, seed: 99, count: 20_000)
		// Deterministic given the fixed seed — tight bounds are safe.
		#expect(abs(mean(s) - 6.0) < 0.09)
		#expect(abs(variance(s) - 64.0 / 12.0) < 0.18)
	}

	// MARK: - DistributionTriangular

	@Test("DistributionTriangular: same seed yields identical sample stream")
	func triangularDeterministicStream() {
		let dist = DistributionTriangular(low: 0.0, high: 10.0, base: 4.0)
		#expect(samples(dist, seed: 42, count: 50) == samples(dist, seed: 42, count: 50))
	}

	@Test("DistributionTriangular: different seeds yield different streams")
	func triangularSeedsDiverge() {
		let dist = DistributionTriangular(low: 0.0, high: 10.0, base: 4.0)
		#expect(samples(dist, seed: 1, count: 50) != samples(dist, seed: 2, count: 50))
	}

	@Test("DistributionTriangular: seeded samples match analytic moments")
	func triangularSeededMoments() {
		// Triangular(a, b, c): mean (a + b + c) / 3,
		// variance (a^2 + b^2 + c^2 - ab - ac - bc) / 18.
		let dist = DistributionTriangular(low: 0.0, high: 10.0, base: 4.0)
		let s = samples(dist, seed: 99, count: 20_000)
		#expect(abs(mean(s) - 14.0 / 3.0) < 0.075)
		#expect(abs(variance(s) - 76.0 / 18.0) < 0.18)
	}

	// MARK: - DistributionExponential

	@Test("DistributionExponential: same seed yields identical sample stream")
	func exponentialDeterministicStream() {
		let dist = DistributionExponential(0.5)
		#expect(samples(dist, seed: 42, count: 50) == samples(dist, seed: 42, count: 50))
	}

	@Test("DistributionExponential: different seeds yield different streams")
	func exponentialSeedsDiverge() {
		let dist = DistributionExponential(0.5)
		#expect(samples(dist, seed: 1, count: 50) != samples(dist, seed: 2, count: 50))
	}

	@Test("DistributionExponential: seeded samples match analytic moments")
	func exponentialSeededMoments() {
		// Exponential(λ): mean 1/λ, variance 1/λ^2.
		let dist = DistributionExponential(0.5)
		let s = samples(dist, seed: 99, count: 20_000)
		#expect(abs(mean(s) - 2.0) < 0.075)
		#expect(abs(variance(s) - 4.0) < 0.4)
	}

	// MARK: - DistributionLogNormal

	@Test("DistributionLogNormal: same seed yields identical sample stream")
	func logNormalDeterministicStream() {
		let dist = DistributionLogNormal(0.0, 0.5)
		#expect(samples(dist, seed: 42, count: 50) == samples(dist, seed: 42, count: 50))
	}

	@Test("DistributionLogNormal: different seeds yield different streams")
	func logNormalSeedsDiverge() {
		let dist = DistributionLogNormal(0.0, 0.5)
		#expect(samples(dist, seed: 1, count: 50) != samples(dist, seed: 2, count: 50))
	}

	@Test("DistributionLogNormal: seeded samples match analytic moments")
	func logNormalSeededMoments() {
		// LogNormal(µ = 0, σ = 0.5): mean exp(µ + σ²/2) = exp(0.125),
		// variance (exp(σ²) - 1) · exp(2µ + σ²) = (exp(0.25) - 1) · exp(0.25).
		let dist = DistributionLogNormal(0.0, 0.5)
		let s = samples(dist, seed: 99, count: 20_000)
		let expectedMean = Foundation.exp(0.125)
		let expectedVariance = (Foundation.exp(0.25) - 1.0) * Foundation.exp(0.25)
		#expect(abs(mean(s) - expectedMean) < 0.025)
		#expect(abs(variance(s) - expectedVariance) < 0.04)
	}

	// MARK: - DistributionRayleigh

	@Test("DistributionRayleigh: same seed yields identical sample stream")
	func rayleighDeterministicStream() {
		let dist = DistributionRayleigh(scale: 2.0)
		#expect(samples(dist, seed: 42, count: 50) == samples(dist, seed: 42, count: 50))
	}

	@Test("DistributionRayleigh: different seeds yield different streams")
	func rayleighSeedsDiverge() {
		let dist = DistributionRayleigh(scale: 2.0)
		#expect(samples(dist, seed: 1, count: 50) != samples(dist, seed: 2, count: 50))
	}

	@Test("DistributionRayleigh: seeded samples match analytic moments")
	func rayleighSeededMoments() {
		// The implementation samples X = m·sqrt(-2·ln U), i.e. a Rayleigh with
		// scale σ = m, so: mean σ·sqrt(π/2), variance (2 - π/2)·σ².
		let m = 2.0
		let dist = DistributionRayleigh(scale: m)
		let s = samples(dist, seed: 99, count: 20_000)
		let expectedMean = m * Foundation.sqrt(Double.pi / 2.0)
		let expectedVariance = (2.0 - Double.pi / 2.0) * m * m
		#expect(abs(mean(s) - expectedMean) < 0.05)
		#expect(abs(variance(s) - expectedVariance) < 0.09)
	}
}
