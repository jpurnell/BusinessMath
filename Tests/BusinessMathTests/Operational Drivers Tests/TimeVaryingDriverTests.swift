//
//  TimeVaryingDriverTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Time-Varying Driver Tests")
struct TimeVaryingDriverTests {

	// MARK: - Basic Time-Varying Behavior

	@Test("TimeVaryingDriver produces different values for different periods")
	func differentPeriodsProduceDifferentValues() {
		let driver = TimeVaryingDriver<Double>(name: "Seasonal") { period in
			// Q4 gets boost
			let multiplier = period.quarter == 4 ? 1.5 : 1.0
			return 100.0 * multiplier
		}

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		#expect(driver.sample(for: q1) == 100.0)
		#expect(driver.sample(for: q4) == 150.0)
	}

	@Test("TimeVaryingDriver with deterministic time variation")
	func deterministicTimeVariation() {
		// Linear growth: 1000 in 2025, 1030 in 2026, etc.
		let driver = TimeVaryingDriver<Double>(name: "Growing") { period in
			let yearsSince2025 = Double(period.year - 2025)
			return 1000.0 * pow(1.03, yearsSince2025)
		}

		let y2025 = Period.year(2025)
		let y2026 = Period.year(2026)
		let y2027 = Period.year(2027)

		#expect(abs(driver.sample(for: y2025) - 1000.0) < 0.1)
		#expect(abs(driver.sample(for: y2026) - 1030.0) < 0.1)
		#expect(abs(driver.sample(for: y2027) - 1060.9) < 0.1)
	}

	@Test("TimeVaryingDriver with probabilistic time variation")
	func probabilisticTimeVariation() {
		let driver = TimeVaryingDriver<Double>(name: "Seasonal with Uncertainty") { period in
			let baseMean = 100.0
			let seasonalMultiplier = period.quarter == 4 ? 1.3 : 1.0
			let mean = baseMean * seasonalMultiplier

			return ProbabilisticDriver<Double>.normal(name: "Value", mean: mean, stdDev: 10.0)
				.sample(for: period)
		}

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		// Sample multiple times to verify randomness
		var q1Samples: [Double] = []
		var q4Samples: [Double] = []

		for _ in 0..<100 {
			q1Samples.append(driver.sample(for: q1))
			q4Samples.append(driver.sample(for: q4))
		}

		let q1Mean = q1Samples.reduce(0.0, +) / Double(q1Samples.count)
		let q4Mean = q4Samples.reduce(0.0, +) / Double(q4Samples.count)

		// Q1 mean should be around 100
		#expect(abs(q1Mean - 100.0) < 10.0)

		// Q4 mean should be around 130
		#expect(abs(q4Mean - 130.0) < 10.0)

		// Q4 should be higher than Q1
		#expect(q4Mean > q1Mean)
	}

	// MARK: - Factory Methods

	@Test("withGrowth creates driver with linear growth")
	func withGrowthLinear() {
		let driver = TimeVaryingDriver.withGrowth(
			name: "Growing Costs",
			baseValue: 1000.0,
			annualGrowthRate: 0.05,  // 5% per year
			baseYear: 2025
		)

		let y2025 = Period.year(2025)
		let y2026 = Period.year(2026)
		let y2027 = Period.year(2027)

		#expect(abs(driver.sample(for: y2025) - 1000.0) < 0.1)
		#expect(abs(driver.sample(for: y2026) - 1050.0) < 0.1)
		#expect(abs(driver.sample(for: y2027) - 1102.5) < 0.1)
	}

