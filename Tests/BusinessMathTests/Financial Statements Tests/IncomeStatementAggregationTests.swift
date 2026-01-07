import Testing
import Foundation
@testable import BusinessMath

/// Tests for IncomeStatement single-array design with role-based aggregation
///
/// These tests verify that:
/// 1. IncomeStatement accepts a single accounts array (not separate revenue/expense arrays)
/// 2. Accounts are validated to have incomeStatementRole
/// 3. Multiple accounts with the same role aggregate correctly
/// 4. Role-based accessors work (revenueAccounts, rdAccounts, etc.)
/// 5. Computed properties use role-based filtering
@Suite("Income Statement Aggregation Tests")
struct IncomeStatementAggregationTests {

	// MARK: - Test Fixtures

	let testEntity = Entity(id: "TEST", primaryType: .ticker, name: "Test Corp")
	let testPeriods = [
		Period.quarter(year: 2024, quarter: 1),
		Period.quarter(year: 2024, quarter: 2),
		Period.quarter(year: 2024, quarter: 3),
		Period.quarter(year: 2024, quarter: 4)
	]

	// MARK: - Single Array Initializer Tests

	@Test("IncomeStatement accepts single accounts array")
	func testSingleArrayInitializer() throws {
		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Product Revenue",
			incomeStatementRole: .productRevenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let cogs = try Account<Double>(
			entity: testEntity,
			name: "Cost of Goods Sold",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: testPeriods, values: [40, 44, 48, 52])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [revenue, cogs]  // Single array!
		)

