//
//  SpearmanCriticalValues.swift
//  BusinessMath
//
//  Two-sided critical values and the significance test for Spearman's rho, exact or
//  approximate.
//

import Foundation
import Numerics

// MARK: - Method

/// How Spearman's rho is tested.
public enum SpearmanSignificanceMethod: String, Sendable, CaseIterable {
    /// From the exact null distribution, ties included. See ``SpearmanDistribution``.
    ///
    /// Exact for every panel it accepts. Untied panels of more than 17 items are refused with
    /// `BusinessMathError.resourceExhausted`; tied panels go further.
    case exact
    /// The Edgeworth series of AS 89 (Best and Roberts, 1975), as in R's `prho.c`.
    ///
    /// An **approximation**, for untied rankings only (ties are refused). This is what R's
    /// `cor.test(method = "spearman", exact = TRUE)` reports for 10 ≤ n ≤ 1290, despite the
    /// argument's name; below 10 R enumerates. It is here so a result can be reproduced
    /// against R, and for untied panels too large to count.
    case edgeworth
    /// Student's t on `n − 2` degrees of freedom, `t = r·√((n − 2)/(1 − r²))`.
    ///
    /// An **approximation**, with or without ties: what R's `cor.test(exact = FALSE)` and
    /// SciPy's `spearmanr` report, and what R falls back to whenever there are ties.
    case tDistribution
}

// MARK: - Critical values

/// Two-sided critical values for Spearman's rho at level α.
///
/// ## The convention
///
/// For the ``SpearmanSignificanceMethod/exact`` method:
///
/// - ``upper`` is the **smallest attainable** rho `U` with `P(ρ ≥ U) ≤ α/2`;
/// - ``lower`` is the **largest attainable** rho `L` with `P(ρ ≤ L) ≤ α/2`;
/// - a rho `≥ U` or `≤ L` is significant at level α. The bounds are themselves significant.
///
/// That is the convention of published tables such as Zar's ("reject if `|r_s|` ≥ the
/// tabled value"). ``nonSignificantRange`` gives the other reading, the attainable rho values
/// strictly between `L` and `U`. Without ties the distribution is symmetric and `L = −U`;
/// with ties it need not be, and one bound can exist without the other.
///
/// ``sumOfSquaredDifferencesAtUpper`` and ``sumOfSquaredDifferencesAtLower`` give the same
/// bounds as `S = Σ dᵢ²`, the form of tables that print `S`; a high rho is a low `S`.
///
/// ## When there are no critical values
///
/// - **Too few items.** With four untied items the most extreme rho has probability
///   1/24 ≈ 0.042, more than 0.025, so nothing is significant at 5% two-sided.
///   ``canReachSignificance`` is `false`.
/// - **A judge tied everything** (``isDegenerate``). Rho does not exist, nothing is
///   significant, and there is no range.
///
/// ## The exactness guarantee
///
/// For the exact method every comparison with α/2 is made in exact integer arithmetic: the
/// tail as a count of arrangements, α as the exact binary value of `alpha`. The bounds are
/// the true critical values of the exact null distribution at that `alpha`. Only the reported
/// rho values and probabilities are rounded, once each.
///
/// ## The approximations
///
/// ``SpearmanSignificanceMethod/tDistribution`` gives `±t/√(n − 2 + t²)` for the `1 − α/2`
/// t quantile, not rounded to any attainable rho, with nominal tails α/2.
/// ``SpearmanSignificanceMethod/edgeworth`` gives the extreme rho on the untied lattice
/// (`S` even) whose Edgeworth tail is within α/2, with that tail. Neither has a
/// non-significant range.
public struct SpearmanCriticalValues<T: Real>: Sendable where T: Sendable {
    /// How these values were computed.
    public let method: SpearmanSignificanceMethod
    /// The two-sided significance level.
    public let alpha: T
    /// The number of items, `n`.
    public let items: Int
    /// A rho at or below this is significantly negative; `nil` when none is.
    public let lower: T?
    /// A rho at or above this is significantly positive; `nil` when none is.
    public let upper: T?
    /// `P(ρ ≤ lower)`: exact for the exact method, the approximation's tail otherwise.
    public let lowerTailProbability: T?
    /// `P(ρ ≥ upper)`: exact for the exact method, the approximation's tail otherwise.
    public let upperTailProbability: T?
    /// `S = Σ dᵢ²` at ``lower``: the largest significant `S`.
    public let sumOfSquaredDifferencesAtLower: T?
    /// `S = Σ dᵢ²` at ``upper``: the smallest significant `S`.
    public let sumOfSquaredDifferencesAtUpper: T?
    /// The attainable rho values that are not significant, from the first above ``lower`` to
    /// the last below ``upper``. `nil` for the approximations and when degenerate.
    public let nonSignificantRange: ClosedRange<T>?
    /// `true` when either judge tied every item, so rho does not exist.
    public let isDegenerate: Bool
    /// How far a rho may sit from a bound and still count as on it (exact method only).
    internal let tolerance: T

