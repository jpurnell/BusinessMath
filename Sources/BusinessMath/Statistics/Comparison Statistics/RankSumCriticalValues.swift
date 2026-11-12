//
//  RankSumCriticalValues.swift
//  BusinessMath
//
//  Two-sided critical values ("breakpoints") for one item's rank sum, exact or approximate.
//

import Foundation
import Numerics

// MARK: - Method

/// How rank-sum critical values are computed.
public enum RankSumCriticalValueMethod: String, Sendable, CaseIterable {
    /// From the exact null distribution, ties included. See ``RankSumDistribution``.
    case exact
    /// From a normal distribution with the exact, tie-corrected mean and variance.
    ///
    /// An **approximation**. It ignores the discreteness of the rank sum, so its thresholds
    /// fall between attainable sums and its nominal tail probability of α/2 is not what any
    /// panel achieves. It is here for comparison, and for panels too large to convolve.
    case normalApproximation
}

// MARK: - Result

/// Two-sided critical values for one item's rank sum at level α.
///
/// ## The convention
///
/// For the ``RankSumCriticalValueMethod/exact`` method:
///
/// - ``lower`` is the **largest attainable** sum `L` with `P(S ≤ L) ≤ α/2`;
/// - ``upper`` is the **smallest attainable** sum `U` with `P(S ≥ U) ≤ α/2`;
/// - an item whose rank sum is `≤ L` or `≥ U` is significant at level α; see ``isSignificant(_:)``.
///
/// The bounds are themselves significant. Published tables differ on this — some print the
/// significant bounds, some the last sums that are *not* significant — so
/// ``nonSignificantRange`` gives the other reading: the attainable sums strictly between
/// `L` and `U`. Without ties every whole number is attainable and it is `L + 1 … U − 1`;
/// with ties sums move in half-steps, and its ends are the nearest attainable sums.
///
/// "Attainable" means a point of the support: without ties no rank sum is a half-integer,
/// so a bound is never placed on one. ``lowerTailProbability`` and ``upperTailProbability``
/// are the tail probabilities the bounds actually achieve, at most α/2 and usually less,
/// because a discrete distribution rarely has a sum whose tail is exactly α/2.
///
/// ## When there are no critical values
///
/// ``lower`` and ``upper`` are `nil` when no attainable sum is extreme enough. Two cases:
///
/// - **The panel is too small.** Two judges ranking five wines: the lowest possible sum, 2,
///   has probability 1/25 = 0.04, more than 0.025, so nothing can be significant at 5%
///   two-sided. ``canReachSignificance`` is `false`; that is a property of the panel.
/// - **The panel tied everything** (``isDegenerate``). Every item's sum is `m(n + 1)/2`
///   with certainty, there is no variation to test, and nothing is significant by either
///   method. ``nonSignificantRange`` is that single sum. This is reported rather than thrown
///   because "no item differs" is the true answer, and a caller showing breakpoints should
///   say there are none rather than show numbers.
///
/// With ties the distribution need not be symmetric, so one bound can exist without the
/// other.
///
/// ## Testing every item
///
/// These values test **one** item. Testing every item of a panel at level α makes it much
/// more likely than α that *some* item is flagged when no item differs: on a 24-judge,
/// 12-wine null panel with ties, about 44% of panels have at least one wine outside the 5%
/// bounds (measured by permutation; see `RankSumReferenceTests`). Nothing here adjusts for
/// that.
///
/// ## The exactness guarantee
///
/// For the exact method, every comparison of a tail with α/2 is made in **exact integer
/// arithmetic**: the tail as a count of the `n^m` equally likely outcomes, α as the exact
/// binary value of `alpha` (`M / 2^k`), so the test is `count · 2^(k+1) ≤ M · n^m` with no
/// rounding anywhere. The bounds are therefore the true critical values of the exact null
/// distribution at that `alpha`, for every panel the method accepts, however close a tail
/// lies to α/2. Only the reported probabilities are rounded, once each, to `T`.
///
/// This matters at the boundary. Two judges and twenty wines give `P(S ≤ 5) = 10/400`,
/// exactly 0.025; summed in `Double` it lands above the rounded α/2 and a float comparison
/// excludes 5, moving the lower bound to 4.
///
/// One consequence of exactness: `alpha` means the number `T` holds. `0.05` as a `Double` is
/// `0.05000000000000000277…`, so a tail lying in the 1.4 × 10⁻¹⁸ gap above 1/40 would count
/// as within α/2. A tail is a fraction with denominator `n^m`, so this can only arise when
/// `n^m` exceeds about 10¹⁷, and it is the correct answer for the level as given.
public struct RankSumCriticalValues<T: Real>: Sendable where T: Sendable {
    /// How these values were computed.
    public let method: RankSumCriticalValueMethod
    /// The two-sided significance level.
    public let alpha: T
    /// The number of judges, `m`.
    public let judges: Int
    /// The number of items, `n`.
    public let items: Int
    /// The mean rank sum, `m(n + 1)/2`.
    public let mean: T
    /// The tie-corrected variance of the rank sum.
    public let variance: T
    /// A rank sum at or below this is significantly low; `nil` when no sum is.
    ///
    /// Exact: an attainable sum. Normal approximation: `mean − z·σ`, not rounded to any sum.
    public let lower: T?
    /// A rank sum at or above this is significantly high; `nil` when no sum is.
    ///
    /// Exact: an attainable sum. Normal approximation: `mean + z·σ`, not rounded to any sum.
    public let upper: T?
    /// `P(S ≤ lower)`: exact for the exact method, the nominal α/2 for the approximation.
    public let lowerTailProbability: T?
    /// `P(S ≥ upper)`: exact for the exact method, the nominal α/2 for the approximation.
    public let upperTailProbability: T?
    /// The attainable sums that are not significant, from the first above ``lower`` to the
    /// last below ``upper``; with no bound on a side, from the extreme of the support.
    ///
    /// `nil` for the normal approximation, which has no notion of attainable sums.
    public let nonSignificantRange: ClosedRange<T>?

