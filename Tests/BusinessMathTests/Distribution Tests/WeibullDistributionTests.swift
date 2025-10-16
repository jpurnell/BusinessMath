//
//  WeibullDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("Weibull Distribution Tests")
struct WeibullDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.WeibullDistributionTests", category: #function)

	@Test("Weibull distribution function produces non-negative values")
	func weibullFunctionNonNegative() {
		// Test with various shape and scale values
		let shape = 2.0
		let scale = 5.0

		// Generate 1000 samples and verify all are >= 0
		for _ in 0..<1000 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			#expect(sample >= 0.0, "Weibull values must be non-negative")
		}
	}

	@Test("Weibull distribution function statistical properties")
	func weibullFunctionStatistics() {
		// Test Weibull(2, 5)
		// Mean = scale × Γ(1 + 1/shape) = 5 × Γ(1.5) ≈ 5 × 0.8862 ≈ 4.431
		let shape = 2.0
		let scale = 5.0

		// For Weibull(k, λ), mean = λ × Γ(1 + 1/k)
		// For k=2: Γ(1.5) = sqrt(π)/2 ≈ 0.8862
		let gamma15 = 0.8862  // Γ(1.5)
		let expectedMean = scale * gamma15

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.15  // 15% tolerance for sampling variance

		#expect(empiricalMean > expectedMean * (1 - tolerance))
		#expect(empiricalMean < expectedMean * (1 + tolerance))
	}

	@Test("Weibull distribution struct random() method")
	func weibullStructRandom() {
		let distribution = DistributionWeibull(shape: 3.0, scale: 2.0)

		// Test that random() produces values in valid range
		for _ in 0..<100 {
			let sample = distribution.random()
			#expect(sample >= 0.0)
		}
	}

	@Test("Weibull distribution struct next() method")
	func weibullStructNext() {
		let distribution = DistributionWeibull(shape: 2.5, scale: 4.0)

		// Test that next() produces values in valid range
		var samples: [Double] = []
		for _ in 0..<1000 {
			let sample = distribution.next()
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// Verify mean is reasonable (all samples should be positive)
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(empiricalMean > 0.0)
	}

	@Test("Weibull distribution exponential case (shape = 1)")
	func weibullExponentialCase() {
		// When shape = 1, Weibull reduces to exponential distribution
		// Mean = scale
		let shape = 1.0
		let scale = 3.0
		let expectedMean = scale

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.15  // 15% tolerance

		#expect(empiricalMean > expectedMean * (1 - tolerance))
		#expect(empiricalMean < expectedMean * (1 + tolerance))
	}

	@Test("Weibull distribution with shape < 1 (decreasing failure rate)")
	func weibullDecreasingFailureRate() {
		// When shape < 1, failure rate decreases over time
		// Example: early failures, infant mortality
		let shape = 0.5
		let scale = 2.0

		var samples: [Double] = []
		for _ in 0..<1000 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// Distribution should be right-skewed with many small values
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(empiricalMean > 0.0)
	}

	@Test("Weibull distribution with shape > 1 (increasing failure rate)")
	func weibullIncreasingFailureRate() {
		// When shape > 1, failure rate increases over time (wear-out)
		// Example: mechanical component wear
		let shape = 3.0
		let scale = 5.0

		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// All samples should be non-negative
		let allNonNegative = samples.allSatisfy { $0 >= 0.0 }
		#expect(allNonNegative)
	}

	@Test("Weibull distribution with shape = 2 (Rayleigh-like)")
	func weibullRayleighLike() {
		// When shape ≈ 2, Weibull is similar to Rayleigh distribution
		let shape = 2.0
		let scale = 5.0

		var samples: [Double] = []
		for _ in 0..<1500 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// Verify reasonable distribution
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(empiricalMean > 0.0)
		#expect(empiricalMean < scale * 2.0, "Mean should be less than 2× scale")
	}

	@Test("Weibull distribution with small scale parameter")
	func weibullSmallScale() {
		// Test with small scale parameter
		let shape = 2.0
		let scale = 0.5

		var samples: [Double] = []
		for _ in 0..<500 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// All samples should be non-negative
		let allNonNegative = samples.allSatisfy { $0 >= 0.0 }
		#expect(allNonNegative)
	}

	@Test("Weibull distribution with large scale parameter")
	func weibullLargeScale() {
		// Test with large scale parameter
		let shape = 1.5
		let scale = 100.0

		var samples: [Double] = []
		for _ in 0..<500 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// Verify mean is proportional to scale
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(empiricalMean > 0.0)
		#expect(empiricalMean < scale * 2.0, "Mean should scale with scale parameter")
	}

	@Test("Weibull distribution with large shape parameter")
	func weibullLargeShape() {
		// Test with large shape parameter (approaches normal distribution)
		let shape = 10.0
		let scale = 5.0

		var samples: [Double] = []
		for _ in 0..<1000 {
			let sample: Double = distributionWeibull(shape: shape, scale: scale)
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// With large shape, distribution becomes more peaked around the mode
		let allNonNegative = samples.allSatisfy { $0 >= 0.0 }
		#expect(allNonNegative)
	}
}
