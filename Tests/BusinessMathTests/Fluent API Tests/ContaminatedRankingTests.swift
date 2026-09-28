//
//  ContaminatedRankingTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Fluent API/` and `Financial Statements/`.
//
//  `InvestmentPortfolio` ranks capital projects with a single comparison:
//
//      investments.sorted { $0.npv > $1.npv }
//
//  `Investment.npv` delegates to `BusinessMath.npv`, which correctly returns `nan` for a
//  contaminated cash flow. `>` is then false in both directions for that key, so the predicate
//  is not a strict weak ordering and `sorted(by:)` is unspecified.
//
//  The damage is not the contaminated project. It is that the **clean** projects come back in
//  the wrong order, with no symptom: `rankedByNPV()` is a capital-allocation ranking, a caller
//  funds the top N, and a lower-NPV project can be funded ahead of a higher one. Same for
//  `rankedByPI()` and `rankedByIRR()`.
//
//  `ConsolidatedStatements.median(for:)` has the same shape over peer entities — its DocC says
//  "useful for peer benchmarking and identifying outliers", which is a ranking — and its own
//  `ranked(by:)` four hundred lines earlier is written the correct way, with two comparisons
//  and an id tie-break, under a comment explaining exactly why.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Capital rankings containing an unevaluable project")
struct ContaminatedRankingTests {

    /// Builds a project whose NPV is a known clean number, or `nan` when contaminated.
    private func project(name: String, inflow: Double, contaminated: Bool = false) -> Investment {
        Investment {
            InitialInvestment(100_000)
            CashFlowCategory("Operating") {
                CashFlow(period: 1, amount: contaminated ? Double.nan : inflow)
                CashFlow(period: 2, amount: inflow)
            }
            DiscountRate(0.10)
            Name(name)
        }
    }

    private var portfolio: InvestmentPortfolio {
        InvestmentPortfolio(investments: [
            project(name: "low", inflow: 55_000),
            project(name: "bad", inflow: 70_000, contaminated: true),
            project(name: "high", inflow: 90_000),
            project(name: "mid", inflow: 70_000),
        ])
    }

    /// The clean projects must keep their order regardless of the unevaluable one.
    @Test("RankedByNPV_KeepsTheCleanProjectsInOrder")
    func rankedByNPVKeepsTheCleanProjectsInOrder() {
        let ranked = portfolio.rankedByNPV().compactMap(\.name).filter { $0 != "bad" }
        #expect(ranked == ["high", "mid", "low"], "got \(ranked)")
    }

    @Test("RankedByPI_KeepsTheCleanProjectsInOrder")
    func rankedByPIKeepsTheCleanProjectsInOrder() {
        let ranked = portfolio.rankedByPI().compactMap(\.name).filter { $0 != "bad" }
        #expect(ranked == ["high", "mid", "low"], "got \(ranked)")
    }

    /// The fixture has to actually contain an unevaluable project, or this proves nothing.
    @Test("Fixture_ContainsAnUnevaluableProject")
    func fixtureContainsAnUnevaluableProject() {
        let bad = portfolio.investments.first { $0.name == "bad" }
        let npv = try? #require(bad).npv
        #expect(npv?.isNaN == true, "got \(String(describing: npv))")
        let clean = portfolio.investments.first { $0.name == "high" }
        #expect(clean?.npv.isFinite == true)
    }

    /// Control: a portfolio of clean projects ranks exactly as before.
    @Test("CleanPortfolio_RanksUnchanged")
    func cleanPortfolioRanksUnchanged() {
        let clean = InvestmentPortfolio(investments: [
            project(name: "low", inflow: 55_000),
            project(name: "high", inflow: 90_000),
            project(name: "mid", inflow: 70_000),
        ])
        #expect(clean.rankedByNPV().compactMap(\.name) == ["high", "mid", "low"])
        #expect(clean.rankedByPI().compactMap(\.name) == ["high", "mid", "low"])
    }
}
