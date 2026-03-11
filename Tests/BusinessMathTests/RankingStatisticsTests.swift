//
//  RankingStatisticsTests.swift
//  BusinessMath
//
//  TDD Test Suite for Ranking Statistics Functions
//  Migrated from WineTaster 4 for upstream implementation
//
//  Functions to implement:
//  - rank() / reverseRank() - Ranking with tie handling
//  - tauAdjustment() - Tie correction for Kendall's Tau
//  - kendallW() - Kendall's W coefficient of concordance
//  - friedmanChiSquare() - Friedman's Chi-Square test statistic
//  - fStatistic() - F-statistic derived from Kendall's W
//  - dValue() - Sum of squared deviations from center rank
//  - nemenyiCD() - Nemenyi Critical Distance for post-hoc testing
//

import Testing
import Foundation
@testable import BusinessMath

// MARK: - Helper Functions

/// Floating-point comparison helper per TDD guidelines
func approxEqual(
    _ a: Double,
    _ b: Double,
    tolerance: Double = 1e-6
) -> Bool {
    abs(a - b) <= tolerance
}

func approxEqual(
    _ a: Float,
    _ b: Float,
    tolerance: Float = 1e-5
) -> Bool {
    abs(a - b) <= tolerance
}

// MARK: - Ranking Functions Tests

@Suite("Ranking Functions")
struct RankingFunctionsTests {

    // MARK: - rank() Golden Path Tests

    @Test("rank() - Simple descending values")
    func rankSimpleDescending() {
        let values: [Double] = [100, 80, 60, 40, 20]
        let expected: [Double] = [1, 2, 3, 4, 5]
        let result = values.rank()

        for (index, rank) in result.enumerated() {
            #expect(approxEqual(rank, expected[index]))
        }
    }

    @Test("rank() - Unsorted values")
    func rankUnsortedValues() {
        let values: [Double] = [60, 100, 20, 80, 40]
        let expected: [Double] = [3, 1, 5, 2, 4]
        let result = values.rank()

        for (index, rank) in result.enumerated() {
            #expect(approxEqual(rank, expected[index]))
        }
    }

    @Test("rank() - With ties produces averaged ranks")
    func rankWithTies() {
        // When values are tied, they should receive the average of their ranks
        // Values: [100, 80, 80, 40] - ranks would be 1, 2, 3, 4
        // But 80 appears twice at positions 2 and 3, so both get (2+3)/2 = 2.5
        let values: [Double] = [100, 80, 80, 40]
        let result = values.rank()

        #expect(approxEqual(result[0], 1.0))      // 100 is rank 1
        #expect(approxEqual(result[1], 2.5))      // 80 tied, average of 2,3
        #expect(approxEqual(result[2], 2.5))      // 80 tied, average of 2,3
        #expect(approxEqual(result[3], 4.0))      // 40 is rank 4
    }

    @Test("rank() - All values tied")
    func rankAllTied() {
        let values: [Double] = [50, 50, 50, 50, 50]
        let result = values.rank()

        // All tied at ranks 1,2,3,4,5 -> average = 3
        for rank in result {
            #expect(approxEqual(rank, 3.0))
        }
    }

    @Test("rank() - Single element")
    func rankSingleElement() {
        let values: [Double] = [42]
        let result = values.rank()

        #expect(result.count == 1)
        #expect(approxEqual(result[0], 1.0))
    }

    @Test("rank() - Two elements")
    func rankTwoElements() {
        let values: [Double] = [10, 20]
        let result = values.rank()

        #expect(approxEqual(result[0], 2.0))  // 10 is lower, rank 2
        #expect(approxEqual(result[1], 1.0))  // 20 is higher, rank 1
    }

    @Test("rank() - Float type works correctly")
    func rankFloatType() {
        let values: [Float] = [100, 80, 60, 40, 20]
        let expected: [Float] = [1, 2, 3, 4, 5]
        let result = values.rank()

        for (index, rank) in result.enumerated() {
            #expect(approxEqual(rank, expected[index]))
        }
    }

    // MARK: - reverseRank() Golden Path Tests

    @Test("reverseRank() - Simple ascending values")
    func reverseRankSimpleAscending() {
        let values: [Double] = [20, 40, 60, 80, 100]
        let expected: [Double] = [1, 2, 3, 4, 5]
        let result = values.reverseRank()

        for (index, rank) in result.enumerated() {
            #expect(approxEqual(rank, expected[index]))
        }
    }

    @Test("reverseRank() - Unsorted values")
    func reverseRankUnsortedValues() {
        let values: [Double] = [60, 100, 20, 80, 40]
        let expected: [Double] = [3, 5, 1, 4, 2]
        let result = values.reverseRank()

        for (index, rank) in result.enumerated() {
            #expect(approxEqual(rank, expected[index]))
        }
    }

    @Test("reverseRank() - With ties produces averaged ranks")
    func reverseRankWithTies() {
        let values: [Double] = [40, 80, 80, 100]
        let result = values.reverseRank()

        #expect(approxEqual(result[0], 1.0))      // 40 is lowest, rank 1
        #expect(approxEqual(result[1], 2.5))      // 80 tied, average of 2,3
        #expect(approxEqual(result[2], 2.5))      // 80 tied, average of 2,3
        #expect(approxEqual(result[3], 4.0))      // 100 is highest, rank 4
    }

    // MARK: - tauAdjustment() Tests

    @Test("tauAdjustment() - No ties returns zero")
    func tauAdjustmentNoTies() {
        let values: [Double] = [100, 80, 60, 40, 20]
        let result = values.tauAdjustment()

        // No ties means no adjustment needed
        #expect(approxEqual(result, 0.0))
    }

