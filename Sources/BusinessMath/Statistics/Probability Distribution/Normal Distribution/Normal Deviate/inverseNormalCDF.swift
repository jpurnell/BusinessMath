//
//  inverseNormalCDF.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the inverse of the normal cumulative distribution function (CDF) — the quantile function.
///
/// Returns the value `x` such that `normalCDF(x: x, mean: mean, stdDev: stdDev) == p`.
///
/// - Parameters:
///   - p: The probability to invert. Values outside `(0, 1)` return an infinity; see **Domain edges**.
///   - mean: The mean of the distribution. Defaults to `0`.
///   - stdDev: The standard deviation of the distribution. Defaults to `1`.
/// - Returns: The quantile of the distribution at `p`.
///
///     let zScore = inverseNormalCDF(p: 0.84, mean: 0, stdDev: 1)
///
/// ## Method
///
/// A closed-form rational approximation (Acklam, 2000) supplies a seed accurate
/// to roughly `1e-9`, which one Halley refinement step against `erfc` polishes to
/// the precision of the floating-point type. There is no iteration and no
/// convergence tolerance: the cost is fixed at one `log`, one `exp`, one `erfc`
/// and two short polynomials.
///
/// Two structural details matter:
///
/// - **Exact mirroring.** For `p >= 0.5` the subtraction `1 - p` is exact in binary
///   floating point (Sterbenz's lemma), so the upper half is computed as
///   `-quantile(1 - p)`. Symmetry `z(p) == -z(1 - p)` therefore holds *bit-for-bit*,
///   and the ill-conditioned upper tail is never evaluated directly.
/// - **No branch seam.** The rational seed switches branches at `p = 0.02425`,
///   where it is discontinuous by about `4.4e-9`. The refinement step removes the
///   seam: the measured jump across it is zero at `Double` precision.
///
/// ## Accuracy
///
/// Absolute error in `z`, measured against an `erfc`-based Halley reference.
/// "Bisection" is the previous implementation of this function — a binary search
/// on `[-10, 10]` with a stopping width of `1e-4` *expressed in z, not in
/// probability*, which is what made it uniformly coarse:
///
/// | p        | reference z      | bisection (old) | this function |
/// |----------|------------------|-----------------|---------------|
/// | 0.4      | -0.2533471031358 | 2.5e-05         | 5.6e-17       |
/// | 0.5      |  0.0             | 0.0             | 0.0           |
/// | 0.6      | +0.2533471031358 | 2.5e-05         | 5.6e-17       |
/// | 0.05     | -1.6448536269515 | 3.2e-05         | 2.2e-16       |
/// | 0.95     | +1.6448536269515 | 3.2e-05         | 2.2e-16       |
/// | 1e-3     | -3.0902323061678 | 5.4e-05         | 4.4e-16       |
/// | 0.999    | +3.0902323061678 | 5.4e-05         | 8.9e-16       |
/// | 1e-4     | -3.7190164854557 | 6.8e-05         | 0.0           |
/// | 0.9999   | +3.7190164854557 | 6.8e-05         | 4.4e-16       |
/// | 1e-6     | -4.7534243088229 | 7.0e-05         | 8.9e-16       |
/// | 0.999999 | +4.7534243088171 | 7.0e-05         | 8.9e-16       |
///
/// Worst case over a dense sweep:
///
/// | range                       | bisection (old) | this function     |
/// |-----------------------------|-----------------|-------------------|
/// | `1e-12 <= p <= 1 - 1e-12`   | 7.6e-05         | 1.8e-15 (2 ulp)   |
/// | lower tail down to `1e-225` | diverges        | 1.1e-14           |
///
/// For scale, the unrefined seed alone measures `8.4e-9` worst case, and Moro's
/// (1995) Chebyshev-tailed variant of Beasley-Springer measures `3.0e-9` — the
/// refinement step is what buys the remaining six orders of magnitude.
///
/// The old bisection also failed outright below about `p = 1e-16`, where the true
/// quantile leaves its hard-coded `[-10, 10]` bracket: at `p = 1e-20` it returned
/// `-8.33` against a true `-9.26`.
///
/// ## Domain edges
///
/// The quantile function has no finite value at the ends of the interval, so this
/// function returns the limits rather than trapping:
///
/// - `p <= 0` returns `-infinity`
/// - `p >= 1` returns `+infinity`
/// - `p` NaN returns NaN
///
/// Returning infinities keeps the function total, which matters because it sits
/// under Monte Carlo draws and optimiser inner loops where a trap would take down
/// a whole run over one sample. Callers that need a finite value should clamp `p`
/// before calling.
///
/// ## References
///
/// - Acklam, P.J. (2000) "An algorithm for computing the inverse normal cumulative
///   distribution function."
/// - Moro, B. (1995) "The full Monte." *Risk* 8(2), 57-58.
public func inverseNormalCDF<T: Real>(p: T, mean: T = 0, stdDev: T = 1) -> T {
    return mean + stdDev * standardNormalQuantile(p)
}

