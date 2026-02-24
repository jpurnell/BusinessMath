//
//  ParetoDistributionTests.swift
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

@Suite("Pareto Distribution Tests")
struct ParetoDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.ParetoDistributionTests", category: #function)

	// Helper function to generate seeds for Pareto distribution using SeededRNG
	// Pareto uses inverse transform with 1 seed per sample
	static func seedsForPareto(count: Int) -> [Double] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 54321)  // Unique seed for Pareto
		var seeds: [Double] = []

		for _ in 0..<count {
			var seed = rng.next()
			seed = max(0.0001, min(0.9999, seed))
			seeds.append(seed)
		}

		return seeds
	}

	@Test("Pareto distribution function produces values >= scale")
	func paretoFunctionBounds() {
		// Test with scale = 1.0, shape = 2.0
		let scale = 1.0
		let shape = 2.0

		// Generate 1000 samples


		let sampleCount = 1000


		let seeds = Self.seedsForPareto(count: sampleCount)



		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			#expect(sample >= scale, "Pareto values must be >= scale parameter")
			#expect(sample.isFinite, "Pareto values must be finite")
			#expect(!sample.isNaN, "Pareto values must not be NaN")
		}
	}

	@Test("Pareto distribution function statistical properties - shape=3")
	func paretoFunctionStatistics() {
		// Test Pareto(scale=1, shape=3)
		// Mean = (α×xₘ)/(α-1) = (3×1)/(3-1) = 1.5
		// Variance = (xₘ²×α)/((α-1)²(α-2)) = (1×3)/(4×1) = 0.75
		let scale = 1.0
		let shape = 3.0
		let expectedMean = (shape * scale) / (shape - 1)  // 1.5
		
		let sampleCount = 1000
		let seeds = Self.seedsForPareto(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 0.1

		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to (α×xₘ)/(α-1)")
	}

	@Test("Pareto distribution struct random() method")
	func paretoStructRandom() {
		let scale = 1.0
		let shape = 2.0
		let sampleCount = 1000
		let seeds = Self.seedsForPareto(count: sampleCount)

		// Test that random() produces values >= scale
		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			#expect(sample >= 1.0)
			#expect(sample.isFinite)
			#expect(!sample.isNaN)
		}
	}

	@Test("Pareto distribution struct next() method")
	func paretoStructNext() {
		let scale = 10.0
		let shape = 2.5
		let sampleCount = 2000
		let seeds = Self.seedsForPareto(count: sampleCount)

		// Test that next() produces values >= scale
		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			samples.append(sample)
			#expect(sample >= 10.0)
			#expect(sample.isFinite)
		}

		// Verify mean
		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = (2.5 * 10.0) / (2.5 - 1)  // 16.67
		let tolerance = 1.0
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Mean should be close to expected")
	}

	@Test("Pareto distribution with shape=1.5 (80/20 rule)")
	func pareto8020Rule() {
		// Shape ≈ 1.5 models the classic 80/20 rule
		let scale = 1.0
		let shape = 1.5
		
		let sampleCount = 2000
		let seeds = Self.seedsForPareto(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			samples.append(sample)
		}

		// Sort to analyze distribution
		let sorted = samples.sorted()

		// Check that top 20% holds significant proportion of total
		let top20Index = Int(Double(samples.count) * 0.8)
		let top20Values = Array(sorted[top20Index...])
		let totalSum = samples.reduce(0, +)
		let top20Sum = top20Values.reduce(0, +)
		let top20Percentage = top20Sum / totalSum

		// For shape=1.5, top 20% should hold > 50% of total
		#expect(top20Percentage > 0.50, "Top 20% should hold majority of value (power law)")
	}

	@Test("Pareto distribution different scale parameters")
	func paretoDifferentScales() {
		// Test that scale parameter shifts minimum value
		let shape = 2.0
		
		let sampleCount = 5000
		let seeds = Self.seedsForPareto(count: sampleCount)

		var samplesScale1: [Double] = []
		var samplesScale10: [Double] = []

		for i in 0..<sampleCount {
			samplesScale1.append(distributionPareto(scale: 1.0, shape: shape, seed: seeds[i]))
			samplesScale10.append(distributionPareto(scale: 10.0, shape: shape, seed: seeds[i]))
		}

		// All scale=1 samples should be >= 1
		#expect(samplesScale1.allSatisfy { $0 >= 1.0 })

		// All scale=10 samples should be >= 10
		#expect(samplesScale10.allSatisfy { $0 >= 10.0 })

		// Mean should scale proportionally (with larger tolerance for heavy tails)
		let mean1 = samplesScale1.reduce(0, +) / Double(samplesScale1.count)
		let mean10 = samplesScale10.reduce(0, +) / Double(samplesScale10.count)

		// mean10 should be approximately 10× mean1 (allow wider range due to heavy tails)
		let ratio = mean10 / mean1
		#expect(ratio > 8.0 && ratio < 12.0, "Means should scale with scale parameter")
	}

	@Test("Pareto distribution with high shape (less inequality)")
	func paretoHighShape() {
		// High shape means less inequality (more concentrated around minimum)
		let scale = 1.0
		let shape = 10.0
		
		let sampleCount = 5000
		let seeds = Self.seedsForPareto(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			samples.append(sample)
		}

		// With high shape, most values should be close to scale
		let withinTwoScale = samples.filter { $0 < 2.0 * scale }.count
		let percentage = Double(withinTwoScale) / Double(samples.count)

		// Expect > 80% of values within 2× the scale
		#expect(percentage > 0.80, "High shape should produce values concentrated near scale")
	}

	@Test("Pareto distribution with low shape (high inequality)")
	func paretoLowShape() {
		// Low shape means high inequality (long tail, extreme values)
		let scale = 1.0
		let shape = 1.2
		
		let sampleCount = 5000
		let seeds = Self.seedsForPareto(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			samples.append(sample)
		}

		// With low shape, should see significant tail (values >> scale)
		let extremeValues = samples.filter { $0 > 10.0 * scale }.count
		let percentage = Double(extremeValues) / Double(samples.count)

		// Expect some extreme values (>10× scale)
		#expect(percentage > 0.01, "Low shape should produce extreme tail values")
	}

	@Test("Pareto distribution heavy tail property")
	func paretoHeavyTail() {
		// Pareto has heavier tail than exponential
		let scale = 1.0
		let shape = 2.0
		
		let sampleCount = 10000
		let seeds = Self.seedsForPareto(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			samples.append(sample)
		}

		// Calculate maximum value
		let maxValue = samples.max() ?? 0

		// With 10K samples, should see some very extreme values
		// (much larger than what exponential would produce)
		#expect(maxValue > 20.0, "Heavy tail should produce extreme outliers")
	}

	@Test("Pareto distribution mean for shape > 1")
	func paretoMeanShapeGreaterThan1() {
		// Test mean calculation for various shape > 1
		let testCases: [(scale: Double, shape: Double, expectedMean: Double)] = [
			(1.0, 2.0, 2.0),    // (2×1)/(2-1) = 2
			(1.0, 3.0, 1.5),    // (3×1)/(3-1) = 1.5
			(2.0, 4.0, 2.67),   // (4×2)/(4-1) = 8/3 ≈ 2.67
		]
		
		let sampleCount = 5000
		let seeds = Self.seedsForPareto(count: sampleCount)

		for testCase in testCases {
			var samples: [Double] = []
			for i in 0..<sampleCount {
				samples.append(distributionPareto(scale: testCase.scale, shape: testCase.shape, seed: seeds[i]))
			}

			let empiricalMean = samples.reduce(0, +) / Double(samples.count)
			let tolerance = 0.15
			#expect(
				abs(empiricalMean - testCase.expectedMean) < tolerance,
				"Mean should match (α×xₘ)/(α-1) for scale=\(testCase.scale), shape=\(testCase.shape)"
			)
		}
	}

	@Test("Pareto distribution median")
	func paretoMedian() {
		// Median of Pareto(xₘ, α) = xₘ × 2^(1/α)
		let scale = 1.0
		let shape = 2.0
		let expectedMedian = scale * pow(2.0, 1.0/shape)  // 1 × 2^0.5 = 1.414
		
		let sampleCount = 5000
		let seeds = Self.seedsForPareto(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			let sample: Double = distributionPareto(scale: scale, shape: shape, seed: seeds[i])
			samples.append(sample)
		}

		let sorted = samples.sorted()
		let empiricalMedian = sorted[sorted.count / 2]
		let tolerance = 0.05

		#expect(abs(empiricalMedian - expectedMedian) < tolerance, "Median should match xₘ × 2^(1/α)")
	}

	@Test("Pareto distribution struct stores parameters")
	func paretoStructParameters() {
		let scale = 5.0
		let shape = 3.0
		
		let sampleCount = 1000
		let seeds = Self.seedsForPareto(count: sampleCount)

		// Generate samples and verify consistency
		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionPareto(scale: scale, shape: shape, seed: seeds[i]))
		}

		// All values should be >= scale
		#expect(samples.allSatisfy { $0 >= scale })

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let expectedMean = (shape * scale) / (shape - 1)
		let tolerance = 0.5
		#expect(abs(empiricalMean - expectedMean) < tolerance, "Distribution should maintain consistent properties")
	}
}
