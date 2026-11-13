//
//  SpearmanExactCounts.swift
//  BusinessMath
//
//  Exact integer counts of the arrangements behind each value of Σ XᵢYᵢ, the statistic that
//  orders Spearman's rho under permutation, ties included.
//

import Foundation
import Numerics

/// Exact counts of the equally likely arrangements of one judge's ranks against another's,
/// by the value of `K = Σ XᵢYᵢ / scale`.
///
/// ## The method
///
/// One judge's doubled ranks are the **positions** `p₀ ≤ p₁ ≤ … ≤ pₙ₋₁`; the other's are a
/// multiset of **values** `v₀ < v₁ < …` with multiplicities `t₀, t₁, …`. Under the null every
/// distinct arrangement of the values over the positions is equally likely (each stands for
/// `∏ tⱼ!` of the `n!` permutations), and there are `n! / ∏ tⱼ!` of them.
///
/// The arrangements are counted by dynamic programming over positions. After `k` positions
/// are filled, the state is how many of each value have been used, `(c₀, c₁, …)` with
/// `Σ cⱼ = k`, and each state carries the exact count of partial arrangements reaching it at
/// every partial sum. Filling position `k` with value `j` moves `(… cⱼ …)` to `(… cⱼ + 1 …)`
/// and adds `pₖ·vⱼ` to the sum. Each distinct arrangement is exactly one path, so the single
/// final state holds the distribution. Van de Wiel and Di Bucchianico (2001, J. Statist.
/// Plann. Inference 92:133–145) compute Spearman's rho with ties by recursions of this kind.
///
/// Without ties the states are the `2ⁿ` subsets of values; ties shrink them to
/// `∏ (tⱼ + 1)`, so heavily tied tastings are exact far beyond the untied limit. The caller
/// chooses as values whichever judge gives fewer states.
///
/// Only two adjacent layers are held at once, and each state stores counts only over the hull
/// of partial sums it can reach. Counts are fixed-width multi-limb integers (see
/// ``MultiLimb``), wide enough for `n!`.
internal struct SpearmanExactCounts: Sendable {
    /// 64-bit limbs per count.
    let width: Int
    /// The attainable values of `K`, ascending. Unattainable values are not stored.
    let keys: [Int]
    /// The count for each key, `width` limbs each, least significant limb first.
    let limbs: [UInt64]
    /// The number of distinct arrangements, `n! / ∏ tⱼ!`: the sum of all counts.
    let total: [UInt64]

    /// The number of attainable values.
    var entries: Int { keys.count }

    /// Entry `index` as a standalone number.
    func count(_ index: Int) -> [UInt64] {
        let start: Int = index * width
        return Array(limbs[start..<(start + width)])
    }

    /// The sum of entries `range`, exactly.
    func sum(_ range: Range<Int>) -> [UInt64] {
        var result: [UInt64] = Array(repeating: 0, count: width)
        for index in range { MultiLimb.add(&result, limbs, at: index * width) }
        return result
    }

    /// How many keys are `≤ key`.
    func countAtMost(_ key: Int) -> Int {
        var low: Int = 0
        var high: Int = keys.count
        while low < high {
            let middle: Int = (low + high) / 2
            if keys[middle] <= key { low = middle + 1 } else { high = middle }
        }
        return low
    }
}

// MARK: - Construction

extension SpearmanExactCounts {
    /// One layer of the recursion: its states in ascending code order, and for each the
    /// lowest partial sum it can reach and how many sums it spans.
    struct Layer {
        var codes: [Int] = []
        var lows: [Int] = []
        var lengths: [Int] = []
        var offsets: [Int] = []
        var limbCount: Int = 0

        /// The position of `code` in ``codes``; the code is known to be present.
        func slot(of code: Int) -> Int {
            var low: Int = 0
            var high: Int = codes.count
            while low < high {
                let middle: Int = (low + high) / 2
                if codes[middle] < code { low = middle + 1 } else { high = middle }
            }
            return low
        }
    }

