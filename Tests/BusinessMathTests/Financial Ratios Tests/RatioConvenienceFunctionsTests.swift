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
//struct RatioConvenienceFunctionsTests {
//	// Test data setup
//	let entity = Entity(
//		id: "TEST",
//		primaryType: .ticker,
//		name: "Test Company"
//	)
//
//	let periods = [
//		Period.quarter(year: 2025, quarter: 1),
//		Period.quarter(year: 2025, quarter: 2)
//	]
//
//	func createTestFinancialStatements() throws -> (IncomeStatement<Double>, BalanceSheet<Double>) {
//		// Revenue
//		let revenue = try Account(
//			entity: entity,
//			name: "Revenue",
//			type: .revenue,
//			timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_100_000])
//		)
//
//		// COGS
//		let cogs = try Account(
//			entity: entity,
//			name: "Cost of Goods Sold",
//			type: .expense,
//			timeSeries: TimeSeries(periods: periods, values: [400_000, 440_000]),
//			expenseType: .costOfGoodsSold
//		)
//
//		// Operating expenses
//		let opex = try Account(
//			entity: entity,
//			name: "Operating Expenses",
//			type: .expense,
//			timeSeries: TimeSeries(periods: periods, values: [300_000, 330_000]),
//			expenseType: .operatingExpense
//		)
//
//		// Depreciation
//		let depreciation = try Account(
//			entity: entity,
//			name: "Depreciation",
//			type: .expense,
//			timeSeries: TimeSeries(periods: periods, values: [50_000, 50_000]),
//			expenseType: .depreciationAmortization
//		)
//
//		// Interest
//		let interest = try Account(
//			entity: entity,
//			name: "Interest Expense",
//			type: .expense,
//			timeSeries: TimeSeries(periods: periods, values: [25_000, 25_000]),
//			expenseType: .interestExpense
//		)
//
//		// Tax
//		let tax = try Account(
//			entity: entity,
//			name: "Income Tax",
//			type: .expense,
//			timeSeries: TimeSeries(periods: periods, values: [47_250, 51_450]),
//			expenseType: .taxExpense
//		)
//
//		// Create income statement
//		let incomeStatement = try IncomeStatement(
//			entity: entity,
//			periods: periods,
//			revenueAccounts: [revenue],
//			expenseAccounts: [cogs, opex, depreciation, interest, tax]
//		)
//
//		// Assets
//		let cash = try Account(
//			entity: entity,
//			name: "Cash",
//			type: .asset,
//			timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000]),
//			assetType: .cashAndEquivalents
//		)
//
//		let receivables = try Account(
//			entity: entity,
//			name: "Accounts Receivable",
//			type: .asset,
//			timeSeries: TimeSeries(periods: periods, values: [300_000, 330_000]),
//			assetType: .accountsReceivable
//		)
//
//		let inventory = try Account(
//			entity: entity,
//			name: "Inventory",
//			type: .asset,
//			timeSeries: TimeSeries(periods: periods, values: [200_000, 220_000]),
//			assetType: .inventory
//		)
//
//		let ppe = try Account(
//			entity: entity,
//			name: "PP&E",
//			type: .asset,
//			timeSeries: TimeSeries(periods: periods, values: [2_000_000, 1_950_000]),
//			assetType: .propertyPlantEquipment
//		)
//
//		// Liabilities
//		let payables = try Account(
//			entity: entity,
//			name: "Accounts Payable",
//			type: .liability,
//			timeSeries: TimeSeries(periods: periods, values: [150_000, 165_000]),
//			liabilityType: .accountsPayable
//		)
//
//		let debt = try Account(
//			entity: entity,
//			name: "Long-term Debt",
//			type: .liability,
//			timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_000_000]),
//			liabilityType: .longTermDebt
//		)
//
//		// Equity
//		let equity = try Account(
//			entity: entity,
//			name: "Equity",
//			type: .equity,
//			timeSeries: TimeSeries(periods: periods, values: [1_850_000, 1_885_000]),
//			equityType: .retainedEarnings
//		)
//
//		// Create balance sheet
//		let balanceSheet = try BalanceSheet(
//			entity: entity,
//			periods: periods,
//			assetAccounts: [cash, receivables, inventory, ppe],
//			liabilityAccounts: [payables, debt],
//			equityAccounts: [equity]
//		)
//
//		return (incomeStatement, balanceSheet)
//	}
//
//	@Test("profitabilityRatios() returns all profitability metrics")
//	func testProfitabilityRatios() throws {
//		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
//
//		let profitability = profitabilityRatios(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet
//		)
//
//		let q1 = periods[0]
//
//		// Verify all metrics are present and reasonable
//		#expect(profitability.grossMargin[q1]! > 0.5) // 60% gross margin
//		#expect(profitability.grossMargin[q1]! < 0.7)
//
//		#expect(profitability.netMargin[q1]! > 0.15) // ~17.75% net margin
//		#expect(profitability.netMargin[q1]! < 0.20)
//
//		#expect(profitability.roa[q1]! > 0.05) // Positive ROA
//		#expect(profitability.roe[q1]! > 0.08) // Positive ROE
//		#expect(profitability.roic[q1]! > 0.05) // Positive ROIC
//
//		// ROE should be higher than ROA due to leverage
//		#expect(profitability.roe[q1]! > profitability.roa[q1]!)
//	}
//
//	@Test("efficiencyRatios() returns all efficiency metrics including CCC")
//	func testEfficiencyRatios() throws {
//		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
//
//		let efficiency = efficiencyRatios(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet
//		)
//
//		let q1 = periods[0]
//
//		// Asset turnover is always available
//		#expect(efficiency.assetTurnover[q1]! > 0.0)
//
//		// With our test data, all optional metrics should be present
//		#expect(efficiency.inventoryTurnover != nil)
//		#expect(efficiency.receivablesTurnover != nil)
//		#expect(efficiency.daysSalesOutstanding != nil)
//		#expect(efficiency.daysInventoryOutstanding != nil)
//		#expect(efficiency.daysPayableOutstanding != nil)
//		#expect(efficiency.cashConversionCycle != nil)
//
//		// Verify values are reasonable
//		#expect(efficiency.inventoryTurnover![q1]! > 0.0)
//		#expect(efficiency.receivablesTurnover![q1]! > 0.0)
//		#expect(efficiency.daysSalesOutstanding![q1]! > 0.0)
//		#expect(efficiency.daysInventoryOutstanding![q1]! > 0.0)
//		#expect(efficiency.daysPayableOutstanding![q1]! > 0.0)
//
//		// Cash Conversion Cycle = DIO + DSO - DPO
//		let expectedCCC = efficiency.daysInventoryOutstanding![q1]! +
//						  efficiency.daysSalesOutstanding![q1]! -
//						  efficiency.daysPayableOutstanding![q1]!
//
//		#expect(abs(efficiency.cashConversionCycle![q1]! - expectedCCC) < 0.01)
//	}
//
//	@Test("liquidityRatios() returns all liquidity metrics")
//	func testLiquidityRatios() throws {
//		let (_, balanceSheet) = try createTestFinancialStatements()
//
//		let liquidity = liquidityRatios(balanceSheet: balanceSheet)
//
//		let q1 = periods[0]
//
//		// Verify all metrics are present and reasonable
//		#expect(liquidity.currentRatio[q1]! > 1.0) // Should be > 1 for healthy company
//		#expect(liquidity.quickRatio[q1]! > 0.0)
//		#expect(liquidity.cashRatio[q1]! > 0.0)
//		#expect(liquidity.workingCapital[q1]! > 0.0) // Positive working capital
//
//		// Quick ratio should be less than current ratio (excludes inventory)
//		#expect(liquidity.quickRatio[q1]! < liquidity.currentRatio[q1]!)
//
//		// Cash ratio should be less than quick ratio
//		#expect(liquidity.cashRatio[q1]! < liquidity.quickRatio[q1]!)
//	}
//
//	@Test("solvencyRatios() returns all solvency metrics")
//	func testSolvencyRatios() throws {
//		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
//
//		let solvency = solvencyRatios(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet
//		)
//
//		let q1 = periods[0]
//
//		// Leverage ratios are always available
//		#expect(solvency.debtToEquity[q1]! > 0.0)
//		#expect(solvency.debtToAssets[q1]! > 0.0)
//		#expect(solvency.debtToAssets[q1]! < 1.0) // Should be less than 100%
//		#expect(solvency.equityRatio[q1]! > 0.0)
//		#expect(solvency.equityRatio[q1]! < 1.0)
//
//		// With our test data, interest coverage should be present
//		#expect(solvency.interestCoverage != nil)
//		#expect(solvency.interestCoverage![q1]! > 1.0) // Should cover interest
//
//		// Debt-to-assets + equity ratio should equal 1.0
//		let sum = solvency.debtToAssets[q1]! + solvency.equityRatio[q1]!
//		#expect(abs(sum - 1.0) < 0.01)
//
//		// Debt service coverage should be nil when not provided
//		#expect(solvency.debtServiceCoverage == nil)
//	}
//
//	@Test("solvencyRatios() calculates DSCR when payments provided")
//	func testSolvencyRatiosWithDSCR() throws {
//		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
//
//		let principal = TimeSeries(periods: periods, values: [10_000, 10_000])
//		let interest = TimeSeries(periods: periods, values: [25_000, 25_000])
//
//		let solvency = solvencyRatios(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet,
//			principalPayments: principal,
//			interestPayments: interest
//		)
//
//		let q1 = periods[0]
//
//		// DSCR should be calculated
//		#expect(solvency.debtServiceCoverage != nil)
//		#expect(solvency.debtServiceCoverage![q1]! > 1.0) // Should cover debt service
//	}
//
//	@Test("valuationMetrics() returns all market-based metrics")
//	func testValuationMetrics() throws {
//		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
//
//		let valuation = valuationMetrics(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet,
//			sharesOutstanding: 1_000_000,
//			marketPrice: 50.0
//		)
//
//		let q1 = periods[0]
//
//		// Market cap should be shares × price
//		#expect(valuation.marketCap[q1]! == 50_000_000)
//
//		// Verify all ratios are present
//		#expect(valuation.priceToEarnings[q1]! > 0.0)
//		#expect(valuation.priceToBook[q1]! > 0.0)
//		#expect(valuation.priceToSales[q1]! > 0.0)
//		#expect(valuation.enterpriseValue[q1]! > 0.0)
//		#expect(valuation.evToEbitda[q1]! > 0.0)
//		#expect(valuation.evToSales[q1]! > 0.0)
//
//		// EV should be Market Cap + Debt - Cash
//		let expectedEV: Double = 50_000_000 + 1_150_000 - 500_000 // MC + Liabilities - Cash
//		#expect(abs(valuation.enterpriseValue[q1]! - expectedEV) < 1.0)
//	}
//
//	@Test("piotroskiFScore() alias works correctly")
//	func testPiotroskiFScoreAlias() throws {
//		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
//
//		// Create a simple cash flow statement
//		let operatingCF = try Account(
//			entity: entity,
//			name: "Operating Cash Flow",
//			type: .operating,
//			timeSeries: TimeSeries(periods: periods, values: [200_000, 220_000])
//		)
//
//		let cashFlowStatement = try CashFlowStatement(
//			entity: entity,
//			periods: periods,
//			operatingAccounts: [operatingCF],
//			investingAccounts: [],
//			financingAccounts: []
//		)
//
//		let q1 = periods[0]
//		let q2 = periods[1]
//
//		// Test that both functions return the same result
//		let scoreOriginal = piotroskiScore(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet,
//			cashFlowStatement: cashFlowStatement,
//			period: q2,
//			priorPeriod: q1
//		)
//
//		let scoreAlias = piotroskiFScore(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet,
//			cashFlowStatement: cashFlowStatement,
//			period: q2,
//			priorPeriod: q1
//		)
//
//		#expect(scoreOriginal.totalScore == scoreAlias.totalScore)
//		#expect(scoreOriginal.profitability == scoreAlias.profitability)
//		#expect(scoreOriginal.leverage == scoreAlias.leverage)
//		#expect(scoreOriginal.efficiency == scoreAlias.efficiency)
//	}
//
//	@Test("Profitability ratios remain consistent across periods")
//	func testProfitabilityTrends() throws {
//		let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
//
//		let profitability = profitabilityRatios(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet
//		)
//
//		let q1 = periods[0]
//		let q2 = periods[1]
//
//		// Both periods should have valid ratios
//		#expect(profitability.grossMargin[q1]! > 0.0)
//		#expect(profitability.grossMargin[q2]! > 0.0)
//
//		// Margins should be relatively stable (within 10%)
//		let marginRatio = profitability.grossMargin[q2]! / profitability.grossMargin[q1]!
//		#expect(marginRatio > 0.9)
//		#expect(marginRatio < 1.1)
//	}
//
//	@Test("Service company without inventory/payables/interest handles gracefully")
//	func testServiceCompanyWithoutOptionalAccounts() throws {
//		// Create a service company with no inventory, payables, or interest expense
//
//		// Revenue
//		let revenue = try Account(
//			entity: entity,
//			name: "Service Revenue",
//			type: .revenue,
//			timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000])
//		)
//
//		// Operating expenses (no COGS for service company)
//		let opex = try Account(
//			entity: entity,
//			name: "Operating Expenses",
//			type: .expense,
//			timeSeries: TimeSeries(periods: periods, values: [300_000, 330_000]),
//			expenseType: .operatingExpense
//		)
//
//		// Tax
//		let tax = try Account(
//			entity: entity,
//			name: "Income Tax",
//			type: .expense,
//			timeSeries: TimeSeries(periods: periods, values: [42_000, 46_200]),
//			expenseType: .taxExpense
//		)
//
//		// Create income statement (no COGS, no interest expense)
//		let incomeStatement = try IncomeStatement(
//			entity: entity,
//			periods: periods,
//			revenueAccounts: [revenue],
//			expenseAccounts: [opex, tax]
//		)
//
//		// Assets (no inventory)
//		let cash = try Account(
//			entity: entity,
//			name: "Cash",
//			type: .asset,
//			timeSeries: TimeSeries(periods: periods, values: [200_000, 220_000]),
//			assetType: .cashAndEquivalents
//		)
//
//		// No receivables for cash-only business
//		let ppe = try Account(
//			entity: entity,
//			name: "Equipment",
//			type: .asset,
//			timeSeries: TimeSeries(periods: periods, values: [100_000, 95_000]),
//			assetType: .propertyPlantEquipment
//		)
//
//		// Liabilities (no payables, no debt)
//		let currentLiab = try Account(
//			entity: entity,
//			name: "Accrued Expenses",
//			type: .liability,
//			timeSeries: TimeSeries(periods: periods, values: [50_000, 55_000]),
//			liabilityType: .accruedExpenses
//		)
//
//		// Equity
//		let equity = try Account(
//			entity: entity,
//			name: "Equity",
//			type: .equity,
//			timeSeries: TimeSeries(periods: periods, values: [250_000, 260_000]),
//			equityType: .retainedEarnings
//		)
//
//		// Create balance sheet
//		let balanceSheet = try BalanceSheet(
//			entity: entity,
//			periods: periods,
//			assetAccounts: [cash, ppe],
//			liabilityAccounts: [currentLiab],
//			equityAccounts: [equity]
//		)
//
//		// Test efficiency ratios
//		let efficiency = efficiencyRatios(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet
//		)
//
//		let q1 = periods[0]
//
//		// Asset turnover should always be available
//		#expect(efficiency.assetTurnover[q1]! > 0.0)
//
//		// Optional metrics should be nil
//		#expect(efficiency.inventoryTurnover == nil, "No inventory account, should be nil")
//		#expect(efficiency.daysInventoryOutstanding == nil, "No inventory account, should be nil")
//		#expect(efficiency.receivablesTurnover == nil, "No receivables account, should be nil")
//		#expect(efficiency.daysSalesOutstanding == nil, "No receivables account, should be nil")
//		#expect(efficiency.daysPayableOutstanding == nil, "No payables account, should be nil")
//		#expect(efficiency.cashConversionCycle == nil, "Missing components, should be nil")
//
//		// Test solvency ratios
//		let solvency = solvencyRatios(
//			incomeStatement: incomeStatement,
//			balanceSheet: balanceSheet
//		)
//
//		// Leverage ratios should be available
//		// Debt-to-equity will be low since we only have accrued expenses (no long-term debt)
//		#expect(solvency.debtToEquity[q1]! >= 0.0)
//		#expect(solvency.debtToAssets[q1]! >= 0.0)
//		#expect(solvency.debtToAssets[q1]! < 1.0)
//		#expect(solvency.equityRatio[q1]! > 0.0)
//
//		// Interest coverage should be nil (no interest expense)
//		#expect(solvency.interestCoverage == nil, "No interest expense, should be nil")
//		#expect(solvency.debtServiceCoverage == nil, "No payment data, should be nil")
//	}
//}

