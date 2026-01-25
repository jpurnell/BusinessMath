//
//  DSCR_EdgeCaseTests.swift
//  BusinessMath
//
//  Focused tests for DSCR edge cases, especially first period handling.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("DSCR Edge Case Tests")
struct DSCR_EdgeCaseTests {

	@Test("diff(lag: 1) correctly skips first period")
	func diffSkipsFirstPeriod() throws {
		let periods = [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3)
		]

		let debt = TimeSeries(periods: periods, values: [100.0, 95.0, 90.0])
		let changes = debt.diff(lag: 1)

		// Should have 2 periods (Q2 and Q3), not 3
		#expect(changes.periods.count == 2, "diff should skip first period")

		// Q2 change: 95 - 100 = -5
		if let q2Change = changes[periods[1]] {
			#expect(abs(q2Change - (-5.0)) < 0.01, "Q2 change should be -5.0")
		} else {
			Issue.record("Q2 should have a value")
		}

		// Q3 change: 90 - 95 = -5
		if let q3Change = changes[periods[2]] {
			#expect(abs(q3Change - (-5.0)) < 0.01, "Q3 change should be -5.0")
		} else {
			Issue.record("Q3 should have a value")
		}

		// Q1 should NOT have a value
		#expect(changes[periods[0]] == nil, "Q1 should not have a value")
	}

	@Test("DSCR with 4 quarters returns 3 values")
	func dscrWithFourQuarters() throws {
		let entity = Entity(id: "test", name: "Test Entity")
		let periods = [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3),
			Period.quarter(year: 2025, quarter: 4)
		]

		// Simple declining debt
		let debt = [100_000.0, 95_000.0, 90_000.0, 85_000.0]
		let interest = [5_000.0, 5_000.0, 5_000.0, 5_000.0]
		let operatingIncome = [60_000.0, 60_000.0, 60_000.0, 60_000.0]

		// Create income statement
		let revenueAccount = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 100_000.0, 100_000.0, 100_000.0])
		)

		let cogsAccount = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [40_000.0, 40_000.0, 40_000.0, 40_000.0])
		)

		let interestAccount = try Account(
			entity: entity,
			name: "Interest Expense",
			incomeStatementRole: .interestExpense,
			timeSeries: TimeSeries(periods: periods, values: interest)
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenueAccount, cogsAccount, interestAccount]
		)

		// Create balance sheet
		let debtAccount = try Account(
			entity: entity,
			name: "Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: periods, values: debt)
		)

		let cashAccount = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [10_000.0, 10_000.0, 10_000.0, 10_000.0])
		)

		let equityAccount = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [10_000.0, 10_000.0, 10_000.0, 10_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cashAccount, debtAccount, equityAccount]
		)

		// Calculate DSCR
		let dscr = try debtServiceCoverage(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		// Should have 3 values (Q2, Q3, Q4)
		#expect(dscr.periods.count == 3, "DSCR should have 3 periods for 4-quarter input")

		// Q1 should NOT exist
		#expect(dscr[periods[0]] == nil, "Q1 DSCR should not exist")

		// Q2-Q4 should exist
		#expect(dscr[periods[1]] != nil, "Q2 DSCR should exist")
		#expect(dscr[periods[2]] != nil, "Q3 DSCR should exist")
		#expect(dscr[periods[3]] != nil, "Q4 DSCR should exist")

		// Each DSCR should be: Operating Income / (Principal + Interest)
		// Principal = $5k (debt decreases by $5k each quarter)
		// Interest = $5k
		// Total service = $10k
		// DSCR = $60k / $10k = 6.0x

		for period in dscr.periods {
			if let value = dscr[period] {
				#expect(abs(value - 6.0) < 0.01, "DSCR should be ~6.0x")
			}
		}
	}

	@Test("DSCR with single period returns empty")
	func dscrWithSinglePeriod() throws {
		let entity = Entity(id: "Test", name: "TEST")
		let periods = [Period.quarter(year: 2025, quarter: 1)]

		let revenueAccount = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let interestAccount = try Account(
			entity: entity,
			name: "Interest",
			incomeStatementRole: .interestExpense,
			timeSeries: TimeSeries(periods: periods, values: [5_000.0])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenueAccount, interestAccount]
		)

		let debtAccount = try Account(
			entity: entity,
			name: "Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let cashAccount = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [10_000.0])
		)

		let equityAccount = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [10_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cashAccount, debtAccount, equityAccount]
		)

		let dscr = try debtServiceCoverage(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		// Should be empty (no prior period for diff)
		#expect(dscr.isEmpty, "DSCR should be empty with single period")
	}

	@Test("DSCR correctly handles CPLTD with reclassification")
	func dscrWithCPLTDReclassification() throws {
		let entity = Entity(id: "Test", name: "TEST")
		let periods = [
			Period.quarter(year: 2025, quarter: 1),
			Period.quarter(year: 2025, quarter: 2),
			Period.quarter(year: 2025, quarter: 3),
			Period.quarter(year: 2025, quarter: 4)
		]

		// Q1: LT=$95k, CPLTD=$5k, Total=$100k
		// Q2: LT=$95k, CPLTD=$0, Total=$95k (paid $5k from CPLTD)
		// Q3: LT=$90k, CPLTD=$5k, Total=$95k (reclassified $5k, no payment)
		// Q4: LT=$90k, CPLTD=$0, Total=$90k (paid $5k from CPLTD)

		let ltDebt = [95_000.0, 95_000.0, 90_000.0, 90_000.0]
		let cpltd = [5_000.0, 0.0, 5_000.0, 0.0]

		let revenueAccount = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0, 100_000.0, 100_000.0, 100_000.0])
		)

		let cogsAccount = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [40_000.0, 40_000.0, 40_000.0, 40_000.0])
		)

		let interestAccount = try Account(
			entity: entity,
			name: "Interest",
			incomeStatementRole: .interestExpense,
			timeSeries: TimeSeries(periods: periods, values: [5_000.0, 5_000.0, 5_000.0, 5_000.0])
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenueAccount, cogsAccount, interestAccount]
		)

		let ltDebtAccount = try Account(
			entity: entity,
			name: "LT Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: periods, values: ltDebt)
		)

		let cpltdAccount = try Account(
			entity: entity,
			name: "CPLTD",
			balanceSheetRole: .currentPortionLongTermDebt,
			timeSeries: TimeSeries(periods: periods, values: cpltd)
		)

		let cashAccount = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [10_000.0, 10_000.0, 10_000.0, 10_000.0])
		)

		let equityAccount = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [10_000.0, 10_000.0, 10_000.0, 10_000.0])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cashAccount, ltDebtAccount, cpltdAccount, equityAccount]
		)

		let dscr = try debtServiceCoverage(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		// Total debt changes (what we're testing!):
		// Q1→Q2: $100k → $95k = -$5k (principal payment)
		// Q2→Q3: $95k → $95k = $0 (reclassification, no payment!)
		// Q3→Q4: $95k → $90k = -$5k (principal payment)

		// Q2: Principal=$5k, Interest=$5k, Total=$10k, DSCR = $60k / $10k = 6.0x
		if let q2Dscr = dscr[periods[1]] {
			#expect(abs(q2Dscr - 6.0) < 0.01, "Q2 DSCR should be 6.0x")
		}

		// Q3: Principal=$0, Interest=$5k, Total=$5k, DSCR = $60k / $5k = 12.0x
		if let q3Dscr = dscr[periods[2]] {
			#expect(abs(q3Dscr - 12.0) < 0.01, "Q3 DSCR should be 12.0x (no principal payment)")
		}

		// Q4: Principal=$5k, Interest=$5k, Total=$10k, DSCR = $60k / $10k = 6.0x
		if let q4Dscr = dscr[periods[3]] {
			#expect(abs(q4Dscr - 6.0) < 0.01, "Q4 DSCR should be 6.0x")
		}
	}
}
