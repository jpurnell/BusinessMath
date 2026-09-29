//
//  FinancialPeriodSummaryCoverageTests.swift
//  BusinessMathTests
//
//  `FinancialPeriodSummary.init` was declared `throws` and contained **zero `throw`
//  statements**. It filled twenty fields with `?? T(0)` for any period at all, covered or
//  not, so a caller asking about a quarter one step outside the statements it supplied got a
//  complete-looking one-pager in which every figure was invented. The same defect one file
//  over scored a solvent, profitable company `0.00` — "Distress Zone (High bankruptcy risk
//  within 2 years)", in `altmanZScore`'s own documentation.
//
//  The fix could not be "throw whenever a lookup returns nil", because **three different
//  meanings of `nil` share one spelling** in that initialiser. Six of the ratios come from
//  `BalanceSheet.ratio(_:over:)`, which deliberately omits periods whose divisor is zero — so
//  a company with no current liabilities has **no current ratio at a period its balance sheet
//  fully covers**. A blanket rule would have rejected exactly the debt-free company an
//  earlier commit in this campaign made representable.
//
//  So these three cases have to come out **different from each other**, and that is what this
//  file asserts:
//
//  | case | raw roll-ups | the six ratios | initialiser |
//  |---|---|---|---|
//  | covered, ordinary company | present | present | succeeds |
//  | covered, debt-free company | present | `nil` where the divisor is zero | succeeds |
//  | uncovered period | — | — | **throws** |
//
//  The last two tests cover the third defect found in the same initialiser: margins and
//  EBITDA multiples guarded by `if revenue != T(0)` with a fallback of `T(0)`. A margin of
//  zero is a claim — "this business ran at exactly breakeven" — and a debt-to-EBITDA of
//  `0.0x` reads as the strongest credit on a lender's scale for the company least able to
//  service its debt. Those now answer `nan`, and the pair of tests below is written so that
//  the zero which is a **measurement** and the one which was an **absence** appear in the
//  same fixture and are told apart.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("FinancialPeriodSummary period coverage")
struct FinancialPeriodSummaryCoverageTests {

	private static let q1 = Period.quarter(year: 2025, quarter: 1)
	private static let q3 = Period.quarter(year: 2025, quarter: 3)

	private struct Fixture {
		let entity: Entity
		let income: IncomeStatement<Double>
		let balance: BalanceSheet<Double>
	}

	/// Builds a one-period entity from `(role, amount)` lists, so each test reads as its
	/// balance sheet rather than as twenty lines of account construction.
	private static func fixture(
		id: String,
		incomeRoles: [(IncomeStatementRole, Double)],
		balanceRoles: [(BalanceSheetRole, Double)]
	) throws -> Fixture {
		let entity = Entity(id: id, name: id)
		let periods = [q1]

		var incomeAccounts: [Account<Double>] = []
		for (index, entry) in incomeRoles.enumerated() {
			let series = TimeSeries(periods: periods, values: [entry.1])
			let account = try Account(
				entity: entity,
				name: "\(id) income \(index)",
				incomeStatementRole: entry.0,
				timeSeries: series
			)
			incomeAccounts.append(account)
		}

		var balanceAccounts: [Account<Double>] = []
		for (index, entry) in balanceRoles.enumerated() {
			let series = TimeSeries(periods: periods, values: [entry.1])
			let account = try Account(
				entity: entity,
				name: "\(id) balance \(index)",
				balanceSheetRole: entry.0,
				timeSeries: series
			)
			balanceAccounts.append(account)
		}

		return Fixture(
			entity: entity,
			income: try IncomeStatement(entity: entity, periods: periods, accounts: incomeAccounts),
			balance: try BalanceSheet(entity: entity, periods: periods, accounts: balanceAccounts)
		)
	}

