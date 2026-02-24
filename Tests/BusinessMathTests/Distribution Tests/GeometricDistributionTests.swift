//
//  GeometricDistributionTests.swift
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

@Suite("Geometric Distribution Tests")
struct GeometricDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.GeometricDistributionTests", category: #function)

	// Helper function to generate seed arrays for Geometric distribution using SeededRNG
	// Geometric needs variable number of seeds (until success), provide enough for testing
	static func seedsForGeometric(count: Int, maxTrialsPerSample: Int = 20) -> [[Double]] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 77777)  // Unique seed for Geometric
		var seedArrays: [[Double]] = []

		for _ in 0..<count {
			var seeds: [Double] = []
			for _ in 0..<maxTrialsPerSample {
				var seed = rng.next()
				seed = max(0.0001, min(0.9999, seed))
				seeds.append(seed)
			}
			seedArrays.append(seeds)
		}

		return seedArrays
	}

	@Test("Geometric distribution function produces positive integers")
	func geometricFunctionPositiveIntegers() {
		let p = 0.5
		let sampleCount = 1000
		let seedArrays = Self.seedsForGeometric(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = distributionGeometric(p, seeds: seedArrays[i])
			#expect(sample >= 1, "Geometric values must be >= 1")
			#expect(sample == floor(sample), "Geometric values must be integers")
			#expect(sample.isFinite, "Geometric values must be finite")
			#expect(!sample.isNaN, "Geometric values must not be NaN")
		}
	}

	@Test("Geometric distribution statistical properties - mean = 1/p")
	func geometricStatisticalProperties() {
		// Test Geometric(p=0.25)
		// Mean = 1/p = 4
		let p = 0.25
		let expectedMean = 1.0 / p
		let sampleCount = 5000
		let seedArrays = Self.seedsForGeometric(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionGeometric(p, seeds: seedArrays[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.2

		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to 1/p")
	}

	@Test("Geometric distribution with p=0.5")
	func geometricP05() {
		// With p=0.5, expected number of trials is 2
		let p = 0.5
		let expectedMean = 1.0 / p  // 2.0
		let sampleCount = 5000
		let seedArrays = Self.seedsForGeometric(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionGeometric(p, seeds: seedArrays[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(empiricalMean - expectedMean) < 0.1, "Mean should be close to 2")
	}

	@Test("Geometric distribution higher p means fewer trials")
	func geometricProbabilityEffect() {
		// Higher probability of success means fewer trials on average
		let sampleCount = 5000
		let seedArraysP01 = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 50)
		let seedArraysP05 = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 10)

		var samplesP01: [Double] = []
		var samplesP05: [Double] = []

		for i in 0..<sampleCount {
			samplesP01.append(distributionGeometric(0.1, seeds: seedArraysP01[i]))
			samplesP05.append(distributionGeometric(0.5, seeds: seedArraysP05[i]))
		}

		let meanP01 = samplesP01.reduce(0, +) / Double(samplesP01.count)
		let meanP05 = samplesP05.reduce(0, +) / Double(samplesP05.count)

		// p=0.1 should have mean ≈ 10, p=0.5 should have mean ≈ 2
		#expect(meanP01 > meanP05, "Lower p should require more trials")
		#expect(abs(meanP01 - 10.0) < 1.0, "Mean should match 1/p")
		#expect(abs(meanP05 - 2.0) < 0.2, "Mean should match 1/p")
	}

	@Test("Geometric distribution variance = (1-p)/p²")
	func geometricVariance() {
		let p = 0.3
		let expectedMean = 1.0 / p
		let expectedVariance = (1.0 - p) / (p * p)
		let sampleCount = 10000
		let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 20)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - empiricalMean, 2) }.reduce(0, +) / Double(samples.count - 1)

		#expect(abs(empiricalMean - expectedMean) < 0.2, "Mean should match 1/p")
		#expect(abs(variance - expectedVariance) < 1.0, "Variance should match (1-p)/p²")
	}

	@Test("Geometric distribution memoryless property")
	func geometricMemoryless() {
		// Memoryless: P(X > s+t | X > s) = P(X > t)
		// If we condition on X > s, the remaining trials follow same distribution
		let p = 0.3
		let threshold = 3.0
		let sampleCount = 10000
		let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 30)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		// Filter samples > threshold and shift them
		let conditionedSamples = samples.filter { $0 > threshold }.map { $0 - threshold }

		// Mean of conditioned samples should still be ≈ 1/p (memoryless)
		if !conditionedSamples.isEmpty {
			let conditionedMean = conditionedSamples.reduce(0, +) / Double(conditionedSamples.count)
			let expectedMean = 1.0 / p
			#expect(abs(conditionedMean - expectedMean) < 1.0, "Memoryless property: conditioned mean should be ≈ 1/p")
		}
	}

	@Test("Geometric distribution struct random() method")
	func geometricStructRandom() {
		let p = 0.4
		let dist = DistributionGeometric(p)

		let sampleCount = 1000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.random()
			samples.append(sample)
			#expect(sample >= 1)
			#expect(sample == floor(sample))
			#expect(sample.isFinite)
		}

		// Check mean
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0 / p
		#expect(abs(empiricalMean - expectedMean) < 0.3, "Mean should be close to 1/p")
	}

	@Test("Geometric distribution struct next() method")
	func geometricStructNext() {
		let p = 0.25
		let dist = DistributionGeometric(p)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.next()
			samples.append(sample)
			#expect(sample >= 1)
			#expect(sample.isFinite)
		}

		// Verify mean
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0 / p  // 4.0
		#expect(abs(empiricalMean - expectedMean) < 0.3, "Mean should be close to expected")
	}

	@Test("Geometric distribution probability of first success on first trial")
	func geometricFirstTrial() {
		// P(X=1) = p
		let p = 0.5
		let sampleCount = 5000
		let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 10)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		let firstTrialSuccesses = samples.filter { $0 == 1.0 }.count
		let empiricalProb = Double(firstTrialSuccesses) / Double(samples.count)

		// Should be close to p
		#expect(abs(empiricalProb - p) < 0.02, "P(X=1) should equal p")
	}

	@Test("Geometric distribution right-skewed")
	func geometricRightSkewed() {
		// Geometric is always right-skewed
		let p = 0.3
		let sampleCount = 5000
		let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 30)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// Right-skewed: mode < median < mean
		#expect(median < mean, "Geometric should be right-skewed (median < mean)")
	}

	@Test("Geometric distribution mode is always 1")
	func geometricModeIsOne() {
		// The most likely outcome is always 1 (success on first trial)
		let p = 0.3
		let sampleCount = 5000
		let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 30)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		// Count frequency of each value
		var frequencies: [Double: Int] = [:]
		for sample in samples {
			frequencies[sample, default: 0] += 1
		}

		// Find mode
		let maxFreq = frequencies.values.max()!
		let mode = frequencies.filter { $0.value == maxFreq }.keys.min()!

		#expect(mode == 1.0, "Mode should always be 1 for geometric distribution")
	}

	@Test("Geometric distribution waiting time application")
	func geometricWaitingTime() {
		// Geometric models waiting time: number of trials until first success
		// Example: Number of coin flips until first heads
		let p = 0.5  // fair coin
		let sampleCount = 5000
		let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 20)

		var waitingTimes: [Double] = []
		for i in 0..<sampleCount {
			waitingTimes.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		let meanWaitingTime = waitingTimes.reduce(0, +) / Double(waitingTimes.count)
		let expectedMeanWaitingTime = 1.0 / p  // 2.0 flips on average

		#expect(abs(meanWaitingTime - expectedMeanWaitingTime) < 0.2, "Mean waiting time should match 1/p")

		// All waiting times should be at least 1
		#expect(waitingTimes.allSatisfy { $0 >= 1 })
	}

	@Test("Geometric distribution with different probabilities")
	func geometricDifferentProbabilities() {
		let testCases: [(p: Double, expectedMean: Double)] = [
			(0.1, 10.0),
			(0.25, 4.0),
			(0.5, 2.0),
			(0.8, 1.25)
		]

		for testCase in testCases {
			let sampleCount = 5000
			let maxTrials = Int(ceil(testCase.expectedMean * 5))  // Allocate enough seeds
			let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: maxTrials)

			var samples: [Double] = []
			for i in 0..<sampleCount {
				samples.append(distributionGeometric(testCase.p, seeds: seedArrays[i]))
			}

			let empiricalMean = samples.reduce(0, +) / Double(samples.count)
			let tolerance = max(0.3, testCase.expectedMean * 0.1)
			#expect(
				abs(empiricalMean - testCase.expectedMean) < tolerance,
				"Mean should match 1/p for p=\(testCase.p)"
			)
		}
	}

	@Test("Geometric distribution seeding produces deterministic results")
	func geometricDeterministicSeeding() {
		let p = 0.3
		let seedArrays = Self.seedsForGeometric(count: 100, maxTrialsPerSample: 20)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(distributionGeometric(p, seeds: seedArrays[i]))
			samples2.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("Geometric distribution struct stores probability parameter")
	func geometricStructParameters() {
		let p = 0.35
		let dist = DistributionGeometric(p)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be positive integers
		#expect(samples.allSatisfy { $0 >= 1 && $0 == floor($0) })

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = 1.0 / p
		#expect(abs(empiricalMean - expectedMean) < 0.3, "Distribution should maintain consistent properties")
	}

	@Test("Geometric distribution PMF properties")
	func geometricPMF() {
		// PMF: P(X = k) = (1-p)^(k-1) * p
		let p = 0.4
		let sampleCount = 10000
		let seedArrays = Self.seedsForGeometric(count: sampleCount, maxTrialsPerSample: 20)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionGeometric(p, seeds: seedArrays[i]))
		}

		// Check P(X=2) empirically
		let countX2 = samples.filter { $0 == 2.0 }.count
		let empiricalP2 = Double(countX2) / Double(samples.count)
		let theoreticalP2 = pow(1 - p, 1) * p  // (1-p)^(2-1) * p

		#expect(abs(empiricalP2 - theoreticalP2) < 0.02, "Empirical PMF should match theoretical")
	}
}
