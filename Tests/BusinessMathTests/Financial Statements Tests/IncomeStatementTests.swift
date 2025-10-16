//
//  IncomeStatementTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Income Statement Tests")
struct IncomeStatementTests {

	// MARK: - Test Helpers

	func makeEntity() -> Entity {
		return Entity(
			id: "TEST",
			primaryType: .internal,
			name: "Test Company"
		)
	}

	func makePeriods() -> [Period] {
		return [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]
	}

	func makeRevenueAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [100_000, 110_000, 120_000, 130_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		return try Account(
			entity: entity,
			name: "Product Revenue",
			type: .revenue,
			timeSeries: timeSeries
		)
	}

	func makeCogsAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [40_000, 44_000, 48_000, 52_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "COGS"
		return try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	func makeOpexAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [20_000, 22_000, 24_000, 26_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "Operating"
		return try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	func makeDAAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [5_000, 5_000, 5_000, 5_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "Operating"
		metadata.tags = ["D&A"]
		return try Account(
			entity: entity,
			name: "Depreciation & Amortization",
			type: .expense,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	// MARK: - Basic Creation

	@Test("Income statement can be created with revenue and expense accounts")
	func incomeStatementCreation() throws {
		let entity = makeEntity()
		let periods = makePeriods()
		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		#expect(incomeStmt.entity == entity)
		#expect(incomeStmt.periods.count == 4)
		#expect(incomeStmt.revenueAccounts.count == 1)
		#expect(incomeStmt.expenseAccounts.count == 1)
	}

	@Test("Income statement can be created with multiple accounts")
	func incomeStatementMultipleAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue1 = try makeRevenueAccount(entity: entity, periods: periods)

		let values2: [Double] = [50_000, 55_000, 60_000, 65_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let revenue2 = try Account(
			entity: entity,
			name: "Service Revenue",
			type: .revenue,
			timeSeries: timeSeries2
		)

		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue1, revenue2],
			expenseAccounts: [cogs, opex]
		)

		#expect(incomeStmt.revenueAccounts.count == 2)
		#expect(incomeStmt.expenseAccounts.count == 2)
	}

	// MARK: - Validation Tests

	@Test("Income statement creation fails with entity mismatch")
	func incomeStatementEntityMismatch() throws {
		let entity1 = makeEntity()
		let entity2 = Entity(id: "OTHER", primaryType: .internal, name: "Other Company")
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity1, periods: periods)
		let cogs = try makeCogsAccount(entity: entity2, periods: periods)

		#expect(throws: IncomeStatementError.self) {
			_ = try IncomeStatement(
				entity: entity1,
				periods: periods,
				revenueAccounts: [revenue],
				expenseAccounts: [cogs]
			)
		}
	}

	@Test("Income statement creation fails with wrong account type in revenue")
	func incomeStatementWrongRevenueType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let expenseAccount = try makeCogsAccount(entity: entity, periods: periods)

