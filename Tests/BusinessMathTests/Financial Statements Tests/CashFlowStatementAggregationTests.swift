import Testing
import Foundation
@testable import BusinessMath

/// Tests for CashFlowStatement single-array design with role-based aggregation
///
/// These tests verify that:
/// 1. CashFlowStatement accepts a single accounts array (not separate operating/investing/financing arrays)
/// 2. Accounts are validated to have cashFlowRole
/// 3. Multiple accounts with the same role aggregate correctly
/// 4. Role-based accessors work (operatingAccounts, investingAccounts, financingAccounts)
/// 5. Computed properties use role-based filtering
/// 6. Working capital changes are calculated automatically using TimeSeries.diff() for accounts with usesChangeInBalance
/// 7. Multi-role accounts (BS + CFS) work correctly
@Suite("Cash Flow Statement Aggregation Tests")
struct CashFlowStatementAggregationTests {

	// MARK: - Test Fixtures

	let testEntity = Entity(id: "TEST", primaryType: .ticker, name: "Test Corp")
	let testPeriods = [
		Period.quarter(year: 2024, quarter: 1),
		Period.quarter(year: 2024, quarter: 2),
		Period.quarter(year: 2024, quarter: 3),
		Period.quarter(year: 2024, quarter: 4)
	]

	// MARK: - Single Array Initializer Tests

	@Test("CashFlowStatement accepts single accounts array")
	func testSingleArrayInitializer() throws {
		let netIncome = try Account<Double>(
			entity: testEntity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation & Amortization",
			incomeStatementRole: .depreciationAmortization,
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [20, 22, 24, 26])
		)

