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

@Suite("SimulationResults Tests", .serialized)
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
//		logger.info("Simulation Results:\n\n\(plotHistogram(histogram))")
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
			let tolerance = 0.5  // Allow 50% deviation
			for bin in histogram {
				let lower = expectedCountPerBin * (1 - tolerance)
				let upper = expectedCountPerBin * (1 + tolerance)
				#expect(Double(bin.count) > lower && Double(bin.count) < upper,
						"Bins should be roughly equal for uniform distribution")
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
		#expect(ci95.low < results.statistics.mean, "Lower bound < mean")
		#expect(ci95.high > results.statistics.mean, "Upper bound > mean")

		// Test 99% confidence interval should be wider than 95%
		let ci99 = results.confidenceInterval(level: 0.99)
		let width95 = ci95.high - ci95.low
		let width99 = ci99.high - ci99.low
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
		#expect((results.probabilityBelow(3.0) * 10).rounded(.up) / 10.0 == 0.4, "2 out of 5 values < 3")
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
//		logger.info("Simulation Results - Extreme Values:\n\n\(plotHistogram(histogram))")
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
//		logger.info("Simulation Results - Histogram Coverage Test:\n\n\(plotHistogram(histogram))")
		// First bin should start at or below min
		#expect(histogram.first!.range.lowerBound <= results.statistics.min)

		// Last bin should end at or above max
		#expect(histogram.last!.range.upperBound >= results.statistics.max)
	}

	@Test("SimulationResults automatic bin calculation")
	func simulationResultsAutomaticBins() {
		// Generate normal distribution data
		let values = (0..<10_000).map { _ in distributionNormal(mean: 100.0, stdDev: 15.0) }
		let results = SimulationResults(values: values)

		// Test automatic bin calculation (no bins parameter)
		let histogramAuto = results.histogram()
//		logger.info("Automatic bins: \(histogramAuto.count) bins for 10,000 samples")

		// Verify histogram is created
		#expect(!histogramAuto.isEmpty, "Should create histogram automatically")

		// Verify all values are captured
		let totalCount = histogramAuto.map { $0.count }.reduce(0, +)
		#expect(totalCount == 10_000, "All values should be in histogram")

		// For 10,000 samples:
		// Sturges: ceil(log2(10000) + 1) = ceil(13.29 + 1) = ceil(14.29) = 15
		// FD depends on IQR, but should be reasonable
		// Bin count should be >= 1 and <= 1000
		#expect(histogramAuto.count >= 1 && histogramAuto.count <= 1000)

		// Should have reasonable resolution (not too few, not too many)
		#expect(histogramAuto.count >= 10 && histogramAuto.count <= 100,
			"For 10k samples, should have 10-100 bins")
	}

	@Test("SimulationResults automatic bins vs manual bins")
	func simulationResultsAutoBinsComparison() {
		let values = (0..<5_000).map { _ in distributionUniform(min: 0.0, max: 100.0) }
		let results = SimulationResults(values: values)

		// Automatic
		let histAuto = results.histogram()

		// Manual with common bin count
		let hist20 = results.histogram(bins: 20)

//		logger.info("Automatic: \(histAuto.count) bins, Manual: \(hist20.count) bins")

		// Both should capture all values
		#expect(histAuto.map { $0.count }.reduce(0, +) == 5_000)
		#expect(hist20.map { $0.count }.reduce(0, +) == 5_000)

		// Automatic should choose a reasonable number
		#expect(histAuto.count > 0)
	}

	@Test("SimulationResults automatic bins with small dataset")
	func simulationResultsAutoBinsSmallDataset() {
		// With small datasets, Sturges' Rule gives small bin counts
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let results = SimulationResults(values: values)

		let histogram = results.histogram()
//		logger.info("Small dataset (n=10): \(histogram.count) bins")

		// For 10 samples: Sturges = ceil(log2(10) + 1) = ceil(4.32) = 5
		// Should have reasonable bin count for small dataset
		#expect(histogram.count >= 1 && histogram.count <= 10)

		// All values captured
		#expect(histogram.map { $0.count }.reduce(0, +) == 10)
	}

	@Test("SimulationResults automatic bins with large dataset")
	func simulationResultsAutoBinsLargeDataset() {
		// Large dataset should get more bins
		let values = (0..<100_000).map { _ in distributionNormal(mean: 50.0, stdDev: 10.0) }
//		logger.debug("Generated \(values.count) values")
		let results = SimulationResults(values: values)
//		logger.debug("\(results.values.count) values recorded")
		let histogram = results.histogram()
		
//		logger.info("Large dataset (n=100k): \(histogram.count) bins")

		// For 100k samples: Sturges = ceil(log2(100000) + 1) = ceil(17.61) = 18
		// FD will likely give more due to large sample size
		#expect(histogram.count >= 15)

		// But should be clamped at max 1000
		#expect(histogram.count <= 1000)

		// All values captured
		#expect(histogram.map { $0.count }.reduce(0, +) == 100_000)
	}

	@Test("SimulationResults automatic bins with outliers")
	func simulationResultsAutoBinsWithOutliers() {
		// Dataset with outliers - FD rule should be robust
		var values: [Double] = (0..<1_000).map { _ in distributionNormal(mean: 50.0, stdDev: 5.0) }
		// Add outliers
		values.append(contentsOf: [1.0, 2.0, 200.0, 250.0])

		let results = SimulationResults(values: values)

		let histogram = results.histogram()
//		logger.info("With outliers (n=1004): \(histogram.count) bins")

		// Should handle outliers gracefully
		#expect(!histogram.isEmpty)

		// All values including outliers should be captured
		#expect(histogram.map { $0.count }.reduce(0, +) == 1_004)

		// Verify outliers are in the bins
		#expect(histogram.first!.range.lowerBound <= 1.0)
		#expect(histogram.last!.range.upperBound >= 250.0)
	}

	@Test("SimulationResults automatic bins with constant values")
	func simulationResultsAutoBinsConstant() {
		// All same values - special case
		let values = Array(repeating: 42.0, count: 100)
		let results = SimulationResults(values: values)

		let histogram = results.histogram()
//		logger.info("Constant values: \(histogram.count) bin(s)")

		// Should create single bin for constant values
		#expect(histogram.count == 1, "Single bin for constant values")
		#expect(histogram[0].count == 100, "All values in single bin")
	}
}

@Suite("SimulationResults – Additional", .serialized)
struct SimulationResultsAdditionalTests {

	@Test("Probability boundary semantics are strict")
	func probabilityBoundaryStrict() {
		let values = [42.0, 42.0, 42.0]
		let results = SimulationResults(values: values)

		// Pin the semantics to avoid ambiguity
		#expect(results.probabilityAbove(42.0) == 0.0, "Above should be strictly greater")
		#expect(results.probabilityBelow(42.0) == 0.0, "Below should be strictly less")
		#expect(results.probabilityBetween(42.0, 42.0) == 0.0, "Strict between equals zero when bounds equal")
	}

	@Test("Histogram bin coverage at exact bounds")
	func histogramBoundsCoverage() {
		let values = [0.0, 1.0, 2.0, 3.0]  // exact integers
		let results = SimulationResults(values: values)
		let hist = results.histogram(bins: 4)

		let total = hist.map { $0.count }.reduce(0, +)
		#expect(total == values.count, "All values should be in bins")

		// The last bin's upper bound should include the max exactly (implementation-dependent)
		#expect(hist.last!.range.upperBound >= results.statistics.max)
		#expect(hist.first!.range.lowerBound <= results.statistics.min)
	}
}
