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
///     let z = zScore(rho: 0.68, items: 7)
public func zScore<T: Real>(rho: T, items: Int) -> T {
    return T.sqrt(T(items - 3)/T(Int(106) / 100)) * fisher(rho)
}

