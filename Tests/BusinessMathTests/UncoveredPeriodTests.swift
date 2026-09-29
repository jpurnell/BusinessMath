//
//  UncoveredPeriodTests.swift
//  BusinessMathTests
//
//  A period-keyed lookup that misses is not an observation of zero.
//
//  `TimeSeries` subscripting returns `nil` for a period the data does not cover, and several
//  financial-statement functions turned that `nil` into `T(0)` with `??` before using it. The
//  result is a confident number computed from a quarter the caller never supplied, landing at
//  whichever end of the scale zero happens to mean.
//
//  Measured on one profitable company with 165,000 of assets and 12,000 of payables:
//
//  | quarter asked for        | altmanZScore | zone     |
//  |--------------------------|--------------|----------|
//  | Q1 2025 — in the books   | 5.92         | safe     |
//  | Q2 2025 — not in the books | 0.00       | DISTRESS |
//
//  Nothing about the company changed between those two rows; only the question did.
//
//  The rule (contract §3.7) is **narrow the domain, don't fabricate the observation**.
//  `TimeSeries.zip(with:)` already does this — it emits only the periods present in both
//  operands — and it is why the multi-period `altmanZScore` never had the defect its
//  single-period sibling did. Each test below pairs the uncovered period with the covered one,
//  so a blanket short-circuit would fail the control rather than pass the suite.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Queries about periods the statements do not cover")
struct UncoveredPeriodTests {

	// MARK: - Altman Z-Score

	private static let covered = Period.quarter(year: 2025, quarter: 1)
	private static let uncovered = Period.quarter(year: 2025, quarter: 2)

