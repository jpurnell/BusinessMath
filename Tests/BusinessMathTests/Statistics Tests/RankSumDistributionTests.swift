//
//  RankSumDistributionTests.swift
//  BusinessMath
//
//  The exact rank-sum distribution against brute-force enumeration, its moments against the
//  closed forms, and the input it must refuse.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// `rankSumDistribution(judgeRanks:)` against an independent code path.
///
/// ## Why brute force is a real oracle here
///
/// The implementation counts outcomes with a sliding-sum convolution over runs of each judge's
/// ranks, in multi-limb integers. The enumeration below shares nothing with it: it walks every
/// one of the `n^m` combinations of per-judge positions, adds up the doubled ranks, and counts.
/// Both sides are exact integer counts divided by `n^m`, so the comparison is between two
/// roundings of the same rational number.
///
/// A second enumeration goes one step further back and does not assume the model at all: it
/// walks every *permutation* of every judge's row and tallies the rank sum of every wine.
/// That is the null hypothesis itself, so it checks the claim the method rests on (each
/// wine's rank from a shuffled judge is uniform over that judge's multiset, independently
/// across judges) rather than only the arithmetic.
///
/// ## Tolerance
///
/// Both sides round the same rational once (the package through its 64-bit leading-limb
/// ratio, the test through `Double(count) / Double(n^m)`), so they differ by at most a couple
/// of ulps of a probability at most 1. 1e-15 is a few ulps of 1 and far below any probability
/// a missing or doubled convolution step would produce.
@Suite("Rank-sum distribution: brute force, moments, input")
struct RankSumDistributionTests {

    // MARK: - Panels

    /// Small panels with and without ties, n ≤ 5 and m ≤ 4, so `n^m` ≤ 625.
    static let panels: [[[Double]]] = [
        [[1, 2, 3]],
        [[1, 2, 3, 4], [2, 1, 4, 3]],
        [[1, 2, 3, 4], [2, 1, 4, 3], [4, 3, 2, 1]],
        [[1, 2, 3, 4, 5], [5, 4, 3, 2, 1], [2, 1, 3, 5, 4], [1, 3, 2, 4, 5]],
        [[1.5, 1.5, 3, 4], [1, 2, 3, 4]],
        [[1, 2.5, 2.5, 4, 5], [1, 2, 3, 4, 5], [2, 2, 2, 4, 5]],
        [[2, 2, 2, 4.5, 4.5], [1.5, 1.5, 3.5, 3.5, 5], [1, 2, 4, 4, 4], [3, 3, 3, 3, 3]],
        [[2.5, 2.5, 2.5, 2.5], [1, 2, 3, 4], [1.5, 1.5, 3.5, 3.5]],
        [[1.5, 1.5], [1, 2], [1.5, 1.5], [2, 1]],
    ]

    /// Every combination of per-judge positions, as integer counts over doubled sums.
    private static func enumeratedCounts(_ panel: [[Double]]) -> [Int: Int] {
        let doubled: [[Int]] = panel.map { row in row.map { Int(($0 * 2).rounded()) } }
        let n: Int = panel.first?.count ?? 0
        var counts: [Int: Int] = [:]
        // Every outcome once: outcome `code` is a base-n numeral whose digit j is judge j's
        // position. A bounded loop over a known count, not an odometer that has to find its end.
        let outcomes: Int = power(n, panel.count)
        for code in 0..<outcomes {
            var rest: Int = code
            var sum: Int = 0
            for judge in 0..<panel.count {
                sum += doubled[judge][rest % n]
                rest /= n
            }
            counts[sum, default: 0] += 1
        }
        return counts
    }

    private static func power(_ base: Int, _ exponent: Int) -> Int {
        var result: Int = 1
        for _ in 0..<exponent { result *= base }
        return result
    }

    @Test("Every probability equals count / n^m from full enumeration", arguments: RankSumDistributionTests.panels)
    func matchesEnumeration(panel: [[Double]]) throws {
        let distribution = try rankSumDistribution(judgeRanks: panel)
        let counts = Self.enumeratedCounts(panel)
        let total: Double = Double(Self.power(panel[0].count, panel.count))
        let lowest: Int = counts.keys.min() ?? -1
        let highest: Int = counts.keys.max() ?? -1
        #expect(distribution.minimumDoubledSum == lowest)
        #expect(distribution.maximumDoubledSum == highest)
        for doubledSum in (lowest - 2)...(highest + 2) {
            let expected: Double = Double(counts[doubledSum] ?? 0) / total
            let actual: Double = distribution.probability(doubledSum: doubledSum)
            let gap: Double = abs(actual - expected)
            #expect(gap < 1e-15, "2S = \(doubledSum): enumeration \(expected), this \(actual)")
        }
    }

