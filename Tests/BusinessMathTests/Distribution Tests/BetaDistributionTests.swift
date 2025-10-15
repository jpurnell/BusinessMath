//
//  BetaDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Beta Distribution Tests")
struct BetaDistributionTests {

	@Test("Beta distribution function produces values in [0, 1]")
	func betaFunctionBounds() {
		// Test with various alpha and beta values
		let alpha = 2.0
		let beta = 5.0

		// Generate 1000 samples and verify all are in [0, 1]
		for _ in 0..<1000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
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

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.03  // 3% tolerance for sampling variance

		#expect(empiricalMean > expectedMean - tolerance)
		#expect(empiricalMean < expectedMean + tolerance)
	}

	@Test("Beta distribution struct random() method")
	func betaStructRandom() {
		let distribution = DistributionBeta(alpha: 3.0, beta: 2.0)

		// Test that random() produces values in valid range
		for _ in 0..<100 {
			let sample = distribution.random()
			#expect(sample >= 0.0)
			#expect(sample <= 1.0)
		}
	}

	@Test("Beta distribution struct next() method")
	func betaStructNext() {
		let distribution = DistributionBeta(alpha: 4.0, beta: 4.0)

		// Test that next() produces values in valid range
		var samples: [Double] = []
		for _ in 0..<1000 {
			let sample = distribution.next()
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

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
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

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
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

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
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

		var samples: [Double] = []
		for _ in 0..<1000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
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

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
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

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionBeta(alpha: alpha, beta: beta)
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
}
