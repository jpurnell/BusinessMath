//
//  zScoreFisherR.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Computes the Z-Score given the Fisher's R value and the number of items.
///
/// This function calculates the Z-Score (also known as a standard score) for the Fisher's R and the number of items.
///
/// - Parameters:
///   - fisherR: The Fisher's R value.
///   - items: The number of items.
/// - Returns: The Z-Score associated with the given Fisher's R and number of items.
/// - Precondition: The `items` count must be an integer greater than 3.
///
///     let z = zScore(fisherR: 0.68, items: 7)
public func zScore<T: Real>(fisherR: T, items: Int) -> T {
	// Fisher's rank-correlation standard error is SE(z) = sqrt(1.06 / (n - 3)), so the
	// statistic exists only for n >= 4. At n = 3 the error is infinite and every correlation
	// scores zero; below that the radicand is negative and the result is NaN. Measured before
	// this guard: `items` of 0, 1 and 2 all returned NaN, and 3 returned exactly 0.0 whatever
	// the correlation was.
	precondition(items >= 4, "Fisher's rank-correlation z-score requires at least 4 observations; got \(items).")
    // Fixed: Integer division T(Int(106) / 100) was always T(1), dropping the 1.06 of
    // Fisher's rank-correlation standard error SE(z) = sqrt(1.06 / (n - 3)). Matches
    // the spelling already used by `zScore(rho:items:)`.
    return T.sqrt(T(items - 3) / (T(106) / T(100))) * fisherR
}
