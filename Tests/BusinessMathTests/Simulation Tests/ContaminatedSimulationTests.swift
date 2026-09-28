//
//  ContaminatedSimulationTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Sources/BusinessMath/Simulation/` — three defects out of 81
//  candidate sites, all in the Monte Carlo result types.
//
//  `Percentiles(values:)` is the contract's canonical *correct* sibling: it throws
//  `BusinessMathError.dataQuality` when any value is non-finite. `SimulationResults.init`
//  caught that throw and rebuilt from the literal `[0]`:
//
//      do { self.percentiles = try Percentiles(values: values) }
//      catch { self.percentiles = try Percentiles(values: [0]) }
//
//  The comment above it reads "Percentiles([0]) should never fail (non-empty, finite)" — the
//  author had the *empty* case in mind, and the finiteness refusal falls into the same catch.
//
//  Measured on one contaminated run:
//
//      | statistic | clean  | contaminated |
//      | p5        | -105.0 |  0.0         |
//      | p95       |  136.0 |  0.0         |
//      | iqr       |  125.0 |  0.0         |
//      | var95     | -105.0 |  nan         |
//
//  The same object reported `nan` for value-at-risk and `0.0` for every percentile, because
//  `RiskMetrics.calculatePercentile` had already been fixed and this had not. A caller
//  thresholding `percentiles.p5 < lossLimit` reads a 5th percentile of zero and concludes the
//  run has no losses at all.
//
//  `SimulationStatistics` fails differently. `Sequence.min()` seeds with the first element and
//  replaces only on `e < result`, and every comparison against `nan` is false — so a `nan`
//  after index 0 is skipped and the finite minimum is returned, while a `nan` *at* index 0 is
//  never replaced. Position-dependent, alongside a `mean` and `stdDev` that correctly say
//  `nan`:
//
//      [nan, 1, 3] -> min nan    [1, nan, 3] -> min 1.0    [3, nan, 1] -> min 1.0
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Monte Carlo results from a contaminated run")
struct ContaminatedSimulationTests {

    private let clean: [Double] = [-120, -45, 10, 80, 150]
    private let contaminated: [Double] = [-120, -45, .nan, 80, 150]

    /// The headline: percentiles must not be fabricated from a substituted sample.
    @Test("Percentiles_FromAContaminatedRun_AreUndefined")
    func percentilesFromAContaminatedRunAreUndefined() {
        let results = SimulationResults(values: contaminated)
        #expect(results.percentiles.p5.isNaN, "got \(results.percentiles.p5)")
        #expect(results.percentiles.p95.isNaN)
        #expect(results.percentiles.p50.isNaN)
        #expect(results.percentiles.interquartileRange.isNaN)
        #expect(results.percentiles.min.isNaN)
        #expect(results.percentiles.max.isNaN)
    }

    /// The property that made it visible: one object was answering two different ways.
    @Test("PercentilesAndValueAtRisk_Agree")
    func percentilesAndValueAtRiskAgree() {
        let results = SimulationResults(values: contaminated)
        let var95 = results.valueAtRisk(confidenceLevel: 0.95)
        #expect(var95.isNaN, "value at risk was already correct")
        #expect(results.percentiles.p5.isNaN, "and the percentile set must say the same thing")
    }

    /// Extremes were position-dependent while every other statistic on the struct propagated.
    @Test("Statistics_ExtremesDoNotDependOnWhereTheNaNSits")
    func statisticsExtremesDoNotDependOnWhereTheNaNSits() {
        let first = SimulationStatistics(values: [.nan, 1.0, 3.0])
        let middle = SimulationStatistics(values: [1.0, .nan, 3.0])
        let last = SimulationStatistics(values: [3.0, .nan, 1.0])
        #expect(first.min.isNaN)
        #expect(middle.min.isNaN, "got \(middle.min)")
        #expect(last.min.isNaN, "got \(last.min)")
        #expect(middle.max.isNaN, "got \(middle.max)")
    }

    /// And must agree with the statistics beside them, which were already right.
    @Test("Statistics_ExtremesAgreeWithMean")
    func statisticsExtremesAgreeWithMean() {
        let stats = SimulationStatistics(values: [1.0, .nan, 3.0])
        #expect(stats.mean.isNaN, "mean was already correct")
        #expect(stats.stdDev.isNaN)
        #expect(stats.min.isNaN, "so the extremes must not claim a range")
    }

    /// Ranking scenarios needs a total order, or the *clean* scenarios come back shuffled.
    @Test("ScenarioRanking_IsATotalOrder")
    func scenarioRankingIsATotalOrder() {
        let comparison = ScenarioComparison(results: [
            "alpha": SimulationResults(values: [100, 110, 120, 130, 140]),
            "beta": SimulationResults(values: [200, 210, 220, 230, 240]),
            "gamma": SimulationResults(values: [50, 60, 70, 80, 90]),
            "dirty": SimulationResults(values: [-500, -300, .nan, 20, 60]),
        ])
        let ranked = comparison.rankScenarios(by: .mean, ascending: false)
        #expect(ranked.count == 4)
        let cleanOrder = ranked.map(\.name).filter { $0 != "dirty" }
        #expect(cleanOrder == ["beta", "alpha", "gamma"],
                "the clean scenarios must keep their order; got \(ranked.map(\.name))")
    }

    // MARK: - Controls

    /// A clean run is untouched, at the measured values.
    @Test("CleanRun_Unchanged")
    func cleanRunUnchanged() {
        let results = SimulationResults(values: clean)
        #expect(results.percentiles.p5.isEqual(to: -105.0))
        #expect(results.percentiles.p95.isEqual(to: 136.0))
        #expect(results.percentiles.interquartileRange.isEqual(to: 125.0))
        let stats = SimulationStatistics(values: clean)
        #expect(stats.min.isEqual(to: -120.0))
        #expect(stats.max.isEqual(to: 150.0))
    }

    /// `Percentiles` itself still refuses, so the sibling that was right stays right.
    @Test("Percentiles_StillRefusesDirectly")
    func percentilesStillRefusesDirectly() {
        let bad = contaminated
        #expect(throws: BusinessMathError.self) {
            try Percentiles(values: bad)
        }
    }
}
