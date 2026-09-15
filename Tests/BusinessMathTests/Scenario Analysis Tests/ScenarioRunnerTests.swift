//
//  ScenarioRunnerTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Testing
import Numerics
import TestSupport  // identical(_:_:)
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
			balanceSheetRole: .otherCurrentAssets,
			timeSeries: values
		)

		// Create equity (also matching the values to balance)
		let equityAccount = try Account(
			entity: entity,
			name: "Retained Earnings",
			balanceSheetRole: .commonStock,
			timeSeries: values
		)

		return try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cashAccount, equityAccount]
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
			let revenueValues = try periods.map { period in
				(try #require(drivers["Revenue"])).sample(for: period)
			}

			let revenueSeries = TimeSeries<Double>(
				periods: periods,
				values: revenueValues
			)

			let revenueAccount = try Account(
				entity: entity,
				name: "Revenue",
				incomeStatementRole: .revenue,
				timeSeries: revenueSeries
			)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount]
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
				cashFlowRole: .otherOperatingActivities,
				timeSeries: cashSeries
			)

			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
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
		let measured0 = try #require(totalRevenue[q1])
		#expect(abs(measured0 - 1000.0) < 1e-2)
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
			let revenueValues = try periods.map { period in
				(try #require(drivers["Revenue"])).sample(for: period)
			}

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: revenueSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount]
			)

			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: revenueSeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", cashFlowRole: .otherOperatingActivities, timeSeries: revenueSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Run both scenarios
		let baseProjection = try runner.run(scenario: baseScenario, entity: entity, periods: periods, builder: builder)
		let optimisticProjection = try runner.run(scenario: optimisticScenario, entity: entity, periods: periods, builder: builder)

		// Verify different scenarios produce different results
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let baseRevenue = try #require(baseProjection.incomeStatement.totalRevenue[q1])
		let optimisticRevenue = try #require(optimisticProjection.incomeStatement.totalRevenue[q1])

		#expect(abs(baseRevenue - 800.0) < 1e-2)
		#expect(abs(optimisticRevenue - 1500.0) < 1e-2)
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
			let revenueValues = try periods.map { try #require(drivers["Revenue"]).sample(for: $0) }
			let costValues = try periods.map { try #require(drivers["Costs"]).sample(for: $0) }

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let costSeries = TimeSeries<Double>(periods: periods, values: costValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: revenueSeries)
			let costAccount = try Account(entity: entity, name: "Costs", incomeStatementRole: .operatingExpenseOther, timeSeries: costSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount, costAccount]
			)

			let equitySeries = revenueSeries - costSeries
			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: equitySeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", cashFlowRole: .otherOperatingActivities, timeSeries: revenueSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Verify both drivers were used
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let revenue = try #require(projection.incomeStatement.totalRevenue[q1])
		let expenses = try #require(projection.incomeStatement.totalExpenses[q1])
		let netIncome = try #require(projection.incomeStatement.netIncome[q1])

		#expect(abs(revenue - 1000.0) < 1e-2)
		#expect(abs(expenses - 600.0) < 1e-2)
		#expect(abs(netIncome - 400.0) < 1e-2)
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
				let revenueValues = try periods.map { try #require(drivers["Revenue"]).sample(for: $0) }
				let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
				let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: revenueSeries)

				let incomeStatement = try IncomeStatement(
					entity: entity,
					periods: periods,
					accounts: [revenueAccount]
				)

				let balanceSheet = try self.createBalancedBalanceSheet(
					entity: entity,
					periods: periods,
					values: revenueSeries
				)

				let cashAccount = try Account(entity: entity, name: "Cash", cashFlowRole: .otherOperatingActivities, timeSeries: revenueSeries)
				let cashFlowStatement = try CashFlowStatement(
					entity: entity,
					periods: periods,
					accounts: [cashAccount]
				)

				return (incomeStatement, balanceSheet, cashFlowStatement)
			}

			let q1 = Period.quarter(year: 2025, quarter: 1)
			revenues.append(try #require(projection.incomeStatement.totalRevenue[q1]))
		}

		// Verify we got different values (probabilistic)
		let allSame = revenues.allSatisfy { $0 == revenues[0] }
		#expect(!allSame)

		// Verify mean is roughly correct (within reasonable bounds)
		let mean = revenues.reduce(0.0, +) / Double(revenues.count)
		#expect(abs(mean - 1000.0) < 200.0)  // Within 200 of expected mean
	}

	/// A seeded simulation reproduces itself, and different seeds diverge.
	///
	/// Until 2026-09-13 `runFinancialSimulation` had no `seed:` and `StatementBuilder` had
	/// nowhere to put a generator, so a builder sampling a probabilistic driver reached for
	/// the global source. About fifteen tests across this suite are bounded rather than
	/// pinned as a result, several at ten, twelve and thirty-two standard errors — bounds
	/// widened until they stopped flaking, which is a coverage ceiling rather than a choice.
	///
	/// The assertions here are `identical` and `!identical` rather than `==` and `!=`:
	/// `==` reports two identical NaN streams as different, and `!=` passes for free if
	/// either stream has gone non-finite, so the divergence check carries an `isFinite`
	/// guard as well.
	@Test("A seeded simulation reproduces exactly, and different seeds diverge")
	func seededSimulationIsReproducible() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()
		let q1 = Period.quarter(year: 2025, quarter: 1)

		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(ProbabilisticDriver<Double>(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		))
		let scenario = FinancialScenario(
			name: "Uncertain Revenue",
			description: "Revenue with uncertainty",
			driverOverrides: overrides
		)

		let builder: ScenarioRunner.SeededStatementBuilder = { drivers, periods, generator in
			let revenue = try periods.map { period -> Double in
				guard let driver = drivers["Revenue"] else { return 0.0 }
				return try driver.sample(for: period, using: &generator)
			}
			let series = TimeSeries<Double>(periods: periods, values: revenue)
			let revenueAccount = try Account(entity: entity, name: "Revenue",
											 incomeStatementRole: .revenue, timeSeries: series)
			let incomeStatement = try IncomeStatement(entity: entity, periods: periods,
													  accounts: [revenueAccount])
			let balanceSheet = try self.createBalancedBalanceSheet(entity: entity,
																   periods: periods, values: series)
			let cashAccount = try Account(entity: entity, name: "Cash",
										  cashFlowRole: .otherOperatingActivities, timeSeries: series)
			let cashFlowStatement = try CashFlowStatement(entity: entity, periods: periods,
														  accounts: [cashAccount])
			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		func revenues(seed: UInt64) throws -> [Double] {
			let simulation = try runFinancialSimulation(
				scenario: scenario, entity: entity, periods: periods,
				iterations: 20, seed: seed, builder: builder
			)
			return try simulation.projections.map {
				try #require($0.incomeStatement.totalRevenue[q1])
			}
		}

		let first = try revenues(seed: 20_260_913)
		let second = try revenues(seed: 20_260_913)
		#expect(first.count == 20)
		#expect(identical(first, second), "the same seed produced a different simulation")

		// One generator threaded across iterations, not a fresh one per iteration: the
		// draws must vary within a run. A fresh generator per iteration would collapse the
		// sample to a single value repeated.
		let distinct = Set(first.map(\.bitPattern))
		#expect(distinct.count > 1,
				"every iteration drew the same value, so the generator is being reseeded")

		let other = try revenues(seed: 99)
		#expect(other.allSatisfy { $0.isFinite }, "a diverging stream must still be finite")
		#expect(!identical(first, other), "two seeds produced the same simulation")
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

			let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: defaultSeries)
			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount]
			)

			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: defaultSeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", cashFlowRole: .otherOperatingActivities, timeSeries: defaultSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
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
			let revenueValues = try periods.map { try #require(drivers["Revenue"]).sample(for: $0) }
			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: revenueSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount]
			)

			let balanceSheet = try self.createBalancedBalanceSheet(
				entity: entity,
				periods: periods,
				values: revenueSeries
			)

			let cashAccount = try Account(entity: entity, name: "Cash", cashFlowRole: .otherOperatingActivities, timeSeries: revenueSeries)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
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

	/// A type nothing in the library could ever throw, so reaching the expectation proves
	/// the builder's own error travelled the whole way out.
	private struct BuilderFault: Error {}

	@Test("Builder errors are propagated by ScenarioRunner")
	func builderErrorPropagation() throws {
		let e = entity()
		let ps = periods()

		let scenario = FinancialScenario(name: "Base", description: "")
		let runner = ScenarioRunner()

		let faultyBuilder: ScenarioRunner.StatementBuilder = { _, _ in
			throw BuilderFault()
		}

		// The claim worth making is that the builder's error arrives *unchanged* — not
		// wrapped, not replaced by a runner-level failure. `(any Error).self` could not
		// tell those apart.
		#expect(throws: BuilderFault.self) {
			_ = try runner.run(scenario: scenario, entity: e, periods: ps, builder: faultyBuilder)
		}
	}
}