    /// `true` when at least one rho is significant.
    public var canReachSignificance: Bool { lower != nil || upper != nil }

    /// Whether a rho is significant at level ``alpha``: `rho ≥ upper` or `rho ≤ lower`.
    ///
    /// For the exact method a rho within a quarter of the smallest lattice step of a bound
    /// counts as on it, so a rho computed elsewhere, a few ulps from the exact value, is
    /// judged as the attainable rho it is. ``spearmanTest(_:vs:alpha:method:)`` decides in
    /// integers and needs no such allowance.
    ///
    /// - Parameter rho: An observed rho.
    /// - Returns: `false` for `nan`, and for every rho when there are no bounds.
    public func isSignificant(_ rho: T) -> Bool {
        guard !rho.isNaN else { return false }
        if let upper, rho >= upper - tolerance { return true }
        if let lower, rho <= lower + tolerance { return true }
        return false
    }
}

extension SpearmanDistribution {
    /// Exact two-sided critical values at level `alpha`; see ``SpearmanCriticalValues``.
    ///
    /// - Parameter alpha: The two-sided significance level, in (0, 1).
    /// - Returns: The exact critical values, with the tail probabilities they achieve.
    /// - Throws: `BusinessMathError.invalidInput` if `alpha` is not in (0, 1).
    public func criticalValues(alpha: T) throws -> SpearmanCriticalValues<T> {
        try validateRankSumAlpha(alpha)
        guard let counts = exactCounts else {
            return SpearmanCriticalValues(
                method: .exact, alpha: alpha, items: items, lower: nil, upper: nil,
                lowerTailProbability: nil, upperTailProbability: nil,
                sumOfSquaredDifferencesAtLower: nil, sumOfSquaredDifferencesAtUpper: nil,
                nonSignificantRange: nil, isDegenerate: true, tolerance: T(0))
        }
        let bounds = try exactBoundIndices(alpha: alpha)
        let lowerTail: T? = bounds.lowerCount.map { MultiLimb.ratio($0, counts.total, as: T.self) }
        let upperTail: T? = bounds.upperCount.map { MultiLimb.ratio($0, counts.total, as: T.self) }
        let first: Int = (bounds.lower ?? -1) + 1
        let last: Int = (bounds.upper ?? counts.entries) - 1
        let range: ClosedRange<T>? = first <= last ? rhoValues[first]...rhoValues[last] : nil
        return SpearmanCriticalValues(
            method: .exact, alpha: alpha, items: items,
            lower: bounds.lower.map { rhoValues[$0] }, upper: bounds.upper.map { rhoValues[$0] },
            lowerTailProbability: lowerTail, upperTailProbability: upperTail,
            sumOfSquaredDifferencesAtLower: bounds.lower.map { sumsOfSquaredDifferences[$0] },
            sumOfSquaredDifferencesAtUpper: bounds.upper.map { sumsOfSquaredDifferences[$0] },
            nonSignificantRange: range, isDegenerate: false, tolerance: tolerance)
    }

