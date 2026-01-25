//
//  File.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/13/26.
//

import Foundation
public struct TestEntity {
    public init() {}
	public func createTestEntity() -> Entity {
		return Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
	}
	
	public func createTestPeriods() -> [Period] {
		return [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3),
			Period.quarter(year: 2025, quarter: 4)
		]
	}
	
	public func createTestScenario() -> FinancialScenario {
		var overrides: [String: AnyDriver<Double>] = [:]
		overrides["Revenue"] = AnyDriver(DeterministicDriver(name: "Revenue", value: 1000.0))
		
		return FinancialScenario(
			name: "Test Scenario",
			description: "A scenario for testing",
			driverOverrides: overrides
		)
	}
	
	public func createTestIncomeStatement() throws -> IncomeStatement<Double> {
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
			incomeStatementRole: .revenue,
			timeSeries: revenueSeries
		)
		
			// Create revenue account
		let cogsSeries = TimeSeries<Double>(
			periods: periods,
			values: [100.0, 110.0, 120.0, 130.0]
		)
		let cogsAccount = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: cogsSeries
		)
		
			// Create expense account
		let expenseSeries = TimeSeries<Double>(
			periods: periods,
			values: [600.0, 650.0, 700.0, 750.0]
		)
		let expenseAccount = try Account(
			entity: entity,
			name: "Expenses",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: expenseSeries
		)
		
		let interestSeries = TimeSeries<Double>(
			periods: periods,
			values: [60.0, 65.0, 70.0, 75.0]
		)
		let interestExpenseAccount = try Account(
			entity: entity,
			name: "Interest Expense",
			incomeStatementRole: .interestExpense,
			timeSeries: interestSeries
		)
		
		return try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenueAccount, cogsAccount, expenseAccount, interestExpenseAccount]
		)
	}
	
	public func createTestBalanceSheet() throws -> BalanceSheet<Double> {
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
			balanceSheetRole: .otherCurrentAssets,
			timeSeries: assetSeries
		)
		
		let inventorySeries = TimeSeries<Double>(
			periods: periods,
			values: [1100.0, 1200.0, 1400.0, 1600.0]
		)
		let inventoryAccount = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: inventorySeries
		)
		
		let receivablesSeries = TimeSeries<Double>(
			periods: periods,
			values: [100.0, 200.0, 400.0, 600.0]
		)
		let accountsReceivable = try Account(
			entity: entity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			timeSeries: receivablesSeries
		)
		
			// Create liability account
		let liabilitySeries = TimeSeries<Double>(
			periods: periods,
			values: [2000.0, 1950.0, 1900.0, 1850.0]
		)
		let liabilityAccount = try Account(
			entity: entity,
			name: "Total Long-Term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: liabilitySeries
		)
		
		let payablesSeries = TimeSeries<Double>(
			periods: periods,
			values: [150.0, 250.0, 450.0, 650.0]
		)
		let accountsPayable = try Account(
			entity: entity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: payablesSeries
		)
		
			// Create equity account
		let equitySeries = TimeSeries<Double>(
			periods: periods,
			values: [3000.0, 3250.0, 3500.0, 3750.0]
		)
		let equityAccount = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: equitySeries
		)
		
		return try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [assetAccount, inventoryAccount, accountsReceivable, accountsPayable, liabilityAccount, equityAccount]
		)
	}
	
	public func createTestCashFlowStatement() throws -> CashFlowStatement<Double> {
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
			cashFlowRole: .netIncome,
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
			cashFlowRole: .capitalExpenditures,
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
			cashFlowRole: .proceedsFromDebt,
			timeSeries: financingSeries
		)
		
		return try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [operatingAccount, investingAccount, financingAccount]
		)
	}
}

