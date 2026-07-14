//
//  SeededDistributionsFormulaTests.swift
//  BusinessMathTests
//
//  RED-phase tests for SeedableDistribution conformances of the
//  formula-based distributions: Weibull, Logistic, Geometric, Pareto,
//  and Chi-squared.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("SeedableDistribution formula-based conformances")
struct SeededDistributionsFormulaTests {

	// MARK: - Helpers

	private func sampleMean(_ samples: [Double]) -> Double {
		samples.reduce(0, +) / Double(samples.count)
	}

	private func sampleVariance(_ samples: [Double]) -> Double {
		let mean = sampleMean(samples)
		return samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count - 1)
	}

	// MARK: - Weibull

	@Test("DistributionWeibull: same generator seed yields identical sample stream")
	func weibullDeterministicStream() {
		let dist = DistributionWeibull(shape: 2.0, scale: 2.0)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionWeibull: different seeds yield different streams")
	func weibullSeedsDiverge() {
		let dist = DistributionWeibull(shape: 2.0, scale: 2.0)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionWeibull: seeded samples match analytic moments")
	func weibullSeededMoments() {
		// Weibull(k, λ): mean = λΓ(1 + 1/k), var = λ²[Γ(1 + 2/k) − Γ(1 + 1/k)²]
		let shape = 2.0
		let scale = 2.0
		let gamma1 = Double.gamma(1 + 1 / shape)
		let gamma2 = Double.gamma(1 + 2 / shape)
		let analyticMean = scale * gamma1
		let analyticVariance = scale * scale * (gamma2 - gamma1 * gamma1)

		let dist = DistributionWeibull(shape: shape, scale: scale)
		var rng = SplitMix64(seed: 99)
		let samples = (0..<20_000).map { _ in dist.next(using: &rng) }
		// Deterministic given the fixed seed — tight bounds are safe.
		#expect(abs(sampleMean(samples) - analyticMean) < 0.03)
		#expect(abs(sampleVariance(samples) - analyticVariance) < 0.05)
	}

	// MARK: - Logistic

	@Test("DistributionLogistic: same generator seed yields identical sample stream")
	func logisticDeterministicStream() {
		let dist = DistributionLogistic(10, 2)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionLogistic: different seeds yield different streams")
	func logisticSeedsDiverge() {
		let dist = DistributionLogistic(10, 2)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionLogistic: seeded samples match analytic moments")
	func logisticSeededMoments() {
		// DistributionLogistic is parameterized directly by mean and stdDev
		// (the scale is derived internally as stdDev·√3/π), so:
		// mean = mean, var = stdDev².
		let analyticMean = 10.0
		let analyticVariance = 4.0

		let dist = DistributionLogistic(10, 2)
		var rng = SplitMix64(seed: 99)
		let samples = (0..<20_000).map { _ in dist.next(using: &rng) }
		// Deterministic given the fixed seed — tight bounds are safe.
		#expect(abs(sampleMean(samples) - analyticMean) < 0.06)
		#expect(abs(sampleVariance(samples) - analyticVariance) < 0.25)
	}

	// MARK: - Geometric

	@Test("DistributionGeometric: same generator seed yields identical sample stream")
	func geometricDeterministicStream() {
		let dist = DistributionGeometric(0.3)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionGeometric: different seeds yield different streams")
	func geometricSeedsDiverge() {
		let dist = DistributionGeometric(0.3)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionGeometric: seeded samples match analytic moments")
	func geometricSeededMoments() {
		// This implementation uses the "number of trials until first success"
		// convention (support {1, 2, 3, ...}): mean = 1/p, var = (1-p)/p².
		let p = 0.3
		let analyticMean = 1 / p
		let analyticVariance = (1 - p) / (p * p)

		let dist = DistributionGeometric(p)
		var rng = SplitMix64(seed: 99)
		let samples = (0..<20_000).map { _ in dist.next(using: &rng) }
		// All samples must respect the support convention (X ≥ 1).
		#expect(samples.allSatisfy { $0 >= 1 })
		// Deterministic given the fixed seed — tight bounds are safe.
		#expect(abs(sampleMean(samples) - analyticMean) < 0.09)
		#expect(abs(sampleVariance(samples) - analyticVariance) < 0.6)
	}

	// MARK: - Pareto

	@Test("DistributionPareto: same generator seed yields identical sample stream")
	func paretoDeterministicStream() {
		let dist = DistributionPareto(scale: 2.0, shape: 5.0)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionPareto: different seeds yield different streams")
	func paretoSeedsDiverge() {
		let dist = DistributionPareto(scale: 2.0, shape: 5.0)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionPareto: seeded samples match analytic moments")
	func paretoSeededMoments() {
		// Pareto(xₘ, α): mean = α·xₘ/(α−1) for α > 1,
		// var = xₘ²·α/((α−1)²(α−2)) for α > 2.
		let scale = 2.0
		let shape = 5.0
		let analyticMean = shape * scale / (shape - 1)
		let analyticVariance = scale * scale * shape / ((shape - 1) * (shape - 1) * (shape - 2))

		let dist = DistributionPareto(scale: scale, shape: shape)
		var rng = SplitMix64(seed: 99)
		let samples = (0..<20_000).map { _ in dist.next(using: &rng) }
		// All samples must respect the support (X ≥ xₘ).
		#expect(samples.allSatisfy { $0 >= scale })
		// Deterministic given the fixed seed — tight bounds are safe
		// (the variance tolerance reflects the heavy Pareto tail).
		#expect(abs(sampleMean(samples) - analyticMean) < 0.03)
		#expect(abs(sampleVariance(samples) - analyticVariance) < 0.12)
	}

	// MARK: - Chi-squared

	@Test("DistributionChiSquared: same generator seed yields identical sample stream")
	func chiSquaredDeterministicStream() {
		let dist = DistributionChiSquared(degreesOfFreedom: 4)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionChiSquared: different seeds yield different streams")
	func chiSquaredSeedsDiverge() {
		let dist = DistributionChiSquared(degreesOfFreedom: 4)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionChiSquared: seeded samples match analytic moments")
	func chiSquaredSeededMoments() {
		// χ²(k): mean = k, var = 2k.
		let degreesOfFreedom = 4
		let analyticMean = Double(degreesOfFreedom)
		let analyticVariance = 2 * Double(degreesOfFreedom)

		let dist = DistributionChiSquared(degreesOfFreedom: degreesOfFreedom)
		var rng = SplitMix64(seed: 99)
		let samples = (0..<20_000).map { _ in dist.next(using: &rng) }
		// All samples must respect the support (X ≥ 0).
		#expect(samples.allSatisfy { $0 >= 0 })
		// Deterministic given the fixed seed — tight bounds are safe.
		#expect(abs(sampleMean(samples) - analyticMean) < 0.09)
		#expect(abs(sampleVariance(samples) - analyticVariance) < 0.5)
	}
}
