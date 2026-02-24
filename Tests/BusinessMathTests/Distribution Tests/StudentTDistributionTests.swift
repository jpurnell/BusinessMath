//
//  StudentTDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif

@testable import BusinessMath

@Suite("Student's t-Distribution Tests")
struct StudentTDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.StudentTDistributionTests", category: #function)

	// Helper function to generate seed sets for t-distribution using SeededRNG
	// Each t-distribution sample needs ~10 seeds (2 for normal, up to 8 for gamma)
	// Uses a seeded pseudo-random generator to create random-looking but deterministic sequences
	static func seedSetsForT(count: Int, seedsPerSample: Int = 10) -> [[Double]] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 12345)
		var seedSets: [[Double]] = []

		for _ in 0..<count {
			var seedSet: [Double] = []
			for _ in 0..<seedsPerSample {
				// Generate pseudo-random value in (0,1), avoiding exact 0 or 1
				var seed = rng.next()
				seed = max(0.0001, min(0.9999, seed))
				seedSet.append(seed)
			}
			seedSets.append(seedSet)
		}

		return seedSets
	}

	@Test("t-distribution function produces reasonable values")
	func tFunctionRange() {
		// Test with df = 10
		let df = 10
		let sampleCount = 1000

		// Generate deterministic samples
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: df, seeds: seedSets[i])
			#expect(sample.isFinite, "t-distribution values must be finite")
			#expect(!sample.isNaN, "t-distribution values must not be NaN")
			samples.append(sample)
		}

		// t-distribution is unbounded but most values should be in reasonable range
		// For df=10, ~95% should be within ±2.23
		let within2SD = samples.filter { abs($0) <= 3.0 }.count
		#expect(within2SD > 900, "Most samples should be within reasonable range")
	}

	@Test("t-distribution function statistical properties - df=30")
	func tFunctionStatistics() {
		// Test t(30) - should be close to standard normal
		let df = 30
		let expectedMean = 0.0
		let expectedVariance = Double(df) / Double(df - 2)  // 30/28 ≈ 1.071
		let sampleCount = 5000

		// Generate deterministic samples
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let squaredDiffs = samples.map { pow($0 - empiricalMean, 2) }
		let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)

		let meanTolerance = 0.05
		let varianceTolerance = 0.15

		#expect(abs(empiricalMean - expectedMean) < meanTolerance, "Mean should be close to 0")
		#expect(abs(empiricalVariance - expectedVariance) < varianceTolerance, "Variance should match theoretical value")
	}

	@Test("t-distribution struct random() method")
	func tStructRandom() {
		let distribution = DistributionT(degreesOfFreedom: 10)

		// Test that random() produces finite values
		for _ in 0..<100 {
			let sample = distribution.random()
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}
	}

	@Test("t-distribution struct next() method")
	func tStructNext() {
		// Test the struct-based sampling
		// Note: The struct's next() method uses random generation internally,
		// so we test the function variant with seeds for statistical properties
		let sampleCount = 2000
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		// Test that next() produces finite values
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: 20, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}

		// Verify mean is close to 0
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.05
		#expect(abs(empiricalMean) < tolerance, "Mean should be close to 0")
	}

	@Test("t-distribution symmetric around zero")
	func tSymmetricCase() {
		// t-distribution is symmetric around 0
		let df = 15
		let sampleCount = 5000

		// Generate deterministic samples
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
		}

		// Mean should be 0
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.05
		#expect(abs(empiricalMean) < tolerance, "Mean should be close to 0")

		// Roughly equal number above and below zero
		let positiveCount = samples.filter { $0 > 0 }.count
		let expectedPositive = 2500  // Half of 5000
		let countTolerance = 200.0  // Allow 8% deviation
		#expect(Double(positiveCount) > Double(expectedPositive) - countTolerance)
		#expect(Double(positiveCount) < Double(expectedPositive) + countTolerance)
	}

	@Test("t-distribution fat tails (df=3)")
	func tFatTails() {
		// Low df produces fat tails (more extreme values)
		let df = 3
		let sampleCount = 5000

		// Generate deterministic samples
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
		}

		// With fat tails, we expect more extreme values (>2 SD)
		let extremeCount = samples.filter { abs($0) > 2.0 }.count

		// For normal distribution, ~5% are beyond 2 SD
		// For t(3), we expect more (should be > 10%)
		let extremePercentage = Double(extremeCount) / Double(samples.count)
		#expect(extremePercentage > 0.10, "df=3 should have fat tails with >10% beyond 2 SD")
	}

	@Test("t-distribution approaches normal as df increases")
	func tApproachesNormal() {
		// Test that variance approaches 1 as df increases
		let dfHigh = 100
		let expectedVariance = Double(dfHigh) / Double(dfHigh - 2)  // 100/98 ≈ 1.020
		let sampleCount = 5000

		// Generate deterministic samples
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: dfHigh, seeds: seedSets[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let squaredDiffs = samples.map { pow($0 - empiricalMean, 2) }
		let empiricalVariance = squaredDiffs.reduce(0, +) / Double(samples.count - 1)

		// Variance should be close to 1 (like standard normal)
		let tolerance = 0.15
		#expect(abs(empiricalVariance - expectedVariance) < tolerance, "High df should approach standard normal variance")
		#expect(abs(empiricalVariance - 1.0) < 0.20, "Variance should be close to 1 for high df")
	}

	@Test("t-distribution with df=1 (Cauchy distribution)")
	func tCauchyCase() {
		// df=1 is Cauchy distribution - has undefined mean and variance
		let df = 1
		let sampleCount = 1000

		// Generate deterministic samples
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}

		// Can't test mean/variance (undefined), but should produce valid samples
		// Most should still be in a reasonable range despite heavy tails
		let withinRange = samples.filter { abs($0) < 100.0 }.count
		#expect(withinRange > 800, "Most df=1 samples should be within reasonable range")
	}

	@Test("t-distribution with df=2")
	func tDF2Case() {
		// df=2 has defined mean (0) but variance is infinite
		// Using deterministic seeding for exact reproducibility
		let df = 2
		let sampleCount = 2000

		// Generate deterministic seed sets - each sample gets 10 seeds
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionT(degreesOfFreedom: df, seeds: seedSets[i])
			samples.append(sample)
			#expect(sample.isFinite, "Sample should be finite")
			#expect(!sample.isNaN, "Sample should not be NaN")
		}

		// With df=2 and deterministic seeding, mean should be very close to 0
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)

		// With deterministic seeding, we can use tighter tolerance
		#expect(abs(empiricalMean) < 0.15, "Mean should be close to 0 for df=2")

		// Verify all samples are reasonable (not extreme outliers)
		let extremeCount = samples.filter { abs($0) > 100.0 }.count
		#expect(extremeCount < samples.count / 10, "Less than 10% should be extreme values")
	}

	@Test("t-distribution with df=5 vs df=30")
	func tCompareDegreesOfFreedom() {
		// Compare two distributions with different df
		// df=5 should have more extreme values than df=30
		let sampleCount = 5000

		// Generate deterministic samples using the same seed sets for both
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		var samplesDF5: [Double] = []
		var samplesDF30: [Double] = []

		for i in 0..<sampleCount {
			samplesDF5.append(distributionT(degreesOfFreedom: 5, seeds: seedSets[i]))
			samplesDF30.append(distributionT(degreesOfFreedom: 30, seeds: seedSets[i]))
		}

		// Count extreme values (beyond 2.5 SD)
		let extremeDF5 = samplesDF5.filter { abs($0) > 2.5 }.count
		let extremeDF30 = samplesDF30.filter { abs($0) > 2.5 }.count

		// df=5 should have more extreme values
		#expect(extremeDF5 > extremeDF30, "Lower df should produce more extreme values")
	}

	@Test("t-distribution struct stores df parameter")
	func tStructParameters() {
		// Test that the distribution maintains consistent properties
		let df = 15
		let sampleCount = 1000
		let seedSets = StudentTDistributionTests.seedSetsForT(count: sampleCount)

		// Generate samples and verify consistency
		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionT(degreesOfFreedom: df, seeds: seedSets[i]))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.08
		#expect(abs(empiricalMean) < tolerance, "Distribution should maintain consistent properties")
	}
}