		#expect(throws: IncomeStatementError.self) {
			_ = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [expenseAccount], // Wrong type!
				expenseAccounts: []
			)
		}
	}

	@Test("Income statement creation fails with wrong account type in expenses")
	func incomeStatementWrongExpenseType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenueAccount = try makeRevenueAccount(entity: entity, periods: periods)

		#expect(throws: IncomeStatementError.self) {
			_ = try IncomeStatement(
				entity: entity,
				periods: periods,
				revenueAccounts: [],
				expenseAccounts: [revenueAccount] // Wrong type!
			)
		}
	}

	// MARK: - Aggregated Totals

	@Test("Total revenue is sum of all revenue accounts")
	func totalRevenue() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue1 = try makeRevenueAccount(entity: entity, periods: periods)

		let values2: [Double] = [50_000, 55_000, 60_000, 65_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let revenue2 = try Account(
			entity: entity,
			name: "Service Revenue",
			type: .revenue,
			timeSeries: timeSeries2
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue1, revenue2],
			expenseAccounts: []
		)

		let total = incomeStmt.totalRevenue
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == 150_000) // 100k + 50k
	}

	@Test("Total expenses is sum of all expense accounts")
	func totalExpenses() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [],
			expenseAccounts: [cogs, opex]
		)

		let total = incomeStmt.totalExpenses
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == 60_000) // 40k + 20k
	}

	@Test("Net income is revenue minus expenses")
	func netIncome() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		let netIncome = incomeStmt.netIncome
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Revenue: 100k, Expenses: 40k + 20k = 60k, Net: 40k
		#expect(netIncome[q1] == 40_000)
	}

	// MARK: - Profitability Metrics

	@Test("Gross profit is revenue minus COGS")
	func grossProfit() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		let grossProfit = incomeStmt.grossProfit
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Revenue: 100k, COGS: 40k, Gross Profit: 60k
		#expect(grossProfit[q1] == 60_000)
	}

	@Test("Operating income is gross profit minus operating expenses")
	func operatingIncome() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		let operatingIncome = incomeStmt.operatingIncome
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Revenue: 100k, COGS: 40k, OpEx: 20k, Operating Income: 40k
		#expect(operatingIncome[q1] == 40_000)
	}

	@Test("EBITDA adds back depreciation and amortization")
	func ebitda() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)
		let da = try makeDAAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, da]
		)

		let ebitda = incomeStmt.ebitda
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Operating Income: 35k (100k - 40k - 20k - 5k)
		// EBITDA: 40k (35k + 5k D&A)
		#expect(ebitda[q1] == 40_000)
	}

	// MARK: - Margin Ratios

	@Test("Gross margin is gross profit divided by revenue")
	func grossMargin() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		let grossMargin = incomeStmt.grossMargin
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Gross Profit: 60k, Revenue: 100k, Margin: 0.6
		#expect(grossMargin[q1] == 0.6)
	}

	@Test("Operating margin is operating income divided by revenue")
	func operatingMargin() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		let operatingMargin = incomeStmt.operatingMargin
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Operating Income: 40k, Revenue: 100k, Margin: 0.4
		#expect(operatingMargin[q1] == 0.4)
	}

	@Test("Net margin is net income divided by revenue")
	func netMargin() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		let netMargin = incomeStmt.netMargin
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Net Income: 40k, Revenue: 100k, Margin: 0.4
		#expect(netMargin[q1] == 0.4)
	}

	@Test("EBITDA margin is EBITDA divided by revenue")
	func ebitdaMargin() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)
		let da = try makeDAAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, da]
		)

		let ebitdaMargin = incomeStmt.ebitdaMargin
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// EBITDA: 40k, Revenue: 100k, Margin: 0.4
		#expect(ebitdaMargin[q1] == 0.4)
	}

	// MARK: - Empty Account Handling

	@Test("Income statement handles empty revenue accounts")
	func emptyRevenueAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()
		let cogs = try makeCogsAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [],
			expenseAccounts: [cogs]
		)

		let totalRevenue = incomeStmt.totalRevenue
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(totalRevenue[q1] == 0)
	}

	@Test("Income statement handles empty expense accounts")
	func emptyExpenseAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()
		let revenue = try makeRevenueAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: []
		)

		let totalExpenses = incomeStmt.totalExpenses
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(totalExpenses[q1] == 0)
	}

	// MARK: - Materialization

	@Test("Materialized income statement has all metrics pre-computed")
	func materialization() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)
		let opex = try makeOpexAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		let materialized = incomeStmt.materialize()

		#expect(materialized.entity == entity)
		#expect(materialized.periods.count == 4)
		#expect(materialized.revenueAccounts.count == 1)
		#expect(materialized.expenseAccounts.count == 2)

		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Check all pre-computed metrics
		#expect(materialized.totalRevenue[q1] == 100_000)
		#expect(materialized.totalExpenses[q1] == 60_000)
		#expect(materialized.netIncome[q1] == 40_000)
		#expect(materialized.grossProfit[q1] == 60_000)
		#expect(materialized.operatingIncome[q1] == 40_000)
		#expect(materialized.grossMargin[q1] == 0.6)
		#expect(materialized.operatingMargin[q1] == 0.4)
		#expect(materialized.netMargin[q1] == 0.4)
	}

	// MARK: - Codable

	@Test("Income statement is Codable")
	func incomeStatementCodable() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try makeRevenueAccount(entity: entity, periods: periods)
		let cogs = try makeCogsAccount(entity: entity, periods: periods)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		let encoded = try JSONEncoder().encode(incomeStmt)
		let decoded = try JSONDecoder().decode(IncomeStatement<Double>.self, from: encoded)

		#expect(decoded.entity == incomeStmt.entity)
		#expect(decoded.periods.count == incomeStmt.periods.count)
		#expect(decoded.revenueAccounts.count == incomeStmt.revenueAccounts.count)
		#expect(decoded.expenseAccounts.count == incomeStmt.expenseAccounts.count)
	}
}
