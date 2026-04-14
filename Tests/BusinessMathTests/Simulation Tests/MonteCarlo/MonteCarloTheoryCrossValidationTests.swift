//
//  MonteCarloTheoryCrossValidationTests.swift
//  BusinessMath
//
//  Cross-validates Monte Carlo simulation statistics against theoretical
//  distribution properties (known mean, variance, additivity).
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Monte Carlo Theory Cross-Validation Tests")
struct MonteCarloTheoryCrossValidationTests {

	/// Number of samples for statistical reliability
	private let sampleCount = 100_000

	/// Relative tolerance for statistical comparisons (~5%)
	private let relativeTolerance = 0.05

	@Test("Normal(100, 15): mean converges to 100, variance converges to 225")
	func normalDistributionMeanAndVariance() throws {
		let theoreticalMean = 100.0
		let theoreticalStdDev = 15.0
		let theoreticalVariance = theoreticalStdDev * theoreticalStdDev

		var samples: [Double] = []
		samples.reserveCapacity(sampleCount)
		for _ in 0..<sampleCount {
			let value: Double = distributionNormal(mean: theoreticalMean, stdDev: theoreticalStdDev)
			samples.append(value)
		}

		let results = SimulationResults(values: samples)

		let meanError = abs(results.statistics.mean - theoreticalMean)
		#expect(meanError < theoreticalMean * relativeTolerance,
			"Normal mean \(results.statistics.mean) should be within 5% of \(theoreticalMean)")

		let varianceError = abs(results.statistics.variance - theoreticalVariance)
		#expect(varianceError < theoreticalVariance * relativeTolerance,
			"Normal variance \(results.statistics.variance) should be within 5% of \(theoreticalVariance)")
	}

	@Test("Uniform(10, 50): mean converges to 30, variance converges to 133.33")
	func uniformDistributionMeanAndVariance() throws {
		let low = 10.0
		let high = 50.0
		let theoreticalMean = (low + high) / 2.0
		let theoreticalVariance = (high - low) * (high - low) / 12.0

		var samples: [Double] = []
		samples.reserveCapacity(sampleCount)
		for _ in 0..<sampleCount {
			let value: Double = distributionUniform(min: low, max: high)
			samples.append(value)
		}

		let results = SimulationResults(values: samples)

		let meanError = abs(results.statistics.mean - theoreticalMean)
		#expect(meanError < theoreticalMean * relativeTolerance,
			"Uniform mean \(results.statistics.mean) should be within 5% of \(theoreticalMean)")

		let varianceError = abs(results.statistics.variance - theoreticalVariance)
		#expect(varianceError < theoreticalVariance * relativeTolerance,
			"Uniform variance \(results.statistics.variance) should be within 5% of \(theoreticalVariance)")
	}

	@Test("Exponential(0.5): mean converges to 2.0 (1/lambda)")
	func exponentialDistributionMean() throws {
		let lambda = 0.5
		let theoreticalMean = 1.0 / lambda
		let theoreticalVariance = 1.0 / (lambda * lambda)

		var samples: [Double] = []
		samples.reserveCapacity(sampleCount)
		for _ in 0..<sampleCount {
			let value: Double = distributionExponential(λ: lambda)
			samples.append(value)
		}

		let results = SimulationResults(values: samples)

		let meanError = abs(results.statistics.mean - theoreticalMean)
		#expect(meanError < theoreticalMean * relativeTolerance,
			"Exponential mean \(results.statistics.mean) should be within 5% of \(theoreticalMean)")

		let varianceError = abs(results.statistics.variance - theoreticalVariance)
		#expect(varianceError < theoreticalVariance * relativeTolerance,
			"Exponential variance \(results.statistics.variance) should be within 5% of \(theoreticalVariance)")
	}

	@Test("Sum of two independent normals: mean and variance are additive")
	func sumOfIndependentNormals() throws {
		let meanX = 50.0, stdDevX = 10.0
		let meanY = 30.0, stdDevY = 5.0
		let theoreticalSumMean = meanX + meanY
		let theoreticalSumVariance = stdDevX * stdDevX + stdDevY * stdDevY

		var sumSamples: [Double] = []
		sumSamples.reserveCapacity(sampleCount)
		for _ in 0..<sampleCount {
			let x: Double = distributionNormal(mean: meanX, stdDev: stdDevX)
			let y: Double = distributionNormal(mean: meanY, stdDev: stdDevY)
			sumSamples.append(x + y)
		}

		let results = SimulationResults(values: sumSamples)

		let meanError = abs(results.statistics.mean - theoreticalSumMean)
		#expect(meanError < theoreticalSumMean * relativeTolerance,
			"Sum mean \(results.statistics.mean) should be within 5% of \(theoreticalSumMean)")

		let varianceError = abs(results.statistics.variance - theoreticalSumVariance)
		#expect(varianceError < theoreticalSumVariance * relativeTolerance,
			"Sum variance \(results.statistics.variance) should be within 5% of \(theoreticalSumVariance)")
	}
}
