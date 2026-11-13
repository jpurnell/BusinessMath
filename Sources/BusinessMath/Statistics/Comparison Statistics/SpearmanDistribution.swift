//
//  SpearmanDistribution.swift
//  BusinessMath
//
//  The exact null distribution of Spearman's rho between two rankings, ties included.
//

import Foundation
import Numerics

// MARK: - Distribution

/// The exact null distribution of Spearman's rho between two judges' rankings, ties included.
///
/// ## The null hypothesis
///
/// Two judges rank the same `n` items. One judge's ranking is held fixed, and the other's is
/// a **uniformly random permutation of that judge's own ranks**: no association between them.
/// Tied items carry the average of the places they span (1, 2.5, 2.5, 4), and both judges'
/// tie structures are **conditioned on as observed**: the distribution is the one for these
/// two particular patterns of ties, not for untied rankings.
///
/// The statistic is the Pearson correlation of the averaged ranks, which is what
/// ``spearmansRho(_:vs:)`` computes with its tie correction. Under permutation the sums and
/// sums of squares of both rankings are fixed, so rho is an increasing function of
/// `Σ xᵢyᵢ` and a decreasing function of `S = Σ dᵢ²`; without ties it is the textbook
/// `1 − 6S/(n³ − n)`.
///
/// ## Exact counts
///
/// Every distinct arrangement of the second judge's ranks is counted exactly, in multi-limb
/// integers, by a dynamic programme over positions; van de Wiel and Di Bucchianico (2001)
/// compute the tied distribution by recursions of this kind.
/// ``probabilities`` are those counts over the total, rounded once each to `T`, and the
/// critical values and the exact p-values of ``spearmanTest(_:vs:alpha:method:)`` are decided
/// on the counts themselves.
///
/// The work grows as `2ⁿ` without ties: 17 untied items are counted in about 0.3 s and
/// 160 MB in a release build, and larger untied panels are refused with `BusinessMathError.resourceExhausted`; see the
/// <doc:2.7-SpearmanSignificance> article. Ties shrink it, because only the multiset of the
/// more-tied judge is tracked, so a heavily tied tasting is exact well beyond 17 items (30 wines scored 1–5 by both
/// judges takes about half a second).
///
/// ## Only attainable values
///
/// ``rhoValues``, ``sumsOfSquaredDifferences`` and ``probabilities`` list the attainable
/// values only, rho ascending, every probability positive.
///
/// ## A judge who tied everything
///
/// If either judge gave every item the same rank, rho is `0/0`: there is no ranking to
/// correlate. The distribution is then ``isDegenerate`` and empty. That is "not computable",
/// never zero agreement.
///
/// ## Usage
///
/// ```swift
/// let d: SpearmanDistribution<Double> = try spearmanDistribution(items: 5)
/// d.probability(atLeast: 0.9)   // 5/120: the identity and its four adjacent swaps
///
/// // A judge who could not separate wines 2 and 3.
/// let tied: SpearmanDistribution<Double> = try spearmanDistribution([1, 2, 3, 4, 5],
///                                                                    vs: [1, 2.5, 2.5, 4, 5])
/// ```
public struct SpearmanDistribution<T: Real>: Sendable where T: Sendable {
    /// The number of items, `n`.
    public let items: Int
    /// Whether either judge tied any items.
    public let hasTies: Bool
    /// Every attainable rho, ascending.
    public let rhoValues: [T]
    /// `S = Σ dᵢ²` at each attainable rho, so descending. With ties a multiple of ¼.
    public let sumsOfSquaredDifferences: [T]
    /// The probability of each attainable rho; all positive, summing to one.
    public let probabilities: [T]

    /// The integer description of the two rankings.
    internal let structure: SpearmanStructure
    /// The exact counts, `nil` when degenerate.
    internal let exactCounts: SpearmanExactCounts?

    /// `true` when either judge tied every item, so rho does not exist.
    public var isDegenerate: Bool { exactCounts == nil }

    /// A quarter of the smallest possible spacing between attainable rho values.
    ///
    /// Queries by rho treat any value within this distance of an attainable rho as that rho:
    /// a rho computed elsewhere, through square roots, is a few ulps from the exact value,
    /// and attainable values are at least four of these apart.
    internal var tolerance: T { structure.latticeStep(as: T.self) / T(4) }