    /// Walks every permutation of every judge's row, which is the null hypothesis itself, and
    /// tallies the rank sum of every wine. Each wine's tally must be the same distribution.
    @Test("Permuting whole rows gives every wine this distribution")
    func permutationsOfWholeRows() throws {
        let panel: [[Double]] = [[1, 2.5, 2.5, 4], [1, 2, 3, 4], [1.5, 1.5, 3, 4]]
        let distribution = try rankSumDistribution(judgeRanks: panel)
        let permutations: [[[Double]]] = panel.map(Self.allPermutations)
        let wines: Int = panel[0].count
        var tallies: [[Int: Int]] = Array(repeating: [:], count: wines)
        var draws: Int = 0
        for a in permutations[0] {
            for b in permutations[1] {
                for c in permutations[2] {
                    draws += 1
                    for wine in 0..<wines {
                        let doubledSum: Int = Int(((a[wine] + b[wine] + c[wine]) * 2).rounded())
                        tallies[wine][doubledSum, default: 0] += 1
                    }
                }
            }
        }
        #expect(draws == 24 * 24 * 24)
        for wine in 0..<wines {
            for (doubledSum, count) in tallies[wine] {
                let expected: Double = Double(count) / Double(draws)
                let gap: Double = abs(distribution.probability(doubledSum: doubledSum) - expected)
                #expect(gap < 1e-15, "wine \(wine), 2S = \(doubledSum)")
            }
            let covered: Int = tallies[wine].count
            let support: Int = distribution.doubledSumProbabilities.filter { $0 > 0 }.count
            #expect(covered == support, "wine \(wine) reaches every attainable sum")
        }
    }

    /// All orderings of a row, duplicates included, so each is equally likely.
    private static func allPermutations(_ row: [Double]) -> [[Double]] {
        guard row.count > 1 else { return [row] }
        var out: [[Double]] = []
        for index in row.indices {
            var rest: [Double] = row
            let head: Double = rest.remove(at: index)
            for tail in allPermutations(rest) { out.append([head] + tail) }
        }
        return out
    }

    // MARK: - Moments

    /// Without ties: mean m(n + 1)/2 and variance m(n² − 1)/12, the classic forms.
    @Test("Untied moments are m(n+1)/2 and m(n²−1)/12")
    func untiedMoments() throws {
        for (m, n) in [(1, 2), (3, 4), (9, 8), (16, 12), (25, 7)] {
            let row: [Double] = (1...n).map(Double.init)
            let panel: [[Double]] = Array(repeating: row, count: m)
            let distribution = try rankSumDistribution(judgeRanks: panel)
            let mean: Double = Double(m * (n + 1)) / 2
            let variance: Double = Double(m * (n * n - 1)) / 12
            #expect(abs(distribution.mean - mean) < 1e-12 * mean)
            #expect(abs(distribution.variance - variance) < 1e-12 * variance)
        }
    }

    /// With ties each judge contributes (n² − 1)/12 − Σ(t³ − t)/(12n), and the pmf's own
    /// moments must agree with the closed form the struct reports.
    @Test("Tied variance follows (n²−1)/12 − Σ(t³−t)/(12n) and matches the pmf", arguments: RankSumDistributionTests.panels)
    func tiedMoments(panel: [[Double]]) throws {
        let distribution = try rankSumDistribution(judgeRanks: panel)
        let n: Int = panel[0].count
        var formula: Double = 0
        for row in panel {
            var groups: [Double: Int] = [:]
            for rank in row { groups[rank, default: 0] += 1 }
            var ties: Double = 0
            for t in groups.values {
                let size: Double = Double(t)
                ties += size * size * size - size
            }
            formula += Double(n * n - 1) / 12 - ties / Double(12 * n)
        }
        var pmfMean: Double = 0
        var pmfSecond: Double = 0
        for (offset, p) in distribution.doubledSumProbabilities.enumerated() {
            let sum: Double = Double(distribution.minimumDoubledSum + offset) / 2
            pmfMean += p * sum
            pmfSecond += p * sum * sum
        }
        let pmfVariance: Double = pmfSecond - pmfMean * pmfMean
        let expectedMean: Double = Double(panel.count * (n + 1)) / 2
        #expect(abs(distribution.mean - expectedMean) < 1e-12)
        #expect(abs(distribution.variance - formula) < 1e-12)
        #expect(abs(pmfMean - expectedMean) < 1e-12)
        #expect(abs(pmfVariance - formula) < 1e-10)
    }