struct RatioConvenienceFunctionsTests2 {
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

				let efficiency = efficiencyRatios(
						incomeStatement: incomeStatement,
						balanceSheet: balanceSheet
				)

				let q1 = periods[0]

				// Asset turnover is always available
				#expect(efficiency.assetTurnover[q1]! > 0.0)

				// With our test data, all optional metrics should be present
				#expect(efficiency.inventoryTurnover != nil)
				#expect(efficiency.receivablesTurnover != nil)
				#expect(efficiency.daysSalesOutstanding != nil)
				#expect(efficiency.daysInventoryOutstanding != nil)
				#expect(efficiency.daysPayableOutstanding != nil)
				#expect(efficiency.cashConversionCycle != nil)

				// Verify values are reasonable
				#expect(efficiency.inventoryTurnover![q1]! > 0.0)
				#expect(efficiency.receivablesTurnover![q1]! > 0.0)
				#expect(efficiency.daysSalesOutstanding![q1]! > 0.0)
				#expect(efficiency.daysInventoryOutstanding![q1]! > 0.0)
				#expect(efficiency.daysPayableOutstanding![q1]! > 0.0)

				// Cash Conversion Cycle = DIO + DSO - DPO
				let expectedCCC = efficiency.daysInventoryOutstanding![q1]! +
												  efficiency.daysSalesOutstanding![q1]! -
												  efficiency.daysPayableOutstanding![q1]!