    @Test("tauAdjustment() - With ties returns correction factor")
    func tauAdjustmentWithTies() {
        // When there's a tie of t items, adjustment is (t³ - t) / 12
        // Two items tied: (2³ - 2) / 12 = (8 - 2) / 12 = 0.5
        let values: [Double] = [100, 80, 80, 40]
        let result = values.tauAdjustment()

        #expect(approxEqual(result, 0.5))
    }

    @Test("tauAdjustment() - Multiple tie groups")
    func tauAdjustmentMultipleTieGroups() {
        // Values: [100, 80, 80, 40, 40]
        // Two groups of 2 ties each: 2 * (2³ - 2) / 12 = 2 * 0.5 = 1.0
        let values: [Double] = [100, 80, 80, 40, 40]
        let result = values.tauAdjustment()

        #expect(approxEqual(result, 1.0))
    }

    @Test("tauAdjustment() - Three-way tie")
    func tauAdjustmentThreeWayTie() {
        // Three items tied: (3³ - 3) / 12 = (27 - 3) / 12 = 2.0
        let values: [Double] = [100, 50, 50, 50, 20]
        let result = values.tauAdjustment()

        #expect(approxEqual(result, 2.0))
    }

    @Test("tauAdjustment() - All tied")
    func tauAdjustmentAllTied() {
        // Five items tied: (5³ - 5) / 12 = (125 - 5) / 12 = 10.0
        let values: [Double] = [50, 50, 50, 50, 50]
        let result = values.tauAdjustment()

        #expect(approxEqual(result, 10.0))
    }

    // MARK: - Edge Cases

    @Test("rank() - Empty array")
    func rankEmptyArray() {
        let values: [Double] = []
        let result = values.rank()

        #expect(result.isEmpty)
    }

    @Test("reverseRank() - Empty array")
    func reverseRankEmptyArray() {
        let values: [Double] = []
        let result = values.reverseRank()

        #expect(result.isEmpty)
    }

    @Test("tauAdjustment() - Empty array")
    func tauAdjustmentEmptyArray() {
        let values: [Double] = []
        let result = values.tauAdjustment()

        #expect(approxEqual(result, 0.0))
    }

    @Test("rank() - Negative values")
    func rankNegativeValues() {
        let values: [Double] = [-10, -20, -5, -30]
        let result = values.rank()

        // Magnitude-based ranking: |-30|=30, |-20|=20, |-10|=10, |-5|=5
        // Ranks by magnitude descending: -30 is rank 1, -20 is rank 2, -10 is rank 3, -5 is rank 4
        #expect(approxEqual(result[0], 3.0))  // -10
        #expect(approxEqual(result[1], 2.0))  // -20
        #expect(approxEqual(result[2], 4.0))  // -5
        #expect(approxEqual(result[3], 1.0))  // -30
    }

    @Test("rank() - Very small differences")
    func rankVerySmallDifferences() {
        let values: [Double] = [1.0000001, 1.0000002, 1.0000003]
        let result = values.rank()

        #expect(approxEqual(result[0], 3.0))
        #expect(approxEqual(result[1], 2.0))
        #expect(approxEqual(result[2], 1.0))
    }

    // MARK: - Property-Based Tests

    @Test("rank() - Sum of ranks equals n(n+1)/2")
    func rankSumProperty() {
        let values: [Double] = [100, 80, 60, 40, 20, 10, 5]
        let result = values.rank()

        let n = Double(values.count)
        let expectedSum = n * (n + 1) / 2
        let actualSum = result.reduce(0, +)

        #expect(approxEqual(actualSum, expectedSum))
    }

    @Test("rank() - Preserves count")
    func rankPreservesCount() {
        let values: [Double] = [100, 80, 60, 40, 20]
        let result = values.rank()

        #expect(result.count == values.count)
    }

    @Test("rank() vs reverseRank() - Ranks sum to n+1")
    func rankAndReverseRankSumProperty() {
        let values: [Double] = [100, 80, 60, 40, 20]
        let ranks = values.rank()
        let reverseRanks = values.reverseRank()
        let n = Double(values.count)

        for i in 0..<values.count {
            #expect(approxEqual(ranks[i] + reverseRanks[i], n + 1))
        }
    }

    // MARK: - Stress Tests

    @Test("rank() - Large array performance", .timeLimit(.minutes(1)))
    func rankLargeArray() {
        let values = (1...10000).map { Double($0) }.shuffled()
        let result = values.rank()

        #expect(result.count == 10000)

        // Verify sum property
        let expectedSum = Double(10000 * 10001 / 2)
        let actualSum = result.reduce(0, +)
        #expect(approxEqual(actualSum, expectedSum, tolerance: 0.01))
    }
}

// MARK: - Kendall's W Coefficient Tests

@Suite("Kendall's W Coefficient of Concordance")
struct KendallWTests {

    // MARK: - Golden Path Tests

    @Test("kendallW() - Perfect agreement returns 1.0")
    func kendallWPerfectAgreement() {
        // When all judges rank items identically, W = 1.0
        // 3 judges, 4 items, all ranking: A=1, B=2, C=3, D=4
        // Rows = judges, Columns = items
        let rankings: [[Double]] = [
            [1, 2, 3, 4],  // Judge 0
            [1, 2, 3, 4],  // Judge 1
            [1, 2, 3, 4],  // Judge 2
        ]
        // Rank sums: A=3, B=6, C=9, D=12

        let result = kendallW(rankings)

        #expect(approxEqual(result, 1.0, tolerance: 1e-6))
    }

