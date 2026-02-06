//
//  DriverProjectionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Driver Projection Tests")
struct DriverProjectionTests {

	// MARK: - Deterministic Projection Tests

	@Test("Deterministic projection creates correct time series")
	func deterministicProjection() {
		let driver = DeterministicDriver(name: "Rent", value: 10_000.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let timeSeries = projection.project()

		#expect(timeSeries.periods.count == 4)
		#expect(timeSeries[periods[0]] == 10_000.0)
		#expect(timeSeries[periods[1]] == 10_000.0)
		#expect(timeSeries[periods[2]] == 10_000.0)
		#expect(timeSeries[periods[3]] == 10_000.0)
	}

	@Test("Probabilistic projection creates valid time series")
	func probabilisticProjection() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let timeSeries = projection.project()

		#expect(timeSeries.periods.count == 4)

		// Should have values for all periods
		for period in periods {
			#expect(timeSeries[period] != nil)
		}
	}

	// MARK: - Monte Carlo Projection Tests

	@Test("Monte Carlo projection with deterministic driver")
	func monteCarloProjectionDeterministic() {
		let driver = DeterministicDriver(name: "Rent", value: 10_000.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 1000)

		// Check statistics for each period
		for period in periods {
			let stats = results.statistics[period]!

			// Mean should equal the deterministic value
			#expect(abs(stats.mean - 10_000.0) < 0.01)

			// Std dev should be zero (no variance)
			#expect(stats.stdDev < 0.01)
		}
	}