    /// `true` when at least one attainable sum is significant.
    public var canReachSignificance: Bool { lower != nil || upper != nil }

    /// `true` when every item's rank sum is fixed, because every judge tied every item.
    public var isDegenerate: Bool { variance == T(0) }

    /// Whether a rank sum is significant at level ``alpha``: `sum ≤ lower` or `sum ≥ upper`.
    ///
    /// - Parameter sum: An item's rank sum.
    /// - Returns: `false` for a `nan` sum, and for every sum when there are no bounds.
    public func isSignificant(_ sum: T) -> Bool {
        if let lower, sum <= lower { return true }
        if let upper, sum >= upper { return true }
        return false
    }
}

// MARK: - Exact

extension RankSumDistribution {
    /// Exact two-sided critical values at level `alpha`.
    ///
    /// See ``RankSumCriticalValues`` for the convention.
    ///
    /// - Parameter alpha: The two-sided significance level, in (0, 1).
    /// - Returns: The exact critical values, with the tail probabilities they achieve.
    /// - Throws: `BusinessMathError.invalidInput` if `alpha` is not in (0, 1).
    public func criticalValues(alpha: T) throws -> RankSumCriticalValues<T> {
        try validateRankSumAlpha(alpha)
        let probabilities: [T] = doubledSumProbabilities
        let counts: RankSumExactCounts = exactCounts
        let threshold: [UInt64] = try exactHalfAlphaCount(alpha, total: counts.total)

        var lowerIndex: Int?
        var lowerCount: [UInt64]?
        var running: [UInt64] = Array(repeating: 0, count: counts.width)
        for index in 0..<counts.entries {
            MultiLimb.add(&running, counts.limbs, at: index * counts.width)
            guard MultiLimb.lessThanOrEqual(running, threshold) else { break }
            if !counts.isZero(index) {
                lowerIndex = index
                lowerCount = running
            }
        }

        var upperIndex: Int?
        var upperCount: [UInt64]?
        running = Array(repeating: 0, count: counts.width)
        for index in stride(from: counts.entries - 1, through: 0, by: -1) {
            MultiLimb.add(&running, counts.limbs, at: index * counts.width)
            guard MultiLimb.lessThanOrEqual(running, threshold) else { break }
            if !counts.isZero(index) {
                upperIndex = index
                upperCount = running
            }
        }
        let lowerTail: T? = lowerCount.map { MultiLimb.ratio($0, counts.total, as: T.self) }
        let upperTail: T? = upperCount.map { MultiLimb.ratio($0, counts.total, as: T.self) }

        let firstInside: Int? = probabilities.indices.first { index in
            index > (lowerIndex ?? -1) && probabilities[index] > T(0)
        }
        let lastInside: Int? = probabilities.indices.last { index in
            index < (upperIndex ?? probabilities.count) && probabilities[index] > T(0)
        }
        var range: ClosedRange<T>?
        if let firstInside, let lastInside, firstInside <= lastInside {
            range = sum(atIndex: firstInside)...sum(atIndex: lastInside)
        }

        return RankSumCriticalValues(
            method: .exact, alpha: alpha, judges: judges, items: items,
            mean: mean, variance: variance,
            lower: lowerIndex.map(sum(atIndex:)), upper: upperIndex.map(sum(atIndex:)),
            lowerTailProbability: lowerTail, upperTailProbability: upperTail,
            nonSignificantRange: range)
    }