    @Test("kendallW() - Complete disagreement approaches 0")
    func kendallWCompleteDisagreement() {
        // When judges completely disagree, W approaches 0
        // 3 judges ranking 3 items with maximum disagreement
        let rankings: [[Double]] = [
            [1, 2, 3],  // Judge 0: A=1, B=2, C=3
            [2, 3, 1],  // Judge 1: A=2, B=3, C=1
            [3, 1, 2],  // Judge 2: A=3, B=1, C=2
        ]
        // Rank sums: A=6, B=6, C=6 (equal sums = no agreement)

        let result = kendallW(rankings)

        #expect(approxEqual(result, 0.0, tolerance: 1e-6))
    }

    @Test("kendallW() - Moderate agreement known value")
    func kendallWModerateAgreement() {
        // 4 judges ranking 5 items
        // Construct rankings that produce rank sums: [8, 12, 10, 16, 14]
        let rankings: [[Double]] = [
            [1, 3, 2, 5, 4],  // Judge 0
            [2, 3, 3, 4, 3],  // Judge 1
            [2, 3, 2, 4, 4],  // Judge 2
            [3, 3, 3, 3, 3],  // Judge 3
        ]
        // Rank sums: [8, 12, 10, 16, 14]
        // Mean rank sum = 60/5 = 12
        // S = (8-12)² + (12-12)² + (10-12)² + (16-12)² + (14-12)² = 40
        // W = 12 * 40 / (16 * 120) = 0.25

        let result = kendallW(rankings)

        #expect(approxEqual(result, 0.25, tolerance: 1e-6))
    }

    @Test("kendallW() - Float type works correctly")
    func kendallWFloatType() {
        let rankings: [[Float]] = [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
        ]

        let result = kendallW(rankings)

        #expect(approxEqual(result, 1.0, tolerance: 1e-5))
    }

    // MARK: - Edge Cases

    @Test("kendallW() - Two items only")
    func kendallWTwoItems() {
        // 3 judges, 2 items, perfect agreement
        let rankings: [[Double]] = [
            [1, 2],
            [1, 2],
            [1, 2],
        ]

        let result = kendallW(rankings)

        #expect(approxEqual(result, 1.0, tolerance: 1e-6))
    }

    @Test("kendallW() - Two judges only")
    func kendallWTwoJudges() {
        // 2 judges agreeing on 4 items
        let rankings: [[Double]] = [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
        ]

        let result = kendallW(rankings)

        #expect(approxEqual(result, 1.0, tolerance: 1e-6))
    }

    @Test("kendallW() - Single item returns 0 or NaN")
    func kendallWSingleItem() {
        // 5 judges, 1 item - no variance possible
        let rankings: [[Double]] = [
            [1],
            [1],
            [1],
            [1],
            [1],
        ]

        let result = kendallW(rankings)

        // With single item, variance is 0, W is undefined/0
        #expect(result.isNaN || approxEqual(result, 0.0, tolerance: 1e-6))
    }

    @Test("kendallW() - Empty array returns NaN")
    func kendallWEmptyArray() {
        let rankings: [[Double]] = []

        let result = kendallW(rankings)

        #expect(result.isNaN)
    }

    @Test("kendallW() - Single judge returns NaN")
    func kendallWSingleJudge() {
        let rankings: [[Double]] = [
            [1, 2, 3, 4],
        ]

        let result = kendallW(rankings)

        // Single judge means no inter-rater agreement to measure
        #expect(result.isNaN || approxEqual(result, 1.0, tolerance: 1e-6))
    }

    // MARK: - Property-Based Tests

