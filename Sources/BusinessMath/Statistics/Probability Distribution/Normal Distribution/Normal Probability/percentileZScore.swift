//
//  percentileZScore.swift
//
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the percentile for a given Z-Score.
///
/// This function calculates the percentile corresponding to the given Z-Score (also known as a standard score) `z`.
///
/// - Parameters:
///   - z: The Z-Score.
/// - Returns: The percentile corresponding to the given Z-Score.
///
///     let percentileValue = percentile(zScore: 1.96)
///
/// This is the standard normal CDF under another name, so it delegates to
/// ``normalCDF(x:mean:stdDev:)`` rather than restating the formula. It carried its
/// own copy of `(1 + erf(z/√2))/2` until that formulation was corrected, which made
/// it a second implementation with the tail cancellation the canonical one no
/// longer has. See ``normalCDF(x:mean:stdDev:)`` for the measured accuracy.
///
/// The delegation is bit-exact, not merely close: at the default `mean = 0` and
/// `stdDev = 1` the subtraction and the division are both exact, so this returns
/// the identical `Double` to `normalCDF(x: z)`.
public func percentile<T: Real>(zScore z: T) -> T {
    return normalCDF(x: z)
}
