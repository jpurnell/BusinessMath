//
//  SimulationStatisticsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("SimulationStatistics Tests")
struct SimulationStatisticsTests {

	@Test("SimulationStatistics initialization from simple dataset")
	func simulationStatisticsInitialization() {
		// Simple dataset: 1 through 10
		let values = (1...10).map { Double($0) }
		let stats = SimulationStatistics(values: values)

		// Test basic statistics
		#expect(stats.mean == 5.5, "Mean of 1-10 should be 5.5")
		#expect(stats.median == 5.5, "Median of 1-10 should be 5.5")
		#expect(stats.min == 1.0, "Min should be 1.0")
		#expect(stats.max == 10.0, "Max should be 10.0")

		// Test standard deviation
		// For 1-10: stdDev ≈ 2.872 (population) or 3.028 (sample)
		// We'll use sample standard deviation (n-1)
		let expectedStdDev = 3.028
		let tolerance = 0.01
		#expect(abs(stats.stdDev - expectedStdDev) < tolerance, "StdDev should be ~3.028")

		// Variance = stdDev^2
		let expectedVariance = expectedStdDev * expectedStdDev
		#expect(abs(stats.variance - expectedVariance) < 0.1, "Variance should be ~9.17")
	}

	@Test("SimulationStatistics with normal distribution data")
	func simulationStatisticsNormalDistribution() {
		// Generate 10,000 samples from N(100, 15)
		var values: [Double] = []
		for _ in 0..<10_000 {
			values.append(distributionNormal(mean: 100.0, stdDev: 15.0))
		}

		let stats = SimulationStatistics(values: values)

		// With 10,000 samples, these should be close to theoretical values
		#expect(stats.mean > 98.0 && stats.mean < 102.0, "Mean should be near 100")
		#expect(stats.stdDev > 14.0 && stats.stdDev < 16.0, "StdDev should be near 15")
		#expect(stats.median > 98.0 && stats.median < 102.0, "Median should be near 100")

		// For normal distribution, skewness should be close to 0
		#expect(abs(stats.skewness) < 0.2, "Skewness should be near 0 for normal distribution")
	}

	@Test("SimulationStatistics with uniform distribution data")
	func simulationStatisticsUniformDistribution() {
		// Generate 5,000 samples from Uniform[0, 100]
		let values = (0..<5_000).map { _ in distributionUniform(min: 0.0, max: 100.0) }
		let stats = SimulationStatistics(values: values)

		// Theoretical: mean = 50, stdDev = 100/sqrt(12) ≈ 28.87
		#expect(stats.mean > 48.0 && stats.mean < 52.0, "Mean should be near 50")
		#expect(stats.stdDev > 27.0 && stats.stdDev < 30.0, "StdDev should be near 28.87")

		// Uniform distribution should have skewness near 0
		#expect(abs(stats.skewness) < 0.2, "Skewness should be near 0 for uniform distribution")
	}

