//
//  DebtAndWaterfallCoverageTests.swift
//  BusinessMath
//
//  Closing wave of the contaminated-input sweep (Phase 2), covering the `?? 0`
//  fallbacks in `DebtInstrument`, `DebtCovenants`, `LeaseAccounting` and the
//  liquidation waterfall.
//
//  Most of what is pinned here are **non-defects**. The waterfall accumulators and the
//  amortization-schedule totals were measured legitimate, and the tests that assert so
//  exist to stop a later sweep from "fixing" them into something worse. Two sites were
//  measured as genuine fabrications — an uncovered period in a covenant ratio, and an
//  empty payment series in a sale-and-leaseback — and their tests fail against the
//  unfixed source.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Debt, lease and waterfall zero-fallback coverage")
struct DebtAndWaterfallCoverageTests {

    // MARK: - Fixtures

    private func entity() -> Entity {
        Entity(id: "ZFB", primaryType: .ticker, name: "Zero Fallback Co")
    }

    private var q1: Period { Period.quarter(year: 2025, quarter: 1) }
    private var q2: Period { Period.quarter(year: 2025, quarter: 2) }

    /// A balance sheet whose equity account carries **one period more** than the
    /// statement declares, so `totalEquity` covers `q2` while `interestBearingDebt`
    /// does not.
    ///
    /// `validatePeriodConsistency` requires each account to cover at least the
    /// statement's periods but permits extra ones, and every aggregated accessor is
    /// `accounts[0].timeSeries + …` where `+` is `zip`. The two operands of
    /// `debtToEquity` therefore span different period sets, which is what makes the
    /// uncovered-numerator branch reachable from the public API.
    private func staggeredBalanceSheet(
        debtAtQ1: Double,
        equityAtQ1: Double,
        equityAtQ2: Double
    ) throws -> BalanceSheet<Double> {
        let e = entity()
        let cash = try Account(
            entity: e,
            name: "Cash",
            balanceSheetRole: .cashAndEquivalents,
            timeSeries: TimeSeries(periods: [q1], values: [500_000.0])
        )
        let payables = try Account(
            entity: e,
            name: "Payables",
            balanceSheetRole: .otherCurrentLiabilities,
            timeSeries: TimeSeries(periods: [q1], values: [300_000.0])
        )
        let debt = try Account(
            entity: e,
            name: "Term Loan",
            balanceSheetRole: .longTermDebt,
            timeSeries: TimeSeries(periods: [q1], values: [debtAtQ1])
        )
        let equity = try Account(
            entity: e,
            name: "Common Stock",
            balanceSheetRole: .commonStock,
            timeSeries: TimeSeries(periods: [q1, q2], values: [equityAtQ1, equityAtQ2])
        )
        return try BalanceSheet(entity: e, periods: [q1], accounts: [cash, payables, debt, equity])
    }