				#expect(abs(efficiency.cashConversionCycle![q1]! - expectedCCC) < 0.01)
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

				let solvency = solvencyRatios(
						incomeStatement: incomeStatement,
						balanceSheet: balanceSheet
				)

				let q1 = periods[0]

				// Leverage ratios are always available
				#expect(solvency.debtToEquity[q1]! > 0.0)
				#expect(solvency.debtToAssets[q1]! > 0.0)
				#expect(solvency.debtToAssets[q1]! < 1.0) // Should be less than 100%
				#expect(solvency.equityRatio[q1]! > 0.0)
				#expect(solvency.equityRatio[q1]! < 1.0)

				// With our test data, interest coverage should be present
				#expect(solvency.interestCoverage != nil)
				#expect(solvency.interestCoverage![q1]! > 1.0) // Should cover interest

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

				let solvency = solvencyRatios(
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

				// EV should be Market Cap + interest-bearing debt - Cash
				let expectedEV: Double = 50_000_000 + 1_000_000 - 500_000
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

		@Test("Service company without inventory/payables/interest handles gracefully")
		func testServiceCompanyWithoutOptionalAccounts() throws {
				// Create a service company with no inventory, payables, or interest expense

				// Revenue
				let revenue = try Account(
						entity: entity,
						name: "Service Revenue",
						type: .revenue,
						timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000])
				)