// MARK: - Implementation

/// The standard normal quantile function, total over the extended reals.
///
/// Splits at `0.5` and evaluates only the lower tail; see the note on exact
/// mirroring in ``inverseNormalCDF(p:mean:stdDev:)``.
private func standardNormalQuantile<T: Real>(_ p: T) -> T {
    if p.isNaN { return p }
    if p <= 0 { return -T.infinity }
    if p >= 1 { return T.infinity }

    let half = T(1) / T(2)
    if p == half { return 0 }
    if p < half { return refinedLowerQuantile(p) }
    // (1 - p) is exact here because p >= 0.5 (Sterbenz), so this mirror is free
    // of rounding and makes the symmetry of the result exact.
    return -refinedLowerQuantile(1 - p)
}

/// Quantile for a lower-tail probability `q` in `(0, 0.5)`.
private func refinedLowerQuantile<T: Real>(_ q: T) -> T {
    return halleyRefined(seed: acklamSeed(q), toward: q)
}

/// Divides `numerator` by `denominator`, falling back when the divisor is zero.
///
/// Every call site below establishes a strictly positive lower bound on the
/// divisor, so `fallback` is unreachable; it exists so the function is total
/// rather than producing an infinity or NaN from an unchecked division.
private func guardedQuotient<T: Real>(_ numerator: T, _ denominator: T, fallback: T) -> T {
    guard denominator != 0 else { return fallback }
    return numerator / denominator
}

// `decimal(_:over:)` lives in SpecialFunctions/DecimalConstant.swift.

