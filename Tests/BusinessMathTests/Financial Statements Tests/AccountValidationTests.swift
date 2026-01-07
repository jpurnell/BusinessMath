import Testing
import Foundation
@testable import BusinessMath

/// Tests for Account validation with multi-role support
///
/// These tests verify that:
/// 1. Accounts must have at least one role (IS, BS, or CFS)
/// 2. Accounts can have single roles
/// 3. Accounts can have multiple roles (e.g., depreciation appears in both IS and CFS)
/// 4. The deprecated AccountType API still works for backward compatibility
@Suite("Account Validation Tests")
struct AccountValidationTests {

	// MARK: - Test Fixtures

	let testEntity = Entity(id: "TEST", primaryType: .ticker, name: "Test Corp")
	let testPeriods = [
		Period.quarter(year: 2024, quarter: 1),
		Period.quarter(year: 2024, quarter: 2)
	]

	var testSeries: TimeSeries<Double> {
		TimeSeries(periods: testPeriods, values: [100.0, 200.0])
	}

	// MARK: - Role Requirement Tests

	@Test("Account requires at least one role")
	func testAccountMustHaveRole() {
		#expect(throws: FinancialModelError.accountMustHaveAtLeastOneRole) {
			try Account<Double>(
				entity: testEntity,
				name: "Invalid Account",
				timeSeries: testSeries
				// No roles specified - should fail
			)
		}
	}

	@Test("Account with nil roles throws error")
	func testNilRolesThrowsError() {
		#expect(throws: FinancialModelError.accountMustHaveAtLeastOneRole) {
			try Account<Double>(
				entity: testEntity,
				name: "No Roles",
				incomeStatementRole: nil,
				balanceSheetRole: nil,
				cashFlowRole: nil,
				timeSeries: testSeries
			)
		}
	}

	// MARK: - Single Role Tests

	@Test("Account can have single income statement role")
	func testSingleIncomeStatementRole() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "Product Revenue",
			incomeStatementRole: .productRevenue,
			timeSeries: testSeries
		)

		#expect(account.incomeStatementRole == .productRevenue)
		#expect(account.balanceSheetRole == nil)
		#expect(account.cashFlowRole == nil)
		#expect(account.name == "Product Revenue")
		#expect(account.entity.id == "TEST")
	}

	@Test("Account can have single balance sheet role")
	func testSingleBalanceSheetRole() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "Cash and Cash Equivalents",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: testSeries
		)

		#expect(account.balanceSheetRole == .cashAndEquivalents)
		#expect(account.incomeStatementRole == nil)
		#expect(account.cashFlowRole == nil)
	}

	@Test("Account can have single cash flow role")
	func testSingleCashFlowRole() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "Capital Expenditures",
			cashFlowRole: .capitalExpenditures,
			timeSeries: testSeries
		)

		#expect(account.cashFlowRole == .capitalExpenditures)
		#expect(account.incomeStatementRole == nil)
		#expect(account.balanceSheetRole == nil)
	}

	// MARK: - Multiple Role Tests

	@Test("Account can have two roles: Income Statement + Cash Flow")
	func testTwoRolesIncomeStatementAndCashFlow() throws {
		// Depreciation appears in both IS (expense) and CFS (add-back)
		let account = try Account<Double>(
			entity: testEntity,
			name: "Depreciation & Amortization",
			incomeStatementRole: .depreciationAmortization,
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: testSeries
		)

		#expect(account.incomeStatementRole == .depreciationAmortization)
		#expect(account.cashFlowRole == .depreciationAmortizationAddback)
		#expect(account.balanceSheetRole == nil)
	}

	@Test("Account can have two roles: Balance Sheet + Cash Flow")
	func testTwoRolesBalanceSheetAndCashFlow() throws {
		// Accounts Receivable appears in BS (asset) and CFS (working capital change)
		let account = try Account<Double>(
			entity: testEntity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			cashFlowRole: .changeInReceivables,
			timeSeries: testSeries
		)

		#expect(account.balanceSheetRole == .accountsReceivable)
		#expect(account.cashFlowRole == .changeInReceivables)
		#expect(account.incomeStatementRole == nil)
	}

	@Test("Account can have all three roles")
	func testAllThreeRoles() throws {
		// Edge case: hypothetical account that appears in all three statements
		// Example: Interest expense (IS), Long-term debt (BS), Debt repayment (CFS)
		let account = try Account<Double>(
			entity: testEntity,
			name: "Debt Service Account",
			incomeStatementRole: .interestExpense,
			balanceSheetRole: .longTermDebt,
			cashFlowRole: .repaymentOfDebt,
			timeSeries: testSeries
		)

		#expect(account.incomeStatementRole == .interestExpense)
		#expect(account.balanceSheetRole == .longTermDebt)
		#expect(account.cashFlowRole == .repaymentOfDebt)
	}

	// MARK: - Working Capital Tests

	@Test("Inventory can have both BS and CFS roles")
	func testInventoryMultiRole() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			cashFlowRole: .changeInInventory,
			timeSeries: testSeries
		)

		#expect(account.balanceSheetRole == .inventory)
		#expect(account.cashFlowRole == .changeInInventory)

		// Verify the CFS role is marked as using balance changes
		#expect(account.cashFlowRole?.usesChangeInBalance == true)
	}

	@Test("Accounts Payable can have both BS and CFS roles")
	func testAccountsPayableMultiRole() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			cashFlowRole: .changeInPayables,
			timeSeries: testSeries
		)

		#expect(account.balanceSheetRole == .accountsPayable)
		#expect(account.cashFlowRole == .changeInPayables)
		#expect(account.cashFlowRole?.usesChangeInBalance == true)
	}

	// MARK: - Deprecated API Compatibility Tests
	// Note: Tests for deprecated AccountType initializer removed
	// Users should use the modern role-based API

	// MARK: - Validation Tests

	@Test("Account name cannot be empty")
	func testEmptyNameThrowsError() {
		#expect(throws: AccountError.invalidName) {
			try Account<Double>(
				entity: testEntity,
				name: "",
				incomeStatementRole: .revenue,
				timeSeries: testSeries
			)
		}
	}

	@Test("Account name cannot be whitespace only")
	func testWhitespaceNameThrowsError() {
		#expect(throws: AccountError.invalidName) {
			try Account<Double>(
				entity: testEntity,
				name: "   ",
				incomeStatementRole: .revenue,
				timeSeries: testSeries
			)
		}
	}

	@Test("Account timeSeries cannot be empty")
	func testEmptyTimeSeriesThrowsError() {
		let emptyTimeSeries = TimeSeries<Double>(periods: [], values: [])

		#expect(throws: AccountError.emptyTimeSeries) {
			try Account<Double>(
				entity: testEntity,
				name: "Invalid Account",
				incomeStatementRole: .revenue,
				timeSeries: emptyTimeSeries
			)
		}
	}

	// MARK: - Real-World Scenario Tests

	@Test("Revenue account has only IS role")
	func testRevenueAccountScenario() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "SaaS Subscription Revenue",
			incomeStatementRole: .subscriptionRevenue,
			timeSeries: testSeries
		)

		#expect(account.incomeStatementRole?.isRevenue == true)
		#expect(account.balanceSheetRole == nil)
		#expect(account.cashFlowRole == nil)
	}

	@Test("COGS account has only IS role")
	func testCOGSAccountScenario() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "Cost of Goods Sold",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: testSeries
		)

		#expect(account.incomeStatementRole?.isCostOfRevenue == true)
		#expect(account.balanceSheetRole == nil)
		#expect(account.cashFlowRole == nil)
	}

	@Test("Stock-based compensation has both IS and CFS roles")
	func testStockCompScenario() throws {
		let account = try Account<Double>(
			entity: testEntity,
			name: "Stock-Based Compensation",
			incomeStatementRole: .stockBasedCompensation,
			cashFlowRole: .stockBasedCompensationAddback,
			timeSeries: testSeries
		)

		#expect(account.incomeStatementRole?.isNonCashCharge == true)
		#expect(account.cashFlowRole?.isOperating == true)
		#expect(account.balanceSheetRole == nil)
	}
}
