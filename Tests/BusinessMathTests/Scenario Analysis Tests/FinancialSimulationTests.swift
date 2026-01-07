//
//  FinancialSimulationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Financial Simulation Tests")
struct FinancialSimulationTests {

	// MARK: - Test Helpers

	private func createTestEntity() -> Entity {
		return Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
	}

	private func createTestPeriods() -> [Period] {
		return [Period.quarter(year: 2025, quarter: 1)]
	}

	/// Helper to create a builder with probabilistic revenue
	private func createProbabilisticBuilder(
		entity: Entity,
		periods: [Period]
	) -> ScenarioRunner.StatementBuilder {
		return { drivers, periods in
			let revenueValue = drivers["Revenue"]?.sample(for: periods[0]) ?? 1000.0

			let revenueValues = Array(repeating: revenueValue, count: periods.count)
			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: revenueSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount]
			)

			let assetAccount = try Account(entity: entity, name: "Cash", balanceSheetRole: .otherCurrentAssets, timeSeries: revenueSeries)
			let equityAccount = try Account(entity: entity, name: "Equity", balanceSheetRole: .commonStock, timeSeries: revenueSeries)
			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: periods,
				accounts: [assetAccount, equityAccount]
			)

			let cashAccount = try Account(entity: entity, name: "Cash", cashFlowRole: .otherOperatingActivities, timeSeries: revenueSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}
	}

	// MARK: - Basic Simulation Tests

	@Test("Financial simulation with probabilistic driver")
	func financialSimulationBasic() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create scenario with probabilistic revenue
		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Uncertain Revenue",
			description: "Revenue with uncertainty",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		// Run 100 iterations
		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 100,
			builder: builder
		)

		// Verify we got 100 projections
		#expect(simulation.projections.count == 100)
		#expect(simulation.iterations == 100)
	}

	@Test("Financial simulation produces different results")
	func financialSimulationVariability() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 200.0)  // Large std dev
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "High Uncertainty",
			description: "High revenue uncertainty",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 50,
			builder: builder
		)

		// Extract net income from each projection
		let q1 = periods[0]
		var netIncomes: [Double] = []
		for projection in simulation.projections {
			let netIncome = projection.incomeStatement.netIncome[q1]!
			netIncomes.append(netIncome)
		}

		// Verify they're not all the same (probabilistic)
		let allSame = netIncomes.allSatisfy { $0 == netIncomes[0] }
		#expect(!allSame)

		// Verify mean is roughly around 1000
		let mean = netIncomes.reduce(0.0, +) / Double(netIncomes.count)
		#expect(abs(mean - 1000.0) < 100.0)
	}

	// MARK: - Percentile Tests

	@Test("Financial simulation calculates percentiles")
	func financialSimulationPercentiles() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1000,
			builder: builder
		)

		let q1 = periods[0]

		// Calculate percentiles for net income
		let p10 = simulation.percentile(0.10) { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		let p50 = simulation.percentile(0.50) { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		let p90 = simulation.percentile(0.90) { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		// Percentiles should be ordered
		#expect(p10 < p50)
		#expect(p50 < p90)

		// P50 (median) should be near the mean (1000)
		#expect(abs(p50 - 1000.0) < 50.0)
	}

	@Test("Percentile calculation with edge cases")
	func percentileEdgeCases() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let fixedRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(fixedRevenue)

		let scenario = FinancialScenario(
			name: "Deterministic",
			description: "No uncertainty",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 100,
			builder: builder
		)

		let q1 = periods[0]

		// All percentiles should be the same for deterministic case
		let p10 = simulation.percentile(0.10) { $0.incomeStatement.netIncome[q1]! }
		let p50 = simulation.percentile(0.50) { $0.incomeStatement.netIncome[q1]! }
		let p90 = simulation.percentile(0.90) { $0.incomeStatement.netIncome[q1]! }

		#expect(abs(p10 - p50) < 0.01)
		#expect(abs(p50 - p90) < 0.01)
		#expect(abs(p50 - 1000.0) < 0.01)
	}

	// MARK: - Confidence Interval Tests

	@Test("Financial simulation calculates confidence intervals")
	func financialSimulationConfidenceIntervals() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1000,
			builder: builder
		)

		let q1 = periods[0]

		// Calculate 90% confidence interval for net income
		let ci = simulation.confidenceInterval(0.90) { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		// Lower bound should be less than upper bound
		#expect(ci.lowerBound < ci.upperBound)

		// Mean should be near 1000
		let mean = (ci.lowerBound + ci.upperBound) / 2.0
		#expect(abs(mean - 1000.0) < 100.0)

		// For 90% CI, bounds should be roughly at 5th and 95th percentiles
		let p05 = simulation.percentile(0.05) { $0.incomeStatement.netIncome[q1]! }
		let p95 = simulation.percentile(0.95) { $0.incomeStatement.netIncome[q1]! }

		#expect(abs(ci.lowerBound - p05) < 10.0)
		#expect(abs(ci.upperBound - p95) < 10.0)
	}

	@Test("Confidence intervals of different levels")
	func confidenceIntervalLevels() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1000,
			builder: builder
		)

		let q1 = periods[0]

		// 50% CI should be narrower than 90% CI
		let ci50 = simulation.confidenceInterval(0.50) { $0.incomeStatement.netIncome[q1]! }
		let ci90 = simulation.confidenceInterval(0.90) { $0.incomeStatement.netIncome[q1]! }

		let width50 = ci50.upperBound - ci50.lowerBound
		let width90 = ci90.upperBound - ci90.lowerBound

		#expect(width50 < width90)
	}

	// MARK: - Risk Metrics Tests

	@Test("Financial simulation calculates VaR")
	func financialSimulationVaR() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 200.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1000,
			builder: builder
		)

		let q1 = periods[0]

		// Calculate 95% VaR (value at risk)
		let var95 = simulation.valueAtRisk(0.95) { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		// VaR at 95% should be the 5th percentile
		let p05 = simulation.percentile(0.05) { $0.incomeStatement.netIncome[q1]! }

		#expect(abs(var95 - p05) < 1.0)
	}

	@Test("Financial simulation calculates CVaR")
	func financialSimulationCVaR() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 200.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1000,
			builder: builder
		)

		let q1 = periods[0]

		// Calculate CVaR (conditional value at risk) - expected loss given we're in the worst 5%
		let cvar95 = simulation.conditionalValueAtRisk(0.95) { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		let var95 = simulation.valueAtRisk(0.95) { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		// CVaR should be worse (lower) than VaR
		#expect(cvar95 <= var95)
	}

	@Test("Financial simulation calculates probability of loss")
	func financialSimulationProbabilityOfLoss() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Mean of 100 with std dev of 50 means some chance of negative values
		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(100.0, 50.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1000,
			builder: builder
		)

		let q1 = periods[0]

		// Calculate probability of negative net income
		let probLoss = simulation.probabilityOfLoss { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		// Should be between 0 and 1
		#expect(probLoss >= 0.0)
		#expect(probLoss <= 1.0)

		// With mean=100, stddev=50, probability of <0 should be around 2-3% (roughly 2 std devs below mean)
		#expect(probLoss > 0.0)
		#expect(probLoss < 0.10)  // Should be less than 10%
	}

	@Test("Probability of loss with safe scenario")
	func probabilityOfLossWithSafeScenario() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// High mean, low variance - virtually no chance of loss
		let safeRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(10000.0, 10.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(safeRevenue)

		let scenario = FinancialScenario(
			name: "Safe",
			description: "Safe scenario",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1000,
			builder: builder
		)

		let q1 = periods[0]

		let probLoss = simulation.probabilityOfLoss { projection in
			projection.incomeStatement.netIncome[q1]!
		}

		// Should be essentially zero
		#expect(probLoss == 0.0)
	}

	// MARK: - Edge Cases

	@Test("Financial simulation with single iteration")
	func financialSimulationSingleIteration() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 1,
			builder: builder
		)

		#expect(simulation.projections.count == 1)
		#expect(simulation.iterations == 1)

		let q1 = periods[0]

		// Percentile should return the single value
		let p50 = simulation.percentile(0.50) { $0.incomeStatement.netIncome[q1]! }
		#expect(p50 > 0.0)
	}

	@Test("Financial simulation with many iterations")
	func financialSimulationManyIterations() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let uncertainRevenue = ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(uncertainRevenue)

		let scenario = FinancialScenario(
			name: "Test",
			description: "Test",
			driverOverrides: overrides
		)

		let builder = createProbabilisticBuilder(entity: entity, periods: periods)

		// Run 10,000 iterations (should still complete quickly)
		let simulation = try runFinancialSimulation(
			scenario: scenario,
			entity: entity,
			periods: periods,
			iterations: 10000,
			builder: builder
		)

		#expect(simulation.projections.count == 10000)

		let q1 = periods[0]

		// With many iterations, statistics should converge
		let mean = simulation.mean { $0.incomeStatement.netIncome[q1]! }
		#expect(abs(mean - 1000.0) < 20.0)  // Should be very close to true mean
	}
}

