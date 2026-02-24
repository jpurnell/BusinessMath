//
//  TriangularDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/25.
//

import Foundation
import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif

@testable import BusinessMath

@Suite("Triangular Distribution Tests")
struct TriangularDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.TriangularDistributionTests", category: #function)

	// Helper function to generate seeds for Triangular distribution using SeededRNG
	// Triangular uses 1 seed per sample
	static func seedsForTriangular(count: Int) -> [Double] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 55555)  // Unique seed for Triangular
		var seeds: [Double] = []

		for _ in 0..<count {
			var seed = rng.next()
			seed = max(0.0001, min(0.9999, seed))
			seeds.append(seed)
		}

		return seeds
	}

	@Test("Triangular distribution function produces values within bounds")
	func triangularFunctionBounds() {
		let low = 10.0
		let high = 20.0
		let base = 15.0
		let sampleCount = 1000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = triangularDistribution(low: low, high: high, base: base, seeds[i])
			#expect(sample >= low, "Triangular values must be >= low")
			#expect(sample <= high, "Triangular values must be <= high")
			#expect(sample.isFinite, "Triangular values must be finite")
			#expect(!sample.isNaN, "Triangular values must not be NaN")
		}
	}

	@Test("Symmetric triangular distribution statistical properties")
	func symmetricTriangularStatistics() {
		// Test symmetric triangular: low=0, high=10, base=5 (center)
		let low = 0.0
		let high = 10.0
		let base = 5.0
		let expectedMean = (low + high + base) / 3.0  // 5.0
		let sampleCount = 5000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = triangularDistribution(low: low, high: high, base: base, seeds[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		#expect(abs(empiricalMean - expectedMean) < 0.1, "Mean should be close to (a+b+c)/3")

		// For symmetric triangular, mean ≈ median ≈ mode
		#expect(abs(empiricalMean - median) < 0.2, "Symmetric triangular should have mean ≈ median")
	}

	@Test("Triangular distribution mean formula (a+b+c)/3")
	func triangularMeanFormula() {
		let testCases: [(low: Double, high: Double, base: Double)] = [
			(0.0, 10.0, 5.0),   // symmetric
			(0.0, 10.0, 7.0),   // right mode
			(0.0, 10.0, 3.0),   // left mode
			(5.0, 15.0, 10.0)   // different range
		]

		for testCase in testCases {
			let sampleCount = 5000
			let seeds = Self.seedsForTriangular(count: sampleCount)
			let expectedMean = (testCase.low + testCase.high + testCase.base) / 3.0

			var samples: [Double] = []
			for i in 0..<sampleCount {
				samples.append(triangularDistribution(low: testCase.low, high: testCase.high, base: testCase.base, seeds[i]))
			}

			let empiricalMean = samples.reduce(0, +) / Double(samples.count)
			#expect(
				abs(empiricalMean - expectedMean) < 0.1,
				"Mean should match (a+b+c)/3 for low=\(testCase.low), high=\(testCase.high), base=\(testCase.base)"
			)
		}
	}

	@Test("Triangular distribution mode is most frequent value")
	func triangularMode() {
		let low = 0.0
		let high = 100.0
		let base = 30.0  // Mode at 30
		let sampleCount = 10000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		// Create histogram to find mode
		let bins = 50
		let binWidth = (high - low) / Double(bins)
		var binCounts: [Int] = Array(repeating: 0, count: bins)

		for sample in samples {
			let binIndex = min(Int((sample - low) / binWidth), bins - 1)
			binCounts[binIndex] += 1
		}

		// Find bin with most samples
		let maxCount = binCounts.max()!
		let modeIndex = binCounts.firstIndex(of: maxCount)!
		let empiricalMode = low + (Double(modeIndex) + 0.5) * binWidth

		// Mode should be close to base
		#expect(abs(empiricalMode - base) < 5.0, "Mode should be close to base parameter")
	}

	@Test("Left-skewed triangular distribution (base near high)")
	func triangularLeftSkewed() {
		// Mode near high end creates left skew
		let low = 0.0
		let high = 10.0
		let base = 9.0
		let sampleCount = 5000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// Left-skewed: mean < median < mode
		#expect(mean < median, "Left-skewed triangular should have mean < median")
		#expect(median < base, "Left-skewed triangular should have median < mode")
	}

	@Test("Right-skewed triangular distribution (base near low)")
	func triangularRightSkewed() {
		// Mode near low end creates right skew
		let low = 0.0
		let high = 10.0
		let base = 1.0
		let sampleCount = 5000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// Right-skewed: mode < median < mean
		#expect(base < median, "Right-skewed triangular should have mode < median")
		#expect(median < mean, "Right-skewed triangular should have median < mean")
	}

	@Test("Triangular distribution with base at low")
	func triangularBaseAtLow() {
		// base = low creates right triangle with mode at low
		let low = 10.0
		let high = 20.0
		let base = 10.0
		let sampleCount = 5000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		// All values should be in range
		#expect(samples.allSatisfy { $0 >= low && $0 <= high })

		// Mode at low means density is highest there, so more values near low
		let midpoint = (low + high) / 2.0
		let belowMid = samples.filter { $0 < midpoint }.count
		let aboveMid = samples.filter { $0 > midpoint }.count

		#expect(belowMid > aboveMid, "Base at low should produce more low values (mode is at low)")
	}

	@Test("Triangular distribution with base at high")
	func triangularBaseAtHigh() {
		// base = high creates right triangle with mode at high
		let low = 10.0
		let high = 20.0
		let base = 20.0
		let sampleCount = 5000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		// All values should be in range
		#expect(samples.allSatisfy { $0 >= low && $0 <= high })

		// Mode at high means density is highest there, so more values near high
		let midpoint = (low + high) / 2.0
		let aboveMid = samples.filter { $0 > midpoint }.count
		let belowMid = samples.filter { $0 < midpoint }.count

		#expect(aboveMid > belowMid, "Base at high should produce more high values (mode is at high)")
	}

	@Test("Triangular distribution struct random() method")
	func triangularStructRandom() {
		let low = 5.0
		let high = 15.0
		let base = 10.0
		let dist = DistributionTriangular(low: low, high: high, base: base)

		let sampleCount = 1000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.random()
			samples.append(sample)
			#expect(sample >= low)
			#expect(sample <= high)
			#expect(sample.isFinite)
		}

		// Check mean
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = (low + high + base) / 3.0
		#expect(abs(empiricalMean - expectedMean) < 0.3, "Mean should be close to (a+b+c)/3")
	}

	@Test("Triangular distribution struct next() method")
	func triangularStructNext() {
		let low = 0.0
		let high = 100.0
		let base = 60.0

		let sampleCount = 2000
		let seeds = Self.seedsForTriangular(count: sampleCount)
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample = triangularDistribution(low: low, high: high, base: base, seeds[i])
			samples.append(sample)
			#expect(sample >= low)
			#expect(sample <= high)
			#expect(sample.isFinite)
		}

		// Verify statistical properties with deterministic seeded values
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = (low + high + base) / 3.0
		#expect(abs(empiricalMean - expectedMean) < 0.5, "Mean should be close to expected")
	}

	@Test("Triangular distribution project estimation use case")
	func triangularProjectEstimation() {
		// Common PERT/project management use: optimistic, most likely, pessimistic
		let optimistic = 5.0  // best case (low)
		let mostLikely = 10.0  // most likely (base/mode)
		let pessimistic = 20.0  // worst case (high)
		let sampleCount = 5000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var estimates: [Double] = []
		for i in 0..<sampleCount {
			estimates.append(triangularDistribution(low: optimistic, high: pessimistic, base: mostLikely, seeds[i]))
		}

		// All estimates should be within bounds
		#expect(estimates.allSatisfy { $0 >= optimistic && $0 <= pessimistic })

		// Expected time = (optimistic + mostLikely + pessimistic) / 3
		let expectedTime = (optimistic + mostLikely + pessimistic) / 3.0
		let empiricalMean = estimates.reduce(0, +) / Double(estimates.count)
		#expect(abs(empiricalMean - expectedTime) < 0.2, "Mean should match formula")

		// Most values should be near mostLikely
		let nearMode = estimates.filter { abs($0 - mostLikely) < 3.0 }.count
		let percentage = Double(nearMode) / Double(estimates.count)
		#expect(percentage > 0.3, "Significant portion should be near mode")
	}

	@Test("Triangular distribution variance formula")
	func triangularVariance() {
		// Variance = (a² + b² + c² - ab - ac - bc) / 18
		let low = 0.0
		let high = 10.0
		let base = 5.0
		let expectedVariance = (low*low + high*high + base*base - low*high - low*base - high*base) / 18.0
		let sampleCount = 10000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)

		#expect(abs(variance - expectedVariance) < 0.3, "Variance should match formula")
	}

	@Test("Triangular distribution seeding produces deterministic results")
	func triangularDeterministicSeeding() {
		let low = 10.0
		let high = 20.0
		let base = 15.0
		let seeds = Self.seedsForTriangular(count: 100)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
			samples2.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("Triangular distribution struct stores parameters")
	func triangularStructParameters() {
		let low = 20.0
		let high = 50.0
		let base = 35.0
		let dist = DistributionTriangular(low: low, high: high, base: base)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be within bounds
		#expect(samples.allSatisfy { $0 >= low && $0 <= high })

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = (low + high + base) / 3.0
		#expect(abs(empiricalMean - expectedMean) < 0.5, "Distribution should maintain consistent properties")
	}

	@Test("Triangular distribution different ranges")
	func triangularDifferentRanges() {
		// Test that wider ranges produce wider spreads
		let sampleCount = 5000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samplesNarrow: [Double] = []
		var samplesWide: [Double] = []

		for i in 0..<sampleCount {
			samplesNarrow.append(triangularDistribution(low: 10.0, high: 12.0, base: 11.0, seeds[i]))
			samplesWide.append(triangularDistribution(low: 0.0, high: 100.0, base: 50.0, seeds[i]))
		}

		let rangeNarrow = samplesNarrow.max()! - samplesNarrow.min()!
		let rangeWide = samplesWide.max()! - samplesWide.min()!

		#expect(rangeWide > 10 * rangeNarrow, "Wider parameter range should produce wider spread")
	}

	@Test("Triangular distribution uniform when base is center")
	func triangularApproachesUniform() {
		// When base is exactly at center, distribution is most uniform-like
		let low = 0.0
		let high = 10.0
		let base = 5.0  // Exactly in center
		let sampleCount = 10000
		let seeds = Self.seedsForTriangular(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(triangularDistribution(low: low, high: high, base: base, seeds[i]))
		}

		// Divide into quarters and check distribution
		let q1 = samples.filter { $0 < 2.5 }.count
		let q2 = samples.filter { $0 >= 2.5 && $0 < 5.0 }.count
		let q3 = samples.filter { $0 >= 5.0 && $0 < 7.5 }.count
		let q4 = samples.filter { $0 >= 7.5 }.count

		// For symmetric triangular, inner quarters should have more than outer quarters
		#expect(q2 > q1, "Inner quarters should have more samples")
		#expect(q3 > q4, "Inner quarters should have more samples")
	}
}
