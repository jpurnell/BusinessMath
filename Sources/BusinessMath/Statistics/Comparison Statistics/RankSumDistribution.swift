//
//  RankSumDistribution.swift
//  BusinessMath
//
//  The exact null distribution of one item's rank sum across a panel of judges, with ties.
//

import Foundation
import Numerics

// MARK: - Distribution

/// The exact null distribution of one item's rank sum across a panel of judges, ties included.
///
/// When `m` judges each rank the same `n` items, the rank sum of an item is the total of the
/// ranks it received. Under the null hypothesis that the judges have no shared preference,
/// each judge's ranking is a uniformly random arrangement of that judge's own ranks. An item's
/// rank from judge `j` is then uniform over judge `j`'s ranks, independently across judges,
/// and its rank sum is the sum of `m` independent discrete uniforms. This type holds that
/// distribution exactly, computed by convolving the `m` uniforms.
///
/// Every item has the same null distribution, so there is one per panel, not one per item.
///
/// ## Ties
///
/// Tied items carry the **average** of the places they span: a judge who places four wines
/// 1, 2, 2, 4 ranks them 1, 2.5, 2.5, 4. Each judge's own multiset of ranks enters the
/// convolution, so a judge with ties contributes a narrower uniform than one without, and a
/// judge who ties everything contributes the constant `(n + 1)/2`. Averaged ranks are
/// multiples of ½, so the distribution is stored over **doubled** sums `2S`, where every
/// value is an integer.
///
/// ## Exact counts
///
/// The distribution is computed as **exact integer counts** of the `n^m` equally likely
/// outcomes, in multi-limb arithmetic (`n^m` overflows every fixed-width integer type within
/// a dozen judges). ``doubledSumProbabilities`` and the tail probabilities are those counts
/// divided by `n^m` and rounded once to `T`, so each is accurate to a few ulps, including
/// tails far below `1e-300`. Critical values are decided on the counts themselves, never on
/// rounded probabilities; see ``RankSumCriticalValues``.
///
/// ## Moments
///
/// The mean is always `m(n + 1)/2`. The variance is
///
/// ```
/// Var(S) = Σⱼ [ (n² − 1)/12 − Σ(t³ − t)/(12n) ]
/// ```
///
/// where `t` runs over the sizes of judge `j`'s groups of tied ranks. Without ties this is the
/// classic `m(n² − 1)/12`.
///
/// ## Usage
///
/// ```swift
/// // Three judges, four wines; the second judge tied wines 2 and 3.
/// let ranks: [[Double]] = [
///     [1, 2,   3,   4],
///     [1, 2.5, 2.5, 4],
///     [2, 1,   4,   3],
/// ]
/// let distribution = try rankSumDistribution(judgeRanks: ranks)
/// distribution.mean                    // 7.5
/// distribution.probability(atMost: 4)  // 3/64 = 0.046875
/// ```
///
/// - SeeAlso: ``rankSumDistribution(judgeRanks:)``
public struct RankSumDistribution<T: Real>: Sendable where T: Sendable {
    /// The number of judges, `m`.
    public let judges: Int
    /// The number of items each judge ranked, `n`.
    public let items: Int
    /// The smallest attainable doubled sum, `2 × min S`.
    public let minimumDoubledSum: Int
    /// The probability of each doubled sum from ``minimumDoubledSum`` upward in steps of one:
    /// element `k` is `P(2S = minimumDoubledSum + k)`.
    ///
    /// Without ties every rank sum is a whole number, so the odd doubled sums have
    /// probability zero. An element can also be zero where a tie pattern skips a half-step.
    public let doubledSumProbabilities: [T]
    /// The mean rank sum, `m(n + 1)/2`.
    public let mean: T
    /// The variance of the rank sum, tie-corrected; see **Moments** above.
    public let variance: T
    /// The exact outcome counts behind ``doubledSumProbabilities``.
    internal let exactCounts: RankSumExactCounts

    /// The largest attainable doubled sum, `2 × max S`.
    public var maximumDoubledSum: Int { minimumDoubledSum + doubledSumProbabilities.count - 1 }