    @Test("kendallW() - Range is [0, 1]")
    func kendallWRangeProperty() {
        let testCases: [[[Double]]] = [
            // Perfect agreement
            [[1, 2, 3, 4], [1, 2, 3, 4], [1, 2, 3, 4]],
            // No agreement
            [[1, 2, 3], [2, 3, 1], [3, 1, 2]],
            // Partial agreement
            [[1, 2, 3, 4], [1, 3, 2, 4], [2, 1, 3, 4]],
        ]

        for rankings in testCases {
            let result = kendallW(rankings)
            #expect(result >= 0.0 && result <= 1.0,
                   "W=\(result) should be in [0,1]")
        }
    }

    @Test("kendallW() - Permuting columns preserves W")
    func kendallWColumnPermutationProperty() {
        // Reordering items (columns) should not change W
        let rankings1: [[Double]] = [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [2, 1, 3, 4],
        ]
        let rankings2: [[Double]] = [
            [4, 3, 2, 1],  // Columns reversed
            [4, 3, 2, 1],
            [4, 3, 1, 2],
        ]

        let result1 = kendallW(rankings1)
        let result2 = kendallW(rankings2)

        #expect(approxEqual(result1, result2, tolerance: 1e-6))
    }

    @Test("kendallW() - Permuting rows preserves W")
    func kendallWRowPermutationProperty() {
        // Reordering judges (rows) should not change W
        let rankings1: [[Double]] = [
            [1, 2, 3, 4],
            [1, 3, 2, 4],
            [2, 1, 3, 4],
        ]
        let rankings2: [[Double]] = [
            [2, 1, 3, 4],  // Rows reordered
            [1, 2, 3, 4],
            [1, 3, 2, 4],
        ]

        let result1 = kendallW(rankings1)
        let result2 = kendallW(rankings2)

        #expect(approxEqual(result1, result2, tolerance: 1e-6))
    }

    // MARK: - Numerical Stability

    @Test("kendallW() - Large rankings")
    func kendallWLargeRankings() {
        // 100 judges ranking 10 items with perfect agreement
        var rankings: [[Double]] = []
        for _ in 0..<100 {
            rankings.append([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        }

        let result = kendallW(rankings)

        #expect(approxEqual(result, 1.0, tolerance: 1e-6))
        #expect(!result.isNaN && !result.isInfinite)
    }

    @Test("kendallW() - Rankings with fractional values from ties")
    func kendallWFractionalRanks() {
        // When original data had ties, ranks may be fractional
        let rankings: [[Double]] = [
            [1.0, 2.5, 2.5, 4.0],  // Items 2 and 3 tied
            [1.0, 2.5, 2.5, 4.0],
            [1.0, 2.5, 2.5, 4.0],
        ]

        let result = kendallW(rankings)

        #expect(!result.isNaN && !result.isInfinite)
        #expect(result >= 0.0 && result <= 1.0)
    }
}

// MARK: - Friedman Chi-Square Tests

@Suite("Friedman Chi-Square Test")
struct FriedmanChiSquareTests {

    // MARK: - Golden Path Tests

    @Test("friedmanChiSquare() - Known textbook value")
    func friedmanChiSquareTextbook() {
        // Classic example: 3 treatments, 4 blocks (judges)
        // Formula: χ² = (12 / (n*k*(k+1))) * Σ(Ri²) - 3n(k+1)
        // Rankings that produce rank sums: [7, 9, 8]
        let rankings: [[Double]] = [
            [1, 3, 2],  // Judge 0
            [2, 3, 1],  // Judge 1
            [2, 1, 3],  // Judge 2
            [2, 2, 2],  // Judge 3
        ]
        // Rank sums: [7, 9, 8]
        // Σ(Ri²) = 49 + 81 + 64 = 194
        // χ² = (12 / (4*3*4)) * 194 - 3*4*4
        // χ² = (12/48) * 194 - 48 = 0.25 * 194 - 48 = 48.5 - 48 = 0.5

        let result = friedmanChiSquare(rankings)

        #expect(approxEqual(result, 0.5, tolerance: 1e-6))
    }

    @Test("friedmanChiSquare() - Perfect agreement gives maximum χ²")
    func friedmanChiSquarePerfectAgreement() {
        // 4 judges ranking 4 items identically
        let rankings: [[Double]] = [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
        ]
        // Rank sums: [4, 8, 12, 16]
        // χ² = 12.0

        let result = friedmanChiSquare(rankings)

        #expect(approxEqual(result, 12.0, tolerance: 1e-6))
    }

    @Test("friedmanChiSquare() - No agreement gives χ² = 0")
    func friedmanChiSquareNoAgreement() {
        // 3 judges, 3 items, maximum disagreement
        let rankings: [[Double]] = [
            [1, 2, 3],
            [2, 3, 1],
            [3, 1, 2],
        ]
        // Rank sums: [6, 6, 6] = equal = no agreement

        let result = friedmanChiSquare(rankings)

        #expect(approxEqual(result, 0.0, tolerance: 1e-6))
    }

    // MARK: - sigma() Tests (sum of squared rank sums - utility function)

    @Test("sigma() - Simple calculation")
    func sigmaSimple() {
        let rankSums: [Double] = [3, 6, 9]

        // Σ(Ri²) = 9 + 36 + 81 = 126
        let result = sigma(rankSums: rankSums)

        #expect(approxEqual(result, 126.0, tolerance: 1e-6))
    }

    @Test("sigma() - With ties")
    func sigmaWithTies() {
        let rankSums: [Double] = [5, 5, 10]

        // Σ(Ri²) = 25 + 25 + 100 = 150
        let result = sigma(rankSums: rankSums)

        #expect(approxEqual(result, 150.0, tolerance: 1e-6))
    }

    // MARK: - Edge Cases

    @Test("friedmanChiSquare() - Two items minimum")
    func friedmanChiSquareTwoItems() {
        // 3 judges, 2 items
        let rankings: [[Double]] = [
            [1, 2],
            [1, 2],
            [1, 2],
        ]

        let result = friedmanChiSquare(rankings)

        #expect(!result.isNaN && !result.isInfinite)
        #expect(result >= 0.0)
    }

    @Test("friedmanChiSquare() - Large number of items")
    func friedmanChiSquareManyItems() {
        // 5 judges, 10 items, perfect agreement
        var rankings: [[Double]] = []
        for _ in 0..<5 {
            rankings.append([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        }

        let result = friedmanChiSquare(rankings)

        #expect(!result.isNaN && !result.isInfinite)
        #expect(result > 0.0)
    }

    @Test("friedmanChiSquare() - Empty array returns NaN")
    func friedmanChiSquareEmptyArray() {
        let rankings: [[Double]] = []

        let result = friedmanChiSquare(rankings)

        #expect(result.isNaN)
    }

    // MARK: - Property-Based Tests

    @Test("friedmanChiSquare() - Non-negative")
    func friedmanChiSquareNonNegative() {
        let testCases: [[[Double]]] = [
            [[1, 2, 3], [1, 2, 3], [1, 2, 3]],           // Perfect agreement
            [[1, 2, 3], [2, 3, 1], [3, 1, 2]],           // No agreement
            [[1, 2, 3, 4], [1, 3, 2, 4], [2, 1, 3, 4]],  // Partial agreement
        ]

        for rankings in testCases {
            let result = friedmanChiSquare(rankings)
            #expect(result >= 0.0,
                   "χ² should be non-negative")
        }
    }

    @Test("friedmanChiSquare() - Relationship with Kendall's W")
    func friedmanChiSquareKendallWRelationship() {
        // χ² = n(k-1)W where n=judges, k=items
        let rankings: [[Double]] = [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
        ]
        let judges = 4
        let items = 4

        let chi2 = friedmanChiSquare(rankings)
        let w = kendallW(rankings)

        let expectedChi2 = Double(judges * (items - 1)) * w

        #expect(approxEqual(chi2, expectedChi2, tolerance: 1e-6))
    }
}

// MARK: - F-Statistic Tests

@Suite("F-Statistic from Kendall's W")
struct FStatisticTests {

    // MARK: - Golden Path Tests

    @Test("fStatistic() - Formula validation")
    func fStatisticFormula() {
        // F = (m-1) * W / (1-W)
        // Where m = number of items
        let w: Double = 0.8
        let items = 5

        // F = (5-1) * 0.8 / (1-0.8) = 4 * 0.8 / 0.2 = 3.2 / 0.2 = 16
        let result = fStatistic(kendallW: w, items: items)

        #expect(approxEqual(result, 16.0, tolerance: 1e-6))
    }

    @Test("fStatistic() - Perfect agreement (W=1)")
    func fStatisticPerfectAgreement() {
        let w: Double = 0.999999  // Approaching 1.0
        let items = 4

        // As W → 1, F → ∞
        let result = fStatistic(kendallW: w, items: items)

        #expect(result > 1000.0)  // Very large value
    }

    @Test("fStatistic() - No agreement (W=0)")
    func fStatisticNoAgreement() {
        let w: Double = 0.0
        let items = 4

        // F = (4-1) * 0 / (1-0) = 0
        let result = fStatistic(kendallW: w, items: items)

        #expect(approxEqual(result, 0.0, tolerance: 1e-6))
    }

    @Test("fStatistic() - Known values",
          arguments: [
            // (W, items, expectedF)
            (0.5, 5, 4.0),      // F = 4*0.5/0.5 = 4
            (0.25, 5, 1.333333),// F = 4*0.25/0.75 ≈ 1.333
            (0.75, 4, 9.0),     // F = 3*0.75/0.25 = 9
          ] as [(Double, Int, Double)])
    func fStatisticKnownValues(data: (Double, Int, Double)) {
        let (w, items, expectedF) = data
        let result = fStatistic(kendallW: w, items: items)

        #expect(approxEqual(result, expectedF, tolerance: 1e-4))
    }

    // MARK: - Edge Cases

    @Test("fStatistic() - W very close to 1")
    func fStatisticWNearOne() {
        let w: Double = 0.99
        let items = 4

        // F = 3 * 0.99 / 0.01 = 297
        let result = fStatistic(kendallW: w, items: items)

        #expect(approxEqual(result, 297.0, tolerance: 1e-4))
    }

    @Test("fStatistic() - W very small")
    func fStatisticWSmall() {
        let w: Double = 0.01
        let items = 4

        // F = 3 * 0.01 / 0.99 ≈ 0.0303
        let result = fStatistic(kendallW: w, items: items)

        #expect(approxEqual(result, 0.030303, tolerance: 1e-4))
    }

    @Test("fStatistic() - Two items")
    func fStatisticTwoItems() {
        let w: Double = 0.5
        let items = 2

        // F = 1 * 0.5 / 0.5 = 1
        let result = fStatistic(kendallW: w, items: items)

        #expect(approxEqual(result, 1.0, tolerance: 1e-6))
    }

    // MARK: - Property-Based Tests

    @Test("fStatistic() - Monotonic in W")
    func fStatisticMonotonicProperty() {
        let items = 5
        var previousF: Double = -1

        for w in stride(from: 0.0, through: 0.99, by: 0.1) {
            let f = fStatistic(kendallW: w, items: items)
            #expect(f > previousF, "F should increase as W increases")
            previousF = f
        }
    }

    @Test("fStatistic() - Non-negative for valid W")
    func fStatisticNonNegativeProperty() {
        for w in stride(from: 0.0, through: 0.99, by: 0.05) {
            let result = fStatistic(kendallW: w, items: 4)
            #expect(result >= 0.0, "F=\(result) should be non-negative for W=\(w)")
        }
    }
}

// MARK: - D-Value Tests

@Suite("D-Value (Sum of Squared Deviations)")
struct DValueTests {

    // MARK: - Golden Path Tests

    @Test("dValue() - Basic calculation")
    func dValueBasic() {
        // n=judges, m=items
        // center = n(m+1)/2
        // D = Σ(Ri - center)²
        // 4 judges ranking 4 items with perfect agreement
        let rankings: [[Double]] = [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
            [1, 2, 3, 4],
        ]
        // Rank sums: [4, 8, 12, 16]
        // center = 4 * (4+1) / 2 = 10
        // D = (4-10)² + (8-10)² + (12-10)² + (16-10)²
        // D = 36 + 4 + 4 + 36 = 80

        let result = dValue(rankings)

        #expect(approxEqual(result, 80.0, tolerance: 1e-6))
    }

    @Test("dValue() - No agreement (equal rank sums)")
    func dValueNoAgreement() {
        // When all rank sums equal the center, D = 0
        let rankings: [[Double]] = [
            [1, 2, 3],
            [2, 3, 1],
            [3, 1, 2],
        ]
        // Rank sums: [6, 6, 6]
        // center = 3 * 4 / 2 = 6
        // All Ri = 6, so D = 0

        let result = dValue(rankings)

        #expect(approxEqual(result, 0.0, tolerance: 1e-6))
    }

    @Test("dValue() - Perfect agreement 3x3")
    func dValuePerfectAgreement3x3() {
        let rankings: [[Double]] = [
            [1, 2, 3],
            [1, 2, 3],
            [1, 2, 3],
        ]
        // Rank sums: [3, 6, 9]
        // center = 3 * 4 / 2 = 6
        // D = (3-6)² + (6-6)² + (9-6)² = 9 + 0 + 9 = 18

        let result = dValue(rankings)

        #expect(approxEqual(result, 18.0, tolerance: 1e-6))
    }

    // MARK: - Edge Cases

    @Test("dValue() - Two items")
    func dValueTwoItems() {
        // 3 judges, 2 items, perfect agreement
        let rankings: [[Double]] = [
            [1, 2],
            [1, 2],
            [1, 2],
        ]
        // Rank sums: [3, 6]
        // center = 3 * 3 / 2 = 4.5
        // D = (3-4.5)² + (6-4.5)² = 2.25 + 2.25 = 4.5

        let result = dValue(rankings)

        #expect(approxEqual(result, 4.5, tolerance: 1e-6))
    }

    @Test("dValue() - Single item")
    func dValueSingleItem() {
        // 5 judges, 1 item
        let rankings: [[Double]] = [
            [1],
            [1],
            [1],
            [1],
            [1],
        ]
        // Rank sum: [5]
        // center = 5 * 2 / 2 = 5
        // D = (5-5)² = 0

        let result = dValue(rankings)

        #expect(approxEqual(result, 0.0, tolerance: 1e-6))
    }

    @Test("dValue() - Empty array returns 0")
    func dValueEmptyArray() {
        let rankings: [[Double]] = []

        let result = dValue(rankings)

        #expect(approxEqual(result, 0.0, tolerance: 1e-6))
    }

    // MARK: - Property-Based Tests

    @Test("dValue() - Non-negative")
    func dValueNonNegativeProperty() {
        let testCases: [[[Double]]] = [
            [[1, 2, 3], [1, 2, 3], [1, 2, 3]],
            [[1, 2, 3], [2, 3, 1], [3, 1, 2]],
            [[1, 2, 3, 4], [1, 3, 2, 4], [2, 1, 3, 4]],
        ]

        for rankings in testCases {
            let result = dValue(rankings)
            #expect(result >= 0.0, "D=\(result) should be non-negative")
        }
    }

    @Test("dValue() - Symmetric around center")
    func dValueSymmetryProperty() {
        // D should be the same if we reverse the item order
        let rankings1: [[Double]] = [
            [1, 2, 3, 4],
            [1, 2, 3, 4],
        ]
        let rankings2: [[Double]] = [
            [4, 3, 2, 1],
            [4, 3, 2, 1],
        ]

        let result1 = dValue(rankings1)
        let result2 = dValue(rankings2)

        #expect(approxEqual(result1, result2, tolerance: 1e-6))
    }
}

// MARK: - Nemenyi Critical Distance Tests

@Suite("Nemenyi Critical Distance")
struct NemenyiCDTests {

    // MARK: - Golden Path Tests

    @Test("nemenyiCD() - Formula validation at p=0.05")
    func nemenyiCDFormulaP05() {
        // CD = q_α * sqrt(k(k+1)/(6n))
        // where k = items, n = judges
        // For k=3 at α=0.05: q = 2.343
        let judges = 4
        let items = 3

        // CD = 2.343 * sqrt(3*4/(6*4)) = 2.343 * sqrt(12/24) = 2.343 * sqrt(0.5)
        // CD = 2.343 * 0.7071 ≈ 1.657
        let result = nemenyiCD(judges: judges, items: items, alpha: 0.05)
        let expected = 2.343 * sqrt(Float(items * (items + 1)) / Float(6 * judges))

        #expect(approxEqual(result, expected, tolerance: 1e-3))
    }

    @Test("nemenyiCD() - Formula validation at p=0.10")
    func nemenyiCDFormulaP10() {
        // For k=3 at α=0.10: q = 2.052
        let judges = 4
        let items = 3

        let result = nemenyiCD(judges: judges, items: items, alpha: 0.10)
        let expected = 2.052 * sqrt(Float(items * (items + 1)) / Float(6 * judges))

        #expect(approxEqual(result, expected, tolerance: 1e-3))
    }

    @Test("nemenyiCD() - Critical values table at p=0.05",
          arguments: [
            // (items, q_value at α=0.05)
            (2, Float(1.960)),
            (3, Float(2.343)),
            (4, Float(2.569)),
            (5, Float(2.728)),
            (6, Float(2.850)),
            (7, Float(2.949)),
            (8, Float(3.031)),
            (9, Float(3.102)),
            (10, Float(3.164)),
          ] as [(Int, Float)])
    func nemenyiCDCriticalValuesP05(data: (Int, Float)) {
        let (items, expectedQ) = data
        let judges = 6

        let result = nemenyiCD(judges: judges, items: items, alpha: 0.05)
        let expected = expectedQ * sqrt(Float(items * (items + 1)) / Float(6 * judges))

        #expect(approxEqual(result, expected, tolerance: 1e-3))
    }

    @Test("nemenyiCD() - Critical values table at p=0.10",
          arguments: [
            // (items, q_value at α=0.10)
            (2, Float(1.645)),
            (3, Float(2.052)),
            (4, Float(2.291)),
            (5, Float(2.459)),
            (6, Float(2.589)),
            (7, Float(2.693)),
            (8, Float(2.780)),
            (9, Float(2.855)),
            (10, Float(2.920)),
          ] as [(Int, Float)])
    func nemenyiCDCriticalValuesP10(data: (Int, Float)) {
        let (items, expectedQ) = data
        let judges = 6

        let result = nemenyiCD(judges: judges, items: items, alpha: 0.10)
        let expected = expectedQ * sqrt(Float(items * (items + 1)) / Float(6 * judges))

        #expect(approxEqual(result, expected, tolerance: 1e-3))
    }

    // MARK: - Edge Cases

    @Test("nemenyiCD() - Two items (minimum)")
    func nemenyiCDTwoItems() {
        let result = nemenyiCD(judges: 5, items: 2, alpha: 0.05)

        #expect(!result.isNaN && !result.isInfinite)
        #expect(result > 0)
    }

    @Test("nemenyiCD() - Many judges")
    func nemenyiCDManyJudges() {
        let result = nemenyiCD(judges: 100, items: 5, alpha: 0.05)

        #expect(!result.isNaN && !result.isInfinite)
        #expect(result > 0)
    }

    // MARK: - Property-Based Tests

    @Test("nemenyiCD() - CD decreases as judges increase")
    func nemenyiCDDecreasesWithJudges() {
        let items = 5
        var previousCD: Float = Float.infinity

        for judges in [2, 5, 10, 20, 50] {
            let cd = nemenyiCD(judges: judges, items: items, alpha: 0.05)
            #expect(cd < previousCD, "CD should decrease as judges increase")
            previousCD = cd
        }
    }

    @Test("nemenyiCD() - CD increases as items increase")
    func nemenyiCDIncreasesWithItems() {
        let judges = 5
        var previousCD: Float = 0

        for items in [2, 3, 4, 5, 6, 7] {
            let cd = nemenyiCD(judges: judges, items: items, alpha: 0.05)
            #expect(cd > previousCD, "CD should increase as items increase")
            previousCD = cd
        }
    }

    @Test("nemenyiCD() - p=0.05 gives larger CD than p=0.10")
    func nemenyiCDAlphaOrdering() {
        let judges = 5
        let items = 5

        let cd05 = nemenyiCD(judges: judges, items: items, alpha: 0.05)
        let cd10 = nemenyiCD(judges: judges, items: items, alpha: 0.10)

        #expect(cd05 > cd10, "CD at α=0.05 should be larger than at α=0.10")
    }

    @Test("nemenyiCD() - Positive for all valid inputs")
    func nemenyiCDPositiveProperty() {
        for judges in [2, 5, 10] {
            for items in [2, 3, 4, 5] {
                let cd = nemenyiCD(judges: judges, items: items, alpha: 0.05)
                #expect(cd > 0, "CD should be positive for judges=\(judges), items=\(items)")
            }
        }
    }
}

// MARK: - Array2D Tests

@Suite("Array2D Structure")
struct Array2DTests {

    // MARK: - Initialization Tests

    @Test("Array2D - Initialize with dimensions")
    func array2DInitialization() {
        let array = Array2D<Int>(columns: 3, rows: 4, initialValue: 0)

        #expect(array.columns == 3)
        #expect(array.rows == 4)
    }

    @Test("Array2D - All values initialized correctly")
    func array2DInitialValues() {
        let array = Array2D<Double>(columns: 3, rows: 3, initialValue: 5.0)

        for col in 0..<3 {
            for row in 0..<3 {
                #expect(approxEqual(array[col, row], 5.0))
            }
        }
    }

    // MARK: - Subscript Tests

    @Test("Array2D - Get and set values")
    func array2DGetSet() {
        var array = Array2D<Int>(columns: 3, rows: 3, initialValue: 0)

        array[0, 0] = 1
        array[1, 1] = 5
        array[2, 2] = 9

        #expect(array[0, 0] == 1)
        #expect(array[1, 1] == 5)
        #expect(array[2, 2] == 9)
        #expect(array[0, 1] == 0)  // Unchanged
    }

    @Test("Array2D - Row-major storage")
    func array2DRowMajor() {
        var array = Array2D<Int>(columns: 3, rows: 2, initialValue: 0)

        // Fill with sequential values
        var value = 1
        for row in 0..<2 {
            for col in 0..<3 {
                array[col, row] = value
                value += 1
            }
        }

        // Verify: row 0 = [1,2,3], row 1 = [4,5,6]
        #expect(array[0, 0] == 1)
        #expect(array[1, 0] == 2)
        #expect(array[2, 0] == 3)
        #expect(array[0, 1] == 4)
        #expect(array[1, 1] == 5)
        #expect(array[2, 1] == 6)
    }

    // MARK: - getRankSum Tests

    @Test("Array2D - getRankSum basic")
    func array2DGetRankSum() {
        var array = Array2D<Double>(columns: 3, rows: 3, initialValue: 0.0)

        // Set column 1 to [1, 2, 3]
        array[1, 0] = 1.0
        array[1, 1] = 2.0
        array[1, 2] = 3.0

        let sum: Double = array.getRankSum(for: 1)

        #expect(approxEqual(sum, 6.0))
    }

    // MARK: - getAvgRank Tests

    @Test("Array2D - getAvgRank basic")
    func array2DGetAvgRank() {
        var array = Array2D<Double>(columns: 3, rows: 4, initialValue: 0.0)

        // Set column 0 to [2, 4, 6, 8]
        array[0, 0] = 2.0
        array[0, 1] = 4.0
        array[0, 2] = 6.0
        array[0, 3] = 8.0

        let avg: Double = array.getAvgRank(for: 0)

        #expect(approxEqual(avg, 5.0))  // (2+4+6+8)/4 = 20/4 = 5
    }

    // MARK: - dValue Tests

    @Test("Array2D - dValue calculation")
    func array2DDValue() {
        var array = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)

        // Set up rank matrix for 3 judges, 4 wines
        // Judge 0: [1, 2, 3, 4]
        // Judge 1: [1, 2, 3, 4]
        // Judge 2: [1, 2, 3, 4]
        for row in 0..<3 {
            for col in 0..<4 {
                array[col, row] = Double(col + 1)
            }
        }

        let d: Double = array.dValue()

        // Rank sums: [3, 6, 9, 12]
        // center = 3 * 5 / 2 = 7.5
        // D = (3-7.5)² + (6-7.5)² + (9-7.5)² + (12-7.5)²
        // D = 20.25 + 2.25 + 2.25 + 20.25 = 45
        #expect(d > 0.0)
    }

    // MARK: - kendallW Tests

    @Test("Array2D - kendallW perfect agreement")
    func array2DKendallWPerfect() {
        var array = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)

        // All judges rank identically
        for row in 0..<3 {
            for col in 0..<4 {
                array[col, row] = Double(col + 1)
            }
        }

        let w: Double = array.kendallW()

        #expect(approxEqual(w, 1.0, tolerance: 1e-4))
    }

    // MARK: - fStatistic Tests

    @Test("Array2D - fStatistic from kendallW")
    func array2DFStatistic() {
        var array = Array2D<Double>(columns: 4, rows: 3, initialValue: 0.0)

        // Perfect agreement
        for row in 0..<3 {
            for col in 0..<4 {
                array[col, row] = Double(col + 1)
            }
        }

        let f: Double = array.fStatistic()

        // W ≈ 1, so F = (4-1) * 1 / (1-1) approaches infinity
        // With slight imprecision, should be very large
        #expect(f > 10.0)
    }

    // MARK: - Edge Cases

    @Test("Array2D - Single cell")
    func array2DSingleCell() {
        var array = Array2D<Int>(columns: 1, rows: 1, initialValue: 42)

        #expect(array[0, 0] == 42)

        array[0, 0] = 100
        #expect(array[0, 0] == 100)
    }

    @Test("Array2D - Single row")
    func array2DSingleRow() {
        var array = Array2D<Int>(columns: 5, rows: 1, initialValue: 0)

        for col in 0..<5 {
            array[col, 0] = col * 2
        }

        #expect(array[0, 0] == 0)
        #expect(array[2, 0] == 4)
        #expect(array[4, 0] == 8)
    }

    @Test("Array2D - Single column")
    func array2DSingleColumn() {
        var array = Array2D<Int>(columns: 1, rows: 5, initialValue: 0)

        for row in 0..<5 {
            array[0, row] = row * 3
        }

        #expect(array[0, 0] == 0)
        #expect(array[0, 2] == 6)
        #expect(array[0, 4] == 12)
    }

    // MARK: - Stress Tests

    @Test("Array2D - Large matrix performance", .timeLimit(.minutes(1)))
    func array2DLargeMatrix() {
        var array = Array2D<Double>(columns: 100, rows: 100, initialValue: 1.0)

        // Fill with values
        for row in 0..<100 {
            for col in 0..<100 {
                array[col, row] = Double(row * 100 + col)
            }
        }

        // Verify some values
        #expect(approxEqual(array[0, 0], 0.0))
        #expect(approxEqual(array[50, 50], 5050.0))
        #expect(approxEqual(array[99, 99], 9999.0))
    }
}

