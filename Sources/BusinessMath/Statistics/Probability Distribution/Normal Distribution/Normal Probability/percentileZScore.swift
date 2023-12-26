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
public func percentile<T: Real>(zScore z: T) -> T {
    return (1 + T.erf(z / T.sqrt(2))) / T(2)
}
