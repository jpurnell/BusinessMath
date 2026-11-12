//
//  RankSumExactCounts.swift
//  BusinessMath
//
//  Exact integer outcome counts for the rank-sum distribution, in fixed-width multi-limb
//  arithmetic, so a critical value is never placed by rounding.
//

import Foundation
import Numerics

/// Exact counts of the `n^m` equally likely outcomes behind each doubled rank sum.
///
/// ## Why integers
///
/// A critical value is decided by comparing a tail probability with α/2. Summed in floating
/// point, a tail that is equal to α/2, or within rounding of it, can land on either side, and
/// the critical value moves by a whole step. Counting outcomes instead makes every tail an
/// exact integer over the exact total `n^m`, and the comparison exact.
///
/// `n^m` overflows any fixed integer type almost at once (50 wines and 12 judges already pass
/// `UInt64`), so each count is a fixed-width unsigned integer of `width` 64-bit limbs, little
/// endian, stored contiguously: entry `i` is `limbs[i·width ..< (i + 1)·width]`. The width is
/// fixed up front from `m·⌈log₂(n + 1)⌉` bits, an upper bound on `n^m`, so no count can
/// overflow it.
///
/// ## The convolution
///
/// Each judge's doubled ranks split into **runs**: a stretch of untied places gives the
/// arithmetic progression `2p + 2, 2p + 4, …`, each value once, and a group of `t` tied items
/// gives one value `t` times. Convolving with a run of length `r` is a sliding sum,
/// `W[i] = W[i − 2] + p[i] − p[i − 2r]`, kept separately for even and odd `i`. Subtraction is
/// exact in integers, so the window costs nothing in accuracy. A judge then costs
/// `O(support × runs × width)`, and an untied judge is a single run.
internal struct RankSumExactCounts: Sendable {
    /// 64-bit limbs per count.
    let width: Int
    /// All counts, `width` limbs each, least significant limb first.
    let limbs: [UInt64]
    /// `n^m`, the number of equally likely outcomes, `width` limbs.
    let total: [UInt64]

    /// The number of counts (the support width, in doubled-sum steps).
    var entries: Int { limbs.count / width }

    /// Whether entry `index` is zero: an unattainable doubled sum.
    func isZero(_ index: Int) -> Bool {
        let start: Int = index * width
        for limb in start..<(start + width) where limbs[limb] != 0 { return false }
        return true
    }

    /// Entry `index` as a standalone number.
    func count(_ index: Int) -> [UInt64] {
        let start: Int = index * width
        return Array(limbs[start..<(start + width)])
    }

    /// The sum of entries `range`, exactly.
    func sum(_ range: Range<Int>) -> [UInt64] {
        var total: [UInt64] = Array(repeating: 0, count: width)
        for index in range { MultiLimb.add(&total, limbs, at: index * width) }
        return total
    }
}

// MARK: - Construction

extension RankSumExactCounts {
    /// One run of a judge's doubled ranks: `length` values `start, start + 2, …`, each
    /// carried by `multiplicity` items.
    struct Run: Equatable {
        let start: Int
        let length: Int
        let multiplicity: Int
    }

    /// Splits a judge's rank groups into runs; see the type's documentation.
    static func runs(_ groups: [DoubledRankGroup]) -> [Run] {
        var runs: [Run] = []
        for group in groups {
            if group.count == 1, let last = runs.last, last.multiplicity == 1,
               last.start + 2 * last.length == group.doubledRank {
                runs[runs.count - 1] = Run(start: last.start, length: last.length + 1, multiplicity: 1)
            } else {
                runs.append(Run(start: group.doubledRank, length: 1, multiplicity: group.count))
            }
        }
        return runs
    }

