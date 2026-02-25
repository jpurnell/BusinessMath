//
//  GammaDistributionTests.swift
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

@Suite("Gamma Distribution Tests")
struct GammaDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.GammaDistributionTests", category: #function)

	// Helper function to generate seeds for Gamma distribution using SeededRNG
	// Gamma(r, λ) as sum of r exponentials needs r seeds
	static func seedsForGamma(count: Int, shape: Int) -> [[Double]] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 44444)  // Unique seed for Gamma
		var seedArrays: [[Double]] = []

		for _ in 0..<count {
			var seeds: [Double] = []
			for _ in 0..<shape {
				var seed = rng.next()
				seed = max(0.0001, min(0.9999, seed))
				seeds.append(seed)
			}
			seedArrays.append(seeds)
		}

		return seedArrays
	}

	@Test("Gamma distribution function produces non-negative values")
	func gammaFunctionNonNegative() {
		let r = 3
		let λ = 2.0
		let sampleCount = 1000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		for i in 0..<sampleCount {
			let sample: Double = distributionGamma(r: r, λ: λ, seeds: seedArrays[i])
			#expect(sample >= 0, "Gamma values must be non-negative")
			#expect(sample.isFinite, "Gamma values must be finite")
			#expect(!sample.isNaN, "Gamma values must not be NaN")
		}
	}

	@Test("Gamma distribution statistical properties - mean = r/λ")
	func gammaStatisticalProperties() {
		// Test Gamma(r=5, λ=2)
		// Mean = r/λ = 5/2 = 2.5
		let r = 5
		let λ = 2.0
		let expectedMean = Double(r) / λ
		let sampleCount = 5000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionGamma(r: r, λ: λ, seeds: seedArrays[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.1

		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to r/λ")
	}

	@Test("Gamma distribution with r=1 equals Exponential")
	func gammaReducesToExponential() {
		// Gamma(1, λ) = Exponential(λ)
		let r = 1
		let λ = 2.0
		let expectedMean = 1.0 / λ  // Mean of Exponential(λ)
		let sampleCount = 5000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionGamma(r: r, λ: λ, seeds: seedArrays[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - expectedMean) < 0.05, "Gamma(1,λ) should match Exponential(λ)")
	}

	@Test("Gamma distribution variance = r/λ²")
	func gammaVariance() {
		let r = 4
		let λ = 2.0
		let expectedMean = Double(r) / λ
		let expectedVariance = Double(r) / (λ * λ)
		let sampleCount = 5000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)

		#expect(abs(empiricalMean - expectedMean) < 0.1, "Mean should match r/λ")
		#expect(abs(variance - expectedVariance) < 0.2, "Variance should match r/λ²")
	}

	@Test("Gamma distribution shape parameter effects")
	func gammaShapeParameter() {
		// Higher r means larger mean for fixed λ
		let λ = 1.0
		let sampleCount = 5000

		let seedArrays2 = Self.seedsForGamma(count: sampleCount, shape: 2)
		let seedArrays5 = Self.seedsForGamma(count: sampleCount, shape: 5)

		var samplesR2: [Double] = []
		var samplesR5: [Double] = []

		for i in 0..<sampleCount {
			samplesR2.append(distributionGamma(r: 2, λ: λ, seeds: seedArrays2[i]))
			samplesR5.append(distributionGamma(r: 5, λ: λ, seeds: seedArrays5[i]))
		}

		let meanR2 = samplesR2.reduce(0, +) / Double(samplesR2.count)
		let meanR5 = samplesR5.reduce(0, +) / Double(samplesR5.count)

		// r=5 should have mean ≈ 5, r=2 should have mean ≈ 2
		#expect(meanR5 > meanR2, "Higher shape should produce larger mean")
		#expect(abs(meanR2 - 2.0) < 0.2, "Mean should be close to r/λ")
		#expect(abs(meanR5 - 5.0) < 0.2, "Mean should be close to r/λ")
	}

	@Test("Gamma distribution rate parameter effects")
	func gammaRateParameter() {
		// Higher λ means smaller mean for fixed r
		let r = 3
		let sampleCount = 5000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var samplesλ1: [Double] = []
		var samplesλ3: [Double] = []

		for i in 0..<sampleCount {
			samplesλ1.append(distributionGamma(r: r, λ: 1.0, seeds: seedArrays[i]))
			samplesλ3.append(distributionGamma(r: r, λ: 3.0, seeds: seedArrays[i]))
		}

		let meanλ1 = samplesλ1.reduce(0, +) / Double(samplesλ1.count)
		let meanλ3 = samplesλ3.reduce(0, +) / Double(samplesλ3.count)

		// λ=1 should have mean ≈ 3, λ=3 should have mean ≈ 1
		#expect(meanλ1 > meanλ3, "Higher rate should produce smaller mean")
		#expect(abs(meanλ1 - 3.0) < 0.2, "Mean should match r/λ")
		#expect(abs(meanλ3 - 1.0) < 0.2, "Mean should match r/λ")
	}

	@Test("Gamma distribution as sum of exponentials")
	func gammaSumOfExponentials() {
		// Gamma(r, λ) is the sum of r independent Exponential(λ) variables
		let r = 4
		let λ = 2.0
		let sampleCount = 1000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var gammaSamples: [Double] = []
		var sumExpSamples: [Double] = []

		for i in 0..<sampleCount {
			// Generate Gamma directly
			gammaSamples.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))

			// Generate as sum of exponentials using same seeds
			var sum: Double = 0
			for j in 0..<r {
				sum += distributionExponential(λ: λ, seed: seedArrays[i][j])
			}
			sumExpSamples.append(sum)
		}

		// These should be identical with same seeds
		for i in 0..<sampleCount {
			#expect(abs(gammaSamples[i] - sumExpSamples[i]) < 0.0001, "Gamma should equal sum of exponentials")
		}
	}

	@Test("Gamma distribution struct random() method")
	func gammaStructRandom() {
		let r = 3
		let λ = 2.0
		let dist = DistributionGamma(r: r, λ: λ)

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
		let expectedMean = Double(r) / λ
		#expect(abs(empiricalMean - expectedMean) < 0.2, "Mean should be close to r/λ")
	}

	@Test("Gamma distribution struct next() method")
	func gammaStructNext() {
		let r = 5
		let λ = 1.0
		let dist = DistributionGamma(r: r, λ: λ)

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
		let expectedMean = Double(r) / λ  // 5.0
		#expect(abs(empiricalMean - expectedMean) < 0.3, "Mean should be close to expected")
	}

	@Test("Gamma distribution right-skewed for small shape")
	func gammaRightSkewed() {
		// Gamma with small r is right-skewed
		let r = 2
		let λ = 1.0
		let sampleCount = 5000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// Right-skewed: mean > median
		#expect(mean > median, "Gamma with small shape should be right-skewed")
	}

	@Test("Gamma distribution approaches Normal for large shape")
	func gammaApproachesNormal() {
		// For large r, Gamma approaches Normal by CLT
		let r = 50
		let λ = 2.0
		let sampleCount = 5000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// Should be roughly symmetric (mean ≈ median)
		let ratio = mean / median
		#expect(ratio > 0.95 && ratio < 1.05, "Large shape should approach symmetry")
	}

	@Test("Gamma distribution mode for r > 1")
	func gammaMode() {
		// Mode = (r-1)/λ for r >= 1
		let r = 5
		let λ = 2.0
		let expectedMode = Double(r - 1) / λ  // 2.0
		let sampleCount = 10000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))
		}

		// Create histogram to find mode
		let sorted = samples.sorted()
		let bins = 50
		let minVal = sorted.first!
		let maxVal = sorted.last!
		let binWidth = (maxVal - minVal) / Double(bins)

		var binCounts: [Int] = Array(repeating: 0, count: bins)
		for sample in samples {
			let binIndex = min(Int((sample - minVal) / binWidth), bins - 1)
			binCounts[binIndex] += 1
		}

		// Find bin with most samples
		let maxCount = binCounts.max()!
		let modeIndex = binCounts.firstIndex(of: maxCount)!
		let empiricalMode = minVal + (Double(modeIndex) + 0.5) * binWidth

		// Mode should be close to (r-1)/λ
		#expect(abs(empiricalMode - expectedMode) < 0.5, "Mode should be close to (r-1)/λ")
	}

	@Test("Gamma distribution different parameter combinations")
	func gammaDifferentParameters() {
		let testCases: [(r: Int, λ: Double, expectedMean: Double)] = [
			(2, 1.0, 2.0),
			(3, 2.0, 1.5),
			(5, 5.0, 1.0),
			(10, 2.0, 5.0)
		]

		for testCase in testCases {
			let sampleCount = 5000
			let seedArrays = Self.seedsForGamma(count: sampleCount, shape: testCase.r)

			var samples: [Double] = []
			for i in 0..<sampleCount {
				samples.append(distributionGamma(r: testCase.r, λ: testCase.λ, seeds: seedArrays[i]))
			}

			let empiricalMean = samples.reduce(0, +) / Double(samples.count)
			let tolerance = 0.2
			#expect(
				abs(empiricalMean - testCase.expectedMean) < tolerance,
				"Mean should match r/λ for r=\(testCase.r), λ=\(testCase.λ)"
			)
		}
	}

	@Test("Gamma distribution seeding produces deterministic results")
	func gammaDeterministicSeeding() {
		let r = 3
		let λ = 2.0
		let seedArrays = Self.seedsForGamma(count: 100, shape: r)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))
			samples2.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("Gamma distribution struct stores parameters")
	func gammaStructParameters() {
		let r = 4
		let λ = 3.0
		let dist = DistributionGamma(r: r, λ: λ)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be non-negative
		#expect(samples.allSatisfy { $0 >= 0 })

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = Double(r) / λ
		#expect(abs(empiricalMean - expectedMean) < 0.2, "Distribution should maintain consistent properties")
	}

	@Test("Gamma distribution waiting time application")
	func gammaWaitingTime() {
		// Gamma(r, λ) models waiting time for r events in a Poisson process with rate λ
		// Example: Time until 5th customer arrival, with average rate of 2 customers per minute
		let r = 5  // waiting for 5th event
		let λ = 2.0  // 2 events per time unit
		let sampleCount = 5000
		let seedArrays = Self.seedsForGamma(count: sampleCount, shape: r)

		var waitingTimes: [Double] = []
		for i in 0..<sampleCount {
			waitingTimes.append(distributionGamma(r: r, λ: λ, seeds: seedArrays[i]))
		}

		let meanWaitingTime = waitingTimes.reduce(0, +) / Double(waitingTimes.count)
		let expectedMeanWaitingTime = Double(r) / λ  // 2.5 time units

		#expect(abs(meanWaitingTime - expectedMeanWaitingTime) < 0.2, "Mean waiting time should match r/λ")

		// All waiting times should be positive
		#expect(waitingTimes.allSatisfy { $0 > 0 })
	}
}