// MARK: - Function Stubs (To be implemented in BusinessMath)

// These function signatures define the API that needs to be implemented.
// The tests above verify the expected behavior.

/// Ranks array elements in descending order by magnitude with proper tie handling.
/// Tied values receive the average of their ranks.
/// - Returns: Array of ranks corresponding to input positions
// extension Array where Element: Real {
//     public func rank() -> [Element]
//     public func reverseRank() -> [Element]
//     public func tauAdjustment() -> Element
// }

/// Calculates Kendall's W coefficient of concordance.
/// W = 12S / (n²(k³-k)) where S = Σ(Ri - R̄)², n = judges, k = items
/// - Parameters:
///   - rankSums: Array of rank sums for each item
///   - judges: Number of judges (raters)
///   - items: Number of items being ranked
/// - Returns: W coefficient in range [0, 1]
// func kendallW<T: Real>(rankSums: [T], judges: Int, items: Int) -> T

/// Calculates Friedman's Chi-Square test statistic.
/// χ² = (12 / (nk(k+1))) * Σ(Ri²) - 3n(k+1)
/// - Parameters:
///   - rankSums: Array of rank sums for each item
///   - judges: Number of judges (blocks)
///   - items: Number of items (treatments)
/// - Returns: Chi-square statistic
// func friedmanChiSquare<T: Real>(rankSums: [T], judges: Int, items: Int) -> T