	@Test("Monte Carlo projection with probabilistic driver")
	func monteCarloProjectionProbabilistic() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)

		// Check statistics for each period
		for period in periods {
			let stats = results.statistics[period]!

			// Mean should be close to 1000
			#expect(abs(stats.mean - 1000.0) < 30.0, "Mean should be close to 1000")

			// Std dev should be close to 100
			#expect(abs(stats.stdDev - 100.0) < 20.0, "StdDev should be close to 100")
		}
	}

	@Test("Monte Carlo projection statistics consistency")
	func monteCarloStatisticsConsistency() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Value", mean: 50.0, stdDev: 10.0)
		let periods = [Period.month(year: 2025, month: 1)]
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)

		let period = periods[0]
		let stats = results.statistics[period]!
		let pctiles = results.percentiles[period]!

		// Basic sanity checks
		#expect(pctiles.p5 < pctiles.p25)
		#expect(pctiles.p25 < pctiles.p50)
		#expect(pctiles.p50 < pctiles.p75)
		#expect(pctiles.p75 < pctiles.p95)

		// Median should be close to mean for normal distribution
		#expect(abs(pctiles.p50 - stats.mean) < 5.0)
	}

	// MARK: - Time Series Extraction Tests

	@Test("Extract expected (mean) time series")
	func extractExpectedTimeSeries() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)
		let expectedSeries = results.expected()

		#expect(expectedSeries.periods.count == 4)

		// All values should be close to 1000
		for period in periods {
			let value = expectedSeries[period]!
			#expect(abs(value - 1000.0) < 50.0)
		}
	}

	@Test("Extract median time series")
	func extractMedianTimeSeries() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)
		let medianSeries = results.median()

		#expect(medianSeries.periods.count == 4)

		// All values should be close to 1000
		for period in periods {
			let value = medianSeries[period]!
			#expect(abs(value - 1000.0) < 50.0)
		}
	}

	@Test("Extract percentile time series")
	func extractPercentileTimeSeries() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)

		let p5Series = results.percentile(0.05)
		let p50Series = results.percentile(0.50)
		let p95Series = results.percentile(0.95)

		// Check ordering: P5 < P50 < P95
		for period in periods {
			let p5 = p5Series[period]!
			let p50 = p50Series[period]!
			let p95 = p95Series[period]!

			#expect(p5 < p50)
			#expect(p50 < p95)
		}
	}

	@Test("Extract standard deviation time series")
	func extractStdDevTimeSeries() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)
		let stdDevSeries = results.standardDeviation()

		#expect(stdDevSeries.periods.count == 4)

		// All std devs should be close to 100
		for period in periods {
			let stdDev = stdDevSeries[period]!
			print("Std Dev: \(stdDev)")
			#expect(abs(stdDev - 100.0) < 20.0)
		}
	}

	// MARK: - Integration Tests

	@Test("Revenue projection with uncertainty")
	func revenueProjectionWithUncertainty() {
		let quantity = ProbabilisticDriver<Double>.normal(name: "Quantity", mean: 1000.0, stdDev: 100.0)
		let price = ProbabilisticDriver<Double>.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)
		let revenue = quantity * price

		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: revenue, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)

		// Expected revenue ≈ 1000 × 100 = 100,000 per quarter
		for period in periods {
			let stats = results.statistics[period]!
			#expect(abs(stats.mean - 100_000.0) < 10_000.0)
		}

		// Extract different confidence levels
		let expected = results.expected()
		let downside = results.percentile(0.05)
		let upside = results.percentile(0.95)

		// Verify ordering
		for period in periods {
			#expect(downside[period]! < expected[period]!)
			#expect(expected[period]! < upside[period]!)
		}
	}

	@Test("Profit projection with full Monte Carlo")
	func profitProjectionMonteCarlo() {
		// Revenue = Quantity × Price (both uncertain)
		let quantity = ProbabilisticDriver<Double>.normal(name: "Quantity", mean: 1000.0, stdDev: 100.0)
		let price = ProbabilisticDriver<Double>.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)
		let revenue = quantity * price

		// Cost = Fixed + (Variable × Units)
		let fixedCost = DeterministicDriver(name: "Fixed", value: 20_000.0)
		let variableCostPerUnit = DeterministicDriver(name: "Variable/Unit", value: 50.0)
		let variableCost = variableCostPerUnit * quantity
		let totalCost = fixedCost + variableCost

		// Profit = Revenue - Cost
		let profit = revenue - totalCost

		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: profit, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 10_000)

		// Expected profit ≈ (1000 × 100) - (20,000 + 50 × 1000) = 100,000 - 70,000 = 30,000
		for period in periods {
			let stats = results.statistics[period]!
			#expect(abs(stats.mean - 30_000.0) < 5000.0, "Expected profit around 30,000")
		}

		// Extract time series
		let expectedProfit = results.expected()
		let worstCase = results.percentile(0.05)
		let bestCase = results.percentile(0.95)

		// Verify we have uncertainty range
		for period in periods {
			#expect(worstCase[period]! < expectedProfit[period]!)
			#expect(expectedProfit[period]! < bestCase[period]!)
		}
	}

	@Test("Multi-period projection maintains independent samples")
	func multiPeriodIndependence() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).months()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 1000)

		// Each period should have similar statistics (independent sampling)
		let firstPeriodMean = results.statistics[periods[0]]!.mean
		let lastPeriodMean = results.statistics[periods[11]]!.mean

		#expect(abs(firstPeriodMean - lastPeriodMean) < 100.0, "Periods should have similar means")
	}
}

@Suite("Driver Projection Additional Tests")
struct DriverProjectionAdditionalTests {

	@Test("Expected time series equals statistics.mean")
	func expectedEqualsMean() {
		let drv = ProbabilisticDriver<Double>.normal(name: "X", mean: 100.0, stdDev: 15.0)
		let periods = Period.year(2025).quarters()
		let proj = DriverProjection(driver: drv, periods: periods)

		let res = proj.projectMonteCarlo(iterations: 5000)
		let expected = res.expected()

		for p in periods {
			let m = res.statistics[p]!.mean
			#expect(abs(expected[p]! - m) < 1e-6)
		}
	}

	@Test("Percentiles are within min/max for all periods")
	func percentilesWithinExtremes() {
		let drv = ProbabilisticDriver<Double>.normal(name: "N", mean: 0.0, stdDev: 1.0)
		let periods = Period.year(2025).months()
		let proj = DriverProjection(driver: drv, periods: periods)
		let res = proj.projectMonteCarlo(iterations: 2000)

		for p in periods {
			let s = res.statistics[p]!
			let q = res.percentiles[p]!
			#expect(s.min <= q.p5 && q.p5 <= q.p25 && q.p25 <= q.p50 && q.p50 <= q.p75 && q.p75 <= q.p95)
			#expect(q.p95 <= s.max)
		}
	}
}