	@Test("SimulationStatistics confidence intervals")
	func simulationStatisticsConfidenceIntervals() {
		// Normal distribution N(100, 15) with 10,000 samples
		var values: [Double] = []
		for _ in 0..<10_000 {
			values.append(distributionNormal(mean: 100.0, stdDev: 15.0))
		}

		let stats = SimulationStatistics(values: values)

		// 90% CI: mean ± 1.645 * stdDev
		let ci90 = stats.confidenceInterval(level: 0.90)
		let expectedLower90 = stats.mean - 1.645 * stats.stdDev
		let expectedUpper90 = stats.mean + 1.645 * stats.stdDev
		#expect(abs(ci90.low - expectedLower90) < 1.0, "90% CI lower bound")
		#expect(abs(ci90.high - expectedUpper90) < 1.0, "90% CI upper bound")

		// 95% CI: mean ± 1.96 * stdDev
		let ci95 = stats.confidenceInterval(level: 0.95)
		let expectedLower95 = stats.mean - 1.96 * stats.stdDev
		let expectedUpper95 = stats.mean + 1.96 * stats.stdDev
		#expect(abs(ci95.low - expectedLower95) < 1.0, "95% CI lower bound")
		#expect(abs(ci95.high - expectedUpper95) < 1.0, "95% CI upper bound")

		// 99% CI: mean ± 2.576 * stdDev
		let ci99 = stats.confidenceInterval(level: 0.99)
		let expectedLower99 = stats.mean - 2.576 * stats.stdDev
		let expectedUpper99 = stats.mean + 2.576 * stats.stdDev
		#expect(abs(ci99.low - expectedLower99) < 1.0, "99% CI lower bound")
		#expect(abs(ci99.high - expectedUpper99) < 1.0, "99% CI upper bound")

		// Verify CI ordering: 99% should be widest
		let width90 = ci90.high - ci90.low
		let width95 = ci95.high - ci95.low
		let width99 = ci99.high - ci99.low
		#expect(width90 < width95, "90% CI should be narrower than 95%")
		#expect(width95 < width99, "95% CI should be narrower than 99%")
	}

	@Test("SimulationStatistics convenience CI properties")
	func simulationStatisticsConvenienceCIs() {
		// Generate normal distribution data
		var values: [Double] = []
		for _ in 0..<5_000 {
			values.append(distributionNormal(mean: 50.0, stdDev: 10.0))
		}

		let stats = SimulationStatistics(values: values)

		// Test convenience properties match the method
		#expect(stats.ci90.low == stats.confidenceInterval(level: 0.90).low)
		#expect(stats.ci90.high == stats.confidenceInterval(level: 0.90).high)
		#expect(stats.ci95.low == stats.confidenceInterval(level: 0.95).low)
		#expect(stats.ci95.high == stats.confidenceInterval(level: 0.95).high)
		#expect(stats.ci99.low == stats.confidenceInterval(level: 0.99).low)
		#expect(stats.ci99.high == stats.confidenceInterval(level: 0.99).high)
	}

	@Test("SimulationStatistics with single value")
	func simulationStatisticsSingleValue() {
		let values = [42.0]
		let stats = SimulationStatistics(values: values)

		// All statistics should be 42 or 0
		#expect(stats.mean == 42.0)
		#expect(stats.median == 42.0)
		#expect(stats.min == 42.0)
		#expect(stats.max == 42.0)
		#expect(stats.stdDev == 0.0, "StdDev should be 0 for single value")
		#expect(stats.variance == 0.0, "Variance should be 0 for single value")
		#expect(stats.skewness.isNaN, "Skewness is undefined (NaN) when variance is 0")

		// CI should collapse to the single value
		let ci95 = stats.ci95
		#expect(ci95.low == 42.0)
		#expect(ci95.high == 42.0)
	}

	@Test("SimulationStatistics with all same values")
	func simulationStatisticsAllSameValues() {
		let values = Array(repeating: 100.0, count: 50)
		let stats = SimulationStatistics(values: values)

		// All statistics should be 100 or 0
		#expect(stats.mean == 100.0)
		#expect(stats.median == 100.0)
		#expect(stats.min == 100.0)
		#expect(stats.max == 100.0)
		#expect(stats.stdDev == 0.0, "StdDev should be 0 for constant values")
		#expect(stats.variance == 0.0, "Variance should be 0 for constant values")
		#expect(stats.skewness.isNaN, "Skewness is undefined (NaN) when variance is 0")
	}

	@Test("SimulationStatistics skewness calculation")
	func simulationStatisticsSkewness() {
		// Right-skewed distribution: most values low, few high
		let rightSkewed = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0, 15.0, 20.0]
		let rightStats = SimulationStatistics(values: rightSkewed)
		#expect(rightStats.skewness > 0.5, "Right-skewed distribution should have positive skewness")