    /// The exact counts for a validated panel, and the smallest doubled sum.
    ///
    /// - Throws: `BusinessMathError.resourceExhausted` when the table would exceed
    ///   `limbBudget` limbs; see ``rankSumDistribution(judgeRanks:)``.
    static func make(_ judges: [[DoubledRankGroup]], items: Int, limbBudget: Int) throws
        -> (counts: RankSumExactCounts, minimumDoubledSum: Int) {
        let bitsPerJudge: Int = Int.bitWidth - items.leadingZeroBitCount
        let width: Int = (judges.count * bitsPerJudge) / 64 + 1
        var span: Int = 0
        for groups in judges {
            span += groups[groups.count - 1].doubledRank - groups[0].doubledRank
        }
        let entries: Int = span + 1
        let (needed, overflow) = entries.multipliedReportingOverflow(by: width)
        guard !overflow, needed <= limbBudget else {
            throw BusinessMathError.resourceExhausted(
                resource: "exact rank-sum counts (\(entries) sums × \(width) limbs)",
                limit: limbBudget,
                context: "\(judges.count) judges × \(items) items; use the normal approximation")
        }

        // Two buffers at the final size, used alternately. Allocating a fresh, slightly larger
        // table for every judge left the allocator holding most of them: peak memory for
        // 200 judges × 50 items was 170 MB against a 3 MB table.
        var current: [UInt64] = Array(repeating: 0, count: entries * width)
        var next: [UInt64] = Array(repeating: 0, count: entries * width)
        current[0] = 1
        var currentEntries: Int = 1
        var minimum: Int = 0
        for groups in judges {
            let lowest: Int = groups[0].doubledRank
            let judgeSpan: Int = groups[groups.count - 1].doubledRank - lowest
            let nextEntries: Int = currentEntries + judgeSpan
            next.withUnsafeMutableBufferPointer { buffer in
                for limb in 0..<(nextEntries * width) { buffer[limb] = 0 }
            }
            for run in runs(groups) {
                convolve(current, entries: currentEntries, width: width,
                         run: run, shift: run.start - lowest, into: &next)
            }
            swap(&current, &next)
            currentEntries = nextEntries
            minimum += lowest
        }

        var total: [UInt64] = Array(repeating: 0, count: width)
        total[0] = 1
        for _ in judges { MultiLimb.multiply(&total, by: UInt64(items)) }
        return (RankSumExactCounts(width: width, limbs: current, total: total), minimum)
    }