    @Test("Probabilities sum to one and an untied panel is symmetric")
    func normalisationAndSymmetry() throws {
        let row: [Double] = (1...7).map(Double.init)
        let distribution = try rankSumDistribution(judgeRanks: Array(repeating: row, count: 9))
        let total: Double = distribution.doubledSumProbabilities.reduce(0, +)
        #expect(abs(total - 1) < 1e-14)
        let low: Int = distribution.minimumDoubledSum
        let high: Int = distribution.maximumDoubledSum
        for doubledSum in low...high {
            let mirror: Int = low + high - doubledSum
            let gap: Double = abs(distribution.probability(doubledSum: doubledSum)
                                  - distribution.probability(doubledSum: mirror))
            #expect(gap < 1e-16)
        }
    }

    // MARK: - Queries in rank-sum units

    @Test("probability(ofSum:), atMost and atLeast agree with the doubled pmf")
    func sumQueries() throws {
        let panel: [[Double]] = [[1, 2.5, 2.5, 4, 5], [1, 2, 3, 4, 5], [2, 2, 2, 4, 5]]
        let distribution = try rankSumDistribution(judgeRanks: panel)
        let probabilities: [Double] = distribution.doubledSumProbabilities
        let low: Int = distribution.minimumDoubledSum
        for (offset, p) in probabilities.enumerated() {
            let sum: Double = Double(low + offset) / 2
            let below: Double = probabilities[0...offset].reduce(0, +)
            let above: Double = probabilities[offset...].reduce(0, +)
            #expect(distribution.probability(ofSum: sum) == p)
            #expect(abs(distribution.probability(atMost: sum) - below) < 1e-15)
            #expect(abs(distribution.probability(atLeast: sum) - above) < 1e-15)
            // Between attainable half-steps nothing changes.
            #expect(distribution.probability(ofSum: sum + 0.25) == 0)
            #expect(abs(distribution.probability(atMost: sum + 0.25) - below) < 1e-15)
        }
        #expect(distribution.probability(atMost: distribution.minimumSum - 0.5) == 0)
        #expect(distribution.probability(atMost: distribution.maximumSum) == 1)
        #expect(distribution.probability(atLeast: distribution.maximumSum + 0.5) == 0)
        #expect(distribution.probability(atLeast: distribution.minimumSum) == 1)
        #expect(distribution.probability(atMost: Double.nan).isNaN)
        #expect(distribution.probability(atLeast: Double.nan).isNaN)
        #expect(distribution.probability(ofSum: Double.nan).isNaN)
    }

    // MARK: - Degenerate judges and panels

    /// A judge who ties every wine gives every wine (n + 1)/2: a constant, which shifts the
    /// distribution and changes nothing else.
    @Test("A judge who ties everything shifts the distribution by (n+1)/2")
    func allTiedJudgeIsAConstant() throws {
        let others: [[Double]] = [[1, 2, 3, 4], [2, 1, 4, 3], [1, 2.5, 2.5, 4]]
        let base = try rankSumDistribution(judgeRanks: others)
        let shifted = try rankSumDistribution(judgeRanks: others + [[2.5, 2.5, 2.5, 2.5]])
        #expect(shifted.minimumDoubledSum == base.minimumDoubledSum + 5)
        #expect(shifted.doubledSumProbabilities == base.doubledSumProbabilities)
        #expect(abs(shifted.variance - base.variance) < 1e-15)
        #expect(abs(shifted.mean - base.mean - 2.5) < 1e-15)
    }

    /// Every judge ties every wine: every wine's sum is m(n + 1)/2 with certainty.
    @Test("A panel that ties everything is a point mass")
    func allTiedPanelIsAPoint() throws {
        let panel: [[Double]] = Array(repeating: [2, 2, 2], count: 4)
        let distribution = try rankSumDistribution(judgeRanks: panel)
        #expect(distribution.isDegenerate)
        #expect(distribution.doubledSumProbabilities == [1])
        #expect(distribution.minimumSum == 8)
        #expect(distribution.mean == 8)
        #expect(distribution.variance == 0)
    }

    @Test("A panel with any spread is not degenerate")
    func spreadIsNotDegenerate() throws {
        let panel: [[Double]] = [[2, 2, 2], [1, 2, 3]]
        let distribution = try rankSumDistribution(judgeRanks: panel)
        #expect(!distribution.isDegenerate)
    }

