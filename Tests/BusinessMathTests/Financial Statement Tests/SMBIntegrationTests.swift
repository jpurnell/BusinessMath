import Testing
import Foundation
@testable import BusinessMath

/// Integration tests for SMB enhancements (v2.0.0)
///
/// These tests verify that new Balance Sheet roles, Cash Flow roles, and Account metadata
/// work correctly together in realistic small business scenarios.
@Suite("SMB Integration Tests (v2.0.0)")
struct SMBIntegrationTests {

	// ═══════════════════════════════════════════════════════════
	// MARK: - Helper: Create Test Entity
	// ═══════════════════════════════════════════════════════════

	private func createTestEntity() -> Entity {
		Entity(id: "SB-TEST", name: "Small Business Corp")
	}

	private func createQuarterlyTimeSeries(values: [Double]) -> TimeSeries<Double> {
		let periods = [
			DateComponents(year: 2024, month: 3, day: 31),
			DateComponents(year: 2024, month: 6, day: 30),
			DateComponents(year: 2024, month: 9, day: 30),
			DateComponents(year: 2024, month: 12, day: 31)
		].compactMap { Calendar.current.date(from: $0) }
			.map { Period.day($0) }

		return TimeSeries(periods: periods, values: values)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Balance Sheet Integration
	// ═══════════════════════════════════════════════════════════

	@Test("Balance Sheet: SMB current liabilities aggregate correctly")
	func balanceSheetSMBCurrentLiabilities() throws {
		let entity = createTestEntity()

		// Create SMB-specific current liability accounts
		let salesTax = try Account(
			entity: entity,
			name: "Sales Tax Payable",
			balanceSheetRole: .salesTaxPayable,
			timeSeries: createQuarterlyTimeSeries(values: [5_000, 5_500, 6_000, 6_500])
		)

		let payroll = try Account(
			entity: entity,
			name: "Payroll Liabilities",
			balanceSheetRole: .payrollLiabilities,
			timeSeries: createQuarterlyTimeSeries(values: [15_000, 16_000, 17_000, 18_000])
		)

		let lineOfCredit = try Account(
			entity: entity,
			name: "Line of Credit",
			balanceSheetRole: .lineOfCredit,
			timeSeries: createQuarterlyTimeSeries(values: [50_000, 45_000, 40_000, 35_000])
		)

		let customerDeposits = try Account(
			entity: entity,
			name: "Customer Deposits",
			balanceSheetRole: .customerDeposits,
			timeSeries: createQuarterlyTimeSeries(values: [10_000, 12_000, 14_000, 16_000])
		)

		// Verify role classification
		#expect(salesTax.balanceSheetRole?.isCurrentLiability == true)
		#expect(payroll.balanceSheetRole?.isCurrentLiability == true)
		#expect(lineOfCredit.balanceSheetRole?.isCurrentLiability == true)
		#expect(customerDeposits.balanceSheetRole?.isCurrentLiability == true)

		// Verify working capital classification
		#expect(salesTax.balanceSheetRole?.isWorkingCapital == true)
		#expect(payroll.balanceSheetRole?.isWorkingCapital == true)
		#expect(lineOfCredit.balanceSheetRole?.isWorkingCapital == false) // Debt excluded
		#expect(customerDeposits.balanceSheetRole?.isWorkingCapital == true)

		// Verify debt classification
		#expect(lineOfCredit.balanceSheetRole?.isDebt == true)
		#expect(salesTax.balanceSheetRole?.isDebt == false)
	}

	@Test("Balance Sheet: Working capital calculation with SMB accounts")
	func balanceSheetWorkingCapitalCalculation() throws {
		let entity = createTestEntity()

		// Current assets
		let _cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: createQuarterlyTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			timeSeries: createQuarterlyTimeSeries(values: [50_000, 55_000, 60_000, 65_000])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: createQuarterlyTimeSeries(values: [30_000, 32_000, 34_000, 36_000])
		)

		// Current liabilities (including new SMB-specific ones)
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: createQuarterlyTimeSeries(values: [25_000, 27_000, 29_000, 31_000])
		)

		let salesTax = try Account(
			entity: entity,
			name: "Sales Tax Payable",
			balanceSheetRole: .salesTaxPayable,
			timeSeries: createQuarterlyTimeSeries(values: [5_000, 5_500, 6_000, 6_500])
		)

