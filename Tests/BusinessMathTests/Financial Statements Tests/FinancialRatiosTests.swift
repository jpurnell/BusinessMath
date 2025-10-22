//
//  FinancialRatiosTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/20/25.
//

import Foundation
import Testing
@testable import BusinessMath

/// # Financial Ratios Tests
///
/// Tests for profitability, efficiency, and leverage ratios that operate
/// across multiple financial statements.
@Suite("Financial Ratios Tests")
struct FinancialRatiosTests {

	// MARK: - Test Fixtures

	/// Create a simple test company with known values for ratio verification
	private func createTestCompany() throws -> (Entity, IncomeStatement<Double>, BalanceSheet<Double>) {
		let entity = Entity(
			id: "TMC",
			primaryType: .ticker,
			name: "Test Manufacturing Co"
		)

		// Create quarterly periods for 2025
		let quarters = Period.year(2025).quarters()

		// Revenue: $1,000k per quarter (growing)
		let revenueAccount = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(
				periods: quarters,
				values: [1_000_000, 1_100_000, 1_200_000, 1_300_000]
			)
		)

		// Operating Expenses: $400k per quarter
		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opexAccount = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(
				periods: quarters,
				values: [400_000, 400_000, 400_000, 400_000]
			),
			metadata: opexMetadata
		)

		// Interest Expense: $50k per quarter
		let interestAccount = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(
				periods: quarters,
				values: [50_000, 50_000, 50_000, 50_000]
			)
		)

		// Income Statement
		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenueAccount],
			expenseAccounts: [opexAccount, interestAccount]
		)

		// Assets: $5,000k (growing slightly)
		let assetAccount = try Account(
			entity: entity,
			name: "Total Assets",
			type: .asset,
			timeSeries: TimeSeries(
				periods: quarters,
				values: [5_000_000, 5_100_000, 5_200_000, 5_300_000]
			)
		)

		// Liabilities: $2,000k (stable)
		let liabilityAccount = try Account(
			entity: entity,
			name: "Total Liabilities",
			type: .liability,
			timeSeries: TimeSeries(
				periods: quarters,
				values: [2_000_000, 2_000_000, 2_000_000, 2_000_000]
			)
		)

		// Equity: Assets - Liabilities
		let equityAccount = try Account(
			entity: entity,
			name: "Shareholders Equity",
			type: .equity,
			timeSeries: TimeSeries(
				periods: quarters,
				values: [3_000_000, 3_100_000, 3_200_000, 3_300_000]
			)
		)

		// Balance Sheet
		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [assetAccount],
			liabilityAccounts: [liabilityAccount],
			equityAccounts: [equityAccount]
		)

		return (entity, incomeStatement, balanceSheet)
	}

	// MARK: - Return on Assets (ROA) Tests

	@Test("Return on Assets - basic calculation")
	func testROA() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		// Calculate ROA
		let roa = returnOnAssets(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Net Income = 1,000k - 400k - 50k = 550k
		//     Average Assets = 5,000k (no prior period)
		//     ROA = 550k / 5,000k = 11%
		let q1ROA = roa[quarters[0]]!
		#expect(abs(q1ROA - 0.11) < 0.001, "Q1 ROA should be ~11%")

		// Q2: Net Income = 1,100k - 400k - 50k = 650k
		//     Average Assets = (5,000k + 5,100k) / 2 = 5,050k
		//     ROA = 650k / 5,050k = 12.87%
		let q2ROA = roa[quarters[1]]!
		#expect(abs(q2ROA - 0.1287) < 0.001, "Q2 ROA should be ~12.87%")

		// Verify ROA is positive for all quarters
		for quarter in quarters {
			#expect(roa[quarter]! > 0, "ROA should be positive")
		}
	}

	@Test("Return on Assets - negative net income")
	func testROAWithNegativeIncome() throws {
		let entity = Entity(id: "UPC", primaryType: .ticker, name: "Unprofitable Co")
		let periods = Period.year(2025).quarters()

		// Revenue less than expenses -> negative net income
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000, 100_000, 100_000, 100_000])
		)

		let expenses = try Account(
			entity: entity,
			name: "Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [200_000, 200_000, 200_000, 200_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [expenses]
		)

		let assets = try Account(
			entity: entity,
			name: "Assets",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_000_000, 1_000_000, 1_000_000])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_000_000, 1_000_000, 1_000_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [assets],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Calculate ROA
		let roa = returnOnAssets(incomeStatement: incomeStatement, balanceSheet: balanceSheet)

		// Net Income = 100k - 200k = -100k
		// ROA = -100k / 1,000k = -10%
		let q1ROA = roa[periods[0]]!
		#expect(q1ROA < 0, "ROA should be negative with losses")
		#expect(abs(q1ROA - (-0.10)) < 0.001, "ROA should be -10%")
	}

	// MARK: - Return on Equity (ROE) Tests

	@Test("Return on Equity - basic calculation")
	func testROE() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		// Calculate ROE
		let roe = returnOnEquity(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Net Income = 550k
		//     Average Equity = 3,000k (no prior period)
		//     ROE = 550k / 3,000k = 18.33%
		let q1ROE = roe[quarters[0]]!
		#expect(abs(q1ROE - 0.1833) < 0.001, "Q1 ROE should be ~18.33%")

		// Q2: Net Income = 650k
		//     Average Equity = (3,000k + 3,100k) / 2 = 3,050k
		//     ROE = 650k / 3,050k = 21.31%
		let q2ROE = roe[quarters[1]]!
		#expect(abs(q2ROE - 0.2131) < 0.001, "Q2 ROE should be ~21.31%")
	}

	@Test("ROE vs ROA - leverage effect")
	func testROEvsROALeverage() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let roa = returnOnAssets(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		let roe = returnOnEquity(incomeStatement: incomeStatement, balanceSheet: balanceSheet)

		let quarters = Period.year(2025).quarters()

		// With leverage (debt), ROE should be higher than ROA
		// This company has $2M debt, so ROE > ROA
		for quarter in quarters {
			let roaValue = roa[quarter]!
			let roeValue = roe[quarter]!
			#expect(roeValue > roaValue, "ROE should exceed ROA when company has debt")
		}
	}

	@Test("Return on Equity - negative equity scenario")
	func testROEWithNegativeEquity() throws {
		let entity = Entity(id: "ISC", primaryType: .ticker, name: "Insolvent Co")
		let periods = [Period.quarter(year: 2025, quarter: 1)]

		// Positive net income
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [200_000])
		)

		let expenses = try Account(
			entity: entity,
			name: "Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [100_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [expenses]
		)

		// Assets < Liabilities -> Negative equity
		let assets = try Account(
			entity: entity,
			name: "Assets",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [500_000])
		)

		let liabilities = try Account(
			entity: entity,
			name: "Liabilities",
			type: .liability,
			timeSeries: TimeSeries(periods: periods, values: [600_000])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [-100_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [assets],
			liabilityAccounts: [liabilities],
			equityAccounts: [equity]
		)

		// Calculate ROE - should handle negative equity
		let roe = returnOnEquity(incomeStatement: incomeStatement, balanceSheet: balanceSheet)

		// With negative equity, ROE is negative even with positive income
		let q1ROE = roe[periods[0]]!
		#expect(q1ROE < 0, "ROE should be negative with negative equity")
	}

	// MARK: - Return on Invested Capital (ROIC) Tests

	@Test("Return on Invested Capital - basic calculation")
	func testROIC() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		// Tax rate of 21%
		let taxRate = 0.21

		// Calculate ROIC
		let roic = returnOnInvestedCapital(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			taxRate: taxRate
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Operating Income = Revenue - OpEx = 1,000k - 400k = 600k
		//     NOPAT = 600k × (1 - 0.21) = 474k
		//     Current Liabilities = 0 (no "Current" category set)
		//     Invested Capital = Total Assets - Current Liabilities = 5,000k - 0 = 5,000k
		//     ROIC = 474k / 5,000k (per quarter, not annualized)
		let q1ROIC = roic[quarters[0]]!
		#expect(q1ROIC > 0, "ROIC should be positive")
		#expect(q1ROIC < 0.20, "ROIC should be reasonable (< 20% per quarter)")
	}

	@Test("ROIC with different tax rates")
	func testROICTaxRates() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let quarters = Period.year(2025).quarters()

		// Calculate ROIC with two different tax rates
		let roic21 = returnOnInvestedCapital(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			taxRate: 0.21
		)

		let roic35 = returnOnInvestedCapital(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			taxRate: 0.35
		)

		// Higher tax rate should result in lower ROIC
		for quarter in quarters {
			#expect(roic21[quarter]! > roic35[quarter]!, "Lower tax rate should yield higher ROIC")
		}
	}

	@Test("Compare ROA, ROE, and ROIC")
	func testCompareReturns() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let roa = returnOnAssets(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		let roe = returnOnEquity(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		let roic = returnOnInvestedCapital(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			taxRate: 0.21
		)

		let quarters = Period.year(2025).quarters()

		// All three should be positive
		for quarter in quarters {
			#expect(roa[quarter]! > 0, "ROA should be positive")
			#expect(roe[quarter]! > 0, "ROE should be positive")
			#expect(roic[quarter]! > 0, "ROIC should be positive")
		}

		// With leverage, typically ROE > ROA
		// ROIC may be between them depending on capital structure
		for quarter in quarters {
			#expect(roe[quarter]! > roa[quarter]!, "ROE should exceed ROA with leverage")
		}
	}

	// MARK: - Efficiency Ratio Tests

	@Test("Asset Turnover - basic calculation")
	func testAssetTurnover() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let assetTurnover = assetTurnover(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Revenue = 1,000k, Assets = 5,000k
		//     Asset Turnover = 1,000k / 5,000k = 0.20
		let q1Turnover = assetTurnover[quarters[0]]!
		#expect(abs(q1Turnover - 0.20) < 0.01, "Q1 asset turnover should be ~0.20")

		// Asset turnover should be positive for all periods
		for quarter in quarters {
			#expect(assetTurnover[quarter]! > 0, "Asset turnover should be positive")
		}
	}

	@Test("Inventory Turnover - manufacturing company")
	func testInventoryTurnover() throws {
		let entity = Entity(id: "MFG", primaryType: .ticker, name: "Manufacturing Co")
		let quarters = Period.year(2025).quarters()

		// Revenue
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [1_000_000, 1_100_000, 1_200_000, 1_300_000])
		)

		// COGS: 60% of revenue
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [600_000, 660_000, 720_000, 780_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		// Inventory: $200k (slowly increasing)
		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [200_000, 210_000, 220_000, 230_000]),
			metadata: inventoryMetadata
		)

		// Other assets
		let otherAssets = try Account(
			entity: entity,
			name: "Other Assets",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [800_000, 800_000, 800_000, 800_000])
		)

		// Equity
		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [1_000_000, 1_010_000, 1_020_000, 1_030_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [inventory, otherAssets],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Calculate inventory turnover
		let turnover = try inventoryTurnover(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		// Q1: COGS = 600k, Inventory = 200k
		//     Turnover = 600k / 200k = 3.0
		let q1Turnover = turnover[quarters[0]]!
		#expect(abs(q1Turnover - 3.0) < 0.1, "Q1 inventory turnover should be ~3.0")

		// All periods should have positive turnover
		for quarter in quarters {
			#expect(turnover[quarter]! > 0, "Inventory turnover should be positive")
		}
	}

	@Test("Days Inventory Outstanding")
	func testDaysInventoryOutstanding() throws {
		let entity = Entity(id: "RETAIL", primaryType: .ticker, name: "Retail Co")
		let quarters = Period.year(2025).quarters()

		// Fast-moving retail inventory
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [500_000, 500_000, 500_000, 500_000])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [400_000, 400_000, 400_000, 400_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 50_000, 50_000, 50_000]),
			metadata: inventoryMetadata
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 50_000, 50_000, 50_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [inventory],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Calculate DIO
		let dio = try daysInventoryOutstanding(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		// Q1: COGS = 400k, Inventory = 50k
		//     Turnover = 400k / 50k = 8
		//     DIO = 365 / 8 = 45.625 days
		let q1DIO = dio[quarters[0]]!
		#expect(abs(q1DIO - 45.625) < 1.0, "Q1 DIO should be ~45.6 days")

		// Lower DIO is better (faster inventory movement)
		for quarter in quarters {
			#expect(dio[quarter]! > 0, "DIO should be positive")
			#expect(dio[quarter]! < 365, "DIO should be less than a year")
		}
	}

	@Test("Receivables Turnover - B2B company")
	func testReceivablesTurnover() throws {
		let entity = Entity(id: "B2B", primaryType: .ticker, name: "B2B Services")
		let quarters = Period.year(2025).quarters()

		// Revenue
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [1_000_000, 1_000_000, 1_000_000, 1_000_000])
		)

		let expenses = try Account(
			entity: entity,
			name: "Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [600_000, 600_000, 600_000, 600_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [expenses]
		)

		// Receivables: customers pay in ~60 days
		var receivablesMetadata = AccountMetadata()
		receivablesMetadata.category = "Current"
		let receivables = try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [200_000, 200_000, 200_000, 200_000]),
			metadata: receivablesMetadata
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [200_000, 200_000, 200_000, 200_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [receivables],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Calculate receivables turnover
		let turnover = try receivablesTurnover(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		// Q1: Revenue = 1,000k, Receivables = 200k
		//     Turnover = 1,000k / 200k = 5.0
		let q1Turnover = turnover[quarters[0]]!
		#expect(abs(q1Turnover - 5.0) < 0.1, "Q1 receivables turnover should be ~5.0")
	}

	@Test("Days Sales Outstanding")
	func testDaysSalesOutstanding() throws {
		let entity = Entity(id: "SVC", primaryType: .ticker, name: "Service Co")
		let quarters = Period.year(2025).quarters()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [365_000, 365_000, 365_000, 365_000])
		)

		let expenses = try Account(
			entity: entity,
			name: "Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [200_000, 200_000, 200_000, 200_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [expenses]
		)

		// Receivables representing 30 days of sales
		var receivablesMetadata = AccountMetadata()
		receivablesMetadata.category = "Current"
		let receivables = try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [30_000, 30_000, 30_000, 30_000]),
			metadata: receivablesMetadata
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [30_000, 30_000, 30_000, 30_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [receivables],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Calculate DSO
		let dso = try daysSalesOutstanding(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		// Q1: Revenue = 365k, Receivables = 30k
		//     Turnover = 365k / 30k ≈ 12.17
		//     DSO = 365 / 12.17 ≈ 30 days
		let q1DSO = dso[quarters[0]]!
		#expect(abs(q1DSO - 30.0) < 1.0, "Q1 DSO should be ~30 days")

		// DSO should be reasonable (< 120 days for most businesses)
		for quarter in quarters {
			#expect(dso[quarter]! > 0, "DSO should be positive")
			#expect(dso[quarter]! < 120, "DSO should be reasonable")
		}
	}

	@Test("Missing inventory account throws error")
	func testMissingInventory() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		// Our test company has no inventory account
		#expect(throws: FinancialRatioError.self) {
			try inventoryTurnover(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet
			)
		}
	}

	@Test("Missing receivables account throws error")
	func testMissingReceivables() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		// Our test company has no receivables account
		#expect(throws: FinancialRatioError.self) {
			try receivablesTurnover(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet
			)
		}
	}

	// MARK: - Leverage Ratio Tests (Interest Coverage, DSCR)

	@Test("Interest Coverage - basic calculation")
	func testInterestCoverage() throws {
		let (_, incomeStatement, _) = try createTestCompany()

		// Calculate interest coverage
		let coverage = try interestCoverage(incomeStatement: incomeStatement)

		let quarters = Period.year(2025).quarters()

		// Q1: Operating Income = Revenue - OpEx = 1,000k - 400k = 600k
		//     Interest Expense = 50k
		//     Coverage = 600k / 50k = 12.0x
		let q1Coverage = coverage[quarters[0]]!
		#expect(abs(q1Coverage - 12.0) < 0.1, "Q1 interest coverage should be ~12.0x")

		// Q2: Operating Income = 1,100k - 400k = 700k
		//     Interest Expense = 50k
		//     Coverage = 700k / 50k = 14.0x
		let q2Coverage = coverage[quarters[1]]!
		#expect(abs(q2Coverage - 14.0) < 0.1, "Q2 interest coverage should be ~14.0x")

		// All quarters should have healthy coverage (> 3.0)
		for quarter in quarters {
			#expect(coverage[quarter]! > 3.0, "Interest coverage should be healthy (> 3.0)")
		}
	}

	@Test("Interest Coverage - distressed company")
	func testInterestCoverageLow() throws {
		let entity = Entity(id: "DST", primaryType: .ticker, name: "Distressed Co")
		let quarters = Period.year(2025).quarters()

		// Low revenue
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 100_000, 100_000, 100_000])
		)

		// High operating expenses
		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [70_000, 70_000, 70_000, 70_000]),
			metadata: opexMetadata
		)

		// High interest expense (relative to operating income)
		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [25_000, 25_000, 25_000, 25_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [opex, interest]
		)

		// Calculate interest coverage
		let coverage = try interestCoverage(incomeStatement: incomeStatement)

		// Operating Income = 100k - 70k = 30k
		// Interest Expense = 25k
		// Coverage = 30k / 25k = 1.2x (risky)
		let q1Coverage = coverage[quarters[0]]!
		#expect(abs(q1Coverage - 1.2) < 0.1, "Low interest coverage should be ~1.2x")
		#expect(q1Coverage < 2.0, "Coverage should be below healthy threshold")
	}

	@Test("Interest Coverage - missing interest expense")
	func testInterestCoverageMissingExpense() throws {
		let entity = Entity(id: "NID", primaryType: .ticker, name: "No Interest Debt Co")
		let quarters = Period.year(2025).quarters()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [1_000_000, 1_000_000, 1_000_000, 1_000_000])
		)

		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [400_000, 400_000, 400_000, 400_000])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [opex]
		)

		// Should throw error when no interest expense found
		#expect(throws: FinancialRatioError.self) {
			try interestCoverage(incomeStatement: incomeStatement)
		}
	}

	@Test("Debt Service Coverage Ratio - basic calculation")
	func testDebtServiceCoverage() throws {
		let (_, incomeStatement, _) = try createTestCompany()

		let quarters = Period.year(2025).quarters()

		// Create principal and interest payment series
		let principalPayments = TimeSeries(
			periods: quarters,
			values: [100_000.0, 100_000.0, 100_000.0, 100_000.0]
		)

		let interestPayments = TimeSeries(
			periods: quarters,
			values: [50_000.0, 50_000.0, 50_000.0, 50_000.0]
		)

		// Calculate DSCR
		let dscr = debtServiceCoverage(
			incomeStatement: incomeStatement,
			principalPayments: principalPayments,
			interestPayments: interestPayments
		)

		// Q1: Operating Income = 600k
		//     Total Debt Service = 100k + 50k = 150k
		//     DSCR = 600k / 150k = 4.0x
		let q1DSCR = dscr[quarters[0]]!
		#expect(abs(q1DSCR - 4.0) < 0.1, "Q1 DSCR should be ~4.0x")

		// All quarters should have strong coverage (> 1.5)
		for quarter in quarters {
			#expect(dscr[quarter]! > 1.5, "DSCR should be strong (> 1.5)")
		}
	}

	@Test("Debt Service Coverage Ratio - tight coverage")
	func testDebtServiceCoverageTight() throws {
		let entity = Entity(id: "TGT", primaryType: .ticker, name: "Tight Coverage Co")
		let quarters = Period.year(2025).quarters()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [500_000, 500_000, 500_000, 500_000])
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [350_000, 350_000, 350_000, 350_000]),
			metadata: opexMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [opex]
		)

		// High debt payments relative to operating income
		let principalPayments = TimeSeries(
			periods: quarters,
			values: [100_000.0, 100_000.0, 100_000.0, 100_000.0]
		)

		let interestPayments = TimeSeries(
			periods: quarters,
			values: [30_000.0, 30_000.0, 30_000.0, 30_000.0]
		)

		let dscr = debtServiceCoverage(
			incomeStatement: incomeStatement,
			principalPayments: principalPayments,
			interestPayments: interestPayments
		)

		// Operating Income = 500k - 350k = 150k
		// Total Debt Service = 100k + 30k = 130k
		// DSCR = 150k / 130k ≈ 1.15x (tight)
		let q1DSCR = dscr[quarters[0]]!
		#expect(abs(q1DSCR - 1.15) < 0.05, "DSCR should be ~1.15x")
		#expect(q1DSCR > 1.0, "DSCR should be above 1.0 (can service debt)")
		#expect(q1DSCR < 1.25, "DSCR should be below 1.25 (tight coverage)")
	}

	@Test("Debt Service Coverage Ratio - insufficient coverage")
	func testDebtServiceCoverageInsufficient() throws {
		let entity = Entity(id: "INS", primaryType: .ticker, name: "Insufficient Coverage Co")
		let quarters = Period.year(2025).quarters()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [200_000, 200_000, 200_000, 200_000])
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [150_000, 150_000, 150_000, 150_000]),
			metadata: opexMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [opex]
		)

		// Debt payments exceed operating income
		let principalPayments = TimeSeries(
			periods: quarters,
			values: [60_000.0, 60_000.0, 60_000.0, 60_000.0]
		)

		let interestPayments = TimeSeries(
			periods: quarters,
			values: [20_000.0, 20_000.0, 20_000.0, 20_000.0]
		)

		let dscr = debtServiceCoverage(
			incomeStatement: incomeStatement,
			principalPayments: principalPayments,
			interestPayments: interestPayments
		)

		// Operating Income = 200k - 150k = 50k
		// Total Debt Service = 60k + 20k = 80k
		// DSCR = 50k / 80k = 0.625 (insufficient!)
		let q1DSCR = dscr[quarters[0]]!
		#expect(abs(q1DSCR - 0.625) < 0.05, "DSCR should be ~0.625")
		#expect(q1DSCR < 1.0, "DSCR < 1.0 indicates insufficient coverage")
	}
}