				// Operating expenses (no COGS for service company)
				let opex = try Account(
						entity: entity,
						name: "Operating Expenses",
						type: .expense,
						timeSeries: TimeSeries(periods: periods, values: [300_000, 330_000]),
						expenseType: .operatingExpense
				)

				// Tax
				let tax = try Account(
						entity: entity,
						name: "Income Tax",
						type: .expense,
						timeSeries: TimeSeries(periods: periods, values: [42_000, 46_200]),
						expenseType: .taxExpense
				)

				// Create income statement (no COGS, no interest expense)
				let incomeStatement = try IncomeStatement(
						entity: entity,
						periods: periods,
						revenueAccounts: [revenue],
						expenseAccounts: [opex, tax]
				)

				// Assets (no inventory)
				let cash = try Account(
						entity: entity,
						name: "Cash",
						type: .asset,
						timeSeries: TimeSeries(periods: periods, values: [200_000, 220_000]),
						assetType: .cashAndEquivalents
				)

				// No receivables for cash-only business
				let ppe = try Account(
						entity: entity,
						name: "Equipment",
						type: .asset,
						timeSeries: TimeSeries(periods: periods, values: [100_000, 95_000]),
						assetType: .propertyPlantEquipment
				)

				// Liabilities (no payables, no debt)
				let currentLiab = try Account(
						entity: entity,
						name: "Accrued Expenses",
						type: .liability,
						timeSeries: TimeSeries(periods: periods, values: [50_000, 55_000]),
						liabilityType: .accruedExpenses
				)