	@Test("withGrowth with uncertainty adds probabilistic variation")
	func withGrowthWithUncertainty() {
		let driver = TimeVaryingDriver.withGrowth(
			name: "Growing Costs",
			baseValue: 1000.0,
			annualGrowthRate: 0.05,
			baseYear: 2025,
			stdDevPercentage: 0.10  // 10% uncertainty
		)

		let y2026 = Period.year(2026)

		var samples: [Double] = []
		for _ in 0..<1000 {
			samples.append(driver.sample(for: y2026))
		}

		let mean = samples.reduce(0.0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(samples.count)
		let stdDev = sqrt(variance)

		// Mean should be around 1050
		#expect(abs(mean - 1050.0) < 20.0)

		// StdDev should be around 10% of 1050 = 105
		#expect(abs(stdDev - 105.0) < 30.0)
	}

	@Test("withSeasonality creates quarterly patterns")
	func withSeasonality() {
		let driver = TimeVaryingDriver.withSeasonality(
			name: "Seasonal Revenue",
			baseValue: 100.0,
			q1Multiplier: 0.8,
			q2Multiplier: 1.0,
			q3Multiplier: 1.0,
			q4Multiplier: 1.4
		)

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q2 = Period.quarter(year: 2025, quarter: 2)
		let q3 = Period.quarter(year: 2025, quarter: 3)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		#expect(abs(driver.sample(for: q1) - 80.0) < 0.1)
		#expect(abs(driver.sample(for: q2) - 100.0) < 0.1)
		#expect(abs(driver.sample(for: q3) - 100.0) < 0.1)
		#expect(abs(driver.sample(for: q4) - 140.0) < 0.1)
	}

	@Test("withSeasonality with uncertainty")
	func withSeasonalityWithUncertainty() {
		let driver = TimeVaryingDriver.withSeasonality(
			name: "Seasonal Revenue",
			baseValue: 100.0,
			q1Multiplier: 0.8,
			q2Multiplier: 1.0,
			q3Multiplier: 1.0,
			q4Multiplier: 1.4,
			stdDevPercentage: 0.10
		)

		let q4 = Period.quarter(year: 2025, quarter: 4)

		var samples: [Double] = []
		for _ in 0..<1000 {
			samples.append(driver.sample(for: q4))
		}

		let mean = samples.reduce(0.0, +) / Double(samples.count)

		// Mean should be around 140 (100 * 1.4)
		#expect(abs(mean - 140.0) < 10.0)
	}

	// MARK: - Integration with Other Drivers

	@Test("TimeVaryingDriver can be combined with operators")
	func combineWithOperators() {
		let seasonalQuantity = TimeVaryingDriver<Double>(name: "Seasonal Quantity") { period in
			let base = 1000.0
			let multiplier = period.quarter == 4 ? 1.3 : 1.0
			return base * multiplier
		}

		let fixedPrice = DeterministicDriver(name: "Price", value: 100.0)

		let revenue = seasonalQuantity * fixedPrice

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		// Q1: 1000 * 100 = 100,000
		#expect(abs(revenue.sample(for: q1) - 100_000.0) < 0.1)

		// Q4: 1300 * 100 = 130,000
		#expect(abs(revenue.sample(for: q4) - 130_000.0) < 0.1)
	}

	// MARK: - Projection Tests

	@Test("TimeVaryingDriver projection shows different values per period")
	func projectionShowsVariation() {
		let driver = TimeVaryingDriver<Double>(name: "Seasonal") { period in
			let multiplier = period.quarter == 4 ? 1.5 : 1.0
			return 100.0 * multiplier
		}

		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let timeSeries = projection.project()

		#expect(timeSeries[periods[0]]! == 100.0)  // Q1
		#expect(timeSeries[periods[1]]! == 100.0)  // Q2
		#expect(timeSeries[periods[2]]! == 100.0)  // Q3
		#expect(timeSeries[periods[3]]! == 150.0)  // Q4
	}

	@Test("TimeVaryingDriver Monte Carlo shows period-specific statistics")
	func monteCarloShowsPeriodSpecificStats() {
		// Q1 has low uncertainty, Q4 has high uncertainty
		let driver = TimeVaryingDriver<Double>(name: "Varying Uncertainty") { period in
			let mean = 100.0
			let stdDev = period.quarter == 4 ? 30.0 : 10.0

			return ProbabilisticDriver<Double>.normal(name: "Value", mean: mean, stdDev: stdDev)
				.sample(for: period)
		}

		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)

		let results = projection.projectMonteCarlo(iterations: 5000)

		let q1Stats = results.statistics[periods[0]]!
		let q4Stats = results.statistics[periods[3]]!

		// Both should have similar means
		#expect(abs(q1Stats.mean - 100.0) < 5.0)
		#expect(abs(q4Stats.mean - 100.0) < 5.0)

		// Q4 should have much higher std dev
		#expect(abs(q1Stats.stdDev - 10.0) < 3.0)
		#expect(abs(q4Stats.stdDev - 30.0) < 5.0)

		// Q4 std dev should be roughly 3x Q1
		#expect(q4Stats.stdDev > q1Stats.stdDev * 2.0)
	}