    // MARK: - Input that is refused

    static let refused: [(name: String, panel: [[Double]])] = [
        ("no judges", []),
        ("one wine", [[1], [1]]),
        ("no wines", [[], []]),
        ("ragged rows", [[1, 2, 3], [1, 2]]),
        ("NaN", [[1, 2, 3], [1, Double.nan, 3]]),
        ("infinity", [[1, 2, 3], [1, 2, Double.infinity]]),
        ("not a half-integer", [[1, 2, 3], [1.2, 1.8, 3]]),
        ("competition ranking 1, 2, 2, 4", [[1, 2, 2, 4]]),
        ("ties given the lower rank", [[1, 1, 3]]),
        ("rank out of range", [[1, 2, 4]]),
        ("repeated untied rank", [[1, 1, 2, 4]]),
        ("zero-based ranks", [[0, 1, 2]]),
    ]

    @Test("Input that is not a panel of averaged ranks is refused")
    func refusesInvalidInput() {
        for (name, panel) in Self.refused {
            #expect(throws: BusinessMathError.self, "\(name)") {
                _ = try rankSumDistribution(judgeRanks: panel)
            }
        }
    }

    @Test("Rows in any order are accepted; only the multiset matters")
    func rowOrderDoesNotMatter() throws {
        let a = try rankSumDistribution(judgeRanks: [[4, 1, 2.5, 2.5], [3, 1, 2, 4]])
        let b = try rankSumDistribution(judgeRanks: [[1, 2.5, 2.5, 4], [1, 2, 3, 4]])
        #expect(a.doubledSumProbabilities == b.doubledSumProbabilities)
        #expect(a.minimumDoubledSum == b.minimumDoubledSum)
    }

    @Test("Works for Float as well as Double")
    func floatPrecision() throws {
        let panel: [[Float]] = [[1, 2.5, 2.5, 4], [1, 2, 3, 4]]
        let distribution = try rankSumDistribution(judgeRanks: panel)
        let total: Float = distribution.doubledSumProbabilities.reduce(0, +)
        #expect(abs(total - 1) < 1e-6)
        #expect(distribution.minimumDoubledSum == 4)
    }

    // MARK: - Size

    /// 3000 judges × 100 wines needs 594 001 sums × 329 limbs, past the 2²⁶-limb budget. It is
    /// refused before anything that size is allocated, and the normal approximation, which
    /// never builds the table, still answers.
    @Test("A panel too large to count is refused up front; the approximation still answers")
    func tooLargeToCount() throws {
        let row: [Double] = (1...100).map(Double.init)
        let panel: [[Double]] = Array(repeating: row, count: 3000)
        #expect(throws: BusinessMathError.self) {
            _ = try rankSumDistribution(judgeRanks: panel)
        }
        let normal = try rankSumCriticalValues(judgeRanks: panel, alpha: 0.05, method: .normalApproximation)
        let mean: Double = 3000.0 * 101.0 / 2.0
        let sigma: Double = (3000.0 * 9999.0 / 12.0).squareRoot()
        let expected: Double = mean - 1.959963984540054 * sigma
        let lower: Double = try #require(normal.lower)
        #expect(abs(lower - expected) < 1e-9 * expected)
    }

    /// 100 judges × 50 wines with ties: the size the method is meant to stay fast for. This
    /// checks the result is a distribution; the timing is reported in the session summary.
    @Test("A 100 x 50 tied panel is a proper distribution")
    func largePanel() throws {
        var panel: [[Double]] = []
        for judge in 0..<100 {
            var row: [Double] = (1...50).map(Double.init)
            if judge % 3 == 0 {
                // A tied pair at places 1 and 2, and a three-way tie at 10, 11, 12.
                row[0] = 1.5; row[1] = 1.5
                row[9] = 11; row[10] = 11; row[11] = 11
            }
            panel.append(row)
        }
        let distribution = try rankSumDistribution(judgeRanks: panel)
        let total: Double = distribution.doubledSumProbabilities.reduce(0, +)
        #expect(abs(total - 1) < 1e-12)
        #expect(distribution.minimumDoubledSum == 2 * 100 + 34)
        #expect(abs(distribution.mean - 2550) < 1e-9)
        let untied: Double = 100.0 * (2500.0 - 1.0) / 12.0
        let ties: Double = 34.0 * (6.0 + 24.0) / (12.0 * 50.0)
        #expect(abs(distribution.variance - (untied - ties)) < 1e-9)
    }
}