    private func incomeStatement(
        revenue: Double,
        cogs: Double,
        opex: Double,
        interest: Double
    ) throws -> IncomeStatement<Double> {
        let e = entity()
        let rev = try Account(
            entity: e,
            name: "Revenue",
            incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: [q1], values: [revenue])
        )
        let cost = try Account(
            entity: e,
            name: "COGS",
            incomeStatementRole: .costOfGoodsSold,
            timeSeries: TimeSeries(periods: [q1], values: [cogs])
        )
        let operating = try Account(
            entity: e,
            name: "SG&A",
            incomeStatementRole: .operatingExpenseOther,
            timeSeries: TimeSeries(periods: [q1], values: [opex])
        )
        let interestExpense = try Account(
            entity: e,
            name: "Interest Expense",
            incomeStatementRole: .interestExpense,
            timeSeries: TimeSeries(periods: [q1], values: [interest])
        )
        return try IncomeStatement(
            entity: e,
            periods: [q1],
            accounts: [rev, cost, operating, interestExpense]
        )
    }

    // MARK: - DebtCovenants: an uncovered period is not a measured zero

    @Test("A maximum-ratio covenant is not certified from a period the numerator never covered")
    func maximumRatioIsNotCertifiedFromAnUncoveredPeriod() throws {
        let balance = try staggeredBalanceSheet(
            debtAtQ1: 800_000.0,
            equityAtQ1: 400_000.0,
            equityAtQ2: 0.0
        )
        let income = try incomeStatement(revenue: 1_000_000.0, cogs: 400_000.0, opex: 200_000.0, interest: 50_000.0)

        let covenant = FinancialCovenant(
            name: "Max Debt/Equity",
            requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
        )

        // `q2` is covered by the equity account and not by the debt account.
        let results = covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q2)
        let result = try #require(results.first)

        // Before the fix the missing numerator was read as a measured `0`, and a
        // leverage ratio of 0.00 clears a maximum-leverage covenant outright: the
        // borrower was certified compliant from statements that said nothing about the
        // period. `.nan` fails `<=`, so nothing is certified.
        #expect(result.actualValue.isNaN, "an uncovered period has no ratio to report")
        #expect(result.isCompliant == false, "a covenant cannot be certified from data that is not there")
    }

    @Test("A covered period still reports its ratio and its verdict")
    func coveredPeriodStillReportsItsRatio() throws {
        let balance = try staggeredBalanceSheet(
            debtAtQ1: 800_000.0,
            equityAtQ1: 400_000.0,
            equityAtQ2: 0.0
        )
        let income = try incomeStatement(revenue: 1_000_000.0, cogs: 400_000.0, opex: 200_000.0, interest: 50_000.0)

        let covenant = FinancialCovenant(
            name: "Max Debt/Equity",
            requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
        )

        let results = covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1)
        let result = try #require(results.first)

        let expected: Double = 800_000.0 / 400_000.0
        #expect(result.actualValue.isEqual(to: expected), "800k of debt over 400k of equity is 2.0")
        #expect(result.isCompliant, "2.0 satisfies a 2.0 ceiling")
    }

    @Test("Debt against no equity stays unbounded, not zero")
    func debtAgainstNoEquityStaysUnbounded() throws {
        let balance = try staggeredBalanceSheet(
            debtAtQ1: 800_000.0,
            equityAtQ1: 0.0,
            equityAtQ2: 0.0
        )
        let income = try incomeStatement(revenue: 1_000_000.0, cogs: 400_000.0, opex: 200_000.0, interest: 50_000.0)

        let covenant = FinancialCovenant(
            name: "Max Debt/Equity",
            requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
        )

        let results = covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1)
        let result = try #require(results.first)

        // Both operands are filed for `q1`; only the denominator is zero. That is a
        // measurement, and a company financed entirely by debt is the last one that
        // should read as unlevered.
        #expect(result.actualValue.isInfinite, "leverage against nothing is unbounded")
        #expect(result.isCompliant == false, "an unbounded ratio breaches a ceiling")
    }

    @Test("An entity with neither debt nor equity reports a measured zero")
    func emptyEntityReportsAMeasuredZero() throws {
        let balance = try staggeredBalanceSheet(
            debtAtQ1: 0.0,
            equityAtQ1: 0.0,
            equityAtQ2: 0.0
        )
        let income = try incomeStatement(revenue: 1_000_000.0, cogs: 400_000.0, opex: 200_000.0, interest: 50_000.0)

        let covenant = FinancialCovenant(
            name: "Max Debt/Equity",
            requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
        )

        let results = covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1)
        let result = try #require(results.first)

        // Zero over zero with both sides *filed* as zero is an empty balance sheet, not
        // an absent one. The reading stays `0.0`; this pins the distinction the guard
        // draws so the two are never tidied into agreement.
        #expect(result.actualValue.isEqual(to: 0.0), "nothing over nothing is reported as zero")
        #expect(result.isCompliant, "no debt clears a leverage ceiling")
    }

    @Test("An omitted principal payment means no amortisation, and reads as better coverage")
    func omittedPrincipalPaymentReadsAsBetterCoverage() throws {
        let balance = try staggeredBalanceSheet(
            debtAtQ1: 800_000.0,
            equityAtQ1: 400_000.0,
            equityAtQ2: 0.0
        )
        let income = try incomeStatement(revenue: 1_000_000.0, cogs: 400_000.0, opex: 200_000.0, interest: 50_000.0)

        let omitted = FinancialCovenant(
            name: "DSCR omitted",
            requirement: .minimumRatio(metric: .debtServiceCoverage, threshold: 0.0)
        )
        let explicitZero = FinancialCovenant(
            name: "DSCR explicit zero",
            requirement: .minimumRatio(metric: .debtServiceCoverage, threshold: 0.0, principalPayment: 0.0)
        )
        let amortising = FinancialCovenant(
            name: "DSCR amortising",
            requirement: .minimumRatio(metric: .debtServiceCoverage, threshold: 0.0, principalPayment: 150_000.0)
        )

        let omittedResult = try #require(
            omitted.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1).first
        )
        let explicitResult = try #require(
            explicitZero.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1).first
        )
        let amortisingResult = try #require(
            amortising.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1).first
        )

        let omittedValue: Double = omittedResult.actualValue
        let explicitValue: Double = explicitResult.actualValue
        let amortisingValue: Double = amortisingResult.actualValue

        // `nil` is taken as "no scheduled amortisation", which is a real term sheet.
        #expect(omittedValue.isEqual(to: explicitValue), "omitting principal is exactly declaring it zero")

        // And it is not a neutral default: the denominator shrinks, so the reported
        // coverage is higher than the real one.
        #expect(omittedValue.isFinite, "the fixture must produce a finite coverage ratio")
        #expect(omittedValue > 0.0, "the fixture must produce positive operating income")
        #expect(amortisingValue.isFinite, "the amortising fixture must produce a finite coverage ratio")
        #expect(amortisingValue < omittedValue, "adding principal to the denominator lowers coverage")

        // A threshold between the two measured values shows the direction of the error:
        // the covenant that leaves principal out passes where the amortising one fails.
        let threshold: Double = (amortisingValue + omittedValue) / 2.0
        let optimistic = FinancialCovenant(
            name: "DSCR optimistic",
            requirement: .minimumRatio(metric: .debtServiceCoverage, threshold: threshold)
        )
        let honest = FinancialCovenant(
            name: "DSCR honest",
            requirement: .minimumRatio(metric: .debtServiceCoverage, threshold: threshold, principalPayment: 150_000.0)
        )
        let optimisticResult = try #require(
            optimistic.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1).first
        )
        let honestResult = try #require(
            honest.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1).first
        )
        #expect(optimisticResult.isCompliant, "interest-only coverage clears the midpoint")
        #expect(honestResult.isCompliant == false, "coverage including principal does not")
    }

    // MARK: - DebtCovenants: `covenantReading` fails in both directions

    /// Every account stops at `q1`, so every aggregated accessor does too and a covenant
    /// tested at `q2` is asking about a period the statements do not cover.
    private func flatBalanceSheet(debt: Double, equity: Double) throws -> BalanceSheet<Double> {
        let e = entity()
        let cash = try Account(
            entity: e,
            name: "Cash",
            balanceSheetRole: .cashAndEquivalents,
            timeSeries: TimeSeries(periods: [q1], values: [500_000.0])
        )
        let loan = try Account(
            entity: e,
            name: "Term Loan",
            balanceSheetRole: .longTermDebt,
            timeSeries: TimeSeries(periods: [q1], values: [debt])
        )
        let stock = try Account(
            entity: e,
            name: "Common Stock",
            balanceSheetRole: .commonStock,
            timeSeries: TimeSeries(periods: [q1], values: [equity])
        )
        return try BalanceSheet(entity: e, periods: [q1], accounts: [cash, loan, stock])
    }

    /// An income statement declaring only `q1` whose accounts all carry `q2` as well, so
    /// `operatingIncome` really does span both periods.
    ///
    /// The depreciation account is load-bearing: `operatingIncome` subtracts
    /// `aggregateAccounts(nonCashChargeAccounts, periods:)`, which with no such accounts
    /// is a zero series over the statement's **declared** periods and would clip the
    /// result back to `q1`. With one, the fixture provably reaches `q2`.
    ///
    /// `secondInterestAtQ2` controls whether the second interest account covers `q2`;
    /// `nil` stops it at `q1`, which is how an interest expense comes out understated.
    private func extendedIncomeStatement(secondInterestAtQ2: Double?) throws -> IncomeStatement<Double> {
        let e = entity()
        let both: [Period] = [q1, q2]
        let rev = try Account(
            entity: e,
            name: "Revenue",
            incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: both, values: [1_000_000.0, 1_000_000.0])
        )
        let cost = try Account(
            entity: e,
            name: "COGS",
            incomeStatementRole: .costOfGoodsSold,
            timeSeries: TimeSeries(periods: both, values: [400_000.0, 400_000.0])
        )
        let opex = try Account(
            entity: e,
            name: "SG&A",
            incomeStatementRole: .operatingExpenseOther,
            timeSeries: TimeSeries(periods: both, values: [200_000.0, 200_000.0])
        )
        let dna = try Account(
            entity: e,
            name: "Depreciation",
            incomeStatementRole: .depreciationAmortization,
            timeSeries: TimeSeries(periods: both, values: [50_000.0, 50_000.0])
        )
        let interestA = try Account(
            entity: e,
            name: "Interest A",
            incomeStatementRole: .interestExpense,
            timeSeries: TimeSeries(periods: both, values: [30_000.0, 30_000.0])
        )
        var accounts: [Account<Double>] = [rev, cost, opex, dna, interestA]
        if let atQ2 = secondInterestAtQ2 {
            let interestB = try Account(
                entity: e,
                name: "Interest B",
                incomeStatementRole: .interestExpense,
                timeSeries: TimeSeries(periods: both, values: [20_000.0, atQ2])
            )
            accounts.append(interestB)
        } else {
            let interestB = try Account(
                entity: e,
                name: "Interest B",
                incomeStatementRole: .interestExpense,
                timeSeries: TimeSeries(periods: [q1], values: [20_000.0])
            )
            accounts.append(interestB)
        }
        return try IncomeStatement(entity: e, periods: [q1], accounts: accounts)
    }

    @Test("A maximum debt/EBITDA covenant no longer passes on a period the balance sheet never covered")
    func maximumDebtToEBITDANoLongerPassesOnMissingData() throws {
        let balance = try flatBalanceSheet(debt: 800_000.0, equity: 400_000.0)
        let income = try extendedIncomeStatement(secondInterestAtQ2: 20_000.0)

        // The fixture must actually exercise the asymmetry: EBITDA reaches `q2` and
        // total liabilities do not. Assert that rather than assuming it.
        let ebitdaAtQ2: Double = try #require(income.operatingIncome[q2])
        #expect(ebitdaAtQ2.isEqual(to: 350_000.0), "1.0m revenue less 400k COGS, 200k opex and 50k D&A")
        #expect(balance.totalLiabilities.periods.contains(q2) == false, "liabilities stop at q1")

        let covenant = FinancialCovenant(
            name: "Max Debt/EBITDA",
            requirement: .maximumRatio(metric: .debtToEBITDA, threshold: 3.0)
        )
        let result = try #require(
            covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q2).first
        )

        // Debt fabricated as `0` over a real EBITDA is a leverage ratio of 0.00, which
        // clears a 3.0x ceiling outright — a borrower certified unlevered because its
        // balance sheet stopped a quarter early.
        #expect(result.actualValue.isNaN, "an uncovered balance sheet has no leverage to report")
        #expect(result.isCompliant == false, "missing data must not clear a leverage ceiling")
        // …and it is not a breach either. `isCompliant == false` was the whole answer until
        // `status` existed, so a lender reading this report was told a default had occurred
        // when the truth was that a quarter of the balance sheet was missing.
        #expect(result.status == .notAnswerable, "an untested covenant is not a breached one")
    }

    @Test("A maximum debt/EBITDA covenant still evaluates a covered period")
    func maximumDebtToEBITDAStillEvaluatesACoveredPeriod() throws {
        let balance = try flatBalanceSheet(debt: 800_000.0, equity: 400_000.0)
        let income = try extendedIncomeStatement(secondInterestAtQ2: 20_000.0)

        let covenant = FinancialCovenant(
            name: "Max Debt/EBITDA",
            requirement: .maximumRatio(metric: .debtToEBITDA, threshold: 3.0)
        )
        let result = try #require(
            covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1).first
        )

        // Total liabilities here is the term loan alone; EBITDA is 350k, as above.
        let expected: Double = 800_000.0 / 350_000.0
        let gap: Double = abs(result.actualValue - expected)
        #expect(gap < 1e-9, "2.29x of leverage")
        #expect(result.isCompliant, "2.29x clears a 3.0x ceiling")
    }

    @Test("A minimum net-worth covenant reports no figure for a period the balance sheet never covered")
    func minimumNetWorthReportsNoFigureOnMissingData() throws {
        let balance = try flatBalanceSheet(debt: 800_000.0, equity: 400_000.0)
        let income = try extendedIncomeStatement(secondInterestAtQ2: 20_000.0)

        let covenant = FinancialCovenant(
            name: "Min Tangible Net Worth",
            requirement: .minimumValue(metric: .tangibleNetWorth, threshold: 250_000.0)
        )
        let result = try #require(
            covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q2).first
        )

        // The other direction of the same fabrication. Equity read as `0` is a *stated*
        // net worth of zero, and it trips a minimum-net-worth covenant for the same
        // missing quarter that cleared the leverage ceiling above — one report, two
        // opposite conclusions from one absence.
        //
        // `isCompliant` is a `Bool` with no room for "not answerable", so the verdict is
        // still `false`; what changes is that `actualValue` no longer claims a net worth
        // the statements never reported. Closing that last conflation needs a widened
        // `CovenantComplianceResult`, which is a deliberate API decision.
        #expect(result.actualValue.isNaN, "an uncovered period has no net worth to report")
        #expect(result.isCompliant == false, "and nothing is certified from it either")
    }

    @Test("A minimum net-worth covenant still passes on a covered period")
    func minimumNetWorthStillPassesOnACoveredPeriod() throws {
        let balance = try flatBalanceSheet(debt: 800_000.0, equity: 400_000.0)
        let income = try extendedIncomeStatement(secondInterestAtQ2: 20_000.0)

        let covenant = FinancialCovenant(
            name: "Min Tangible Net Worth",
            requirement: .minimumValue(metric: .tangibleNetWorth, threshold: 250_000.0)
        )
        let result = try #require(
            covenant.isCompliant(incomeStatement: income, balanceSheet: balance, period: q1).first
        )
        #expect(result.actualValue.isEqual(to: 400_000.0), "the common stock account")
        #expect(result.isCompliant, "400k clears a 250k floor")
    }

    @Test("An interest account that stops early no longer understates the expense")
    func interestAccountStoppingEarlyNoLongerUnderstatesTheExpense() throws {
        let balance = try flatBalanceSheet(debt: 800_000.0, equity: 400_000.0)
        let truncated = try extendedIncomeStatement(secondInterestAtQ2: nil)
        let complete = try extendedIncomeStatement(secondInterestAtQ2: 20_000.0)

        let covenant = FinancialCovenant(
            name: "Min Interest Coverage",
            requirement: .minimumRatio(metric: .interestCoverage, threshold: 8.0)
        )

        // Control first: with both interest accounts covering `q2`, coverage is
        // 350,000 / 50,000 = 7.0 and the 8.0x floor is breached.
        let full = try #require(
            covenant.isCompliant(incomeStatement: complete, balanceSheet: balance, period: q2).first
        )
        #expect(full.actualValue.isEqual(to: 7.0), "350k of EBIT over 50k of interest")
        #expect(full.isCompliant == false, "7.0x does not clear an 8.0x floor")

        // With the second account stopping at `q1`, its absence used to contribute `0`
        // to the reduction, leaving 350,000 / 30,000 = 11.67x — comfortably clear of the
        // floor the borrower had in fact breached. A dropped term in a sum is the one
        // thing the contract forbids outright.
        let short = try #require(
            covenant.isCompliant(incomeStatement: truncated, balanceSheet: balance, period: q2).first
        )
        #expect(short.actualValue.isNaN, "an interest account that stops early poisons the total")
        #expect(short.isCompliant == false, "an understated expense must not clear the floor")
    }

    // MARK: - AmortizationSchedule: the totals cover every period by construction

    @Test("Amortization totals sum every period the schedule declares")
    func amortizationTotalsSumEveryPeriod() throws {
        let start = try #require(
            gregorianUTC.date(from: DateComponents(year: 2025, month: 1, day: 1))
        )
        let maturity = try #require(
            gregorianUTC.date(from: DateComponents(year: 2030, month: 1, day: 1))
        )
        let loan = DebtInstrument(
            principal: 1_000_000.0,
            interestRate: 0.06,
            startDate: start,
            maturityDate: maturity,
            paymentFrequency: .quarterly,
            amortizationType: .straightLine
        )
        let schedule = try loan.schedule()

        // The `?? 0.0` in the three totals is unreachable: every branch of `schedule()`
        // writes all five dictionaries for every element of `periods`, and the
        // memberwise initializer is internal, so no caller can supply a `periods` array
        // the dictionaries do not cover. `compactMap` would silently shorten if that
        // ever stopped being true, so the count is asserted rather than the sum alone.
        #expect(schedule.periods.count == 20, "five years of quarterly payments")

        let pulledInterest: [Double] = schedule.periods.compactMap { schedule.interest[$0] }
        let pulledPrincipal: [Double] = schedule.periods.compactMap { schedule.principal[$0] }
        let pulledPayment: [Double] = schedule.periods.compactMap { schedule.payment[$0] }

        #expect(pulledInterest.count == schedule.periods.count, "every period carries an interest figure")
        #expect(pulledPrincipal.count == schedule.periods.count, "every period carries a principal figure")
        #expect(pulledPayment.count == schedule.periods.count, "every period carries a payment figure")

        let summedInterest: Double = pulledInterest.reduce(0.0, +)
        let summedPrincipal: Double = pulledPrincipal.reduce(0.0, +)
        let summedPayment: Double = pulledPayment.reduce(0.0, +)

        #expect(summedInterest.isEqual(to: schedule.totalInterest), "no period is skipped by the reduction")
        #expect(summedPrincipal.isEqual(to: schedule.totalPrincipal), "no period is skipped by the reduction")
        #expect(summedPayment.isEqual(to: schedule.totalPayments), "no period is skipped by the reduction")

        // Straight-line repays the whole principal, which is the independent check that
        // the totals are the *whole* figure and not a partial one.
        let principalGap: Double = abs(schedule.totalPrincipal - 1_000_000.0)
        #expect(principalGap < 1e-6, "straight-line amortisation repays the full principal")
    }

    @Test("A bullet schedule's totals match the closed form")
    func bulletScheduleTotalsMatchClosedForm() throws {
        let start = try #require(
            gregorianUTC.date(from: DateComponents(year: 2025, month: 1, day: 1))
        )
        let maturity = try #require(
            gregorianUTC.date(from: DateComponents(year: 2029, month: 1, day: 1))
        )
        let bond = DebtInstrument(
            principal: 1_000_000.0,
            interestRate: 0.08,
            startDate: start,
            maturityDate: maturity,
            paymentFrequency: .annual,
            amortizationType: .bulletPayment
        )
        let schedule = try bond.schedule()
        let n: Int = schedule.periods.count
        #expect(n == 4, "four annual coupons")

        // Derived, not recalled: a bullet pays 8% of the full principal every period and
        // the principal once at maturity.
        let expectedInterest: Double = 1_000_000.0 * 0.08 * Double(n)
        let interestGap: Double = abs(schedule.totalInterest - expectedInterest)
        #expect(interestGap < 1e-6, "every coupon accrues on the undiminished principal")

        let principalGap: Double = abs(schedule.totalPrincipal - 1_000_000.0)
        #expect(principalGap < 1e-6, "the principal is repaid once, at maturity")
    }

    // MARK: - SaleAndLeaseback: an empty payment series is not a free leaseback

    @Test("A sale-and-leaseback built from no payments is not answerable")
    func saleAndLeasebackWithNoPaymentsIsNotAnswerable() throws {
        let empty = TimeSeries<Double>(periods: [], values: [])
        let transaction = SaleAndLeaseback(
            carryingValue: 500_000.0,
            salePrice: 600_000.0,
            leasebackPayments: empty,
            discountRate: 0.06,
            startDate: q1.startDate
        )

        // Before the fix this read `annualLeasePayment == 0`, which priced the leaseback
        // obligation at zero, made `netCashBenefit` the entire sale price and answered
        // `isEconomicallyBeneficial == true` — the most favourable verdict the type can
        // give, from a series that carried no payments at all.
        #expect(transaction.annualLeasePayment.isNaN, "no payments filed is not a payment of zero")
        #expect(transaction.leaseObligationPV.isNaN, "an unpriced obligation has no present value")
        #expect(transaction.netCashBenefit.isNaN, "and no net benefit either")
        #expect(
            transaction.isEconomicallyBeneficial == false,
            "an unpriced transaction is never certified beneficial"
        )
        #expect(transaction.leaseTerm == 0, "the term still reports what the series contained")
    }

    @Test("A sale-and-leaseback with payments prices the annuity")
    func saleAndLeasebackWithPaymentsPricesTheAnnuity() throws {
        let periods: [Period] = [q1, q1 + 1, q1 + 2, q1 + 3]
        let payments = TimeSeries(
            periods: periods,
            values: [40_000.0, 40_000.0, 40_000.0, 40_000.0]
        )
        let transaction = SaleAndLeaseback(
            carryingValue: 500_000.0,
            salePrice: 600_000.0,
            leasebackPayments: payments,
            discountRate: 0.06,
            startDate: q1.startDate
        )

        #expect(transaction.annualLeasePayment.isEqual(to: 40_000.0), "the opening payment, in period order")
        #expect(transaction.leaseTerm == 4, "one period per payment")

        // Independent oracle: discount each payment separately rather than reusing the
        // annuity closed form the implementation uses.
        var byHand: Double = 0.0
        for t in 1...4 {
            let discount: Double = Double.pow(1.06, Double(t))
            byHand += 40_000.0 / discount
        }
        let gap: Double = abs(transaction.leaseObligationPV - byHand)
        #expect(gap < 1e-6, "the annuity form agrees with the term-by-term discounting")

        let benefit: Double = 600_000.0 - byHand
        let benefitGap: Double = abs(transaction.netCashBenefit - benefit)
        #expect(benefitGap < 1e-6, "net benefit is the sale price less the obligation")
    }

    // MARK: - Waterfall: the accumulators are keyed by recipient, not by period

    @Test("A participant no tier has reached reads as a measured zero, and the key is present")
    func unreachedParticipantsReadAsMeasuredZero() throws {
        let waterfall = try LiquidationWaterfall {
            try Tier("Senior Debt", priority: 1) {
                try CapitalReturn(1_000_000)
            }
            try Tier("Residual", priority: 2) {
                try ProRata([
                    ("LP", 0.70),
                    ("GP", 0.30)
                ])
            }
        }

        // Proceeds are exhausted by the first tier, so the second is never reached.
        let result = waterfall.distribute(1_000_000)

        let senior: Double = try #require(result.distributions["Senior Debt"])
        let lp: Double = try #require(result.distributions["LP"])
        let gp: Double = try #require(result.distributions["GP"])

        #expect(senior.isEqual(to: 1_000_000.0), "the first tier takes everything")
        #expect(lp.isEqual(to: 0.0), "a participant nothing reached has received nothing")
        #expect(gp.isEqual(to: 0.0), "a participant nothing reached has received nothing")

        // The `?? 0` in `LiquidationWaterfall.distribute` is a real measurement rather
        // than a fabricated one because absence can only mean "no tier has paid this
        // name yet": every read uses the same key it then writes, and the dictionary
        // starts empty inside this call. The key set proves it — it is exactly the
        // recipients the tiers name, with nothing looked up from anywhere else.
        let keys: Set<String> = Set(result.distributions.keys)
        #expect(keys == Set(["Senior Debt", "LP", "GP"]), "recipients come only from the tiers")
        #expect(result.remaining.isEqual(to: 0.0), "nothing is left over")
    }

    @Test("Non-positive proceeds still list every tier at zero")
    func nonPositiveProceedsStillListEveryTier() throws {
        let waterfall = try LiquidationWaterfall {
            try Tier("Senior Debt", priority: 1) {
                try CapitalReturn(1_000_000)
            }
            try Tier("Residual", priority: 2) {
                try ProRata([("LP", 1.0)])
            }
        }

        let result = waterfall.distribute(0)
        let senior: Double = try #require(result.distributions["Senior Debt"])
        let residual: Double = try #require(result.distributions["Residual"])
        #expect(senior.isEqual(to: 0.0), "nothing to distribute is a measured zero")
        #expect(residual.isEqual(to: 0.0), "nothing to distribute is a measured zero")
        #expect(result.remaining.isEqual(to: 0.0), "and nothing is left over")
    }

    @Test("Two tiers paying the same recipient accumulate rather than overwrite")
    func repeatedRecipientAccumulates() throws {
        let waterfall = try LiquidationWaterfall {
            try Tier("Split A", priority: 1) {
                try CapitalReturn(400_000)
            }
            try Tier("Split B", priority: 2) {
                try ProRata([
                    ("Split A", 0.50),
                    ("Other", 0.50)
                ])
            }
        }

        // 400k to the first tier, then 600k split evenly — 300k of which lands on the
        // same key. The accumulator's `?? 0` is only the seed for the first write.
        let result = waterfall.distribute(1_000_000)
        let splitA: Double = try #require(result.distributions["Split A"])
        let other: Double = try #require(result.distributions["Other"])
        #expect(splitA.isEqual(to: 700_000.0), "400k of capital plus a 300k pro-rata share")
        #expect(other.isEqual(to: 300_000.0), "the other half of the residual")
    }

    @Test("A catch-up reads its own prior distributions, keyed by the tier's own name")
    func catchUpReadsItsOwnPriorDistributions() throws {
        let tier = try Tier("GP", priority: 2) {
            try CatchUp(to: 0.20)
        }

        // 1,000,000 of capital and 250,000 of profit distributed so far, all of it to
        // the LP. The GP's target is 20% of total profits, so total profits for the
        // ratio are 250,000 / 0.80 = 312,500 and the GP should hold 62,500.
        let fresh = WaterfallContext(
            totalCapitalInvested: 1_000_000.0,
            totalProceeds: 2_000_000.0,
            currentDistributions: ["LP": 1_250_000.0]
        )
        let (freshDistribution, freshRemaining) = tier.distribute(500_000.0, context: fresh)
        let freshPaid: Double = try #require(freshDistribution["GP"])
        #expect(freshPaid.isEqual(to: 62_500.0), "the GP is brought to 20% of profits distributed")
        #expect(freshRemaining.isEqual(to: 437_500.0), "the rest passes down")

        // Same waterfall state, except the GP already holds 40,000 under its own name.
        // `currentDistributions[name] ?? 0` is a lookup into an accumulator keyed by
        // recipient, so a present key is honoured and only the shortfall is paid.
        var partial = fresh
        partial.currentDistributions["GP"] = 40_000.0
        partial.currentDistributions["LP"] = 1_210_000.0
        let (partialDistribution, partialRemaining) = tier.distribute(500_000.0, context: partial)
        let partialPaid: Double = try #require(partialDistribution["GP"])
        #expect(partialPaid.isEqual(to: 22_500.0), "only the shortfall to 62,500 is paid")
        #expect(partialRemaining.isEqual(to: 477_500.0), "the rest passes down")
    }

    @Test("A catch-up named other than its recipient starts from zero")
    func catchUpNamedOtherThanItsRecipientStartsFromZero() throws {
        // The identity in this dictionary is the *name string*. A tier called
        // "GP Catch-Up" does not see money credited to "GP", and the `?? 0` reports
        // that truthfully: the key "GP Catch-Up" has indeed received nothing. This is
        // pinned as documented behaviour, not as a fabricated zero — the naming
        // contract belongs to whoever builds the waterfall.
        let tier = try Tier("GP Catch-Up", priority: 2) {
            try CatchUp(to: 0.20)
        }
        let context = WaterfallContext(
            totalCapitalInvested: 1_000_000.0,
            totalProceeds: 2_000_000.0,
            currentDistributions: ["LP": 1_210_000.0, "GP": 40_000.0]
        )
        let (distribution, _) = tier.distribute(500_000.0, context: context)
        let paid: Double = try #require(distribution["GP Catch-Up"])
        #expect(paid.isEqual(to: 62_500.0), "the 40,000 credited to \"GP\" is a different recipient")

        // The same context, read by a tier named for the recipient, pays only the
        // shortfall. The 40,000 difference is the whole of the naming contract.
        let matched = try Tier("GP", priority: 2) {
            try CatchUp(to: 0.20)
        }
        let (matchedDistribution, _) = matched.distribute(500_000.0, context: context)
        let matchedPaid: Double = try #require(matchedDistribution["GP"])
        #expect(matchedPaid.isEqual(to: 22_500.0), "a matching name sees the 40,000 already paid")
    }
}