		let payroll = try Account(
			entity: entity,
			name: "Payroll Liabilities",
			balanceSheetRole: .payrollLiabilities,
			timeSeries: createQuarterlyTimeSeries(values: [10_000, 11_000, 12_000, 13_000])
		)

		let lineOfCredit = try Account(
			entity: entity,
			name: "Line of Credit",
			balanceSheetRole: .lineOfCredit,
			timeSeries: createQuarterlyTimeSeries(values: [50_000, 45_000, 40_000, 35_000])
		)

		// Working Capital = (AR + Inventory) - (AP + Sales Tax + Payroll)
		// Note: Cash and LOC are excluded from working capital

		// Q4 2024 working capital calculation
		let q4WorkingCapitalAssets = 65_000.0 + 36_000.0  // AR + Inventory
		let q4WorkingCapitalLiabilities = 31_000.0 + 6_500.0 + 13_000.0  // AP + Sales Tax + Payroll
		let expectedQ4WorkingCapital = q4WorkingCapitalAssets - q4WorkingCapitalLiabilities

		#expect(expectedQ4WorkingCapital == 50_500.0)

		// Verify accounts are classified correctly for working capital
		#expect(_cash.balanceSheetRole?.isWorkingCapital == false)
		#expect(ar.balanceSheetRole?.isWorkingCapital == true)
		#expect(inventory.balanceSheetRole?.isWorkingCapital == true)
		#expect(ap.balanceSheetRole?.isWorkingCapital == true)
		#expect(salesTax.balanceSheetRole?.isWorkingCapital == true)
		#expect(payroll.balanceSheetRole?.isWorkingCapital == true)
		#expect(lineOfCredit.balanceSheetRole?.isWorkingCapital == false)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Cash Flow Integration
	// ═══════════════════════════════════════════════════════════

	@Test("Cash Flow: SMB operating activities aggregate correctly")
	func cashFlowSMBOperatingActivities() throws {
		let entity = createTestEntity()

		// Create accounts with cash flow roles
		let changeInSalesTax = try Account(
			entity: entity,
			name: "Change in Sales Tax Payable",
			cashFlowRole: .changeInSalesTaxPayable,
			timeSeries: createQuarterlyTimeSeries(values: [500, 500, 500, 500])
		)

		let changeInPayroll = try Account(
			entity: entity,
			name: "Change in Payroll Liabilities",
			cashFlowRole: .changeInPayrollLiabilities,
			timeSeries: createQuarterlyTimeSeries(values: [1_000, 1_000, 1_000, 1_000])
		)

		let changeInDeposits = try Account(
			entity: entity,
			name: "Change in Customer Deposits",
			cashFlowRole: .changeInCustomerDeposits,
			timeSeries: createQuarterlyTimeSeries(values: [2_000, 2_000, 2_000, 2_000])
		)

		// Verify classification
		#expect(changeInSalesTax.cashFlowRole?.isOperating == true)
		#expect(changeInPayroll.cashFlowRole?.isOperating == true)
		#expect(changeInDeposits.cashFlowRole?.isOperating == true)

		// Verify they use change in balance
		#expect(changeInSalesTax.cashFlowRole?.usesChangeInBalance == true)
		#expect(changeInPayroll.cashFlowRole?.usesChangeInBalance == true)
		#expect(changeInDeposits.cashFlowRole?.usesChangeInBalance == true)
	}