    /// The exact counts for positions against a multiset of values.
    ///
    /// - Parameters:
    ///   - positions: One judge's doubled ranks, ascending.
    ///   - values: The other judge's doubled ranks as groups, ascending.
    ///   - scale: A common factor of every `pₖ·vⱼ`; sums are stored divided by it.
    ///   - limbBudget: The most 64-bit limbs two adjacent layers may hold together.
    ///   - stateBudget: The most states one layer may have.
    ///   - minimumWidth: Limbs per count at least; tests use it to exercise the multi-limb path
    ///     on panels small enough to check.
    /// - Throws: `BusinessMathError.resourceExhausted` when either budget would be exceeded.
    ///   Nothing large is allocated before the check.
    static func make(positions: [Int], values: [DoubledRankGroup], scale: Int,
                     limbBudget: Int, stateBudget: Int, minimumWidth: Int = 1) throws -> SpearmanExactCounts {
        let n: Int = positions.count
        let sizes: [Int] = values.map(\.count)
        var strides: [Int] = []
        var stride: Int = 1
        for size in sizes {
            strides.append(stride)
            let (next, overflow) = stride.multipliedReportingOverflow(by: size + 1)
            guard !overflow else { throw exhausted("states", limit: stateBudget, n: n) }
            stride = next
        }
        guard largestLayer(sizes) <= Double(stateBudget) else {
            throw exhausted("states per layer", limit: stateBudget, n: n)
        }

        // Every count is at most n!, so ⌈log₂ n!⌉ ≤ Σ bit lengths of 2…n bits suffice.
        var bits: Int = 1
        if n >= 2 { for k in 2...n { bits += Int.bitWidth - k.leadingZeroBitCount } }
        let width: Int = Swift.max(bits / 64 + 1, minimumWidth)

        var weights: [[Int]] = []
        weights.reserveCapacity(n)
        for position in positions {
            weights.append(values.map { position * $0.doubledRank / scale })
        }

        // First pass: the shape of every layer, so the budget is checked before any count
        // table exists.
        var layers: [Layer] = [Layer(codes: [0], lows: [0], lengths: [1], offsets: [0], limbCount: width)]
        for k in 0..<n {
            let next: Layer = try nextLayerShape(layers[k], sizes: sizes, strides: strides,
                                                 weights: weights[k], width: width)
            let (pair, overflow) = layers[k].limbCount.addingReportingOverflow(next.limbCount)
            guard !overflow, pair <= limbBudget else {
                throw exhausted("count limbs in two layers", limit: limbBudget, n: n)
            }
            layers.append(next)
        }

        // Second pass: the counts.
        var current: [UInt64] = [1] + Array(repeating: 0, count: width - 1)
        for k in 0..<n {
            var next: [UInt64] = Array(repeating: 0, count: layers[k + 1].limbCount)
            accumulate(current, from: layers[k], into: &next, to: layers[k + 1],
                       sizes: sizes, strides: strides, weights: weights[k], width: width)
            current = next
        }

        let final: Layer = layers[n]
        var keys: [Int] = []
        var limbs: [UInt64] = []
        var total: [UInt64] = Array(repeating: 0, count: width)
        for entry in 0..<final.lengths[0] {
            let start: Int = entry * width
            let count: ArraySlice<UInt64> = current[start..<(start + width)]
            guard count.contains(where: { $0 != 0 }) else { continue }
            keys.append(final.lows[0] + entry)
            limbs.append(contentsOf: count)
            MultiLimb.add(&total, current, at: start)
        }
        return SpearmanExactCounts(width: width, keys: keys, limbs: limbs, total: total)
    }

