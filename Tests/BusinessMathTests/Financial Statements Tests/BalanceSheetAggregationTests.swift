import Testing
import Foundation
@testable import BusinessMath

/// Tests for BalanceSheet single-array design with role-based aggregation
///
/// These tests verify that:
/// 1. BalanceSheet accepts a single accounts array
/// 2. Accounts are validated to have balanceSheetRole
/// 3. Assets, liabilities, and equity aggregate correctly
/// 4. Role-based accessors work (currentAssetAccounts, liabilityAccounts, etc.)
/// 5. Accounting equation (A = L + E) is computed correctly
@Suite("Balance Sheet Aggregation Tests")
struct BalanceSheetAggregationTests {

	// MARK: - Test Fixtures

	let testEntity = Entity(id: "TEST", primaryType: .ticker, name: "Test Corp")
	let testPeriods = [
		Period.quarter(year: 2024, quarter: 1),
		Period.quarter(year: 2024, quarter: 2),
		Period.quarter(year: 2024, quarter: 3),
		Period.quarter(year: 2024, quarter: 4)
	]

	// MARK: - Single Array Initializer Tests

	@Test("BalanceSheet accepts single accounts array")
	func testSingleArrayInitializer() throws {
		let cash = try Account<Double>(
			entity: testEntity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let debt = try Account<Double>(
			entity: testEntity,
			name: "Long-term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 480, 460, 440])
		)

		let equity = try Account<Double>(
			entity: testEntity,
			name: "Retained Earnings",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 620, 740, 860])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [cash, debt, equity]  // Single array!
		)