	// MARK: - Real-World Scenarios

	@Test("Product lifecycle model")
	func productLifecycleModel() {
		// Product lifecycle based on calendar year/quarter
		let driver = TimeVaryingDriver<Double>(name: "Product Revenue") { period in
			// Calculate quarters since Q1 2025 (launch date)
			let quartersSinceLaunch = (period.year - 2025) * 4 + period.quarter

			let mean: Double
			if quartersSinceLaunch <= 2 {
				// Launch phase: low revenue (Q1-Q2 2025)
				mean = 50_000.0
			} else if quartersSinceLaunch <= 6 {
				// Growth phase (Q3 2025 - Q2 2026)
				mean = 50_000.0 + Double(quartersSinceLaunch - 2) * 25_000.0
			} else {
				// Mature phase (Q3 2026+)
				mean = 150_000.0
			}

			return mean
		}

		let q1_2025 = Period.quarter(year: 2025, quarter: 1)  // Quarter 1 since launch
		let q3_2025 = Period.quarter(year: 2025, quarter: 3)  // Quarter 3 since launch
		let q3_2026 = Period.quarter(year: 2026, quarter: 3)  // Quarter 7 since launch

		#expect(driver.sample(for: q1_2025) == 50_000.0)  // Launch: 50k
		#expect(driver.sample(for: q3_2025) == 75_000.0)  // Growth: 50k + (3-2)*25k = 75k
		#expect(driver.sample(for: q3_2026) == 150_000.0)  // Mature: 150k
	}

	@Test("Inflation-adjusted costs")
	func inflationAdjustedCosts() {
		let driver = TimeVaryingDriver.withGrowth(
			name: "Operating Costs",
			baseValue: 50_000.0,
			annualGrowthRate: 0.03,  // 3% inflation
			baseYear: 2025
		)

		let y2025 = Period.year(2025)
		let y2030 = Period.year(2030)

		let cost2025 = driver.sample(for: y2025)
		let cost2030 = driver.sample(for: y2030)

		// After 5 years at 3%: 50,000 * 1.03^5 ≈ 57,964
		#expect(abs(cost2025 - 50_000.0) < 0.1)
		#expect(abs(cost2030 - 57_964.0) < 10.0)

		// Cost should increase
		#expect(cost2030 > cost2025)
	}
}

@Suite("Time-Varying Driver Additional Tests")
struct TimeVaryingDriverAdditionalTests {

	@Test("Seasonality repeats year-over-year")
	func seasonalityRepeats() {
		let drv = TimeVaryingDriver.withSeasonality(
			name: "Seasonal",
			baseValue: 100.0,
			q1Multiplier: 0.9,
			q2Multiplier: 1.0,
			q3Multiplier: 1.1,
			q4Multiplier: 1.2
		)

		let q1_2025 = Period.quarter(year: 2025, quarter: 1)
		let q1_2026 = Period.quarter(year: 2026, quarter: 1)
		#expect(abs(drv.sample(for: q1_2025) - drv.sample(for: q1_2026)) < 1e-9)
	}
}
