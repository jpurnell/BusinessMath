//
//  DebtDefinitionAsymmetryTests.swift
//  BusinessMathTests
//
//  Two ratios on the same balance sheet answer "how levered is this" from different
//  numerators. That is deliberate, it is not documented everywhere it is relied on,
//  and nothing pinned either value.
//

import Testing
import Foundation
@testable import BusinessMath

/// `debtToAssets` and `debtToEquity` do not use the same definition of debt.
///
/// - `debtRatio` — surfaced as ``SolvencyRatios/debtToAssets`` — is
///   **total liabilities** over total assets. Accounts payable counts.
/// - `debtToEquity` is **interest-bearing debt** over total equity. Accounts payable
///   does not count.
///
/// Both are standard, and the asymmetry is intentional: the debt ratio asks what share
/// of the asset base is owed to anyone, while leverage asks what is owed to lenders.
/// The defect was that only one of them said so.
///
/// A review filed this as a bug and proposed renaming the second `longTermDebtToEquity`.
/// That diagnosis is wrong twice. The numerator is *all* interest-bearing debt — every
/// account whose `balanceSheetRole.isDebt` is true, which includes short-term debt, lines
/// of credit and convertible debt — so the rename would be **less** accurate, not more.
/// It matched the long-term-debt hypothesis only because long-term debt is the
/// documentation fixture's sole debt account. `interestBearingDebtIsNotLongTermDebt`
/// below is the test that tells the two hypotheses apart.
@Suite("Debt definition asymmetry")
struct DebtDefinitionAsymmetryTests {

	private func fixture() throws -> (BalanceSheet<Double>, [Period]) {
		let sheet = try BalanceSheet<Double>.documentationFixture
		return (sheet, sheet.periods)
	}

	/// Ground the arithmetic: every later expectation is read off these three totals.
	@Test("The fixture balances, and its totals are the ones these expectations assume")
	func fixtureTotals() throws {
		let (sheet, periods) = try fixture()
		let q1 = try #require(periods.first)

		let assets: Double = try #require(sheet.totalAssets[q1])
		let liabilities: Double = try #require(sheet.totalLiabilities[q1])
		let equity: Double = try #require(sheet.totalEquity[q1])

		#expect(assets.isEqual(to: 1000.0), "assets were \(assets)")
		#expect(liabilities.isEqual(to: 400.0), "liabilities were \(liabilities)")
		#expect(equity.isEqual(to: 600.0), "equity was \(equity)")

		// The accounting identity, stated rather than assumed.
		let sum: Double = liabilities + equity
		#expect(sum.isEqual(to: assets), "\(liabilities) + \(equity) != \(assets)")
	}

	/// The two numerators differ by exactly the operating liabilities.
	@Test("Total liabilities exceed interest-bearing debt by accounts payable")
	func numeratorsDifferByAccountsPayable() throws {
		let (sheet, periods) = try fixture()
		let q1 = try #require(periods.first)

		let liabilities: Double = try #require(sheet.totalLiabilities[q1])
		let interestBearing: Double = try #require(sheet.interestBearingDebt[q1])
		let difference: Double = liabilities - interestBearing

		#expect(interestBearing.isEqual(to: 250.0), "interest-bearing debt was \(interestBearing)")
		// Accounts payable, 150 in Q1 — an operating liability, owed to suppliers and
		// carrying no interest, so it belongs in one ratio and not the other.
		#expect(difference.isEqual(to: 150.0), "the two numerators differ by \(difference)")
	}

	/// Both values, pinned on the shared fixture, at every period it defines.
	@Test("debtToAssets is total liabilities over total assets, in all four quarters")
	func debtToAssetsIsPinned() throws {
		let (sheet, periods) = try fixture()
		let expected: [Double] = [400.0 / 1000.0, 400.0 / 1020.0, 400.0 / 1040.0, 400.0 / 1060.0]

		for (index, period) in periods.enumerated() {
			let actual: Double = try #require(sheet.debtRatio[period])
			let target: Double = expected[index]
			#expect(actual.isEqual(to: target), "period \(index) gave \(actual), not \(target)")
		}
	}

	@Test("debtToEquity is interest-bearing debt over total equity, in all four quarters")
	func debtToEquityIsPinned() throws {
		let (sheet, periods) = try fixture()
		let expected: [Double] = [250.0 / 600.0, 245.0 / 620.0, 240.0 / 640.0, 235.0 / 660.0]

		for (index, period) in periods.enumerated() {
			let actual: Double = try #require(sheet.debtToEquity[period])
			let target: Double = expected[index]
			#expect(actual.isEqual(to: target), "period \(index) gave \(actual), not \(target)")
		}
	}