		#expect(incomeStmt.accounts.count == 2)
		#expect(incomeStmt.entity.id == "TEST")
		#expect(incomeStmt.periods.count == 4)
	}

	@Test("IncomeStatement works with empty accounts array")
	func testEmptyAccountsArray() throws {
		let incomeStmt = try IncomeStatement<Double>(
			entity: testEntity,
			periods: testPeriods,
			accounts: []
		)

		#expect(incomeStmt.accounts.count == 0)
		// Should have zero revenue and expenses
		#expect(incomeStmt.totalRevenue[testPeriods[0]]! == 0.0)
	}

	// MARK: - Role Validation Tests

	@Test("IncomeStatement validates all accounts have IS roles")
	func testRoleValidation() throws {
		let balanceSheetAccount = try Account<Double>(
			entity: testEntity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		#expect(throws: FinancialModelError.accountMissingRole(statement: .incomeStatement, accountName: "Cash")) {
			try IncomeStatement(
				entity: testEntity,
				periods: testPeriods,
				accounts: [balanceSheetAccount]  // Wrong role type!
			)
		}
	}

	@Test("IncomeStatement accepts multi-role accounts")
	func testMultiRoleAccountAccepted() throws {
		// Depreciation has both IS and CFS roles - should be accepted
		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation & Amortization",
			incomeStatementRole: .depreciationAmortization,
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [10, 11, 12, 13])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [depreciation]
		)

		#expect(incomeStmt.accounts.count == 1)
	}

	// MARK: - Aggregation Tests

	@Test("IncomeStatement aggregates multiple revenue accounts")
	func testMultipleRevenueAggregation() throws {
		let usRevenue = try Account<Double>(
			entity: testEntity,
			name: "US Product Revenue",
			incomeStatementRole: .productRevenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let euRevenue = try Account<Double>(
			entity: testEntity,
			name: "EU Product Revenue",
			incomeStatementRole: .productRevenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 55, 60, 65])
		)

		let serviceRevenue = try Account<Double>(
			entity: testEntity,
			name: "Service Revenue",
			incomeStatementRole: .serviceRevenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [25, 30, 35, 40])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [usRevenue, euRevenue, serviceRevenue]
		)

		// Total revenue should be sum of all revenue accounts
		#expect(incomeStmt.totalRevenue[testPeriods[0]]! == 175.0)  // 100 + 50 + 25
		#expect(incomeStmt.totalRevenue[testPeriods[1]]! == 195.0)  // 110 + 55 + 30
		#expect(incomeStmt.totalRevenue[testPeriods[2]]! == 215.0)  // 120 + 60 + 35
		#expect(incomeStmt.totalRevenue[testPeriods[3]]! == 235.0)  // 130 + 65 + 40
	}

	@Test("IncomeStatement aggregates multiple expense accounts")
	func testMultipleExpenseAggregation() throws {
		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let rd = try Account<Double>(
			entity: testEntity,
			name: "Research & Development",
			incomeStatementRole: .researchAndDevelopment,
			timeSeries: TimeSeries(periods: testPeriods, values: [200, 210, 220, 230])
		)

		let sm = try Account<Double>(
			entity: testEntity,
			name: "Sales & Marketing",
			incomeStatementRole: .salesAndMarketing,
			timeSeries: TimeSeries(periods: testPeriods, values: [150, 160, 170, 180])
		)

		let ga = try Account<Double>(
			entity: testEntity,
			name: "General & Administrative",
			incomeStatementRole: .generalAndAdministrative,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 105, 110, 115])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [revenue, rd, sm, ga]
		)

		// Total operating expenses should be sum of R&D + S&M + G&A
		let q1OpEx = incomeStmt.operatingExpenses[testPeriods[0]]!
		#expect(q1OpEx == 450.0)  // 200 + 150 + 100
	}

	// MARK: - Role-Based Accessor Tests

	@Test("IncomeStatement provides role-specific accessors")
	func testRoleBasedAccessors() throws {
		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let rd = try Account<Double>(
			entity: testEntity,
			name: "R&D",
			incomeStatementRole: .researchAndDevelopment,
			timeSeries: TimeSeries(periods: testPeriods, values: [200, 210, 220, 230])
		)

		let sm = try Account<Double>(
			entity: testEntity,
			name: "S&M",
			incomeStatementRole: .salesAndMarketing,
			timeSeries: TimeSeries(periods: testPeriods, values: [150, 160, 170, 180])
		)

		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "D&A",
			incomeStatementRole: .depreciationAmortization,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 52, 54, 56])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [revenue, rd, sm, depreciation]
		)

		// Role-based accessors should filter correctly
		#expect(incomeStmt.revenueAccounts.count == 1)
		#expect(incomeStmt.revenueAccounts[0].name == "Revenue")

		#expect(incomeStmt.operatingExpenseAccounts.count == 2)  // R&D + S&M (not D&A)

		#expect(incomeStmt.nonCashChargeAccounts.count == 1)  // Just D&A
		#expect(incomeStmt.nonCashChargeAccounts[0].name == "D&A")
	}

	// MARK: - Computed Property Tests

	@Test("IncomeStatement computes gross profit correctly")
	func testGrossProfitComputation() throws {
		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let cogs = try Account<Double>(
			entity: testEntity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: testPeriods, values: [400, 440, 480, 520])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [revenue, cogs]
		)

		// Gross Profit = Revenue - COGS
		#expect(incomeStmt.grossProfit[testPeriods[0]]! == 600.0)  // 1000 - 400
		#expect(incomeStmt.grossProfit[testPeriods[1]]! == 660.0)  // 1100 - 440
	}

	@Test("IncomeStatement computes operating income correctly")
	func testOperatingIncomeComputation() throws {
		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let cogs = try Account<Double>(
			entity: testEntity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: testPeriods, values: [300, 330, 360, 390])
		)

		let rd = try Account<Double>(
			entity: testEntity,
			name: "R&D",
			incomeStatementRole: .researchAndDevelopment,
			timeSeries: TimeSeries(periods: testPeriods, values: [200, 210, 220, 230])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [revenue, cogs, rd]
		)

		// Operating Income = Revenue - COGS - Operating Expenses
		// Q1: 1000 - 300 - 200 = 500
		#expect(incomeStmt.operatingIncome[testPeriods[0]]! == 500.0)
	}

	@Test("IncomeStatement computes EBITDA correctly")
	func testEBITDAComputation() throws {
		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let rd = try Account<Double>(
			entity: testEntity,
			name: "R&D",
			incomeStatementRole: .researchAndDevelopment,
			timeSeries: TimeSeries(periods: testPeriods, values: [300, 320, 340, 360])
		)

		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "D&A",
			incomeStatementRole: .depreciationAmortization,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 105, 110, 115])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [revenue, rd, depreciation]
		)

		// EBITDA = Operating Income + D&A
		// Operating Income (EBIT) = Revenue - OpEx - D&A = 1000 - 300 - 100 = 600
		// EBITDA = 600 + 100 = 700
		#expect(incomeStmt.ebitda[testPeriods[0]]! == 700.0)
	}

	@Test("IncomeStatement computes net income correctly")
	func testNetIncomeComputation() throws {
		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let rd = try Account<Double>(
			entity: testEntity,
			name: "R&D",
			incomeStatementRole: .researchAndDevelopment,
			timeSeries: TimeSeries(periods: testPeriods, values: [200, 210, 220, 230])
		)

		let interest = try Account<Double>(
			entity: testEntity,
			name: "Interest Expense",
			incomeStatementRole: .interestExpense,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 45, 40, 35])
		)

		let tax = try Account<Double>(
			entity: testEntity,
			name: "Income Tax",
			incomeStatementRole: .incomeTaxExpense,
			timeSeries: TimeSeries(periods: testPeriods, values: [150, 169, 188, 207])
		)

		let incomeStmt = try IncomeStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [revenue, rd, interest, tax]
		)

		// Net Income = Revenue - All Expenses
		// Q1: 1000 - 200 - 50 - 150 = 600
		#expect(incomeStmt.netIncome[testPeriods[0]]! == 600.0)
	}

	// MARK: - Entity and Period Validation Tests

	@Test("IncomeStatement validates entity match")
	func testEntityMismatch() throws {
		let otherEntity = Entity(id: "OTHER", primaryType: .ticker, name: "Other Corp")

		let revenue = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let expense = try Account<Double>(
			entity: otherEntity,  // Different entity!
			name: "Expense",
			incomeStatementRole: .researchAndDevelopment,
			timeSeries: TimeSeries(periods: testPeriods, values: [200, 210, 220, 230])
		)

		#expect(throws: FinancialModelError.entityMismatch(expected: "TEST", found: "OTHER", accountName: "Expense")) {
			try IncomeStatement(
				entity: testEntity,
				periods: testPeriods,
				accounts: [revenue, expense]
			)
		}
	}
}
