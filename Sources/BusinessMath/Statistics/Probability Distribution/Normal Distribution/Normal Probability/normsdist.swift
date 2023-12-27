//
//  normSDist.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

// MARK: - Excel Compatibility – Equivalent of Excel's NORM.S.DIST function, culumative probability = true
/// Computes the cumulative distribution function (CDF) for the standard normal distribution, given a Z-Score.
///
/// Excel Compatibility – Equivalent of Excel's NORM.S.DIST function, culumative probability = true
/// 
/// This function computes the CDF, or the probability that a random variable X from the distribution is less than or equal to a given `z`.
///
/// - Parameters:
///   - z: The Z-Score.
/// - Returns: The CDF for the standard normal distribution at `z`.
///
///     let result = normSDist(zScore: 1.96)
public func normSDist<T: Real>(zScore z: T) -> T {
    return percentile(zScore: z)
}
