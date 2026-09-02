//
//  PeriodDriverTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// Running a period-local model across a timeline.
///
/// The split this type exists to keep clean: **within-period cycles belong to
/// `CycleSolver`, cross-period carry belongs here.** Formulas never reference
/// another period; a balance moves forward because a `Rollforward` says so, in
/// data, where it can be read.
@Suite("Period Driver")
struct PeriodDriverTests {

    private let years = [
        Period.year(2024), Period.year(2025), Period.year(2026), Period.year(2027)
    ]

    private func series(_ values: [Double], over periods: [Period]) -> TimeSeries<Double> {
        TimeSeries(periods: Array(periods.prefix(values.count)), values: values)
    }

    // MARK: - Carrying a balance

    @Test("A closing balance opens the next period")
    func balanceCarriesForward() throws {
        // Debt falls by a fixed repayment each year, starting at 100.
        let model = ModelDefinition<Double>(
            inputs: ["repayment": series([10, 10, 10, 10], over: years)]
        )
        .defining("closingDebt", as: "openingDebt - repayment")

        let driver = PeriodDriver(
            definition: model,
            rollforwards: [Rollforward(opening: "openingDebt", closing: "closingDebt", seed: 100)]
        )

        let results = try driver.run(over: years)
        #expect(results["openingDebt"]?.valuesArray == [100, 90, 80, 70])
        #expect(results["closingDebt"]?.valuesArray == [90, 80, 70, 60])
    }

    @Test("The seed supplies the first period, which has no prior")
    func seedOpensTheTimeline() throws {
        let model = ModelDefinition<Double>(inputs: ["draw": series([5, 5], over: years)])
            .defining("closing", as: "opening + draw")

        let driver = PeriodDriver(
            definition: model,
            rollforwards: [Rollforward(opening: "opening", closing: "closing", seed: 40)]
        )

        let results = try driver.run(over: Array(years.prefix(2)))
        #expect(results["opening"]?.valuesArray == [40, 45])
    }

    @Test("Several rollforwards carry independently")
    func multipleRollforwards() throws {
        let model = ModelDefinition<Double>(
            inputs: [
                "debtRepayment": series([10, 10], over: years),
                "cashFlow": series([7, 7], over: years)
            ]
        )
        .defining("closingDebt", as: "openingDebt - debtRepayment")
        .defining("closingCash", as: "openingCash + cashFlow")

        let driver = PeriodDriver(
            definition: model,
            rollforwards: [
                Rollforward(opening: "openingDebt", closing: "closingDebt", seed: 100),
                Rollforward(opening: "openingCash", closing: "closingCash", seed: 0)
            ]
        )

        let results = try driver.run(over: Array(years.prefix(2)))
        #expect(results["openingDebt"]?.valuesArray == [100, 90])
        #expect(results["openingCash"]?.valuesArray == [0, 7])
    }

    // MARK: - The reference number

    @Test("Year-one interest on a swept balance is the average-balance figure")
    func averageBalanceInterest() throws {
        // 120 drawn at 10%, with 16.75 of cash available for debt service. Interest
        // accrues on the *average* of the opening and closing balance, and the
        // balance depends on the sweep, which depends on the interest — a cycle
        // inside one period, resolved by `CycleSolver`.
        //
        //   interest = rate × (opening + closing) / 2
        //   sweep    = MIN(cashAvailable − interest, opening)
        //   closing  = opening − sweep
        //
        // Solving: interest = 11.75, sweep = 5, closing = 115.
        //
        // Accruing on the *beginning* balance instead would give 120 × 10% = 12.00
        // exactly, with no cycle to solve at all. That one number is what separates
        // a correct cyclic solve from a model that broke the cycle by timing, which
        // is why it is the figure worth pinning.
        let model = ModelDefinition<Double>(
            inputs: [
                "rate": series([0.1], over: years),
                "cashAvailable": series([16.75], over: years)
            ]
        )
        .defining("interest", as: "rate * (opening + closing) / 2")
        .defining("sweep", as: "MIN(cashAvailable - interest, opening)")
        .defining("closing", as: "opening - sweep")

        let driver = PeriodDriver(
            definition: model,
            rollforwards: [Rollforward(opening: "opening", closing: "closing", seed: 120)]
        )

        let results = try driver.run(over: Array(years.prefix(1)))
        let interest = try #require(results["interest"]?.valuesArray.first)
        #expect(abs(interest - 11.75) < 1e-6, "average balance")
        #expect(abs(interest - 12.0) > 0.2, "and demonstrably not the beginning balance")
        #expect(abs(try #require(results["closing"]?.valuesArray.first) - 115) < 1e-6)
        #expect(abs(try #require(results["sweep"]?.valuesArray.first) - 5) < 1e-6)
    }

    // MARK: - Refusals

    @Test("A rollforward naming an account the model does not define is refused")
    func unknownAccountIsRefused() {
        let model = ModelDefinition<Double>(inputs: ["x": series([1], over: years)])
            .defining("y", as: "x + 1")

        let driver = PeriodDriver(
            definition: model,
            rollforwards: [Rollforward(opening: "opening", closing: "nowhere", seed: 0)]
        )

        #expect(throws: (any Error).self) {
            _ = try driver.run(over: Array(years.prefix(1)))
        }
    }

    @Test("An empty timeline is refused rather than returning nothing")
    func emptyTimelineIsRefused() {
        let model = ModelDefinition<Double>().defining("y", as: "1 + 1")
        let driver = PeriodDriver(definition: model, rollforwards: [])

        #expect(throws: PeriodDriverError.emptyTimeline) {
            _ = try driver.run(over: [])
        }
    }

    @Test("A failure names the period it happened in")
    func failureNamesItsPeriod() {
        let model = ModelDefinition<Double>().defining("y", as: "missingAccount + 1")
        let driver = PeriodDriver(definition: model, rollforwards: [])

        do {
            _ = try driver.run(over: Array(years.prefix(1)))
            Issue.record("Expected a throw")
        } catch let error as PeriodDriverError {
            guard case .periodFailure(let period, _) = error else {
                Issue.record("Expected a period failure, got \(error)")
                return
            }
            #expect(period == years[0])
        } catch {
            Issue.record("Expected a PeriodDriverError, got \(error)")
        }
    }

    // MARK: - Without rollforwards

    @Test("A model with no rollforwards still runs period by period")
    func noRollforwardsStillRuns() throws {
        let model = ModelDefinition<Double>(
            inputs: ["revenue": series([100, 200], over: years)]
        )
        .defining("margin", as: "revenue * 0.4")

        let driver = PeriodDriver(definition: model, rollforwards: [])
        let results = try driver.run(over: Array(years.prefix(2)))
        #expect(results["margin"]?.valuesArray == [40, 80])
    }
}
