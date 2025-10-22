//
//  SimulationResultsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
import OSLog
@testable import BusinessMath

@Suite("SimulationResults Tests")
struct SimulationResultsTests {
	let logger = Logger(subsystem: "\(#file)", category: "\(#function)")
	@Test("SimulationResults initialization from values")
	func simulationResultsInitialization() {
		// Generate 1000 samples from a normal distribution
		let values = (0..<1_000).map { _ in distributionNormal(mean: 100.0, stdDev: 15.0) }
		let results = SimulationResults(values: values)

		// Verify values are stored
		#expect(results.values.count == 1_000, "Should have 1000 values")

		// Verify statistics are computed
		#expect(results.statistics.mean > 95.0 && results.statistics.mean < 105.0, "Mean should be near 100")
		#expect(results.statistics.stdDev > 13.0 && results.statistics.stdDev < 17.0, "StdDev should be near 15")

		// Verify percentiles are computed
		#expect(results.percentiles.p50 > 95.0 && results.percentiles.p50 < 105.0, "Median should be near 100")
	}

	@Test("SimulationResults probability calculations")
	func simulationResultsProbabilities() {
		// Create a uniform distribution [0, 100] for predictable probabilities
		let values = (0..<10_000).map { _ in distributionUniform(min: 0.0, max: 100.0) }
		let results = SimulationResults(values: values)

		// Test probabilityAbove
		let probAbove50 = results.probabilityAbove(50.0)
		#expect(probAbove50 > 0.45 && probAbove50 < 0.55, "P(X > 50) should be ~0.5 for Uniform[0,100]")

		// Test probabilityBelow
		let probBelow25 = results.probabilityBelow(25.0)
		#expect(probBelow25 > 0.20 && probBelow25 < 0.30, "P(X < 25) should be ~0.25 for Uniform[0,100]")

		// Test probabilityBetween
		let probBetween25And75 = results.probabilityBetween(25.0, 75.0)
		#expect(probBetween25And75 > 0.45 && probBetween25And75 < 0.55, "P(25 < X < 75) should be ~0.5")
	}

	@Test("SimulationResults probability edge cases")
	func simulationResultsProbabilityEdgeCases() {
		let values = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
		let results = SimulationResults(values: values)

		// All values above 0
		#expect(results.probabilityAbove(0.0) == 1.0, "All values > 0")

		// All values below 200
		#expect(results.probabilityBelow(200.0) == 1.0, "All values < 200")

		// No values above 200
		#expect(results.probabilityAbove(200.0) == 0.0, "No values > 200")

		// No values below 0
		#expect(results.probabilityBelow(0.0) == 0.0, "No values < 0")
	}

	@Test("SimulationResults histogram generation")
	func simulationResultsHistogram() {
		// Generate uniform data for predictable histogram
		let values = (0..<1_000).map { _ in distributionUniform(min: 0.0, max: 100.0) }
		let results = SimulationResults(values: values)

		// Generate histogram with 10 bins
		let histogram = results.histogram(bins: 10)
		logger.info("Simulation Results:\n\n\(plotHistogram(histogram))")
		#expect(histogram.count == 10, "Should have 10 bins")

		// Each bin should have roughly equal counts (uniform distribution)
		let totalCount = histogram.map { $0.count }.reduce(0, +)
		#expect(totalCount == 1_000, "Total count should equal number of values")

		// Verify bins are ordered
		for i in 0..<(histogram.count - 1) {
			#expect(histogram[i].range.lowerBound < histogram[i + 1].range.lowerBound, "Bins should be ordered")
		}

		// For uniform distribution, each bin should have roughly equal counts
		let expectedCountPerBin = 1_000.0 / 10.0  // 100
		for bin in histogram {
			#expect(Double(bin.count) > 50 && Double(bin.count) < 150, "Bins should be roughly equal for uniform")
		}
	}

	@Test("SimulationResults histogram with different bin counts")
	func simulationResultsHistogramBinCounts() {
		let values = (0..<500).map { _ in distributionNormal(mean: 50.0, stdDev: 10.0) }
		let results = SimulationResults(values: values)

		// Test different bin counts
		let hist5 = results.histogram(bins: 5)
		let hist10 = results.histogram(bins: 10)
		let hist20 = results.histogram(bins: 20)

		#expect(hist5.count == 5)
		#expect(hist10.count == 10)
		#expect(hist20.count == 20)

		// Total counts should always equal number of values
		#expect(hist5.map { $0.count }.reduce(0, +) == 500)
		#expect(hist10.map { $0.count }.reduce(0, +) == 500)
		#expect(hist20.map { $0.count }.reduce(0, +) == 500)
	}

	@Test("SimulationResults confidence intervals")
	func simulationResultsConfidenceIntervals() {
		// Generate normal distribution data
		let values = (0..<5_000).map { _ in distributionNormal(mean: 100.0, stdDev: 15.0) }
		let results = SimulationResults(values: values)

		// Test 95% confidence interval
		let ci95 = results.confidenceInterval(level: 0.95)
		#expect(ci95.lower < results.statistics.mean, "Lower bound < mean")
		#expect(ci95.upper > results.statistics.mean, "Upper bound > mean")

		// Test 99% confidence interval should be wider than 95%
		let ci99 = results.confidenceInterval(level: 0.99)
		let width95 = ci95.upper - ci95.lower
		let width99 = ci99.upper - ci99.lower
		#expect(width99 > width95, "99% CI should be wider than 95% CI")
	}

