//
//  AltmanDebtFreeTests.swift
//  BusinessMathTests
//
//  `altmanZScore` computes component D as market value of equity over total liabilities, and
//  bailed out of the whole calculation when that denominator was zero:
//
//      guard totalLiabilities != T(0) else { return T(0) }
//
//  A company with zero liabilities is debt-free — the safest balance sheet there is, and the
//  one where component D is unbounded. The file's own documentation puts `Z < 1.81` in the
//  "Distress Zone (High bankruptcy risk within 2 years)", so returning `0` did not merely
//  decline to answer: it returned the strongest possible bankruptcy warning about the
//  soundest possible company.
//
//  Measured before the fix, on one profitable company with 165,000 of assets:
//
//  | balance sheet          | Z-Score | zone     |
//  |------------------------|---------|----------|
//  | no liabilities         | 0.00    | DISTRESS |
//  | 12,000 accounts payable| 5.92    | safe     |
//
//  Taking on debt moved it from "about to fail" to "very safe".
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Altman Z-Score for a debt-free company")
struct AltmanDebtFreeTests {

    private let period = Period.quarter(year: 2025, quarter: 1)

    /// One profitable company, built with and without liabilities.
    private func company(liabilities: Double?) throws -> (IncomeStatement<Double>, BalanceSheet<Double>) {
        let entity = Entity(id: "DEBTFREE", primaryType: .ticker, name: "Debt Free Corp")
        let quarters = [period]

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

        var accounts = [cash, ppe, retained, stock]
        if let liabilities {
            accounts.append(try Account(entity: entity, name: "AP",
                balanceSheetRole: .accountsPayable,
                timeSeries: TimeSeries(periods: quarters, values: [liabilities])))
        }
        return (incomeStatement, try BalanceSheet(entity: entity, periods: quarters, accounts: accounts))
    }

    private func zScore(liabilities: Double?) throws -> Double {
        let (incomeStatement, balanceSheet) = try company(liabilities: liabilities)
        return altmanZScore(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: period,
            marketPrice: 50.0,
            sharesOutstanding: 1_000.0
        )
    }

    /// The fixture has to actually be debt-free, or the test proves nothing.
    @Test("Fixture_ReallyHasNoLiabilities")
    func fixtureReallyHasNoLiabilities() throws {
        let (_, balanceSheet) = try company(liabilities: nil)
        let total = try #require(balanceSheet.totalLiabilities[period])
        #expect(total.isEqual(to: 0.0))
        let assets = try #require(balanceSheet.totalAssets[period])
        #expect(assets.isEqual(to: 165_000.0), "and it is a real company, not an empty one")
    }

    /// The headline: no debt must not read as imminent bankruptcy.
    @Test("DebtFree_IsNotInTheDistressZone")
    func debtFreeIsNotInTheDistressZone() throws {
        let z = try zScore(liabilities: nil)
        #expect(!(z < 1.81), "Z = \(z) falls in the documented distress zone")
        #expect(z > 2.99, "a debt-free, profitable company belongs in the safe zone")
    }

    /// Component D genuinely diverges with no liabilities, so the Z-Score does too.
    @Test("DebtFree_ScoreIsUnbounded")
    func debtFreeScoreIsUnbounded() throws {
        let z = try zScore(liabilities: nil)
        #expect(z.isEqual(to: .infinity))
    }

    /// The property that actually broke: adding debt must not *improve* the score.
    @Test("TakingOnDebt_DoesNotImproveTheScore")
    func takingOnDebtDoesNotImproveTheScore() throws {
        let debtFree = try zScore(liabilities: nil)
        let leveraged = try zScore(liabilities: 12_000)
        #expect(leveraged < debtFree,
                "12,000 of payables scored \(leveraged) against \(debtFree) with none")
    }

    /// Control: the ordinary leveraged path is untouched.
    @Test("WithLiabilities_Unchanged")
    func withLiabilitiesUnchanged() throws {
        let z = try zScore(liabilities: 12_000)
        #expect(z.isEqual(to: 5.924848484848485))
    }
}
