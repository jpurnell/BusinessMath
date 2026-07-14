//
//  SeededDistributionsCompositeTests.swift
//  BusinessMathTests
//
//  RED-phase tests for SeedableDistribution conformance of the composite
//  distributions: DistributionGamma, DistributionBeta, DistributionT, DistributionF
//  (MonteCarloDeterminismAndAsyncExecution proposal, Phase 1).
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Seeded composite distributions")
struct SeededDistributionsCompositeTests {

	// MARK: - DistributionGamma (shape r, rate λ — mean r/λ, variance r/λ²)

	@Test("DistributionGamma: same generator seed yields identical sample stream")
	func gammaDeterministicStream() {
		let dist = DistributionGamma(r: 3, λ: 2.0)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionGamma: different seeds yield different streams")
	func gammaSeedsDiverge() {
		let dist = DistributionGamma(r: 3, λ: 2.0)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionGamma: seeded samples match analytic moments")
	func gammaSeededMoments() {
		// Gamma with integer shape r = 3 and rate λ = 2: mean = r/λ, variance = r/λ².
		let dist = DistributionGamma(r: 3, λ: 2.0)
		var rng = SplitMix64(seed: 99)
		let n = 20_000
		let samples = (0..<n).map { _ in dist.next(using: &rng) }
		let mean = samples.reduce(0, +) / Double(n)
		let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n - 1)
		// Deterministic given the fixed seed — tight bounds are safe.
		#expect(abs(mean - 1.5) < 0.05)
		#expect(abs(variance - 0.75) < 0.05)
	}

	// MARK: - DistributionBeta (shape α, shape β — mean α/(α+β))

	@Test("DistributionBeta: same generator seed yields identical sample stream")
	func betaDeterministicStream() {
		let dist = DistributionBeta(alpha: 2.0, beta: 5.0)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionBeta: different seeds yield different streams")
	func betaSeedsDiverge() {
		let dist = DistributionBeta(alpha: 2.0, beta: 5.0)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionBeta: seeded samples match analytic moments")
	func betaSeededMoments() {
		// Beta(α = 2, β = 5): mean = α/(α+β) = 2/7,
		// variance = αβ/[(α+β)²(α+β+1)] = 10/392 ≈ 0.02551.
		let dist = DistributionBeta(alpha: 2.0, beta: 5.0)
		var rng = SplitMix64(seed: 99)
		let n = 20_000
		let samples = (0..<n).map { _ in dist.next(using: &rng) }
		let mean = samples.reduce(0, +) / Double(n)
		let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n - 1)
		#expect(abs(mean - 2.0 / 7.0) < 0.01)
		#expect(abs(variance - 10.0 / 392.0) < 0.005)
		// Beta support is [0, 1].
		#expect(samples.allSatisfy { $0 >= 0 && $0 <= 1 })
	}

	// MARK: - DistributionT (degrees of freedom ν — mean 0, variance ν/(ν−2) for ν > 2)

	@Test("DistributionT: same generator seed yields identical sample stream")
	func tDeterministicStream() {
		let dist = DistributionT(degreesOfFreedom: 8)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionT: different seeds yield different streams")
	func tSeedsDiverge() {
		let dist = DistributionT(degreesOfFreedom: 8)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionT: seeded samples match analytic moments")
	func tSeededMoments() {
		// t(ν = 8): mean = 0, variance = ν/(ν−2) = 8/6 ≈ 1.3333.
		let dist = DistributionT(degreesOfFreedom: 8)
		var rng = SplitMix64(seed: 99)
		let n = 20_000
		let samples = (0..<n).map { _ in dist.next(using: &rng) }
		let mean = samples.reduce(0, +) / Double(n)
		let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n - 1)
		#expect(abs(mean) < 0.05)
		#expect(abs(variance - 8.0 / 6.0) < 0.12)
	}

	// MARK: - DistributionF (df1, df2 — mean df2/(df2−2) for df2 > 2)

	@Test("DistributionF: same generator seed yields identical sample stream")
	func fDeterministicStream() {
		let dist = DistributionF(df1: 8, df2: 12)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionF: different seeds yield different streams")
	func fSeedsDiverge() {
		let dist = DistributionF(df1: 8, df2: 12)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionF: seeded samples match analytic moments")
	func fSeededMoments() {
		// F(df1 = 8, df2 = 12): mean = df2/(df2−2) = 12/10 = 1.2,
		// variance = 2·df2²·(df1+df2−2) / [df1·(df2−2)²·(df2−4)] = 5184/6400 = 0.81.
		let dist = DistributionF(df1: 8, df2: 12)
		var rng = SplitMix64(seed: 99)
		let n = 20_000
		let samples = (0..<n).map { _ in dist.next(using: &rng) }
		let mean = samples.reduce(0, +) / Double(n)
		let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n - 1)
		#expect(abs(mean - 1.2) < 0.05)
		#expect(abs(variance - 0.81) < 0.1)
		// F support is [0, ∞).
		#expect(samples.allSatisfy { $0 >= 0 })
	}

	// MARK: - Existential usability

	@Test("Composite distributions are usable through the SeedableDistribution existential")
	func compositesSeedableExistential() {
		let distributions: [any SeedableDistribution<Double>] = [
			DistributionGamma(r: 3, λ: 2.0),
			DistributionBeta(alpha: 2.0, beta: 5.0),
			DistributionT(degreesOfFreedom: 8),
			DistributionF(df1: 8, df2: 12)
		]
		var rng = SplitMix64(seed: 3)
		for dist in distributions {
			let value = dist.next(using: &rng)
			#expect(value.isFinite)
		}
	}
}
