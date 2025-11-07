import Testing
import Foundation
@testable import BusinessMath

@Suite("Financial Validation Tests")
struct FinancialValidationTests {

	// MARK: - Helper Functions

	func makeEntity() -> Entity {
		return Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
	}

	func makePeriods() -> [Period] {
		return [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]
	}

	// MARK: - Balance Sheet Validation

	@Test("Balance sheet balances - valid")
	func balanceSheetBalancesValid() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Assets = 100, Liabilities = 40, Equity = 60 → Balanced
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [100.0, 110.0]),
			assetType: .cashAndEquivalents
		)

		let debt = try Account(
			entity: entity,
			name: "Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: periods, values: [40.0, 45.0]),
			liabilityType: .longTermDebt
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [60.0, 65.0]),
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [debt],
			equityAccounts: [equity]
		)

		let rule = FinancialValidation.BalanceSheetBalances<Double>()
		let context = ValidationContext(fieldName: "Balance Sheet")

		let result = rule.validate(balanceSheet, context: context)

		#expect(result.isValid)
		#expect(result.errors.isEmpty)
	}

	@Test("Balance sheet doesn't balance - invalid")
	func balanceSheetUnbalanced() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Assets = 100, Liabilities = 40, Equity = 50 → Unbalanced (off by 10)
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [100.0, 110.0]),
			assetType: .cashAndEquivalents
		)

		let debt = try Account(
			entity: entity,
			name: "Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: periods, values: [40.0, 45.0]),
			liabilityType: .longTermDebt
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [50.0, 55.0]),  // Should be 60, 65
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [debt],
			equityAccounts: [equity]
		)

		let rule = FinancialValidation.BalanceSheetBalances<Double>()
		let context = ValidationContext(fieldName: "Balance Sheet")

		let result = rule.validate(balanceSheet, context: context)

		#expect(!result.isValid)
		#expect(result.errors.count > 0)
		#expect(result.errors[0].message.contains("do not equal"))
	}

	@Test("Balance sheet with tolerance")
	func balanceSheetWithTolerance() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Slightly off but within tolerance
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [100.0, 110.0]),
			assetType: .cashAndEquivalents
		)

		let debt = try Account(
			entity: entity,
			name: "Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: periods, values: [40.0, 45.0]),
			liabilityType: .longTermDebt
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [60.005, 65.005]),  // Within 0.01 tolerance
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [debt],
			equityAccounts: [equity]
		)

		let rule = FinancialValidation.BalanceSheetBalances<Double>(tolerance: 0.01)
		let context = ValidationContext(fieldName: "Balance Sheet")

		let result = rule.validate(balanceSheet, context: context)

		#expect(result.isValid)
	}

	// MARK: - Revenue Validation

	@Test("Positive revenue - valid")
	func positiveRevenueValid() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: []
		)

		let rule = FinancialValidation.PositiveRevenue<Double>()
		let context = ValidationContext(fieldName: "Income Statement")

		let result = rule.validate(incomeStatement, context: context)

		#expect(result.isValid)
	}

	@Test("Negative revenue - invalid")
	func negativeRevenue() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [-100_000.0, 110_000.0])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: []
		)

		let rule = FinancialValidation.PositiveRevenue<Double>()
		let context = ValidationContext(fieldName: "Income Statement")

		let result = rule.validate(incomeStatement, context: context)

		#expect(!result.isValid)
		#expect(result.errors.count == 1)
		#expect(result.errors[0].message.contains("negative"))
	}

	// MARK: - Gross Margin Validation

	@Test("Reasonable gross margin - valid")
	func reasonableGrossMargin() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [60_000.0, 65_000.0]),
			expenseType: .costOfGoodsSold
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		let rule = FinancialValidation.ReasonableGrossMargin<Double>()
		let context = ValidationContext(fieldName: "Income Statement")

		let result = rule.validate(incomeStatement, context: context)

		#expect(result.isValid)
		#expect(result.warnings.isEmpty)
	}

	@Test("Unusual gross margin - warning")
	func unusualGrossMargin() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			type: .expense,
			timeSeries: TimeSeries(periods: periods, values: [120_000.0, 130_000.0]),  // Higher than revenue!
			expenseType: .costOfGoodsSold
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs]
		)

		let rule = FinancialValidation.ReasonableGrossMargin<Double>()
		let context = ValidationContext(fieldName: "Income Statement")

		let result = rule.validate(incomeStatement, context: context)

		#expect(result.isValid)  // Warnings don't fail validation
		#expect(result.warnings.count > 0)
		#expect(result.warnings[0].message.contains("Unusual"))
	}

	// MARK: - Cash Flow Reconciliation

	@Test("Cash flow reconciles with balance sheet - valid")
	func cashFlowReconciles() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Cash: Q1 = 50,000, Q2 = 60,000 (change of +10,000)
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0, 60_000.0]),
			assetType: .cashAndEquivalents
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0, 60_000.0]),
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Create cash flow statement with matching net change
		// Operating: 15,000 per period
		// Investing: -8,000 per period
		// Financing: 3,000 per period
		// Net: 10,000 per period (matches cash change in Q2)
		
		let operatingCF = try Account(
			entity: entity,
			name: "Cash from Operations",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [15_000.0, 15_000.0])
		)

		let investingCF = try Account(
			entity: entity,
			name: "Cash from Investing",
			type: .investing,
			timeSeries: TimeSeries(periods: periods, values: [-8_000.0, -8_000.0])
		)

		let financingCF = try Account(
			entity: entity,
			name: "Cash from Financing",
			type: .financing,
			timeSeries: TimeSeries(periods: periods, values: [3_000.0, 3_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingCF],
			investingAccounts: [investingCF],
			financingAccounts: [financingCF]
		)

		let rule = FinancialValidation.CashFlowReconciliation<Double>()
		let context = ValidationContext(fieldName: "Cash Flow Reconciliation")

		let result = rule.validate((cashFlowStmt, balanceSheet), context: context)

		#expect(result.isValid)
		#expect(result.errors.isEmpty)
	}

	@Test("Cash flow doesn't reconcile - invalid")
	func cashFlowDoesNotReconcile() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Cash: Q1 = 50,000, Q2 = 60,000 (change of +10,000)
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0, 60_000.0]),
			assetType: .cashAndEquivalents
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0, 60_000.0]),
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Cash flow statement with NON-matching net change
		// Net: 15,000 per period (doesn't match +10,000 cash change)
		let operatingCF = try Account(
			entity: entity,
			name: "Cash from Operations",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [15_000.0, 15_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingCF],
			investingAccounts: [],
			financingAccounts: []
		)

		let rule = FinancialValidation.CashFlowReconciliation<Double>()
		let context = ValidationContext(fieldName: "Cash Flow Reconciliation")

		let result = rule.validate((cashFlowStmt, balanceSheet), context: context)

		#expect(!result.isValid)
		#expect(result.errors.count > 0)
		#expect(result.errors[0].message.contains("does not reconcile"))
	}

	@Test("Cash flow reconciliation with tolerance")
	func cashFlowReconciliationWithTolerance() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Cash: Q1 = 50,000, Q2 = 60,000 (change of +10,000)
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0, 60_000.0]),
			assetType: .cashAndEquivalents
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0, 60_000.0]),
			equityType: .commonStock
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		// Cash flow slightly off (10,004 vs 10,000) but within tolerance of 5
		let operatingCF = try Account(
			entity: entity,
			name: "Cash from Operations",
			type: .operating,
			timeSeries: TimeSeries(periods: periods, values: [10_004.0, 10_004.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operatingCF],
			investingAccounts: [],
			financingAccounts: []
		)

		let rule = FinancialValidation.CashFlowReconciliation<Double>(tolerance: 5.0)
		let context = ValidationContext(fieldName: "Cash Flow Reconciliation")

		let result = rule.validate((cashFlowStmt, balanceSheet), context: context)

		#expect(result.isValid)
	}
}
