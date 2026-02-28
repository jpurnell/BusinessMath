import Testing
import Foundation
@testable import BusinessMath

/// Tests for Working Capital Analysis (v2.0.0)
///
/// Verifies that working capital properties and turnover calculations work correctly
/// for operational analysis and LBO modeling.
@Suite("Working Capital Analysis (v2.0.0)")
struct WorkingCapitalTests {

	// ═══════════════════════════════════════════════════════════
	// MARK: - Net Working Capital Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Net working capital calculation")
	func netWorkingCapitalCalculation() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// Current assets
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0, 600_000.0])
		)

		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_200_000.0])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: periods, values: [800_000.0, 900_000.0])
		)

		// Current liabilities
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [600_000.0, 700_000.0])
		)

		let accruedExpenses = try Account(
			entity: entity,
			name: "Accrued Expenses",
			balanceSheetRole: .accruedLiabilities,
			timeSeries: TimeSeries(periods: periods, values: [200_000.0, 250_000.0])
		)

		// Non-current (should not affect NWC)
		let ppe = try Account(
			entity: entity,
			name: "PPE",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: periods, values: [5_000_000.0, 5_000_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Common Stock",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [6_500_000.0, 6_750_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, ar, inventory, ap, accruedExpenses, ppe, equity]
		)

		let nwc = balanceSheet.netWorkingCapital

		// Q1: ($500K + $1M + $800K) - ($600K + $200K) = $2.3M - $800K = $1.5M
		#expect(nwc[periods[0]]! == 1_500_000.0)

		// Q2: ($600K + $1.2M + $900K) - ($700K + $250K) = $2.7M - $950K = $1.75M
		#expect(nwc[periods[1]]! == 1_750_000.0)
	}

	@Test("Net working capital equals working capital")
	func netWorkingCapitalEqualsWorkingCapital() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, ap, equity]
		)

		#expect(balanceSheet.netWorkingCapital[periods[0]]! == balanceSheet.workingCapital[periods[0]]!)
	}

	@Test("Negative net working capital")
	func negativeNetWorkingCapital() throws {
		let entity = Entity(id: "RETAIL", name: "Retail Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Retail with negative cash conversion cycle
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0])
		)

		// High current liabilities (customer deposits, AP)
		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [1_200_000.0])
		)

		let deferredRevenue = try Account(
			entity: entity,
			name: "Deferred Revenue",
			balanceSheetRole: .deferredRevenue,
			timeSeries: TimeSeries(periods: periods, values: [800_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, inventory, ap, deferredRevenue, equity]
		)

		let nwc = balanceSheet.netWorkingCapital

		// ($500K + $1M) - ($1.2M + $800K) = $1.5M - $2M = -$500K
		#expect(nwc[periods[0]]! == -500_000.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Working Capital Components Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Working capital components breakdown")
	func workingCapitalComponentsBreakdown() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [300_000.0])
		)

		let ar = try Account(
			entity: entity,
			name: "AR",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: periods, values: [400_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [350_000.0])
		)

		let accrued = try Account(
			entity: entity,
			name: "Accrued Expenses",
			balanceSheetRole: .accruedLiabilities,
			timeSeries: TimeSeries(periods: periods, values: [150_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [700_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, ar, inventory, ap, accrued, equity]
		)

		let components: [BalanceSheetRole: TimeSeries<Double>] = balanceSheet.workingCapitalComponents

		// Should have 5 components (3 current assets + 2 current liabilities)
		#expect(components.count == 5)

		// Current assets (positive)
		#expect(components[BalanceSheetRole.cashAndEquivalents]![periods[0]]! == 300_000.0)
		#expect(components[BalanceSheetRole.accountsReceivable]![periods[0]]! == 500_000.0)
		#expect(components[BalanceSheetRole.inventory]![periods[0]]! == 400_000.0)

		// Current liabilities (negative - showing reduction in NWC)
		#expect(components[BalanceSheetRole.accountsPayable]![periods[0]]! == -350_000.0)
		#expect(components[BalanceSheetRole.accruedLiabilities]![periods[0]]! == -150_000.0)
	}

	@Test("Working capital components sum equals net working capital")
	func componentsSumEqualsNWC() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [200_000.0])
		)

		let ar = try Account(
			entity: entity,
			name: "AR",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: periods, values: [600_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [300_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, ar, ap, equity]
		)

		let components: [BalanceSheetRole: TimeSeries<Double>] = balanceSheet.workingCapitalComponents
		let nwc = balanceSheet.netWorkingCapital

		// Sum all components
		let sumOfComponents = components.values.reduce(0.0) { sum, timeSeries in
			sum + timeSeries[periods[0]]!
		}

		#expect(sumOfComponents == nwc[periods[0]]!)
	}

	@Test("Working capital components aggregate multiple accounts of same role")
	func componentsAggregateMultipleAccounts() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Two cash accounts
		let cash1 = try Account(
			entity: entity,
			name: "Operating Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let cash2 = try Account(
			entity: entity,
			name: "Petty Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [5_000.0])
		)

		// Two AP accounts
		let ap1 = try Account(
			entity: entity,
			name: "Trade Payables",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0])
		)

		let ap2 = try Account(
			entity: entity,
			name: "Other Payables",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [10_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [45_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash1, cash2, ap1, ap2, equity]
		)

		let components: [BalanceSheetRole: TimeSeries<Double>] = balanceSheet.workingCapitalComponents

		// Should aggregate both cash accounts
		#expect(components[BalanceSheetRole.cashAndEquivalents]![periods[0]]! == 105_000.0)

		// Should aggregate both AP accounts (negative)
		#expect(components[BalanceSheetRole.accountsPayable]![periods[0]]! == -60_000.0)
	}

	@Test("Working capital components exclude non-current items")
	func componentsExcludeNonCurrent() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Current assets
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		// Non-current assets (should NOT appear in components)
		let ppe = try Account(
			entity: entity,
			name: "PPE",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		// Current liabilities
		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0])
		)

		// Non-current liabilities (should NOT appear in components)
		let ltDebt = try Account(
			entity: entity,
			name: "Long-term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: periods, values: [300_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [250_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, ppe, ap, ltDebt, equity]
		)

		let components: [BalanceSheetRole: TimeSeries<Double>] = balanceSheet.workingCapitalComponents

		// Should only have 2 components (cash and AP)
		#expect(components.count == 2)
		#expect(components[BalanceSheetRole.cashAndEquivalents] != nil)
		#expect(components[BalanceSheetRole.accountsPayable] != nil)

		// Should NOT have PPE or long-term debt
		#expect(components[BalanceSheetRole.propertyPlantEquipment] == nil)
		#expect(components[BalanceSheetRole.longTermDebt] == nil)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Working Capital Turnover Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Working capital turnover calculation")
	func workingCapitalTurnoverCalculation() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3)
		]

		// Working capital: Q1=$1M, Q2=$1.2M, Q3=$1.1M
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_200_000.0, 1_100_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [0.0, 0.0, 0.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_200_000.0, 1_100_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, ap, equity]
		)

		// Revenue: Q1=$5M, Q2=$6M, Q3=$5.5M
		let revenue = TimeSeries(periods: periods, values: [5_000_000.0, 6_000_000.0, 5_500_000.0])

		let turnover = balanceSheet.workingCapitalTurnover(revenue: revenue)

		// Q1: $5M / $1M = 5.0×
		#expect(turnover[periods[0]]! == 5.0)

		// Q2: $6M / (($1M + $1.2M) / 2) = $6M / $1.1M = 5.45×
		let q2Expected = 6_000_000.0 / 1_100_000.0
		#expect(abs(turnover[periods[1]]! - q2Expected) < 0.01)

		// Q3: $5.5M / (($1.2M + $1.1M) / 2) = $5.5M / $1.15M = 4.78×
		let q3Expected = 5_500_000.0 / 1_150_000.0
		#expect(abs(turnover[periods[2]]! - q3Expected) < 0.01)
	}

	@Test("High working capital turnover (retail)")
	func highWorkingCapitalTurnoverRetail() throws {
		let entity = Entity(id: "RETAIL", name: "Retail Company")
		let periods = [Period.year(2024)]

		// Low working capital (negative CCC)
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [200_000.0])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [600_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, inventory, ap, equity]
		)

		// NWC: ($200K + $500K) - $600K = $100K (very low)
		// High revenue
		let revenue = TimeSeries(periods: periods, values: [10_000_000.0])

		let turnover = balanceSheet.workingCapitalTurnover(revenue: revenue)

		// $10M / $100K = 100× (very high - typical for retail)
		#expect(turnover[periods[0]]! == 100.0)
	}

	@Test("Low working capital turnover (manufacturing)")
	func lowWorkingCapitalTurnoverManufacturing() throws {
		let entity = Entity(id: "MFG", name: "Manufacturing Company")
		let periods = [Period.year(2024)]

		// High working capital (high AR, high inventory)
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		let ar = try Account(
			entity: entity,
			name: "AR",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: periods, values: [2_000_000.0])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: periods, values: [3_000_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [4_500_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, ar, inventory, ap, equity]
		)

		// NWC: ($500K + $2M + $3M) - $1M = $4.5M (high)
		let revenue = TimeSeries(periods: periods, values: [20_000_000.0])

		let turnover = balanceSheet.workingCapitalTurnover(revenue: revenue)

		// $20M / $4.5M = 4.44× (lower - typical for manufacturing)
		let expected = 20_000_000.0 / 4_500_000.0
		#expect(abs(turnover[periods[0]]! - expected) < 0.01)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - LBO Modeling Scenarios
	// ═══════════════════════════════════════════════════════════

	@Test("LBO: Working capital build and release tracking")
	func lboWorkingCapitalTracking() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]

		// Simulate growing AR (working capital build - use of cash)
		let ar = try Account(
			entity: entity,
			name: "AR",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_200_000.0, 1_400_000.0, 1_300_000.0])
		)

		// Stable inventory
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: periods, values: [800_000.0, 800_000.0, 800_000.0, 800_000.0])
		)

		// Growing AP (working capital release - source of cash)
		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0, 600_000.0, 700_000.0, 750_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [1_300_000.0, 1_400_000.0, 1_500_000.0, 1_350_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [ar, inventory, ap, equity]
		)

		let nwc = balanceSheet.netWorkingCapital
		let components: [BalanceSheetRole: TimeSeries<Double>] = balanceSheet.workingCapitalComponents

		// Track AR build/release
		let arComponent = components[BalanceSheetRole.accountsReceivable]!
		let q1ToQ2ARChange = arComponent[periods[1]]! - arComponent[periods[0]]!
		let q3ToQ4ARChange = arComponent[periods[3]]! - arComponent[periods[2]]!

		#expect(q1ToQ2ARChange == 200_000.0)  // AR increased - use of cash
		#expect(q3ToQ4ARChange == -100_000.0)  // AR decreased - source of cash

		// Track total NWC changes
		let q1NWC = nwc[periods[0]]!  // $1M + $800K - $500K = $1.3M
		let q4NWC = nwc[periods[3]]!  // $1.3M + $800K - $750K = $1.35M

		#expect(q1NWC == 1_300_000.0)
		#expect(q4NWC == 1_350_000.0)

		// Small NWC increase overall ($50K use of cash)
		let nwcChange = q4NWC - q1NWC
		#expect(nwcChange == 50_000.0)
	}

	@Test("LBO: Working capital efficiency improvement post-acquisition")
	func lboWorkingCapitalEfficiency() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periodsPreAcquisition = [Period.year(2023)]
		let periodsPostAcquisition = [Period.year(2024), Period.year(2025)]
		let allPeriods = periodsPreAcquisition + periodsPostAcquisition

		// Pre-acquisition: Inefficient working capital (high AR, high inventory)
		// Post-acquisition: Improved collections and inventory management
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: allPeriods, values: [500_000.0, 500_000.0, 500_000.0])
		)

		// AR decreases (improved collections)
		let ar = try Account(
			entity: entity,
			name: "AR",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: allPeriods, values: [3_000_000.0, 2_500_000.0, 2_200_000.0])
		)

		// Inventory decreases (improved turnover)
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: allPeriods, values: [2_500_000.0, 2_000_000.0, 1_800_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: allPeriods, values: [1_000_000.0, 1_000_000.0, 1_000_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: allPeriods, values: [5_000_000.0, 4_000_000.0, 3_500_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: allPeriods,
			accounts: [cash, ar, inventory, ap, equity]
		)

		// Stable revenue
		let revenue = TimeSeries(periods: allPeriods, values: [25_000_000.0, 26_000_000.0, 27_000_000.0])

		let nwc = balanceSheet.netWorkingCapital
		let turnover = balanceSheet.workingCapitalTurnover(revenue: revenue)

		// Pre-acquisition NWC: ($500K + $3M + $2.5M) - $1M = $5M
		#expect(nwc[periodsPreAcquisition[0]]! == 5_000_000.0)

		// Post-acquisition NWC (2025): ($500K + $2.2M + $1.8M) - $1M = $3.5M
		#expect(nwc[periodsPostAcquisition[1]]! == 3_500_000.0)

		// Cash released from WC optimization: $5M - $3.5M = $1.5M
		let cashReleased = nwc[periodsPreAcquisition[0]]! - nwc[periodsPostAcquisition[1]]!
		#expect(cashReleased == 1_500_000.0)

		// Turnover improved (lower denominator with stable revenue)
		let preAcquisitionTurnover = turnover[periodsPreAcquisition[0]]!
		let postAcquisitionTurnover = turnover[periodsPostAcquisition[1]]!

		#expect(postAcquisitionTurnover > preAcquisitionTurnover)

		// Pre: $25M / $5M = 5.0×
		// Post (2025): $27M / (($3.5M + $4M)/2) = $27M / $3.75M = 7.2×
		let improvementPercent = ((postAcquisitionTurnover / preAcquisitionTurnover) - 1) * 100
		#expect(improvementPercent > 40.0)  // >40% improvement
	}

	@Test("Empty working capital for debt-free cash-only company")
	func emptyWorkingCapitalComponents() throws {
		let entity = Entity(id: "CASH-ONLY", name: "Cash Only Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Only non-current assets and equity
		let ppe = try Account(
			entity: entity,
			name: "PPE",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [ppe, equity]
		)

		let components: [BalanceSheetRole: TimeSeries<Double>] = balanceSheet.workingCapitalComponents

		// Should be empty - no current assets or liabilities
		#expect(components.isEmpty)

		// NWC should be zero
		#expect(balanceSheet.netWorkingCapital[periods[0]]! == 0.0)
	}
}