    /// `next[i + shift] += multiplicity × Σ_{k < length} current[i − 2k]`, by sliding sums.
    private static func convolve(_ current: [UInt64], entries: Int, width: Int,
                                 run: Run, shift: Int, into next: inout [UInt64]) {
        let reach: Int = entries + 2 * (run.length - 1)
        let multiplier: UInt64 = UInt64(run.multiplicity)
        // Two windows, even and odd positions, side by side: limbs [0, width) and [width, 2·width).
        var windows: [UInt64] = Array(repeating: 0, count: 2 * width)
        // The hot loop of the whole method, written against buffers and inlined by hand: it runs
        // `support × runs` times per judge, and in an unoptimised build the per-element array
        // accessors and helper calls cost more than the arithmetic.
        current.withUnsafeBufferPointer { source in
            next.withUnsafeMutableBufferPointer { target in
                windows.withUnsafeMutableBufferPointer { window in
                    for index in 0..<reach {
                        let base: Int = (index & 1) * width
                        var nonZero: Bool = false
                        if index < entries {
                            let from: Int = index * width
                            var carry: Bool = false
                            for limb in 0..<width {
                                let (partial, first) = window[base + limb].addingReportingOverflow(source[from + limb])
                                let (sum, second) = partial.addingReportingOverflow(carry ? 1 : 0)
                                window[base + limb] = sum
                                carry = first || second
                            }
                        }
                        let leaving: Int = index - 2 * run.length
                        if leaving >= 0 && leaving < entries {
                            let from: Int = leaving * width
                            var borrow: Bool = false
                            for limb in 0..<width {
                                let (partial, first) = window[base + limb].subtractingReportingOverflow(source[from + limb])
                                let (difference, second) = partial.subtractingReportingOverflow(borrow ? 1 : 0)
                                window[base + limb] = difference
                                borrow = first || second
                            }
                        }
                        for limb in 0..<width where window[base + limb] != 0 { nonZero = true; break }
                        guard nonZero else { continue }
                        let to: Int = (index + shift) * width
                        var carry: UInt64 = 0
                        for limb in 0..<width {
                            let product = window[base + limb].multipliedFullWidth(by: multiplier)
                            let (low, first) = product.low.addingReportingOverflow(carry)
                            let (sum, second) = target[to + limb].addingReportingOverflow(low)
                            target[to + limb] = sum
                            carry = product.high &+ (first ? 1 : 0) &+ (second ? 1 : 0)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Fixed-width arithmetic

/// Unsigned multi-limb arithmetic on little-endian `[UInt64]`, fixed width, no allocation in
/// the hot paths. Every operation's result is known to fit (see ``RankSumExactCounts``), so an
/// overflow out of the top limb would be a bug in the width bound, not an input condition.
internal enum MultiLimb {
    /// `target += source[offset ..< offset + target.count]`.
    static func add(_ target: inout [UInt64], _ source: [UInt64], at offset: Int) {
        var carry: UInt64 = 0
        for limb in 0..<target.count {
            let (partial, first) = target[limb].addingReportingOverflow(source[offset + limb])
            let (sum, second) = partial.addingReportingOverflow(carry)
            target[limb] = sum
            carry = (first ? 1 : 0) + (second ? 1 : 0)
        }
    }

    /// `value ×= multiplier`, in place.
    static func multiply(_ value: inout [UInt64], by multiplier: UInt64) {
        var carry: UInt64 = 0
        for limb in 0..<value.count {
            let product = value[limb].multipliedFullWidth(by: multiplier)
            let (low, overflow) = product.low.addingReportingOverflow(carry)
            value[limb] = low
            carry = product.high &+ (overflow ? 1 : 0)
        }
    }

    /// `value × multiplier`, one limb wider so it cannot overflow.
    static func product(_ value: [UInt64], _ multiplier: UInt64) -> [UInt64] {
        var widened: [UInt64] = value
        widened.append(0)
        multiply(&widened, by: multiplier)
        return widened
    }

    /// `value >> bits`, same width.
    static func shiftedRight(_ value: [UInt64], by bits: Int) -> [UInt64] {
        let limbShift: Int = bits / 64
        let bitShift: Int = bits % 64
        var out: [UInt64] = Array(repeating: 0, count: value.count)
        for limb in 0..<value.count {
            let source: Int = limb + limbShift
            guard source < value.count else { break }
            var word: UInt64 = value[source] >> UInt64(bitShift)
            if bitShift > 0, source + 1 < value.count {
                word |= value[source + 1] << UInt64(64 - bitShift)
            }
            out[limb] = word
        }
        return out
    }

    /// `a ≤ b`, for numbers of any widths.
    static func lessThanOrEqual(_ a: [UInt64], _ b: [UInt64]) -> Bool {
        let width: Int = Swift.max(a.count, b.count)
        for limb in stride(from: width - 1, through: 0, by: -1) {
            let x: UInt64 = limb < a.count ? a[limb] : 0
            let y: UInt64 = limb < b.count ? b[limb] : 0
            if x != y { return x < y }
        }
        return true
    }

    /// The top 64 significant bits of `value` and the power of two they stand at:
    /// `value ≈ top × 2^exponent`, truncated. `nil` for zero.
    static func leading(_ value: [UInt64]) -> (top: UInt64, exponent: Int)? {
        guard let highest = value.lastIndex(where: { $0 != 0 }) else { return nil }
        let leadingZeros: Int = value[highest].leadingZeroBitCount
        var top: UInt64 = value[highest] << UInt64(leadingZeros)
        if leadingZeros > 0, highest > 0 {
            top |= value[highest - 1] >> UInt64(64 - leadingZeros)
        }
        let exponent: Int = highest * 64 - leadingZeros
        return (top, exponent)
    }

    /// `numerator / denominator` as a floating-point value, accurate to a few ulps for any
    /// widths, including ratios far below the smallest normal number (which become zero or
    /// subnormal rather than garbage).
    static func ratio<T: Real>(_ numerator: [UInt64], _ denominator: [UInt64], as type: T.Type) -> T {
        guard let top = leading(numerator), let bottom = leading(denominator) else { return T(0) }
        let quotient: T = real(top.top, as: T.self) / real(bottom.top, as: T.self)
        let scale: Int = top.exponent - bottom.exponent
        return T(sign: .plus, exponent: T.Exponent(scale), significand: quotient)
    }

    /// A `UInt64` as `T`, through two exact 32-bit halves.
    static func real<T: Real>(_ value: UInt64, as type: T.Type) -> T {
        let high: T = T(Int(value >> 32))
        let low: T = T(Int(value & 0xFFFF_FFFF))
        let shifted: T = high * T(4_294_967_296)
        return shifted + low
    }
}