	/// Revenue 1,000 · COGS 400 · opex 200. Assets 1,000 (cash 300, receivables 200, PP&E
	/// 500) against liabilities 400 (payables 250, long-term debt 150) and equity 600.
	private static func ordinary() throws -> Fixture {
		try fixture(
			id: "ORD",
			incomeRoles: [
				(.revenue, 1_000),
				(.costOfGoodsSold, 400),
				(.operatingExpenseOther, 200)
			],
			balanceRoles: [
				(.cashAndEquivalents, 300),
				(.accountsReceivable, 200),
				(.propertyPlantEquipment, 500),
				(.accountsPayable, 250),
				(.longTermDebt, 150),
				(.commonStock, 600)
			]
		)
	}

	/// Revenue 800 · COGS 300. Assets 1,000 (cash 400, PP&E 600) against **no liabilities at
	/// all** and equity 1,000. Owes nothing, short-term or long.
	private static func debtFree() throws -> Fixture {
		try fixture(
			id: "FREE",
			incomeRoles: [
				(.revenue, 800),
				(.costOfGoodsSold, 300)
			],
			balanceRoles: [
				(.cashAndEquivalents, 400),
				(.propertyPlantEquipment, 600),
				(.commonStock, 1_000)
			]
		)
	}

	// MARK: - The control: a covered period for an ordinary company

	@Test("Covered period, ordinary company: every figure is present and is the arithmetic")
	func coveredPeriodIsComplete() throws {
		let fixture = try Self.ordinary()

		let summary = try FinancialPeriodSummary(
			entity: fixture.entity,
			period: Self.q1,
			incomeStatement: fixture.income,
			balanceSheet: fixture.balance
		)

		// Raw roll-ups, straight from the statements.
		#expect(summary.revenue.isEqual(to: 1_000))
		#expect(summary.grossProfit.isEqual(to: 600), "1,000 revenue less 400 of COGS")
		#expect(summary.operatingIncome.isEqual(to: 400), "600 gross profit less 200 of opex")
		#expect(summary.ebitda.isEqual(to: 400), "no non-cash charges, so EBITDA is EBIT")
		#expect(summary.netIncome.isEqual(to: 400), "1,000 less 400 less 200")
		#expect(summary.totalAssets.isEqual(to: 1_000), "300 + 200 + 500")
		#expect(summary.currentAssets.isEqual(to: 500), "cash and receivables only")
		#expect(summary.totalLiabilities.isEqual(to: 400), "250 payables + 150 debt")
		#expect(summary.currentLiabilities.isEqual(to: 250))
		#expect(summary.totalEquity.isEqual(to: 600))
		#expect(summary.workingCapital.isEqual(to: 250), "500 - 250")
		#expect(summary.cash.isEqual(to: 300))
		#expect(summary.debt.isEqual(to: 150), "payables are not interest-bearing")
		#expect(summary.netDebt.isEqual(to: -150), "150 of debt against 300 of cash")

		// Margins, which have a denominator and therefore exist.
		#expect(summary.grossMargin.isEqual(to: 0.6))
		#expect(summary.operatingMargin.isEqual(to: 0.4))
		#expect(summary.netMargin.isEqual(to: 0.4))

		// The six optional ratios: all six have a non-zero divisor here, so all six are
		// present. This is the control the debt-free case below is measured against.
		let currentRatio = try #require(summary.currentRatio)
		#expect(currentRatio.isEqual(to: 2.0), "500 / 250")
		let quickRatio = try #require(summary.quickRatio)
		#expect(quickRatio.isEqual(to: 2.0), "no inventory, so the quick ratio is the current one")
		let cashRatio = try #require(summary.cashRatio)
		#expect(cashRatio.isEqual(to: 1.2), "300 / 250")
		let debtToEquity = try #require(summary.debtToEquityRatio)
		#expect(debtToEquity.isEqual(to: 0.25), "150 / 600")
		let debtToAssets = try #require(summary.debtToAssetsRatio)
		#expect(debtToAssets.isEqual(to: 0.4), "400 / 1,000")
		let equityRatio = try #require(summary.equityRatio)
		#expect(equityRatio.isEqual(to: 0.6), "600 / 1,000")

		// Returns and credit multiples. A single-period balance sheet averages to itself.
		#expect(summary.roa.isEqual(to: 0.4), "400 / 1,000")
		let expectedROE: Double = 400.0 / 600.0
		let roeGap: Double = abs(summary.roe - expectedROE)
		#expect(roeGap < 1e-12, "400 / 600")
		#expect(summary.debtToEBITDARatio.isEqual(to: 0.375), "150 / 400")
		#expect(summary.netDebtToEBITDARatio.isEqual(to: -0.375), "-150 / 400")
	}