    /// The size of the largest layer: the largest coefficient of `∏ (1 + z + … + z^tⱼ)`.
    /// In floating point, because it is only compared with a budget and may be astronomical.
    static func largestLayer(_ sizes: [Int]) -> Double {
        var coefficients: [Double] = [1]
        for size in sizes {
            var product: [Double] = Array(repeating: 0, count: coefficients.count + size)
            for (degree, c) in coefficients.enumerated() {
                for extra in 0...size { product[degree + extra] += c }
            }
            coefficients = product
        }
        return coefficients.max() ?? 1
    }

    /// The states reachable from `layer` by filling one more position, with their sum hulls.
    private static func nextLayerShape(_ layer: Layer, sizes: [Int], strides: [Int],
                                       weights: [Int], width: Int) throws -> Layer {
        var codes: Set<Int> = []
        for code in layer.codes {
            for j in sizes.indices where (code / strides[j]) % (sizes[j] + 1) < sizes[j] {
                codes.insert(code + strides[j])
            }
        }
        var next = Layer()
        next.codes = codes.sorted()
        var highs: [Int] = Array(repeating: Int.min, count: next.codes.count)
        next.lows = Array(repeating: Int.max, count: next.codes.count)
        for (parent, code) in layer.codes.enumerated() {
            let low: Int = layer.lows[parent]
            let high: Int = low + layer.lengths[parent] - 1
            for j in sizes.indices where (code / strides[j]) % (sizes[j] + 1) < sizes[j] {
                let child: Int = next.slot(of: code + strides[j])
                next.lows[child] = Swift.min(next.lows[child], low + weights[j])
                highs[child] = Swift.max(highs[child], high + weights[j])
            }
        }
        next.lengths = zip(next.lows, highs).map { $1 - $0 + 1 }
        next.offsets.reserveCapacity(next.codes.count)
        var offset: Int = 0
        for length in next.lengths {
            next.offsets.append(offset)
            let (limbs, overflow) = length.multipliedReportingOverflow(by: width)
            let (sum, overflowSum) = offset.addingReportingOverflow(limbs)
            guard !overflow, !overflowSum else {
                throw exhausted("count limbs", limit: Int.max, n: sizes.reduce(0, +))
            }
            offset = sum
        }
        next.limbCount = offset
        return next
    }

    /// Adds every parent's counts into each child it reaches, shifted by the weight added.
    ///
    /// The hot loop of the method: `Σ states × children × hull × width` limb additions,
    /// written against buffers because per-element array access dominates an unoptimised
    /// build.
    private static func accumulate(_ current: [UInt64], from layer: Layer, into next: inout [UInt64],
                                   to nextLayer: Layer, sizes: [Int], strides: [Int],
                                   weights: [Int], width: Int) {
        current.withUnsafeBufferPointer { source in
            next.withUnsafeMutableBufferPointer { target in
                for (parent, code) in layer.codes.enumerated() {
                    let from: Int = layer.offsets[parent]
                    let length: Int = layer.lengths[parent]
                    for j in sizes.indices where (code / strides[j]) % (sizes[j] + 1) < sizes[j] {
                        let child: Int = nextLayer.slot(of: code + strides[j])
                        let shift: Int = layer.lows[parent] + weights[j] - nextLayer.lows[child]
                        let to: Int = nextLayer.offsets[child] + shift * width
                        if width == 1 {
                            for entry in 0..<length {
                                target[to + entry] &+= source[from + entry]
                            }
                            continue
                        }
                        for entry in 0..<length {
                            let base: Int = entry * width
                            var carry: Bool = false
                            for limb in 0..<width {
                                let (partial, first) = target[to + base + limb]
                                    .addingReportingOverflow(source[from + base + limb])
                                let (sum, second) = partial.addingReportingOverflow(carry ? 1 : 0)
                                target[to + base + limb] = sum
                                carry = first || second
                            }
                        }
                    }
                }
            }
        }
    }

    private static func exhausted(_ what: String, limit: Int, n: Int) -> BusinessMathError {
        BusinessMathError.resourceExhausted(
            resource: "exact Spearman distribution (\(what))", limit: limit,
            context: "\(n) items; use the Edgeworth or t approximation")
    }
}