    /// The rank sum at a position of ``doubledSumProbabilities``.
    private func sum(atIndex index: Int) -> T {
        T(minimumDoubledSum + index) / T(2)
    }
}

// MARK: - Entry point

/// Two-sided critical values ("breakpoints") for one item's rank sum across a panel of judges.
///
/// With `m` judges each ranking `n` items, an item whose rank sum is at or below
/// ``RankSumCriticalValues/lower`` or at or above ``RankSumCriticalValues/upper`` is ranked
/// significantly low or high at level `alpha` (Kramer's rank-sum test). Ties are handled
/// exactly: each judge's own averaged ranks enter the null distribution, so a tied tasting
/// gets its own breakpoints rather than the untied table's.
///
/// ```swift
/// // Nine judges, eight wines, no ties.
/// let row: [Double] = [1, 2, 3, 4, 5, 6, 7, 8]
/// let untied = try rankSumCriticalValues(judgeRanks: Array(repeating: row, count: 9))
/// untied.lower                 // 26: a rank sum of 26 or less is significant at 5%
/// untied.upper                 // 55
/// untied.nonSignificantRange   // 27...54
///
/// // The same panel, but three judges could not separate wines 1 and 2.
/// var tied = Array(repeating: row, count: 9)
/// for judge in 0..<3 { tied[judge][0] = 1.5; tied[judge][1] = 1.5 }
/// let values = try rankSumCriticalValues(judgeRanks: tied)
/// values.lower                 // 26.5: the tied panel's own bound, not the untied 26
/// values.upper                 // 54.5
/// values.lowerTailProbability  // 0.021649, exact
/// ```
///
/// - Parameters:
///   - judgeRanks: One row per judge, each a full set of averaged ranks 1…n in any order, as
///     ``rankSumDistribution(judgeRanks:)`` takes.
///   - alpha: The two-sided significance level, in (0, 1). Defaults to 0.05.
///   - method: ``RankSumCriticalValueMethod/exact`` (the default) or
///     ``RankSumCriticalValueMethod/normalApproximation``.
/// - Returns: The critical values; see ``RankSumCriticalValues`` for the convention and for
///   what `nil` bounds mean.
/// - Throws: `BusinessMathError.invalidInput` for an `alpha` outside (0, 1) and for rankings
///   ``rankSumDistribution(judgeRanks:)`` refuses; `BusinessMathError.mismatchedDimensions`
///   for rows of different lengths.
///
/// - Note: These values test one item at a time. Testing every item of a panel at `alpha`
///   flags *some* item far more often than `alpha` when none differs; see
///   ``RankSumCriticalValues``.
public func rankSumCriticalValues<T: Real & Sendable>(
    judgeRanks: [[T]], alpha: T = T(5) / T(100),
    method: RankSumCriticalValueMethod = .exact
) throws -> RankSumCriticalValues<T> {
    try validateRankSumAlpha(alpha)
    switch method {
    case .exact:
        return try rankSumDistribution(judgeRanks: judgeRanks).criticalValues(alpha: alpha)
    case .normalApproximation:
        return try rankSumNormalCriticalValues(judgeRanks: judgeRanks, alpha: alpha)
    }
}

