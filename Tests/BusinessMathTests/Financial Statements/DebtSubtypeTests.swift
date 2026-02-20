import Testing
import Foundation
@testable import BusinessMath

/// Tests for debt subtype granularity (v2.0.0)
///
/// Verifies that new granular debt classifications work correctly and integrate with
/// existing debt aggregation logic.
@Suite("Debt Subtype Granularity (v2.0.0)")
struct DebtSubtypeTests {

	// ═══════════════════════════════════════════════════════════
	// MARK: - Debt Classification Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Revolving credit facility is classified as debt")
	func revolvingCreditFacilityIsDebt() {
		#expect(BalanceSheetRole.revolvingCreditFacility.isDebt == true)
		#expect(BalanceSheetRole.revolvingCreditFacility.isNonCurrentLiability == true)
		#expect(BalanceSheetRole.revolvingCreditFacility.isLiability == true)
	}

	@Test("Term loan short-term is classified as current debt")
	func termLoanShortTermIsCurrentDebt() {
		#expect(BalanceSheetRole.termLoanShortTerm.isDebt == true)
		#expect(BalanceSheetRole.termLoanShortTerm.isCurrentLiability == true)
		#expect(BalanceSheetRole.termLoanShortTerm.isLiability == true)
	}

	@Test("Term loan long-term is classified as non-current debt")
	func termLoanLongTermIsNonCurrentDebt() {
		#expect(BalanceSheetRole.termLoanLongTerm.isDebt == true)
		#expect(BalanceSheetRole.termLoanLongTerm.isNonCurrentLiability == true)
		#expect(BalanceSheetRole.termLoanLongTerm.isLiability == true)
	}

	@Test("Mezzanine debt is classified as non-current debt")
	func mezzanineDebtIsNonCurrentDebt() {
		#expect(BalanceSheetRole.mezzanineDebt.isDebt == true)
		#expect(BalanceSheetRole.mezzanineDebt.isNonCurrentLiability == true)
		#expect(BalanceSheetRole.mezzanineDebt.isLiability == true)
	}

	@Test("Convertible debt is classified as non-current debt")
	func convertibleDebtIsNonCurrentDebt() {
		#expect(BalanceSheetRole.convertibleDebt.isDebt == true)
		#expect(BalanceSheetRole.convertibleDebt.isNonCurrentLiability == true)
		#expect(BalanceSheetRole.convertibleDebt.isLiability == true)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Backward Compatibility
	// ═══════════════════════════════════════════════════════════

	@Test("Existing debt types still classified correctly")
	func existingDebtTypesUnchanged() {
		// Verify existing debt types work identically
		#expect(BalanceSheetRole.shortTermDebt.isDebt == true)
		#expect(BalanceSheetRole.longTermDebt.isDebt == true)
		#expect(BalanceSheetRole.lineOfCredit.isDebt == true)
		#expect(BalanceSheetRole.currentPortionLongTermDebt.isDebt == true)

		// Verify non-debt liabilities are NOT debt
		#expect(BalanceSheetRole.accountsPayable.isDebt == false)
		#expect(BalanceSheetRole.deferredTaxLiabilities.isDebt == false)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Debt Breakdown Integration Tests
	// ═══════════════════════════════════════════════════════════

	@Test("Debt breakdown includes all debt types")
	func debtBreakdownIncludesAllTypes() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		// Create diverse debt accounts
		let revolver = try Account(
			entity: entity,
			name: "Revolving Credit Facility",
			balanceSheetRole: .revolvingCreditFacility,
			timeSeries: TimeSeries(periods: periods, values: [50_000, 45_000])
		)

		let termLoan = try Account(
			entity: entity,
			name: "First Lien Term Loan",
			balanceSheetRole: .termLoanLongTerm,
			timeSeries: TimeSeries(periods: periods, values: [100_000, 95_000])
		)

		let mezz = try Account(
			entity: entity,
			name: "Subordinated Mezzanine",
			balanceSheetRole: .mezzanineDebt,
			timeSeries: TimeSeries(periods: periods, values: [30_000, 30_000])
		)

		// Create balance sheet
		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [revolver, termLoan, mezz]
		)

		// Get debt breakdown
		let debtByType = balanceSheet.interestBearingDebtByType

		// Verify all three debt types are in the breakdown
		#expect(debtByType.count == 3)
		#expect(debtByType[.revolvingCreditFacility] != nil)
		#expect(debtByType[.termLoanLongTerm] != nil)
		#expect(debtByType[.mezzanineDebt] != nil)

		// Verify values for Q1
		#expect(debtByType[.revolvingCreditFacility]![periods[0]]! == 50_000.0)
		#expect(debtByType[.termLoanLongTerm]![periods[0]]! == 100_000.0)
		#expect(debtByType[.mezzanineDebt]![periods[0]]! == 30_000.0)
	}

	@Test("Total debt equals sum of debt breakdown")
	func totalDebtEqualsSumOfBreakdown() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let revolver = try Account(
			entity: entity,
			name: "Revolver",
			balanceSheetRole: .revolvingCreditFacility,
			timeSeries: TimeSeries(periods: periods, values: [25_000])
		)

