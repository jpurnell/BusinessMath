//
//  BetaDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif

@testable import BusinessMath

@Suite("Beta Distribution Tests")
struct BetaDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.BetaDistributionTests", category: #function)

	// Deterministic seeds for the distribution's `seed:` parameter. Each element seeds a
	// private xoshiro256** stream, which sizes itself to whatever the sampler asks for.
	// This used to hand out fixed-length `[Double]` budgets of pre-drawn uniforms; the
	// sampler consumes a data-dependent number of them and silently finished on the
	// global generator once a budget ran out, so the "deterministic" tests below were
	// only mostly deterministic.
	static func seedSetsForBeta(count: Int) -> [UInt64] {
		var rng = DeterministicRNG(seed: 76543)
		return (0..<count).map { _ in rng.next() }
	}

	@Test("Beta distribution function produces values in [0, 1]")
	func betaFunctionBounds() {
		// Test with various alpha and beta values
		let alpha = 2.0
		let beta = 5.0
		let sampleCount = 1000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		// Generate deterministic samples and verify all are in [0, 1]
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			#expect(sample >= 0.0, "Beta values must be >= 0")
			#expect(sample <= 1.0, "Beta values must be <= 1")
		}
	}

	@Test("Beta distribution function statistical properties")
	func betaFunctionStatistics() {
		// Test Beta(2, 5) - mean should be 2/(2+5) = 2/7 ≈ 0.2857
		let alpha = 2.0
		let beta = 5.0
		let expectedMean = alpha / (alpha + beta)
		let sampleCount = 2000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.03  // 3% tolerance for sampling variance

		#expect(empiricalMean > expectedMean - tolerance)
		#expect(empiricalMean < expectedMean + tolerance)
	}

	@Test("Beta distribution struct random() method")
	func betaStructRandom() {
		let alpha = 3.0
		let beta = 2.0

		// Test that seeded function produces values in valid range
		for i in 0..<100 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: UInt64(i) &+ 1)
			#expect(sample >= 0.0)
			#expect(sample <= 1.0)
		}
	}

	@Test("Beta distribution struct next() method")
	func betaStructNext() {
		// Use deterministic function variant for testing
		let alpha = 4.0
		let beta = 4.0
		let sampleCount = 1000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		// Test that function produces values in valid range
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
			#expect(sample <= 1.0)
		}

		// Verify mean is close to 0.5 (symmetric case)
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.03
		#expect(empiricalMean > 0.5 - tolerance)
		#expect(empiricalMean < 0.5 + tolerance)
	}

	@Test("Beta distribution symmetric case")
	func betaSymmetricCase() {
		// When alpha = beta, distribution is symmetric around 0.5
		let alpha = 10.0
		let beta = 10.0
		let sampleCount = 2000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 0.5
		let tolerance = 0.02

		#expect(empiricalMean > expectedMean - tolerance)
		#expect(empiricalMean < expectedMean + tolerance)
	}

	@Test("Beta distribution skewed right (alpha > beta)")
	func betaSkewedRight() {
		// When alpha > beta, distribution is skewed right (mean > 0.5)
		let alpha = 8.0
		let beta = 2.0
		let expectedMean = alpha / (alpha + beta)  // 0.8
		let sampleCount = 2000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.03

		#expect(empiricalMean > expectedMean - tolerance)
		#expect(empiricalMean < expectedMean + tolerance)
		#expect(empiricalMean > 0.5, "Alpha > beta should produce mean > 0.5")
	}

	@Test("Beta distribution skewed left (alpha < beta)")
	func betaSkewedLeft() {
		// When alpha < beta, distribution is skewed left (mean < 0.5)
		let alpha = 2.0
		let beta = 8.0
		let expectedMean = alpha / (alpha + beta)  // 0.2
		let sampleCount = 2000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.03

		#expect(empiricalMean > expectedMean - tolerance)
		#expect(empiricalMean < expectedMean + tolerance)
		#expect(empiricalMean < 0.5, "Alpha < beta should produce mean < 0.5")
	}

	@Test("Beta distribution with small alpha and beta")
	func betaSmallParameters() {
		// Test with small parameters (α = β = 0.5)
		// This produces a U-shaped distribution
		let alpha = 0.5
		let beta = 0.5
		let sampleCount = 1000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
			#expect(sample <= 1.0)
		}

		// Mean should still be 0.5 (symmetric)
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.05  // Larger tolerance for U-shaped distribution
		#expect(empiricalMean > 0.5 - tolerance)
		#expect(empiricalMean < 0.5 + tolerance)
	}

	@Test("Beta distribution with large alpha and beta")
	func betaLargeParameters() {
		// Test with large parameters (α = β = 50)
		// This produces a very peaked distribution around 0.5
		let alpha = 50.0
		let beta = 50.0
		let sampleCount = 2000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
			#expect(sample <= 1.0)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.02  // Tighter tolerance for peaked distribution
		#expect(empiricalMean > 0.5 - tolerance)
		#expect(empiricalMean < 0.5 + tolerance)
	}

	@Test("Beta distribution uniform case (alpha = beta = 1)")
	func betaUniformCase() {
		// When α = β = 1, Beta distribution is uniform on [0, 1]
		let alpha = 1.0
		let beta = 1.0
		let sampleCount = 2000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
			samples.append(sample)
		}

		// Mean should be 0.5
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.03
		#expect(empiricalMean > 0.5 - tolerance)
		#expect(empiricalMean < 0.5 + tolerance)

		// For uniform distribution, we expect roughly equal distribution across bins
		let binCount = samples.filter { $0 < 0.5 }.count
		let expectedBinCount = 1000  // Half of 2000 samples
		let binTolerance = 100.0  // Allow 10% deviation
		#expect(Double(binCount) > Double(expectedBinCount) - binTolerance)
		#expect(Double(binCount) < Double(expectedBinCount) + binTolerance)
	}
	
	// 1. Add variance verification for peaked distributions
	@Test("Beta distribution variance properties")
	func betaVariance() {
		let alpha = 2.0, beta = 5.0
		let expectedVariance = (alpha * beta) / (pow(alpha + beta, 2) * (alpha + beta + 1))
		let sampleCount = 5000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		let samples = (0..<sampleCount).map { i in
			distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let empiricalVariance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)

		#expect(abs(empiricalVariance - expectedVariance) < 0.01)
	}

	// 2. Test edge case behavior more rigorously
	@Test("Beta distribution extreme parameter values")
	func betaExtremeParameters() {
		// Test very small parameters
		let tinySample: Double = distributionBeta(alpha: 0.1, beta: 0.1, seed: 5150)
		#expect(tinySample >= 0.0 && tinySample <= 1.0)

		// Test very large parameters
		let largeSample: Double = distributionBeta(alpha: 1000.0, beta: 1000.0, seed: 5150)
		#expect(largeSample >= 0.0 && largeSample <= 1.0)
	}

	// 3. Add correlation test for consecutive samples
	@Test("Beta distribution independence")
	func betaIndependence() {
		let alpha = 2.0, beta = 2.0
		let sampleCount = 1000
		let seedSets = Self.seedSetsForBeta(count: sampleCount)

		let samples = (0..<sampleCount).map { i in
			distributionBeta(alpha: alpha, beta: beta, seed: seedSets[i])
		}

		// A normalised lag-1 autocorrelation, because the raw product moment could not
		// fail. Beta(2, 2) has mean 0.5 and variance αβ/((α+β)²(α+β+1)) = 4/(16·5) = 0.05,
		// so E[X₁X₂] = 0.25 + 0.05ρ. Asserting |E[X₁X₂] − 0.25| < 0.05 therefore asserts
		// |ρ| < 1 — true of every possible correlation, including ρ = 0.999.
		//
		// Dividing by the sample variance removes that: ρ̂ is on [−1, 1] whatever the
		// variance happens to be, so the bound is about dependence rather than about scale.
		let mean = samples.reduce(0.0, +) / Double(sampleCount)
		let centred = samples.map { $0 - mean }
		var covariance = 0.0
		for i in 0..<(sampleCount - 1) {
			covariance += centred[i] * centred[i + 1]
		}
		let variance = centred.reduce(0.0) { $0 + $1 * $1 }
		let rho = covariance / variance

		// 4/√n is four standard errors of a lag-1 correlation under independence, where
		// se ≈ 1/√n. At n = 1000 that is 0.1265, and a stream with any real serial
		// structure exceeds it.
		let bound = 4.0 / Double(sampleCount).squareRoot()
		#expect(abs(rho) < bound,
				"lag-1 autocorrelation \(rho) exceeds \(bound), four standard errors under independence")
	}
}
