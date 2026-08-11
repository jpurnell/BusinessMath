//
//  zScorePercentile.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the Z-Score given a percentile.
///
/// This function calculates the Z-Score (also known as a standard score) for a given percentile.
///
/// - Parameters:
///   - percentile: The percentile to compute the Z-Score for.
/// - Returns: The Z-Score corresponding to the given percentile.
/// - Precondition: The `percentile` argument must be a valid real number between 0 and 1.
///
///     let z = zScore(percentile: 0.84)
///
/// ## Method
///
/// The normal quantile function, so it delegates to ``inverseNormalCDF(p:mean:stdDev:)``
/// rather than being a second answer to the same question.
///
/// It previously computed `√2 · erfInv(2p - 1)`, refining against `erf`. That is
/// structurally the wrong direction in the tail: `erf`'s value saturates at `±1`,
/// so `erf(x) - y` has no bits left to correct with, and the Newton step stalls at
/// whatever the seed gave. `inverseNormalCDF` refines against `erfc` in the lower
/// tail, where the residual is a small number compared against a small number.
///
/// ## Accuracy
///
/// Absolute error in `z` against an arbitrary-precision reference:
///
/// | p      | reference z         | `√2·erfInv(2p-1)` (old) | this function |
/// |--------|---------------------|-------------------------|---------------|
/// | 1e-12  | -7.0344838253011321 | 2.1e-06                 | 0.0           |
/// | 1e-09  | -5.9978070150076865 | 5.1e-09                 | 8.9e-16       |
/// | 1e-06  | -4.7534243088228987 | 4.6e-12                 | 0.0           |
/// | 1e-04  | -3.7190164854556804 | 3.7e-14                 | 0.0           |
/// | 0.001  | -3.0902323061678136 | 1.3e-15                 | 4.4e-16       |
/// | 0.9995 |  3.2905267314919260 | 1.4e-14                 | 4.4e-16       |
///
/// Worst case over `1e-12 ≤ p ≤ 1 - 1e-12` is now `inverseNormalCDF`'s own
/// `1.8e-15`; see that function for the full table and the domain-edge behaviour,
/// which this function inherits (`p ≤ 0` gives `-infinity`, `p ≥ 1` gives
/// `+infinity`, NaN gives NaN) rather than the large-finite-value convention
/// ``erfInv(y:)`` uses.
public func zScore<T: Real>(percentile: T) -> T where T: BinaryFloatingPoint {
    return inverseNormalCDF(p: percentile)
}
