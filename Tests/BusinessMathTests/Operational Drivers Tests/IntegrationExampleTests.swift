//
//  IntegrationExampleTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

/// # Integration Example Tests
///
/// These tests demonstrate how to use the complete SaaS financial model
/// and serve as both verification and documentation.
@Suite("Integration Example Tests")
struct IntegrationExampleTests {

	// MARK: - Basic Model Creation

	@Test("Create SaaS financial model")
	func createModel() {
		let model = SaaSFinancialModel()

		// Verify all drivers are initialized
		#expect(model.users.name.contains("Users"))
		#expect(model.pricePerUser.name.contains("Price"))
		#expect(model.revenue.name.contains("×"))
		#expect(model.profit.name.contains("-") || model.profit.name.contains("+"))
	}

	// MARK: - Single Period Sampling

	@Test("Sample all model components for a single period")
	func sampleSinglePeriod() {
		let model = SaaSFinancialModel()
		let q1 = Period.quarter(year: 2025, quarter: 1)

		// Sample all components (note: each sample is independent random draw)
		let users = model.users.sample(for: q1)
		let pricePerUser = model.pricePerUser.sample(for: q1)
		let revenue = model.revenue.sample(for: q1)
		let fixedCosts = model.fixedCosts.sample(for: q1)
		let variableCosts = model.variableCosts.sample(for: q1)
		let headcount = model.headcount.sample(for: q1)
		let payroll = model.payroll.sample(for: q1)
		let totalCosts = model.totalCosts.sample(for: q1)
		let profit = model.profit.sample(for: q1)

		// Verify reasonable values and constraints
		#expect(users >= 0.0, "Users must be non-negative")
		#expect(users == users.rounded(), "Users should be integer")
		#expect(users >= 800.0 && users <= 1500.0, "Users should be around 1000 ± uncertainty")

		#expect(pricePerUser >= 80.0 && pricePerUser <= 120.0, "Price in triangular range")

		#expect(revenue > 0.0, "Revenue should be positive")
		#expect(revenue >= 64_000.0 && revenue <= 180_000.0, "Revenue = ~1000 users × ~$100 with bounds")

		#expect(fixedCosts >= 49_000.0 && fixedCosts <= 51_000.0, "Fixed costs around $50k")

		#expect(variableCosts > 0.0, "Variable costs should be positive")

		#expect(headcount >= 0.0, "Headcount must be non-negative")
		#expect(headcount == headcount.rounded(), "Headcount should be integer")
		#expect(headcount >= 15.0 && headcount <= 30.0, "Headcount around ~20 (1000/50)")

		#expect(payroll > 0.0, "Payroll should be positive")

		#expect(totalCosts > 0.0, "Total costs should be positive")

		// Profit can be negative or positive depending on the scenario
		// Just verify it's a finite number
		#expect(profit.isFinite, "Profit should be finite")
	}

	// MARK: - Deterministic Projection

	@Test("Project deterministic path over multiple periods")
	func deterministicProjection() {
		let model = SaaSFinancialModel()
		let quarters = Period.year(2025).quarters()

		// Project all components
		let projections = model.projectDeterministic(periods: quarters)

		// Verify all components present
		#expect(projections["users"] != nil)
		#expect(projections["pricePerUser"] != nil)
		#expect(projections["revenue"] != nil)
		#expect(projections["fixedCosts"] != nil)
		#expect(projections["variableCosts"] != nil)
		#expect(projections["headcount"] != nil)
		#expect(projections["payroll"] != nil)
		#expect(projections["totalCosts"] != nil)
		#expect(projections["profit"] != nil)

		// Verify each has correct number of periods
		for (_, timeSeries) in projections {
			#expect(timeSeries.count == 4, "Should have 4 quarters")
		}

		// Verify Q4 seasonal boost in users
		let usersTS = projections["users"]!
		let q1Users = usersTS[quarters[0]]!
		let q4Users = usersTS[quarters[3]]!
		#expect(q4Users > q1Users, "Q4 should have more users (seasonal boost)")

		// Verify growth in fixed costs (inflation)
		let fixedCostsTS = projections["fixedCosts"]!
		let q1Fixed = fixedCostsTS[quarters[0]]!
		let q4Fixed = fixedCostsTS[quarters[3]]!
		#expect(q4Fixed >= q1Fixed, "Fixed costs should grow with inflation")

		// Verify profit varies across quarters
		let profitTS = projections["profit"]!
		let q1Profit = profitTS[quarters[0]]!
		let q4Profit = profitTS[quarters[3]]!
		// Profit will vary based on revenue (seasonal) vs costs (more stable)
		// Just verify both are finite
		#expect(q1Profit.isFinite && q4Profit.isFinite, "Profits should be finite")
	}