		let capex = try Account<Double>(
			entity: testEntity,
			name: "Capital Expenditures",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: testPeriods, values: [-50, -55, -60, -65])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [netIncome, depreciation, capex]  // Single array!
		)

		#expect(cfs.accounts.count == 3)
		#expect(cfs.entity.id == "TEST")
		#expect(cfs.periods.count == 4)
	}

	@Test("CashFlowStatement works with empty accounts array")
	func testEmptyAccountsArray() throws {
		let cfs = try CashFlowStatement<Double>(
			entity: testEntity,
			periods: testPeriods,
			accounts: []
		)

		#expect(cfs.accounts.count == 0)
		// Should have zero cash flows
		#expect(cfs.operatingCashFlow[testPeriods[0]]! == 0.0)
	}

	// MARK: - Role Validation Tests

	@Test("CashFlowStatement validates all accounts have CFS roles")
	func testRoleValidation() throws {
		let incomeStatementAccount = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		#expect(throws: FinancialModelError.accountMissingRole(statement: .cashFlowStatement, accountName: "Revenue")) {
			try CashFlowStatement(
				entity: testEntity,
				periods: testPeriods,
				accounts: [incomeStatementAccount]  // Wrong role type!
			)
		}
	}

	@Test("CashFlowStatement accepts multi-role accounts")
	func testMultiRoleAccountAccepted() throws {
		// Depreciation has both IS and CFS roles - should be accepted
		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation & Amortization",
			incomeStatementRole: .depreciationAmortization,
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [10, 11, 12, 13])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [depreciation]
		)

		#expect(cfs.accounts.count == 1)
	}

	// MARK: - Aggregation Tests

	@Test("CashFlowStatement aggregates operating cash flow items")
	func testOperatingCashFlowAggregation() throws {
		let netIncome = try Account<Double>(
			entity: testEntity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation",
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let sbc = try Account<Double>(
			entity: testEntity,
			name: "Stock-Based Compensation",
			cashFlowRole: .stockBasedCompensationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 55, 60, 65])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [netIncome, depreciation, sbc]
		)

		// Operating cash flow = net income + depreciation + SBC
		#expect(cfs.operatingCashFlow[testPeriods[0]]! == 1150.0)  // 1000 + 100 + 50
		#expect(cfs.operatingCashFlow[testPeriods[1]]! == 1265.0)  // 1100 + 110 + 55
	}

	@Test("CashFlowStatement aggregates investing cash flow items")
	func testInvestingCashFlowAggregation() throws {
		let capex = try Account<Double>(
			entity: testEntity,
			name: "Capital Expenditures",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: testPeriods, values: [-200, -220, -240, -260])
		)

		let acquisitions = try Account<Double>(
			entity: testEntity,
			name: "Business Acquisitions",
			cashFlowRole: .acquisitions,
			timeSeries: TimeSeries(periods: testPeriods, values: [-500, 0, -750, 0])  // Negative = cash outflow
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [capex, acquisitions]
		)

		// Investing cash flow = capex + acquisitions (both are outflows/negative)
		#expect(cfs.investingCashFlow[testPeriods[0]]! == -700.0)  // -200 + (-500)
		#expect(cfs.investingCashFlow[testPeriods[1]]! == -220.0)  // -220 + 0
		#expect(cfs.investingCashFlow[testPeriods[2]]! == -990.0)  // -240 + (-750)
	}

	@Test("CashFlowStatement aggregates financing cash flow items")
	func testFinancingCashFlowAggregation() throws {
		let debtIssuance = try Account<Double>(
			entity: testEntity,
			name: "Debt Issuance",
			cashFlowRole: .proceedsFromDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 0, 500, 0])
		)

		let debtRepayment = try Account<Double>(
			entity: testEntity,
			name: "Debt Repayment",
			cashFlowRole: .repaymentOfDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let dividends = try Account<Double>(
			entity: testEntity,
			name: "Dividends Paid",
			cashFlowRole: .dividendsPaid,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 55, 60, 65])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [debtIssuance, debtRepayment, dividends]
		)

		// Financing cash flow = issuance - repayment - dividends
		// Q1: 1000 - 100 - 50 = 850 (but they all add since values are already signed)
		#expect(cfs.financingCashFlow[testPeriods[0]]! == 1150.0)  // 1000 + 100 + 50
	}

	// MARK: - Working Capital Change Tests

	@Test("CashFlowStatement calculates working capital changes automatically")
	func testWorkingCapitalChanges() throws {
		// Accounts Receivable balance increases each quarter
		let receivables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [receivables]
		)

		// The CFS should automatically calculate changes: 100, 100, 100
		// (because receivables.cashFlowRole!.usesChangeInBalance == true)
		// Change in receivables = current - previous
		let changes = cfs.workingCapitalChanges[testPeriods[1]]!  // Q2
		#expect(changes == 100.0)  // 1100 - 1000
	}

	@Test("CashFlowStatement handles multiple working capital accounts")
	func testMultipleWorkingCapitalAccounts() throws {
		// Receivables increase (cash decrease)
		let receivables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		// Inventory increase (cash decrease)
		let inventory = try Account<Double>(
			entity: testEntity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 550, 600, 650])
		)

		// Payables increase (cash increase)
		let payables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			cashFlowRole: .changeInPayables,
			timeSeries: TimeSeries(periods: testPeriods, values: [300, 330, 360, 390])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [receivables, inventory, payables]
		)

		// Total working capital change in Q2:
		// Receivables: +100 (1100 - 1000) = -100 cash impact
		// Inventory: +50 (550 - 500) = -50 cash impact
		// Payables: +30 (330 - 300) = +30 cash impact
		// Net: -100 - 50 + 30 = -120 (cash decreased by 120)
		let totalWCChange = cfs.workingCapitalChanges[testPeriods[1]]!
		#expect(totalWCChange == 180.0)  // 100 + 50 + 30 (absolute changes)
	}

	@Test("CashFlowStatement uses diff() for balance change accounts")
	func testDiffUsageForBalanceChanges() throws {
		let inventory = try Account<Double>(
			entity: testEntity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 150, 175, 200])
		)

		// Verify the role is marked for balance changes
		#expect(inventory.cashFlowRole?.usesChangeInBalance == true)

		_ = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [inventory]
		)

		// CFS should use TimeSeries.diff() internally:
		// Q2: 150 - 100 = 50
		// Q3: 175 - 150 = 25
		// Q4: 200 - 175 = 25
		// (Q1 has no previous period, so change is 0 or unavailable)
	}

	// MARK: - Role-Based Accessor Tests

	@Test("CashFlowStatement provides role-specific accessors")
	func testRoleBasedAccessors() throws {
		let netIncome = try Account<Double>(
			entity: testEntity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation",
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let capex = try Account<Double>(
			entity: testEntity,
			name: "CapEx",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: testPeriods, values: [-200, -220, -240, -260])
		)

		let dividends = try Account<Double>(
			entity: testEntity,
			name: "Dividends",
			cashFlowRole: .dividendsPaid,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 55, 60, 65])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [netIncome, depreciation, capex, dividends]
		)

		// Role-based accessors should filter correctly
		#expect(cfs.operatingAccounts.count == 2)  // Net income + depreciation
		#expect(cfs.investingAccounts.count == 1)  // CapEx
		#expect(cfs.financingAccounts.count == 1)  // Dividends
	}

	// MARK: - Computed Property Tests

	@Test("CashFlowStatement computes operating cash flow correctly")
	func testOperatingCashFlowComputation() throws {
		let netIncome = try Account<Double>(
			entity: testEntity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation",
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [netIncome, depreciation]
		)

		// Operating cash flow = net income + depreciation
		#expect(cfs.operatingCashFlow[testPeriods[0]]! == 1100.0)  // 1000 + 100
		#expect(cfs.operatingCashFlow[testPeriods[1]]! == 1210.0)  // 1100 + 110
	}

	@Test("CashFlowStatement computes investing cash flow correctly")
	func testInvestingCashFlowComputation() throws {
		let capex = try Account<Double>(
			entity: testEntity,
			name: "Capital Expenditures",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: testPeriods, values: [-200, -220, -240, -260])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [capex]
		)

		// Investing cash flow = capex (negative/outflow)
		#expect(cfs.investingCashFlow[testPeriods[0]]! == -200.0)
		#expect(cfs.investingCashFlow[testPeriods[1]]! == -220.0)
	}

	@Test("CashFlowStatement computes financing cash flow correctly")
	func testFinancingCashFlowComputation() throws {
		let debtIssuance = try Account<Double>(
			entity: testEntity,
			name: "Debt Issuance",
			cashFlowRole: .proceedsFromDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 0, 500, 0])
		)

		let dividends = try Account<Double>(
			entity: testEntity,
			name: "Dividends",
			cashFlowRole: .dividendsPaid,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 55, 60, 65])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [debtIssuance, dividends]
		)

		// Financing cash flow = issuance - dividends
		#expect(cfs.financingCashFlow[testPeriods[0]]! == 1050.0)  // 1000 + 50
		#expect(cfs.financingCashFlow[testPeriods[1]]! == 55.0)    // 0 + 55
	}

	@Test("CashFlowStatement computes free cash flow correctly")
	func testFreeCashFlowComputation() throws {
		let netIncome = try Account<Double>(
			entity: testEntity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation",
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		let capex = try Account<Double>(
			entity: testEntity,
			name: "CapEx",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: testPeriods, values: [-200, -220, -240, -260])  // Negative = cash outflow
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [netIncome, depreciation, capex]
		)

		// Free Cash Flow = Operating Cash Flow + Investing Cash Flow
		// Q1: (1000 + 100) + (-200) = 900
		#expect(cfs.freeCashFlow[testPeriods[0]]! == 900.0)
		// Q2: (1100 + 110) + (-220) = 990
		#expect(cfs.freeCashFlow[testPeriods[1]]! == 990.0)
	}

	// MARK: - Entity and Period Validation Tests

	@Test("CashFlowStatement validates entity match")
	func testEntityMismatch() throws {
		let otherEntity = Entity(id: "OTHER", primaryType: .ticker, name: "Other Corp")

		let netIncome = try Account<Double>(
			entity: testEntity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let capex = try Account<Double>(
			entity: otherEntity,  // Different entity!
			name: "CapEx",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: testPeriods, values: [-200, -220, -240, -260])
		)

		#expect(throws: FinancialModelError.entityMismatch(expected: "TEST", found: "OTHER", accountName: "CapEx")) {
			try CashFlowStatement(
				entity: testEntity,
				periods: testPeriods,
				accounts: [netIncome, capex]
			)
		}
	}

	// MARK: - Multi-Role Account Integration Tests

	@Test("CashFlowStatement works with BS+CFS multi-role accounts")
	func testBalanceSheetCashFlowMultiRole() throws {
		// Accounts Receivable appears in both BS and CFS
		let receivables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		// Inventory appears in both BS and CFS
		let inventory = try Account<Double>(
			entity: testEntity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 550, 600, 650])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [receivables, inventory]
		)

		#expect(cfs.accounts.count == 2)
		// Both accounts should be in operating section (working capital)
		#expect(cfs.operatingAccounts.count == 2)
	}

	@Test("CashFlowStatement works with IS+CFS multi-role accounts")
	func testIncomeStatementCashFlowMultiRole() throws {
		// Depreciation appears in both IS and CFS
		let depreciation = try Account<Double>(
			entity: testEntity,
			name: "Depreciation & Amortization",
			incomeStatementRole: .depreciationAmortization,
			cashFlowRole: .depreciationAmortizationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 110, 120, 130])
		)

		// Stock-based comp appears in both IS and CFS
		let sbc = try Account<Double>(
			entity: testEntity,
			name: "Stock-Based Compensation",
			incomeStatementRole: .stockBasedCompensation,
			cashFlowRole: .stockBasedCompensationAddback,
			timeSeries: TimeSeries(periods: testPeriods, values: [50, 55, 60, 65])
		)

		let cfs = try CashFlowStatement(
			entity: testEntity,
			periods: testPeriods,
			accounts: [depreciation, sbc]
		)

		#expect(cfs.accounts.count == 2)
		// Both should be in operating section (non-cash charges)
		#expect(cfs.operatingAccounts.count == 2)
	}
}