// MARK: - Normal approximation

/// `mean ∓ z·σ` with the tie-corrected variance, without building the exact distribution.
private func rankSumNormalCriticalValues<T: Real & Sendable>(
    judgeRanks: [[T]], alpha: T
) throws -> RankSumCriticalValues<T> {
    let judges: [[DoubledRankGroup]] = try doubledRankGroups(judgeRanks)
    let items: Int = judgeRanks[0].count
    let moments = rankSumMoments(judges, items: items, as: T.self)
    let tail: T = alpha / T(2)

    var lower: T?
    var upper: T?
    var lowerTail: T?
    var upperTail: T?
    if moments.variance > T(0) {
        let z: T = inverseNormalCDF(p: T(1) - tail)
        let reach: T = z * moments.variance.squareRoot()
        lower = moments.mean - reach
        upper = moments.mean + reach
        lowerTail = tail
        upperTail = tail
    }

    return RankSumCriticalValues(
        method: .normalApproximation, alpha: alpha, judges: judgeRanks.count, items: items,
        mean: moments.mean, variance: moments.variance,
        lower: lower, upper: upper,
        lowerTailProbability: lowerTail, upperTailProbability: upperTail,
        nonSignificantRange: nil)
}

/// The largest outcome count `C` with `C / total ≤ alpha / 2`, exactly.
///
/// `alpha` is decomposed exactly as `M / 2^k` (doubling is exact in binary floating point, so
/// `alpha · 2^k` is computed without rounding until it is an integer), and then
/// `C ≤ α·total/2 ⇔ C ≤ ⌊M·total / 2^(k+1)⌋`, the right shift of an exact product.
private func exactHalfAlphaCount<T: Real>(_ alpha: T, total: [UInt64]) throws -> [UInt64] {
    var scaled: T = alpha
    var exponent: Int = 0
    while scaled.rounded(.towardZero) != scaled {
        guard exponent < 100_000 else { break }
        scaled = scaled * T(2)
        exponent += 1
    }
    let limit: T = T(sign: .plus, exponent: T.Exponent(64), significand: T(1))
    guard scaled.rounded(.towardZero) == scaled, scaled < limit else {
        throw BusinessMathError.invalidInput(
            message: "The significance level has more than 64 significant bits",
            value: "\(alpha)", expectedRange: "a Float, Double or Float80 value in (0, 1)")
    }
    var mantissa: UInt64 = 0
    for bit in stride(from: 63, through: 0, by: -1) {
        let power: T = T(sign: .plus, exponent: T.Exponent(bit), significand: T(1))
        if scaled >= power {
            scaled -= power
            mantissa |= UInt64(1) << UInt64(bit)
        }
    }
    let product: [UInt64] = MultiLimb.product(total, mantissa)
    return MultiLimb.shiftedRight(product, by: exponent + 1)
}

/// Refuses a level outside the open interval (0, 1), and `nan`.
private func validateRankSumAlpha<T: Real>(_ alpha: T) throws {
    guard alpha > T(0), alpha < T(1) else {
        throw BusinessMathError.invalidInput(
            message: "The significance level must lie strictly between 0 and 1",
            value: "\(alpha)", expectedRange: "(0, 1)")
    }
}