	// MARK: - The discriminating case: covered, but the divisor is zero

	@Test("Covered period, debt-free company: the roll-ups are there, the ratio is nil, nothing throws")
	func debtFreeCompanyKeepsItsRollUpsAndLosesOnlyTheUndefinedRatios() throws {
		let fixture = try Self.debtFree()

		// The initialiser must not throw. This company's statements cover the period
		// completely; it simply owes nothing, which is a balance sheet, not a gap in one.
		let summary = try FinancialPeriodSummary(
			entity: fixture.entity,
			period: Self.q1,
			incomeStatement: fixture.income,
			balanceSheet: fixture.balance
		)

		// Every raw roll-up is present and right — including the ones that are legitimately
		// zero, which is the half of the distinction that a nil-everywhere rule would lose.
		#expect(summary.revenue.isEqual(to: 800))
		#expect(summary.netIncome.isEqual(to: 500), "800 less 300 of COGS")
		#expect(summary.totalAssets.isEqual(to: 1_000), "400 cash + 600 PP&E")
		#expect(summary.currentAssets.isEqual(to: 400))
		#expect(summary.totalEquity.isEqual(to: 1_000))
		#expect(summary.totalLiabilities.isEqual(to: 0), "owes nothing: a measurement, not an absence")
		#expect(summary.currentLiabilities.isEqual(to: 0))
		#expect(summary.debt.isEqual(to: 0))
		#expect(summary.workingCapital.isEqual(to: 400), "400 - 0")
		#expect(summary.netDebt.isEqual(to: -400), "a net cash position")

		// The three liquidity ratios divide by current liabilities. There are none, so there
		// is no number of times over they are covered. `0` said the opposite — no coverage at
		// all — and failed every minimum-coverage covenant in the library.
		#expect(summary.currentRatio == nil, "no current liabilities, so no current ratio")
		#expect(summary.quickRatio == nil)
		#expect(summary.cashRatio == nil)

		// And the other three divide by equity or assets, which this company has. They are
		// present, and one of them is genuinely `0.0`. That is the point: absence and zero
		// are now two different answers in the same summary, from the same six fields.
		let debtToEquity = try #require(summary.debtToEquityRatio, "there is equity, so there is a ratio")
		#expect(debtToEquity.isEqual(to: 0), "no debt against 1,000 of equity really is zero leverage")
		let debtToAssets = try #require(summary.debtToAssetsRatio)
		#expect(debtToAssets.isEqual(to: 0))
		let equityRatio = try #require(summary.equityRatio)
		#expect(equityRatio.isEqual(to: 1.0), "equity funds the whole balance sheet")
	}

	// MARK: - The refused case: a period the statements do not cover

	@Test("Uncovered period: the initialiser throws instead of fabricating twenty zeros")
	func uncoveredPeriodThrows() throws {
		let fixture = try Self.ordinary()

		// Q3 is not in these statements. Before this change the call succeeded and returned a
		// summary whose revenue, assets, equity and EBITDA were all `0` — a company that had
		// ceased to exist, reported with the same confidence as the Q1 figures above.
		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try FinancialPeriodSummary(
				entity: fixture.entity,
				period: Self.q3,
				incomeStatement: fixture.income,
				balanceSheet: fixture.balance
			)
		}