	@Test("SimulationResults with small dataset")
	func simulationResultsSmallDataset() {
		let values = [1.0, 2.0, 3.0, 4.0, 5.0]
		let results = SimulationResults(values: values)

		#expect(results.values.count == 5)
		#expect(results.statistics.mean == 3.0)
		#expect(results.percentiles.p50 == 3.0)

		// Test probability calculations
		#expect(results.probabilityAbove(3.0) == 0.4, "2 out of 5 values > 3")
		#expect(results.probabilityBelow(3.0) == 0.4, "2 out of 5 values < 3")
	}

	@Test("SimulationResults with single value")
	func simulationResultsSingleValue() {
		let values = [42.0]
		let results = SimulationResults(values: values)

		#expect(results.values.count == 1)
		#expect(results.statistics.mean == 42.0)
		#expect(results.statistics.median == 42.0)
		#expect(results.percentiles.p50 == 42.0)

		// Probability tests
		#expect(results.probabilityAbove(41.0) == 1.0)
		#expect(results.probabilityBelow(43.0) == 1.0)
		#expect(results.probabilityBetween(41.0, 43.0) == 1.0)
	}

	@Test("SimulationResults with large dataset")
	func simulationResultsLargeDataset() {
		// Generate 50,000 samples to test performance
		let values = (0..<50_000).map { _ in distributionNormal(mean: 0.0, stdDev: 1.0) }
		let results = SimulationResults(values: values)

		#expect(results.values.count == 50_000)
		#expect(abs(results.statistics.mean) < 0.05, "Mean should be near 0")
		#expect(abs(results.statistics.stdDev - 1.0) < 0.05, "StdDev should be near 1")
	}

	@Test("SimulationResults probability between - order independence")
	func simulationResultsProbabilityBetweenOrder() {
		let values = (0..<1_000).map { _ in distributionUniform(min: 0.0, max: 100.0) }
		let results = SimulationResults(values: values)

		// Should work regardless of argument order
		let prob1 = results.probabilityBetween(25.0, 75.0)
		let prob2 = results.probabilityBetween(75.0, 25.0)

		#expect(prob1 == prob2, "probabilityBetween should handle reversed arguments")
	}

	@Test("SimulationResults histogram with extreme values")
	func simulationResultsHistogramExtremeValues() {
		// Dataset with outliers
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 100.0, 200.0]
		let results = SimulationResults(values: values)

		let histogram = results.histogram(bins: 5)
		logger.info("Simulation Results - Extreme Values:\n\n\(plotHistogram(histogram))")
		// Verify all values are captured
		let totalCount = histogram.map { $0.count }.reduce(0, +)
		#expect(totalCount == 7, "All values should be in histogram")

		// Most values should be in first bins, outliers in last bins
		#expect(histogram.first!.count >= 5, "Most values in first bins")
	}

	@Test("SimulationResults integration with real simulation")
	func simulationResultsIntegration() {
		// Simulate a simple financial model: Revenue - Costs = Profit
		var profitValues: [Double] = []

		for _ in 0..<10_000 {
			let revenue = distributionNormal(mean: 1_000_000.0, stdDev: 100_000.0)
			let costs = distributionNormal(mean: 700_000.0, stdDev: 50_000.0)
			let profit = revenue - costs
			profitValues.append(profit)
		}

		let results = SimulationResults(values: profitValues)

		// Expected profit ~300,000
		#expect(results.statistics.mean > 250_000 && results.statistics.mean < 350_000)

		// What's the probability of making a loss (profit < 0)?
		let probLoss = results.probabilityBelow(0.0)
		#expect(probLoss < 0.05, "Low probability of loss with these parameters")

		// What's the probability of profit > 400,000?
		let probHighProfit = results.probabilityAbove(400_000.0)
		#expect(probHighProfit > 0.1 && probHighProfit < 0.3, "Reasonable probability of high profit")
	}

	@Test("SimulationResults percentile-based analysis")
	func simulationResultsPercentileAnalysis() {
		let values = (0..<5_000).map { _ in distributionNormal(mean: 100.0, stdDev: 20.0) }
		let results = SimulationResults(values: values)

		// Use percentiles for risk analysis
		let p5 = results.percentiles.p5
		let p95 = results.percentiles.p95

		// 90% of outcomes should be between p5 and p95
		let probInRange = results.probabilityBetween(p5, p95)
		#expect(probInRange > 0.85 && probInRange < 0.95, "~90% should be in [p5, p95]")
	}

	@Test("SimulationResults statistics integration")
	func simulationResultsStatisticsIntegration() {
		// Verify that statistics and percentiles are consistent
		let values = (0..<1_000).map { _ in distributionUniform(min: 50.0, max: 150.0) }
		let results = SimulationResults(values: values)

		// Median from statistics should match p50 from percentiles
		#expect(results.statistics.median == results.percentiles.p50, "Median should match p50")

		// Min/max should match
		#expect(results.statistics.min == results.percentiles.min)
		#expect(results.statistics.max == results.percentiles.max)
	}

	@Test("SimulationResults histogram coverage")
	func simulationResultsHistogramCoverage() {
		let values = (0..<1_000).map { _ in distributionNormal(mean: 50.0, stdDev: 10.0) }
		let results = SimulationResults(values: values)

		let histogram = results.histogram(bins: 20)
		logger.info("Simulation Results - Histogram Coverage Test:\n\n\(plotHistogram(histogram))") 
		// First bin should start at or below min
		#expect(histogram.first!.range.lowerBound <= results.statistics.min)

		// Last bin should end at or above max
		#expect(histogram.last!.range.upperBound >= results.statistics.max)
	}
}
