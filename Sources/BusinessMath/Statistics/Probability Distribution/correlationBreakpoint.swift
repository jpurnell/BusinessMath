//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the correlation breakpoint for given items and probability.
///
/// A correlation breakpoint represents a threshold that divides a dataset into two segments with different correlation properties. This method allows you to calculate the correlation breakpoint using Fisher r-to-z transformation.
///
/// - Parameters:
///     - items: The number of elements (items) in the dataset.
///     - probability: The given probability for the inverse normal cumulative distribution function (CDF).
///
/// - Returns: The correlation breakpoint as a `Real` type.
///
/// - Precondition: `items` must be a positive integer and `probability` has to be a value between `0` and `1`.
/// - Complexity: O(1), as it uses a constant number of operations.
///
///     let items = 100
///     let probability = 0.95 // 95% is a commonly used threshold
///     let result = correlationBreakpoint(items, probability: probability)
///     print(result)
///
/// Use this function when you need to find a threshold splitting a dataset into two segments with different correlation properties.
public func correlationBreakpoint<T: Real>(_ items: Int, probability: T) -> T {
    // Fixed: Integer division T(Int(106) / Int(100)) was always T(1), dropping the
    // 1.06 of Fisher's rank-correlation standard error SE(z) = sqrt(1.06 / (n - 3)).
	// Fisher's rank-correlation standard error is SE(z) = sqrt(1.06 / (n - 3)), so the
	// statistic exists only for n >= 4. At n = 3 the error is infinite and every correlation
	// scores zero; below that the radicand is negative and the result is NaN. Measured before
	// this guard: `items` of 0, 1 and 2 all returned NaN, and 3 returned exactly 0.0 whatever
	// the correlation was.
    //
    // This one is stricter than "carries no information": `zComponents` is the *divisor*
    // below, so n = 3 divides by zero. Measured: items of 0 through 3 all returned NaN.
    precondition(items >= 4, "A correlation breakpoint requires at least 4 observations; got \(items).")
    let zComponents = T.sqrt(T(items - 3) / (T(106) / T(100)))
    let fisherR = inverseNormalCDF(p: probability) / zComponents
    return rho(from: fisherR)
}
