//
//  LogNormalDistributionTests.swift
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

@Suite("LogNormal Distribution Tests")
struct LogNormalDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.LogNormalDistributionTests", category: #function)

	// Helper function to generate seed pairs for LogNormal distribution using SeededRNG
	// LogNormal uses Normal (Box-Muller) with 2 seeds per sample
	static func seedsForLogNormal(count: Int) -> [(u1: Double, u2: Double)] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 33333)  // Unique seed for LogNormal
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

	@Test("LogNormal distribution function produces positive values")
	func logNormalFunctionPositive() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 1000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			#expect(sample > 0, "LogNormal values must be positive")
			#expect(sample.isFinite, "LogNormal values must be finite")
			#expect(!sample.isNaN, "LogNormal values must not be NaN")
		}
	}

	@Test("Standard LogNormal distribution (mean=0, stdDev=1)")
	func standardLogNormal() {
		// Standard LogNormal with underlying N(0,1)
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 5000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2)
			samples.append(sample)
		}

		// All values should be positive
		#expect(samples.allSatisfy { $0 > 0 })

		// LogNormal should be right-skewed: mean > median
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		#expect(empiricalMean > median, "LogNormal should be right-skewed (mean > median)")
	}

	@Test("LogNormal distribution with different parameters")
	func logNormalDifferentParameters() {
		let sampleCount = 5000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		// Test with mean=1, stdDev=0.5
		var samples1: [Double] = []
		for i in 0..<sampleCount {
			samples1.append(distributionLogNormal(mean: 1.0, stdDev: 0.5, seeds[i].u1, seeds[i].u2))
		}

		// Test with mean=2, stdDev=1.0
		var samples2: [Double] = []
		for i in 0..<sampleCount {
			samples2.append(distributionLogNormal(mean: 2.0, stdDev: 1.0, seeds[i].u1, seeds[i].u2))
		}

		// All should be positive
		#expect(samples1.allSatisfy { $0 > 0 })
		#expect(samples2.allSatisfy { $0 > 0 })

		// Higher parameters should generally produce larger values
		let mean1 = samples1.reduce(0, +) / Double(samples1.count)
		let mean2 = samples2.reduce(0, +) / Double(samples2.count)
		#expect(mean2 > mean1, "Higher underlying mean should produce larger LogNormal values")
	}

	@Test("LogNormal distribution median formula")
	func logNormalMedian() {
		// Median of LogNormal(μ, σ) = e^μ
		let underlyingMean = 2.0
		let underlyingStdDev = 0.5
		let expectedMedian = exp(underlyingMean)

		let sampleCount = 5000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogNormal(mean: underlyingMean, stdDev: underlyingStdDev, seeds[i].u1, seeds[i].u2))
		}

		let sorted = samples.sorted()
		let empiricalMedian = sorted[sorted.count / 2]

		let tolerance = expectedMedian * 0.05  // 5% tolerance
		#expect(abs(empiricalMedian - expectedMedian) < tolerance, "Median should match e^μ")
	}

	@Test("LogNormal distribution relationship to Normal")
	func logNormalRelationshipToNormal() {
		// If Y ~ N(μ, σ²), then X = e^Y ~ LogNormal
		// Taking log of LogNormal samples should give Normal
		let underlyingMean = 1.0
		let underlyingStdDev = 0.5
		let sampleCount = 5000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var logNormalSamples: [Double] = []
		for i in 0..<sampleCount {
			logNormalSamples.append(distributionLogNormal(mean: underlyingMean, stdDev: underlyingStdDev, seeds[i].u1, seeds[i].u2))
		}

		// Take log of samples
		let logSamples = logNormalSamples.map { log($0) }

		// These should be approximately Normal(μ, σ)
		let logMean = logSamples.reduce(0, +) / Double(logSamples.count)
		let logVariance = logSamples.map { pow($0 - logMean, 2) }.reduce(0, +) / Double(logSamples.count - 1)
		let logStdDev = sqrt(logVariance)

		#expect(abs(logMean - underlyingMean) < 0.05, "Log of LogNormal should have mean ≈ μ")
		#expect(abs(logStdDev - underlyingStdDev) < 0.05, "Log of LogNormal should have stdDev ≈ σ")
	}

	@Test("LogNormal distribution right-skewed property")
	func logNormalRightSkewed() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// For right-skewed: mean > median
		#expect(empiricalMean > median, "LogNormal is right-skewed")

		// Should also have some very large values (long right tail)
		let maxValue = samples.max()!
		let q99 = sorted[Int(Double(sorted.count) * 0.99)]
		#expect(maxValue > 2 * q99, "Should have extreme values in right tail")
	}

	@Test("LogNormal distribution with variance parameter")
	func logNormalWithVariance() {
		let mean = 1.0
		let variance = 0.25  // stdDev = 0.5
		let sampleCount = 5000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogNormal(mean: mean, variance: variance, seeds[i].u1, seeds[i].u2))
		}

		// All positive
		#expect(samples.allSatisfy { $0 > 0 })

		// Check median: e^μ
		let sorted = samples.sorted()
		let empiricalMedian = sorted[sorted.count / 2]
		let expectedMedian = exp(mean)
		let tolerance = expectedMedian * 0.05

		#expect(abs(empiricalMedian - expectedMedian) < tolerance, "Median should match e^μ")
	}

	@Test("LogNormal distribution struct random() method")
	func logNormalStructRandom() {
		let mean = 0.0
		let stdDev = 1.0
		let dist = DistributionLogNormal(mean, stdDev)

		let sampleCount = 1000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.random()
			samples.append(sample)
			#expect(sample > 0)
			#expect(sample.isFinite)
		}

		// Check right-skewed
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]
		#expect(empiricalMean > median, "Should be right-skewed")
	}

	@Test("LogNormal distribution struct next() method")
	func logNormalStructNext() {
		let mean = 1.0
		let stdDev = 0.5
		let dist = DistributionLogNormal(mean, stdDev)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.next()
			samples.append(sample)
			#expect(sample > 0)
			#expect(sample.isFinite)
		}

		// Verify all positive
		#expect(samples.allSatisfy { $0 > 0 })
	}

	@Test("LogNormal distribution increasing variance increases spread")
	func logNormalVarianceEffect() {
		let mean = 0.0
		let sampleCount = 5000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var samplesLowVar: [Double] = []
		var samplesHighVar: [Double] = []

		for i in 0..<sampleCount {
			samplesLowVar.append(distributionLogNormal(mean: mean, stdDev: 0.3, seeds[i].u1, seeds[i].u2))
			samplesHighVar.append(distributionLogNormal(mean: mean, stdDev: 1.5, seeds[i].u1, seeds[i].u2))
		}

		// Higher variance should produce wider range
		let rangeLow = samplesLowVar.max()! - samplesLowVar.min()!
		let rangeHigh = samplesHighVar.max()! - samplesHighVar.min()!

		#expect(rangeHigh > rangeLow, "Higher variance should produce wider spread")
	}

	@Test("LogNormal distribution used in finance (stock price model)")
	func logNormalFinancialModel() {
		// Model stock price: S_t = S_0 * e^((μ - σ²/2)t + σ√t*Z)
		// For simplicity, model returns as LogNormal
		let annualReturn = 0.08  // 8% expected return
		let annualVolatility = 0.20  // 20% volatility
		let sampleCount = 1000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		// Simulate 1-year returns
		var returns: [Double] = []
		for i in 0..<sampleCount {
			returns.append(distributionLogNormal(mean: annualReturn, stdDev: annualVolatility, seeds[i].u1, seeds[i].u2))
		}

		// All returns should be positive
		#expect(returns.allSatisfy { $0 > 0 })

		// Should have right-skewed distribution (long right tail of big gains)
		let meanReturn = returns.reduce(0, +) / Double(returns.count)
		let sorted = returns.sorted()
		let medianReturn = sorted[sorted.count / 2]
		#expect(meanReturn > medianReturn, "Stock returns should be right-skewed")
	}

	@Test("LogNormal distribution percentiles")
	func logNormalPercentiles() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		let sorted = samples.sorted()

		// 50th percentile (median) = e^μ = e^0 = 1
		let p50 = sorted[sorted.count / 2]
		#expect(abs(p50 - 1.0) < 0.1, "Median should be close to 1.0 for standard LogNormal")

		// 95th percentile should be significantly higher
		let p95Index = Int(Double(sorted.count) * 0.95)
		let p95 = sorted[p95Index]
		#expect(p95 > 3.0, "95th percentile should be substantially higher due to right skew")
	}

	@Test("LogNormal distribution extreme values")
	func logNormalExtremeValues() {
		// LogNormal can produce very large values
		let mean = 0.0
		let stdDev = 2.0  // High volatility
		let sampleCount = 10000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		// Should see some very large values
		let maxValue = samples.max()!
		let median = samples.sorted()[samples.count / 2]

		#expect(maxValue > 20 * median, "Should produce extreme values with high stdDev")
	}

	@Test("LogNormal distribution seeding produces deterministic results")
	func logNormalDeterministicSeeding() {
		let mean = 1.0
		let stdDev = 0.5
		let seeds = Self.seedsForLogNormal(count: 100)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
			samples2.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("LogNormal distribution struct stores parameters")
	func logNormalStructParameters() {
		let mean = 2.0
		let variance = 1.0  // stdDev = 1
		let dist = DistributionLogNormal(mean: mean, variance: variance)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be positive
		#expect(samples.allSatisfy { $0 > 0 })

		// Check median: e^μ = e^2 ≈ 7.39
		let sorted = samples.sorted()
		let empiricalMedian = sorted[sorted.count / 2]
		let expectedMedian = exp(mean)
		let tolerance = expectedMedian * 0.1

		#expect(abs(empiricalMedian - expectedMedian) < tolerance, "Distribution should maintain consistent properties")
	}

	@Test("LogNormal distribution comparison with Normal")
	func logNormalVsNormal() {
		// Generate both Normal and LogNormal samples
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 5000
		let seeds = Self.seedsForLogNormal(count: sampleCount)

		var normalSamples: [Double] = []
		var logNormalSamples: [Double] = []

		for i in 0..<sampleCount {
			normalSamples.append(distributionNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
			logNormalSamples.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		// Normal can have negative values, LogNormal cannot
		let normalNegatives = normalSamples.filter { $0 < 0 }.count
		let logNormalNegatives = logNormalSamples.filter { $0 < 0 }.count

		#expect(normalNegatives > 0, "Normal should have negative values")
		#expect(logNormalNegatives == 0, "LogNormal should never have negative values")

		// Normal is symmetric, LogNormal is right-skewed
		let normalSorted = normalSamples.sorted()
		let logNormalSorted = logNormalSamples.sorted()

		let normalMean = normalSamples.reduce(0, +) / Double(normalSamples.count)
		let normalMedian = normalSorted[normalSorted.count / 2]

		let logNormalMean = logNormalSamples.reduce(0, +) / Double(logNormalSamples.count)
		let logNormalMedian = logNormalSorted[logNormalSorted.count / 2]

		#expect(abs(normalMean - normalMedian) < 0.2, "Normal should be roughly symmetric")
		#expect(logNormalMean > logNormalMedian * 1.1, "LogNormal should be right-skewed")
	}
}
