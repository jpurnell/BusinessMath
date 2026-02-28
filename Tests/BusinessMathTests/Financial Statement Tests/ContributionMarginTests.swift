import Testing
import Foundation
@testable import BusinessMath

/// Tests for contribution margin analysis (v2.0.0)
///
/// Verifies that income statements correctly calculate contribution margin, contribution margin
/// percentage, and operating leverage based on cost classification metadata.
@Suite("Contribution Margin Analysis (v2.0.0)")
struct ContributionMarginTests {

	// ═══════════════════════════════════════════════════════════
	// MARK: - Helper: Create Test Data
	// ═══════════════════════════════════════════════════════════

	private func createTestEntity() -> Entity {
		Entity(id: "TEST-CO", name: "Test Company")
	}

	private func createQuarterlyPeriods() -> [Period] {
		return [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]
	}

	private func createTimeSeries(values: [Double]) -> TimeSeries<Double> {
		let periods = createQuarterlyPeriods()
		return TimeSeries(periods: periods, values: values)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Cost Classification Filtering
	// ═══════════════════════════════════════════════════════════

	@Test("Variable cost accounts filter correctly")
	func variableCostAccountsFilter() throws {
		let entity = createTestEntity()

		// Create accounts with cost classification
		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [40_000, 44_000, 48_000, 52_000]),
			metadata: cogsMetadata
		)

