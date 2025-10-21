//
//  FinancialProjectionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Financial Projection Tests")
struct FinancialProjectionTests {

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

	private func createTestScenario() -> FinancialScenario {
		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(DeterministicDriver(name: "Revenue", value: 1000.0))

		return FinancialScenario(
			name: "Test Scenario",
			description: "A scenario for testing",
			driverOverrides: overrides
		)
	}

	private func createTestIncomeStatement() throws -> IncomeStatement<Double> {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create revenue account
		let revenueSeries = TimeSeries<Double>(
			periods: periods,
			values: [1000.0, 1100.0, 1200.0, 1300.0]
		)
		let revenueAccount = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: revenueSeries
		)

		// Create expense account
		let expenseSeries = TimeSeries<Double>(
			periods: periods,
			values: [600.0, 650.0, 700.0, 750.0]
		)
		let expenseAccount = try Account(
			entity: entity,
			name: "Expenses",
			type: .expense,
			timeSeries: expenseSeries
		)

		return try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenueAccount],
			expenseAccounts: [expenseAccount]
		)
	}

	private func createTestBalanceSheet() throws -> BalanceSheet<Double> {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create asset account
		let assetSeries = TimeSeries<Double>(
			periods: periods,
			values: [5000.0, 5200.0, 5400.0, 5600.0]
		)
		let assetAccount = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: assetSeries
		)

		// Create liability account
		let liabilitySeries = TimeSeries<Double>(
			periods: periods,
			values: [2000.0, 1950.0, 1900.0, 1850.0]
		)
		let liabilityAccount = try Account(
			entity: entity,
			name: "Debt",
			type: .liability,
			timeSeries: liabilitySeries
		)

		// Create equity account
		let equitySeries = TimeSeries<Double>(
			periods: periods,
			values: [3000.0, 3250.0, 3500.0, 3750.0]
		)
		let equityAccount = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: equitySeries
		)

		return try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [assetAccount],
			liabilityAccounts: [liabilityAccount],
			equityAccounts: [equityAccount]
		)
	}

	private func createTestCashFlowStatement() throws -> CashFlowStatement<Double> {
		let entity = createTestEntity()
		let periods = createTestPeriods()

		// Create operating cash flow account
		let operatingSeries = TimeSeries<Double>(
			periods: periods,
			values: [400.0, 450.0, 500.0, 550.0]
		)
		let operatingAccount = try Account(
			entity: entity,
			name: "Operating Cash Flow",
			type: .operating,
			timeSeries: operatingSeries
		)

		// Create investing cash flow account
		let investingSeries = TimeSeries<Double>(
			periods: periods,
			values: [-100.0, -120.0, -140.0, -160.0]
		)
		let investingAccount = try Account(
			entity: entity,
			name: "Investing Cash Flow",
			type: .investing,
			timeSeries: investingSeries
		)

		// Create financing cash flow account
		let financingSeries = TimeSeries<Double>(
			periods: periods,
			values: [-50.0, -50.0, -50.0, -50.0]
		)
		let financingAccount = try Account(
			entity: entity,
			name: "Financing Cash Flow",
			type: .financing,
			timeSeries: financingSeries
		)

		return try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingAccount],
			investingAccounts: [investingAccount],
			financingAccounts: [financingAccount]
		)
	}

	// MARK: - Basic Creation Tests

	@Test("FinancialProjection creation with all statements")
	func financialProjectionBasicCreation() throws {
		let scenario = createTestScenario()
		let incomeStatement = try createTestIncomeStatement()
		let balanceSheet = try createTestBalanceSheet()
		let cashFlowStatement = try createTestCashFlowStatement()

		let projection = FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		#expect(projection.scenario.name == "Test Scenario")
		#expect(projection.incomeStatement.entity.id == "TEST")
		#expect(projection.balanceSheet.entity.id == "TEST")
		#expect(projection.cashFlowStatement.entity.id == "TEST")
	}

	@Test("FinancialProjection stores scenario reference")
	func financialProjectionStoresScenario() throws {
		let scenario = FinancialScenario(
			name: "Optimistic",
			description: "High growth scenario"
		)
		let incomeStatement = try createTestIncomeStatement()
		let balanceSheet = try createTestBalanceSheet()
		let cashFlowStatement = try createTestCashFlowStatement()

		let projection = FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		#expect(projection.scenario.name == "Optimistic")
		#expect(projection.scenario.description == "High growth scenario")
	}

	// MARK: - Statement Access Tests

	@Test("Access income statement metrics")
	func accessIncomeStatementMetrics() throws {
		let scenario = createTestScenario()
		let incomeStatement = try createTestIncomeStatement()
		let balanceSheet = try createTestBalanceSheet()
		let cashFlowStatement = try createTestCashFlowStatement()

		let projection = FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		// Access income statement metrics
		let netIncome = projection.incomeStatement.netIncome
		#expect(!netIncome.periods.isEmpty)
		#expect(netIncome.periods.count == 4)

		// Net income should be revenue - expenses
		// Q1: 1000 - 600 = 400
		let q1 = Period.quarter(year: 2025, quarter: 1)
		#expect(netIncome[q1] == 400.0)
	}

	@Test("Access balance sheet metrics")
	func accessBalanceSheetMetrics() throws {
		let scenario = createTestScenario()
		let incomeStatement = try createTestIncomeStatement()
		let balanceSheet = try createTestBalanceSheet()
		let cashFlowStatement = try createTestCashFlowStatement()

		let projection = FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		// Access balance sheet metrics
		let totalAssets = projection.balanceSheet.totalAssets
		let totalLiabilities = projection.balanceSheet.totalLiabilities
		let totalEquity = projection.balanceSheet.totalEquity

		#expect(!totalAssets.periods.isEmpty)
		#expect(totalAssets.periods.count == 4)

		// Verify accounting equation: Assets = Liabilities + Equity
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let assets = totalAssets[q1]!
		let liabilities = totalLiabilities[q1]!
		let equity = totalEquity[q1]!

		#expect(abs(assets - (liabilities + equity)) < 0.01)
	}

	@Test("Access cash flow statement metrics")
	func accessCashFlowStatementMetrics() throws {
		let scenario = createTestScenario()
		let incomeStatement = try createTestIncomeStatement()
		let balanceSheet = try createTestBalanceSheet()
		let cashFlowStatement = try createTestCashFlowStatement()

		let projection = FinancialProjection(
			scenario: scenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		// Access cash flow metrics
		let operatingCashFlow = projection.cashFlowStatement.operatingCashFlow
		let freeCashFlow = projection.cashFlowStatement.freeCashFlow

		#expect(!operatingCashFlow.periods.isEmpty)
		#expect(!freeCashFlow.periods.isEmpty)

		let q1 = Period.quarter(year: 2025, quarter: 1)
		#expect(operatingCashFlow[q1] == 400.0)

		// FCF = Operating CF + Investing CF = 400 + (-100) = 300
		#expect(freeCashFlow[q1] == 300.0)
	}

	// MARK: - Multiple Projection Comparison Tests

	@Test("Compare projections from different scenarios")
	func compareMultipleProjections() throws {
		// Base case scenario
		let baseScenario = FinancialScenario(
			name: "Base Case",
			description: "Expected case"
		)
		let baseIncome = try createTestIncomeStatement()
		let baseBalance = try createTestBalanceSheet()
		let baseCashFlow = try createTestCashFlowStatement()
		let baseProjection = FinancialProjection(
			scenario: baseScenario,
			incomeStatement: baseIncome,
			balanceSheet: baseBalance,
			cashFlowStatement: baseCashFlow
		)

		// Optimistic scenario (different income statement)
		let optimisticScenario = FinancialScenario(
			name: "Optimistic",
			description: "High growth"
		)

		// Create higher revenue income statement for optimistic case
		let entity = createTestEntity()
		let periods = createTestPeriods()
		let highRevenueSeries = TimeSeries<Double>(
			periods: periods,
			values: [1500.0, 1650.0, 1800.0, 1950.0]
		)
		let highRevenueAccount = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: highRevenueSeries
		)
		let expenseSeries = TimeSeries<Double>(
			periods: periods,
			values: [600.0, 650.0, 700.0, 750.0]
		)
		let expenseAccount = try Account(
			entity: entity,
			name: "Expenses",
			type: .expense,
			timeSeries: expenseSeries
		)
		let optimisticIncome = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [highRevenueAccount],
			expenseAccounts: [expenseAccount]
		)

		let optimisticProjection = FinancialProjection(
			scenario: optimisticScenario,
			incomeStatement: optimisticIncome,
			balanceSheet: baseBalance,
			cashFlowStatement: baseCashFlow
		)

		// Compare scenarios
		#expect(baseProjection.scenario.name != optimisticProjection.scenario.name)

		// Compare net income
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let baseNetIncome = baseProjection.incomeStatement.netIncome[q1]!
		let optimisticNetIncome = optimisticProjection.incomeStatement.netIncome[q1]!

		// Base: 1000 - 600 = 400
		// Optimistic: 1500 - 600 = 900
		#expect(baseNetIncome == 400.0)
		#expect(optimisticNetIncome == 900.0)
		#expect(optimisticNetIncome > baseNetIncome)
	}

	// MARK: - Edge Cases

	@Test("FinancialProjection with empty scenario overrides")
	func projectionWithEmptyScenario() throws {
		let emptyScenario = FinancialScenario(
			name: "Empty",
			description: "No overrides"
		)
		let incomeStatement = try createTestIncomeStatement()
		let balanceSheet = try createTestBalanceSheet()
		let cashFlowStatement = try createTestCashFlowStatement()

		let projection = FinancialProjection(
			scenario: emptyScenario,
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement
		)

		#expect(projection.scenario.driverOverrides.isEmpty)
		#expect(projection.scenario.assumptions.isEmpty)
		#expect(!projection.incomeStatement.periods.isEmpty)
	}

	@Test("Multiple projections maintain independence")
	func multipleProjectionsAreIndependent() throws {
		let scenario1 = FinancialScenario(name: "Scenario 1", description: "First")
		let scenario2 = FinancialScenario(name: "Scenario 2", description: "Second")

		let income1 = try createTestIncomeStatement()
		let income2 = try createTestIncomeStatement()
		let balance = try createTestBalanceSheet()
		let cashFlow = try createTestCashFlowStatement()

		let projection1 = FinancialProjection(
			scenario: scenario1,
			incomeStatement: income1,
			balanceSheet: balance,
			cashFlowStatement: cashFlow
		)

		let projection2 = FinancialProjection(
			scenario: scenario2,
			incomeStatement: income2,
			balanceSheet: balance,
			cashFlowStatement: cashFlow
		)

		// Verify they are independent
		#expect(projection1.scenario.name != projection2.scenario.name)
		#expect(projection1.scenario.description != projection2.scenario.description)
	}
}