    /// The indices of the exact bounds and their tail counts, decided in integers.
    internal func exactBoundIndices(alpha: T) throws
        -> (lower: Int?, upper: Int?, lowerCount: [UInt64]?, upperCount: [UInt64]?) {
        guard let counts = exactCounts else { return (nil, nil, nil, nil) }
        let threshold: [UInt64] = try exactHalfAlphaCount(alpha, total: counts.total)
        var lower: Int?
        var lowerCount: [UInt64]?
        var running: [UInt64] = Array(repeating: 0, count: counts.width)
        for index in 0..<counts.entries {
            MultiLimb.add(&running, counts.limbs, at: index * counts.width)
            guard MultiLimb.lessThanOrEqual(running, threshold) else { break }
            lower = index
            lowerCount = running
        }
        var upper: Int?
        var upperCount: [UInt64]?
        running = Array(repeating: 0, count: counts.width)
        for index in stride(from: counts.entries - 1, through: 0, by: -1) {
            MultiLimb.add(&running, counts.limbs, at: index * counts.width)
            guard MultiLimb.lessThanOrEqual(running, threshold) else { break }
            upper = index
            upperCount = running
        }
        return (lower, upper, lowerCount, upperCount)
    }
}

// MARK: - Entry points

/// Two-sided critical values for Spearman's rho with `items` untied items: the published
/// table, computed.
///
/// ```swift
/// let values = try spearmanCriticalValues(items: 10, alpha: 0.05)
/// values.upper   // 0.648…: a rho of 0.648 or more is significant at 5% two-sided
/// ```
///
/// - Parameters:
///   - items: The number of items, at least 2 (at least 3 for the approximations).
///   - alpha: The two-sided significance level, in (0, 1). Defaults to 0.05.
///   - method: ``SpearmanSignificanceMethod/exact`` (the default), or an approximation.
/// - Returns: The critical values; see ``SpearmanCriticalValues``.
/// - Throws: `BusinessMathError.invalidInput` for an `alpha` outside (0, 1) or too few items;
///   `BusinessMathError.resourceExhausted` from the exact method beyond 17 untied items.
public func spearmanCriticalValues<T: Real & Sendable>(
    items: Int, alpha: T = T(5) / T(100), method: SpearmanSignificanceMethod = .exact
) throws -> SpearmanCriticalValues<T> {
    try validateRankSumAlpha(alpha)
    return try spearmanCriticalValues(SpearmanStructure(untied: items), alpha: alpha, method: method)
}

/// Two-sided critical values for Spearman's rho between two judges, ties included.
///
/// Only the two judges' tie patterns matter: a tied tasting gets its own critical values
/// rather than the untied table's.
///
/// - Parameters:
///   - independent: The first judge's scores or ranks.
///   - variable: The second judge's, for the same items.
///   - alpha: The two-sided significance level, in (0, 1). Defaults to 0.05.
///   - method: ``SpearmanSignificanceMethod/exact`` (the default), or an approximation.
/// - Returns: The critical values; see ``SpearmanCriticalValues``.
/// - Throws: As ``spearmanDistribution(_:vs:)``, and `BusinessMathError.invalidInput` for an
///   `alpha` outside (0, 1), or for ties under ``SpearmanSignificanceMethod/edgeworth``.
public func spearmanCriticalValues<T: Real & Sendable>(
    _ independent: [T], vs variable: [T], alpha: T = T(5) / T(100),
    method: SpearmanSignificanceMethod = .exact
) throws -> SpearmanCriticalValues<T> {
    try validateRankSumAlpha(alpha)
    return try spearmanCriticalValues(SpearmanStructure(independent, variable), alpha: alpha, method: method)
}

private func spearmanCriticalValues<T: Real & Sendable>(
    _ structure: SpearmanStructure, alpha: T, method: SpearmanSignificanceMethod
) throws -> SpearmanCriticalValues<T> {
    switch method {
    case .exact:
        let distribution: SpearmanDistribution<T> = try spearmanDistribution(structure)
        return try distribution.criticalValues(alpha: alpha)
    case .edgeworth:
        return try edgeworthCriticalValues(structure, alpha: alpha)
    case .tDistribution:
        return try tCriticalValues(structure, alpha: alpha)
    }
}

// MARK: - Test