	/// Q3's ratio is 240/640 = 3/8, which a binary floating-point type holds exactly.
	///
	/// Worth one assertion of its own: a tolerance cannot distinguish "correct" from
	/// "correct to within the tolerance", and here it does not have to.
	@Test("The Q3 leverage ratio is exactly 0.375, so it is asserted exactly")
	func q3LeverageIsBinaryExact() throws {
		let (sheet, periods) = try fixture()
		let q3 = periods[2]
		let leverage: Double = try #require(sheet.debtToEquity[q3])
		#expect(leverage.isEqual(to: 0.375), "Q3 leverage was \(leverage)")
	}

	/// The property that proves the two ratios are not the same measurement rescaled.
	///
	/// In Q1 the debt ratio is **below** leverage (0.4 against 0.4167); by Q4 it is
	/// **above** it (0.3774 against 0.3561). The sign of the difference flips.
	///
	/// This is the assertion worth having. "The two values differ" is satisfied by any
	/// implementation where one is a fixed multiple of the other — including several
	/// plausible wrong ones. A sign change cannot survive any monotone rescaling, so it
	/// witnesses two genuinely different numerators rather than one scaled twice.
	@Test("The two ratios cross between Q1 and Q4, so neither rescales into the other")
	func theRatiosCross() throws {
		let (sheet, periods) = try fixture()
		let q1 = periods[0]
		let q4 = periods[3]

		let assetsQ1: Double = try #require(sheet.debtRatio[q1])
		let equityQ1: Double = try #require(sheet.debtToEquity[q1])
		let assetsQ4: Double = try #require(sheet.debtRatio[q4])
		let equityQ4: Double = try #require(sheet.debtToEquity[q4])

		#expect(assetsQ1 < equityQ1, "Q1: \(assetsQ1) should sit below \(equityQ1)")
		#expect(assetsQ4 > equityQ4, "Q4: \(assetsQ4) should sit above \(equityQ4)")
	}

	/// Why the proposed rename to `longTermDebtToEquity` would have been wrong.
	///
	/// On the documentation fixture the two hypotheses are indistinguishable, because
	/// long-term debt is the only debt account there. Add a line of credit and they part:
	/// interest-bearing debt picks it up and long-term debt does not.
	@Test("Interest-bearing debt is more than long-term debt once a second debt account exists")
	func interestBearingDebtIsNotLongTermDebt() throws {
		let entity = Entity.documentationFixture
		let periods = Period.documentationQuarters

		func account(_ name: String, _ role: BalanceSheetRole, _ values: [Double]) throws -> Account<Double> {
			try Account(
				entity: entity,
				name: name,
				balanceSheetRole: role,
				timeSeries: TimeSeries(periods: periods, values: values)
			)
		}

		// The documentation fixture, plus a 100 line of credit, with equity raised to
		// keep the accounting identity intact.
		let accounts = [
			try account("Cash", .cashAndEquivalents, [300, 320, 340, 360]),
			try account("Accounts Receivable", .accountsReceivable, [200, 210, 220, 230]),
			try account("Inventory", .inventory, [150, 150, 150, 150]),
			try account("Property, Plant and Equipment", .propertyPlantEquipment, [450, 440, 430, 420]),
			try account("Accounts Payable", .accountsPayable, [150, 155, 160, 165]),
			try account("Long-Term Debt", .longTermDebt, [250, 245, 240, 235]),
			try account("Line of Credit", .lineOfCredit, [100, 100, 100, 100]),
			try account("Common Stock", .commonStock, [400, 400, 400, 400]),
			try account("Retained Earnings", .retainedEarnings, [200, 220, 240, 260])
		]
		let sheet = try BalanceSheet(entity: entity, periods: periods, accounts: accounts)
		let q1 = try #require(periods.first)

		let interestBearing: Double = try #require(sheet.interestBearingDebt[q1])
		// 250 long-term + 100 drawn on the line, and the line is interest-bearing.
		#expect(interestBearing.isEqual(to: 350.0), "interest-bearing debt was \(interestBearing)")

		// Had the numerator been long-term debt, this would read 250 and the proposed
		// rename would have described it. It does not.
		let longTermOnly: Double = 250.0
		#expect(interestBearing > longTermOnly,
				"\(interestBearing) must exceed the \(longTermOnly) of long-term debt alone")
	}
}
