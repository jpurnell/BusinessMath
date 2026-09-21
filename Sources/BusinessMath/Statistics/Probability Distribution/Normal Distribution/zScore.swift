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
	// Fisher's rank-correlation standard error is SE(z) = sqrt(1.06 / (n - 3)), so the
	// statistic exists only for n >= 4. At n = 3 the error is infinite and every correlation
	// scores zero; below that the radicand is negative and the result is NaN. Measured before
	// this guard: `items` of 0, 1 and 2 all returned NaN, and 3 returned exactly 0.0 whatever
	// the correlation was.
	guard n >= 4 else {
		throw BusinessMathError.invalidInput(
			message: "Fisher's rank-correlation z-score requires at least 4 observations",
			value: "\(n)",
			expectedRange: ">= 4"
		)
	}
    let r = try spearmansRho(independent, vs: variable)
    return T.sqrt( T(n - 3) / (T(106) / T(100)) ) * (try fisher(r))
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
///     let z = try zScore([1, 2, 3], r: 0.5)
///
/// - Throws: `BusinessMathError.invalidInput` if r is exactly ±1
public func zScore<T: Real>(_ independent: [T], r: T) throws -> T {
	// Fisher's rank-correlation standard error is SE(z) = sqrt(1.06 / (n - 3)), so the
	// statistic exists only for n >= 4. At n = 3 the error is infinite and every correlation
	// scores zero; below that the radicand is negative and the result is NaN. Measured before
	// this guard: `items` of 0, 1 and 2 all returned NaN, and 3 returned exactly 0.0 whatever
	// the correlation was.
	guard independent.count >= 4 else {
			throw BusinessMathError.invalidInput(
				message: "Fisher's rank-correlation z-score requires at least 4 observations",
				value: "\(independent.count)",
				expectedRange: ">= 4"
			)
		}
        return T.sqrt( (T(independent.count - 3) / (T(106) / T(100))) ) * (try fisher(r))
}