	// MARK: - Monte Carlo Simulation

	@Test("Run Monte Carlo simulation")
	func monteCarloSimulation() {
		let model = SaaSFinancialModel()
		let quarters = Period.year(2025).quarters()

		// Run Monte Carlo with 1000 iterations (reduced for test speed)
		let results = model.projectMonteCarlo(periods: quarters, iterations: 1_000)

		// Verify all components present
		#expect(results["profit"] != nil)
		#expect(results["revenue"] != nil)
		#expect(results["totalCosts"] != nil)

		// Analyze Q1 profit
		let q1 = quarters[0]
		let profitResults = results["profit"]!
		let profitStats = profitResults.statistics[q1]!
		let profitPctiles = profitResults.percentiles[q1]!

		// Verify statistics are reasonable
		#expect(profitStats.mean.isFinite, "Mean should be finite")
		#expect(profitStats.stdDev > 0.0, "Should have uncertainty")

		// Verify percentile ordering
		#expect(profitPctiles.p5 < profitPctiles.p25)
		#expect(profitPctiles.p25 < profitPctiles.p50)
		#expect(profitPctiles.p50 < profitPctiles.p75)
		#expect(profitPctiles.p75 < profitPctiles.p95)

		// Verify mean is reasonably close to median (not heavily skewed)
		let meanMedianDiff = abs(profitStats.mean - profitPctiles.p50)
		#expect(meanMedianDiff < profitStats.stdDev * 2.0, "Mean should be reasonably close to median")
	}

	// MARK: - Uncertainty Analysis

	@Test("Analyze profit uncertainty across quarters")
	func profitUncertainty() {
		let model = SaaSFinancialModel()
		let quarters = Period.year(2025).quarters()

		// Run Monte Carlo
		let results = model.projectMonteCarlo(periods: quarters, iterations: 5_000)
		let profitResults = results["profit"]!

		// Compare uncertainty across quarters
		var stdDevs: [Double] = []
		for quarter in quarters {
			let stats = profitResults.statistics[quarter]!
			stdDevs.append(stats.stdDev)
		}

		// Verify all quarters have uncertainty
		for stdDev in stdDevs {
			#expect(stdDev > 0.0, "Each quarter should have uncertainty")
		}

		// Q4 might have higher absolute uncertainty due to scale
		// but coefficient of variation should be similar
	}

	// MARK: - Growth Validation

	@Test("Validate 30% annual user growth")
	func validateUserGrowth() {
		let model = SaaSFinancialModel()

		// Compare Q1 2025 vs Q1 2026
		let q1_2025 = Period.quarter(year: 2025, quarter: 1)
		let q1_2026 = Period.quarter(year: 2026, quarter: 1)

		// Sample multiple times and average (to reduce random variation)
		var users2025: [Double] = []
		var users2026: [Double] = []
		for _ in 0..<100 {
			users2025.append(model.users.sample(for: q1_2025))
			users2026.append(model.users.sample(for: q1_2026))
		}

		let avgUsers2025 = users2025.reduce(0.0, +) / Double(users2025.count)
		let avgUsers2026 = users2026.reduce(0.0, +) / Double(users2026.count)

		// Growth should be approximately 30% (within tolerance due to uncertainty)
		let growthRate = (avgUsers2026 - avgUsers2025) / avgUsers2025
		#expect(growthRate > 0.20, "Growth should be at least 20%")
		#expect(growthRate < 0.40, "Growth should be at most 40%")
	}

	// MARK: - Seasonality Validation