		// Left-skewed distribution: most values high, few low
		let leftSkewed = [1.0, 5.0, 10.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0]
		let leftStats = SimulationStatistics(values: leftSkewed)
		#expect(leftStats.skewness < -0.5, "Left-skewed distribution should have negative skewness")

		// Symmetric distribution
		let symmetric = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
		let symStats = SimulationStatistics(values: symmetric)
		#expect(abs(symStats.skewness) < 0.3, "Symmetric distribution should have skewness near 0")
	}

	@Test("SimulationStatistics with negative values")
	func simulationStatisticsNegativeValues() {
		// Mix of positive and negative values
		let values = [-50.0, -25.0, 0.0, 25.0, 50.0, 75.0, 100.0]
		let stats = SimulationStatistics(values: values)

		#expect(stats.min == -50.0)
		#expect(stats.max == 100.0)
		#expect(stats.median == 25.0, "Median should be 25")

		// Mean = sum / count = 175 / 7 = 25
		#expect(stats.mean == 25.0, "Mean should be 25")
	}

	@Test("SimulationStatistics with large dataset")
	func simulationStatisticsLargeDataset() {
		// Generate 100,000 samples to test performance
		var values: [Double] = []
		for _ in 0..<100_000 {
			values.append(distributionNormal(mean: 0.0, stdDev: 1.0))
		}

		let stats = SimulationStatistics(values: values)

		// Should complete quickly and have values near standard normal
		#expect(abs(stats.mean) < 0.05, "Mean should be near 0")
		#expect(abs(stats.stdDev - 1.0) < 0.05, "StdDev should be near 1")
		#expect(abs(stats.skewness) < 0.1, "Skewness should be near 0")
	}

	@Test("SimulationStatistics variance-stdDev relationship")
	func simulationStatisticsVarianceStdDev() {
		let values = [10.0, 20.0, 30.0, 40.0, 50.0]
		let stats = SimulationStatistics(values: values)

		// Variance should equal stdDev^2
		let varianceFromStdDev = stats.stdDev * stats.stdDev
		let tolerance = 0.001
		#expect(abs(stats.variance - varianceFromStdDev) < tolerance, "Variance should equal stdDev^2")
	}

	@Test("SimulationStatistics with exponential distribution")
	func simulationStatisticsExponentialDistribution() {
		// Exponential distribution with lambda = 0.5 (mean = 2.0)
		let values = (0..<10_000).map { _ in distributionExponential(λ: 0.5) }
		let stats = SimulationStatistics(values: values)

		// Theoretical: mean = 1/lambda = 2.0, stdDev = 1/lambda = 2.0
		#expect(stats.mean > 1.8 && stats.mean < 2.2, "Mean should be near 2.0")
		#expect(stats.stdDev > 1.8 && stats.stdDev < 2.2, "StdDev should be near 2.0")

		// Exponential distribution is right-skewed (skewness = 2)
		#expect(stats.skewness > 1.5 && stats.skewness < 2.5, "Skewness should be near 2.0")
	}
}

@Suite("SimulationStatistics – Additional")
struct SimulationStatisticsAdditionalTests {

	@Test("Coverage interval vs CI of the mean – semantics pin")
	func coverageVsCiOfMean() {
		// If your API is intended as coverage interval, this test pins it.
		// If you intend to return a CI of the mean, update implementation and this test accordingly.
		var values: [Double] = []
		for _ in 0..<5000 {
			values.append(distributionNormal(mean: 100.0, stdDev: 15.0))
		}

		let stats = SimulationStatistics(values: values)
		let ci95 = stats.confidenceInterval(level: 0.95)

		// Coverage interval (not CI of the mean): mean ± 1.96*σ
		let expectedLow = stats.mean - 1.96 * stats.stdDev
		let expectedHigh = stats.mean + 1.96 * stats.stdDev

		#expect(abs(ci95.low - expectedLow) < 1.0)
		#expect(abs(ci95.high - expectedHigh) < 1.0)
	}
}
