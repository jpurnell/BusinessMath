import Testing
import Foundation
@testable import BusinessMath

/// Tests for Cash Flow Extensions (v2.0.0)
///
/// Verifies that working capital changes by component work correctly
/// for cash flow analysis and LBO modeling.
@Suite("Cash Flow Extensions (v2.0.0)")
struct CashFlowExtensionsTests {

	// ═══════════════════════════════════════════════════════════
	// MARK: - Working Capital Changes By Component Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Working capital changes by component breakdown")
	func workingCapitalChangesByComponentBreakdown() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3)
		]

		// AR: $1M → $1.2M → $1.4M (increasing - use of cash)
		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_200_000.0, 1_400_000.0])
		)

		// Inventory: $800K → $900K → $850K (increase then decrease)
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: periods, values: [800_000.0, 900_000.0, 850_000.0])
		)

		// AP: $600K → $700K → $750K (increasing - source of cash)
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			cashFlowRole: .changeInPayables,
			timeSeries: TimeSeries(periods: periods, values: [600_000.0, 700_000.0, 750_000.0])
		)

		// Non-WC account (should not appear)
		let capex = try Account(
			entity: entity,
			name: "CapEx",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: periods, values: [-500_000.0, -600_000.0, -550_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [ar, inventory, ap, capex]
		)

		let wcComponents: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// Should have 3 WC components (AR, Inventory, AP), not CapEx
		#expect(wcComponents.count == 3)
		#expect(wcComponents[CashFlowRole.changeInReceivables] != nil)
		#expect(wcComponents[CashFlowRole.changeInInventory] != nil)
		#expect(wcComponents[CashFlowRole.changeInPayables] != nil)
		#expect(wcComponents[CashFlowRole.capitalExpenditures] == nil)

		// AR changes: Q2 = $1.2M - $1M = $200K (use of cash)
		let arChanges = wcComponents[CashFlowRole.changeInReceivables]!
		#expect(arChanges[periods[1]]! == 200_000.0)
		// Q3 = $1.4M - $1.2M = $200K (continued use of cash)
		#expect(arChanges[periods[2]]! == 200_000.0)

		// Inventory changes: Q2 = $900K - $800K = $100K (use of cash)
		let invChanges = wcComponents[CashFlowRole.changeInInventory]!
		#expect(invChanges[periods[1]]! == 100_000.0)
		// Q3 = $850K - $900K = -$50K (source of cash - inventory decrease)
		#expect(invChanges[periods[2]]! == -50_000.0)

		// AP changes: Q2 = $700K - $600K = $100K (source of cash)
		let apChanges = wcComponents[CashFlowRole.changeInPayables]!
		#expect(apChanges[periods[1]]! == 100_000.0)
		// Q3 = $750K - $700K = $50K (continued source of cash)
		#expect(apChanges[periods[2]]! == 50_000.0)
	}

	@Test("Working capital components sum equals total working capital changes")
	func componentsSumEqualsTotal() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		let ar = try Account(
			entity: entity,
			name: "AR",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0, 600_000.0])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: periods, values: [300_000.0, 350_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			cashFlowRole: .changeInPayables,
			timeSeries: TimeSeries(periods: periods, values: [200_000.0, 250_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [ar, inventory, ap]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent
		let totalWC = cashFlowStmt.workingCapitalChanges

		// Sum component changes for Q2
		let sumOfComponents = components.values.reduce(0.0) { sum, timeSeries in
			sum + timeSeries[periods[1]]!
		}

		// AR: +$100K, Inv: +$50K, AP: +$50K = $200K total WC change
		#expect(sumOfComponents == totalWC[periods[1]]!)
	}

	@Test("Working capital components aggregate multiple accounts of same role")
	func componentsAggregateMultipleAccounts() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// Two AR accounts
		let ar1 = try Account(
			entity: entity,
			name: "Trade Receivables",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [400_000.0, 450_000.0])
		)

		let ar2 = try Account(
			entity: entity,
			name: "Other Receivables",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 120_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [ar1, ar2]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// Should aggregate both AR accounts
		// Total AR: Q1=$500K, Q2=$570K → Change = $70K
		let arChanges = components[CashFlowRole.changeInReceivables]!
		#expect(arChanges[periods[1]]! == 70_000.0)
	}

	@Test("Empty components for cash flow with no working capital items")
	func emptyComponentsForNoWorkingCapital() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// Only non-WC items
		let capex = try Account(
			entity: entity,
			name: "CapEx",
			cashFlowRole: .capitalExpenditures,
			timeSeries: TimeSeries(periods: periods, values: [-500_000.0, -600_000.0])
		)

		let debtPayment = try Account(
			entity: entity,
			name: "Debt Repayment",
			cashFlowRole: .repaymentOfDebt,
			timeSeries: TimeSeries(periods: periods, values: [-100_000.0, -150_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [capex, debtPayment]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// Should be empty - no working capital items
		#expect(components.isEmpty)

		// Total WC changes should be zero
		let totalWC = cashFlowStmt.workingCapitalChanges
		#expect(totalWC[periods[1]]! == 0.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Cash Flow Analysis Scenarios
	// ═══════════════════════════════════════════════════════════

	@Test("AR increase tracked in components")
	func arIncreaseTrackedInComponents() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// AR increasing (customers taking longer to pay)
		let ar = try Account(
			entity: entity,
			name: "AR",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_300_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [ar]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// AR increased by $300K - use of cash
		let arChange = components[CashFlowRole.changeInReceivables]![periods[1]]!
		#expect(arChange == 300_000.0)

		// Total WC changes should match component
		let totalWC = cashFlowStmt.workingCapitalChanges
		#expect(totalWC[periods[1]]! == 300_000.0)
	}

	@Test("AP increase tracked in components")
	func apIncreaseTrackedInComponents() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// AP increasing (taking longer to pay suppliers)
		let ap = try Account(
			entity: entity,
			name: "AP",
			cashFlowRole: .changeInPayables,
			timeSeries: TimeSeries(periods: periods, values: [800_000.0, 1_000_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [ap]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// AP increased by $200K - source of cash
		let apChange = components[CashFlowRole.changeInPayables]![periods[1]]!
		#expect(apChange == 200_000.0)

		// Total WC changes should match component
		let totalWC = cashFlowStmt.workingCapitalChanges
		#expect(totalWC[periods[1]]! == 200_000.0)
	}

	@Test("Inventory build tracked in components")
	func inventoryBuildTrackedInComponents() throws {
		let entity = Entity(id: "MFG", name: "Manufacturing Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// Building inventory for anticipated demand
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: periods, values: [2_000_000.0, 2_500_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [inventory]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// Inventory increased by $500K - use of cash
		let invChange = components[CashFlowRole.changeInInventory]![periods[1]]!
		#expect(invChange == 500_000.0)

		// Total WC changes should match component
		let totalWC = cashFlowStmt.workingCapitalChanges
		#expect(totalWC[periods[1]]! == 500_000.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - LBO Modeling Scenarios
	// ═══════════════════════════════════════════════════════════

	@Test("LBO: Detailed working capital forecast by component")
	func lboWorkingCapitalForecast() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]

		let netIncome = try Account(
			entity: entity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0, 600_000.0, 650_000.0, 700_000.0])
		)

		// AR: Growing with revenue but improving DSO
		let ar = try Account(
			entity: entity,
			name: "AR",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [1_500_000.0, 1_700_000.0, 1_850_000.0, 1_900_000.0])
		)

		// Inventory: Optimizing turnover (decreasing)
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: periods, values: [1_200_000.0, 1_150_000.0, 1_100_000.0, 1_050_000.0])
		)

		// AP: Negotiating better payment terms (increasing)
		let ap = try Account(
			entity: entity,
			name: "AP",
			cashFlowRole: .changeInPayables,
			timeSeries: TimeSeries(periods: periods, values: [900_000.0, 950_000.0, 1_000_000.0, 1_050_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [netIncome, ar, inventory, ap]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// Q2 Analysis
		let q2ARChange = components[CashFlowRole.changeInReceivables]![periods[1]]!
		let q2InvChange = components[CashFlowRole.changeInInventory]![periods[1]]!
		let q2APChange = components[CashFlowRole.changeInPayables]![periods[1]]!

		#expect(q2ARChange == 200_000.0)   // AR up $200K - use of cash
		#expect(q2InvChange == -50_000.0)  // Inventory down $50K - source of cash
		#expect(q2APChange == 50_000.0)    // AP up $50K - source of cash

		// Net WC impact Q2: -$200K (AR) + $50K (Inv) + $50K (AP) = -$100K
		let q2WCImpact = -q2ARChange + (-q2InvChange) + q2APChange
		#expect(q2WCImpact == -100_000.0)  // $100K use of cash

		// Q4 Analysis (operational improvements showing)
		let q4ARChange = components[CashFlowRole.changeInReceivables]![periods[3]]!
		let q4InvChange = components[CashFlowRole.changeInInventory]![periods[3]]!
		let q4APChange = components[CashFlowRole.changeInPayables]![periods[3]]!

		// AR growth slowing (Q3→Q4: $1.9M - $1.85M = $50K vs $200K in Q2)
		#expect(q4ARChange == 50_000.0)
		// Continued inventory optimization
		#expect(q4InvChange == -50_000.0)
		// Continued AP improvement
		#expect(q4APChange == 50_000.0)
	}

	@Test("LBO: Working capital release creates cash for deleveraging")
	func lboWorkingCapitalRelease() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periodsPreAcquisition = [Period.year(2023)]
		let periodsPostAcquisition = [Period.year(2024), Period.year(2025)]
		let allPeriods = periodsPreAcquisition + periodsPostAcquisition

		let netIncome = try Account(
			entity: entity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: allPeriods, values: [5_000_000.0, 5_500_000.0, 6_000_000.0])
		)

		// Pre-acquisition: Inefficient WC (high AR, high inventory)
		// Post-acquisition: PE firm improves collections and inventory management
		let ar = try Account(
			entity: entity,
			name: "AR",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: allPeriods, values: [8_000_000.0, 7_000_000.0, 6_500_000.0])
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: allPeriods, values: [6_000_000.0, 5_000_000.0, 4_500_000.0])
		)

		let ap = try Account(
			entity: entity,
			name: "AP",
			cashFlowRole: .changeInPayables,
			timeSeries: TimeSeries(periods: allPeriods, values: [3_000_000.0, 3_000_000.0, 3_000_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: allPeriods,
			accounts: [netIncome, ar, inventory, ap]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// 2024 (Year 1 post-acquisition): Major WC release
		let y1ARChange = components[CashFlowRole.changeInReceivables]![periodsPostAcquisition[0]]!
		let y1InvChange = components[CashFlowRole.changeInInventory]![periodsPostAcquisition[0]]!

		// AR decreased $1M - source of cash (improved collections)
		#expect(y1ARChange == -1_000_000.0)
		// Inventory decreased $1M - source of cash (improved turnover)
		#expect(y1InvChange == -1_000_000.0)

		// Total WC release Year 1: $2M available for debt paydown
		let y1WCRelease: Double = Double(-y1ARChange) + Double(-y1InvChange)
		#expect(y1WCRelease == 2_000_000.0)

		// Total WC changes should be negative (source of cash from WC release)
		let totalWC = cashFlowStmt.workingCapitalChanges
		#expect(totalWC[periodsPostAcquisition[0]]! == -2_000_000.0)
	}

	@Test("Tracking DSO improvement through AR changes")
	func trackingDSOImprovement() throws {
		let entity = Entity(id: "SAAS", name: "SaaS Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]

		let netIncome = try Account(
			entity: entity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_100_000.0, 1_200_000.0, 1_300_000.0])
		)

		// AR decreasing despite revenue growth (DSO improvement)
		// Q1: $3M, Q2: $2.9M, Q3: $2.8M, Q4: $2.7M
		let ar = try Account(
			entity: entity,
			name: "AR",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [3_000_000.0, 2_900_000.0, 2_800_000.0, 2_700_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [netIncome, ar]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent
		let arChanges = components[CashFlowRole.changeInReceivables]!

		// Each quarter sees AR decrease (source of cash)
		#expect(arChanges[periods[1]]! == -100_000.0)  // Q2: AR down $100K
		#expect(arChanges[periods[2]]! == -100_000.0)  // Q3: AR down $100K
		#expect(arChanges[periods[3]]! == -100_000.0)  // Q4: AR down $100K

		// Total AR reduction over 3 quarters: $300K cash released
		let q2 = -arChanges[periods[1]]!
		let q3 = -arChanges[periods[2]]!
		let q4 = -arChanges[periods[3]]!
		let totalARRelease: Double = Double(q2) + Double(q3) + Double(q4)
		#expect(totalARRelease == 300_000.0)
	}

	@Test("Negative cash conversion cycle (retail model)")
	func negativeCashConversionCycle() throws {
		let entity = Entity(id: "RETAIL", name: "Retail Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		let netIncome = try Account(
			entity: entity,
			name: "Net Income",
			cashFlowRole: .netIncome,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0, 600_000.0])
		)

		// Very low AR (mostly cash sales)
		let ar = try Account(
			entity: entity,
			name: "AR",
			cashFlowRole: .changeInReceivables,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		)

		// Fast inventory turnover
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			cashFlowRole: .changeInInventory,
			timeSeries: TimeSeries(periods: periods, values: [800_000.0, 850_000.0])
		)

		// High AP (paid after inventory sold)
		let ap = try Account(
			entity: entity,
			name: "AP",
			cashFlowRole: .changeInPayables,
			timeSeries: TimeSeries(periods: periods, values: [1_200_000.0, 1_300_000.0])
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			accounts: [netIncome, ar, inventory, ap]
		)

		let components: [CashFlowRole: TimeSeries<Double>] = cashFlowStmt.workingCapitalChangesByComponent

		// Q2 working capital changes
		let arChange = components[CashFlowRole.changeInReceivables]![periods[1]]!
		let invChange = components[CashFlowRole.changeInInventory]![periods[1]]!
		let apChange = components[CashFlowRole.changeInPayables]![periods[1]]!

		// Small AR increase
		#expect(arChange == 10_000.0)
		// Small inventory increase
		#expect(invChange == 50_000.0)
		// Larger AP increase (negative CCC benefit)
		#expect(apChange == 100_000.0)

		// Net WC impact: -$10K (AR) - $50K (Inv) + $100K (AP) = +$40K source of cash
		// AP increase > (AR increase + Inventory increase) = negative CCC
		let wcImpact: Double = Double(-arChange) + Double(-invChange) + Double(apChange)
		#expect(wcImpact == 40_000.0)  // Net source of cash from working capital
	}
}
