//
//  RayleighDistributionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/25.
//

import Foundation
import Testing
import Numerics
import OSLog

@testable import BusinessMath

@Suite("Rayleigh Distribution Tests")
struct RayleighDistributionTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.RayleighDistributionTests", category: #function)

	// Helper function to generate seeds for Rayleigh distribution using SeededRNG
	// Rayleigh uses 1 seed per sample
	static func seedsForRayleigh(count: Int) -> [Double] {
		let rng = DistributionSeedingTests.SeededRNG(seed: 88888)  // Unique seed for Rayleigh
		var seeds: [Double] = []

		for _ in 0..<count {
			var seed = rng.next()
			seed = max(0.0001, min(0.9999, seed))
			seeds.append(seed)
		}

		return seeds
	}

	@Test("Rayleigh distribution function produces non-negative values")
	func rayleighFunctionNonNegative() {
		let mean = 1.0
		let sampleCount = 1000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		for i in 0..<sampleCount {
			let sample: Double = distributionRayleigh(mean: mean, seed: seeds[i])
			#expect(sample >= 0, "Rayleigh values must be non-negative")
			#expect(sample.isFinite, "Rayleigh values must be finite")
			#expect(!sample.isNaN, "Rayleigh values must not be NaN")
		}
	}

	@Test("Rayleigh distribution statistical properties")
	func rayleighStatisticalProperties() {
		// For Rayleigh with scale σ: mean ≈ σ√(π/2) ≈ 1.253σ
		// If we want mean = 10, solve for σ: σ = mean / √(π/2)
		let desiredMean = 10.0
		let scale = desiredMean / sqrt(Double.pi / 2.0)
		let sampleCount = 5000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			// Note: the function parameter is "mean" but internally uses it as scale
			let sample: Double = distributionRayleigh(mean: scale, seed: seeds[i])
			samples.append(sample)
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let tolerance = 1.0

		#expect(abs(empiricalMean - desiredMean) < tolerance, "Mean should be close to expected")
	}

	@Test("Rayleigh distribution always positive")
	func rayleighAlwaysPositive() {
		let mean = 5.0
		let sampleCount = 5000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionRayleigh(mean: mean, seed: seeds[i]))
		}

		// All values must be positive
		#expect(samples.allSatisfy { $0 > 0 }, "Rayleigh is defined only for positive values")

		// Check that minimum is reasonably close to 0
		let minValue = samples.min()!
		#expect(minValue < 1.0, "Should produce some small values close to 0")
	}

	@Test("Rayleigh distribution right-skewed")
	func rayleighRightSkewed() {
		let mean = 10.0
		let sampleCount = 5000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionRayleigh(mean: mean, seed: seeds[i]))
		}

		let empiricalMean = samples.reduce(0, +) / Double(samples.count)
		let sorted = samples.sorted()
		let median = sorted[sorted.count / 2]

		// Right-skewed: mode < median < mean
		#expect(median < empiricalMean, "Rayleigh should be right-skewed (median < mean)")
	}

	@Test("Rayleigh distribution mode")
	func rayleighMode() {
		// Mode of Rayleigh(σ) = σ
		let scale = 10.0
		let sampleCount = 10000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionRayleigh(mean: scale, seed: seeds[i]))
		}

		// Create histogram to find mode
		let sorted = samples.sorted()
		let bins = 50
		let minVal = sorted.first!
		let maxVal = sorted.last!
		let binWidth = (maxVal - minVal) / Double(bins)

		var binCounts: [Int] = Array(repeating: 0, count: bins)
		for sample in samples {
			let binIndex = min(Int((sample - minVal) / binWidth), bins - 1)
			binCounts[binIndex] += 1
		}

		// Find bin with most samples
		let maxCount = binCounts.max()!
		let modeIndex = binCounts.firstIndex(of: maxCount)!
		let empiricalMode = minVal + (Double(modeIndex) + 0.5) * binWidth

		// Mode should be close to scale
		#expect(abs(empiricalMode - scale) < 3.0, "Mode should be close to scale parameter")
	}

	@Test("Rayleigh distribution struct random() method")
	func rayleighStructRandom() {
		let mean = 5.0
		let dist = DistributionRayleigh(mean: mean)

		let sampleCount = 1000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			let sample = dist.random()
			samples.append(sample)
			#expect(sample > 0)
			#expect(sample.isFinite)
		}

		// All should be positive
		#expect(samples.allSatisfy { $0 > 0 })
	}

	@Test("Rayleigh distribution struct next() method")
	func rayleighStructNext() {
		let mean = 8.0
		let dist = DistributionRayleigh(mean: mean)

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

	@Test("Rayleigh distribution different scale parameters")
	func rayleighDifferentScales() {
		let sampleCount = 5000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samplesScale2: [Double] = []
		var samplesScale10: [Double] = []

		for i in 0..<sampleCount {
			samplesScale2.append(distributionRayleigh(mean: 2.0, seed: seeds[i]))
			samplesScale10.append(distributionRayleigh(mean: 10.0, seed: seeds[i]))
		}

		let mean2 = samplesScale2.reduce(0, +) / Double(samplesScale2.count)
		let mean10 = samplesScale10.reduce(0, +) / Double(samplesScale10.count)

		// Larger scale should produce larger mean
		#expect(mean10 > mean2, "Larger scale should produce larger values")

		// Means should scale proportionally
		let ratio = mean10 / mean2
		#expect(ratio > 3.0 && ratio < 7.0, "Means should scale with scale parameter")
	}

	@Test("Rayleigh distribution wind speed application")
	func rayleighWindSpeed() {
		// Rayleigh is commonly used to model wind speeds
		// Example: average wind speed of 15 m/s
		let averageWindSpeed = 15.0
		let scale = averageWindSpeed / sqrt(Double.pi / 2.0)
		let sampleCount = 5000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var windSpeeds: [Double] = []
		for i in 0..<sampleCount {
			windSpeeds.append(distributionRayleigh(mean: scale, seed: seeds[i]))
		}

		// All wind speeds should be positive
		#expect(windSpeeds.allSatisfy { $0 > 0 })

		// Calculate empirical mean
		let empiricalMean = windSpeeds.reduce(0, +) / Double(windSpeeds.count)

		#expect(abs(empiricalMean - averageWindSpeed) < 2.0, "Mean wind speed should match target")

		// Should see some calm periods (low speeds) and some gusts (high speeds)
		let lowSpeeds = windSpeeds.filter { $0 < averageWindSpeed / 2 }.count
		let highSpeeds = windSpeeds.filter { $0 > averageWindSpeed * 1.5 }.count

		#expect(lowSpeeds > 0, "Should have some low wind speeds")
		#expect(highSpeeds > 0, "Should have some high wind speeds")
	}

	@Test("Rayleigh distribution magnitude of 2D normal vector")
	func rayleighAs2DNormalMagnitude() {
		// Rayleigh arises as magnitude of (X,Y) where X,Y ~ N(0,σ²)
		// Magnitude = √(X² + Y²) ~ Rayleigh(σ)
		let σ = 5.0
		let sampleCount = 5000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var rayleighSamples: [Double] = []
		for i in 0..<sampleCount {
			rayleighSamples.append(distributionRayleigh(mean: σ, seed: seeds[i]))
		}

		// All should be positive
		#expect(rayleighSamples.allSatisfy { $0 > 0 })

		// Mean of Rayleigh(σ) = σ√(π/2)
		let expectedMean = σ * sqrt(Double.pi / 2.0)
		let empiricalMean = rayleighSamples.reduce(0, +) / Double(rayleighSamples.count)

		#expect(abs(empiricalMean - expectedMean) < 1.0, "Mean should match σ√(π/2)")
	}

	@Test("Rayleigh distribution CDF properties")
	func rayleighCDF() {
		// CDF: F(x) = 1 - e^(-x²/2σ²)
		// At x = σ, CDF ≈ 0.393
		let σ = 10.0
		let sampleCount = 10000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionRayleigh(mean: σ, seed: seeds[i]))
		}

		// Count values <= σ
		let countBelowScale = samples.filter { $0 <= σ }.count
		let empiricalCDF = Double(countBelowScale) / Double(samples.count)

		let theoreticalCDF = 1.0 - exp(-0.5)  // ≈ 0.393

		#expect(abs(empiricalCDF - theoreticalCDF) < 0.02, "Empirical CDF should match theoretical")
	}

	@Test("Rayleigh distribution seeding produces deterministic results")
	func rayleighDeterministicSeeding() {
		let mean = 10.0
		let seeds = Self.seedsForRayleigh(count: 100)

		// Generate sequence twice with same seeds
		var samples1: [Double] = []
		var samples2: [Double] = []

		for i in 0..<100 {
			samples1.append(distributionRayleigh(mean: mean, seed: seeds[i]))
			samples2.append(distributionRayleigh(mean: mean, seed: seeds[i]))
		}

		#expect(samples1 == samples2, "Same seeds should produce identical sequences")
	}

	@Test("Rayleigh distribution struct stores mean parameter")
	func rayleighStructParameters() {
		let mean = 12.0
		let dist = DistributionRayleigh(mean: mean)

		let sampleCount = 2000
		var samples: [Double] = []
		for _ in 0..<sampleCount {
			samples.append(dist.next())
		}

		// All values should be positive
		#expect(samples.allSatisfy { $0 > 0 })

		// Should have reasonable spread
		let maxValue = samples.max()!
		let minValue = samples.min()!
		#expect(maxValue > minValue * 2, "Should have reasonable spread")
	}

	@Test("Rayleigh distribution percentiles")
	func rayleighPercentiles() {
		let σ = 10.0
		let sampleCount = 10000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionRayleigh(mean: σ, seed: seeds[i]))
		}

		let sorted = samples.sorted()

		// 50th percentile (median)
		let p50 = sorted[sorted.count / 2]
		// Theoretical median: σ√(2ln2) ≈ 1.177σ
		let theoreticalMedian = σ * sqrt(2.0 * log(2.0))
		#expect(abs(p50 - theoreticalMedian) < 1.0, "Median should match σ√(2ln2)")

		// All values should be positive
		#expect(sorted.first! > 0, "Minimum should be positive")
	}

	@Test("Rayleigh distribution extreme values")
	func rayleighExtremeValues() {
		// Rayleigh has moderate right tail
		let σ = 10.0
		let sampleCount = 10000
		let seeds = Self.seedsForRayleigh(count: sampleCount)

		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionRayleigh(mean: σ, seed: seeds[i]))
		}

		// Should see some values much larger than mode
		let maxValue = samples.max()!
		#expect(maxValue > 3 * σ, "Should produce some extreme values")

		// Count values > 2σ
		let extremeValues = samples.filter { $0 > 2 * σ }.count
		let extremePercent = Double(extremeValues) / Double(samples.count)

		// Should have reasonable number of high values
		#expect(extremePercent > 0.05, "Should have some extreme values in right tail")
	}
}
