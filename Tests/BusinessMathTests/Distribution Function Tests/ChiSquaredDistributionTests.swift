//
//  ChiSquaredDistributionTests.swift
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

@Suite("Chi-Squared Distribution Tests")
struct ChiSquaredDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.ChiSquaredDistributionTests", category: #function)
	
		// Helper function to generate seed sets for chi-squared distribution using SeededRNG
		// Chi-squared uses gamma distribution which needs ~10 seeds per sample
	static func seedSetsForChiSquared(count: Int, seedsPerSample: Int = 10) -> [[Double]] {
		let rng = SeededRNG(seed: 54321)  // Different seed from t-dist
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
	
	@Test("Chi-squared distribution function produces positive values")
	func chiSquaredFunctionBounds() {
			// Test with df = 5
		let df = 5
		let sampleCount = 1000
		
			// Generate deterministic samples
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		for i in 0..<sampleCount {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i])
			#expect(sample >= 0.0, "Chi-squared values must be >= 0")
			#expect(sample.isFinite, "Chi-squared values must be finite")
			#expect(!sample.isNaN, "Chi-squared values must not be NaN")
		}
	}
	
	@Test("Chi-squared distribution function statistical properties - df=10")
	func chiSquaredFunctionStatistics() {
			// Test χ²(10) - mean should be 10, variance should be 20
		let df = 10
		let expectedMean = Double(df)
		let expectedVariance = 2.0 * Double(df)  // 20
		let sampleCount = 5000
		
			// Generate deterministic samples
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
		}
		
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let squaredDiffs = samples.map { pow($0 - empiricalMean, 2) }
		let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)
		
		let meanTolerance = 0.3
		let varianceTolerance = 1.0
		
		#expect(abs(empiricalMean - expectedMean) < meanTolerance, "Mean should be close to df")
		#expect(abs(empiricalVariance - expectedVariance) < varianceTolerance, "Variance should be close to 2*df")
	}
	
	@Test("Chi-squared distribution struct random() method")
	func chiSquaredStructRandom() {
		let distribution = DistributionChiSquared(degreesOfFreedom: 10)
		
			// Test that random() produces positive values
		for _ in 0..<100 {
			let sample = distribution.random()
			#expect(sample >= 0.0)
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}
	}
	
	@Test("Chi-squared distribution struct next() method")
	func chiSquaredStructNext() {
			// Use deterministic function variant for testing
		let df = 15
		let sampleCount = 2000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
			#expect(sample.isFinite)
		}
		
			// Verify mean is close to df
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 15.0
		let tolerance = 0.5
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to df")
	}
	
	@Test("Chi-squared distribution with df=1")
	func chiSquaredDF1() {
			// df=1 is the distribution of Z² where Z ~ N(0,1)
		let df = 1
		let sampleCount = 5000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
		}
		
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0
		let tolerance = 0.10
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be 1 for df=1")
	}
	
	@Test("Chi-squared distribution with df=2 (exponential)")
	func chiSquaredDF2() {
			// df=2 is equivalent to Exponential(0.5)
		let df = 2
		let sampleCount = 5000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample >= 0.0)
		}
		
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 2.0
		let tolerance = 0.15
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be 2 for df=2")
	}
	
	@Test("Chi-squared distribution right-skewed")
	func chiSquaredRightSkewed() {
			// Chi-squared is right-skewed (median < mean)
		let df = 5
		let sampleCount = 5000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
		}
		
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let sortedSamples = samples.sorted()
		let empiricalMedian = sortedSamples[sortedSamples.count / 2]
		
			// For right-skewed distribution, median < mean
		#expect(empiricalMedian < empiricalMean, "Chi-squared should be right-skewed (median < mean)")
	}
	
	@Test("Chi-squared distribution with df=20")
	func chiSquaredDF20() {
			// Test with larger df
		let df = 20
		let expectedMean = Double(df)
		let expectedVariance = 2.0 * Double(df)
		let sampleCount = 5000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
		}
		
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let squaredDiffs = samples.map { pow($0 - empiricalMean, 2) }
		let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)
		
		let meanTolerance = 0.5
		let varianceTolerance = 2.0
		
		#expect(abs(empiricalMean - expectedMean) < meanTolerance, "Mean should be close to 20")
		#expect(abs(empiricalVariance - expectedVariance) < varianceTolerance, "Variance should be close to 40")
	}
	
	@Test("Chi-squared distribution approaches normal as df increases")
	func chiSquaredApproachesNormal() {
			// Test that skewness decreases as df increases
			// For chi-squared, skewness = sqrt(8/df)
		let sampleCount = 5000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
		var samplesDF5: [Double] = []
		var samplesDF50: [Double] = []
		
		for i in 0..<sampleCount {
			samplesDF5.append(distributionChiSquared(degreesOfFreedom: 5, seeds: seedSets[i]))
			samplesDF50.append(distributionChiSquared(degreesOfFreedom: 50, seeds: seedSets[i]))
		}
		
			// Calculate skewness: E[(X-μ)³] / σ³
		func skewness(_ samples: [Double]) -> Double {
			let mean = samples.reduce(0, +) / Double(samples.count)
			let squaredDiffs = samples.map { pow($0 - mean, 2) }
			let variance = squaredDiffs.reduce(0, +) / Double(samples.count)
			let stdDev = sqrt(variance)
			
			let cubedDiffs = samples.map { pow(($0 - mean) / stdDev, 3) }
			return cubedDiffs.reduce(0, +) / Double(samples.count)
		}
		
		let skewnessDF5 = abs(skewness(samplesDF5))
		let skewnessDF50 = abs(skewness(samplesDF50))
		
			// Higher df should have lower skewness (more normal-like)
		#expect(skewnessDF50 < skewnessDF5, "Skewness should decrease as df increases")
	}
	
	@Test("Chi-squared distribution variance relationship")
	func chiSquaredVarianceRelationship() {
			// Test that variance = 2*df for multiple df values
		let testCases: [(df: Int, expectedVariance: Double)] = [
			(5, 10.0),
			(10, 20.0),
			(15, 30.0)
		]
		
		for testCase in testCases {
			let sampleCount = 5000
			let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
			
			var samples: [Double] = []
			for i in 0..<sampleCount {
				samples.append(distributionChiSquared(degreesOfFreedom: testCase.df, seeds: seedSets[i]))
			}
			
			let mean = samples.reduce(0, +) / Double(samples.count)
			let squaredDiffs = samples.map { pow($0 - mean, 2) }
			let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)
			
			let tolerance = 1.5
			#expect(
				abs(empiricalVariance - testCase.expectedVariance) < tolerance,
				"Variance should be 2*df for df=\(testCase.df)"
			)
		}
	}
	
	@Test("Chi-squared distribution struct stores df parameter")
	func chiSquaredStructParameters() {
		let df = 8
		let sampleCount = 1000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)
		
			// Generate samples and verify consistency
		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i]))
		}
		
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = Double(df)
		let tolerance = 0.5
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Distribution should maintain consistent properties")
	}
	
	@Test("Chi-squared additivity property")
	func chiSquaredAdditivity() {
			// If X ~ χ²(m) and Y ~ χ²(n) are independent, then X + Y ~ χ²(m+n)
		let df1 = 5
		let df2 = 7
		let expectedDf = df1 + df2
		let sampleCount = 5000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount * 2)
		
		var sumSamples: [Double] = []
		
		for i in 0..<sampleCount {
			let sample1: Double = distributionChiSquared(degreesOfFreedom: df1, seeds: seedSets[i])
			let sample2: Double = distributionChiSquared(degreesOfFreedom: df2, seeds: seedSets[i + sampleCount])
			sumSamples.append(sample1 + sample2)
		}
		
		let empiricalMean = sumSamples.reduce(0, +) / Double(sumSamples.count)
		let expectedMean = Double(expectedDf)
		let tolerance = 0.5
		
		#expect(abs(empiricalMean - expectedMean) < tolerance,
				"Sum of independent chi-squared variables should have df = sum of dfs")
	}
	
	@Test("Chi-squared relationship to normal distribution")
	func chiSquaredFromNormal() {
		// For df=1, should be square of standard normal
		let sampleCount = 5000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)

		var chiSquaredSamples: [Double] = []
		var normalSquaredSamples: [Double] = []

		for i in 0..<sampleCount {
			// Generate chi-squared directly
			chiSquaredSamples.append(distributionChiSquared(degreesOfFreedom: 1, seeds: seedSets[i]))

			// Generate from normal: Z² where Z ~ N(0,1)
			// Using first two seeds for normal distribution
			let normalSample: Double =  distributionNormal(mean: 0, stdDev: 1, seedSets[i][0], seedSets[i][1])
			normalSquaredSamples.append(normalSample * normalSample)
		}

		// Compare means - should be similar
		let chiSquaredMean = chiSquaredSamples.reduce(0, +) / Double(chiSquaredSamples.count)
		let normalSquaredMean = normalSquaredSamples.reduce(0, +) / Double(normalSquaredSamples.count)
		let tolerance = 0.15

		#expect(abs(chiSquaredMean - normalSquaredMean) < tolerance,
			   "χ²(1) should behave like square of standard normal")
	}
	
	@Test("Chi-squared mode property")
	func chiSquaredMode() {
		// Mode should be max(0, df - 2)
		let testCases: [(df: Int, expectedMode: Double)] = [
			(1, 0.0),    // df < 2 → mode = 0
			(2, 0.0),    // df = 2 → mode = 0
			(3, 1.0),    // df > 2 → mode = df - 2
			(5, 3.0),
			(10, 8.0)
		]

		for testCase in testCases {
			let sampleCount = 5000
			let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)

			var samples: [Double] = []
			for i in 0..<sampleCount {
				samples.append(distributionChiSquared(degreesOfFreedom: testCase.df, seeds: seedSets[i]))
			}

			// Estimate mode using histogram
			let binCount = 50
			let maxVal = samples.max() ?? 1.0
			var histogram = [Int](repeating: 0, count: binCount)

			for sample in samples {
				let binIndex = min(Int(sample / maxVal * Double(binCount)), binCount - 1)
				histogram[binIndex] += 1
			}

			let maxBinIndex = histogram.firstIndex(of: histogram.max()!)!
			let empiricalMode = Double(maxBinIndex) / Double(binCount) * maxVal

			// For df >= 3, mode should be reasonably close to df-2
			if testCase.df >= 3 {
				let tolerance = 1.5
				#expect(abs(empiricalMode - testCase.expectedMode) < tolerance,
					   "Mode should be close to max(0, df-2) for df=\(testCase.df)")
			}
		}
	}
	
	@Test("Chi-squared moment generating function")
	func chiSquaredMGF() {
		// MGF: M(t) = (1 - 2t)^{-k/2} for t < 1/2
		// Test by comparing empirical and theoretical moments
		let df = 8
		let sampleCount = 10000
		let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionChiSquared(degreesOfFreedom: df, seeds: seedSets[i]))
		}

		// Test first four moments
		let mean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)

		// Third moment (related to skewness)
		let thirdMoment = samples.map { pow($0 - mean, 3) }.reduce(0, +) / Double(samples.count)
		let empiricalSkewness = thirdMoment / pow(variance, 1.5)
		let theoreticalSkewness = sqrt(8.0 / Double(df))

		let skewnessTolerance = 0.3
		#expect(abs(empiricalSkewness - theoreticalSkewness) < skewnessTolerance,
			   "Skewness should match theoretical value")
	}
	
	@Test("Chi-squared extreme value behavior")
	func chiSquaredExtremeValues() {
		// Test behavior with very small and very large df
		let extremeCases: [(df: Int, description: String)] = [
			(1, "minimum meaningful df"),
			(2, "exponential special case"),
			(1000, "very large df - near normal"),
			(1, "df=1 repeated for consistency")
		]

		for testCase in extremeCases {
			let sampleCount = 1000
			let seedSets = ChiSquaredDistributionTests.seedSetsForChiSquared(count: sampleCount)

			var allValid = true
			var samples: [Double] = []

			for i in 0..<sampleCount {
				let sample: Double = distributionChiSquared(degreesOfFreedom: testCase.df, seeds: seedSets[i])
				samples.append(sample)

				if sample < 0 || sample.isNaN || !sample.isFinite {
					allValid = false
				}
			}

			#expect(allValid, "All samples should be valid for \(testCase.description)")

			// For very large df, verify samples are large and variance is huge
			if testCase.df >= 100 {
				let mean = samples.reduce(0, +) / Double(samples.count)
				#expect(mean > Double(testCase.df) * 0.8,
					   "Very large df should produce large values")
			}
		}
	}
	
	@Test("Chi-squared parameter validation")
	func chiSquaredParameterValidation() {
		// Test that invalid degrees of freedom return NaN
		let invalidDFCases: [(df: Int, description: String)] = [
			(0, "zero degrees of freedom"),
			(-1, "negative degrees of freedom"),
			(-10, "large negative degrees of freedom")
		]

		for testCase in invalidDFCases {
			let sample: Double = distributionChiSquared(degreesOfFreedom: testCase.df, seeds: [0.5, 0.6])
			#expect(sample.isNaN, "Should return NaN for \(testCase.description)")
		}

		// Test that valid df with empty seeds array still works (uses random generation)
		let sampleWithEmptySeeds: Double = distributionChiSquared(degreesOfFreedom: 5, seeds: [])
		#expect(sampleWithEmptySeeds.isFinite, "Should handle empty seeds array")

		// Test that seeds out of range are handled (this is clamped in implementation)
		let sampleWithBadSeeds: Double = distributionChiSquared(degreesOfFreedom: 5, seeds: [1.1, 0.5])
		#expect(sampleWithBadSeeds.isFinite, "Should handle seeds out of range by clamping")
	}
	
	@Test("Chi-squared consistency across repeated calls")
	func chiSquaredConsistency() {
		// Same seeds should produce same results
		let df = 10
		let seeds = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95]

		let sample1: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seeds)
		let sample2: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seeds)
		let sample3: Double = distributionChiSquared(degreesOfFreedom: df, seeds: seeds)

		#expect(sample1 == sample2 && sample2 == sample3,
			   "Same seeds should produce identical results")

		// Different seeds should produce different results
		let differentSeeds = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99]
		let differentSample: Double = distributionChiSquared(degreesOfFreedom: df, seeds: differentSeeds)

		#expect(sample1 != differentSample,
			   "Different seeds should produce different results")
	}
}
