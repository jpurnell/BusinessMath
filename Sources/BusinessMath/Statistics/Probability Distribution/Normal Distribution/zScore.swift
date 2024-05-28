//
//  File.swift
//  
//
//  Created by Justin Purnell on 6/11/22.
//

import Foundation
import Numerics

/// Computes the Z-Score between pairs of elements in two independent sets.
///
/// This function calculates the Z-Score (also known as a standard score), which quantifies how many standard deviations an element `x` in `independent` is from the corresponding element in `variable`.
///
/// Uses Spearman's rank correlation coefficient (`spearmansRho`) and Fisher's Z-transformation (`fisher`) to calculate the z-score.
///
/// - Parameters:
///   - independent: An array of elements in the independent set.
///   - variable: An array of elements in the variable set.
/// - Returns: The Z-Score between elements in the independent set and variable set.
/// - Precondition: The input arrays `independent` and `variable` must have at least 3 elements each and be of the same length.
///
///     let z = zScore([1, 2, 3], vs: [1, 2, 3])
public func zScore<T: Real>(_ independent: [T], vs variable: [T]) throws -> T {
	guard independent.count == variable.count else { throw ArrayError.mismatchedLengths }
    let n = independent.count
    let r = try spearmansRho(independent, vs: variable)
    return T.sqrt( T(n - 3) / (T(106) / T(100)) ) * fisher(r)
}

/// Computes the Z-Score given the rank correlation of an independent set.
///
/// This function calculates the Z-Score (also known as a standard score) for the correlation `r` of elements in `independent`.
///
/// Uses Fisher's Z-transformation (`fisher`) to calculate the z-score.
///
/// - Parameters:
///   - independent: An array of elements in the independent set.
///   - r: The correlation coefficient.
/// - Returns: The Z-Score for the given correlation `r` and distribution in `independent`.
/// - Precondition: The input array `independent` must have at least 3 elements.
///
///     let z = zScore([1, 2, 3], r: 0.5)
public func zScore<T: Real>(_ independent: [T], r: T) -> T {
        return T.sqrt( (T(independent.count - 3) / (T(106) / T(100))) ) * fisher(r)
}