    /// The lower-tail probability `P(rho ≤ value)`, summed in exact counts and rounded once.
    ///
    /// - Parameter rho: Any value; one within rounding of an attainable rho counts as it.
    /// - Returns: The probability, `nan` for a `nan` rho, and zero when degenerate.
    public func probability(atMost rho: T) -> T {
        guard !rho.isNaN else { return T.nan }
        guard let counts = exactCounts else { return T(0) }
        let included: Int = countAtMost(rho + tolerance)
        guard included > 0 else { return T(0) }
        guard included < counts.entries else { return T(1) }
        return MultiLimb.ratio(counts.sum(0..<included), counts.total, as: T.self)
    }

    /// The upper-tail probability `P(rho ≥ value)`, summed in exact counts and rounded once.
    ///
    /// - Parameter rho: Any value; one within rounding of an attainable rho counts as it.
    /// - Returns: The probability, `nan` for a `nan` rho, and zero when degenerate.
    public func probability(atLeast rho: T) -> T {
        guard !rho.isNaN else { return T.nan }
        guard let counts = exactCounts else { return T(0) }
        let below: Int = countBelow(rho - tolerance)
        guard below > 0 else { return T(1) }
        guard below < counts.entries else { return T(0) }
        return MultiLimb.ratio(counts.sum(below..<counts.entries), counts.total, as: T.self)
    }

    /// The exact two-sided p-value of an observed rho: `min(1, 2·min(P(ρ ≤ r), P(ρ ≥ r)))`.
    ///
    /// That is the convention of R's `cor.test` and SciPy's `permutation_test`. Both tails are
    /// counted exactly and the smaller is doubled before the single rounding.
    ///
    /// - Parameter rho: An observed rho; one within rounding of an attainable rho counts as it.
    /// - Returns: The p-value, or `nil` when degenerate or `rho` is `nan`.
    public func pValue(rho: T) -> T? {
        guard !rho.isNaN, let counts = exactCounts else { return nil }
        let below: [UInt64] = counts.sum(0..<countAtMost(rho + tolerance))
        let above: [UInt64] = counts.sum(countBelow(rho - tolerance)..<counts.entries)
        return Self.twoSided(below: below, above: above, total: counts.total)
    }

    /// The exact two-sided p-value of an observed `K`.
    internal func pValue(key: Int) -> T? {
        guard let counts = exactCounts else { return nil }
        let atMost: Int = counts.countAtMost(key)
        let below: Int = counts.countAtMost(key - 1)
        return Self.twoSided(below: counts.sum(0..<atMost), above: counts.sum(below..<counts.entries),
                             total: counts.total)
    }

    private static func twoSided(below: [UInt64], above: [UInt64], total: [UInt64]) -> T {
        let smaller: [UInt64] = MultiLimb.lessThanOrEqual(below, above) ? below : above
        let doubled: [UInt64] = MultiLimb.product(smaller, 2)
        guard MultiLimb.lessThanOrEqual(doubled, total) else { return T(1) }
        return MultiLimb.ratio(doubled, total, as: T.self)
    }

    /// How many attainable rho values are `≤ value`.
    private func countAtMost(_ value: T) -> Int {
        var low: Int = 0
        var high: Int = rhoValues.count
        while low < high {
            let middle: Int = (low + high) / 2
            if rhoValues[middle] <= value { low = middle + 1 } else { high = middle }
        }
        return low
    }

    /// How many attainable rho values are `< value`.
    private func countBelow(_ value: T) -> Int {
        var low: Int = 0
        var high: Int = rhoValues.count
        while low < high {
            let middle: Int = (low + high) / 2
            if rhoValues[middle] < value { low = middle + 1 } else { high = middle }
        }
        return low
    }
}

// MARK: - Construction