		#expect(bs.accounts.count == 3)
		#expect(bs.entity.id == "TEST")
		#expect(bs.periods.count == 4)
	}

	// MARK: - Role Validation Tests

	@Test("BalanceSheet validates all accounts have BS roles")
	func testRoleValidation() throws {
		let incomeStatementAccount = try Account<Double>(
			entity: testEntity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		#expect(throws: FinancialModelError.accountMissingRole(statement: .balanceSheet, accountName: "Revenue")) {
			try BalanceSheet(
				entity: testEntity,
				periods: testPeriods,
				accounts: [incomeStatementAccount]  // Wrong role type!
			)
		}
	}

	@Test("BalanceSheet accepts multi-role accounts")
	func testMultiRoleAccountAccepted() throws {
		// Inventory has both BS and CFS roles - should be accepted
		let inventory = try Account<Double>(
			entity: testEntity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 520, 540, 560])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [inventory]
		)

		#expect(bs.accounts.count == 1)
	}

	// MARK: - Asset Aggregation Tests

	@Test("BalanceSheet aggregates current assets correctly")
	func testCurrentAssetAggregation() throws {
		let cash = try Account<Double>(
			entity: testEntity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let receivables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 550, 600, 650])
		)

		let inventory = try Account<Double>(
			entity: testEntity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: testPeriods, values: [300, 320, 340, 360])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [cash, receivables, inventory]
		)

		// Total current assets = sum of all current assets
		#expect(bs.currentAssets[testPeriods[0]]! == 1800.0)  // 1000 + 500 + 300
		#expect(bs.currentAssets[testPeriods[1]]! == 1970.0)  // 1100 + 550 + 320
	}

	@Test("BalanceSheet aggregates non-current assets correctly")
	func testNonCurrentAssetAggregation() throws {
		let ppe = try Account<Double>(
			entity: testEntity,
			name: "PP&E",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: testPeriods, values: [5000, 5200, 5400, 5600])
		)

		let intangibles = try Account<Double>(
			entity: testEntity,
			name: "Intangible Assets",
			balanceSheetRole: .intangibleAssets,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 980, 960, 940])
		)

		let goodwill = try Account<Double>(
			entity: testEntity,
			name: "Goodwill",
			balanceSheetRole: .goodwill,
			timeSeries: TimeSeries(periods: testPeriods, values: [2000, 2000, 2000, 2000])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [ppe, intangibles, goodwill]
		)

		// Total non-current assets = sum of all non-current assets
		#expect(bs.nonCurrentAssets[testPeriods[0]]! == 8000.0)  // 5000 + 1000 + 2000
		#expect(bs.nonCurrentAssets[testPeriods[1]]! == 8180.0)  // 5200 + 980 + 2000
	}

	// MARK: - Liability Aggregation Tests

	@Test("BalanceSheet aggregates current liabilities correctly")
	func testCurrentLiabilityAggregation() throws {
		let payables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: testPeriods, values: [400, 420, 440, 460])
		)

		let accrued = try Account<Double>(
			entity: testEntity,
			name: "Accrued Liabilities",
			balanceSheetRole: .accruedLiabilities,
			timeSeries: TimeSeries(periods: testPeriods, values: [200, 210, 220, 230])
		)

		let shortTermDebt = try Account<Double>(
			entity: testEntity,
			name: "Short-term Debt",
			balanceSheetRole: .shortTermDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [100, 90, 80, 70])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [payables, accrued, shortTermDebt]
		)

		// Total current liabilities = sum of all current liabilities
		#expect(bs.currentLiabilities[testPeriods[0]]! == 700.0)  // 400 + 200 + 100
		#expect(bs.currentLiabilities[testPeriods[1]]! == 720.0)  // 420 + 210 + 90
	}

	@Test("BalanceSheet aggregates non-current liabilities correctly")
	func testNonCurrentLiabilityAggregation() throws {
		let longTermDebt = try Account<Double>(
			entity: testEntity,
			name: "Long-term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [2000, 1900, 1800, 1700])
		)

		let deferredTax = try Account<Double>(
			entity: testEntity,
			name: "Deferred Tax Liabilities",
			balanceSheetRole: .deferredTaxLiabilities,
			timeSeries: TimeSeries(periods: testPeriods, values: [300, 310, 320, 330])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [longTermDebt, deferredTax]
		)

		// Total non-current liabilities = sum of all non-current liabilities
		#expect(bs.nonCurrentLiabilities[testPeriods[0]]! == 2300.0)  // 2000 + 300
		#expect(bs.nonCurrentLiabilities[testPeriods[1]]! == 2210.0)  // 1900 + 310
	}

	// MARK: - Equity Aggregation Tests

	@Test("BalanceSheet aggregates equity correctly")
	func testEquityAggregation() throws {
		let commonStock = try Account<Double>(
			entity: testEntity,
			name: "Common Stock",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1000, 1000, 1000])
		)

		let retainedEarnings = try Account<Double>(
			entity: testEntity,
			name: "Retained Earnings",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: testPeriods, values: [5000, 5300, 5600, 5900])
		)

		let apic = try Account<Double>(
			entity: testEntity,
			name: "Additional Paid-In Capital",
			balanceSheetRole: .additionalPaidInCapital,
			timeSeries: TimeSeries(periods: testPeriods, values: [2000, 2000, 2000, 2000])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [commonStock, retainedEarnings, apic]
		)

		// Total equity = sum of all equity accounts
		#expect(bs.totalEquity[testPeriods[0]]! == 8000.0)  // 1000 + 5000 + 2000
		#expect(bs.totalEquity[testPeriods[1]]! == 8300.0)  // 1000 + 5300 + 2000
	}

	// MARK: - Role-Based Accessor Tests

	@Test("BalanceSheet provides role-specific accessors")
	func testRoleBasedAccessors() throws {
		let cash = try Account<Double>(
			entity: testEntity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let inventory = try Account<Double>(
			entity: testEntity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 520, 540, 560])
		)

		let ppe = try Account<Double>(
			entity: testEntity,
			name: "PP&E",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: testPeriods, values: [5000, 5200, 5400, 5600])
		)

		let payables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: testPeriods, values: [400, 420, 440, 460])
		)

		let debt = try Account<Double>(
			entity: testEntity,
			name: "Long-term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [2000, 1900, 1800, 1700])
		)

		let equity = try Account<Double>(
			entity: testEntity,
			name: "Retained Earnings",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: testPeriods, values: [4100, 4500, 4900, 5300])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [cash, inventory, ppe, payables, debt, equity]
		)

		// Role-based accessors should filter correctly
		#expect(bs.currentAssetAccounts.count == 2)  // Cash + Inventory
		#expect(bs.nonCurrentAssetAccounts.count == 1)  // PP&E
		#expect(bs.assetAccounts.count == 3)  // All assets

		#expect(bs.currentLiabilityAccounts.count == 1)  // Payables
		#expect(bs.nonCurrentLiabilityAccounts.count == 1)  // Debt
		#expect(bs.liabilityAccounts.count == 2)  // All liabilities

		#expect(bs.equityAccounts.count == 1)  // Retained Earnings
	}

	// MARK: - Computed Property Tests

	@Test("BalanceSheet computes total assets correctly")
	func testTotalAssetsComputation() throws {
		let cash = try Account<Double>(
			entity: testEntity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let ppe = try Account<Double>(
			entity: testEntity,
			name: "PP&E",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: testPeriods, values: [5000, 5200, 5400, 5600])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [cash, ppe]
		)

		// Total assets = current + non-current
		#expect(bs.totalAssets[testPeriods[0]]! == 6000.0)  // 1000 + 5000
		#expect(bs.totalAssets[testPeriods[1]]! == 6300.0)  // 1100 + 5200
	}

	@Test("BalanceSheet computes total liabilities correctly")
	func testTotalLiabilitiesComputation() throws {
		let payables = try Account<Double>(
			entity: testEntity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: testPeriods, values: [400, 420, 440, 460])
		)

		let debt = try Account<Double>(
			entity: testEntity,
			name: "Long-term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [2000, 1900, 1800, 1700])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [payables, debt]
		)

		// Total liabilities = current + non-current
		#expect(bs.totalLiabilities[testPeriods[0]]! == 2400.0)  // 400 + 2000
		#expect(bs.totalLiabilities[testPeriods[1]]! == 2320.0)  // 420 + 1900
	}

	@Test("BalanceSheet validates accounting equation")
	func testAccountingEquationValidation() throws {
		// A = L + E should hold
		let cash = try Account<Double>(
			entity: testEntity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: testPeriods, values: [10000, 11000, 12000, 13000])
		)

		let debt = try Account<Double>(
			entity: testEntity,
			name: "Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: testPeriods, values: [6000, 5800, 5600, 5400])
		)

		let equity = try Account<Double>(
			entity: testEntity,
			name: "Equity",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: testPeriods, values: [4000, 5200, 6400, 7600])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [cash, debt, equity]
		)

		// Assets = Liabilities + Equity
		for period in testPeriods {
			let assets = bs.totalAssets[period]!
			let liabilities = bs.totalLiabilities[period]!
			let equityValue = bs.totalEquity[period]!

			#expect(abs(assets - (liabilities + equityValue)) < 0.01)
		}
	}

	@Test("BalanceSheet computes working capital correctly")
	func testWorkingCapitalComputation() throws {
		let cash = try Account<Double>(
			entity: testEntity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: testPeriods, values: [1000, 1100, 1200, 1300])
		)

		let receivables = try Account<Double>(
			entity: testEntity,
			name: "AR",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: testPeriods, values: [500, 550, 600, 650])
		)

		let payables = try Account<Double>(
			entity: testEntity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: testPeriods, values: [300, 320, 340, 360])
		)

		let bs = try BalanceSheet(
			entity: testEntity,
			periods: testPeriods,
			accounts: [cash, receivables, payables]
		)

		// Working Capital = Current Assets - Current Liabilities
		// Q1: 1500 - 300 = 1200
		#expect(bs.workingCapital[testPeriods[0]]! == 1200.0)
		#expect(bs.workingCapital[testPeriods[1]]! == 1330.0)  // 1650 - 320
	}
}
