//
//  NormalDistributionTests.swift
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

@Suite("Normal Distribution Tests")
struct NormalDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.NormalDistributionTests", category: #function)

	// Helper function to generate seed pairs for Normal distribution using SeededRNG
	// Normal uses Box-Muller transform with 2 seeds per sample
	static func seedsForNormal(count: Int) -> [(u1: Double, u2: Double)] {
		let rng = SeededRNG(seed: 11111)  // Unique seed for Normal
		var seedPairs: [(u1: Double, u2: Double)] = []

		for _ in 0..<count {
			var u1 = rng.next()
			var u2 = rng.next()

			// Ensure seeds are in valid range for Box-Muller
			u1 = max(0.0001, min(0.9999, u1))
			u2 = max(0.0001, min(0.9999, u2))

			seedPairs.append((u1, u2))
		}

		return seedPairs
	}

	@Test("Normal distribution function produces finite values")
	func normalFunctionFiniteValues() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 1000
		let seeds = Self.seedsForNormal(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			#expect(sample.isFinite, "Normal values must be finite")
			#expect(!sample.isNaN, "Normal values must not be NaN")
		}
	}

	@Test("Standard normal distribution N(0,1) statistical properties")
	func standardNormalStatistics() {
		// Test N(0, 1) - mean = 0, stdDev = 1
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 5000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)
		let empiricalStdDev = sqrt(variance)

		#expect(abs(empiricalMean - mean) < 0.05, "Mean should be close to 0")
		#expect(abs(empiricalStdDev - stdDev) < 0.05, "StdDev should be close to 1")
	}

	@Test("Normal distribution with mean=100, stdDev=15")
	func normalWithParameters() {
		let mean = 100.0
		let stdDev = 15.0
		let sampleCount = 5000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)
		let empiricalStdDev = sqrt(variance)

		#expect(abs(empiricalMean - mean) < 1.0, "Mean should be close to 100")
		#expect(abs(empiricalStdDev - stdDev) < 1.0, "StdDev should be close to 15")
	}

	@Test("Normal distribution symmetry around mean")
	func normalSymmetry() {
		let mean = 50.0
		let stdDev = 10.0
		let sampleCount = 5000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		// Count values above and below mean
		let aboveMean = samples.filter { $0 > mean }.count
		let belowMean = samples.filter { $0 < mean }.count

		// Should be roughly equal (within 10% tolerance)
		let ratio = Double(aboveMean) / Double(belowMean)
		#expect(ratio > 0.90 && ratio < 1.10, "Distribution should be symmetric around mean")
	}

	@Test("Normal distribution 68-95-99.7 rule (empirical rule)")
	func normalEmpiricalRule() {
		let mean = 100.0
		let stdDev = 15.0
		let sampleCount = 10000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		// Within 1 standard deviation: ~68%
		let within1Sigma = samples.filter { abs($0 - mean) <= stdDev }.count
		let percent1Sigma = Double(within1Sigma) / Double(samples.count)
		#expect(percent1Sigma > 0.65 && percent1Sigma < 0.71, "~68% should be within 1σ")

		// Within 2 standard deviations: ~95%
		let within2Sigma = samples.filter { abs($0 - mean) <= 2 * stdDev }.count
		let percent2Sigma = Double(within2Sigma) / Double(samples.count)
		#expect(percent2Sigma > 0.93 && percent2Sigma < 0.97, "~95% should be within 2σ")

		// Within 3 standard deviations: ~99.7%
		let within3Sigma = samples.filter { abs($0 - mean) <= 3 * stdDev }.count
		let percent3Sigma = Double(within3Sigma) / Double(samples.count)
		#expect(percent3Sigma > 0.995 && percent3Sigma < 1.0, "~99.7% should be within 3σ")
	}

	@Test("Normal distribution can produce negative values")
	func normalNegativeValues() {
		// With mean close to 0 and high stdDev, should see negatives
		let mean = 0.0
		let stdDev = 10.0
		let sampleCount = 5000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		let negativeCount = samples.filter { $0 < 0 }.count
		#expect(negativeCount > 0, "Normal distribution should produce some negative values")
		#expect(negativeCount > 2000, "About half should be negative for N(0, σ)")
	}

	@Test("Normal distribution with variance parameter")
	func normalWithVariance() {
		let mean = 50.0
		let variance = 100.0  // stdDev = 10
		let sampleCount = 5000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, variance: variance, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let empiricalVariance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)

		#expect(abs(empiricalMean - mean) < 0.5, "Mean should be close to 50")
		#expect(abs(empiricalVariance - variance) < 10.0, "Variance should be close to 100")
	}

	@Test("Normal distribution struct random() method - bounds check")
	func normalStructRandom() {
		let mean = 100.0
		let stdDev = 15.0
		let dist = DistributionNormal(mean, stdDev)

		// Test that random() produces finite values (unseeded is OK for bounds)
		for _ in 0..<100 {
			let sample = dist.random()
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}
	}

	@Test("Normal distribution struct statistical properties - seeded")
	func normalStructStatistics() {
		let mean = 100.0
		let stdDev = 15.0

		// Use seeded variant for deterministic statistical testing
		let sampleCount = 1000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - mean) < 2.0, "Mean should be reasonably close")
	}

	@Test("Normal distribution struct next() method")
	func normalStructNext() {
		let mean = 75.0
		let stdDev = 20.0
		let dist = DistributionNormal(mean, stdDev)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.next()
			samples.append(sample)
			#expect(sample.isFinite)
		}

		// Verify statistical properties
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)
		let empiricalStdDev = sqrt(variance)

		#expect(abs(empiricalMean - mean) < 2.0, "Mean should be close to expected")
		#expect(abs(empiricalStdDev - stdDev) < 2.0, "StdDev should be close to expected")
	}

	@Test("Normal distribution with different standard deviations")
	func normalDifferentStdDevs() {
		let mean = 100.0
		let sampleCount = 5000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samplesStdDev5: [Double] = []
		var samplesStdDev20: [Double] = []

		for i in 0..<sampleCount {
			samplesStdDev5.append(distributionNormal(mean: mean, stdDev: 5.0, seeds[i].u1, seeds[i].u2))
			samplesStdDev20.append(distributionNormal(mean: mean, stdDev: 20.0, seeds[i].u1, seeds[i].u2))
		}

		// Calculate spreads
		let range5 = samplesStdDev5.max()! - samplesStdDev5.min()!
		let range20 = samplesStdDev20.max()! - samplesStdDev20.min()!

		// Larger stdDev should have larger range
		#expect(range20 > range5, "Larger stdDev should produce wider spread")
		#expect(range20 > 2 * range5, "Range should scale with stdDev")
	}

	@Test("Normal distribution with extreme parameters")
	func normalExtremeParameters() {
		// Very small standard deviation
		let seeds1 = Self.seedsForNormal(count: 1000)
		var samplesSmallStdDev: [Double] = []
		for i in 0..<1000 {
			samplesSmallStdDev.append(distributionNormal(mean: 100.0, stdDev: 0.1, seeds1[i].u1, seeds1[i].u2))
		}

		let range = samplesSmallStdDev.max()! - samplesSmallStdDev.min()!
		#expect(range < 2.0, "Small stdDev should produce tightly clustered values")

		// Very large standard deviation
		let seeds2 = Self.seedsForNormal(count: 1000)
		var samplesLargeStdDev: [Double] = []
		for i in 0..<1000 {
			samplesLargeStdDev.append(distributionNormal(mean: 0.0, stdDev: 100.0, seeds2[i].u1, seeds2[i].u2))
		}

		let range2 = samplesLargeStdDev.max()! - samplesLargeStdDev.min()!
		#expect(range2 > 400.0, "Large stdDev should produce widely spread values")
	}

	@Test("Normal distribution struct stores parameters")
	func normalStructParameters() {
		let mean = 42.0
		let variance = 64.0  // stdDev = 8
		let dist = DistributionNormal(mean: mean, variance: variance)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be finite
		#expect(samples.allSatisfy { $0.isFinite })

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - mean) < 1.0, "Distribution should maintain consistent mean")
	}

	@Test("Normal distribution seeding produces deterministic results")
	func normalDeterministicSeeding() {
		let mean = 100.0
		let stdDev = 15.0
		let seeds = Self.seedsForNormal(count: 100)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
			samples2.append(distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("Normal distribution z-score properties")
	func normalZScoreProperties() {
		// Standard normal N(0,1)
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		// Count extreme values (|z| > 3)
		let extremeValues = samples.filter { abs($0) > 3.0 }.count
		let extremePercent = Double(extremeValues) / Double(samples.count)

		// Should be < 0.3% (0.003) outside ±3σ
		#expect(extremePercent < 0.01, "Very few values should be beyond ±3σ")
	}

	@Test("Normal distribution invalid parameters return NaN")
	func normalInvalidParameters() {
		// Test negative stdDev
		let negativeStdDevResult = distributionNormal(mean: 0.0, stdDev: -1.0, 0.5, 0.5)
		#expect(negativeStdDevResult.isNaN, "Negative stdDev should return NaN")

		// Test zero stdDev returns mean (degenerate distribution)
		let zeroStdDevResult = distributionNormal(mean: 5.0, stdDev: 0.0, 0.5, 0.5)
		#expect(zeroStdDevResult == 5.0, "Zero stdDev should return mean (degenerate)")

		// Test NaN stdDev
		let nanStdDevResult = distributionNormal(mean: 0.0, stdDev: Double.nan, 0.5, 0.5)
		#expect(nanStdDevResult.isNaN, "NaN stdDev should return NaN")

		// Test infinite stdDev
		let infStdDevResult = distributionNormal(mean: 0.0, stdDev: Double.infinity, 0.5, 0.5)
		#expect(infStdDevResult.isNaN, "Infinite stdDev should return NaN")
	}
}