/// The result of testing two judges' agreement with Spearman's rho.
public struct SpearmanTestResult<T: Real>: Sendable where T: Sendable {
    /// How the p-value and critical values were computed.
    public let method: SpearmanSignificanceMethod
    /// The two-sided significance level.
    public let alpha: T
    /// The number of items.
    public let items: Int
    /// Spearman's rho, tie-corrected; `nil` when a judge tied every item.
    public let rho: T?
    /// `S = Σ dᵢ²` of the averaged ranks; `nil` when a judge tied every item.
    public let sumOfSquaredDifferences: T?
    /// The two-sided p-value: exact for the exact method, the approximation's otherwise.
    /// `nil` when a judge tied every item.
    public let pValue: T?
    /// Whether either judge tied any items.
    public let hasTies: Bool
    /// The critical values for these two judges' tie patterns.
    public let criticalValues: SpearmanCriticalValues<T>
    /// Whether rho is significant at ``alpha``. Exact method: decided in integers, and the
    /// same as `pValue ≤ alpha` decided exactly.
    public let isSignificant: Bool

    /// `false` when a judge tied every item, so rho does not exist. Report that as "not
    /// computable", never as zero agreement.
    public var isComputable: Bool { rho != nil }
}

/// Tests two judges' agreement: Spearman's rho, its two-sided p-value, and its critical
/// values, ties included.
///
/// ```swift
/// let a: [Double] = [1, 2, 3, 4, 5, 6, 7, 8]
/// let b: [Double] = [2, 1, 4, 3, 6, 5, 8, 7]
/// let result = try spearmanTest(a, vs: b)
/// result.rho            // 0.905
/// result.pValue         // exact, from the 8! arrangements
/// result.isSignificant  // true at 5%
/// ```
///
/// - Parameters:
///   - independent: The first judge's scores or ranks; ranked here with averaged ties.
///   - variable: The second judge's, for the same items in the same order.
///   - alpha: The two-sided significance level, in (0, 1). Defaults to 0.05.
///   - method: ``SpearmanSignificanceMethod/exact`` (the default), or an approximation.
/// - Returns: The result. When a judge tied every item, rho and the p-value are `nil` and
///   nothing is significant.
/// - Throws: As ``spearmanCriticalValues(_:vs:alpha:method:)``.
public func spearmanTest<T: Real & Sendable>(
    _ independent: [T], vs variable: [T], alpha: T = T(5) / T(100),
    method: SpearmanSignificanceMethod = .exact
) throws -> SpearmanTestResult<T> {
    try validateRankSumAlpha(alpha)
    let structure = try SpearmanStructure(independent, variable)
    let key: Int = structure.observedKey
    let rho: T? = structure.isDegenerate ? nil : structure.rho(key: key, as: T.self)
    let squares: T? = structure.isDegenerate ? nil : structure.sumOfSquaredDifferences(key: key, as: T.self)

    let values: SpearmanCriticalValues<T>
    let pValue: T?
    let significant: Bool
    switch method {
    case .exact:
        let distribution: SpearmanDistribution<T> = try spearmanDistribution(structure)
        values = try distribution.criticalValues(alpha: alpha)
        pValue = distribution.pValue(key: key)
        let bounds = try distribution.exactBoundIndices(alpha: alpha)
        let keys: [Int] = distribution.exactCounts?.keys ?? []
        let low: Bool = bounds.lower.map { key <= keys[$0] } ?? false
        let high: Bool = bounds.upper.map { key >= keys[$0] } ?? false
        significant = low || high
    case .edgeworth:
        values = try edgeworthCriticalValues(structure, alpha: alpha)
        pValue = structure.isDegenerate ? nil
            : edgeworthTwoSided(items: structure.items, s: structure.sumOfSquaredDifferences(key: key, as: T.self))
        significant = pValue.map { $0 <= alpha } ?? false
    case .tDistribution:
        values = try tCriticalValues(structure, alpha: alpha)
        pValue = try rho.map { try tTwoSided(rho: $0, items: structure.items) }
        significant = pValue.map { $0 <= alpha } ?? false
    }
    return SpearmanTestResult(
        method: method, alpha: alpha, items: structure.items, rho: rho,
        sumOfSquaredDifferences: squares, pValue: pValue, hasTies: structure.hasTies,
        criticalValues: values, isSignificant: significant)
}

// MARK: - t approximation

