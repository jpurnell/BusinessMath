//
//  RatioConvenienceFunctionsTests.swift
//  BusinessMath
//
//  Created for testing convenience ratio functions
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for convenience ratio analysis functions
struct RatioConvenienceFunctionsTests {
	// Test data setup
	let entity = Entity(
		id: "TEST",
		primaryType: .ticker,
		name: "Test Company"
	)

	let periods = [
		Period.quarter(year: 2025, quarter: 1),
		Period.quarter(year: 2025, quarter: 2)
	]

	func createTestFinancialStatements() throws -> (IncomeStatement<Double>, BalanceSheet<Double>) {
		// Revenue
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_100_000])
		)

		// COGS
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [400_000, 440_000]),
			expenseType: .costOfGoodsSold
		)

		// Operating expenses
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [300_000, 330_000]),
			expenseType: .operatingExpense
		)

		// Depreciation
		let depreciation = try Account(
			entity: entity,
			name: "Depreciation",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [50_000, 50_000]),
			expenseType: .depreciationAmortization
		)

		// Interest
		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [25_000, 25_000]),
			expenseType: .interestExpense
		)

		// Tax
		let tax = try Account(
			entity: entity,
			name: "Income Tax",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [47_250, 51_450]),
			expenseType: .taxExpense
		)

		// Create income statement
		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, depreciation, interest, tax]
		)

		// Assets
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000]),
			assetType: .cashAndEquivalents
		)

		let receivables = try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [300_000, 330_000]),
			assetType: .accountsReceivable
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [200_000, 220_000]),
			assetType: .inventory
		)

		let ppe = try Account(
			entity: entity,
			name: "PP&E",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [2_000_000, 1_950_000]),
			assetType: .propertyPlantEquipment
		)

		// Liabilities
		let payables = try Account(
			entity: entity,
			name: "Accounts Payable",
			type: .liability,
			timeSeries: TimeSeries(periods: periods, values: [150_000, 165_000]),
			liabilityType: .accountsPayable
		)

		let debt = try Account(
			entity: entity,
			name: "Long-term Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_000_000]),
			liabilityType: .longTermDebt
		)

		// Equity
		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [1_850_000, 1_885_000]),
			equityType: .retainedEarnings
		)

		// Create balance sheet
		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, receivables, inventory, ppe],
			liabilityAccounts: [payables, debt],
			equityAccounts: [equity]
		)

		return (incomeStatement, balanceSheet)
	}

	@Test("profitabilityRatios() returns all profitability metrics")
	func testProfitabilityRatios() throws {
		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

		let profitability = profitabilityRatios(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let q1 = periods[0]

		// Verify all metrics are present and reasonable
		#expect(profitability.grossMargin[q1]! > 0.5) // 60% gross margin
		#expect(profitability.grossMargin[q1]! < 0.7)

		#expect(profitability.netMargin[q1]! > 0.15) // ~17.75% net margin
		#expect(profitability.netMargin[q1]! < 0.20)

		#expect(profitability.roa[q1]! > 0.05) // Positive ROA
		#expect(profitability.roe[q1]! > 0.08) // Positive ROE
		#expect(profitability.roic[q1]! > 0.05) // Positive ROIC

		// ROE should be higher than ROA due to leverage
		#expect(profitability.roe[q1]! > profitability.roa[q1]!)
	}

	@Test("efficiencyRatios() returns all efficiency metrics including CCC")
	func testEfficiencyRatios() throws {
		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

		let efficiency = try efficiencyRatios(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let q1 = periods[0]

		// Verify all metrics are present
		#expect(efficiency.assetTurnover[q1]! > 0.0)
		#expect(efficiency.inventoryTurnover[q1]! > 0.0)
		#expect(efficiency.receivablesTurnover[q1]! > 0.0)
		#expect(efficiency.daysSalesOutstanding[q1]! > 0.0)
		#expect(efficiency.daysInventoryOutstanding[q1]! > 0.0)
		#expect(efficiency.daysPayableOutstanding[q1]! > 0.0)

		// Cash Conversion Cycle = DIO + DSO - DPO
		let expectedCCC = efficiency.daysInventoryOutstanding[q1]! +
						  efficiency.daysSalesOutstanding[q1]! -
						  efficiency.daysPayableOutstanding[q1]!

		#expect(abs(efficiency.cashConversionCycle[q1]! - expectedCCC) < 0.01)
	}

	@Test("liquidityRatios() returns all liquidity metrics")
	func testLiquidityRatios() throws {
		let (_, balanceSheet) = try createTestFinancialStatements()

		let liquidity = liquidityRatios(balanceSheet: balanceSheet)

		let q1 = periods[0]

		// Verify all metrics are present and reasonable
		#expect(liquidity.currentRatio[q1]! > 1.0) // Should be > 1 for healthy company
		#expect(liquidity.quickRatio[q1]! > 0.0)
		#expect(liquidity.cashRatio[q1]! > 0.0)
		#expect(liquidity.workingCapital[q1]! > 0.0) // Positive working capital

		// Quick ratio should be less than current ratio (excludes inventory)
		#expect(liquidity.quickRatio[q1]! < liquidity.currentRatio[q1]!)

		// Cash ratio should be less than quick ratio
		#expect(liquidity.cashRatio[q1]! < liquidity.quickRatio[q1]!)
	}

	@Test("solvencyRatios() returns all solvency metrics")
	func testSolvencyRatios() throws {
		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

		let solvency = try solvencyRatios(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let q1 = periods[0]

		// Verify all metrics are present
		#expect(solvency.debtToEquity[q1]! > 0.0)
		#expect(solvency.debtToAssets[q1]! > 0.0)
		#expect(solvency.debtToAssets[q1]! < 1.0) // Should be less than 100%
		#expect(solvency.equityRatio[q1]! > 0.0)
		#expect(solvency.equityRatio[q1]! < 1.0)
		#expect(solvency.interestCoverage[q1]! > 1.0) // Should cover interest

		// Debt-to-assets + equity ratio should equal 1.0
		let sum = solvency.debtToAssets[q1]! + solvency.equityRatio[q1]!
		#expect(abs(sum - 1.0) < 0.01)

		// Debt service coverage should be nil when not provided
		#expect(solvency.debtServiceCoverage == nil)
	}

	@Test("solvencyRatios() calculates DSCR when payments provided")
	func testSolvencyRatiosWithDSCR() throws {
		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

		let principal = TimeSeries(periods: periods, values: [10_000, 10_000])
		let interest = TimeSeries(periods: periods, values: [25_000, 25_000])

		let solvency = try solvencyRatios(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			principalPayments: principal,
			interestPayments: interest
		)

		let q1 = periods[0]

		// DSCR should be calculated
		#expect(solvency.debtServiceCoverage != nil)
		#expect(solvency.debtServiceCoverage![q1]! > 1.0) // Should cover debt service
	}

	@Test("valuationMetrics() returns all market-based metrics")
	func testValuationMetrics() throws {
		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

		let valuation = valuationMetrics(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			sharesOutstanding: 1_000_000,
			marketPrice: 50.0
		)

		let q1 = periods[0]

		// Market cap should be shares × price
		#expect(valuation.marketCap[q1]! == 50_000_000)

		// Verify all ratios are present
		#expect(valuation.priceToEarnings[q1]! > 0.0)
		#expect(valuation.priceToBook[q1]! > 0.0)
		#expect(valuation.priceToSales[q1]! > 0.0)
		#expect(valuation.enterpriseValue[q1]! > 0.0)
		#expect(valuation.evToEbitda[q1]! > 0.0)
		#expect(valuation.evToSales[q1]! > 0.0)

		// EV should be Market Cap + Debt - Cash
		let expectedEV: Double = 50_000_000 + 1_150_000 - 500_000 // MC + Liabilities - Cash
		#expect(abs(valuation.enterpriseValue[q1]! - expectedEV) < 1.0)
	}

	@Test("piotroskiFScore() alias works correctly")
	func testPiotroskiFScoreAlias() throws {
		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

		// Create a simple cash flow statement
		let operatingCF = try Account(
			entity: entity,
			name: "Operating Cash Flow",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [200_000, 220_000])
		)

		let cashFlowStatement = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingCF],
			investingAccounts: [],
			financingAccounts: []
		)

		let q1 = periods[0]
		let q2 = periods[1]

		// Test that both functions return the same result
		let scoreOriginal = piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: q2,
			priorPeriod: q1
		)

		let scoreAlias = piotroskiFScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: q2,
			priorPeriod: q1
		)

		#expect(scoreOriginal.totalScore == scoreAlias.totalScore)
		#expect(scoreOriginal.profitability == scoreAlias.profitability)
		#expect(scoreOriginal.leverage == scoreAlias.leverage)
		#expect(scoreOriginal.efficiency == scoreAlias.efficiency)
	}

	@Test("Profitability ratios remain consistent across periods")
	func testProfitabilityTrends() throws {
		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

		let profitability = profitabilityRatios(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let q1 = periods[0]
		let q2 = periods[1]

		// Both periods should have valid ratios
		#expect(profitability.grossMargin[q1]! > 0.0)
		#expect(profitability.grossMargin[q2]! > 0.0)

		// Margins should be relatively stable (within 10%)
		let marginRatio = profitability.grossMargin[q2]! / profitability.grossMargin[q1]!
		#expect(marginRatio > 0.9)
		#expect(marginRatio < 1.1)
	}
}
