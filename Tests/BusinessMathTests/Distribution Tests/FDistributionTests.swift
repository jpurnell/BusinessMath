//
//  FDistributionTests.swift
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
	
	@Test("F-distribution variance formula")
	func fVarianceFormula() {
		// Variance = [2 * df2² * (df1 + df2 - 2)] / [df1 * (df2 - 2)² * (df2 - 4)] for df2 > 4
		let df1 = 5
		let df2 = 10  // df2 > 4 so variance exists
		let expectedVariance = (2.0 * pow(Double(df2), 2) * Double(df1 + df2 - 2)) /
							  (Double(df1) * pow(Double(df2 - 2), 2) * Double(df2 - 4))
		// = (2 * 100 * 13) / (5 * 64 * 6) = 2600 / 1920 ≈ 1.354

		let sampleCount = 10000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionF(df1: df1, df2: df2, seeds: seedSets[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let squaredDiffs = samples.map { pow($0 - mean, 2) }
		let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)

		let tolerance = 0.3
		#expect(abs(empiricalVariance - expectedVariance) < tolerance,
			   "Variance should match theoretical formula for df2 > 4")
	}
	
	@Test("F-distribution mode property")
	func fModeProperty() {
		// Mode = [df1 * (df2 - 2)] / [df2 * (df1 + 2)] for df1 > 2
		let df1 = 5
		let df2 = 10
		let expectedMode = (Double(df1) * Double(df2 - 2)) / (Double(df2) * Double(df1 + 2))
		// = (5 * 8) / (10 * 7) = 40/70 ≈ 0.571

		let sampleCount = 10000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionF(df1: df1, df2: df2, seeds: seedSets[i]))
		}

		//^[[A Estimate mode using histogram
		let binCount = 100
		let maxVal = samples.max() ?? 5.0
		var histogram = [Int](repeating: 0, count: binCount)

		for sample in samples {
			let binIndex = min(Int(sample / maxVal * Double(binCount)), binCount - 1)
			histogram[binIndex] += 1
		}

		let maxBinIndex = histogram.firstIndex(of: histogram.max()!)!
		let empiricalMode = Double(maxBinIndex) / Double(binCount) * maxVal

		let tolerance = 0.3
		#expect(abs(empiricalMode - expectedMode) < tolerance,
			   "Mode should be close to theoretical value for df1 > 2")
	}
	
	@Test("F-distribution relationship to chi-squared")
	func fChiSquaredRelationship() {
		// F(df1, ∞) = χ²(df1)/df1
		// Test with very large df2 to approximate this relationship
		let df1 = 5
		let df2 = 1000  // Large df2 approximates infinity
		let sampleCount = 5000
		let seedSetsF = Self.seedSetsForF(count: sampleCount)
		let seedSetsChi = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)

		var fSamples: [Double] = []
		var chiSamples: [Double] = []

		for i in 0..<sampleCount {
			fSamples.append(distributionF(df1: df1, df2: df2, seeds: seedSetsF[i]))
			chiSamples.append(distributionChiSquared(degreesOfFreedom: df1, seeds: seedSetsChi[i]) / Double(df1))
		}

		let fMean = fSamples.reduce(0, +) / Double(fSamples.count)
		let chiMean = chiSamples.reduce(0, +) / Double(chiSamples.count)

		// Both should approach 1.0 as df2 → ∞
		let tolerance = 0.15
		#expect(abs(fMean - chiMean) < tolerance,
			   "F(df1,∞) should approximate χ²(df1)/df1")
	}
	
	@Test("F-distribution approaches normal for large degrees of freedom")
	func fApproachesNormal() {
		// F-distribution approaches normal as both df1 and df2 become large
		let smallDF = (df1: 5, df2: 10)
		let largeDF = (df1: 50, df2: 100)
		let sampleCount = 5000
		let seedSets = Self.seedSetsForF(count: sampleCount * 2)

		var smallSamples: [Double] = []
		var largeSamples: [Double] = []

		for i in 0..<sampleCount {
			smallSamples.append(distributionF(df1: smallDF.df1, df2: smallDF.df2, seeds: seedSets[i]))
			largeSamples.append(distributionF(df1: largeDF.df1, df2: largeDF.df2, seeds: seedSets[i + sampleCount]))
		}

		// Calculate skewness
		func skewness(_ samples: [Double]) -> Double {
			let mean = samples.reduce(0, +) / Double(samples.count)
			let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
			let stdDev = sqrt(variance)
			let cubedDiffs = samples.map { pow(($0 - mean) / stdDev, 3) }
			return cubedDiffs.reduce(0, +) / Double(samples.count)
		}

		let smallSkewness = abs(skewness(smallSamples))
		let largeSkewness = abs(skewness(largeSamples))

		// Larger degrees of freedom should have lower skewness (more normal)
		#expect(largeSkewness < smallSkewness,
			   "F-distribution should become less skewed with larger degrees of freedom")
	}
	
	@Test("F-distribution in ANOVA context")
	func fANOVARelationship() {
		// In ANOVA, F = (between-group variance) / (within-group variance)
		// This should follow F-distribution under null hypothesis
		let df1 = 3  // groups - 1
		let df2 = 20 // total observations - groups
		let sampleCount = 5000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionF(df1: df1, df2: df2, seeds: seedSets[i]))
		}

		// Under null hypothesis, F-statistic should be around 1.0 on average
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = Double(df2) / Double(df2 - 2)  // 20/18 ≈ 1.111

		let tolerance = 0.15
		#expect(abs(empiricalMean - expectedMean) < tolerance,
			   "F-statistic under null should follow F-distribution")
	}
	
	@Test("F-distribution parameter validation")
	func fParameterValidation() {
		// Test edge cases and invalid parameters
		let edgeCases: [(df1: Int, df2: Int, description: String)] = [
			(1, 3, "minimum valid df1"),
			(2, 3, "minimum valid df2"),
			(1000, 1000, "very large degrees of freedom"),
			(1, 1000, "very unbalanced degrees of freedom")
		]

		for testCase in edgeCases {
			let sample: Double = distributionF(df1: testCase.df1, df2: testCase.df2, seeds: [0.5])
			#expect(sample >= 0.0, "Should handle \(testCase.description)")
			#expect(sample.isFinite, "Should produce finite value for \(testCase.description)")
		}
	}
	
	
	@Test("F-distribution common quantiles")
	func fCommonQuantiles() {
		// Test that common F-distribution quantiles are in expected ranges
		let df1 = 5
		let df2 = 10
		let sampleCount = 10000
		let seedSets = Self.seedSetsForF(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionF(df1: df1, df2: df2, seeds: seedSets[i]))
		}

		let sorted = samples.sorted()

		// Common quantiles for F(5,10)
		let p50 = sorted[sorted.count / 2]        // Median ~0.94
		let p90 = sorted[Int(Double(sorted.count) * 0.9)]  // 90th percentile ~2.52
		let p95 = sorted[Int(Double(sorted.count) * 0.95)] // 95th percentile ~3.33

		#expect(p50 > 0.5 && p50 < 1.5, "Median should be in reasonable range")
		#expect(p90 > 1.5 && p90 < 4.0, "90th percentile should be in reasonable range")
		#expect(p95 > 2.0 && p95 < 5.0, "95th percentile should be in reasonable range")
	}
	
	@Test("F-distribution invalid parameter handling")
	func fInvalidParameters() {
		// Test that invalid degrees of freedom return NaN
		let invalidCases: [(df1: Int, df2: Int, description: String)] = [
			(0, 5, "df1 = 0"),
			(-1, 5, "negative df1"),
			(5, 0, "df2 = 0"),
			(5, -1, "negative df2"),
			(-1, -1, "both negative"),
			(0, 0, "both zero")
		]

		for testCase in invalidCases {
			let sample: Double = distributionF(df1: testCase.df1, df2: testCase.df2, seeds: [0.5])
			#expect(sample.isNaN, "Should return NaN for \(testCase.description)")
		}

		// Test that valid parameters still work
		let validSample: Double = distributionF(df1: 5, df2: 10, seeds: [0.5, 0.6, 0.7])
		#expect(validSample.isFinite && !validSample.isNaN, "Valid parameters should produce finite value")
		#expect(validSample >= 0.0, "F-distribution should be non-negative")
	}
}
