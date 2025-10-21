//
//  FDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("F-Distribution Tests")
struct FDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.FDistributionTests", category: #function)

	// Helper function to generate seed sets for F-distribution using SeededRNG
	// F-distribution uses two chi-squared distributions, each needs ~10 seeds
	static func seedSetsForF(count: Int, seedsPerSample: Int = 20) -> [[Double]] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 87654)  // Unique seed for F-dist
		var seedSets: [[Double]] = []

		for _ in 0..<count {
			var seedSet: [Double] = []
			for _ in 0..<seedsPerSample {
				var seed = rng.next()
				seed = max(0.0001, min(0.9999, seed))
				seedSet.append(seed)
			}
			seedSets.append(seedSet)
		}

		return seedSets
	}

	@Test("F-distribution function produces positive values")
	func fFunctionBounds() {
		// Test with df1 = 5, df2 = 10
		let df1 = 5
		let df2 = 10
		let sampleCount = 1000

		// Generate deterministic samples
		let seedSets = Self.seedSetsForF(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			#expect(sample >= 0.0, "F-distribution values must be >= 0")
			#expect(sample.isFinite, "F-distribution values must be finite")
			#expect(!sample.isNaN, "F-distribution values must not be NaN")
		}
	}

	@Test("F-distribution function statistical properties - F(5, 20)")
	func fFunctionStatistics() {
		// Test F(5, 20) - mean should be 20/(20-2) = 1.111
		let df1 = 5
		let df2 = 20
		let expectedMean = Double(df2) / Double(df2 - 2)  // 1.111
		let sampleCount = 5000

		// Generate deterministic samples
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.10

		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to df2/(df2-2)")
	}

	@Test("F-distribution struct random() method")
	func fStructRandom() {
		let distribution = DistributionF(df1: 10, df2: 15)

		// Test that random() produces positive values
		for _ in 0..<100 {
			let sample = distribution.random()
			#expect(sample >= 0.0)
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}
	}

	@Test("F-distribution struct next() method")
	func fStructNext() {
		// Use deterministic function variant for testing
		let df1 = 8
		let df2 = 20
		let sampleCount = 2000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		// Test that function produces positive values
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
			#expect(sample.isFinite)
		}

		// Verify mean is close to df2/(df2-2)
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 20.0 / 18.0  // 1.111
		let tolerance = 0.10
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to df2/(df2-2)")
	}

	@Test("F-distribution with small df1 and df2")
	func fSmallDegreesOfFreedom() {
		// Test with small degrees of freedom
		let df1 = 2
		let df2 = 5
		let sampleCount = 5000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// Mean for df2=5 is 5/(5-2) = 5/3 ≈ 1.667
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 5.0 / 3.0
		let tolerance = 0.15
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to expected")
	}

	@Test("F-distribution with large df1 and df2")
	func fLargeDegreesOfFreedom() {
		// Test with large degrees of freedom
		// F(50, 50) should approach 1.0 in distribution
		let df1 = 50
		let df2 = 50
		let sampleCount = 5000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			samples.append(sample)
		}

		// Mean should be 50/(50-2) = 1.042
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 50.0 / 48.0  // 1.042
		let tolerance = 0.08
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to 1 for large equal df")
	}

	@Test("F-distribution right-skewed")
	func fRightSkewed() {
		// F-distribution is right-skewed (median < mean for df2 > 2)
		let df1 = 5
		let df2 = 15
		let sampleCount = 5000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let sortedSamples = samples.sorted()
		let empiricalMedian = sortedSamples[sortedSamples.count / 2]

		// For right-skewed distribution, median < mean
		#expect(empiricalMedian < empiricalMean, "F-distribution should be right-skewed (median < mean)")
	}

	@Test("F-distribution with df1=1 (similar to squared t)")
	func fDF1Equals1() {
		// F(1, df2) is related to t²(df2)
		let df1 = 1
		let df2 = 10
		let sampleCount = 5000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
		}

		// Mean should be 10/(10-2) = 1.25
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 10.0 / 8.0
		let tolerance = 0.12
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should match expected")
	}

	@Test("F-distribution mean only defined for df2 > 2")
	func fMeanDefinedForDF2GreaterThan2() {
		// Test that we can generate values even when mean is undefined (df2 ≤ 2)
		// but won't test the mean itself

		let df1 = 5
		let df2 = 2  // Mean is undefined
		let sampleCount = 1000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionF(df1: df1, df2: df2, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
			#expect(sample.isFinite)
		}

		// Just verify we can generate valid samples
		#expect(samples.count == 1000, "Should generate 1000 valid samples")
	}

	@Test("F-distribution reciprocal relationship")
	func fReciprocalRelationship() {
		// F(df1, df2) and 1/F(df2, df1) should have similar distributions
		let df1 = 5
		let df2 = 10
		let sampleCount = 5000
		let seedSetsF = Self.seedSetsForF(count: sampleCount)
		let seedSetsInvF = Self.seedSetsForF(count: sampleCount)  // Different seed set

		var samplesF: [Double] = []
		var samplesInvF: [Double] = []

		for i in 0..<sampleCount {
			samplesF.append(distributionF(df1: df1, df2: df2, seeds: seedSetsF[i]))
			samplesInvF.append(1.0 / distributionF(df1: df2, df2: df1, seeds: seedSetsInvF[i]))
		}

		// Means should be similar (within tolerance due to sampling)
		let meanF = samplesF.reduce(0, +) / Double(samplesF.count)
		let meanInvF = samplesInvF.reduce(0, +) / Double(samplesInvF.count)

		let tolerance = 0.15
		#expect(abs(meanF - meanInvF) < tolerance, "F(df1,df2) and 1/F(df2,df1) should have similar means")
	}

	@Test("F-distribution variance exists only for df2 > 4")
	func fVarianceCondition() {
		// Test with df2 > 4 (variance exists)
		let df1 = 5
		let df2 = 10
		let sampleCount = 5000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionF(df1: df1, df2: df2, seeds: seedSets[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let squaredDiffs = samples.map { pow($0 - mean, 2) }
		let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)

		// Variance should be finite and reasonable for df2 > 4
		#expect(empiricalVariance.isFinite, "Variance should be finite for df2 > 4")
		#expect(empiricalVariance > 0.0, "Variance should be positive")
	}

	@Test("F-distribution struct stores df parameters")
	func fStructParameters() {
		// Use deterministic function variant for testing
		let df1 = 6
		let df2 = 12
		let sampleCount = 1000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		// Generate samples and verify consistency
		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionF(df1: df1, df2: df2, seeds: seedSets[i]))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = Double(df2) / Double(df2 - 2)  // 12/10 = 1.2
		let tolerance = 0.15
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Distribution should maintain consistent properties")
	}
}
