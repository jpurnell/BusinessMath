//
//  SensitivityAnalysisTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Scenario Sensitivity Analysis Tests")
struct ScenarioSensitivityAnalysisTests {

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

	/// Helper to create a simple builder that maps Revenue driver to income statement
	private func createSimpleBuilder(
		entity: Entity,
		periods: [Period]
	) -> ScenarioRunner.StatementBuilder {
		return { drivers, periods in
			// Sample revenue driver
			let revenueValues = periods.map { period in
				drivers["Revenue"]?.sample(for: period) ?? 1000.0
			}

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
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

			// Minimal balance sheet (Assets = Equity)
			let assetAccount = try Account(
				entity: entity,
				name: "Cash",
				balanceSheetRole: .otherCurrentAssets,
				timeSeries: revenueSeries
			)

			let equityAccount = try Account(
				entity: entity,
				name: "Retained Earnings",
				balanceSheetRole: .commonStock,
				timeSeries: revenueSeries
			)

			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: periods,
				accounts: [assetAccount, equityAccount]
			)

			// Minimal cash flow
			let cashAccount = try Account(
				entity: entity,
				name: "Operating Cash",
				cashFlowRole: .otherOperatingActivities,
				timeSeries: revenueSeries
			)

			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}
	}

	// MARK: - One-Way Sensitivity Tests

	@Test("One-way sensitivity analysis with single input")
	func oneWaySensitivitySingleInput() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Base case scenario
		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base revenue scenario",
			driverOverrides: baseOverrides
		)

		let builder = createSimpleBuilder(entity: entity, periods: periods)

		// Run sensitivity analysis varying revenue from 800 to 1200 in 5 steps
		let sensitivity = try runSensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver: "Revenue",
			inputRange: 800.0...1200.0,
			steps: 5,
			builder: builder
		) { projection in
			// Output metric: Q1 net income
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		// Verify sensitivity structure
		#expect(sensitivity.inputDriver == "Revenue")
		#expect(sensitivity.inputValues.count == 5)
		#expect(sensitivity.outputValues.count == 5)

		// Verify input range
		#expect(sensitivity.inputValues.first == 800.0)
		#expect(sensitivity.inputValues.last == 1200.0)

		// Verify output increases with revenue (linear in this simple case)
		#expect(sensitivity.outputValues[0] < sensitivity.outputValues[4])
	}

	@Test("One-way sensitivity with more granular steps")
	func oneWaySensitivityGranular() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createSimpleBuilder(entity: entity, periods: periods)

		// Run with 11 steps (800, 840, 880, ..., 1200)
		let sensitivity = try runSensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver: "Revenue",
			inputRange: 800.0...1200.0,
			steps: 11,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		#expect(sensitivity.inputValues.count == 11)
		#expect(sensitivity.outputValues.count == 11)

		// Verify even spacing
		let step = (1200.0 - 800.0) / 10.0
		for i in 0..<11 {
			let expectedInput = 800.0 + Double(i) * step
			#expect(abs(sensitivity.inputValues[i] - expectedInput) < 0.01)
		}
	}

	@Test("Sensitivity analysis with different output metrics")
	func sensitivityDifferentOutputs() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createSimpleBuilder(entity: entity, periods: periods)

		// Test different output metrics

		// 1. Total revenue across all periods
		let revenueSensitivity = try runSensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver: "Revenue",
			inputRange: 900.0...1100.0,
			steps: 3,
			builder: builder
		) { projection in
			let totalRevenue = projection.incomeStatement.totalRevenue
			return totalRevenue.valuesArray.reduce(0.0, +)
		}

		#expect(revenueSensitivity.inputValues.count == 3)
		#expect(revenueSensitivity.outputValues[0] < revenueSensitivity.outputValues[2])

		// 2. Q4 value specifically
		let q4Sensitivity = try runSensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver: "Revenue",
			inputRange: 900.0...1100.0,
			steps: 3,
			builder: builder
		) { projection in
			let q4 = Period.quarter(year: 2025, quarter: 4)
			return projection.incomeStatement.netIncome[q4]!
		}

		#expect(q4Sensitivity.inputValues.count == 3)
	}

	@Test("Sensitivity analysis finds base case in results")
	func sensitivityIncludesBaseCase() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createSimpleBuilder(entity: entity, periods: periods)

		// Range includes base case value (1000.0)
		let sensitivity = try runSensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver: "Revenue",
			inputRange: 800.0...1200.0,
			steps: 5,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		// Base case (1000.0) should be one of the input values
		let containsBaseCase = sensitivity.inputValues.contains(where: { abs($0 - 1000.0) < 0.01 })
		#expect(containsBaseCase)
	}

	// MARK: - Two-Way Sensitivity Tests

	@Test("Two-way sensitivity analysis with two inputs")
	func twoWaySensitivityBasic() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Base case with revenue and cost drivers
		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		let baseCost = DeterministicDriver(name: "Cost", value: 600.0)

		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)
		baseOverrides["Cost"] = AnyDriver(baseCost)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		// Builder with both revenue and cost
		let builder: ScenarioRunner.StatementBuilder = { drivers, periods in
			let revenueValues = periods.map { drivers["Revenue"]?.sample(for: $0) ?? 1000.0 }
			let costValues = periods.map { drivers["Cost"]?.sample(for: $0) ?? 600.0 }

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let costSeries = TimeSeries<Double>(periods: periods, values: costValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: revenueSeries)
			let costAccount = try Account(entity: entity, name: "Cost", incomeStatementRole: .operatingExpenseOther, timeSeries: costSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount, costAccount]
			)

			// Minimal balance sheet and cash flow
			let netIncome = incomeStatement.netIncome
			let assetAccount = try Account(entity: entity, name: "Cash", balanceSheetRole: .otherCurrentAssets, timeSeries: netIncome)
			let equityAccount = try Account(entity: entity, name: "Equity", balanceSheetRole: .commonStock, timeSeries: netIncome)
			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: periods,
				accounts: [assetAccount, equityAccount]
			)

			let cashAccount = try Account(entity: entity, name: "Cash", cashFlowRole: .otherOperatingActivities, timeSeries: netIncome)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Run two-way sensitivity
		let sensitivity = try runTwoWaySensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver1: "Revenue",
			inputRange1: 900.0...1100.0,
			steps1: 3,
			inputDriver2: "Cost",
			inputRange2: 500.0...700.0,
			steps2: 3,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		// Verify structure
		#expect(sensitivity.inputDriver1 == "Revenue")
		#expect(sensitivity.inputDriver2 == "Cost")
		#expect(sensitivity.inputValues1.count == 3)
		#expect(sensitivity.inputValues2.count == 3)

		// Results should be a 3x3 grid
		#expect(sensitivity.results.count == 3)
		for row in sensitivity.results {
			#expect(row.count == 3)
		}

		// Verify output increases with revenue, decreases with cost
		// Bottom-left (low revenue, high cost) should be lowest
		// Top-right (high revenue, low cost) should be highest
		let bottomLeft = sensitivity.results[0][2]  // revenue[0], cost[2]
		let topRight = sensitivity.results[2][0]    // revenue[2], cost[0]
		#expect(bottomLeft < topRight)
	}

	@Test("Two-way sensitivity creates proper grid")
	func twoWaySensitivityGrid() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		let baseCost = DeterministicDriver(name: "Cost", value: 600.0)

		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)
		baseOverrides["Cost"] = AnyDriver(baseCost)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder: ScenarioRunner.StatementBuilder = { drivers, periods in
			let revenueValues = periods.map { drivers["Revenue"]?.sample(for: $0) ?? 1000.0 }
			let costValues = periods.map { drivers["Cost"]?.sample(for: $0) ?? 600.0 }

			let revenueSeries = TimeSeries<Double>(periods: periods, values: revenueValues)
			let costSeries = TimeSeries<Double>(periods: periods, values: costValues)

			let revenueAccount = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: revenueSeries)
			let costAccount = try Account(entity: entity, name: "Cost", incomeStatementRole: .operatingExpenseOther, timeSeries: costSeries)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount, costAccount]
			)

			let netIncome = incomeStatement.netIncome
			let assetAccount = try Account(entity: entity, name: "Cash", balanceSheetRole: .otherCurrentAssets, timeSeries: netIncome)
			let equityAccount = try Account(entity: entity, name: "Equity", balanceSheetRole: .commonStock, timeSeries: netIncome)
			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: periods,
				accounts: [assetAccount, equityAccount]
			)

			let cashAccount = try Account(entity: entity, name: "Operating Cash", cashFlowRole: .otherOperatingActivities, timeSeries: netIncome)
			let cashFlowStatement = try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [cashAccount]
			)

			return (incomeStatement, balanceSheet, cashFlowStatement)
		}

		// Create 4x5 grid
		let sensitivity = try runTwoWaySensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver1: "Revenue",
			inputRange1: 800.0...1200.0,
			steps1: 4,
			inputDriver2: "Cost",
			inputRange2: 500.0...700.0,
			steps2: 5,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		#expect(sensitivity.results.count == 4)
		for row in sensitivity.results {
			#expect(row.count == 5)
		}
	}

	// MARK: - Edge Cases

	@Test("Sensitivity analysis with single step")
	func sensitivitySingleStep() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createSimpleBuilder(entity: entity, periods: periods)

		// Single step (just evaluate at one point)
		let sensitivity = try runSensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver: "Revenue",
			inputRange: 1000.0...1000.0,
			steps: 1,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		#expect(sensitivity.inputValues.count == 1)
		#expect(sensitivity.outputValues.count == 1)
		#expect(sensitivity.inputValues[0] == 1000.0)
	}

	@Test("Sensitivity analysis with narrow range")
	func sensitivityNarrowRange() throws {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		let baseRevenue = DeterministicDriver(name: "Revenue", value: 1000.0)
		var baseOverrides: [String: AnyDriver<Double>] = [:]
		baseOverrides["Revenue"] = AnyDriver(baseRevenue)

		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Base scenario",
			driverOverrides: baseOverrides
		)

		let builder = createSimpleBuilder(entity: entity, periods: periods)

		// Very narrow range (990 to 1010)
		let sensitivity = try runSensitivity(
			baseCase: baseScenario,
			entity: entity,
			periods: periods,
			inputDriver: "Revenue",
			inputRange: 990.0...1010.0,
			steps: 5,
			builder: builder
		) { projection in
			let q1 = Period.quarter(year: 2025, quarter: 1)
			return projection.incomeStatement.netIncome[q1]!
		}

		#expect(sensitivity.inputValues.count == 5)
		#expect(sensitivity.inputValues.first == 990.0)
		#expect(sensitivity.inputValues.last == 1010.0)

		// Verify range is narrow
		let range = sensitivity.inputValues.last! - sensitivity.inputValues.first!
		#expect(range == 20.0)
	}
}
