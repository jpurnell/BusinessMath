//
//  poissonSurvival.swift
//  BusinessMath
//
//  The Poisson upper tail, P(X ≥ k), computed directly. Added for the Diagnostics Hub's spike
//  rule, which asks whether a day's count is improbable under a baseline rate and tests the
//  answer against 0.001; `1 - poissonCDF` cannot see a tail that small with any precision.
//

import Foundation
import Numerics

/// The Poisson survival function: the probability of **at least** `k` events.
///
/// ```
/// P(X ≥ k) = Σ_{j ≥ k} e^(−λ) λʲ / j!
/// ```
///
/// Note the convention: `k` itself is included. That is the probability a spike test wants,
/// "a day at least this bad", and it is R's `ppois(k - 1, lambda, lower.tail = FALSE)` and
/// SciPy's `poisson.sf(k - 1, lambda)` (both of which exclude their argument).
///
/// ## Why not `1 - poissonCDF`
///
/// When the tail is small the CDF below it is close to 1, and the subtraction keeps only
/// the digits of the CDF that differ from 1. At `λ = 1` the probability of 20 or more events
/// is 1.59e-19; the CDF at 19 is 1 to within the rounding of its own sum, so
/// `1 - poissonCDF(19, µ: 1)` is that rounding, zero or of order 1e-16: not one correct digit.
/// A spike test would then misjudge a rare day by a factor of a thousand or more, and every
/// tail below about 1e-16 would look alike.
///
/// ## Method
///
/// The tail is summed from whichever side is small, so no step subtracts two nearly equal
/// numbers:
///
/// - **`k > λ`**: the upper tail itself. The first term, `P(X = k)`, is formed in log space,
///   as `exp(k ln λ − λ − ln Γ(k + 1))`, so that a large `λ` or `k` cannot overflow `λᵏ` or
///   underflow `e^(−λ)` on the way. Later terms follow by `P(X = j + 1) = P(X = j) · λ/(j + 1)`.
///   Past the mean that ratio is below 1 and falling, so the sum stops when a term no longer
///   changes it.
/// - **`k ≤ λ`**: `1 − P(X ≤ k − 1)`, with the lower sum taken downward from `k − 1` by
///   `P(X = j − 1) = P(X = j) · j/λ`. Below the mean `P(X ≤ k − 1)` is at most about ½, so
///   the subtraction loses nothing.
///
/// The regularized incomplete gamma, ``regularizedLowerIncompleteGamma(a:x:)``, is the
/// same quantity (`P(X ≥ k) = P(k, λ)`), but its series is capped at 200 terms, which is
/// too few once `k` and `λ` are in the hundreds.
///
/// ## Accuracy
///
/// Against R 4.6.2 (`ppois`) and SciPy 1.17.1 (`poisson.sf`): relative error below 1e-12
/// for `λ ≤ 10`, including tails down to 1e-215; below 1e-11 at `λ = 1000`; below 1e-9 at
/// `λ = 100 000`. The error at large `λ` is the rounding of `ln Γ(k + 1)` and `k ln λ`,
/// which are of order `k ln k` and cancel to a small difference. A tail below the smallest
/// subnormal `T` is returned as `0`.
///
/// ## Edges
///
/// - `k = 0` returns `1` for every rate, including `λ = 0`: at least zero events is certain.
/// - `λ = 0` returns `0` for every `k ≥ 1`: the distribution is a point mass at zero.
///
/// ## Usage
///
/// ```swift
/// // Baseline of 1.5 a day; today brought 9.
/// let p = try poissonSurvival(k: 9, lambda: 1.5)   // 2.8e-5
/// let spikes = p < 0.001                           // true
/// ```
///
/// - Parameters:
///   - k: The count, `k ≥ 0`. The tail includes `k`.
///   - lambda: The rate, finite and `λ ≥ 0`.
/// - Returns: `P(X ≥ k)` for `X ~ Poisson(λ)`, in [0, 1].
/// - Throws: `BusinessMathError.invalidInput` when `k` is negative, or when `lambda` is
///   negative, `nan` or infinite.
///
/// - Complexity: O(√λ) terms near the mean and fewer in the tails; the sum stops once a
///   term is below the precision of the total.
///
/// - SeeAlso: ``poissonCDF(_:µ:)``, ``poisson(_:µ:)``
public func poissonSurvival<T: Real>(k: Int, lambda: T) throws -> T {
    guard k >= 0 else {
        throw BusinessMathError.invalidInput(
            message: "poissonSurvival needs a non-negative count",
            value: "\(k)", expectedRange: "[0, ∞)")
    }
    // `lambda >= 0` is false for a `nan`, so this one guard refuses all three readings that
    // are not a rate: negative, `nan` and infinite.
    guard lambda.isFinite, lambda >= T.zero else {
        throw BusinessMathError.invalidInput(
            message: "poissonSurvival needs a finite, non-negative rate",
            value: "\(lambda)", expectedRange: "[0, ∞)")
    }
    // At least zero events is certain, whatever the rate.
    guard k > 0 else { return T(1) }
    // A zero rate is a point mass at zero, so no k ≥ 1 is reachable. Taken before the
    // logarithm below, which would be -infinity.
    guard lambda > T.zero else { return T.zero }

    let count: T = T(k)
    if count > lambda {
        return poissonUpperTailSum(from: k, lambda: lambda)
    }
    let below: T = poissonLowerTailSum(through: k - 1, lambda: lambda)
    return max(T.zero, T(1) - below)
}

/// `P(X = j)` in log space: `exp(j ln λ − λ − ln Γ(j + 1))`. `lambda` must be positive.
private func poissonTerm<T: Real>(_ j: Int, lambda: T) -> T {
    let count: T = T(j)
    let logPower: T = count * T.log(lambda)
    let logTerm: T = logPower - lambda - T.logGamma(count + T(1))
    return T.exp(logTerm)
}

/// `Σ_{j ≥ k} P(X = j)` for `k > λ > 0`, summed upward until a term stops mattering.
///
/// Every ratio `λ/(j + 1)` is below 1 and falling, so the terms decrease geometrically
/// and the loop ends: either a term drops below the total's precision, or it underflows to
/// zero, which satisfies the same test.
private func poissonUpperTailSum<T: Real>(from k: Int, lambda: T) -> T {
    var term: T = poissonTerm(k, lambda: lambda)
    var total: T = term
    var j: Int = k
    while term > total * T.ulpOfOne {
        j += 1
        term *= lambda / T(j)
        total += term
    }
    return min(total, T(1))
}

/// `Σ_{j ≤ upper} P(X = j)` for `0 ≤ upper < λ`, summed downward from `upper`.
///
/// Every ratio `j/λ` is below 1 and falling, so the loop ends on a negligible term, or at
/// `j = 0` at the latest.
private func poissonLowerTailSum<T: Real>(through upper: Int, lambda: T) -> T {
    var term: T = poissonTerm(upper, lambda: lambda)
    var total: T = term
    var j: Int = upper
    while j > 0, term > total * T.ulpOfOne {
        term *= T(j) / lambda
        j -= 1
        total += term
    }
    return total
}