/// The exact null distribution of Spearman's rho for two judges' observations, ties included.
///
/// The observations are ranked here, ties given their average place, exactly as
/// ``spearmansRho(_:vs:)`` ranks them; ranks themselves may be passed. Only the two tie
/// patterns matter to the distribution, not how the items are paired.
///
/// - Parameters:
///   - independent: The first judge's scores or ranks.
///   - variable: The second judge's, for the same items in the same order.
/// - Returns: The exact distribution of rho under the null; see ``SpearmanDistribution``.
/// - Throws: `BusinessMathError.invalidInput` for fewer than two items or a `nan` or infinite
///   value; `BusinessMathError.mismatchedDimensions` when the lengths differ;
///   `BusinessMathError.resourceExhausted` when the exact count would exceed its memory
///   budget (untied panels of more than 17 items).
///
/// - Complexity: Proportional to `Σₖ (states in layer k) × (distinct values) × (sum hull)`
///   limb additions. Without ties the states are subsets, so about `n·2ⁿ⁻¹ × n³/8`; ties
///   shrink it to `∏ (tⱼ + 1)` states. See the <doc:2.7-SpearmanSignificance> article for
///   timings.
public func spearmanDistribution<T: Real & Sendable>(_ independent: [T], vs variable: [T]) throws
    -> SpearmanDistribution<T> {
    let structure = try SpearmanStructure(independent, variable)
    return try spearmanDistribution(structure)
}

/// The exact null distribution of Spearman's rho for `items` untied items: the distribution
/// every published table is computed from.
///
/// - Parameter items: The number of items ranked by each judge, at least 2.
/// - Returns: The distribution; see ``SpearmanDistribution``.
/// - Throws: `BusinessMathError.invalidInput` for fewer than two items;
///   `BusinessMathError.resourceExhausted` beyond the exact method's budget (more than 17 items).
public func spearmanDistribution<T: Real & Sendable>(items: Int) throws -> SpearmanDistribution<T> {
    try spearmanDistribution(SpearmanStructure(untied: items))
}

/// The most 64-bit limbs two adjacent layers of the exact recursion may hold: 2²⁵, 256 MiB.
internal let spearmanExactLimbBudget: Int = 1 << 25

/// The most states one layer of the exact recursion may hold: 2¹⁸. It refuses hopeless panels
/// (21 untied items, C(21, 10) = 352,716 states) before any work; the limb budget, checked
/// next from the layers' shapes, is what stops untied panels at 18.
internal let spearmanExactStateBudget: Int = 1 << 18

internal func spearmanDistribution<T: Real & Sendable>(_ structure: SpearmanStructure) throws
    -> SpearmanDistribution<T> {
    guard !structure.isDegenerate else {
        return SpearmanDistribution(items: structure.items, hasTies: structure.hasTies, rhoValues: [],
                                    sumsOfSquaredDifferences: [], probabilities: [],
                                    structure: structure, exactCounts: nil)
    }
    let counts = try SpearmanExactCounts.make(
        positions: structure.positions, values: structure.values, scale: structure.scale,
        limbBudget: spearmanExactLimbBudget, stateBudget: spearmanExactStateBudget)
    var rho: [T] = []
    var squares: [T] = []
    var probabilities: [T] = []
    rho.reserveCapacity(counts.entries)
    squares.reserveCapacity(counts.entries)
    probabilities.reserveCapacity(counts.entries)
    for (index, key) in counts.keys.enumerated() {
        rho.append(structure.rho(key: key, as: T.self))
        squares.append(structure.sumOfSquaredDifferences(key: key, as: T.self))
        probabilities.append(MultiLimb.ratio(counts.count(index), counts.total, as: T.self))
    }
    return SpearmanDistribution(items: structure.items, hasTies: structure.hasTies, rhoValues: rho,
                                sumsOfSquaredDifferences: squares, probabilities: probabilities,
                                structure: structure, exactCounts: counts)
}

// MARK: - Structure

/// Two rankings reduced to integers: doubled averaged ranks, their sums, and the observed
/// pairing.
///
/// Doubled averaged ranks are integers (a group of `t` ties at sorted places `p … p + t − 1`,
/// zero-based, has doubled rank `2p + t + 1`), so every quantity the exact method decides on
/// is an integer, and nothing is decided on a rounded value.
internal struct SpearmanStructure: Sendable {
    /// `n`.
    let items: Int
    /// Doubled ranks of each judge, in the items' order.
    let first: [Int]
    let second: [Int]
    /// The judge whose ranks are positions (ascending) and the one whose multiset is tracked.
    let positions: [Int]
    let values: [DoubledRankGroup]
    /// A common factor of every product `xᵢ·yⱼ` of doubled ranks; `K = Σ XᵢYᵢ / scale`.
    let scale: Int
    let sumFirst: Int
    let sumSecond: Int
    let sumSquaresFirst: Int
    let sumSquaresSecond: Int
    let hasTies: Bool