				// Equity
				let equity = try Account(
						entity: entity,
						name: "Equity",
						type: .equity,
						timeSeries: TimeSeries(periods: periods, values: [250_000, 260_000]),
						equityType: .retainedEarnings
				)

				// Create balance sheet
				let balanceSheet = try BalanceSheet(
						entity: entity,
						periods: periods,
						assetAccounts: [cash, ppe],
						liabilityAccounts: [currentLiab],
						equityAccounts: [equity]
				)

				// Test efficiency ratios
				let efficiency = efficiencyRatios(
						incomeStatement: incomeStatement,
						balanceSheet: balanceSheet
				)

				let q1 = periods[0]

				// Asset turnover should always be available
				#expect(efficiency.assetTurnover[q1]! > 0.0)

				// Optional metrics should be nil
				#expect(efficiency.inventoryTurnover == nil, "No inventory account, should be nil")
				#expect(efficiency.daysInventoryOutstanding == nil, "No inventory account, should be nil")
				#expect(efficiency.receivablesTurnover == nil, "No receivables account, should be nil")
				#expect(efficiency.daysSalesOutstanding == nil, "No receivables account, should be nil")
				#expect(efficiency.daysPayableOutstanding == nil, "No payables account, should be nil")
				#expect(efficiency.cashConversionCycle == nil, "Missing components, should be nil")

