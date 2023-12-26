//
//  inverseNormalCDF.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the inverse of the normal cumulative distribution function (CDF) for a given probability with configuring mean and standard deviation.
///
/// This function calculates the quantile function (also known as the percent-point function or inverse CDF) for the normal distribution given a certain probability `p`. The function uses a binary search algorithm to find the z-score (i.e., the standard normal random variable) that corresponds to a given percentile.
///
/// - Parameters:
///   - p: The percentile to compute the inverse CDF for.
///   - mean: The mean or average of the distribution. Defaults to `0`.
///   - stdDev: The standard deviation of the distribution. Defaults to `1`.
///   - tolerance: The tolerance for the iterative algorithm to compute the inverse CDF. Defaults to `1/10000`.
/// - Returns: The z-score that corresponds to the given percentile.
/// - Precondition: The `stdDev` argument must be a non-zero valid real number, and `p` should be a valid real number between 0 and 1.
///
///     let zScore = inverseNormalCDF(p: 0.84, mean: 0, stdDev: 1)
public func inverseNormalCDF<T: Real>(p: T, mean: T = 0, stdDev: T = 1, tolerance: T = T(1)/T(10000)) -> T {
    if mean != 0 || stdDev != 1 {
        return mean + stdDev * inverseNormalCDF(p: p)
    }
    
    var lowZ = T(-10)
    var midZ = T(0)
    var midP = T(0)
    var hiZ = T(10)
    
    while hiZ - lowZ > tolerance {
        midZ = (lowZ + hiZ) / T(2)
        midP = normalCDF(x: midZ)
        
        if midP < p {
            lowZ = midZ
        }
        else if midP > p {
            hiZ = midZ
        }
        else {
            break
        }
    }
    return midZ
}