/// Refuses approximations for fewer than three items, where they have no degrees of freedom.
private func requireApproximable(_ structure: SpearmanStructure) throws {
    guard structure.items >= 3 else {
        throw BusinessMathError.invalidInput(
            message: "The Spearman approximations need at least 3 items",
            value: "\(structure.items)", expectedRange: "[3, ∞)")
    }
}

/// Two-sided `P(|T| ≥ |t|)` on `n − 2` df, as `I_{1 − r²}((n − 2)/2, ½)`, with
/// `1 − r² = (1 − r)(1 + r)` so nothing cancels near `|r| = 1`.
internal func tTwoSided<T: Real>(rho: T, items: Int) throws -> T {
    let magnitude: T = Swift.min(Swift.abs(rho), T(1))
    let x: T = (T(1) - magnitude) * (T(1) + magnitude)
    guard x > T(0) else { return T(0) }
    return try regularizedIncompleteBeta(x: x, a: T(items - 2) / T(2), b: T(1) / T(2))
}

private func tCriticalValues<T: Real & Sendable>(_ structure: SpearmanStructure, alpha: T) throws
    -> SpearmanCriticalValues<T> {
    try requireApproximable(structure)
    guard !structure.isDegenerate else { return degenerateValues(.tDistribution, structure, alpha) }
    // |r| ≥ r_c ⇔ I_{1 − r²}(ν/2, ½) ≤ α, and I is increasing in its argument.
    let x: T = try inverseRegularizedIncompleteBeta(p: alpha, a: T(structure.items - 2) / T(2), b: T(1) / T(2))
    let critical: T = (T(1) - x).squareRoot()
    let half: T = alpha / T(2)
    return SpearmanCriticalValues(
        method: .tDistribution, alpha: alpha, items: structure.items,
        lower: -critical, upper: critical, lowerTailProbability: half, upperTailProbability: half,
        sumOfSquaredDifferencesAtLower: structure.sumOfSquaredDifferences(rho: -critical, as: T.self),
        sumOfSquaredDifferencesAtUpper: structure.sumOfSquaredDifferences(rho: critical, as: T.self),
        nonSignificantRange: nil, isDegenerate: false, tolerance: T(0))
}

private func degenerateValues<T: Real & Sendable>(_ method: SpearmanSignificanceMethod,
                                                  _ structure: SpearmanStructure, _ alpha: T)
    -> SpearmanCriticalValues<T> {
    SpearmanCriticalValues(
        method: method, alpha: alpha, items: structure.items, lower: nil, upper: nil,
        lowerTailProbability: nil, upperTailProbability: nil,
        sumOfSquaredDifferencesAtLower: nil, sumOfSquaredDifferencesAtUpper: nil,
        nonSignificantRange: nil, isDegenerate: true, tolerance: T(0))
}

// MARK: - Edgeworth (AS 89, as in R)

/// R's `prho` (src/library/stats/src/prho.c, after AS 89), Edgeworth branch only.
///
/// - Parameters:
///   - items: `n`.
///   - s: The statistic `S = Σ dᵢ²` threshold.
///   - lowerTail: `false` for `P(S ≥ s)`; `true` for `P(S < s)`.
internal func edgeworthTail<T: Real>(items: Int, s: T, lowerTail: Bool) -> T {
    let c: [T] = [T(2274), T(2531), T(1745), T(758), T(1033), T(3932),
                  T(879), T(151), T(72), T(831), T(131)].map { $0 / T(10_000) }
    let c12: T = T(46) / T(100_000)
    guard s > T(0) else { return lowerTail ? T(0) : T(1) }
    let n: T = T(items)
    let n3: T = n * (n * n - T(1)) / T(3)
    guard s <= n3 else { return lowerTail ? T(1) : T(0) }
    let b: T = T(1) / n
    // Split into steps: as one expression it exceeds the Linux type-checker's time limit.
    let nSquaredMinusOne: T = n * n - T(1)
    let scaled: T = T(6) * (s - T(1)) * b / nSquaredMinusOne
    let x: T = (scaled - T(1)) * (n - T(1)).squareRoot()
    let y: T = x * x
    let inner: T = c[8] - c[9] * b + y * b * (c[10] - c12 * y)
    let middle: T = c[6] + c[7] * b - y * inner
    let outer: T = -c[3] + b * (c[4] + c[5] * b) - y * b * middle
    let u: T = x * b * (c[0] + b * (c[1] + c[2] * b) + y * outer)
    let correction: T = u / T.exp(y / T(2))
    let p: T = lowerTail ? normalCDF(x: x) - correction : normalCDF(x: -x) + correction
    return Swift.min(Swift.max(p, T(0)), T(1))
}