	/// One profitable, leveraged company whose books contain exactly one quarter.
	///
	/// This is the fixture from `AltmanDebtFreeTests`, which measured 5.924848484848485 for
	/// the covered quarter.
	private func company() throws -> (IncomeStatement<Double>, BalanceSheet<Double>) {
		let entity = Entity(id: "ONEQTR", primaryType: .ticker, name: "One Quarter Corp")
		let quarters = [Self.covered]

		let revenue = try Account(entity: entity, name: "Revenue",
			incomeStatementRole: .revenue, timeSeries: TimeSeries(periods: quarters, values: [120_000]))
		let cogs = try Account(entity: entity, name: "COGS",
			incomeStatementRole: .costOfGoodsSold, timeSeries: TimeSeries(periods: quarters, values: [45_000]))
		let incomeStatement = try IncomeStatement(entity: entity, periods: quarters, accounts: [revenue, cogs])

		let cash = try Account(entity: entity, name: "Cash",
			balanceSheetRole: .cashAndEquivalents, timeSeries: TimeSeries(periods: quarters, values: [60_000]))
		let ppe = try Account(entity: entity, name: "PPE",
			balanceSheetRole: .propertyPlantEquipment, timeSeries: TimeSeries(periods: quarters, values: [105_000]))
		let retained = try Account(entity: entity, name: "Retained Earnings",
			balanceSheetRole: .retainedEarnings, timeSeries: TimeSeries(periods: quarters, values: [100_000]))
		let stock = try Account(entity: entity, name: "Common Stock",
			balanceSheetRole: .commonStock, timeSeries: TimeSeries(periods: quarters, values: [65_000]))
		let payables = try Account(entity: entity, name: "AP",
			balanceSheetRole: .accountsPayable, timeSeries: TimeSeries(periods: quarters, values: [12_000]))

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			accounts: [cash, ppe, retained, stock, payables]
		)
		return (incomeStatement, balanceSheet)
	}

	private func zScore(for period: Period) throws -> Double {
		let (incomeStatement, balanceSheet) = try company()
		return altmanZScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			period: period,
			marketPrice: 50.0,
			sharesOutstanding: 1_000.0
		)
	}

	/// The fixture only proves something if Q1 is really in the books and Q2 really is not.
	@Test("Altman_FixtureCoversOneQuarterOnly")
	func altmanFixtureCoversOneQuarterOnly() throws {
		let (_, balanceSheet) = try company()

		let assets = try #require(balanceSheet.totalAssets[Self.covered])
		#expect(assets.isEqual(to: 165_000.0), "Q1 is a real company, not an empty one")

		#expect(!balanceSheet.totalAssets.periods.contains(Self.uncovered),
				"Q2 must be outside the statements, or the uncovered case is not being exercised")
	}

	/// The control: the covered quarter still gives its measured answer.
	@Test("Altman_CoveredQuarterIsUnchanged")
	func altmanCoveredQuarterIsUnchanged() throws {
		let z = try zScore(for: Self.covered)
		#expect(z.isEqual(to: 5.924848484848485))
		#expect(z > 2.99, "and it is read as the safe zone the DocC describes")
	}

	/// The defect: asking about a quarter outside the books returned the strongest possible
	/// bankruptcy warning, 0.00, about the same company.
	@Test("Altman_UncoveredQuarterIsNotAnswered")
	func altmanUncoveredQuarterIsNotAnswered() throws {
		let z = try zScore(for: Self.uncovered)
		#expect(z.isNaN, "an uncovered quarter has no Z-Score; measured 0.00 before the fix")
		#expect(!(z < 1.81), "and must not read as the documented distress zone")
	}

	/// The company does not change between the two questions, so neither may the verdict —
	/// and it was the *absence* of data that moved it by 5.92 points.
	@Test("Altman_MissingDataDoesNotMoveTheVerdict")
	func altmanMissingDataDoesNotMoveTheVerdict() throws {
		let coveredScore = try zScore(for: Self.covered)
		let uncoveredScore = try zScore(for: Self.uncovered)
		#expect(!(uncoveredScore < coveredScore),
				"uncovered scored \(uncoveredScore) against \(coveredScore) for the same company")
	}

	/// The correctly-behaving sibling, pinned: the multi-period overload is built from
	/// `TimeSeries` arithmetic, so it never emits a period the statements do not cover — even
	/// when the market data does.
	@Test("Altman_MultiPeriodOverloadAlreadyNarrowsTheDomain")
	func altmanMultiPeriodOverloadAlreadyNarrowsTheDomain() throws {
		let (incomeStatement, balanceSheet) = try company()
		let bothQuarters = [Self.covered, Self.uncovered]
		let marketPrice = TimeSeries(periods: bothQuarters, values: [50.0, 50.0])
		let sharesOutstanding = TimeSeries(periods: bothQuarters, values: [1_000.0, 1_000.0])

		let zScores = altmanZScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let covered = try #require(zScores[Self.covered])
		#expect(covered.isEqual(to: 5.924848484848485))
		#expect(!zScores.periods.contains(Self.uncovered),
				"the sibling that reads its inputs through zip leaves the uncovered quarter out")
	}

	// MARK: - Working capital turnover

	private static let wcQuarters = [
		Period.quarter(year: 2024, quarter: 1),
		Period.quarter(year: 2024, quarter: 2),
		Period.quarter(year: 2024, quarter: 3)
	]

	private static let wcByQuarter: [Double] = [1_000_000.0, 1_200_000.0, 1_100_000.0]
	private static let revenueByQuarter: [Double] = [5_000_000.0, 6_000_000.0, 5_500_000.0]

	/// A balance sheet with three quarters of working capital and no current liabilities, so
	/// net working capital is exactly the cash balance.
	private func turnoverBalanceSheet() throws -> BalanceSheet<Double> {
		let entity = Entity(id: "WCTURN", name: "Turnover Company")
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: Self.wcQuarters, values: Self.wcByQuarter)
		)
		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: Self.wcQuarters, values: Self.wcByQuarter)
		)
		return try BalanceSheet(entity: entity, periods: Self.wcQuarters, accounts: [cash, equity])
	}

	/// Net working capital has to actually be the cash balance, or the expected values below
	/// are arithmetic about the wrong fixture.
	@Test("Turnover_FixtureWorkingCapitalIsTheCashBalance")
	func turnoverFixtureWorkingCapitalIsTheCashBalance() throws {
		let nwc = try turnoverBalanceSheet().netWorkingCapital
		for (index, quarter) in Self.wcQuarters.enumerated() {
			let value = try #require(nwc[quarter])
			#expect(value.isEqual(to: Self.wcByQuarter[index]))
		}
	}

	/// The control: revenue covering every quarter is answered for every quarter, and the
	/// averaging rule for periods after the first is unchanged.
	@Test("Turnover_FullyCoveredRevenueIsUnchanged")
	func turnoverFullyCoveredRevenueIsUnchanged() throws {
		let balanceSheet = try turnoverBalanceSheet()
		let revenue = TimeSeries(periods: Self.wcQuarters, values: Self.revenueByQuarter)
		let turnover = balanceSheet.workingCapitalTurnover(revenue: revenue)

		// First quarter: current working capital, no average.
		let q1 = try #require(turnover[Self.wcQuarters[0]])
		let q1Expected = Self.revenueByQuarter[0] / Self.wcByQuarter[0]
		#expect(q1.isEqual(to: q1Expected))

		// Later quarters: the mean of this quarter's and the prior quarter's.
		let q2Divisor = (Self.wcByQuarter[0] + Self.wcByQuarter[1]) / 2.0
		let q2Expected = Self.revenueByQuarter[1] / q2Divisor
		let q2 = try #require(turnover[Self.wcQuarters[1]])
		#expect(q2.isEqual(to: q2Expected))

		let q3Divisor = (Self.wcByQuarter[1] + Self.wcByQuarter[2]) / 2.0
		let q3Expected = Self.revenueByQuarter[2] / q3Divisor
		let q3 = try #require(turnover[Self.wcQuarters[2]])
		#expect(q3.isEqual(to: q3Expected))
	}

	/// The defect: revenue that stops short of the balance sheet used to report the missing
	/// quarter as a turnover of 0.0× — working capital generating no sales whatsoever.
	@Test("Turnover_QuarterWithNoRevenueDataIsOmitted")
	func turnoverQuarterWithNoRevenueDataIsOmitted() throws {
		let balanceSheet = try turnoverBalanceSheet()
		let shortQuarters = Array(Self.wcQuarters.prefix(2))
		let shortValues = Array(Self.revenueByQuarter.prefix(2))
		let revenue = TimeSeries(periods: shortQuarters, values: shortValues)

		#expect(!revenue.periods.contains(Self.wcQuarters[2]),
				"the third quarter must be missing from revenue, or nothing is being exercised")

		let turnover = balanceSheet.workingCapitalTurnover(revenue: revenue)

		#expect(!turnover.periods.contains(Self.wcQuarters[2]),
				"an unanswerable quarter is left out, not reported as 0.0×")

		// The paired control: the two quarters revenue does cover are answered exactly as
		// they are when it covers all three.
		let q1 = try #require(turnover[Self.wcQuarters[0]])
		let q1Expected = Self.revenueByQuarter[0] / Self.wcByQuarter[0]
		#expect(q1.isEqual(to: q1Expected))

		let q2Divisor = (Self.wcByQuarter[0] + Self.wcByQuarter[1]) / 2.0
		let q2Expected = Self.revenueByQuarter[1] / q2Divisor
		let q2 = try #require(turnover[Self.wcQuarters[1]])
		#expect(q2.isEqual(to: q2Expected))
	}

	/// Revenue that starts *after* the balance sheet is the same absence seen from the other
	/// side, and `TimeSeries` cannot tell the two apart — the fix does not depend on being
	/// able to.
	@Test("Turnover_QuarterBeforeRevenueBeginsIsOmitted")
	func turnoverQuarterBeforeRevenueBeginsIsOmitted() throws {
		let balanceSheet = try turnoverBalanceSheet()
		let lateQuarters = Array(Self.wcQuarters.suffix(2))
		let lateValues = Array(Self.revenueByQuarter.suffix(2))
		let revenue = TimeSeries(periods: lateQuarters, values: lateValues)

		let turnover = balanceSheet.workingCapitalTurnover(revenue: revenue)

		#expect(!turnover.periods.contains(Self.wcQuarters[0]),
				"the quarter before revenue begins has no turnover to report")

		// The later quarters still average against the balance sheet's own prior quarter,
		// which it does cover.
		let q2Divisor = (Self.wcByQuarter[0] + Self.wcByQuarter[1]) / 2.0
		let q2Expected = Self.revenueByQuarter[1] / q2Divisor
		let q2 = try #require(turnover[Self.wcQuarters[1]])
		#expect(q2.isEqual(to: q2Expected))
	}
}
