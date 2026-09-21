//
//  zScoreRho.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the Z-Score given the rank correlation (rho) and the number of items.
///
/// This function calculates the Z-Score (also known as a standard score), applying Fisher's Z-transformation (`fisher`) to the rank correlation coefficient `rho`, and adjusting for item count.
///
/// - Parameters:
///   - rho: The rank correlation coefficient.
///   - items: The number of items in the population.
/// - Returns: The Z-Score associated with the given rank correlation `rho` and item count.
/// - Precondition: The `items` count must be an integer greater than 3.
///
///     let z = try zScore(rho: 0.68, items: 7)
///
/// - Throws: `BusinessMathError.invalidInput` if rho is exactly ±1
public func zScore<T: Real>(rho: T, items: Int) throws -> T {
	// Fisher's rank-correlation standard error is SE(z) = sqrt(1.06 / (n - 3)), so the
	// statistic exists only for n >= 4. At n = 3 the error is infinite and every correlation
	// scores zero; below that the radicand is negative and the result is NaN. Measured before
	// this guard: `items` of 0, 1 and 2 all returned NaN, and 3 returned exactly 0.0 whatever
	// the correlation was.
	guard items >= 4 else {
		throw BusinessMathError.invalidInput(
			message: "Fisher's rank-correlation z-score requires at least 4 observations",
			value: "\(items)",
			expectedRange: ">= 4"
		)
	}
    // Fixed: Integer division T(Int(106) / 100) was always T(1)
    return T.sqrt(T(items - 3) / (T(106) / T(100))) * (try fisher(rho))
}

