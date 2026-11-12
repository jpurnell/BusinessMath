//
//  RankSumCriticalValuesTests.swift
//  BusinessMath
//
//  The behaviour of rank-sum critical values at the edges: no attainable bound, a panel that
//  ties everything, the level itself, and what `isSignificant` and the non-significant range
//  promise. Reference values are in RankSumReferenceTests.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Rank-sum critical values: edges and contract")
struct RankSumCriticalValuesTests {

    static let untied3x4: [[Double]] = [[1, 2, 3, 4], [2, 1, 3, 4], [1, 3, 2, 4]]

    // MARK: - The level

    @Test("α outside (0, 1) or nan is refused")
    func refusesInvalidAlpha() {
        for alpha in [0.0, 1.0, -0.05, 1.5, Double.nan, Double.infinity] {
            for method in [RankSumCriticalValueMethod.exact, .normalApproximation] {
                #expect(throws: BusinessMathError.self, "α = \(alpha), \(method)") {
                    _ = try rankSumCriticalValues(judgeRanks: Self.untied3x4, alpha: alpha, method: method)
                }
            }
        }
    }

    @Test("Invalid rankings are refused by both methods")
    func refusesInvalidRankings() {
        let panels: [[[Double]]] = [[], [[1]], [[1, 2, 2, 4]], [[1, 2, 3], [1, 2]]]
        for panel in panels {
            for method in [RankSumCriticalValueMethod.exact, .normalApproximation] {
                #expect(throws: BusinessMathError.self) {
                    _ = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.05, method: method)
                }
            }
        }
    }

    // MARK: - Contract

    /// `isSignificant` is exactly "≤ lower or ≥ upper", and every attainable sum is either
    /// significant or inside the non-significant range, never both.
    @Test("isSignificant and the non-significant range partition the support")
    func partition() throws {
        let panel: [[Double]] = [[1, 2.5, 2.5, 4, 5], [1, 2, 3, 4, 5], [2, 2, 2, 4, 5],
                                 [1.5, 1.5, 3, 4, 5], [1, 2, 3, 4.5, 4.5], [5, 4, 3, 2, 1]]
        let distribution = try rankSumDistribution(judgeRanks: panel)
        let values = try distribution.criticalValues(alpha: 0.05)
        let range = try #require(values.nonSignificantRange)
        let lowerBound = try #require(values.lower)
        let upperBound = try #require(values.upper)
        #expect(lowerBound < distribution.mean && distribution.mean < upperBound)
        for (offset, p) in distribution.doubledSumProbabilities.enumerated() where p > 0 {
            let sum: Double = Double(distribution.minimumDoubledSum + offset) / 2
            let significant: Bool = values.isSignificant(sum)
            #expect(significant != range.contains(sum), "sum \(sum)")
            let below: Bool = values.lower.map { sum <= $0 } ?? false
            let above: Bool = values.upper.map { sum >= $0 } ?? false
            #expect(significant == (below || above), "sum \(sum)")
        }
        #expect(!values.isSignificant(.nan))
    }

    /// Without ties every integer from m to mn is attainable, so the non-significant range is
    /// `lower + 1 … upper − 1`, and the bounds are symmetric about the mean.
    @Test("Untied: non-significant range is lower+1 … upper−1, symmetric about the mean")
    func untiedRange() throws {
        let row: [Double] = (1...8).map(Double.init)
        let values = try rankSumCriticalValues(judgeRanks: Array(repeating: row, count: 9), alpha: 0.05)
        let lower = try #require(values.lower)
        let upper = try #require(values.upper)
        let range = try #require(values.nonSignificantRange)
        #expect(range == (lower + 1)...(upper - 1))
        #expect(lower + upper == 81)
        #expect(values.mean.isEqual(to: 40.5))
    }

    /// 2 judges × 5 wines: the most extreme sum, 2, has probability 1/25 = 0.04 > 0.025, so
    /// no sum is significant at 5% two-sided. That is a property of the panel, not a failure.
    @Test("A panel too small to reach significance reports no bounds")
    func tooSmallToReachSignificance() throws {
        let panel: [[Double]] = [[1, 2, 3, 4, 5], [1, 2, 3, 4, 5]]
        let values = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.05)
        #expect(values.lower == nil)
        #expect(values.upper == nil)
        #expect(values.lowerTailProbability == nil)
        #expect(values.upperTailProbability == nil)
        #expect(!values.canReachSignificance)
        #expect(values.nonSignificantRange == 2...10)
        for sum in stride(from: 2.0, through: 10.0, by: 1.0) { #expect(!values.isSignificant(sum)) }
        // At 10% two-sided the extremes qualify (0.04 ≤ 0.05).
        let wider = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.10)
        #expect(wider.lower == 2)
        #expect(wider.upper == 10)
        #expect(wider.canReachSignificance)
    }

    /// Every judge ties every wine: every wine's sum is m(n + 1)/2 with certainty. There is
    /// nothing to test, so there are no critical values, nothing is significant, and the
    /// non-significant range is that single sum. The normal approximation agrees rather than
    /// dividing by a zero standard deviation.
    @Test("A panel that ties everything: no bounds, nothing significant, by both methods")
    func allTiedPanel() throws {
        let panel: [[Double]] = Array(repeating: [2.5, 2.5, 2.5, 2.5], count: 3)
        let exact = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.05)
        #expect(exact.isDegenerate)
        #expect(exact.lower == nil && exact.upper == nil)
        #expect(!exact.canReachSignificance)
        let point = try #require(exact.nonSignificantRange)
        #expect(point.lowerBound.isEqual(to: 7.5) && point.upperBound.isEqual(to: 7.5))
        #expect(!exact.isSignificant(7.5))
        #expect(exact.variance == 0)

        let normal = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.05, method: .normalApproximation)
        #expect(normal.isDegenerate)
        #expect(normal.lower == nil && normal.upper == nil)
        #expect(!normal.canReachSignificance)
        #expect(!normal.isSignificant(7.5))
    }

    @Test("A judge who ties everything does not make the panel degenerate")
    func oneAllTiedJudge() throws {
        let panel: [[Double]] = [[1, 2, 3, 4], [2, 1, 3, 4], [1, 2, 4, 3], [2.5, 2.5, 2.5, 2.5]]
        let values = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.10)
        #expect(!values.isDegenerate)
        // Equivalent to the three ranking judges, shifted by 2.5.
        let base = try rankSumCriticalValues(judgeRanks: Array(panel.prefix(3)), alpha: 0.10)
        #expect(values.lower == base.lower.map { $0 + 2.5 })
        #expect(values.upper == base.upper.map { $0 + 2.5 })
    }

    @Test("The distribution method and the free function agree")
    func twoEntryPoints() throws {
        let distribution = try rankSumDistribution(judgeRanks: Self.untied3x4)
        let a = try distribution.criticalValues(alpha: 0.10)
        let b = try rankSumCriticalValues(judgeRanks: Self.untied3x4, alpha: 0.10)
        #expect(a.lower == b.lower && a.upper == b.upper)
        #expect(a.lowerTailProbability == b.lowerTailProbability)
        #expect(a.judges == 3 && a.items == 4)
    }

    // MARK: - Normal approximation

    /// μ ∓ z·σ with the tie-corrected σ: continuous thresholds, no non-significant range of
    /// attainable sums, and nominal tails of exactly α/2 by construction.
    @Test("The normal approximation is μ ∓ z·σ and says it is an approximation")
    func normalShape() throws {
        let panel: [[Double]] = [[1, 2.5, 2.5, 4, 5], [1, 2, 3, 4, 5], [2, 2, 2, 4, 5]]
        let values = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.05, method: .normalApproximation)
        #expect(values.method == .normalApproximation)
        #expect(values.nonSignificantRange == nil)
        let lower = try #require(values.lower)
        let upper = try #require(values.upper)
        let center: Double = (lower + upper) / 2
        #expect(abs(center - values.mean) < 1e-12)
        let z: Double = (upper - values.mean) / values.variance.squareRoot()
        #expect(abs(z - 1.959963984540054) < 1e-12)
        #expect(values.lowerTailProbability?.isEqual(to: 0.025) == true)
        #expect(values.upperTailProbability?.isEqual(to: 0.025) == true)
        #expect(values.isSignificant(lower) && values.isSignificant(upper))
        #expect(!values.isSignificant(values.mean))
    }
}