struct AdditionalFinancialSimulationTests {
		// MARK: - Helpers
	private func entity() -> Entity {
		Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
	}
	private func singlePeriod() -> [Period] {
		[ .quarter(year: 2025, quarter: 1) ]
	}
	private func builder(entity: Entity) -> ScenarioRunner.StatementBuilder {
		return { drivers, periods in
				// Use "Revenue" driver; default 1000.0 if missing
			let value = drivers["Revenue"]?.sample(for: periods[0]) ?? 1000.0
			let series = TimeSeries<Double>(periods: periods, values: Array(repeating: value, count: periods.count))
			let revenue = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: series)
			let income = try IncomeStatement(entity: entity, periods: periods, accounts: [revenue])
			let asset = try Account(entity: entity, name: "Cash", balanceSheetRole: .otherCurrentAssets, timeSeries: series)
			let equity = try Account(entity: entity, name: "Equity", balanceSheetRole: .commonStock, timeSeries: series)
			let bs = try BalanceSheet(entity: entity, periods: periods, accounts: [asset, equity])
			let op = try Account(entity: entity, name: "Operating Cash", cashFlowRole: .otherOperatingActivities, timeSeries: series)
			let cfs = try CashFlowStatement(entity: entity, periods: periods, accounts: [op])
			return (income, bs, cfs)
		}
	}
	@Test("Percentiles are monotonic (Normal(1000, 100))")
		func percentileMonotonicity() throws {
			let e = entity()
			let ps = singlePeriod()

			var overrides: [String: AnyDriver<Double>] = [:]
			overrides["Revenue"] = AnyDriver(ProbabilisticDriver(name: "Revenue",
																 distribution: DistributionNormal(1000.0, 100.0)))
			let scenario = FinancialScenario(name: "P", description: "", driverOverrides: overrides)
			let sim = try runFinancialSimulation(scenario: scenario, entity: e, periods: ps, iterations: 2000, builder: builder(entity: e))

			let q = ps[0]
			let quantiles: [Double] = [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]
			var last: Double? = nil
			for quantile in quantiles {
				let value = sim.percentile(quantile) { $0.incomeStatement.netIncome[q]! }
				if let prev = last {
					#expect(value >= prev)
				}
				last = value
			}
		}
	@Test("Sample mean and stddev reasonable for Normal(1000, 100)")
		func sampleMomentsNormal() throws {
			let e = entity()
			let ps = singlePeriod()

			var overrides: [String: AnyDriver<Double>] = [:]
			overrides["Revenue"] = AnyDriver(ProbabilisticDriver(name: "Revenue",
																 distribution: DistributionNormal(1000.0, 100.0)))
			let scenario = FinancialScenario(name: "P", description: "", driverOverrides: overrides)

			let n = 5000
			let sim = try runFinancialSimulation(scenario: scenario, entity: e, periods: ps, iterations: n, builder: builder(entity: e))
			let p = ps[0]
			let values = sim.projections.map { $0.incomeStatement.netIncome[p]! }

			let sd = stdDev(values)

			// 3-sigma/sqrt(n) bound for mean
			let se = 100.0 / pow(Double(n), 0.5)
			#expect(abs(mean(values) - 1000.0) < 3.0 * se)
			// Stddev within ~15%
			#expect(abs(sd - 100.0) < 15.0)
		}
	@Test("CVaR monotonic across confidence levels")
		func cvarMonotonicity() throws {
			let e = entity()
			let ps = singlePeriod()

			var overrides: [String: AnyDriver<Double>] = [:]
			overrides["Revenue"] = AnyDriver(ProbabilisticDriver(name: "Revenue",
																 distribution: DistributionNormal(1000.0, 200.0)))
			let scenario = FinancialScenario(name: "P", description: "", driverOverrides: overrides)

			let sim = try runFinancialSimulation(scenario: scenario, entity: e, periods: ps, iterations: 4000, builder: builder(entity: e))
			let p = ps[0]

			let cvar90 = sim.conditionalValueAtRisk(0.90) { $0.incomeStatement.netIncome[p]! }
			let cvar95 = sim.conditionalValueAtRisk(0.95) { $0.incomeStatement.netIncome[p]! }

			// With lower tail on income, a higher alpha (95%) uses a smaller, more severe tail; CVaR95 <= CVaR90
			#expect(cvar95 <= cvar90)
		}
}
