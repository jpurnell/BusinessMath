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
/// This function calculates the Z-Score (also known as a standard score) for a given percentile by applying the inverse error function (`erfInv`).
///
/// - Parameters:
///   - percentile: The percentile to compute the Z-Score for.
/// - Returns: The Z-Score corresponding to the given percentile.
/// - Precondition: The `percentile` argument must be a valid real number between 0 and 1.
///
///     let z = zScore(percentile: 0.84)
public func zScore<T: Real>(percentile: T) -> T where T: BinaryFloatingPoint {
    return T.sqrt(2) * erfInv(y: ((T(2) * percentile) - T(1)))
}