/// R's two-sided Edgeworth p-value for an untied `S`: the tail on the observation's side,
/// doubled, capped at 1.
internal func edgeworthTwoSided<T: Real>(items: Int, s: T) -> T {
    let n: T = T(items)
    let mean: T = (n * n * n - n) / T(6)
    let p: T = s > mean
        ? edgeworthTail(items: items, s: s, lowerTail: false)
        : edgeworthTail(items: items, s: s + T(2), lowerTail: true)
    return Swift.min(T(2) * p, T(1))
}

private func edgeworthCriticalValues<T: Real & Sendable>(_ structure: SpearmanStructure, alpha: T) throws
    -> SpearmanCriticalValues<T> {
    try requireApproximable(structure)
    guard !structure.hasTies else {
        throw BusinessMathError.invalidInput(
            message: "The Edgeworth approximation (AS 89) assumes no ties; use the exact method or the t approximation",
            value: "ties", expectedRange: "untied rankings")
    }
    let n: Int = structure.items
    let half: T = alpha / T(2)
    // S runs over even integers 0 … (n³ − n)/3; as a count of half-steps, 0 … top.
    let top: Int = (n * n * n - n) / 6
    // Upper rho bound: the largest even s with P(S ≤ s) = P(S < s + 2) ≤ α/2.
    let upperTail: (Int) -> T = { step in
        edgeworthTail(items: n, s: T(2 * step + 2), lowerTail: true)
    }
    // Lower rho bound: the smallest even s with P(S ≥ s) ≤ α/2.
    let lowerTail: (Int) -> T = { step in
        edgeworthTail(items: n, s: T(2 * step), lowerTail: false)
    }
    let upperStep: Int? = lastStep(within: half, from: 0, to: top / 2, tail: upperTail)
    let lowerStep: Int? = firstStep(within: half, from: (top + 1) / 2, to: top, tail: lowerTail)
    let cube: T = T(n * n * n - n)
    let rho: (Int) -> T = { step in T(1) - T(6) * T(2 * step) / cube }
    return SpearmanCriticalValues(
        method: .edgeworth, alpha: alpha, items: n,
        lower: lowerStep.map(rho), upper: upperStep.map(rho),
        lowerTailProbability: lowerStep.map(lowerTail), upperTailProbability: upperStep.map(upperTail),
        sumOfSquaredDifferencesAtLower: lowerStep.map { T(2 * $0) },
        sumOfSquaredDifferencesAtUpper: upperStep.map { T(2 * $0) },
        nonSignificantRange: nil, isDegenerate: false, tolerance: T(0))
}

/// The last step in `from…to` whose tail is within `limit`, for a tail increasing in the
/// step; `nil` when even `from` exceeds it. Bisection.
private func lastStep<T: Real>(within limit: T, from: Int, to: Int, tail: (Int) -> T) -> Int? {
    guard tail(from) <= limit else { return nil }
    var low: Int = from
    var high: Int = to
    while low < high {
        let middle: Int = low + (high - low + 1) / 2
        if tail(middle) <= limit { low = middle } else { high = middle - 1 }
    }
    return low
}

/// The first step in `from…to` whose tail is within `limit`, for a tail decreasing in the
/// step; `nil` when even `to` exceeds it. Bisection.
private func firstStep<T: Real>(within limit: T, from: Int, to: Int, tail: (Int) -> T) -> Int? {
    guard tail(to) <= limit else { return nil }
    var low: Int = from
    var high: Int = to
    while low < high {
        let middle: Int = low + (high - low) / 2
        if tail(middle) <= limit { high = middle } else { low = middle + 1 }
    }
    return low
}
