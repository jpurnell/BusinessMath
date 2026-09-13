//
//  ActivityRatioDayCountTests.swift
//  BusinessMathTests
//
//  DSO, DIO and DPO divide a day count by a turnover rate. The two have to describe
//  the same period, and for any statement that is not annual they did not.
//

import Testing
import Foundation
@testable import BusinessMath

/// The day count in an activity ratio must match the period of the flow beneath it.
///
/// `daysInventoryOutstanding` is `daysPerYear / inventoryTurnover`, and
/// `inventoryTurnover` is COGS over average inventory **for the period** — so on a
/// quarterly statement it is turns *per quarter*. Dividing an annual day count by a
/// quarterly rate is a dimensional error: it answers "how many days would this take if
/// the quarter's turns were a year's turns", which is not a question anyone asks.
///
/// Measured before the fix, on the quarterly documentation fixture: inventory turned
/// 4.0 times in Q1 2024 and `daysInventoryOutstanding` reported **91.25 days**, where
/// the quarter is 91 days long and the answer is 91/4 = 22.75. **A factor of 4.01.**
///
/// The number is also the reason nobody caught it. 91.25 sits a quarter of a day from
/// the 91 days in the quarter, so a reader checking "is DIO about one quarter?" sees
/// agreement. It is wrong by 4× and shaped like the right answer.
@Suite("Activity ratio day counts")
struct ActivityRatioDayCountTests {

    private func fixture() throws -> (IncomeStatement<Double>, BalanceSheet<Double>, Period) {
        let income = try IncomeStatement<Double>.documentationFixture
        let balance = try BalanceSheet<Double>.documentationFixture
        let first = try #require(income.periods.first)
        return (income, balance, first)
    }

    /// The fixture is quarterly, which is what makes the dimensional error visible.
    @Test("The documentation fixture is quarterly, and Q1 2024 has 91 days")
    func fixtureIsQuarterlyAndLeap() throws {
        let (_, _, q1) = try fixture()
        #expect(q1.type == .quarterly, "the fixture is \(q1.type); this suite assumes quarterly")

        // 2024 is a leap year: 31 + 29 + 31.
        let days = DayCountConvention.actual365.days(in: q1)
        // A day count is an integer-valued Double, so this is a deliberate IEEE comparison.
        #expect(days.isEqual(to: 91.0), "Q1 2024 measured \(days) days")
    }

    /// Days outstanding is the period's own day count over the period's own turn rate.
    @Test("DIO, DSO and DPO use the days in their own period")
    func daysOutstandingUsesThePeriodsDayCount() throws {
        let (income, balance, q1) = try fixture()
        let days = DayCountConvention.actual365.days(in: q1)

        let inventoryTurns = try #require(
            try inventoryTurnover(incomeStatement: income, balanceSheet: balance)[q1])
        let dio = try #require(
            try daysInventoryOutstanding(incomeStatement: income, balanceSheet: balance)[q1])
        let expectedDIO = days / inventoryTurns
        #expect(abs(dio - expectedDIO) < 1e-9,
                "DIO \(dio) against \(days) days over \(inventoryTurns) turns = \(expectedDIO)")

        let receivableTurns = try #require(
            try receivablesTurnover(incomeStatement: income, balanceSheet: balance)[q1])
        let dso = try #require(
            try daysSalesOutstanding(incomeStatement: income, balanceSheet: balance)[q1])
        let expectedDSO = days / receivableTurns
        #expect(abs(dso - expectedDSO) < 1e-9,
                "DSO \(dso) against \(days) days over \(receivableTurns) turns = \(expectedDSO)")

        let dpo = try #require(
            try daysPayableOutstanding(incomeStatement: income, balanceSheet: balance)[q1])
        #expect(dpo > 0.0 && dpo <= days,
                "DPO \(dpo) is outside the \(days) days of its own period")
    }

    /// The dimensional invariant, stated without reference to any expected value.
    ///
    /// If inventory turns over at least once within the period, the days it sits there
    /// cannot exceed the days in the period. This holds for every correct implementation
    /// and every fixture, and it is what the annual day count violated: at 4.0 turns in a
    /// 91-day quarter the old code reported 91.25 days.
    @Test("Days outstanding cannot exceed the period when the flow turns at least once")
    func daysCannotExceedThePeriodWhenTurningAtLeastOnce() throws {
        let (income, balance, q1) = try fixture()
        let days = DayCountConvention.actual365.days(in: q1)

        let turns = try #require(
            try inventoryTurnover(incomeStatement: income, balanceSheet: balance)[q1])
        try #require(turns >= 1.0)

        let dio = try #require(
            try daysInventoryOutstanding(incomeStatement: income, balanceSheet: balance)[q1])
        // TEST-QUALITY: non-strict-improvement — equality is exact at one turn per period
        #expect(dio <= days,
                "inventory turned \(turns) times in \(days) days, so it cannot sit for \(dio)")
    }

    /// The cash conversion cycle is DIO + DSO − DPO, and stays so under the fix.
    ///
    /// This identity held before the fix too — the day count is a common factor and
    /// cancels — which is exactly why it could not detect the error. Kept as a
    /// regression guard, and noted here so a later reader does not mistake it for one.
    @Test("The cash conversion cycle identity holds")
    func cashConversionCycleIdentity() throws {
        let (income, balance, q1) = try fixture()
        let dio = try #require(
            try daysInventoryOutstanding(incomeStatement: income, balanceSheet: balance)[q1])
        let dso = try #require(
            try daysSalesOutstanding(incomeStatement: income, balanceSheet: balance)[q1])
        let dpo = try #require(
            try daysPayableOutstanding(incomeStatement: income, balanceSheet: balance)[q1])
        let efficiency = efficiencyRatios(incomeStatement: income, balanceSheet: balance)
        let ccc = try #require(efficiency.cashConversionCycle?[q1])

        #expect(abs(ccc - (dio + dso - dpo)) < 1e-9,
                "CCC \(ccc) against DIO \(dio) + DSO \(dso) − DPO \(dpo)")
    }

    /// A caller can ask for a different convention, and 30/360 is the one that differs.
    ///
    /// Under 30/360 a quarter is 90 days by construction, against 91 actual days for
    /// Q1 2024 — so the two conventions disagree by exactly one day here, which is what
    /// makes this a test rather than a restatement.
    @Test("The day-count convention is the caller's to choose")
    func conventionIsSelectable() throws {
        let (income, balance, q1) = try fixture()

        let actualDays = DayCountConvention.actual365.days(in: q1)
        let thirtyDays = DayCountConvention.thirty360.days(in: q1)
        #expect(actualDays.isEqual(to: 91.0))
        #expect(thirtyDays.isEqual(to: 90.0), "30/360 measured \(thirtyDays) days for a quarter")

        let byActual = try #require(
            try daysInventoryOutstanding(incomeStatement: income, balanceSheet: balance,
                                         dayCount: .actual365)[q1])
        let byThirty = try #require(
            try daysInventoryOutstanding(incomeStatement: income, balanceSheet: balance,
                                         dayCount: .thirty360)[q1])
        let turns = try #require(
            try inventoryTurnover(incomeStatement: income, balanceSheet: balance)[q1])

        #expect(abs(byActual - actualDays / turns) < 1e-9)
        #expect(abs(byThirty - thirtyDays / turns) < 1e-9)
        #expect(byActual > byThirty, "91 days should give more than 90 at the same turn rate")
    }
}