/// Calculates sum of squared rank sums (sigma).
/// σ = Σ(Ri²)
// func sigma<T: Real>(rankSums: [T]) -> T

/// Calculates F-statistic from Kendall's W.
/// F = (m-1) * W / (1-W)
/// - Parameters:
///   - kendallW: Kendall's W coefficient
///   - items: Number of items (m)
/// - Returns: F-statistic value
// func fStatistic<T: Real>(kendallW: T, items: Int) -> T

/// Calculates D-value (sum of squared deviations from center).
/// D = Σ(Ri - center)² where center = n(m+1)/2
/// - Parameters:
///   - rankSums: Array of rank sums
///   - judges: Number of judges (n)
///   - items: Number of items (m)
/// - Returns: D-value
// func dValue<T: Real>(rankSums: [T], judges: Int, items: Int) -> T

/// Calculates Nemenyi Critical Distance for post-hoc testing.
/// CD = q_α * sqrt(k(k+1)/(6n))
/// - Parameters:
///   - judges: Number of judges (n)
///   - items: Number of items (k)
///   - alpha: Significance level (0.05 or 0.10)
/// - Returns: Critical distance threshold
// func nemenyiCD(judges: Int, items: Int, alpha: Double) -> Float

/// Generic 2D array structure for matrix operations.
// public struct Array2D<T> {
//     public let columns: Int
//     public let rows: Int
//     public init(columns: Int, rows: Int, initialValue: T)
//     public subscript(column: Int, row: Int) -> T { get set }
//     func getRankSum<U: Real>(for column: Int) -> U
//     func getAvgRank<U: Real>(for column: Int) -> U
//     func dValue<U: Real>() -> U
//     func kendallW<U: Real>() -> U
//     func fStatistic<U: Real>() -> U
// }
