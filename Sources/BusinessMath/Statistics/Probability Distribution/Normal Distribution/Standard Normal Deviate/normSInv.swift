//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import Foundation
import Numerics

// MARK: - Excel Compatibility: Equivalent of Excel's NORM.S.INV function, culumative probability = true
/// Computes the inverse of the standard normal cumulative distribution function (CDF) for a given probability.
///
/// This function computes the quantile function (also known as the percent-point function or inverse CDF) for the standard normal distribution. Excel Compatibility: Equivalent of Excel's NORM.S.INV function, culumative probability = true
/// - Parameters:
///   - x: The probability for which the inverse CDF is computed.
/// - Returns: The inverse CDF for the standard normal distribution at `x`.
/// - Precondition: The `x` argument must be a valid real number between 0 and 1.
///
///     let result = normSInv(probability: 0.84)
public func normSInv<T: Real>(probability x: T) -> T where T: BinaryFloatingPoint {
    return zScore(percentile: x)
}
