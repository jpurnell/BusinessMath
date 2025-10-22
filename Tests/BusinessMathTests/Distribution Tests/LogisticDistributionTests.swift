//
//  LogisticDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/25.
//

import Foundation
import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("Logistic Distribution Tests")
struct LogisticDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.LogisticDistributionTests", category: #function)

	// Helper function to generate seeds for Logistic distribution using SeededRNG
	// Logistic uses 1 seed per sample
	static func seedsForLogistic(count: Int) -> [Double] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 66666)  // Unique seed for Logistic
		var seeds: [Double] = []

		for _ in 0..<count {
			var seed = rng.next()
			seed = max(0.0001, min(0.9999, seed))
			seeds.append(seed)
		}

		return seeds
	}

	@Test("Logistic distribution function produces finite values")
	func logisticFunctionFiniteValues() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 1000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = distributionLogistic(mean, stdDev, seed: seeds[i])
			#expect(sample.isFinite, "Logistic values must be finite")
			#expect(!sample.isNaN, "Logistic values must not be NaN")
		}
	}

	@Test("Standard logistic distribution (mean=0, stdDev=1)")
	func standardLogisticStatistics() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 5000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionLogistic(mean, stdDev, seed: seeds[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)
		let empiricalStdDev = sqrt(variance)

		#expect(abs(empiricalMean - mean) < 0.1, "Mean should be close to 0")
		#expect(abs(empiricalStdDev - stdDev) < 0.1, "StdDev should be close to 1")
	}

	@Test("Logistic distribution symmetry around mean")
	func logisticSymmetry() {
		let mean = 50.0
		let stdDev = 10.0
		let sampleCount = 5000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionLogistic(mean, stdDev, seed: seeds[i])
			samples.append(sample)
		}

		// Count values above and below mean
		let aboveMean = samples.filter { $0 > mean }.count
		let belowMean = samples.filter { $0 < mean }.count

		// Should be roughly equal (within 10% tolerance)
		let ratio = Double(aboveMean) / Double(belowMean)
		#expect(ratio > 0.90 && ratio < 1.10, "Distribution should be symmetric around mean")
	}

	@Test("Logistic distribution heavier tails than Normal")
	func logisticHeavierTails() {
		// Logistic has heavier tails than Normal
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionLogistic(mean, stdDev, seed: seeds[i])
			samples.append(sample)
		}

		// Count extreme values (|x| > 3)
		let extremeValues = samples.filter { abs($0 - mean) > 3.0 * stdDev }.count
		let extremePercent = Double(extremeValues) / Double(samples.count)

		// Logistic should have more extreme values than Normal (which has < 0.3%)
		// For logistic, expect around 0.5-1% beyond ±3σ (heavier than normal's 0.3%)
		#expect(extremePercent > 0.003, "Logistic should have heavier tails than Normal")
	}

	@Test("Logistic distribution with different parameters")
	func logisticDifferentParameters() {
		let sampleCount = 5000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<sampleCount {
			samples1.append(distributionLogistic(0.0, 1.0, seed: seeds[i]))
			samples2.append(distributionLogistic(100.0, 15.0, seed: seeds[i]))
		}

		let mean1 = samples1.reduce(0, +) / Double(samples1.count)
		let mean2 = samples2.reduce(0, +) / Double(samples2.count)

		#expect(abs(mean1 - 0.0) < 0.2, "Mean should be close to 0")
		#expect(abs(mean2 - 100.0) < 2.0, "Mean should be close to 100")
	}

	@Test("Logistic distribution median equals mean")
	func logisticMedianEqualsMean() {
		let mean = 50.0
		let stdDev = 10.0
		let sampleCount = 5000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
		}

		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// For symmetric distribution, median ≈ mean
		#expect(abs(median - mean) < 1.0, "Median should equal mean for symmetric logistic")
	}

	@Test("Logistic distribution struct random() method")
	func logisticStructRandom() {
		let mean = 100.0
		let stdDev = 15.0
		let dist = DistributionLogistic(mean, stdDev)

		let sampleCount = 1000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.random()
			samples.append(sample)
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}

		// Check that we get reasonable distribution
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - mean) < 5.0, "Mean should be reasonably close")
	}

	@Test("Logistic distribution struct next() method")
	func logisticStructNext() {
		let mean = 75.0
		let stdDev = 20.0
		let dist = DistributionLogistic(mean, stdDev)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.next()
			samples.append(sample)
			#expect(sample.isFinite)
		}

		// Verify statistical properties
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - mean) < 3.0, "Mean should be close to expected")
	}

	@Test("Logistic distribution with variance parameter")
	func logisticWithVariance() {
		let mean = 50.0
		let variance = 100.0  // stdDev = 10
		let dist = DistributionLogistic(mean: mean, variance: variance)

		let sampleCount = 5000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - mean) < 1.5, "Mean should be close to 50")
	}

	@Test("Logistic distribution range is unbounded")
	func logisticUnbounded() {
		// Logistic can produce any real value (unlike some bounded distributions)
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
		}

		// Should see both positive and negative values
		let positiveCount = samples.filter { $0 > 0 }.count
		let negativeCount = samples.filter { $0 < 0 }.count

		#expect(positiveCount > 0, "Should produce positive values")
		#expect(negativeCount > 0, "Should produce negative values")

		// Should see some extreme values
		let maxAbs = samples.map { abs($0) }.max()!
		#expect(maxAbs > 5.0, "Should produce some extreme values")
	}

	@Test("Logistic distribution S-shaped CDF")
	func logisticSShapedCDF() {
		// The CDF of logistic is the logistic function: F(x) = 1/(1 + e^(-(x-μ)/s))
		// At mean, CDF should be 0.5
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
		}

		// Count values <= mean
		let countBelowMean = samples.filter { $0 <= mean }.count
		let empiricalCDFAtMean = Double(countBelowMean) / Double(samples.count)

		// Should be close to 0.5
		#expect(abs(empiricalCDFAtMean - 0.5) < 0.02, "CDF at mean should be 0.5")
	}

	@Test("Logistic distribution growth model use case")
	func logisticGrowthModel() {
		// Logistic is used in growth models and S-curves
		// Example: adoption rate over time with early and late adopters
		let mean = 50.0  // midpoint of adoption
		let stdDev = 10.0  // spread of adoption
		let sampleCount = 5000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var adoptionTimes: [Double] = []
		for i in 0..<sampleCount {
			adoptionTimes.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
		}

		// Most adoption should happen around the mean
		let nearMean = adoptionTimes.filter { abs($0 - mean) < stdDev }.count
		let percentage = Double(nearMean) / Double(adoptionTimes.count)

		#expect(percentage > 0.50, "Most adoption should occur near mean")

		// Should have some early and late adopters
		let earlyAdopters = adoptionTimes.filter { $0 < mean - 2 * stdDev }.count
		let lateAdopters = adoptionTimes.filter { $0 > mean + 2 * stdDev }.count

		#expect(earlyAdopters > 0, "Should have early adopters")
		#expect(lateAdopters > 0, "Should have late adopters")
	}

	@Test("Logistic distribution comparison with Normal")
	func logisticVsNormal() {
		// Both are symmetric, but Logistic has heavier tails
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var logisticSamples: [Double] = []
		for i in 0..<sampleCount {
			logisticSamples.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
		}

		// Logistic should have more extreme values than Normal
		let extremeLogistic = logisticSamples.filter { abs($0) > 4.0 }.count
		let percentLogistic = Double(extremeLogistic) / Double(logisticSamples.count)

		// Normal would have < 0.01% beyond ±4σ, Logistic should have more (around 0.1%)
		#expect(percentLogistic > 0.0005, "Logistic should have more extreme values than Normal")
	}

	@Test("Logistic distribution seeding produces deterministic results")
	func logisticDeterministicSeeding() {
		let mean = 100.0
		let stdDev = 15.0
		let seeds = Self.seedsForLogistic(count: 100)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
			samples2.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("Logistic distribution struct stores parameters")
	func logisticStructParameters() {
		let mean = 42.0
		let variance = 64.0  // stdDev = 8
		let dist = DistributionLogistic(mean: mean, variance: variance)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be finite
		#expect(samples.allSatisfy { $0.isFinite })

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - mean) < 1.5, "Distribution should maintain consistent mean")
	}

	@Test("Logistic distribution percentiles")
	func logisticPercentiles() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForLogistic(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogistic(mean, stdDev, seed: seeds[i]))
		}

		let sorted = samples.sorted()

		// 50th percentile (median) should equal mean for symmetric distribution
		let p50 = sorted[sorted.count / 2]
		#expect(abs(p50 - mean) < 0.1, "50th percentile should equal mean")

		// 25th and 75th percentiles should be symmetric around mean
		let p25Index = Int(Double(sorted.count) * 0.25)
		let p75Index = Int(Double(sorted.count) * 0.75)
		let p25 = sorted[p25Index]
		let p75 = sorted[p75Index]

		let dist25 = abs(p25 - mean)
		let dist75 = abs(p75 - mean)

		#expect(abs(dist25 - dist75) < 0.5, "Percentiles should be symmetric around mean")
	}
}