				// Test solvency ratios
				let solvency = solvencyRatios(
						incomeStatement: incomeStatement,
						balanceSheet: balanceSheet
				)

				// Leverage ratios should be available
				// Debt-to-equity will be low since we only have accrued expenses (no long-term debt)
				#expect(solvency.debtToEquity[q1]! >= 0.0)
				#expect(solvency.debtToAssets[q1]! >= 0.0)
				#expect(solvency.debtToAssets[q1]! < 1.0)
				#expect(solvency.equityRatio[q1]! > 0.0)

				// Interest coverage should be nil (no interest expense)
				#expect(solvency.interestCoverage == nil, "No interest expense, should be nil")
				#expect(solvency.debtServiceCoverage == nil, "No payment data, should be nil")
		}
}

struct RatioConvenienceFunctionsAdditionalTests {
				// Reuse the same base fixture
				let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
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

								// Income statement
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

								// Balance sheet
								let balanceSheet = try BalanceSheet(
												entity: entity,
												periods: periods,
												assetAccounts: [cash, receivables, inventory, ppe],
												liabilityAccounts: [payables, debt],
												equityAccounts: [equity]
								)

								return (incomeStatement, balanceSheet)
				}

				@Test("Liquidity ratios: exact Q1 values")
				func testLiquidityRatiosExactValues() throws {
								let (_, balanceSheet) = try createTestFinancialStatements()
								let q1 = periods[0]

								let liquidity = liquidityRatios(balanceSheet: balanceSheet)

								// Current assets and liabilities (Q1)
								let currentAssetsQ1: Double = 500_000 + 300_000 + 200_000
								let currentLiabilitiesQ1: Double = 150_000

								let expectedCurrent = currentAssetsQ1 / currentLiabilitiesQ1 // 1,000,000 / 150,000 = 6.666...
								let expectedQuick = (500_000 + 300_000) / currentLiabilitiesQ1 // 800,000 / 150,000 = 5.333...
								let expectedCash = 500_000 / currentLiabilitiesQ1 // 3.333...
								let expectedWC = currentAssetsQ1 - currentLiabilitiesQ1 // 850,000

								#expect(abs(liquidity.currentRatio[q1]! - expectedCurrent) < 1e-9)
								#expect(abs(liquidity.quickRatio[q1]! - expectedQuick) < 1e-9)
								#expect(abs(liquidity.cashRatio[q1]! - expectedCash) < 1e-9)
								#expect(abs(liquidity.workingCapital[q1]! - expectedWC) < 1e-6)

								// Also check both periods are present
								let q2 = periods[1]
								#expect(liquidity.currentRatio[q2] != nil)
								#expect(liquidity.quickRatio[q2] != nil)
								#expect(liquidity.cashRatio[q2] != nil)
								#expect(liquidity.workingCapital[q2] != nil)
				}

				@Test("Valuation ratios: P/E, P/S, P/B exact Q1 values")
				func testValuationRatiosExactValues() throws {
								let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
								let q1 = periods[0]

								let shares: Double = 1_000_000
								let price: Double = 50.0

								let valuation = valuationMetrics(
												incomeStatement: incomeStatement,
												balanceSheet: balanceSheet,
												sharesOutstanding: shares,
												marketPrice: price
								)

								// Hand-calculated values for Q1
								let revenueQ1 = 1_000_000.0
								let cogsQ1 = 400_000.0
								let opexQ1 = 300_000.0
								let depQ1 = 50_000.0
								let interestQ1 = 25_000.0
								let taxQ1 = 47_250.0
								let netIncomeQ1 = revenueQ1 - cogsQ1 - opexQ1 - depQ1 - interestQ1 - taxQ1 // 177,750

								let marketCapQ1: Double = shares * price // 50,000,000
								let epsQ1 = netIncomeQ1 / shares // 0.17775
								let peExpected = price / epsQ1 // ≈ 281.270...
								let psExpected = marketCapQ1 / revenueQ1 // 50
								let bookEquityQ1 = 1_850_000.0
								let pbExpected = marketCapQ1 / bookEquityQ1 // ≈ 27.027...

								#expect(valuation.marketCap[q1] == marketCapQ1)
								#expect(abs(valuation.priceToEarnings[q1]! - peExpected) < 1e-6)
								#expect(abs(valuation.priceToSales[q1]! - psExpected) < 1e-9)
								#expect(abs(valuation.priceToBook[q1]! - pbExpected) < 1e-9)
				}

				@Test("Profitability: gross and net margin exact Q1 values; both periods present")
				func testProfitabilityExactMargins() throws {
								let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
								let ratios = profitabilityRatios(incomeStatement: incomeStatement, balanceSheet: balanceSheet)

								let q1 = periods[0]
								let q2 = periods[1]

								let revenueQ1 = 1_000_000.0
								let cogsQ1 = 400_000.0
								let opexQ1 = 300_000.0
								let depQ1 = 50_000.0
								let interestQ1 = 25_000.0
								let taxQ1 = 47_250.0

								let grossMarginExpected = (revenueQ1 - cogsQ1) / revenueQ1 // 0.6
								let netIncomeQ1 = revenueQ1 - cogsQ1 - opexQ1 - depQ1 - interestQ1 - taxQ1
								let netMarginExpected = netIncomeQ1 / revenueQ1 // 0.17775

								#expect(abs(ratios.grossMargin[q1]! - grossMarginExpected) < 1e-12)
								#expect(abs(ratios.netMargin[q1]! - netMarginExpected) < 1e-12)

								// Ensure both periods are populated
								#expect(ratios.grossMargin[q2] != nil)
								#expect(ratios.netMargin[q2] != nil)
								#expect(ratios.roa[q1] != nil && ratios.roa[q2] != nil)
								#expect(ratios.roe[q1] != nil && ratios.roe[q2] != nil)
				}

				@Test("Solvency: interest coverage equals EBIT/Interest, Q1")
				func testInterestCoverageExact() throws {
								let (incomeStatement, balanceSheet) = try createTestFinancialStatements()
								let solvency = solvencyRatios(incomeStatement: incomeStatement, balanceSheet: balanceSheet)

								let q1 = periods[0]

								let revenueQ1 = 1_000_000.0
								let cogsQ1 = 400_000.0
								let opexQ1 = 300_000.0
								let depQ1 = 50_000.0
								let interestQ1 = 25_000.0

								let ebitQ1 = revenueQ1 - cogsQ1 - opexQ1 - depQ1 // 250,000
								let expectedCoverage = ebitQ1 / interestQ1 // 10.0

								#expect(solvency.interestCoverage != nil)
								#expect(abs(solvency.interestCoverage![q1]! - expectedCoverage) < 1e-12)
				}

				@Test("Piotroski alias: score bounded and components within [0,1]")
				func testPiotroskiScoreBounds() throws {
								let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

								let operatingCF = try Account(
												entity: entity,
												name: "Operating Cash Flow",
												type: .operating,
												timeSeries: TimeSeries(periods: periods, values: [200_000, 220_000])
								)
								let cfs = try CashFlowStatement(
												entity: entity,
												periods: periods,
												operatingAccounts: [operatingCF],
												investingAccounts: [],
												financingAccounts: []
								)

								let q1 = periods[0]
								let q2 = periods[1]

								let score = piotroskiFScore(
												incomeStatement: incomeStatement,
												balanceSheet: balanceSheet,
												cashFlowStatement: cfs,
												period: q2,
												priorPeriod: q1
								)

								#expect(score.totalScore >= 0 && score.totalScore <= 9)
				}

				@Test("Returned metrics have no NaN or Infinity values for present keys")
				func testNoNaNOrInfinite() throws {
								let (incomeStatement, balanceSheet) = try createTestFinancialStatements()

								let profitability = profitabilityRatios(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
								let efficiency = efficiencyRatios(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
								let liquidity = liquidityRatios(balanceSheet: balanceSheet)
								let solvency = solvencyRatios(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
								let valuation = valuationMetrics(
												incomeStatement: incomeStatement,
												balanceSheet: balanceSheet,
												sharesOutstanding: 1_000_000,
												marketPrice: 50.0
								)

								func isFinite(_ x: Double?) -> Bool {
												guard let v = x else { return true } // nil is okay; check only present values
												return v.isFinite && !v.isNaN
								}

								for p in periods {
												#expect(isFinite(profitability.grossMargin[p]))
												#expect(isFinite(profitability.netMargin[p]))
												#expect(isFinite(profitability.roa[p]))
												#expect(isFinite(profitability.roe[p]))
												#expect(isFinite(profitability.roic[p]))

												#expect(isFinite(efficiency.assetTurnover[p]))
												#expect(isFinite(efficiency.inventoryTurnover?[p]))
												#expect(isFinite(efficiency.receivablesTurnover?[p]))
												#expect(isFinite(efficiency.daysSalesOutstanding?[p]))
												#expect(isFinite(efficiency.daysInventoryOutstanding?[p]))
												#expect(isFinite(efficiency.daysPayableOutstanding?[p]))
												#expect(isFinite(efficiency.cashConversionCycle?[p]))

												#expect(isFinite(liquidity.currentRatio[p]))
												#expect(isFinite(liquidity.quickRatio[p]))
												#expect(isFinite(liquidity.cashRatio[p]))
												#expect(isFinite(liquidity.workingCapital[p]))

												#expect(isFinite(solvency.debtToEquity[p]))
												#expect(isFinite(solvency.debtToAssets[p]))
												#expect(isFinite(solvency.equityRatio[p]))
												#expect(isFinite(solvency.interestCoverage?[p]))
												#expect(isFinite(solvency.debtServiceCoverage?[p]))

												#expect(isFinite(valuation.marketCap[p]))
												#expect(isFinite(valuation.priceToEarnings[p]))
												#expect(isFinite(valuation.priceToBook[p]))
												#expect(isFinite(valuation.priceToSales[p]))
												#expect(isFinite(valuation.enterpriseValue[p]))
												#expect(isFinite(valuation.evToEbitda[p]))
												#expect(isFinite(valuation.evToSales[p]))
								}
				}

				@Test("Mismatched periods: functions operate on intersection")
				func testMismatchedPeriodsIntersection() throws {
								let p1 = Period.quarter(year: 2025, quarter: 1)
								let p2 = Period.quarter(year: 2025, quarter: 2)
								let p3 = Period.quarter(year: 2025, quarter: 3)

								// IS has Q1-Q3; BS has Q2-Q3 only
								let revenue = try Account(
												entity: entity, name: "Revenue", type: .revenue,
												timeSeries: TimeSeries(periods: [p1, p2, p3], values: [100, 110, 120])
								)
								let cogs = try Account(
												entity: entity, name: "COGS", type: .expense,
												timeSeries: TimeSeries(periods: [p1, p2, p3], values: [40, 44, 48]),
												expenseType: .costOfGoodsSold
								)
								let isObj = try IncomeStatement(
												entity: entity,
												periods: [p1, p2, p3],
												revenueAccounts: [revenue],
												expenseAccounts: [cogs]
								)

								let cash = try Account(
												entity: entity, name: "Cash", type: .asset,
												timeSeries: TimeSeries(periods: [p2, p3], values: [50, 60]),
												assetType: .cashAndEquivalents
								)
								let ap = try Account(
												entity: entity, name: "AP", type: .liability,
												timeSeries: TimeSeries(periods: [p2, p3], values: [10, 12]),
												liabilityType: .accountsPayable
								)
								let equity = try Account(
												entity: entity, name: "Equity", type: .equity,
												timeSeries: TimeSeries(periods: [p2, p3], values: [40, 48]),
												equityType: .retainedEarnings
								)
								let bsObj = try BalanceSheet(
												entity: entity,
												periods: [p2, p3],
												assetAccounts: [cash],
												liabilityAccounts: [ap],
												equityAccounts: [equity]
								)

								let efficiency = efficiencyRatios(incomeStatement: isObj, balanceSheet: bsObj)

								#expect(efficiency.assetTurnover[p1] == nil)
								#expect(efficiency.assetTurnover[p2] != nil)
								#expect(efficiency.assetTurnover[p3] != nil)
				}
}