		let termLoan = try Account(
			entity: entity,
			name: "Term Loan",
			balanceSheetRole: .termLoanLongTerm,
			timeSeries: TimeSeries(periods: periods, values: [75_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [revolver, termLoan]
		)

		// Total debt should equal sum of breakdown
		let totalDebt = balanceSheet.interestBearingDebt
		let debtByType = balanceSheet.interestBearingDebtByType

		let sumOfBreakdown = debtByType.values.reduce(TimeSeries(periods: periods, values: [0.0])) { $0 + $1 }

		#expect(totalDebt[periods[0]]! == 100_000.0)
		#expect(sumOfBreakdown[periods[0]]! == 100_000.0)
		#expect(totalDebt[periods[0]]! == sumOfBreakdown[periods[0]]!)
	}

	@Test("Debt breakdown handles multiple accounts of same type")
	func debtBreakdownAggregatesSameType() throws {
		let entity = Entity(id: "TEST", name: "Test Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Two term loans
		let termLoan1 = try Account(
			entity: entity,
			name: "Term Loan A",
			balanceSheetRole: .termLoanLongTerm,
			timeSeries: TimeSeries(periods: periods, values: [50_000])
		)

		let termLoan2 = try Account(
			entity: entity,
			name: "Term Loan B",
			balanceSheetRole: .termLoanLongTerm,
			timeSeries: TimeSeries(periods: periods, values: [30_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [termLoan1, termLoan2]
		)

		let debtByType = balanceSheet.interestBearingDebtByType

		// Should aggregate both term loans into single entry
		#expect(debtByType.count == 1)
		#expect(debtByType[.termLoanLongTerm]![periods[0]]! == 80_000.0)
	}

	// ═══════════════════════════════════════════════════════════
	// MARK: - Real-World Scenarios
	// ═══════════════════════════════════════════════════════════

	@Test("PE capital structure with multiple debt tranches")
	func peCapitalStructure() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Typical LBO capital structure
		let revolver = try Account(
			entity: entity,
			name: "ABL Revolver ($100M facility)",
			balanceSheetRole: .revolvingCreditFacility,
			timeSeries: TimeSeries(periods: periods, values: [25_000_000])  // 25% drawn
		)

		let termLoanA = try Account(
			entity: entity,
			name: "First Lien Term Loan",
			balanceSheetRole: .termLoanLongTerm,
			timeSeries: TimeSeries(periods: periods, values: [200_000_000])
		)

		let mezzanine = try Account(
			entity: entity,
			name: "Subordinated Notes",
			balanceSheetRole: .mezzanineDebt,
			timeSeries: TimeSeries(periods: periods, values: [50_000_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [revolver, termLoanA, mezzanine]
		)

		let debtByType = balanceSheet.interestBearingDebtByType

		// Verify capital structure
		#expect(debtByType.count == 3)

		// Calculate senior vs subordinated debt
		let seniorDebt = (debtByType[.revolvingCreditFacility]![periods[0]]! +
						   debtByType[.termLoanLongTerm]![periods[0]]!)
		let subDebt = debtByType[.mezzanineDebt]![periods[0]]!

		#expect(seniorDebt == 225_000_000.0)
		#expect(subDebt == 50_000_000.0)

		// Total debt
		let totalDebt = balanceSheet.interestBearingDebt
		#expect(totalDebt[periods[0]]! == 275_000_000.0)
	}

	@Test("Covenant compliance tracking by debt type")
	func covenantComplianceTracking() throws {
		let entity = Entity(id: "PORTCO", name: "Portfolio Company")
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]

		// Revolver with covenant: Must be paid down quarterly
		let revolver = try Account(
			entity: entity,
			name: "Revolver",
			balanceSheetRole: .revolvingCreditFacility,
			timeSeries: TimeSeries(periods: periods, values: [30_000, 20_000, 10_000, 5_000])
		)

		// Term loan with amortization schedule
		let termLoan = try Account(
			entity: entity,
			name: "Term Loan",
			balanceSheetRole: .termLoanLongTerm,
			timeSeries: TimeSeries(periods: periods, values: [100_000, 98_000, 96_000, 94_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [revolver, termLoan]
		)

		let debtByType = balanceSheet.interestBearingDebtByType

		// Track revolver utilization over time
		let revolverBalance = debtByType[.revolvingCreditFacility]!
		#expect(revolverBalance[periods[0]]! == 30_000.0)
		#expect(revolverBalance[periods[3]]! == 5_000.0)  // Paid down as required

		// Track term loan amortization
		let termLoanBalance = debtByType[.termLoanLongTerm]!
		#expect(termLoanBalance[periods[0]]! == 100_000.0)
		#expect(termLoanBalance[periods[3]]! == 94_000.0)  // Amortizing down
	}

	@Test("Empty debt breakdown for debt-free company")
	func emptyDebtBreakdown() throws {
		let entity = Entity(id: "DEBT-FREE", name: "No Debt Company")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		// Only equity, no debt
		let equity = try Account(
			entity: entity,
			name: "Common Stock",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [1_000_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [equity]
		)

		let debtByType = balanceSheet.interestBearingDebtByType

		// Should be empty - no debt
		#expect(debtByType.isEmpty)

		// Total debt should be zero
		let totalDebt = balanceSheet.interestBearingDebt
		#expect(totalDebt[periods[0]]! == 0.0)
	}
}