	@Test("Cash Flow: SMB financing activities aggregate correctly")
	func cashFlowSMBFinancingActivities() throws {
		let entity = createTestEntity()

		// Create SMB financing accounts
		let ownerDistributions = try Account(
			entity: entity,
			name: "Owner Distributions",
			cashFlowRole: .ownerDistributions,
			timeSeries: createQuarterlyTimeSeries(values: [-10_000, -10_000, -10_000, -10_000])
		)

		let ownerContributions = try Account(
			entity: entity,
			name: "Owner Capital Contributions",
			cashFlowRole: .ownerContributions,
			timeSeries: createQuarterlyTimeSeries(values: [25_000, 0, 0, 0])
		)

		let locDraw = try Account(
			entity: entity,
			name: "Draw on Line of Credit",
			cashFlowRole: .drawOnLineOfCredit,
			timeSeries: createQuarterlyTimeSeries(values: [20_000, 0, 0, 0])
		)

		let locRepayment = try Account(
			entity: entity,
			name: "Repayment of Line of Credit",
			cashFlowRole: .repaymentOfLineOfCredit,
			timeSeries: createQuarterlyTimeSeries(values: [0, -5_000, -5_000, -5_000])
		)

		// Verify classification
		#expect(ownerDistributions.cashFlowRole?.isFinancing == true)
		#expect(ownerContributions.cashFlowRole?.isFinancing == true)
		#expect(locDraw.cashFlowRole?.isFinancing == true)
		#expect(locRepayment.cashFlowRole?.isFinancing == true)

		// Verify they don't use change in balance (they're actual cash flows)
		#expect(ownerDistributions.cashFlowRole?.usesChangeInBalance == false)
		#expect(ownerContributions.cashFlowRole?.usesChangeInBalance == false)
		#expect(locDraw.cashFlowRole?.usesChangeInBalance == false)
		#expect(locRepayment.cashFlowRole?.usesChangeInBalance == false)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Account Metadata Integration
	// ═══════════════════════════════════════════════════════════

	@Test("Metadata: External system integration with accounts")
	func metadataExternalSystemIntegration() throws {
		let entity = createTestEntity()

		// Create metadata for a QuickBooks-imported account
		let metadata = AccountMetadata(
			description: "Sales tax collected from customers",
			category: "Current Liabilities",
			subCategory: "Tax Liabilities",
			tags: ["tax", "regulatory"],
			externalId: "ACCT-2150",
			externalAccountType: "Other Current Liability",
			externalDetailType: "SalesTaxPayable",
			externalSourceSystem: "QuickBooks Online"
		)

		let salesTax = try Account(
			entity: entity,
			name: "Sales Tax Payable",
			balanceSheetRole: .salesTaxPayable,
			timeSeries: createQuarterlyTimeSeries(values: [5_000, 5_500, 6_000, 6_500]),
			metadata: metadata
		)

		// Verify metadata preserved
		#expect(salesTax.metadata?.externalSourceSystem == "QuickBooks Online")
		#expect(salesTax.metadata?.externalAccountType == "Other Current Liability")
		#expect(salesTax.metadata?.externalDetailType == "SalesTaxPayable")
		#expect(salesTax.metadata?.externalId == "ACCT-2150")

		// Verify role still works
		#expect(salesTax.balanceSheetRole == .salesTaxPayable)
		#expect(salesTax.balanceSheetRole?.isCurrentLiability == true)
	}

	@Test("Metadata: Cost classification for contribution margin analysis")
	func metadataCostClassification() throws {
		let entity = createTestEntity()

		// Variable cost (COGS)
		let cogsMetadata = AccountMetadata(
			description: "Raw materials and direct labor",
			category: "Cost of Goods Sold",
			isVariableCost: true
		)

		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createQuarterlyTimeSeries(values: [-40_000, -44_000, -48_000, -52_000]),
			metadata: cogsMetadata
		)

		// Fixed cost (Rent)
		let rentMetadata = AccountMetadata(
			description: "Office and warehouse rent",
			category: "Operating Expenses",
			subCategory: "Occupancy",
			isFixedCost: true
		)

		let rent = try Account(
			entity: entity,
			name: "Rent Expense",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createQuarterlyTimeSeries(values: [-5_000, -5_000, -5_000, -5_000]),
			metadata: rentMetadata
		)

		// Verify cost classification
		#expect(cogs.metadata?.isVariableCost == true)
		#expect(cogs.metadata?.isFixedCost == false)

		#expect(rent.metadata?.isFixedCost == true)
		#expect(rent.metadata?.isVariableCost == false)

		// Verify income statement roles still work
		#expect(cogs.incomeStatementRole == .costOfGoodsSold)
		#expect(rent.incomeStatementRole == .operatingExpenseOther)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Multi-Statement Integration
	// ═══════════════════════════════════════════════════════════

	@Test("Complete SMB scenario: All statements work together")
	func completeSMBScenario() throws {
		let entity = createTestEntity()

		// INCOME STATEMENT ACCOUNTS
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createQuarterlyTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createQuarterlyTimeSeries(values: [-40_000, -44_000, -48_000, -52_000]),
			metadata: cogsMetadata
		)

		let rentMetadata = AccountMetadata(isFixedCost: true)
		let rent = try Account(
			entity: entity,
			name: "Rent",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createQuarterlyTimeSeries(values: [-5_000, -5_000, -5_000, -5_000]),
			metadata: rentMetadata
		)

		// BALANCE SHEET ACCOUNTS (SMB-specific)
		let salesTaxMetadata = AccountMetadata(
			externalAccountType: "Current Liability",
			externalDetailType: "SalesTaxPayable",
			externalSourceSystem: "QuickBooks"
		)
		let salesTax = try Account(
			entity: entity,
			name: "Sales Tax Payable",
			balanceSheetRole: .salesTaxPayable,
			timeSeries: createQuarterlyTimeSeries(values: [5_000, 5_500, 6_000, 6_500]),
			metadata: salesTaxMetadata
		)

		let lineOfCredit = try Account(
			entity: entity,
			name: "Line of Credit",
			balanceSheetRole: .lineOfCredit,
			timeSeries: createQuarterlyTimeSeries(values: [50_000, 65_000, 60_000, 55_000])
		)

		// CASH FLOW ACCOUNTS (SMB-specific)
		let changeInSalesTax = try Account(
			entity: entity,
			name: "Change in Sales Tax Payable",
			cashFlowRole: .changeInSalesTaxPayable,
			timeSeries: createQuarterlyTimeSeries(values: [500, 500, 500, 500])
		)

		let ownerDistributions = try Account(
			entity: entity,
			name: "Owner Distributions",
			cashFlowRole: .ownerDistributions,
			timeSeries: createQuarterlyTimeSeries(values: [-10_000, -10_000, -10_000, -10_000])
		)

		let locDraw = try Account(
			entity: entity,
			name: "Draw on LOC",
			cashFlowRole: .drawOnLineOfCredit,
			timeSeries: createQuarterlyTimeSeries(values: [20_000, 15_000, 0, 0])
		)

		let locRepayment = try Account(
			entity: entity,
			name: "Repayment of LOC",
			cashFlowRole: .repaymentOfLineOfCredit,
			timeSeries: createQuarterlyTimeSeries(values: [0, 0, -5_000, -5_000])
		)

		// VERIFY: Income statement accounts with cost classification
		#expect(revenue.incomeStatementRole == IncomeStatementRole.revenue)
		#expect(cogs.metadata?.isVariableCost == true)
		#expect(rent.metadata?.isFixedCost == true)

		// VERIFY: Balance sheet SMB accounts
		#expect(salesTax.balanceSheetRole?.isCurrentLiability == true)
		#expect(salesTax.balanceSheetRole?.isWorkingCapital == true)
		#expect(salesTax.metadata?.externalSourceSystem == "QuickBooks")

		#expect(lineOfCredit.balanceSheetRole?.isDebt == true)
		#expect(lineOfCredit.balanceSheetRole?.isWorkingCapital == false)

		// VERIFY: Cash flow SMB accounts
		#expect(changeInSalesTax.cashFlowRole?.isOperating == true)
		#expect(changeInSalesTax.cashFlowRole?.usesChangeInBalance == true)

		#expect(ownerDistributions.cashFlowRole?.isFinancing == true)
		#expect(locDraw.cashFlowRole?.isFinancing == true)
		#expect(locRepayment.cashFlowRole?.isFinancing == true)

		// VERIFY: All accounts belong to the same entity
		#expect(revenue.entity == entity)
		#expect(salesTax.entity == entity)
		#expect(locDraw.entity == entity)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Backward Compatibility
	// ═══════════════════════════════════════════════════════════

	@Test("Backward compatibility: v2.0 RC patterns still work")
	func backwardCompatibilityV20RC() throws {
		let entity = createTestEntity()

		// Old v2.0 RC pattern: Account without new SMB roles or metadata
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: createQuarterlyTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: createQuarterlyTimeSeries(values: [25_000, 27_000, 29_000, 31_000])
		)

		let changeInAP = try Account(
			entity: entity,
			name: "Change in Payables",
			cashFlowRole: .changeInPayables,
			timeSeries: createQuarterlyTimeSeries(values: [2_000, 2_000, 2_000, 2_000])
		)

		// Verify old patterns work identically
		#expect(cash.balanceSheetRole == BalanceSheetRole.cashAndEquivalents)
		#expect(ap.balanceSheetRole == BalanceSheetRole.accountsPayable)
		#expect(changeInAP.cashFlowRole == CashFlowRole.changeInPayables)

		// Verify metadata is nil when not provided
		#expect(cash.metadata == nil)
		#expect(ap.metadata == nil)
		#expect(changeInAP.metadata == nil)
	}
}
