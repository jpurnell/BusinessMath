//
//  zScoreCI.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the Z-Score given a confidence interval.
///
/// This function calculates the Z-Score (also known as a standard score) for the given confidence interval `ci`.
///
/// - Parameters:
///   - ci: The confidence interval.
/// - Returns: The Z-Score associated with the given confidence interval.
/// - Precondition: The `ci` argument must be a valid real number between 0 and 1.
///
///     let z = zScore(ci: 0.95)
public func zScore<T: Real>(ci: T) -> T where T: BinaryFloatingPoint {
    let lowProb = (T(1) - ci) / T(2)
    let highProb = T(1) - lowProb
    return zScore(percentile: highProb)
}