    /// Either judge tied every item: the variance of that ranking is zero.
    var isDegenerate: Bool {
        items * sumSquaresFirst == sumFirst * sumFirst || items * sumSquaresSecond == sumSecond * sumSecond
    }

    /// `K` for the observed pairing.
    var observedKey: Int {
        var sum: Int = 0
        for i in 0..<items { sum += first[i] * second[i] }
        return sum / scale
    }

    init<T: Real>(_ independent: [T], _ variable: [T]) throws {
        guard independent.count == variable.count else {
            throw BusinessMathError.mismatchedDimensions(
                message: "Spearman's rho needs the same items from both judges",
                expected: "\(independent.count)", actual: "\(variable.count)")
        }
        guard independent.count >= 2 else {
            throw BusinessMathError.invalidInput(
                message: "Spearman's rho needs at least 2 items",
                value: "\(independent.count)", expectedRange: "[2, ∞)")
        }
        for value in independent + variable where !value.isFinite {
            throw BusinessMathError.invalidInput(
                message: "Spearman's rho requires finite observations; a NaN or infinity has no rank",
                value: "\(value)", expectedRange: "finite values")
        }
        self.init(first: doubledAverageRanks(independent), second: doubledAverageRanks(variable))
    }

    init(untied items: Int) throws {
        guard items >= 2 else {
            throw BusinessMathError.invalidInput(
                message: "Spearman's rho needs at least 2 items",
                value: "\(items)", expectedRange: "[2, ∞)")
        }
        let ranks: [Int] = (1...items).map { 2 * $0 }
        self.init(first: ranks, second: ranks)
    }

    private init(first: [Int], second: [Int]) {
        items = first.count
        self.first = first
        self.second = second
        let firstGroups: [DoubledRankGroup] = rankGroups(first)
        let secondGroups: [DoubledRankGroup] = rankGroups(second)
        hasTies = firstGroups.count < items || secondGroups.count < items
        // Track the multiset that gives fewer states: ∏ (t + 1).
        let firstStates: Double = firstGroups.reduce(1) { $0 * Double($1.count + 1) }
        let secondStates: Double = secondGroups.reduce(1) { $0 * Double($1.count + 1) }
        if firstStates < secondStates {
            values = firstGroups
            positions = second.sorted()
        } else {
            values = secondGroups
            positions = first.sorted()
        }
        let positionFactor: Int = positions.reduce(0) { greatestCommonDivisor($0, $1) }
        let valueFactor: Int = values.reduce(0) { greatestCommonDivisor($0, $1.doubledRank) }
        scale = Swift.max(1, positionFactor * valueFactor)
        sumFirst = first.reduce(0, +)
        sumSecond = second.reduce(0, +)
        sumSquaresFirst = first.reduce(0) { $0 + $1 * $1 }
        sumSquaresSecond = second.reduce(0) { $0 + $1 * $1 }
    }

    /// `n·Σx² − (Σx)²` for each judge, in `T` (they can exceed `Int` for very large `n`).
    func spreads<T: Real>(as type: T.Type) -> (first: T, second: T) {
        let n: T = T(items)
        let first: T = n * T(sumSquaresFirst) - T(sumFirst) * T(sumFirst)
        let second: T = n * T(sumSquaresSecond) - T(sumSecond) * T(sumSecond)
        return (first, second)
    }

    /// Rho at a key.
    ///
    /// Formed in integers wherever they fit: the numerator `n·scale·K − Σx·Σy` exactly, the
    /// denominator as one square root of the exact product of the spreads, so rho carries
    /// two roundings. Perfect agreement is detected in integers (numerator² equals the
    /// product) and returned as exactly ±1.
    func rho<T: Real>(key: Int, as type: T.Type) -> T {
        guard let exact = integerTerms(key: key) else {
            let spread = spreads(as: T.self)
            let top: T = T(items) * T(key) * T(scale) - T(sumFirst) * T(sumSecond)
            return top / (spread.first.squareRoot() * spread.second.squareRoot())
        }
        let (square, overflow) = exact.numerator.multipliedReportingOverflow(by: exact.numerator)
        if !overflow, exact.product > 0, square == exact.product {
            return exact.numerator > 0 ? T(1) : T(-1)
        }
        return T(exact.numerator) / T(exact.product).squareRoot()
    }