    /// The smallest attainable rank sum.
    public var minimumSum: T { T(minimumDoubledSum) / T(2) }

    /// The largest attainable rank sum.
    public var maximumSum: T { T(maximumDoubledSum) / T(2) }

    /// The standard deviation of the rank sum.
    public var standardDeviation: T { variance.squareRoot() }

    /// `true` when every item's rank sum is the same number with certainty.
    ///
    /// That happens exactly when every judge tied every item. No rank sum can then differ
    /// from any other, so no item can be significant.
    public var isDegenerate: Bool { doubledSumProbabilities.count == 1 }

    /// The probability of a doubled sum `2S`. Zero outside the support.
    ///
    /// - Parameter doubledSum: Twice the rank sum.
    /// - Returns: `P(2S = doubledSum)`.
    public func probability(doubledSum: Int) -> T {
        let offset: Int = doubledSum - minimumDoubledSum
        guard offset >= 0, offset < doubledSumProbabilities.count else { return T(0) }
        return doubledSumProbabilities[offset]
    }

    /// The probability that the rank sum equals `sum` exactly.
    ///
    /// - Parameter sum: A rank sum. A value that is not a multiple of ½ cannot occur and has
    ///   probability zero.
    /// - Returns: `P(S = sum)`, or `nan` for a `nan` sum.
    public func probability(ofSum sum: T) -> T {
        guard !sum.isNaN else { return T.nan }
        let doubled: T = sum * T(2)
        guard doubled.rounded() == doubled else { return T(0) }
        let count: Int = doubledSumsAtMost(doubled)
        guard count > 0 else { return T(0) }
        let candidate: T = T(minimumDoubledSum + count - 1)
        return candidate == doubled ? doubledSumProbabilities[count - 1] : T(0)
    }

    /// The lower-tail probability `P(S ≤ sum)`.
    ///
    /// Summed exactly in outcome counts and rounded once, so a small tail keeps its relative
    /// precision.
    ///
    /// - Parameter sum: Any rank sum; it need not be attainable.
    /// - Returns: `P(S ≤ sum)`, or `nan` for a `nan` sum.
    public func probability(atMost sum: T) -> T {
        guard !sum.isNaN else { return T.nan }
        let count: Int = doubledSumsAtMost(sum * T(2))
        guard count > 0 else { return T(0) }
        guard count < doubledSumProbabilities.count else { return T(1) }
        return MultiLimb.ratio(exactCounts.sum(0..<count), exactCounts.total, as: T.self)
    }

    /// The upper-tail probability `P(S ≥ sum)`.
    ///
    /// Summed exactly in outcome counts and rounded once, never computed as `1 − P(S < sum)`.
    ///
    /// - Parameter sum: Any rank sum; it need not be attainable.
    /// - Returns: `P(S ≥ sum)`, or `nan` for a `nan` sum.
    public func probability(atLeast sum: T) -> T {
        guard !sum.isNaN else { return T.nan }
        let below: Int = doubledSumsBelow(sum * T(2))
        guard below > 0 else { return T(1) }
        guard below < doubledSumProbabilities.count else { return T(0) }
        let tail: [UInt64] = exactCounts.sum(below..<doubledSumProbabilities.count)
        return MultiLimb.ratio(tail, exactCounts.total, as: T.self)
    }

