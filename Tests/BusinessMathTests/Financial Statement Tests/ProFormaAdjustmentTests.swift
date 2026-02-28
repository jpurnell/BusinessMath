import Testing
import Foundation
@testable import BusinessMath

/// Tests for Pro Forma Adjustment System (v2.0.0)
///
/// Verifies that pro forma adjustments work correctly for quality of earnings
/// analyses and LBO valuations.
@Suite("Pro Forma Adjustment System (v2.0.0)")
struct ProFormaAdjustmentTests {

	// ═══════════════════════════════════════════════════════════
	// MARK: - Single Account Adjustment Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Single adjustment applied to account")
	func singleAdjustmentToAccount() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// Legal expense: $500K in Q1 (includes $250K one-time settlement)
		let legalExpense = try Account(
			entity: entity,
			name: "Legal Fees",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0, 100_000.0])
		)

		// Add back one-time settlement in Q1
		let settlement = AccountAdjustment(
			adjustmentType: .addback,
			amount: TimeSeries(periods: [periods[0]], values: [250_000.0]),
			description: "One-time litigation settlement"
		)

		let adjustedLegal = legalExpense.applying(adjustment: settlement)

		// Q1 should be reduced by $250K (addback reduces expense)
		#expect(adjustedLegal.timeSeries[periods[0]]! == 750_000.0)
		// Q2 unchanged (no adjustment for that period)
		#expect(adjustedLegal.timeSeries[periods[1]]! == 100_000.0)

		// Original account unchanged
		#expect(legalExpense.timeSeries[periods[0]]! == 500_000.0)
	}

	@Test("Multiple adjustments applied to account")
	func multipleAdjustmentsToAccount() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]

		// G&A expense with multiple one-time items
		let gnaExpense = try Account(
			entity: entity,
			name: "General & Administrative",
			incomeStatementRole: .generalAndAdministrative,
			timeSeries: TimeSeries(periods: periods, values: [800_000.0, 750_000.0, 750_000.0, 900_000.0])
		)

		let adjustments = [
			// One-time relocation costs in Q1
			AccountAdjustment(
				adjustmentType: .oneTimeCharge,
				amount: TimeSeries(periods: [periods[0]], values: [100_000.0]),
				description: "Office relocation costs"
			),
			// Normalize CFO comp across all quarters
			AccountAdjustment(
				adjustmentType: .ownerCompensation,
				amount: TimeSeries(periods: periods, values: [25_000.0, 25_000.0, 25_000.0, 25_000.0]),
				description: "Normalize CFO comp to market rate"
			),
			// Acquisition costs in Q4
			AccountAdjustment(
				adjustmentType: .oneTimeCharge,
				amount: TimeSeries(periods: [periods[3]], values: [150_000.0]),
				description: "Acquisition-related advisory fees"
			)
		]

		let adjustedGNA = gnaExpense.applying(adjustments: adjustments)

		// Q1: $800K + $100K (relocation) + $25K (comp) = $925K
		#expect(adjustedGNA.timeSeries[periods[0]]! == 925_000.0)
		// Q2: $750K + $25K (comp only) = $775K
		#expect(adjustedGNA.timeSeries[periods[1]]! == 775_000.0)
		// Q3: $750K + $25K (comp only) = $775K
		#expect(adjustedGNA.timeSeries[periods[2]]! == 775_000.0)
		// Q4: $900K + $25K (comp) + $150K (acquisition) = $1,075K
		#expect(adjustedGNA.timeSeries[periods[3]]! == 1_075_000.0)
	}

	@Test("Empty adjustments returns unchanged account")
	func emptyAdjustmentsReturnsOriginal() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let expense = try Account(
			entity: entity,
			name: "Operating Expense",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let adjusted = expense.applying(adjustments: [])

		#expect(adjusted.timeSeries[periods[0]]! == 100_000.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Adjusted EBITDA Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Adjusted EBITDA calculation")
	func adjustedEBITDACalculation() throws {
		let entity = Entity(id: "TARGET", name: "Target Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// Revenue
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0, 1_000_000.0])
		)

		// COGS (for EBITDA calc)
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [400_000.0, 400_000.0])
		)

		// Operating expenses
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: [300_000.0, 250_000.0])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs, opex]
		)

		// Reported EBITDA: Revenue - COGS - OpEx = $1M - $400K - $300K = $300K (Q1)
		let reportedEBITDA = incomeStmt.ebitda
		#expect(reportedEBITDA[periods[0]]! == 300_000.0)

		// Add back one-time legal settlement in Q1
		let adjustments = [
			AccountAdjustment(
				adjustmentType: .addback,
				amount: TimeSeries(periods: [periods[0]], values: [50_000.0]),
				description: "One-time legal settlement"
			)
		]

		let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: adjustments)

		// Adjusted EBITDA: $300K + $50K = $350K (Q1)
		#expect(adjustedEBITDA[periods[0]]! == 350_000.0)
		// Q2 unchanged (no adjustments)
		#expect(adjustedEBITDA[periods[1]]! == 350_000.0)

		// Original EBITDA unchanged
		#expect(reportedEBITDA[periods[0]]! == 300_000.0)
	}

	@Test("Empty adjustments returns unadjusted EBITDA")
	func emptyAdjustmentsReturnsUnadjustedEBITDA() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [500_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [200_000.0])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs]
		)

		let reportedEBITDA = incomeStmt.ebitda
		let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: [])

		#expect(reportedEBITDA[periods[0]]! == adjustedEBITDA[periods[0]]!)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Quality of Earnings Scenarios
	// ═══════════════════════════════════════════════════════════

	@Test("Quality of earnings: SMB acquisition normalization")
	func qualityOfEarningsSMB() throws {
		let entity = Entity(id: "SMB", name: "Small Business Target")
		let periods = [
			Period.year(2023),
			Period.year(2024)
		]

		// Revenue growing steadily
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [5_000_000.0, 5_500_000.0])
		)

		// COGS
		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [2_000_000.0, 2_200_000.0])
		)

		// Operating expenses (includes excess owner comp)
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: [2_500_000.0, 2_600_000.0])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs, opex]
		)

		// Reported EBITDA 2024: $5.5M - $2.2M - $2.6M = $700K
		let reportedEBITDA = incomeStmt.ebitda
		#expect(reportedEBITDA[periods[1]]! == 700_000.0)

		// Quality of earnings adjustments
		let adjustments = [
			// Owner takes $400K salary, market rate is $250K
			AccountAdjustment(
				adjustmentType: .ownerCompensation,
				amount: TimeSeries(periods: periods, values: [150_000.0, 150_000.0]),
				description: "Normalize owner compensation from $400K to market rate $250K",
				metadata: ["market_rate": "$250K", "excess": "$150K"]
			),
			// One-time facility upgrade in 2023
			AccountAdjustment(
				adjustmentType: .oneTimeCharge,
				amount: TimeSeries(periods: [periods[0]], values: [100_000.0]),
				description: "Facility renovation - non-recurring"
			)
		]

		let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: adjustments)

		// Adjusted EBITDA 2023: $500K + $150K (owner) + $100K (facility) = $750K
		#expect(adjustedEBITDA[periods[0]]! == 750_000.0)
		// Adjusted EBITDA 2024: $700K + $150K (owner) = $850K
		#expect(adjustedEBITDA[periods[1]]! == 850_000.0)
	}

	@Test("Quality of earnings: Multiple one-time charges")
	func qualityOfEarningsMultipleCharges() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periods = [Period.year(2024)]

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [10_000_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [4_000_000.0])
		)

		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: [4_500_000.0])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs, opex]
		)

		// Reported EBITDA: $10M - $4M - $4.5M = $1.5M
		let reportedEBITDA = incomeStmt.ebitda
		#expect(reportedEBITDA[periods[0]]! == 1_500_000.0)

		// Multiple addbacks
		let adjustments = [
			AccountAdjustment(
				adjustmentType: .addback,
				amount: TimeSeries(periods: periods, values: [250_000.0]),
				description: "Legal settlement - non-recurring",
				metadata: ["category": "legal", "verified": "true"]
			),
			AccountAdjustment(
				adjustmentType: .addback,
				amount: TimeSeries(periods: periods, values: [150_000.0]),
				description: "Restructuring severance - non-recurring",
				metadata: ["category": "restructuring"]
			),
			AccountAdjustment(
				adjustmentType: .oneTimeCharge,
				amount: TimeSeries(periods: periods, values: [300_000.0]),
				description: "Acquisition advisory fees",
				metadata: ["deal": "Acme Corp acquisition"]
			)
		]

		let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: adjustments)

		// Adjusted EBITDA: $1.5M + $250K + $150K + $300K = $2.2M
		#expect(adjustedEBITDA[periods[0]]! == 2_200_000.0)

		// Verify bridge calculation
		let totalAdjustments = 250_000.0 + 150_000.0 + 300_000.0
		#expect(adjustedEBITDA[periods[0]]! == reportedEBITDA[periods[0]]! + totalAdjustments)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - LBO Valuation Scenarios
	// ═══════════════════════════════════════════════════════════

	@Test("LBO valuation: Enterprise value from adjusted EBITDA")
	func lboValuationEnterpriseValue() throws {
		let entity = Entity(id: "TARGET", name: "Acquisition Target")
		let periods = [Period.year(2024)]

		// LTM financials
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [50_000_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [20_000_000.0])
		)

		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: [18_000_000.0])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs, opex]
		)

		// Reported EBITDA: $50M - $20M - $18M = $12M
		let reportedEBITDA = incomeStmt.ebitda
		#expect(reportedEBITDA[periods[0]]! == 12_000_000.0)

		// Pro forma adjustments for LBO
		let adjustments = [
			// Owner compensation normalization
			AccountAdjustment(
				adjustmentType: .ownerCompensation,
				amount: TimeSeries(periods: periods, values: [500_000.0]),
				description: "Normalize founder salary to market",
				metadata: ["market_rate": "$300K", "current": "$800K"]
			),
			// One-time acquisition defense costs
			AccountAdjustment(
				adjustmentType: .addback,
				amount: TimeSeries(periods: periods, values: [750_000.0]),
				description: "Deal-related costs incurred during prior sale process"
			),
			// Product discontinuation charges
			AccountAdjustment(
				adjustmentType: .oneTimeCharge,
				amount: TimeSeries(periods: periods, values: [1_250_000.0]),
				description: "Legacy product line exit costs"
			)
		]

		let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: adjustments)

		// Adjusted EBITDA: $12M + $500K + $750K + $1.25M = $14.5M
		#expect(adjustedEBITDA[periods[0]]! == 14_500_000.0)

		// LBO pricing at 6.0× adjusted EBITDA multiple
		let valuationMultiple = 6.0
		let enterpriseValue = adjustedEBITDA[periods[0]]! * valuationMultiple

		#expect(enterpriseValue == 87_000_000.0)  // $14.5M × 6.0× = $87M

		// Verify adjustment impact on valuation
		let unadjustedEV = reportedEBITDA[periods[0]]! * valuationMultiple
		let adjustmentImpact = enterpriseValue - unadjustedEV

		#expect(unadjustedEV == 72_000_000.0)  // $12M × 6.0× = $72M
		#expect(adjustmentImpact == 15_000_000.0)  // $2.5M adjustments × 6.0× = $15M
	}

	@Test("LBO covenant compliance with adjusted EBITDA")
	func lboCovenantCompliance() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [12_000_000.0, 13_000_000.0, 14_000_000.0, 15_000_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [5_000_000.0, 5_400_000.0, 5_800_000.0, 6_200_000.0])
		)

		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: [5_500_000.0, 5_600_000.0, 5_700_000.0, 5_800_000.0])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs, opex]
		)

		// Management fee addback per credit agreement
		let adjustments = [
			AccountAdjustment(
				adjustmentType: .normalizedExpense,
				amount: TimeSeries(periods: periods, values: [250_000.0, 250_000.0, 250_000.0, 250_000.0]),
				description: "PE sponsor management fee - permitted addback per credit agreement",
				metadata: ["covenant": "permitted_addback", "agreement": "First Lien Credit Agreement"]
			)
		]

		let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: adjustments)

		// Q1: ($12M - $5M - $5.5M) + $250K = $1.75M
		#expect(adjustedEBITDA[periods[0]]! == 1_750_000.0)
		// Q4: ($15M - $6.2M - $5.8M) + $250K = $3.25M
		#expect(adjustedEBITDA[periods[3]]! == 3_250_000.0)

		// Covenant test: Senior leverage ratio < 4.0×
		// (Assuming $8M total debt)
		let totalDebt = 8_000_000.0

		// Calculate trailing 4-quarter adjusted EBITDA
		let q1EBITDA = adjustedEBITDA[periods[0]]!
		let q2EBITDA = adjustedEBITDA[periods[1]]!
		let q3EBITDA = adjustedEBITDA[periods[2]]!
		let q4EBITDA = adjustedEBITDA[periods[3]]!
		let ttmAdjustedEBITDA = q1EBITDA + q2EBITDA + q3EBITDA + q4EBITDA

		let seniorLeverageRatio = totalDebt / ttmAdjustedEBITDA

		// TTM adjusted EBITDA: $1.75M + $2.25M + $2.75M + $3.25M = $10M
		#expect(ttmAdjustedEBITDA == 10_000_000.0)
		// Leverage: $8M / $10M = 0.8× (well below 4.0× covenant)
		#expect(seniorLeverageRatio < 4.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Adjustment Type Tests
	// ═══════════════════════════════════════════════════════════

	@Test("All adjustment types are Codable")
	func adjustmentTypesAreCodable() throws {
		let types: [AccountAdjustment<Double>.AdjustmentType] = [
			.addback,
			.normalizedExpense,
			.oneTimeCharge,
			.ownerCompensation,
			.other
		]

		for type in types {
			let encoder = JSONEncoder()
			let decoder = JSONDecoder()

			let encoded = try encoder.encode(type)
			let decoded = try decoder.decode(AccountAdjustment<Double>.AdjustmentType.self, from: encoded)

			#expect(decoded == type)
		}
	}

	@Test("AccountAdjustment is Codable with metadata")
	func adjustmentIsCodableWithMetadata() throws {
		let periods = [Period.year(2024)]

		let adjustment = AccountAdjustment(
			adjustmentType: .addback,
			amount: TimeSeries(periods: periods, values: [250_000.0]),
			description: "One-time legal settlement",
			metadata: [
				"approvedBy": "Investment Committee",
				"supportingDoc": "QoE_Analysis_v3.pdf",
				"confidence": "high"
			]
		)

		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		let encoded = try encoder.encode(adjustment)
		let decoded = try decoder.decode(AccountAdjustment<Double>.self, from: encoded)

		#expect(decoded.adjustmentType == .addback)
		#expect(decoded.description == "One-time legal settlement")
		#expect(decoded.metadata["approvedBy"] == "Investment Committee")
		#expect(decoded.metadata["confidence"] == "high")
		#expect(decoded.amount[periods[0]]! == 250_000.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Edge Cases
	// ═══════════════════════════════════════════════════════════

	@Test("Negative adjustments decrease EBITDA")
	func negativeAdjustmentsDecreaseEBITDA() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.year(2024)]

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [400_000.0])
		)

		let incomeStmt = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs]
		)

		// Reported EBITDA: $600K
		let reportedEBITDA = incomeStmt.ebitda
		#expect(reportedEBITDA[periods[0]]! == 600_000.0)

		// Negative adjustment (e.g., non-recurring revenue to exclude)
		let adjustments = [
			AccountAdjustment(
				adjustmentType: .oneTimeCharge,
				amount: TimeSeries(periods: periods, values: [-100_000.0]),
				description: "Non-recurring revenue to exclude from normalized EBITDA"
			)
		]

		let adjustedEBITDA = incomeStmt.adjustedEBITDA(adjustments: adjustments)

		// Adjusted EBITDA: $600K - $100K = $500K
		#expect(adjustedEBITDA[periods[0]]! == 500_000.0)
	}

	@Test("Adjustment with empty metadata")
	func adjustmentWithEmptyMetadata() throws {
		let periods = [Period.year(2024)]

		let adjustment = AccountAdjustment(
			adjustmentType: .addback,
			amount: TimeSeries(periods: periods, values: [100_000.0]),
			description: "Simple adjustment without metadata"
			// metadata defaults to [:]
		)

		#expect(adjustment.metadata.isEmpty)
		#expect(adjustment.description == "Simple adjustment without metadata")
	}
}
