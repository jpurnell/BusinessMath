//
//  ExponentialDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/25.
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif

@testable import BusinessMath

@Suite("Exponential Distribution Tests")
struct ExponentialDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.ExponentialDistributionTests", category: #function)

	// Helper function to generate seeds for Exponential distribution using SeededRNG
	// Exponential uses inverse transform with 1 seed per sample
	static func seedsForExponential(count: Int) -> [Double] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 22222)  // Unique seed for Exponential
		var seeds: [Double] = []

		for _ in 0..<count {
			var seed = rng.next()
			seed = max(0.0001, min(0.9999, seed))
			seeds.append(seed)
		}

		return seeds
	}

	@Test("Exponential distribution function produces non-negative values")
	func exponentialFunctionNonNegative() {
		let λ = 1.0
		let sampleCount = 1000
		let seeds = Self.seedsForExponential(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = distributionExponential(λ: λ, seed: seeds[i])
			#expect(sample >= 0, "Exponential values must be non-negative")
			#expect(sample.isFinite, "Exponential values must be finite")
			#expect(!sample.isNaN, "Exponential values must not be NaN")
		}
	}

	@Test("Exponential distribution statistical properties - mean = 1/λ")
	func exponentialStatisticalProperties() {
		// Test Exponential(λ=2)
		// Mean = 1/λ = 0.5
		let λ = 2.0
		let expectedMean = 1.0 / λ
		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionExponential(λ: λ, seed: seeds[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.05

		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to 1/λ")
	}

	@Test("Exponential distribution with λ=1")
	func exponentialLambdaOne() {
		// Standard exponential with λ=1, mean=1
		let λ = 1.0
		let expectedMean = 1.0
		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionExponential(λ: λ, seed: seeds[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - expectedMean) < 0.05, "Mean should be close to 1")
	}

	@Test("Exponential distribution memoryless property")
	func exponentialMemoryless() {
		// The memoryless property: P(X > s+t | X > s) = P(X > t)
		// Test by checking that the distribution of (X - s | X > s) matches Exp(λ)
		let λ = 1.0
		let threshold = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionExponential(λ: λ, seed: seeds[i])
			samples.append(sample)
		}

		// Filter samples > threshold and shift them
		let conditionedSamples = samples.filter { $0 > threshold }.map { $0 - threshold }

		// Mean of conditioned samples should still be ≈ 1/λ (memoryless)
		if !conditionedSamples.isEmpty {
			let conditionedMean = conditionedSamples.reduce(0, +) / Double(conditionedSamples.count)
			let expectedMean = 1.0 / λ
			#expect(abs(conditionedMean - expectedMean) < 0.2, "Memoryless property: conditioned mean should be ≈ 1/λ")
		}
	}
	
	@Test("Exponential distribution memoryless property reiterated")
	func exponentialMemorylessReiterated() {
			let λ = 2.0
			let sampleCount = 10000
			let seeds = Self.seedsForExponential(count: sampleCount)

			var samples: [Double] = []
			for i in 0..<sampleCount {
					samples.append(distributionExponential(λ: λ, seed: seeds[i]))
			}

			let threshold = 2.0
			let conditionedSamples = samples.filter { $0 > threshold }.map { $0 - threshold }

			// Should observe the mean should still be lambda^-1
			if !conditionedSamples.isEmpty {
					let conditionedMean = conditionedSamples.reduce(0, +) / Double(conditionedSamples.count)
				#expect(abs(conditionedMean) - (1.0 / λ) < 0.2)
			}
	}

	@Test("Exponential distribution rate parameter effects")
	func exponentialRateParameter() {
		// Higher λ (rate) means shorter wait times (smaller mean)
		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samplesλ1: [Double] = []
		var samplesλ5: [Double] = []

		for i in 0..<sampleCount {
			samplesλ1.append(distributionExponential(λ: 1.0, seed: seeds[i]))
			samplesλ5.append(distributionExponential(λ: 5.0, seed: seeds[i]))
		}

		let meanλ1 = samplesλ1.reduce(0, +) / Double(samplesλ1.count)
		let meanλ5 = samplesλ5.reduce(0, +) / Double(samplesλ5.count)

		// λ=5 should have mean ≈ 0.2, λ=1 should have mean ≈ 1.0
		#expect(meanλ5 < meanλ1, "Higher rate should produce smaller mean")
		#expect(meanλ1 > 4 * meanλ5, "Mean should scale inversely with rate")
	}

	@Test("Exponential distribution CDF approximation")
	func exponentialCDF() {
		// CDF: F(x) = 1 - e^(-λx)
		// For λ=1, F(1) ≈ 0.632
		let λ = 1.0
		let x = 1.0
		let expectedCDF = 1.0 - exp(-λ * x)  // ≈ 0.632

		let sampleCount = 10000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		let countBelowX = samples.filter { $0 <= x }.count
		let empiricalCDF = Double(countBelowX) / Double(samples.count)

		#expect(abs(empiricalCDF - expectedCDF) < 0.02, "Empirical CDF should match theoretical")
	}

	@Test("Exponential distribution struct random() method")
	func exponentialStructRandom() {
		let λ = 2.0
		let dist = DistributionExponential(λ)

		let sampleCount = 1000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.random()
			samples.append(sample)
			#expect(sample >= 0)
			#expect(sample.isFinite)
		}

		// Check mean
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0 / λ
		#expect(abs(empiricalMean - expectedMean) < 0.1, "Mean should be close to 1/λ")
	}

	@Test("Exponential distribution struct next() method")
	func exponentialStructNext() {
		let λ = 0.5
		let dist = DistributionExponential(λ)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.next()
			samples.append(sample)
			#expect(sample >= 0)
			#expect(sample.isFinite)
		}

		// Verify mean
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0 / λ  // 2.0
		#expect(abs(empiricalMean - expectedMean) < 0.2, "Mean should be close to expected")
	}

	@Test("Exponential distribution with different rates")
	func exponentialDifferentRates() {
		// Test that different rates produce different distributions
		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount)

		let rates = [0.5, 1.0, 2.0, 5.0]
		var means: [Double] = []

		for rate in rates {
			var samples: [Double] = []
			for i in 0..<sampleCount {
				samples.append(distributionExponential(λ: rate, seed: seeds[i]))
			}
			let mean = samples.reduce(0, +) / Double(samples.count)
			means.append(mean)
		}

		// Means should decrease as rate increases
		for i in 1..<means.count {
			#expect(means[i] < means[i-1], "Higher rate should produce smaller mean")
		}

		// Check that means approximately equal 1/λ
		for i in 0..<rates.count {
			let expectedMean = 1.0 / rates[i]
			#expect(abs(means[i] - expectedMean) < 0.2, "Mean should match 1/λ")
		}
	}

	@Test("Exponential distribution median")
	func exponentialMedian() {
		// Median = ln(2)/λ
		let λ = 1.0
		let expectedMedian = log(2.0) / λ  // ≈ 0.693

		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		let sorted = samples.sorted()
		let empiricalMedian = sorted[sorted.count / 2]

		#expect(abs(empiricalMedian - expectedMedian) < 0.05, "Median should match ln(2)/λ")
	}

	@Test("Exponential distribution 50th and 90th percentiles")
	func exponentialPercentiles() {
		let λ = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		let sorted = samples.sorted()

		// 50th percentile (median) = ln(2)/λ ≈ 0.693
		let p50 = sorted[sorted.count / 2]
		let expectedP50 = log(2.0) / λ
		#expect(abs(p50 - expectedP50) < 0.1, "50th percentile should match ln(2)/λ")

		// 90th percentile: -ln(1-0.9)/λ = -ln(0.1)/λ ≈ 2.303
		let p90Index = Int(Double(sorted.count) * 0.9)
		let p90 = sorted[p90Index]
		let expectedP90 = -log(0.1) / λ
		#expect(abs(p90 - expectedP90) < 0.2, "90th percentile should match -ln(0.1)/λ")
	}

	@Test("Exponential distribution right-skewed property")
	func exponentialRightSkewed() {
		// Exponential is right-skewed: mean > median
		let λ = 1.0
		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		#expect(mean > median, "Exponential should be right-skewed (mean > median)")
	}

	@Test("Exponential distribution seeding produces deterministic results")
	func exponentialDeterministicSeeding() {
		let λ = 2.0
		let seeds = Self.seedsForExponential(count: 100)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(distributionExponential(λ: λ, seed: seeds[i]))
			samples2.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("Exponential distribution struct stores rate parameter")
	func exponentialStructParameters() {
		let λ = 3.0
		let dist = DistributionExponential(λ)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be non-negative
		#expect(samples.allSatisfy { $0 >= 0 })

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0 / λ
		#expect(abs(empiricalMean - expectedMean) < 0.1, "Distribution should maintain consistent properties")
	}

	@Test("Exponential distribution extreme values are rare")
	func exponentialExtremeValues() {
		// Very large values should be rare
		let λ = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		// Count values > 5 (should be rare for λ=1)
		let extremeValues = samples.filter { $0 > 5.0 }.count
		let extremePercent = Double(extremeValues) / Double(samples.count)

		// P(X > 5) = e^(-5) ≈ 0.0067 (< 1%)
		#expect(extremePercent < 0.02, "Extreme values should be rare")
	}
	
	@Test("Exponential relationship to other distributions")
	func exponentialDistributionRelationships() {
		// Exponential is special case of Gamma(1, 1/λ)
		// Also related to Poisson process
		let λ = 2.0
		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var exponentialSamples: [Double] = []
		for i in 0..<sampleCount {
			exponentialSamples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		// Compare with Gamma(1, 1/λ) - should be identical
		var gammaSamples: [Double] = []
		var seedIndex = 0
		for i in 0..<sampleCount {
			// Gamma(shape=1, scale=1/λ) = Exponential(λ)
			gammaSamples.append(gammaVariate(shape: 1.0, scale: 1.0/λ, seeds: [seeds[i]], seedIndex: &seedIndex))
		}

		let expMean = exponentialSamples.reduce(0, +) / Double(exponentialSamples.count)
		let gammaMean = gammaSamples.reduce(0, +) / Double(gammaSamples.count)

		#expect(abs(expMean - gammaMean) < 0.1, "Exponential should match Gamma(1, 1/λ)")
	}
	
	@Test("Minimum of exponential random variables")
	func exponentialMinimumProperty() {
		// min(X₁, X₂, ..., Xₙ) ~ Exponential(λ₁ + λ₂ + ... + λₙ)
		let λ1 = 1.0
		let λ2 = 2.0
		let expectedλ = λ1 + λ2  // 3.0
		let expectedMean = 1.0 / expectedλ  // ≈ 0.333

		let sampleCount = 5000
		let seeds = Self.seedsForExponential(count: sampleCount * 2)

		var minSamples: [Double] = []
		for i in 0..<sampleCount {
			let sample1 = distributionExponential(λ: λ1, seed: seeds[i])
			let sample2 = distributionExponential(λ: λ2, seed: seeds[i + sampleCount])
			minSamples.append(min(sample1, sample2))
		}

		let empiricalMean = minSamples.reduce(0, +) / Double(minSamples.count)
		#expect(abs(empiricalMean - expectedMean) < 0.05,
			   "Minimum of exponentials should have rate = sum of rates")
	}
	
	@Test("Exponential constant hazard rate")
	func exponentialConstantHazardRate() {
		// Hazard rate h(t) = f(t) / (1 - F(t)) = λ (constant)
		let λ = 1.5
		let sampleCount = 10000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		// Estimate hazard rate at different time points
		let timePoints: [Double] = [0.5, 1.0, 2.0, 3.0]

		for t in timePoints {
			// Count samples in [t, t+Δt] and surviving past t
			let Δt = 0.1
			let inInterval = samples.filter { $0 >= t && $0 < t + Δt }.count
			let surviving = samples.filter { $0 >= t }.count

			if surviving > 0 {
				let empiricalHazard = Double(inInterval) / (Double(surviving) * Δt)
				#expect(abs(empiricalHazard - λ) < 0.5,
					   "Hazard rate should be approximately constant at λ")
			}
		}
	}
	
	@Test("Exponential parameter validation")
	func exponentialParameterValidation() {
		// Test edge cases for λ parameter
		let edgeCases: [(λ: Double, description: String)] = [
			(0.001, "very small rate"),
			(1000.0, "very large rate"),
			(1e-10, "extremely small rate"),
			(1e10, "extremely large rate")
		]

		for testCase in edgeCases {
			let sample = distributionExponential(λ: testCase.λ, seed: 0.5)
			#expect(sample >= 0, "Should handle \(testCase.description)")
			#expect(sample.isFinite, "Should produce finite value for \(testCase.description)")
		}
	}
	
	@Test("Exponential moment generating function")
	func exponentialMGF() {
		// MGF: M(t) = λ / (λ - t) for t < λ
		// This implies E[X] = 1/λ, Var(X) = 1/λ²
		let λ = 2.0
		let sampleCount = 10000
		let seeds = Self.seedsForExponential(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)

		let expectedMean = 1.0 / λ
		let expectedVariance = 1.0 / (λ * λ)

		#expect(abs(mean - expectedMean) < 0.05, "Mean should match 1/λ")
		#expect(abs(variance - expectedVariance) < 0.05, "Variance should match 1/λ²")
	}
	
	@Test("Exponential order statistics")
	func exponentialOrderStatistics() {
		// For exponential, the order statistics have nice properties
		let λ = 1.0
		let sampleCount = 5000
		let n = 5  // Sample size for order statistics
		let seeds = Self.seedsForExponential(count: sampleCount * n)

		var minValues: [Double] = []

		for i in 0..<sampleCount {
			var sample: [Double] = []
			for j in 0..<n {
				sample.append(distributionExponential(λ: λ, seed: seeds[i * n + j]))
			}
			minValues.append(sample.min()!)
		}

		// Minimum of n exponentials should be Exponential(nλ)
		let minMean = minValues.reduce(0, +) / Double(minValues.count)
		let expectedMinMean = 1.0 / (Double(n) * λ)  // 0.2

		#expect(abs(minMean - expectedMinMean) < 0.02,
			   "Minimum of n exponentials should have mean 1/(nλ)")
	}
	
	@Test("Exponential distribution stress test")
	func exponentialStressTest() {
		// Test with very large sample sizes
		let λ = 1.0
		let veryLargeSampleCount = 100000
		let seeds = Self.seedsForExponential(count: veryLargeSampleCount)

		var samples: [Double] = []
		for i in 0..<veryLargeSampleCount {
			samples.append(distributionExponential(λ: λ, seed: seeds[i]))
		}

		// With large samples, statistics should be very accurate
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0 / λ

		#expect(abs(empiricalMean - expectedMean) < 0.01,
			   "Large sample mean should be very close to theoretical")

		// Variance should also be accurate
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count)
		let expectedVariance = 1.0 / (λ * λ)
		#expect(abs(variance - expectedVariance) < 0.01,
			   "Large sample variance should be very close to theoretical")
	}
}