/// Acklam's (2000) two-branch rational approximation to the lower-tail quantile.
///
/// Relative error below `1.15e-9` as published; measured worst case `8.4e-9`
/// absolute. Used only as a seed — the refinement step below carries it the
/// rest of the way.
private func acklamSeed<T: Real>(_ q: T) -> T {
    let a1: T = decimal(-3_969_683_028_665_376, over: 100_000_000_000_000)
    let a2: T = decimal(2_209_460_984_245_205, over: 10_000_000_000_000)
    let a3: T = decimal(-2_759_285_104_469_687, over: 10_000_000_000_000)
    let a4: T = decimal(138_357_751_867_269, over: 1_000_000_000_000)
    let a5: T = decimal(-3_066_479_806_614_716, over: 100_000_000_000_000)
    let a6: T = decimal(2_506_628_277_459_239, over: 1_000_000_000_000_000)

    let b1: T = decimal(-5_447_609_879_822_406, over: 100_000_000_000_000)
    let b2: T = decimal(1_615_858_368_580_409, over: 10_000_000_000_000)
    let b3: T = decimal(-1_556_989_798_598_866, over: 10_000_000_000_000)
    let b4: T = decimal(6_680_131_188_771_972, over: 100_000_000_000_000)
    let b5: T = decimal(-1_328_068_155_288_572, over: 100_000_000_000_000)

    let c1: T = decimal(-7_784_894_002_430_293, over: 1_000_000_000_000_000_000)
    let c2: T = decimal(-3_223_964_580_411_365, over: 10_000_000_000_000_000)
    let c3: T = decimal(-2_400_758_277_161_838, over: 1_000_000_000_000_000)
    let c4: T = decimal(-2_549_732_539_343_734, over: 1_000_000_000_000_000)
    let c5: T = decimal(4_374_664_141_464_968, over: 1_000_000_000_000_000)
    let c6: T = decimal(2_938_163_982_698_783, over: 1_000_000_000_000_000)

    let d1: T = decimal(7_784_695_709_041_462, over: 1_000_000_000_000_000_000)
    let d2: T = decimal(3_224_671_290_700_398, over: 10_000_000_000_000_000)
    let d3: T = decimal(2_445_134_137_142_996, over: 1_000_000_000_000_000)
    let d4: T = decimal(3_754_408_661_907_416, over: 1_000_000_000_000_000)

    let lowerBreak: T = decimal(2_425, over: 100_000)

    if q < lowerBreak {
        // Tail branch, in terms of r = sqrt(-2 ln q).
        let r = T.sqrt(-2 * T.log(q))

        // Horner, one step per binding. Written out rather than nested because the
        // nested form is a single generic expression of ten operators, and the Linux
        // 6.2.1 type-checker gives up on it under `-O` while macOS does not — the
        // failure appears only in CI. Each step is the same multiply-add in the same
        // order, so the result is bit-for-bit what the nested form produced.
        let cStep1: T = c1 * r + c2
        let cStep2: T = cStep1 * r + c3
        let cStep3: T = cStep2 * r + c4
        let cStep4: T = cStep3 * r + c5
        let numerator: T = cStep4 * r + c6

        let dStep1: T = d1 * r + d2
        let dStep2: T = dStep1 * r + d3
        let dStep3: T = dStep2 * r + d4
        let denominator: T = dStep3 * r + 1
        // |denominator| >= 23.6 for all q in (0, 0.02425).
        return guardedQuotient(numerator, denominator, fallback: -r)
    }

    // Central branch, in terms of u = q - 1/2.
    let half = T(1) / T(2)
    let u = q - half
    let r = u * u
    // Horner, one step per binding — same reason as the tail branch above, same
    // arithmetic in the same order.
    let aStep1: T = a1 * r + a2
    let aStep2: T = aStep1 * r + a3
    let aStep3: T = aStep2 * r + a4
    let aStep4: T = aStep3 * r + a5
    let aStep5: T = aStep4 * r + a6
    let numerator: T = aStep5 * u

    let bStep1: T = b1 * r + b2
    let bStep2: T = bStep1 * r + b3
    let bStep3: T = bStep2 * r + b4
    let bStep4: T = bStep3 * r + b5
    let denominator: T = bStep4 * r + 1
    // |denominator| >= 2.6e-3 for all q in [0.02425, 0.5).
    return guardedQuotient(numerator, denominator, fallback: 0)
}

/// One Halley step of `normalCDF(z) - q = 0`, taken entirely in the lower tail.
///
/// Halley converges cubically here, so a seed good to `1e-9` lands at full
/// precision in a single step. Working in the lower tail lets the residual be
/// formed from `erfc` directly, avoiding the cancellation that would occur if a
/// near-one CDF value were subtracted from a near-one probability.
private func halleyRefined<T: Real>(seed z: T, toward q: T) -> T {
    let half = T(1) / T(2)
    // sqrt(1/2) == 1/sqrt(2) and sqrt(1/(2*pi)) == 1/sqrt(2*pi), computed this
    // way so the values carry the full precision of `T` rather than a truncated
    // decimal, and so neither needs a reciprocal.
    let invSqrt2 = T.sqrt(half)
    let invSqrt2Pi = T.sqrt(half / T.pi)

    // Standard normal density at the seed.
    let density = T.exp(-z * z * half) * invSqrt2Pi
    // Underflows once |z| passes about 38 for Double; the seed is already at the
    // limit of what the type can express there, so return it unrefined.
    guard density > 0, density.isFinite else { return z }

    let residual = T.erfc(-z * invSqrt2) * half - q
    let newtonStep = guardedQuotient(residual, density, fallback: 0)

    let halleyDenominator = 1 + z * newtonStep * half
    let step = guardedQuotient(newtonStep, halleyDenominator, fallback: newtonStep)
    guard step.isFinite else { return z }

    return z - step
}