	@Test("Validate Q4 seasonal boost")
	func validateSeasonality() {
		let model = SaaSFinancialModel()

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		// Sample many times to get stable averages
		var q1Users: [Double] = []
		var q4Users: [Double] = []
		for _ in 0..<100 {
			q1Users.append(model.users.sample(for: q1))
			q4Users.append(model.users.sample(for: q4))
		}

		let avgQ1 = q1Users.reduce(0.0, +) / Double(q1Users.count)
		let avgQ4 = q4Users.reduce(0.0, +) / Double(q4Users.count)

		// Q4 should be higher due to 15% seasonal boost
		let boost = (avgQ4 - avgQ1) / avgQ1
		#expect(boost > 0.10, "Q4 should have at least 10% more users")
		#expect(boost < 0.25, "Q4 boost should be at most 25%")
	}

	// MARK: - Constraint Validation

	@Test("Validate users and headcount are positive integers")
	func validateConstraints() {
		let model = SaaSFinancialModel()
		let period = Period.quarter(year: 2025, quarter: 1)

		// Sample 100 times
		for _ in 0..<100 {
			let users = model.users.sample(for: period)
			let headcount = model.headcount.sample(for: period)

			// Must be positive
			#expect(users >= 0.0, "Users must be non-negative")
			#expect(headcount >= 0.0, "Headcount must be non-negative")

			// Must be integers
			#expect(users == users.rounded(), "Users must be integer")
			#expect(headcount == headcount.rounded(), "Headcount must be integer")
		}
	}

	@Test("Validate price per user is in triangular range")
	func validatePriceRange() {
		let model = SaaSFinancialModel()
		let period = Period.quarter(year: 2025, quarter: 1)

		// Sample 100 times
		for _ in 0..<100 {
			let price = model.pricePerUser.sample(for: period)

			// Must be in [$80, $120] range
			#expect(price >= 80.0, "Price should be at least $80")
			#expect(price <= 120.0, "Price should be at most $120")
			#expect(price > 0.0, "Price must be positive")
		}
	}

	// MARK: - Reasonable Value Ranges

	@Test("Verify revenue is in reasonable range")
	func verifyRevenueRange() {
		let model = SaaSFinancialModel()
		let period = Period.quarter(year: 2025, quarter: 1)

		// Sample 100 times and verify all are in reasonable range
		for _ in 0..<100 {
			let revenue = model.revenue.sample(for: period)

			// Revenue = Users (~1000) × Price (~$100) = ~$100k
			// With uncertainty, should be in reasonable range
			#expect(revenue >= 50_000.0, "Revenue should be at least $50k")
			#expect(revenue <= 200_000.0, "Revenue should be at most $200k")
			#expect(revenue > 0.0, "Revenue must be positive")
		}
	}

	@Test("Verify total costs are in reasonable range")
	func verifyTotalCostsRange() {
		let model = SaaSFinancialModel()
		let period = Period.quarter(year: 2025, quarter: 1)

		// Sample 100 times
		for _ in 0..<100 {
			let costs = model.totalCosts.sample(for: period)

			// Fixed ($50k) + Variable (1000 × $20 = $20k) + Payroll (20 × $10k = $200k)
			// = ~$270k total, but with variability
			#expect(costs >= 150_000.0, "Costs should be at least $150k")
			#expect(costs <= 400_000.0, "Costs should be at most $400k")
			#expect(costs > 0.0, "Costs must be positive")
		}
	}

	// MARK: - Real-World Scenario Testing

	@Test("Model statistics are reasonable")
	func modelStatisticsReasonable() {
		let model = SaaSFinancialModel()
		let quarters = Period.year(2025).quarters()

		// Run Monte Carlo
		let results = model.projectMonteCarlo(periods: quarters, iterations: 5_000)
		let profitResults = results["profit"]!

		// Check each quarter produces finite statistics
		for quarter in quarters {
			let stats = profitResults.statistics[quarter]!
			let pctiles = profitResults.percentiles[quarter]!

			// Verify all statistics are finite
			#expect(stats.mean.isFinite, "\(quarter.label) mean should be finite")
			#expect(stats.stdDev >= 0.0, "\(quarter.label) stdDev should be non-negative")
			#expect(pctiles.p5.isFinite && pctiles.p95.isFinite, "Percentiles should be finite")

			// Note: This model may not be profitable on average (high payroll costs)
			// The purpose is to demonstrate the framework, not to be a realistic business model
		}
	}