		let rentMetadata = AccountMetadata(isFixedCost: true)
		let rent = try Account(
			entity: entity,
			name: "Rent",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [5_000, 5_000, 5_000, 5_000]),
			metadata: rentMetadata
		)

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, rent]
		)

		// Verify filtering
		#expect(incomeStmt.variableCostAccounts.count == 1)
		#expect(incomeStmt.variableCostAccounts[0].name == "COGS")

		#expect(incomeStmt.fixedCostAccounts.count == 1)
		#expect(incomeStmt.fixedCostAccounts[0].name == "Rent")
	}

	@Test("Accounts without cost classification are excluded")
	func unclassifiedAccountsExcluded() throws {
		let entity = createTestEntity()

		// Account without cost classification
		let misc = try Account(
			entity: entity,
			name: "Miscellaneous Expense",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [1_000, 1_000, 1_000, 1_000])
		)

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, misc]
		)

		// Unclassified accounts should not appear in either filter
		#expect(incomeStmt.variableCostAccounts.isEmpty)
		#expect(incomeStmt.fixedCostAccounts.isEmpty)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Contribution Margin Calculation
	// ═══════════════════════════════════════════════════════════

	@Test("Contribution margin calculated correctly")
	func contributionMarginCalculation() throws {
		let entity = createTestEntity()

		// Revenue: $100K, $110K, $120K, $130K
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		// Variable costs: $60K, $66K, $72K, $78K (60% of revenue)
		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [60_000, 66_000, 72_000, 78_000]),
			metadata: cogsMetadata
		)

		// Fixed costs: $10K per quarter
		let rentMetadata = AccountMetadata(isFixedCost: true)
		let rent = try Account(
			entity: entity,
			name: "Rent",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [10_000, 10_000, 10_000, 10_000]),
			metadata: rentMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, rent]
		)

		// Contribution Margin = Revenue - Variable Costs
		// Q1: $100K - $60K = $40K
		// Q2: $110K - $66K = $44K
		// Q3: $120K - $72K = $48K
		// Q4: $130K - $78K = $52K
		let cm = incomeStmt.contributionMargin

		#expect(cm[incomeStmt.periods[0]]! == 40_000.0)
		#expect(cm[incomeStmt.periods[1]]! == 44_000.0)
		#expect(cm[incomeStmt.periods[2]]! == 48_000.0)
		#expect(cm[incomeStmt.periods[3]]! == 52_000.0)
	}

	@Test("Contribution margin percentage calculated correctly")
	func contributionMarginPercentCalculation() throws {
		let entity = createTestEntity()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		// Variable costs at 60% of revenue
		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [60_000, 66_000, 72_000, 78_000]),
			metadata: cogsMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs]
		)

		// Contribution Margin % = (Revenue - Variable Costs) / Revenue
		// All quarters: 40% contribution margin
		let cmPercent = incomeStmt.contributionMarginPercent

		#expect(cmPercent[incomeStmt.periods[0]]! == 0.40)
		#expect(cmPercent[incomeStmt.periods[1]]! == 0.40)
		#expect(cmPercent[incomeStmt.periods[2]]! == 0.40)
		#expect(cmPercent[incomeStmt.periods[3]]! == 0.40)
	}

	@Test("Total variable costs aggregates correctly")
	func totalVariableCostsAggregation() throws {
		let entity = createTestEntity()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		// Multiple variable cost accounts
		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [50_000, 55_000, 60_000, 65_000]),
			metadata: cogsMetadata
		)

		let commissionsMetadata = AccountMetadata(isVariableCost: true)
		let commissions = try Account(
			entity: entity,
			name: "Sales Commissions",
			incomeStatementRole: .salesAndMarketing,
			timeSeries: createTimeSeries(values: [5_000, 5_500, 6_000, 6_500]),
			metadata: commissionsMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, commissions]
		)

		// Total Variable Costs = COGS + Commissions
		// Q1: $50K + $5K = $55K
		// Q2: $55K + $5.5K = $60.5K
		let totalVC = incomeStmt.totalVariableCosts

		#expect(totalVC[incomeStmt.periods[0]]! == 55_000.0)
		#expect(totalVC[incomeStmt.periods[1]]! == 60_500.0)
		#expect(totalVC[incomeStmt.periods[2]]! == 66_000.0)
		#expect(totalVC[incomeStmt.periods[3]]! == 71_500.0)
	}

	@Test("Total fixed costs aggregates correctly")
	func totalFixedCostsAggregation() throws {
		let entity = createTestEntity()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		// Multiple fixed cost accounts
		let rentMetadata = AccountMetadata(isFixedCost: true)
		let rent = try Account(
			entity: entity,
			name: "Rent",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [10_000, 10_000, 10_000, 10_000]),
			metadata: rentMetadata
		)

		let salariesMetadata = AccountMetadata(isFixedCost: true)
		let salaries = try Account(
			entity: entity,
			name: "Salaries",
			incomeStatementRole: .generalAndAdministrative,
			timeSeries: createTimeSeries(values: [20_000, 20_000, 20_000, 20_000]),
			metadata: salariesMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, rent, salaries]
		)

		// Total Fixed Costs = Rent + Salaries = $30K per quarter
		let totalFC = incomeStmt.totalFixedCosts

		#expect(totalFC[incomeStmt.periods[0]]! == 30_000.0)
		#expect(totalFC[incomeStmt.periods[1]]! == 30_000.0)
		#expect(totalFC[incomeStmt.periods[2]]! == 30_000.0)
		#expect(totalFC[incomeStmt.periods[3]]! == 30_000.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Operating Leverage
	// ═══════════════════════════════════════════════════════════

	@Test("Operating leverage calculated correctly")
	func operatingLeverageCalculation() throws {
		let entity = createTestEntity()

		// Revenue: $100K
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		// Variable costs: $60K (60% of revenue)
		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [60_000, 66_000, 72_000, 78_000]),
			metadata: cogsMetadata
		)

		// Fixed costs: $30K
		let rentMetadata = AccountMetadata(isFixedCost: true)
		let rent = try Account(
			entity: entity,
			name: "Fixed Costs",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [30_000, 30_000, 30_000, 30_000]),
			metadata: rentMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, rent]
		)

		// Contribution Margin = $40K
		// Operating Income = $40K - $30K = $10K
		// Operating Leverage = $40K / $10K = 4.0
		let leverage = incomeStmt.operatingLeverage()

		#expect(leverage[incomeStmt.periods[0]]! == 4.0)

		// Q2: CM = $44K, OI = $14K, Leverage = ~3.14
		#expect(abs(leverage[incomeStmt.periods[1]]! - 3.142857) < 0.001)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Graceful Handling (No Cost Classification)
	// ═══════════════════════════════════════════════════════════

	@Test("Graceful handling when NO cost classification")
	func noCostClassificationGraceful() throws {
		let entity = createTestEntity()

		// Accounts without any cost classification metadata
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [60_000, 66_000, 72_000, 78_000])
		)

		let rent = try Account(
			entity: entity,
			name: "Rent",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [10_000, 10_000, 10_000, 10_000])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, rent]
		)

		// With no classification:
		// - totalVariableCosts should be zero
		// - totalFixedCosts should be zero
		// - contributionMargin should equal totalRevenue
		// - contributionMarginPercent should be 100% (1.0)

		let totalVC = incomeStmt.totalVariableCosts
		let totalFC = incomeStmt.totalFixedCosts
		let cm = incomeStmt.contributionMargin
		let cmPercent = incomeStmt.contributionMarginPercent

		#expect(totalVC[incomeStmt.periods[0]]! == 0.0)
		#expect(totalFC[incomeStmt.periods[0]]! == 0.0)
		#expect(cm[incomeStmt.periods[0]]! == 100_000.0)  // Equals revenue
		#expect(cmPercent[incomeStmt.periods[0]]! == 1.0)  // 100%
	}

	@Test("Partial cost classification handled correctly")
	func partialCostClassification() throws {
		let entity = createTestEntity()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		// Only COGS is classified as variable
		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [60_000, 66_000, 72_000, 78_000]),
			metadata: cogsMetadata
		)

		// Rent is NOT classified
		let rent = try Account(
			entity: entity,
			name: "Rent",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [10_000, 10_000, 10_000, 10_000])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, rent]
		)

		// Only COGS should be counted as variable cost
		let totalVC = incomeStmt.totalVariableCosts
		#expect(totalVC[incomeStmt.periods[0]]! == 60_000.0)

		// No fixed costs since rent is unclassified
		let totalFC = incomeStmt.totalFixedCosts
		#expect(totalFC[incomeStmt.periods[0]]! == 0.0)

		// Contribution margin = Revenue - Variable Costs = $40K
		let cm = incomeStmt.contributionMargin
		#expect(cm[incomeStmt.periods[0]]! == 40_000.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Existing Properties Unchanged
	// ═══════════════════════════════════════════════════════════

	@Test("Existing properties unchanged by new features")
	func existingPropertiesUnchanged() throws {
		let entity = createTestEntity()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: createTimeSeries(values: [100_000, 110_000, 120_000, 130_000])
		)

		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [60_000, 66_000, 72_000, 78_000]),
			metadata: cogsMetadata
		)

		let rentMetadata = AccountMetadata(isFixedCost: true)
		let rent = try Account(
			entity: entity,
			name: "Rent",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [10_000, 10_000, 10_000, 10_000]),
			metadata: rentMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, rent]
		)

		// Verify existing properties work identically
		#expect(incomeStmt.totalRevenue[incomeStmt.periods[0]]! == 100_000.0)
		#expect(incomeStmt.totalExpenses[incomeStmt.periods[0]]! == 70_000.0)
		#expect(incomeStmt.netIncome[incomeStmt.periods[0]]! == 30_000.0)
		#expect(incomeStmt.grossProfit[incomeStmt.periods[0]]! == 40_000.0)

		// Gross margin should be 40% (unchanged by cost classification)
		#expect(incomeStmt.grossMargin[incomeStmt.periods[0]]! == 0.40)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Real-World Scenarios
	// ═══════════════════════════════════════════════════════════

	@Test("Real-world scenario: SaaS company with high contribution margin")
	func saasCompanyScenario() throws {
		let entity = createTestEntity()

		// SaaS Revenue: $500K per quarter
		let revenue = try Account(
			entity: entity,
			name: "Subscription Revenue",
			incomeStatementRole: .subscriptionRevenue,
			timeSeries: createTimeSeries(values: [500_000, 500_000, 500_000, 500_000])
		)

		// Minimal variable costs (hosting, payment processing): $50K (10%)
		let hostingMetadata = AccountMetadata(isVariableCost: true)
		let hosting = try Account(
			entity: entity,
			name: "Hosting & Infrastructure",
			incomeStatementRole: .costOfServices,
			timeSeries: createTimeSeries(values: [50_000, 50_000, 50_000, 50_000]),
			metadata: hostingMetadata
		)

		// High fixed costs (salaries, R&D): $300K
		let salariesMetadata = AccountMetadata(isFixedCost: true)
		let salaries = try Account(
			entity: entity,
			name: "Employee Costs",
			incomeStatementRole: .generalAndAdministrative,
			timeSeries: createTimeSeries(values: [300_000, 300_000, 300_000, 300_000]),
			metadata: salariesMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, hosting, salaries]
		)

		// Contribution Margin = $450K (90% margin)
		let cm = incomeStmt.contributionMargin
		#expect(cm[incomeStmt.periods[0]]! == 450_000.0)

		// Contribution Margin % = 90%
		let cmPercent = incomeStmt.contributionMarginPercent
		#expect(cmPercent[incomeStmt.periods[0]]! == 0.90)

		// Operating Income = $150K
		// Operating Leverage = $450K / $150K = 3.0
		let leverage = incomeStmt.operatingLeverage()
		#expect(leverage[incomeStmt.periods[0]]! == 3.0)

		// High contribution margin = scalable business model
		#expect(cmPercent[incomeStmt.periods[0]]! > 0.70)  // >70% is excellent
	}

	@Test("Real-world scenario: Retail business with moderate margins")
	func retailBusinessScenario() throws {
		let entity = createTestEntity()

		// Retail Revenue: $200K
		let revenue = try Account(
			entity: entity,
			name: "Product Sales",
			incomeStatementRole: .productRevenue,
			timeSeries: createTimeSeries(values: [200_000, 220_000, 240_000, 260_000])
		)

		// Higher variable costs (inventory, shipping): $140K (70%)
		let cogsMetadata = AccountMetadata(isVariableCost: true)
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: createTimeSeries(values: [140_000, 154_000, 168_000, 182_000]),
			metadata: cogsMetadata
		)

		// Moderate fixed costs: $40K
		let fixedMetadata = AccountMetadata(isFixedCost: true)
		let fixed = try Account(
			entity: entity,
			name: "Store Rent & Utilities",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: createTimeSeries(values: [40_000, 40_000, 40_000, 40_000]),
			metadata: fixedMetadata
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: createQuarterlyPeriods(),
			accounts: [revenue, cogs, fixed]
		)

		// Contribution Margin = $60K (30% margin)
		let cm = incomeStmt.contributionMargin
		#expect(cm[incomeStmt.periods[0]]! == 60_000.0)

		// Contribution Margin % = 30%
		let cmPercent = incomeStmt.contributionMarginPercent
		#expect(cmPercent[incomeStmt.periods[0]]! == 0.30)

		// Operating Income = $20K
		// Operating Leverage = $60K / $20K = 3.0
		let leverage = incomeStmt.operatingLeverage()
		#expect(leverage[incomeStmt.periods[0]]! == 3.0)

		// Typical retail margins (25-35%)
		#expect(cmPercent[incomeStmt.periods[0]]! >= 0.25 && cmPercent[incomeStmt.periods[0]]! <= 0.35)
	}
}
