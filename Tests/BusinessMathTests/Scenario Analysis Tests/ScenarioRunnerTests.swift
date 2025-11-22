//
//  ScenarioRunnerTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Scenario Runner Tests")
struct ScenarioRunnerTests {

	// MARK: - Test Helpers

	private func createTestEntity() -> Entity {
		return Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
	}

	private func createTestPeriods() -> [Period] {
		return [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3),
			Period.quarter(year: 2025, quarter: 4)
		]
	}

	/// Helper to create a balanced balance sheet from a value series
	private func createBalancedBalanceSheet(
		entity: Entity,
		periods: [Period],
		values: TimeSeries<Double>
	) throws -> BalanceSheet<Double> {
		// Create cash asset (matching the values)
		let cashAccount = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: values
		)

		// Create equity (also matching the values to balance)
		let equityAccount = try Account(
			entity: entity,
			name: "Retained Earnings",
			type: .equity,
			timeSeries: values
		)

		return try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cashAccount],
			liabilityAccounts: [],
			equityAccounts: [equityAccount]
		)
	}

	// MARK: - Basic Execution Tests

	@Test("ScenarioRunner executes simple scenario")
	func runSimpleScenario() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create a simple scenario with revenue driver
		let revenueDriver = DeterministicDriver(name: "Revenue", value: 1000.0)
		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(revenueDriver)

		let scenario = FinancialScenario(
			name: "Base Case",
			description: "Simple revenue scenario",
			driverOverrides: overrides
		)

		let runner = ScenarioRunner()

		// Run the scenario with a simple builder
		let projection = try runner.run(
			scenario: scenario,
			entity: entity,
			periods: periods
		) { drivers, periods in
			// Simple builder: revenue becomes revenue account, no expenses
			let revenueValues = periods.map { period in
				drivers["Revenue"]!.sample(for: period)
			}

			let revenueSeries = TimeSeries<Double>(
				periods: periods,
				values: revenueValues
			)

			let revenueAccount = try Account(
				entity: entity,
				name: "Revenue",
				type: .revenue,
				timeSeries: revenueSeries
			)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [revenueAccount],
				expenseAccounts: []
			)

			// Create minimal balance sheet (just cash = equity)
			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: revenueSeries
			)

			// Create minimal cash flow statement
			let cashSeries = revenueSeries
			let cashAccount = try Account(
				entity: entity,
				name: "Operating Cash",
				type: .operating,
				timeSeries: cashSeries
			)

			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [cashAccount],
				investingAccounts: [],
				financingAccounts: []
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Verify the projection was created
		#expect(projection.scenario.name == "Base Case")
		#expect(projection.entity.id == "TEST")
		#expect(projection.periods.count == 4)

		// Verify revenue was set correctly
		let totalRevenue = projection.incomeStatement.totalRevenue
		let q1 = Period.quarter(year: 2025, quarter: 1)
		#expect(totalRevenue[q1] == 1000.0)
	}

	@Test("ScenarioRunner applies driver overrides")
	func runnerAppliesOverrides() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create base case scenario (low revenue)
		let lowRevenueDriver = DeterministicDriver(name: "Revenue", value: 800.0)
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(lowRevenueDriver)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Low revenue",
			driverOverrides: baseOverrides
		)

		// Create optimistic scenario (high revenue)
		let highRevenueDriver = DeterministicDriver(name: "Revenue", value: 1500.0)
		var optimisticOverrides: [String: AnyDriver<Double>] = [:]
		optimisticOverrides["Revenue"] = AnyDriver(highRevenueDriver)

		let optimisticScenario = FinancialScenario(
			name: "Optimistic",
			description: "High revenue",
			driverOverrides: optimisticOverrides
		)

		let runner = ScenarioRunner()

		// Simple builder function
		let builder: ScenarioRunner.StatementBuilder = { drivers, periods in
			let revenueValues = periods.map { period in
				drivers["Revenue"]!.sample(for: period)
			}

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let revenueAccount = try Account(entity: entity, name: "Revenue", type: .revenue, timeSeries: revenueSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [revenueAccount],
				expenseAccounts: []
			)

			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: revenueSeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", type: .operating, timeSeries: revenueSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [cashAccount],
				investingAccounts: [],
				financingAccounts: []
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Run both scenarios
		let baseProjection = try runner.run(scenario: baseScenario, entity: entity, periods: periods, builder: builder)
		let optimisticProjection = try runner.run(scenario: optimisticScenario, entity: entity, periods: periods, builder: builder)

		// Verify different scenarios produce different results
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let baseRevenue = baseProjection.incomeStatement.totalRevenue[q1]!
		let optimisticRevenue = optimisticProjection.incomeStatement.totalRevenue[q1]!

		#expect(baseRevenue == 800.0)
		#expect(optimisticRevenue == 1500.0)
		#expect(optimisticRevenue > baseRevenue)
	}

	@Test("ScenarioRunner handles multiple drivers")
	func runnerHandlesMultipleDrivers() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create scenario with revenue and cost drivers
		let revenueDriver = DeterministicDriver(name: "Revenue", value: 1000.0)
		let costDriver = DeterministicDriver(name: "Costs", value: 600.0)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(revenueDriver)
		overrides["Costs"] = AnyDriver(costDriver)

		let scenario = FinancialScenario(
			name: "Two Driver Scenario",
			description: "Revenue and costs",
			driverOverrides: overrides
		)

		let runner = ScenarioRunner()

		let projection = try runner.run(
			scenario: scenario,
			entity: entity,
			periods: periods
		) { drivers, periods in
			// Build statements from both drivers
			let revenueValues = periods.map { drivers["Revenue"]!.sample(for: $0) }
			let costValues = periods.map { drivers["Costs"]!.sample(for: $0) }

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let costSeries = TimeSeries<Double>(periods: periods, values: costValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", type: .revenue, timeSeries: revenueSeries)
			let costAccount = try Account(entity: entity, name: "Costs", type: .expense, timeSeries: costSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [revenueAccount],
				expenseAccounts: [costAccount]
			)

			let equitySeries = revenueSeries - costSeries
			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: equitySeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", type: .operating, timeSeries: revenueSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [cashAccount],
				investingAccounts: [],
				financingAccounts: []
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Verify both drivers were used
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let revenue = projection.incomeStatement.totalRevenue[q1]!
		let expenses = projection.incomeStatement.totalExpenses[q1]!
		let netIncome = projection.incomeStatement.netIncome[q1]!

		#expect(revenue == 1000.0)
		#expect(expenses == 600.0)
		#expect(netIncome == 400.0)
	}

	@Test("ScenarioRunner with probabilistic drivers samples correctly")
	func runnerWithProbabilisticDrivers() throws {
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

		let runner = ScenarioRunner()

		// Run scenario multiple times to verify probabilistic behavior
		var revenues: [Double] = []
		for _ in 0..<10 {
			let projection = try runner.run(
				scenario: scenario,
				entity: entity,
				periods: periods
			) { drivers, periods in
				let revenueValues = periods.map { drivers["Revenue"]!.sample(for: $0) }
				let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
				let revenueAccount = try Account(entity: entity, name: "Revenue", type: .revenue, timeSeries: revenueSeries)

				let incomeStatement = try IncomeStatement(
					entity: entity,
					periods: periods,
					revenueAccounts: [revenueAccount],
					expenseAccounts: []
				)

				let balanceSheet = try self.createBalancedBalanceSheet(
					entity: entity,
					periods: periods,
					values: revenueSeries
				)

				let cashAccount = try Account(entity: entity, name: "Cash", type: .operating, timeSeries: revenueSeries)
				let cashFlowStatement = try CashFlowStatement(
					entity: entity,
					periods: periods,
					operatingAccounts: [cashAccount],
					investingAccounts: [],
					financingAccounts: []
				)

				return (incomeStatement, balanceSheet, cashFlowStatement)
			}

			let q1 = Period.quarter(year: 2025, quarter: 1)
			revenues.append(projection.incomeStatement.totalRevenue[q1]!)
		}

		// Verify we got different values (probabilistic)
		let allSame = revenues.allSatisfy { $0 == revenues[0] }
		#expect(!allSame)

		// Verify mean is roughly correct (within reasonable bounds)
		let mean = revenues.reduce(0.0, +) / Double(revenues.count)
		#expect(abs(mean - 1000.0) < 200.0)  // Within 200 of expected mean
	}

	@Test("ScenarioRunner with empty scenario uses all provided drivers")
	func runnerWithEmptyScenario() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Empty scenario (no overrides)
		let emptyScenario = FinancialScenario(
			name: "Empty",
			description: "No driver overrides"
		)

		let runner = ScenarioRunner()

		// The builder will need to handle the case where scenario has no drivers
		// For this test, we'll provide drivers directly in the builder
		let projection = try runner.run(
			scenario: emptyScenario,
			entity: entity,
			periods: periods
		) { drivers, periods in
			// Even with empty scenario, builder can create statements
			// Using default/fallback values
			let defaultValues = Array(repeating: 100.0, count: periods.count)
			let defaultSeries = TimeSeries<Double>(periods: periods, values: defaultValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", type: .revenue, timeSeries: defaultSeries)
			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [revenueAccount],
				expenseAccounts: []
			)

			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: defaultSeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", type: .operating, timeSeries: defaultSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [cashAccount],
				investingAccounts: [],
				financingAccounts: []
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		#expect(projection.scenario.name == "Empty")
		#expect(projection.scenario.driverOverrides.isEmpty)
	}

	@Test("ScenarioRunner preserves scenario metadata in projection")
	func runnerPreservesScenarioMetadata() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		var assumptions: [String: String] = [:]
		assumptions["Market Growth"] = "5% annually"
		assumptions["Competition"] = "2 new entrants"

		let revenueDriver = DeterministicDriver(name: "Revenue", value: 1000.0)
		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(revenueDriver)

		let scenario = FinancialScenario(
			name: "Detailed Scenario",
			description: "With full assumptions",
			driverOverrides: overrides,
			assumptions: assumptions
		)

		let runner = ScenarioRunner()

		let projection = try runner.run(
			scenario: scenario,
			entity: entity,
			periods: periods
		) { drivers, periods in
			let revenueValues = periods.map { drivers["Revenue"]!.sample(for: $0) }
			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let revenueAccount = try Account(entity: entity, name: "Revenue", type: .revenue, timeSeries: revenueSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [revenueAccount],
				expenseAccounts: []
			)

			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: revenueSeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", type: .operating, timeSeries: revenueSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [cashAccount],
				investingAccounts: [],
				financingAccounts: []
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Verify all scenario metadata is preserved
		#expect(projection.scenario.name == "Detailed Scenario")
		#expect(projection.scenario.description == "With full assumptions")
		#expect(projection.scenario.assumptions.count == 2)
		#expect(projection.scenario.assumptions["Market Growth"] == "5% annually")
		#expect(projection.scenario.assumptions["Competition"] == "2 new entrants")
		#expect(projection.scenario.overrideCount == 1)
	}
}

@Suite("Scenario Runner Error Propagation Tests")
struct ScenarioRunnerErrorPropagationTests {

	private func entity() -> Entity {
		Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
	}

	private func periods() -> [Period] {
		[ .quarter(year: 2025, quarter: 1) ]
	}

	@Test("Builder errors are propagated by ScenarioRunner")
	func builderErrorPropagation() {
		let e = entity()
		let ps = periods()

		let scenario = FinancialScenario(name: "Base", description: "")
		let runner = ScenarioRunner()

		let faultyBuilder: ScenarioRunner.StatementBuilder = { _, periods in
			// Create a mismatched TimeSeries to provoke an error, or throw directly.
			struct TestError: Error {}
			throw TestError()
		}

		#expect(throws: (any Error).self) {
			_ = try runner.run(scenario: scenario, entity: e, periods: ps, builder: faultyBuilder)
		}
	}
}
