//
//  ChiSquaredDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("Chi-Squared Distribution Tests")
struct ChiSquaredDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.ChiSquaredDistributionTests", category: #function)

	@Test("Chi-squared distribution function produces positive values")
	func chiSquaredFunctionBounds() {
		// Test with df = 5
		let df = 5

		// Generate 1000 samples and verify all are positive
		for _ in 0..<1000 {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df)
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

		var samples: [Double] = []
		for _ in 0..<5000 {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df)
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
		let distribution = DistributionChiSquared(degreesOfFreedom: 15)

		// Test that next() produces positive values
		var samples: [Double] = []
		for _ in 0..<2000 {
			let sample = distribution.next()
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

		var samples: [Double] = []
		for _ in 0..<5000 {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df)
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

		var samples: [Double] = []
		for _ in 0..<5000 {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df)
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

		var samples: [Double] = []
		for _ in 0..<5000 {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df)
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

		var samples: [Double] = []
		for _ in 0..<5000 {
			let sample: Double = distributionChiSquared(degreesOfFreedom: df)
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

		var samplesDF5: [Double] = []
		var samplesDF50: [Double] = []

		for _ in 0..<5000 {
			samplesDF5.append(distributionChiSquared(degreesOfFreedom: 5))
			samplesDF50.append(distributionChiSquared(degreesOfFreedom: 50))
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
			var samples: [Double] = []
			for _ in 0..<5000 {
				samples.append(distributionChiSquared(degreesOfFreedom: testCase.df))
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
		let distribution = DistributionChiSquared(degreesOfFreedom: df)

		// Generate samples and verify consistency
		var samples: [Double] = []
		for _ in 0..<1000 {
			samples.append(distribution.next())
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = Double(df)
		let tolerance = 0.5
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Distribution should maintain consistent properties")
	}
}
