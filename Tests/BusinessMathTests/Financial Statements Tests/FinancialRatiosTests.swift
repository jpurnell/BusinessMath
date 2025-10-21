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
		let opexAccount = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(
				periods: quarters,
				values: [400_000, 400_000, 400_000, 400_000]
			)
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
}