	@Test("Revenue grows faster than costs")
	func revenueGrowthVsCostGrowth() {
		let model = SaaSFinancialModel()
		let quarters = Period.year(2025).quarters()

		// Run Monte Carlo to get expected values (not random samples)
		let results = model.projectMonteCarlo(periods: quarters, iterations: 5_000)

		let revenueResults = results["revenue"]!
		let costsResults = results["totalCosts"]!

		// Use expected values (mean) for growth comparison
		let q1RevenueMean = revenueResults.statistics[quarters[0]]!.mean
		let q4RevenueMean = revenueResults.statistics[quarters[3]]!.mean
		let q1CostsMean = costsResults.statistics[quarters[0]]!.mean
		let q4CostsMean = costsResults.statistics[quarters[3]]!.mean

		let revenueGrowth = (q4RevenueMean - q1RevenueMean) / q1RevenueMean
		let costGrowth = (q4CostsMean - q1CostsMean) / q1CostsMean

		// Revenue should grow faster than costs (due to Q4 seasonal boost in users)
		// Q4 users get 15% boost, which drives revenue up more than costs
		// (variable costs also increase, but payroll is less sensitive to short-term user changes)
		#expect(revenueGrowth > costGrowth, "Expected revenue growth should outpace expected cost growth")
	}

	@Test("Headcount scales with user base")
	func headcountScaling() {
		let model = SaaSFinancialModel()
		let period = Period.quarter(year: 2025, quarter: 1)

		// Sample multiple times
		var ratios: [Double] = []
		for _ in 0..<100 {
			let users = model.users.sample(for: period)
			let headcount = model.headcount.sample(for: period)

			if headcount > 0 {
				let ratio = users / headcount
				ratios.append(ratio)
			}
		}

		let avgRatio = ratios.reduce(0.0, +) / Double(ratios.count)

		// Should be approximately 50 users per employee (within tolerance)
		#expect(avgRatio > 40.0 && avgRatio < 60.0, "Should have ~50 users per employee")
	}

	// MARK: - Time Series Extraction

	@Test("Extract time series at different confidence levels")
	func extractTimeSeries() {
		let model = SaaSFinancialModel()
		let quarters = Period.year(2025).quarters()

		// Run Monte Carlo
		let results = model.projectMonteCarlo(periods: quarters, iterations: 5_000)
		let profitResults = results["profit"]!

		// Extract different scenarios
		let expectedProfit = profitResults.expected()
		let medianProfit = profitResults.median()
		let p5Profit = profitResults.percentile(0.05)
		let p95Profit = profitResults.percentile(0.95)

		// Verify each has 4 quarters
		#expect(expectedProfit.count == 4)
		#expect(medianProfit.count == 4)
		#expect(p5Profit.count == 4)
		#expect(p95Profit.count == 4)

		// Verify ordering for Q1
		let q1 = quarters[0]
		let q1P5 = p5Profit[q1]!
		let q1Median = medianProfit[q1]!
		let q1Mean = expectedProfit[q1]!
		let q1P95 = p95Profit[q1]!

		#expect(q1P5 < q1Median, "P5 should be less than median")
		#expect(q1Median < q1P95, "Median should be less than P95")
		#expect(abs(q1Mean - q1Median) < q1P95 - q1P5, "Mean should be near median")
	}

	// MARK: - Documentation Example

	@Test("Run complete example from documentation")
	func documentationExample() {
		// Create the model
		let model = SaaSFinancialModel()

		// Project over 4 quarters
		let quarters = Period.year(2025).quarters()

		// Run Monte Carlo simulation (reduced iterations for test speed)
		let profitProjection = DriverProjection(driver: model.profit, periods: quarters)
		let results = profitProjection.projectMonteCarlo(iterations: 1_000)

		// Analyze uncertainty for each quarter
		for quarter in quarters {
			let stats = results.statistics[quarter]!
			let pctiles = results.percentiles[quarter]!

			// Verify we can access all the data
			#expect(stats.mean.isFinite)
			#expect(stats.stdDev >= 0.0)
			#expect(pctiles.p5.isFinite)
			#expect(pctiles.p50.isFinite)
			#expect(pctiles.p95.isFinite)

			// Basic sanity checks
			#expect(pctiles.p5 < pctiles.p95, "P5 should be less than P95")
		}
	}
}