    /// The numerator and the product of the spreads as integers, or `nil` if either overflows.
    private func integerTerms(key: Int) -> (numerator: Int, product: Int)? {
        let (scaled, o1) = key.multipliedReportingOverflow(by: scale * items)
        let (sums, o2) = sumFirst.multipliedReportingOverflow(by: sumSecond)
        let (numerator, o3) = scaled.subtractingReportingOverflow(sums)
        let (firstSquares, o4) = items.multipliedReportingOverflow(by: sumSquaresFirst)
        let (secondSquares, o5) = items.multipliedReportingOverflow(by: sumSquaresSecond)
        let (firstSum, o6) = sumFirst.multipliedReportingOverflow(by: sumFirst)
        let (secondSum, o7) = sumSecond.multipliedReportingOverflow(by: sumSecond)
        let (product, o8) = (firstSquares - firstSum).multipliedReportingOverflow(by: secondSquares - secondSum)
        guard !(o1 || o2 || o3 || o4 || o5 || o6 || o7 || o8) else { return nil }
        return (numerator, product)
    }

    /// `S = Σ dᵢ²` at a key: `(ΣX² + ΣY² − 2·scale·K) / 4` in doubled ranks.
    func sumOfSquaredDifferences<T: Real>(key: Int, as type: T.Type) -> T {
        let fourS: Int = sumSquaresFirst + sumSquaresSecond - 2 * scale * key
        return T(fourS) / T(4)
    }

    /// `S` for a rho that need not be attainable (the approximations' thresholds).
    func sumOfSquaredDifferences<T: Real>(rho: T, as type: T.Type) -> T {
        let spread = spreads(as: T.self)
        let crossSum: T = (rho * spread.first.squareRoot() * spread.second.squareRoot()
                           + T(sumFirst) * T(sumSecond)) / T(items)
        return (T(sumSquaresFirst) + T(sumSquaresSecond) - T(2) * crossSum) / T(4)
    }

    /// The smallest possible gap between two attainable rho values: one step of `K`.
    func latticeStep<T: Real>(as type: T.Type) -> T {
        let spread = spreads(as: T.self)
        return T(items) * T(scale) / (spread.first.squareRoot() * spread.second.squareRoot())
    }
}

/// Averaged ranks, doubled: integers, `2p + t + 1` for a group of `t` ties at zero-based
/// sorted place `p`. Read off positions, never converted from a floating-point rank.
internal func doubledAverageRanks<T: Real>(_ values: [T]) -> [Int] {
    let order: [Int] = values.indices.sorted { values[$0] < values[$1] }
    var ranks: [Int] = Array(repeating: 0, count: values.count)
    var start: Int = 0
    while start < order.count {
        var end: Int = start + 1
        while end < order.count && values[order[end]] == values[order[start]] { end += 1 }
        let doubled: Int = start + end + 1
        for k in start..<end { ranks[order[k]] = doubled }
        start = end
    }
    return ranks
}

/// Doubled ranks grouped by value, ascending.
private func rankGroups(_ doubled: [Int]) -> [DoubledRankGroup] {
    var groups: [DoubledRankGroup] = []
    for rank in doubled.sorted() {
        if let last = groups.last, last.doubledRank == rank {
            groups[groups.count - 1] = DoubledRankGroup(doubledRank: rank, count: last.count + 1)
        } else {
            groups.append(DoubledRankGroup(doubledRank: rank, count: 1))
        }
    }
    return groups
}

/// Euclid's algorithm, iteratively; `gcd(0, b) = b`.
private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
    var x: Int = Swift.abs(a)
    var y: Int = Swift.abs(b)
    while y != 0 {
        let remainder: Int = x % y
        x = y
        y = remainder
    }
    return x
}
