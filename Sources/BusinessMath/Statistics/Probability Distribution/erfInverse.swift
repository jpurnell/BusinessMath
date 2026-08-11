//
//  erfInverse.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// erfInv allows us to calculate the zScore for a desired Area under a normal curve without having to rely on a lookup table
// https://stackoverflow.com/questions/36784763/is-there-an-inverse-error-public function-available-in-swifts-foundation-import

/// Computes the inverse of the error function.
///
/// The error function (also called the Gauss error function) is a special function of probability theory and statistics. This method implements the inverse error function, also known as the quantile function or the percent-point function `erf-1()`. The quantile function is the function that, given a probability `y`, returns a value `x` such that `Pr[X <= x] = y`. It's particularly important in statistics for generating values of random variables for a given probability.
///
/// - Parameter y: The probability for which to find `x`.
///
/// - Returns: The value `x` that corresponds to the given `y` probability when passed to the error function. If `abs(y)` equals `1`, it returns `y * 1e308` (a very large finite value representing practical infinity). If `abs(y)` is greater than `1`, it returns `.nan`.
///
/// - Precondition: `y` should be a value between `-1` and `1` (inclusive).
/// - Complexity: O(1), since it uses a constant number of operations.
///
///     let y = 0.5
///     let result = erfInv(y: y)
///     print(result)
///
/// Use this function when you need to perform a quantile function or percent-point function operation on your dataset.
///
/// ## Method
///
/// `erf⁻¹(y) = Φ⁻¹((1 + y)/2) / √2`, evaluated through
/// ``inverseNormalCDF(p:mean:stdDev:)`` so that the library has one quantile
/// implementation rather than two.
///
/// The argument is always formed from the *smaller* side. For `y ≥ 0` the function
/// uses `-Φ⁻¹((1 - y)/2)/√2`, which is the same value by the symmetry
/// `Φ⁻¹(p) = -Φ⁻¹(1 - p)`. This matters because `1 - y` is exact in binary floating
/// point for `y ≥ 0.5` (Sterbenz's lemma) while `1 + y` is not, so the near-`1`
/// end of the domain — where the function is most sensitive — is reached without
/// rounding its own argument. `erfInv(nextDown(1))` is finite and correct rather
/// than saturating.
///
/// The previous implementation was a rational seed followed by two Newton steps
/// against `erf`. In the tail `erf` saturates at `±1`, so the residual `erf(x) - y`
/// underflows to zero and the correction stalls; the error there was the seed's.
///
/// ## Accuracy
///
/// Measured as the relative residual `|erfc(erfInv(y)) - (1 - y)| / (1 - y)`, which
/// compares two small quantities and so cannot be flattered by `erf` saturating:
///
/// | y             | 1 - y    | Newton/`erf` (old) | this function |
/// |---------------|----------|--------------------|---------------|
/// | 0.9           | 1e-01    | 2.8e-16            | 0.0           |
/// | 0.99          | 1e-02    | 7.1e-15            | 6.9e-16       |
/// | 0.999         | 1e-03    | 6.6e-14            | 8.7e-16       |
/// | 0.999999      | 1e-06    | 5.6e-11            | 2.1e-16       |
/// | 1 - 1e-10     | 1e-10    | 4.0e-07            | 5.2e-16       |
/// | 1 - 1e-13     | 1e-13    | 6.0e-05            | 1.6e-15       |
/// | `nextDown(1)` | 1.11e-16 | 4.3e-03            | 4.4e-15       |
///
/// Worst case over `0 ≤ y < 1` sampled at `5e-5`: `5.3e-13` before, `2.3e-15` after.
///
/// ## Domain edges
///
/// Unchanged, because callers depend on them: `abs(y) == 1` returns `y * 1e308`
/// rather than an infinity, `abs(y) > 1` returns NaN, NaN returns NaN, and the sign
/// of a zero argument is preserved.
public func erfInv<T: Real>(y: T) -> T where T: BinaryFloatingPoint {
    if y.isNaN { return y }
    if abs(y) > T(1) { return .nan }
    // Use a large finite value instead of Int.max to avoid 32-bit overflow
    // This represents infinity in practical terms for the inverse error function
    if abs(y) == T(1) { return y * T(1e308) }
    // Returned directly so erfInv(-0) is -0 rather than the +0 the general branch
    // would produce from negating Φ⁻¹(0.5).
    if y == T(0) { return y }

    let invSqrt2 = T.sqrt(T(1) / T(2))
    if y > T(0) {
        // (1 - y) is exact for y >= 0.5 (Sterbenz), and well conditioned below it.
        return -inverseNormalCDF(p: (T(1) - y) / T(2)) * invSqrt2
    }
    return inverseNormalCDF(p: (T(1) + y) / T(2)) * invSqrt2
}