    /// How many support positions have a doubled sum `≤ doubled`.
    ///
    /// A binary search on the positions themselves, so no floating-point value is ever
    /// converted to an `Int`; `Real` offers no such conversion, and a value outside `Int`'s
    /// range would trap if it did.
    private func doubledSumsAtMost(_ doubled: T) -> Int {
        var low: Int = 0
        var high: Int = doubledSumProbabilities.count
        while low < high {
            let middle: Int = (low + high) / 2
            if T(minimumDoubledSum + middle) <= doubled {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }

    /// How many support positions have a doubled sum `< doubled`.
    private func doubledSumsBelow(_ doubled: T) -> Int {
        var low: Int = 0
        var high: Int = doubledSumProbabilities.count
        while low < high {
            let middle: Int = (low + high) / 2
            if T(minimumDoubledSum + middle) < doubled {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }
}

// MARK: - Construction

/// The exact null distribution of an item's rank sum for a panel of judges, ties included.
///
/// Pass one row per judge holding that judge's ranks for all `n` items, in the same layout
/// ``concordanceAnalysis(_:)`` takes. Tied items must carry the average of the places they
/// span (1, 2.5, 2.5, 4), which is what `rankdata` in SciPy and `rank` in R produce.
///
/// The distribution is the convolution of one discrete uniform per judge over that judge's
/// doubled ranks; see ``RankSumDistribution`` for the model.
///
/// - Parameter judgeRanks: One row per judge; each row a full set of averaged ranks 1…n in
///   any order.
/// - Returns: The exact distribution of any one item's rank sum under the null hypothesis.
/// - Throws: `BusinessMathError.invalidInput` when there are no judges, fewer than two
///   items, or a row that is not a set of averaged ranks 1…n (a `nan` or infinite value, a
///   value that is not a multiple of ½, a rank out of range, or ties not given their average
///   — for example 1, 2, 2, 4 instead of 1, 2.5, 2.5, 4);
///   `BusinessMathError.mismatchedDimensions` when the rows differ in length;
///   `BusinessMathError.resourceExhausted` when the exact count table would exceed 2²⁶
///   64-bit limbs (512 MiB, held twice while it is built) — use
///   ``rankSumCriticalValues(judgeRanks:alpha:method:)`` with the normal approximation there.
///
/// - Complexity: Each judge costs one pass over the support (at most `2m(n − 1) + 1` doubled
///   sums) per **run** of its ranks — a stretch of untied places, or one tied group — times
///   the count width, `⌊m·⌈log₂(n + 1)⌉/64⌋ + 1` limbs. An untied panel is about
///   `2m²n · width` limb operations; memory is two tables of `support × width` limbs. In a
///   release build on Apple silicon, 100 judges × 50 items takes about 0.03 s untied and
///   0.1–0.5 s with ties, in 10 MB; see the <doc:2.6-RankSumSignificance> article for larger
///   panels.
public func rankSumDistribution<T: Real & Sendable>(judgeRanks: [[T]]) throws -> RankSumDistribution<T> {
    let judges: [[DoubledRankGroup]] = try doubledRankGroups(judgeRanks)
    let items: Int = judgeRanks[0].count
    let exact = try RankSumExactCounts.make(judges, items: items,
                                            limbBudget: rankSumExactLimbBudget)
    let counts: RankSumExactCounts = exact.counts
    var probabilities: [T] = []
    probabilities.reserveCapacity(counts.entries)
    for index in 0..<counts.entries {
        probabilities.append(MultiLimb.ratio(counts.count(index), counts.total, as: T.self))
    }
    let moments = rankSumMoments(judges, items: items, as: T.self)
    return RankSumDistribution(
        judges: judgeRanks.count, items: items, minimumDoubledSum: exact.minimumDoubledSum,
        doubledSumProbabilities: probabilities, mean: moments.mean, variance: moments.variance,
        exactCounts: counts)
}

/// The most 64-bit limbs the exact count table may hold: 2²⁶ limbs, 512 MiB.
///
/// The table is `(2·m·(n − 1) + 1)` sums × `⌊m·⌈log₂(n + 1)⌉ / 64⌋ + 1` limbs. See
/// ``rankSumDistribution(judgeRanks:)`` for the sizes this admits.
internal let rankSumExactLimbBudget: Int = 1 << 26

// MARK: - Validation and moments

/// One value in a judge's multiset of ranks: a doubled rank and how many items carry it.
internal struct DoubledRankGroup: Sendable, Equatable {
    let doubledRank: Int
    let count: Int
}

/// Validates a panel of averaged ranks and reduces each judge to groups of equal ranks.
///
/// The doubled rank of each group is read off its position, not converted from the value:
/// a group of `t` tied items occupying sorted positions `p … p + t − 1` (zero-based) must
/// carry the averaged rank `p + (t + 1)/2`, whose double is the integer `2p + t + 1`. Checking
/// each value against that is what proves the row is a set of averaged ranks 1…n, and it
/// yields the integer without converting a floating-point value to `Int`.
///
/// - Returns: For each judge, the groups in ascending order of rank.
internal func doubledRankGroups<T: Real>(_ judgeRanks: [[T]]) throws -> [[DoubledRankGroup]] {
    guard let first = judgeRanks.first else {
        throw BusinessMathError.invalidInput(
            message: "A rank-sum distribution needs at least one judge",
            value: "0 judges", expectedRange: "at least 1 judge")
    }
    let items: Int = first.count
    guard items >= 2 else {
        throw BusinessMathError.invalidInput(
            message: "A rank-sum distribution needs at least 2 items",
            value: "\(items)", expectedRange: "[2, ∞)")
    }

    var judges: [[DoubledRankGroup]] = []
    judges.reserveCapacity(judgeRanks.count)
    for (judge, row) in judgeRanks.enumerated() {
        guard row.count == items else {
            throw BusinessMathError.mismatchedDimensions(
                message: "Judge \(judge) ranked \(row.count) items; judge 0 ranked \(items)",
                expected: "\(items)", actual: "\(row.count)")
        }
        judges.append(try doubledRankGroups(row: row, judge: judge))
    }
    return judges
}

/// One judge's row reduced to groups of equal ranks, or a thrown error naming the problem.
private func doubledRankGroups<T: Real>(row: [T], judge: Int) throws -> [DoubledRankGroup] {
    for value in row {
        guard value.isFinite else {
            throw BusinessMathError.invalidInput(
                message: "Judge \(judge) has a rank that is nan or infinite",
                value: "\(value)", expectedRange: "averaged ranks 1…\(row.count)")
        }
        let doubled: T = value * T(2)
        guard doubled.rounded() == doubled else {
            throw BusinessMathError.invalidInput(
                message: "Judge \(judge) has a rank that is not a multiple of ½; tied items "
                    + "carry the average of the places they span",
                value: "\(value)", expectedRange: "multiples of ½ in 1…\(row.count)")
        }
    }

    let sorted: [T] = row.sorted()
    var groups: [DoubledRankGroup] = []
    var start: Int = 0
    while start < sorted.count {
        var end: Int = start + 1
        while end < sorted.count && sorted[end] == sorted[start] { end += 1 }
        let size: Int = end - start
        let doubledRank: Int = 2 * start + size + 1
        guard sorted[start] * T(2) == T(doubledRank) else {
            throw BusinessMathError.invalidInput(
                message: "Judge \(judge) does not rank 1…\(row.count) with averaged ties: "
                    + "the \(size) item(s) at sorted place \(start + 1) should carry "
                    + "\(T(doubledRank) / T(2))",
                value: "\(sorted[start])", expectedRange: "averaged ranks 1…\(row.count)")
        }
        groups.append(DoubledRankGroup(doubledRank: doubledRank, count: size))
        start = end
    }
    return groups
}

/// Mean `m(n + 1)/2` and tie-corrected variance `Σⱼ [(n² − 1)/12 − Σ(t³ − t)/(12n)]`.
///
/// Computed in `T` from the group sizes, so a panel too large for the exact convolution still
/// gets its moments without integer overflow.
internal func rankSumMoments<T: Real>(_ judges: [[DoubledRankGroup]], items: Int, as type: T.Type)
    -> (mean: T, variance: T) {
    let n: T = T(items)
    let m: T = T(judges.count)
    let mean: T = m * (n + T(1)) / T(2)
    let perJudgeUntied: T = (n * n - T(1)) / T(12)
    let tieScale: T = T(12) * n

    var variance: T = T(0)
    for groups in judges {
        var ties: T = T(0)
        for group in groups where group.count > 1 {
            let t: T = T(group.count)
            let cube: T = t * t * t
            ties += cube - t
        }
        let correction: T = ties / tieScale
        variance += perJudgeUntied - correction
    }
    return (mean, variance)
}