		let error = try #require(thrown, "a period outside the statements has no summary")
		guard case .missingData(let account, let period) = error else {
			Issue.record("expected .missingData, got \(error)")
			return
		}
		#expect(account == "totalRevenue", "the first figure read is the one named in the error")
		#expect(period == Self.q3.label)
	}

	@Test("An uncovered period is refused for the debt-free company too, not confused with its nil ratios")
	func uncoveredPeriodThrowsEvenWhenRatiosWouldBeNil() throws {
		let fixture = try Self.debtFree()

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try FinancialPeriodSummary(
				entity: fixture.entity,
				period: Self.q3,
				incomeStatement: fixture.income,
				balanceSheet: fixture.balance
			)
		}

		// The two conditions are told apart by which one you get: this company's current
		// ratio is `nil` at a covered period and its whole summary is refused at an
		// uncovered one. Neither answer is available for the other question.
		let error = try #require(thrown)
		guard case .missingData = error else {
			Issue.record("expected .missingData, got \(error)")
			return
		}
		#expect(Self.q3.label != Self.q1.label, "the two periods really are different")
	}

	// MARK: - The third defect: a zero that was a claim

	@Test("No revenue: the margins are nan, and the multiples that still have a divisor are not")
	func zeroRevenueGivesNoMargins() throws {
		let fixture = try Self.fixture(
			id: "NOREV",
			incomeRoles: [
				(.revenue, 0),
				(.operatingExpenseOther, 100)
			],
			balanceRoles: [
				(.cashAndEquivalents, 200),
				(.propertyPlantEquipment, 800),
				(.longTermDebt, 200),
				(.commonStock, 800)
			]
		)

		let summary = try FinancialPeriodSummary(
			entity: fixture.entity,
			period: Self.q1,
			incomeStatement: fixture.income,
			balanceSheet: fixture.balance
		)

		#expect(summary.revenue.isEqual(to: 0))
		#expect(summary.netIncome.isEqual(to: -100), "no revenue against 100 of opex")

		// The old guard was `if revenue != T(0)`, falling back to `T(0)`. A gross margin of
		// zero says the business converted revenue into cost exactly; this business had no
		// revenue to convert. Those are different statements and a peer ranking treats them
		// very differently.
		#expect(summary.grossMargin.isNaN, "no denominator, so no margin")
		#expect(summary.operatingMargin.isNaN)
		#expect(summary.netMargin.isNaN)

		// EBITDA is -100, which is a divisor, so the credit multiples are still answerable.
		// This is the control that keeps the change above from being a blanket nan.
		#expect(summary.ebitda.isEqual(to: -100))
		#expect(summary.debtToEBITDARatio.isEqual(to: -2.0), "200 / -100")
		let netDebtToEBITDA: Double = summary.netDebtToEBITDARatio
		#expect(netDebtToEBITDA.isEqual(to: 0), "net debt is 200 - 200 = 0, and 0 / -100 is 0")
	}

	@Test("No EBITDA: the credit multiples are nan, and a margin of zero survives as a measurement")
	func zeroEBITDAGivesNoCreditMultiples() throws {
		let fixture = try Self.fixture(
			id: "NOEBITDA",
			incomeRoles: [
				(.revenue, 500),
				(.costOfGoodsSold, 500)
			],
			balanceRoles: [
				(.cashAndEquivalents, 200),
				(.propertyPlantEquipment, 800),
				(.longTermDebt, 200),
				(.commonStock, 800)
			]
		)

		let summary = try FinancialPeriodSummary(
			entity: fixture.entity,
			period: Self.q1,
			incomeStatement: fixture.income,
			balanceSheet: fixture.balance
		)

		#expect(summary.ebitda.isEqual(to: 0), "revenue exactly consumed by cost of goods")

		// `0.0x` debt-to-EBITDA is the best reading on every lender's scale, and this company
		// has 200 of debt and nothing to service it with — the worst.
		#expect(summary.debtToEBITDARatio.isNaN, "no earnings to measure the debt against")
		#expect(summary.netDebtToEBITDARatio.isNaN)

		// And the margins here are a real, measured zero: revenue of 500 that produced no
		// gross profit. The same numeral, two different facts, in two adjacent fields.
		#expect(summary.revenue.isEqual(to: 500))
		#expect(summary.grossMargin.isEqual(to: 0), "0 / 500 — measured, not fabricated")
		#expect(summary.netMargin.isEqual(to: 0))
	}
}
